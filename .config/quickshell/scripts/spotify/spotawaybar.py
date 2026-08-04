#!/usr/bin/env python3
"""Spotify Connectの再生情報を表示し、バーから操作する。"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
ENV_FILE = SCRIPT_DIR / ".env"
TOKEN_FILE = SCRIPT_DIR / ".spotify-token.json"
AUTHORIZE_URL = "https://accounts.spotify.com/authorize"
TOKEN_URL = "https://accounts.spotify.com/api/token"
API_BASE_URL = "https://api.spotify.com/v1"
SCOPES = (
    "user-read-currently-playing",
    "user-read-playback-state",
    "user-modify-playback-state",
)
REQUEST_TIMEOUT = 10
EXPIRY_MARGIN = 60
DISPLAY_WIDTH = 60
API_REFRESH_SECONDS = 5
SCROLL_INTERVAL_SECONDS = 1
SCROLL_SEPARATOR = "   •   "
EMPTY_TITLE = ""
EMPTY_ARTIST = ""
EMPTY_COVER_URL = ""


class SpotaWaybarError(RuntimeError):
    """設定・認証・Spotify APIで想定されるエラー。"""


def load_env(path: Path = ENV_FILE) -> None:
    """既存の環境変数を上書きせず、単純なKEY=VALUE設定を読み込む。"""
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].lstrip()
        key, separator, value = line.partition("=")
        if not separator or not key.strip():
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        os.environ.setdefault(key.strip(), value)


def get_config() -> tuple[str, str]:
    load_env()
    client_id = os.environ.get("SPOTIFY_CLIENT_ID", "").strip()
    redirect_uri = os.environ.get(
        "SPOTIFY_REDIRECT_URI", "http://127.0.0.1:8888/callback"
    ).strip()
    if not client_id:
        raise SpotaWaybarError(
            f"SPOTIFY_CLIENT_ID is not set. Copy {SCRIPT_DIR / '.env.example'} to {ENV_FILE}."
        )

    parsed = urllib.parse.urlparse(redirect_uri)
    if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "::1"}:
        raise SpotaWaybarError("SPOTIFY_REDIRECT_URI must use an HTTP loopback address.")
    if not parsed.port:
        raise SpotaWaybarError("SPOTIFY_REDIRECT_URI must include a port.")
    return client_id, redirect_uri


def save_token(token: dict[str, Any], path: Path = TOKEN_FILE) -> None:
    token = dict(token)
    token["expires_at"] = int(time.time()) + int(token.get("expires_in", 3600))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(token, indent=2) + "\n", encoding="utf-8")
    temporary.chmod(0o600)
    os.replace(temporary, path)
    path.chmod(0o600)


def load_token(path: Path = TOKEN_FILE) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise SpotaWaybarError("Spotify authorization is missing. Run: spotawaybar.py auth") from error
    except (json.JSONDecodeError, OSError) as error:
        raise SpotaWaybarError(f"Could not read the Spotify token: {error}") from error
    if not isinstance(data, dict) or not data.get("access_token"):
        raise SpotaWaybarError("The Spotify token file is invalid. Run: spotawaybar.py auth")
    return data


def http_request(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    form: dict[str, str] | None = None,
) -> tuple[int, Any | None]:
    data = None
    request_headers = dict(headers or {})
    if form is not None:
        data = urllib.parse.urlencode(form).encode("utf-8")
        request_headers["Content-Type"] = "application/x-www-form-urlencoded"
    request = urllib.request.Request(url, data=data, headers=request_headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT) as response:
            body = response.read()
            return response.status, json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        body = error.read()
        try:
            detail = json.loads(body) if body else {}
        except json.JSONDecodeError:
            detail = body.decode("utf-8", errors="replace")
        if error.code == 429:
            retry_after = error.headers.get("Retry-After", "unknown")
            raise SpotaWaybarError(f"Spotify rate limit reached; retry after {retry_after}s") from error
        raise SpotaWaybarError(f"Spotify API returned HTTP {error.code}: {detail}") from error
    except urllib.error.URLError as error:
        raise SpotaWaybarError(f"Could not connect to Spotify: {error.reason}") from error


def refresh_access_token(token: dict[str, Any], client_id: str) -> dict[str, Any]:
    refresh_token = token.get("refresh_token")
    if not refresh_token:
        raise SpotaWaybarError("No refresh token is available. Run: spotawaybar.py auth")
    _, refreshed = http_request(
        TOKEN_URL,
        method="POST",
        form={
            "client_id": client_id,
            "grant_type": "refresh_token",
            "refresh_token": str(refresh_token),
        },
    )
    if not isinstance(refreshed, dict) or not refreshed.get("access_token"):
        raise SpotaWaybarError("Spotify returned an invalid token refresh response")
    if not refreshed.get("refresh_token"):
        refreshed["refresh_token"] = refresh_token
    save_token(refreshed)
    return refreshed


def get_access_token() -> str:
    client_id, _ = get_config()
    token = load_token()
    if int(token.get("expires_at", 0)) <= int(time.time()) + EXPIRY_MARGIN:
        token = refresh_access_token(token, client_id)
    return str(token["access_token"])


def spotify_request(path: str, *, method: str = "GET") -> tuple[int, Any | None]:
    access_token = get_access_token()
    return http_request(
        f"{API_BASE_URL}{path}",
        method=method,
        headers={"Authorization": f"Bearer {access_token}"},
    )


def authorize() -> None:
    client_id, redirect_uri = get_config()
    parsed = urllib.parse.urlparse(redirect_uri)
    verifier = secrets.token_urlsafe(64)[:96]
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode("ascii")).digest()
    ).rstrip(b"=").decode("ascii")
    state = secrets.token_urlsafe(24)
    query = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "response_type": "code",
            "redirect_uri": redirect_uri,
            "scope": " ".join(SCOPES),
            "code_challenge_method": "S256",
            "code_challenge": challenge,
            "state": state,
        }
    )
    result: dict[str, str] = {}
    callback_path = parsed.path or "/"

    class CallbackHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
            request_url = urllib.parse.urlparse(self.path)
            if request_url.path != callback_path:
                self.send_error(404)
                return
            parameters = urllib.parse.parse_qs(request_url.query)
            result["state"] = parameters.get("state", [""])[0]
            result["code"] = parameters.get("code", [""])[0]
            result["error"] = parameters.get("error", [""])[0]
            success = bool(result["code"] and not result["error"])
            message = "Authorization complete. You can close this tab." if success else "Authorization failed. Return to the terminal."
            body = message.encode("utf-8")
            self.send_response(200 if success else 400)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: Any) -> None:
            return

    host = parsed.hostname or "127.0.0.1"
    server = HTTPServer((host, parsed.port), CallbackHandler)
    server.timeout = 180
    authorization_url = f"{AUTHORIZE_URL}?{query}"
    print(f"Open this URL to authorize SpotaWaybar:\n{authorization_url}")
    webbrowser.open(authorization_url)
    server.handle_request()
    server.server_close()

    if result.get("error"):
        raise SpotaWaybarError(f"Spotify authorization failed: {result['error']}")
    if not result.get("code") or result.get("state") != state:
        raise SpotaWaybarError("Spotify authorization timed out or returned an invalid state")
    _, token = http_request(
        TOKEN_URL,
        method="POST",
        form={
            "client_id": client_id,
            "grant_type": "authorization_code",
            "code": result["code"],
            "redirect_uri": redirect_uri,
            "code_verifier": verifier,
        },
    )
    if not isinstance(token, dict) or not token.get("access_token"):
        raise SpotaWaybarError("Spotify returned an invalid authorization response")
    save_token(token)
    print("Spotify authorization completed.")


def playback_status() -> dict[str, Any]:
    """Spotifyの再生状態をバーとカード用の辞書として返す。"""
    status, playback = spotify_request("/me/player/currently-playing")
    if status == 204 or not isinstance(playback, dict) or not playback.get("item"):
        return empty_playback_status("Spotify: not playing")

    item = playback["item"]
    if not isinstance(item, dict):
        return empty_playback_status("Spotify: unsupported item")
    title = str(item.get("name") or "Unknown title")
    artists = item.get("artists") or []
    artist_names = [
        str(artist.get("name"))
        for artist in artists
        if isinstance(artist, dict) and artist.get("name")
    ]
    show = item.get("show") if isinstance(item.get("show"), dict) else {}
    artist = ", ".join(artist_names) or str(show.get("name") or "Spotify")
    is_playing = bool(playback.get("is_playing"))
    device = playback.get("device") if isinstance(playback.get("device"), dict) else {}
    state_label = "Playing" if is_playing else "Paused"
    tooltip = f"{state_label}: {title} — {artist}"
    if device.get("name"):
        tooltip += f"\nDevice: {device['name']}"
    return {
        "text": f" {title} - {artist}",
        "tooltip": tooltip,
        "class": "playing" if is_playing else "paused",
        "title": title,
        "artist": artist,
        "cover_url": find_cover_url(item),
        "is_playing": is_playing,
    }


def empty_playback_status(tooltip: str = "") -> dict[str, Any]:
    """再生対象がないときの初期値を返す。状態値の取り残しを防ぐ。"""
    return {
        "text": "",
        "tooltip": tooltip,
        "class": "stopped",
        "title": EMPTY_TITLE,
        "artist": EMPTY_ARTIST,
        "cover_url": EMPTY_COVER_URL,
        "is_playing": False,
    }


def find_cover_url(item: dict[str, Any]) -> str:
    """楽曲またはPodcastから最も優先度の高いHTTPS画像URLを返す。"""
    image_sources = []
    album = item.get("album")
    show = item.get("show")
    if isinstance(album, dict):
        image_sources.append(album.get("images"))
    image_sources.append(item.get("images"))
    if isinstance(show, dict):
        image_sources.append(show.get("images"))

    for images in image_sources:
        if not isinstance(images, list):
            continue
        for image in images:
            if not isinstance(image, dict):
                continue
            url = image.get("url")
            if isinstance(url, str) and url.startswith("https://"):
                return url
    return EMPTY_COVER_URL


def print_status() -> None:
    try:
        output = playback_status()
    except SpotaWaybarError as error:
        print(f"SpotaWaybar: {error}", file=sys.stderr)
        output = empty_playback_status()
        output["class"] = "error"
    print(json.dumps(output, ensure_ascii=False))


def scroll_output(
    output: dict[str, Any], offset: int, width: int = DISPLAY_WIDTH
) -> dict[str, Any]:
    """Spotifyアイコンを固定したまま、指定幅で曲名をスクロールする。"""
    text = str(output.get("text", ""))
    prefix = " " if text.startswith(" ") else ""
    content = text[len(prefix) :]
    available_width = max(1, width - len(prefix))
    if len(content) <= available_width:
        return output

    loop = content + SCROLL_SEPARATOR
    start = offset % len(loop)
    repeated = loop + loop
    while len(repeated) < start + available_width:
        repeated += loop
    scrolled = dict(output)
    scrolled["text"] = prefix + repeated[start : start + available_width]
    return scrolled


def watch(width: int) -> None:
    """API取得頻度を抑えつつ、バー向けJSONを継続的に出力する。"""
    output: dict[str, Any] = empty_playback_status()
    previous_text = ""
    offset = 0
    next_api_refresh = 0.0

    while True:
        now = time.monotonic()
        if now >= next_api_refresh:
            try:
                output = playback_status()
            except SpotaWaybarError as error:
                print(f"SpotaWaybar: {error}", file=sys.stderr)
                output = empty_playback_status()
                output["class"] = "error"
            current_text = str(output.get("text", ""))
            if current_text != previous_text:
                offset = 0
                previous_text = current_text
            next_api_refresh = now + API_REFRESH_SECONDS

        print(json.dumps(scroll_output(output, offset, width), ensure_ascii=False), flush=True)
        offset += 1
        time.sleep(SCROLL_INTERVAL_SECONDS)


def control(action: str) -> None:
    if action == "toggle":
        _, playback = spotify_request("/me/player")
        is_playing = isinstance(playback, dict) and bool(playback.get("is_playing"))
        spotify_request("/me/player/pause" if is_playing else "/me/player/play", method="PUT")
        return
    endpoint = "/me/player/previous" if action == "previous" else "/me/player/next"
    spotify_request(endpoint, method="POST")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command", choices=("auth", "status", "watch", "toggle", "previous", "next")
    )
    parser.add_argument("--width", type=int, default=DISPLAY_WIDTH)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "auth":
            authorize()
        elif args.command == "status":
            print_status()
        elif args.command == "watch":
            if args.width < 2:
                raise SpotaWaybarError("--width must be at least 2")
            watch(args.width)
        else:
            control(args.command)
    except SpotaWaybarError as error:
        print(f"SpotaWaybar: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
