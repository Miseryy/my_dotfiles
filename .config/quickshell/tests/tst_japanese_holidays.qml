import QtQuick
import QtTest
import "../components/JapaneseHolidays.js" as JapaneseHolidays

TestCase {
    name: "JapaneseHolidays"

    // 指定日の祝日名を取得する。文字列を返し、テスト対象以外への副作用はない。
    function holiday_name(year, month, day) {
        var holidays = JapaneseHolidays.holidays_for_year(year)
        return JapaneseHolidays.holiday_name(holidays, year, month, day)
    }

    // 2026年について内閣府公表日と主要な計算祝日を確認する。
    function test_2026_official_holidays() {
        compare(holiday_name(2026, 1, 12), "成人の日")
        compare(holiday_name(2026, 3, 20), "春分の日")
        compare(holiday_name(2026, 5, 6), "振替休日")
        compare(holiday_name(2026, 7, 20), "海の日")
        compare(holiday_name(2026, 9, 22), "国民の休日")
        compare(holiday_name(2026, 9, 23), "秋分の日")
    }

    // 2027年の春分と振替休日が内閣府公表日と一致することを確認する。
    function test_2027_official_holidays() {
        compare(holiday_name(2027, 3, 21), "春分の日")
        compare(holiday_name(2027, 3, 22), "振替休日")
        compare(holiday_name(2027, 9, 23), "秋分の日")
    }

    // 日曜の祝日から次の空いている平日へ振替休日が生成されることを確認する。
    function test_substitute_holiday() {
        compare(holiday_name(2024, 2, 12), "振替休日")
        compare(holiday_name(2021, 8, 9), "振替休日")
    }

    // 2020年と2021年の五輪特例で通常日が祝日にならないことを確認する。
    function test_olympic_exceptions() {
        compare(holiday_name(2020, 7, 23), "海の日")
        compare(holiday_name(2020, 7, 24), "スポーツの日")
        compare(holiday_name(2020, 10, 12), "")
        compare(holiday_name(2021, 7, 22), "海の日")
        compare(holiday_name(2021, 7, 23), "スポーツの日")
    }

    // 対応範囲外では推測した祝日を返さないことを確認する。
    function test_unsupported_year() {
        compare(holiday_name(1999, 1, 1), "")
        compare(holiday_name(2100, 1, 1), "")
    }
}
