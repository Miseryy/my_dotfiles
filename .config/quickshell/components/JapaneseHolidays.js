.pragma library

var MIN_SUPPORTED_YEAR = 2000
var MAX_SUPPORTED_YEAR = 2099
var SUNDAY = 0
var MONDAY = 1
var SUBSTITUTE_HOLIDAY_START_YEAR = 1973
var EXTENDED_SUBSTITUTE_START_YEAR = 2007

// 指定日を祝日辞書で使う固定長キーへ変換する。文字列を返し、副作用はない。
function date_key(year, month, day) {
    return String(year) + "-" + String(month).padStart(2, "0") + "-"
        + String(day).padStart(2, "0")
}

// 指定月の第n曜日の日付を返す。副作用はない。
function nth_weekday(year, month, weekday, occurrence) {
    var first_weekday = new Date(year, month - 1, 1, 12).getDay()
    return 1 + ((weekday - first_weekday + 7) % 7) + (occurrence - 1) * 7
}

// 春分の日を2000〜2099年向けの暦計算で返す。副作用はない。
function vernal_equinox_day(year) {
    return Math.floor(20.8431 + 0.242194 * (year - 1980)
        - Math.floor((year - 1980) / 4))
}

// 秋分の日を2000〜2099年向けの暦計算で返す。副作用はない。
function autumnal_equinox_day(year) {
    return Math.floor(23.2488 + 0.242194 * (year - 1980)
        - Math.floor((year - 1980) / 4))
}

// 祝日辞書へ日付と名称を登録する。戻り値はなく、受け取った辞書を更新する。
function add_holiday(holidays, year, month, day, name) {
    holidays[date_key(year, month, day)] = name
}

// 通常の国民の祝日と年ごとの特例日を辞書へ登録する。戻り値はなく、辞書を更新する。
function add_national_holidays(holidays, year) {
    add_holiday(holidays, year, 1, 1, "元日")
    add_holiday(holidays, year, 1, nth_weekday(year, 1, MONDAY, 2), "成人の日")
    add_holiday(holidays, year, 2, 11, "建国記念の日")
    if (year >= 2020)
        add_holiday(holidays, year, 2, 23, "天皇誕生日")

    add_holiday(holidays, year, 3, vernal_equinox_day(year), "春分の日")
    add_holiday(
        holidays,
        year,
        4,
        29,
        year >= 2007 ? "昭和の日" : "みどりの日"
    )
    add_holiday(holidays, year, 5, 3, "憲法記念日")
    if (year >= 2007)
        add_holiday(holidays, year, 5, 4, "みどりの日")
    add_holiday(holidays, year, 5, 5, "こどもの日")

    add_summer_holidays(holidays, year)
    add_holiday(holidays, year, 9, nth_weekday(year, 9, MONDAY, 3), "敬老の日")
    add_holiday(holidays, year, 9, autumnal_equinox_day(year), "秋分の日")
    add_sports_holiday(holidays, year)
    add_holiday(holidays, year, 11, 3, "文化の日")
    add_holiday(holidays, year, 11, 23, "勤労感謝の日")

    if (year <= 2018)
        add_holiday(holidays, year, 12, 23, "天皇誕生日")
    if (year === 2019) {
        add_holiday(holidays, year, 5, 1, "天皇の即位の日")
        add_holiday(holidays, year, 10, 22, "即位礼正殿の儀の行われる日")
    }
}

// 海の日と山の日を五輪特例を含めて登録する。戻り値はなく、辞書を更新する。
function add_summer_holidays(holidays, year) {
    if (year === 2020) {
        add_holiday(holidays, year, 7, 23, "海の日")
        add_holiday(holidays, year, 8, 10, "山の日")
        return
    }
    if (year === 2021) {
        add_holiday(holidays, year, 7, 22, "海の日")
        add_holiday(holidays, year, 8, 8, "山の日")
        return
    }

    var marine_day = year >= 2003
        ? nth_weekday(year, 7, MONDAY, 3)
        : 20
    add_holiday(holidays, year, 7, marine_day, "海の日")
    if (year >= 2016)
        add_holiday(holidays, year, 8, 11, "山の日")
}

// スポーツの日を五輪特例と旧名称を含めて登録する。戻り値はなく、辞書を更新する。
function add_sports_holiday(holidays, year) {
    if (year === 2020) {
        add_holiday(holidays, year, 7, 24, "スポーツの日")
        return
    }
    if (year === 2021) {
        add_holiday(holidays, year, 7, 23, "スポーツの日")
        return
    }

    var name = year >= 2020 ? "スポーツの日" : "体育の日"
    add_holiday(
        holidays,
        year,
        10,
        nth_weekday(year, 10, MONDAY, 2),
        name
    )
}

// 二つの国民の祝日に挟まれた平日を「国民の休日」として追加する。戻り値はなく、辞書を更新する。
function add_citizens_holidays(holidays, year) {
    var national_holidays = Object.assign({}, holidays)
    var cursor = new Date(year, 0, 2, 12)
    var end_date = new Date(year, 11, 30, 12)

    while (cursor <= end_date) {
        var current_key = date_key(year, cursor.getMonth() + 1, cursor.getDate())
        if (!national_holidays[current_key] && cursor.getDay() !== SUNDAY) {
            var previous_date = new Date(cursor)
            var next_date = new Date(cursor)
            previous_date.setDate(previous_date.getDate() - 1)
            next_date.setDate(next_date.getDate() + 1)
            var previous_key = date_key(
                previous_date.getFullYear(),
                previous_date.getMonth() + 1,
                previous_date.getDate()
            )
            var next_key = date_key(
                next_date.getFullYear(),
                next_date.getMonth() + 1,
                next_date.getDate()
            )
            if (national_holidays[previous_key] && national_holidays[next_key])
                holidays[current_key] = "国民の休日"
        }
        cursor.setDate(cursor.getDate() + 1)
    }
}

// 日曜の祝日に対応する振替休日を追加する。戻り値はなく、辞書を更新する。
function add_substitute_holidays(holidays, year) {
    if (year < SUBSTITUTE_HOLIDAY_START_YEAR)
        return

    var holiday_keys = Object.keys(holidays)
    for (var index = 0; index < holiday_keys.length; index++) {
        var parts = holiday_keys[index].split("-")
        var holiday_date = new Date(
            Number(parts[0]),
            Number(parts[1]) - 1,
            Number(parts[2]),
            12
        )
        if (holiday_date.getDay() !== SUNDAY)
            continue

        var substitute_date = new Date(holiday_date)
        substitute_date.setDate(substitute_date.getDate() + 1)
        var substitute_key = date_key(
            substitute_date.getFullYear(),
            substitute_date.getMonth() + 1,
            substitute_date.getDate()
        )
        if (year >= EXTENDED_SUBSTITUTE_START_YEAR) {
            while (holidays[substitute_key]) {
                substitute_date.setDate(substitute_date.getDate() + 1)
                substitute_key = date_key(
                    substitute_date.getFullYear(),
                    substitute_date.getMonth() + 1,
                    substitute_date.getDate()
                )
            }
        }
        if (!holidays[substitute_key])
            holidays[substitute_key] = "振替休日"
    }
}

// 指定年の祝日名を日付キーで引ける辞書として返す。範囲外は空辞書を返し、副作用はない。
function holidays_for_year(year) {
    if (year < MIN_SUPPORTED_YEAR || year > MAX_SUPPORTED_YEAR)
        return {}

    var holidays = {}
    add_national_holidays(holidays, year)
    add_citizens_holidays(holidays, year)
    add_substitute_holidays(holidays, year)
    return holidays
}

// 祝日辞書から指定日の名称を返し、祝日でなければ空文字列を返す。副作用はない。
function holiday_name(holidays, year, month, day) {
    return holidays[date_key(year, month, day)] || ""
}
