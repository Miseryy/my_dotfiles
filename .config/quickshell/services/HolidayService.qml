import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var holidays: ({})
    property var availableYears: ({})
    property string source: "fallback"
    property string updatedMonth: ""
    property int revision: 0

    readonly property int refreshCheckIntervalMilliseconds: 21600000
    readonly property string scriptPath: Quickshell.shellDir
        + "/scripts/calendar/update_holidays.py"

    function synchronize(): void {
        // 月次更新スクリプトを起動する。戻り値はなく、プロセス実行状態を変更する。
        if (!sync_process.running)
            sync_process.running = true;
    }

    function rebuild_available_years(): void {
        // 公式キャッシュに含まれる年を索引化する。戻り値はなく、公開年一覧を更新する。
        const years = {};
        const keys = Object.keys(root.holidays);
        for (let index = 0; index < keys.length; index++)
            years[keys[index].slice(0, 4)] = true;
        root.availableYears = years;
    }

    function has_year(year: int): bool {
        // 公式キャッシュに指定年が含まれるかを返す。副作用はない。
        return root.availableYears[String(year)] === true;
    }

    function holiday_name(year: int, month: int, day: int): string {
        // 公式キャッシュから指定日の祝日名を返し、休日でなければ空文字列を返す。副作用はない。
        const key = String(year) + "-"
            + String(month).padStart(2, "0") + "-"
            + String(day).padStart(2, "0");
        return String(root.holidays[key] || "");
    }

    property Process sync_process: Process {
        id: sync_process
        running: true
        command: ["python3", root.scriptPath]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text);
                    if (typeof value.holidays !== "object" || value.holidays === null)
                        throw new Error("祝日キャッシュの形式が不正です");
                    root.holidays = value.holidays;
                    root.source = String(value.source || "fallback");
                    root.updatedMonth = String(value.updated_month || "");
                    root.rebuild_available_years();
                    root.revision++;
                    if (value.error)
                        console.warn("Holiday update:", value.error);
                } catch (error) {
                    root.source = "fallback";
                    console.warn("Holiday update returned invalid JSON:", error);
                }
            }
        }
    }

    property Timer refresh_timer: Timer {
        interval: root.refreshCheckIntervalMilliseconds
        repeat: true
        running: true
        onTriggered: root.synchronize()
    }
}
