#!/usr/bin/env python3
"""内閣府CSVを月1回取得し、日本の祝日キャッシュをJSONで出力する。"""

from __future__ import annotations

import csv
import json
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime
from io import StringIO
from pathlib import Path
from typing import Callable


HOLIDAY_CSV_URL = "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv"
CACHE_FILE = Path.home() / ".cache/quickshell/holidays/japanese-holidays.json"
CSV_ENCODING = "cp932"
DATE_FORMAT = "%Y/%m/%d"
DATE_KEY_FORMAT = "%Y-%m-%d"
MONTH_KEY_FORMAT = "%Y-%m"
REQUEST_TIMEOUT_SECONDS = 15
MINIMUM_HOLIDAY_COUNT = 100
USER_AGENT = "Quickshell Japanese Holiday Calendar/1.0"


class HolidayUpdateError(RuntimeError):
    """祝日CSVの取得・解析・キャッシュで想定されるエラー。"""


@dataclass(frozen=True)
class HolidayCache:
    """更新月と日付別祝日名を保持するキャッシュデータ。"""

    updated_month: str
    holidays: dict[str, str]


def current_month_key(now: datetime | None = None) -> str:
    """現在年月を更新判定用の文字列で返す。副作用はない。"""
    target = now or datetime.now().astimezone()
    return target.strftime(MONTH_KEY_FORMAT)


def parse_holiday_csv(content: bytes) -> dict[str, str]:
    """Shift_JISの内閣府CSVを日付別祝日名へ変換して返す。副作用はない。"""
    try:
        decoded = content.decode(CSV_ENCODING)
    except UnicodeDecodeError as error:
        raise HolidayUpdateError("内閣府CSVの文字コードが不正です") from error

    holidays: dict[str, str] = {}
    rows = csv.reader(StringIO(decoded))
    next(rows, None)
    for row in rows:
        if len(row) < 2:
            continue
        raw_date = row[0].strip()
        name = row[1].strip()
        if not raw_date or not name:
            continue
        try:
            date_key = datetime.strptime(raw_date, DATE_FORMAT).strftime(
                DATE_KEY_FORMAT
            )
        except ValueError as error:
            raise HolidayUpdateError(f"内閣府CSVの日付が不正です: {raw_date}") from error
        holidays[date_key] = name

    if len(holidays) < MINIMUM_HOLIDAY_COUNT:
        raise HolidayUpdateError("内閣府CSVの祝日件数が不足しています")
    return holidays


def download_holidays() -> dict[str, str]:
    """内閣府CSVを取得・検証して祝日辞書を返す。ネットワーク通信を行う。"""
    request = urllib.request.Request(
        HOLIDAY_CSV_URL,
        headers={"User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(
            request,
            timeout=REQUEST_TIMEOUT_SECONDS,
        ) as response:
            return parse_holiday_csv(response.read())
    except (urllib.error.URLError, TimeoutError) as error:
        raise HolidayUpdateError(f"内閣府CSVを取得できません: {error}") from error


def load_cache(path: Path = CACHE_FILE) -> HolidayCache | None:
    """有効なJSONキャッシュを返し、未作成・破損時はNoneを返す。副作用はない。"""
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return None
    if not isinstance(value, dict):
        return None
    updated_month = value.get("updated_month")
    holidays = value.get("holidays")
    if not isinstance(updated_month, str) or not isinstance(holidays, dict):
        return None
    valid_entries = all(
        isinstance(key, str) and isinstance(name, str)
        for key, name in holidays.items()
    )
    if not valid_entries:
        return None
    return HolidayCache(updated_month=updated_month, holidays=holidays)


def save_cache(cache: HolidayCache, path: Path = CACHE_FILE) -> None:
    """祝日キャッシュを原子的に保存する。戻り値はなく、キャッシュファイルを更新する。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    payload = {
        "updated_month": cache.updated_month,
        "holidays": cache.holidays,
    }
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def synchronize(
    *,
    path: Path = CACHE_FILE,
    month_key: str | None = None,
    downloader: Callable[[], dict[str, str]] = download_holidays,
) -> tuple[HolidayCache | None, str, str]:
    """月次更新を行い、キャッシュ・取得元・エラー文を返す。必要時だけ通信と保存を行う。"""
    target_month = month_key or current_month_key()
    cached = load_cache(path)
    if cached and cached.updated_month == target_month:
        return cached, "cache", ""

    try:
        updated = HolidayCache(target_month, downloader())
        save_cache(updated, path)
        return updated, "official_csv", ""
    except HolidayUpdateError as error:
        return cached, "stale_cache" if cached else "fallback", str(error)
    except OSError as error:
        return cached, "stale_cache" if cached else "fallback", str(error)


def main() -> int:
    """同期結果をQMLサービス向けJSONとして出力し、常に処理結果コードを返す。"""
    cache, source, error = synchronize()
    output = {
        "holidays": cache.holidays if cache else {},
        "source": source,
        "updated_month": cache.updated_month if cache else "",
        "error": error,
    }
    print(json.dumps(output, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
