import json
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path
from unittest.mock import Mock

import update_holidays


class HolidayCsvTests(unittest.TestCase):
    """内閣府CSVの解析を検証する。"""

    def test_shift_jis_csv_is_parsed(self) -> None:
        """Shift_JISの有効なCSVが日付別辞書へ変換されることを確認する。"""
        rows = ["国民の祝日・休日月日,国民の祝日・休日名称"]
        start_date = date(2026, 1, 1)
        for index in range(101):
            target = start_date + timedelta(days=index)
            raw_date = f"{target.year}/{target.month}/{target.day}"
            rows.append(f"{raw_date},祝日{index}")
        content = "\r\n".join(rows).encode("cp932")

        holidays = update_holidays.parse_holiday_csv(content)

        self.assertEqual(holidays["2026-01-01"], "祝日0")

    def test_too_few_rows_are_rejected(self) -> None:
        """件数不足のCSVが正常データとして採用されないことを確認する。"""
        content = "日付,名称\r\n2026/1/1,元日".encode("cp932")

        with self.assertRaises(update_holidays.HolidayUpdateError):
            update_holidays.parse_holiday_csv(content)


class SynchronizeTests(unittest.TestCase):
    """月次更新とフォールバックを検証する。"""

    def test_current_month_cache_skips_download(self) -> None:
        """当月のキャッシュがある場合にダウンロードしないことを確認する。"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "holidays.json"
            path.write_text(
                json.dumps(
                    {
                        "updated_month": "2026-08",
                        "holidays": {"2026-01-01": "元日"},
                    }
                ),
                encoding="utf-8",
            )
            downloader = Mock()

            cache, source, error = update_holidays.synchronize(
                path=path,
                month_key="2026-08",
                downloader=downloader,
            )

        self.assertIsNotNone(cache)
        self.assertEqual(source, "cache")
        self.assertEqual(error, "")
        downloader.assert_not_called()

    def test_stale_cache_is_replaced(self) -> None:
        """前月のキャッシュが公式データで置換されることを確認する。"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "holidays.json"
            path.write_text(
                json.dumps({"updated_month": "2026-07", "holidays": {"old": "古い"}}),
                encoding="utf-8",
            )

            cache, source, _ = update_holidays.synchronize(
                path=path,
                month_key="2026-08",
                downloader=lambda: {"2027-01-01": "元日"},
            )

        self.assertIsNotNone(cache)
        self.assertEqual(cache.updated_month, "2026-08")
        self.assertEqual(source, "official_csv")

    def test_failed_download_keeps_stale_cache(self) -> None:
        """取得失敗時に前回キャッシュを保持することを確認する。"""
        def fail_download() -> dict[str, str]:
            """通信失敗を模擬する例外を送出する。戻り値と副作用はない。"""
            raise update_holidays.HolidayUpdateError("offline")

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "holidays.json"
            path.write_text(
                json.dumps(
                    {
                        "updated_month": "2026-07",
                        "holidays": {"2026-01-01": "元日"},
                    }
                ),
                encoding="utf-8",
            )

            cache, source, error = update_holidays.synchronize(
                path=path,
                month_key="2026-08",
                downloader=fail_download,
            )

        self.assertIsNotNone(cache)
        self.assertEqual(source, "stale_cache")
        self.assertIn("offline", error)


if __name__ == "__main__":
    unittest.main()
