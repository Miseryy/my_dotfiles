import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

import spotawaybar


class PlaybackStatusTests(unittest.TestCase):
    def test_playing_track_is_formatted_for_waybar(self) -> None:
        playback = {
            "is_playing": True,
            "item": {
                "name": "Song",
                "artists": [{"name": "Artist"}],
                "album": {"images": [{"url": "https://example.com/cover.jpg"}]},
            },
            "device": {"name": "Phone"},
        }
        with patch.object(spotawaybar, "spotify_request", return_value=(200, playback)):
            result = spotawaybar.playback_status()

        self.assertEqual(result["text"], " Song - Artist")
        self.assertEqual(result["class"], "playing")
        self.assertEqual(result["title"], "Song")
        self.assertEqual(result["artist"], "Artist")
        self.assertEqual(result["cover_url"], "https://example.com/cover.jpg")
        self.assertTrue(result["is_playing"])
        self.assertIn("Phone", result["tooltip"])

    def test_paused_track_uses_paused_class(self) -> None:
        playback = {
            "is_playing": False,
            "item": {"name": "Song", "artists": [{"name": "Artist"}]},
        }
        with patch.object(spotawaybar, "spotify_request", return_value=(200, playback)):
            result = spotawaybar.playback_status()

        self.assertEqual(result["class"], "paused")

    def test_no_playback_is_hidden(self) -> None:
        with patch.object(spotawaybar, "spotify_request", return_value=(204, None)):
            result = spotawaybar.playback_status()

        self.assertEqual(result["text"], "")
        self.assertEqual(result["class"], "stopped")
        self.assertEqual(result["cover_url"], "")
        self.assertFalse(result["is_playing"])

    def test_episode_uses_episode_cover_before_show_cover(self) -> None:
        playback = {
            "is_playing": True,
            "item": {
                "name": "Episode",
                "show": {
                    "name": "Podcast",
                    "images": [{"url": "https://example.com/show.jpg"}],
                },
                "images": [{"url": "https://example.com/episode.jpg"}],
            },
        }
        with patch.object(spotawaybar, "spotify_request", return_value=(200, playback)):
            result = spotawaybar.playback_status()

        self.assertEqual(result["artist"], "Podcast")
        self.assertEqual(result["cover_url"], "https://example.com/episode.jpg")

    def test_invalid_or_insecure_cover_url_is_ignored(self) -> None:
        item = {
            "album": {
                "images": [
                    {"url": "http://example.com/insecure.jpg"},
                    {"url": 123},
                    "invalid",
                ]
            }
        }

        self.assertEqual(spotawaybar.find_cover_url(item), "")

    def test_error_still_prints_valid_waybar_json(self) -> None:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch.object(
            spotawaybar,
            "playback_status",
            side_effect=spotawaybar.SpotaWaybarError("offline"),
        ), redirect_stdout(stdout), redirect_stderr(stderr):
            spotawaybar.print_status()

        self.assertEqual(json.loads(stdout.getvalue())["text"], "")
        self.assertIn("offline", stderr.getvalue())

    def test_long_text_scrolls_and_keeps_icon_fixed(self) -> None:
        output = {"text": " 123456789", "tooltip": "Full title", "class": "playing"}

        first = spotawaybar.scroll_output(output, offset=0, width=8)
        second = spotawaybar.scroll_output(output, offset=1, width=8)

        self.assertEqual(first["text"], " 123456")
        self.assertEqual(second["text"], " 234567")
        self.assertEqual(second["tooltip"], "Full title")

    def test_short_text_does_not_scroll(self) -> None:
        output = {"text": " Song", "class": "playing"}

        self.assertIs(spotawaybar.scroll_output(output, offset=10, width=60), output)


class TokenTests(unittest.TestCase):
    def test_token_is_saved_with_private_permissions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "token.json"
            spotawaybar.save_token(
                {"access_token": "access", "refresh_token": "refresh", "expires_in": 60},
                path,
            )
            saved = json.loads(path.read_text(encoding="utf-8"))

            self.assertEqual(saved["access_token"], "access")
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertIn("expires_at", saved)

    def test_refresh_preserves_existing_refresh_token(self) -> None:
        response = {"access_token": "new", "expires_in": 3600}
        with patch.object(spotawaybar, "http_request", return_value=(200, response)), patch.object(
            spotawaybar, "save_token"
        ) as save:
            refreshed = spotawaybar.refresh_access_token(
                {"access_token": "old", "refresh_token": "keep"}, "client-id"
            )

        self.assertEqual(refreshed["refresh_token"], "keep")
        save.assert_called_once()


class ControlTests(unittest.TestCase):
    def test_toggle_pauses_active_playback(self) -> None:
        with patch.object(
            spotawaybar,
            "spotify_request",
            side_effect=[(200, {"is_playing": True}), (204, None)],
        ) as request:
            spotawaybar.control("toggle")

        request.assert_any_call("/me/player/pause", method="PUT")

    def test_next_posts_to_next_endpoint(self) -> None:
        with patch.object(spotawaybar, "spotify_request", return_value=(204, None)) as request:
            spotawaybar.control("next")

        request.assert_called_once_with("/me/player/next", method="POST")


if __name__ == "__main__":
    unittest.main()
