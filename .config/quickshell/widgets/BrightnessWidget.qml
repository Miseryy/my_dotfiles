import Quickshell
import Quickshell.Io
import QtQuick
import "../components" as Components
import "../components/Theme.js" as Theme

Components.BarPill {
    id: root

    property int percent: 0
    property bool available: false
    property int lastSentPercent: -1
    property string deviceName: ""
    property int maxBrightness: 0

    visible: available
    text: percent + "% " + (percent < 40 ? "" : "")
    tooltipText: "Brightness: " + percent + "%"
    backgroundColor: Theme.red
    foregroundColor: Theme.foreground

    function refresh(): void {
        // 書き込み中の読み戻しで古い値へ戻らないよう競合を避ける。
        if (!reader.running && !setter.running && !setDebounce.running)
            reader.running = true;
    }

    onWheel: delta => {
        // 操作時は表示を即時更新し、書き込み後にハードウェア実値で補正する。
        percent = Math.max(1, Math.min(100, percent + (delta > 0 ? 1 : -1)));
        setDebounce.restart();
    }

    Process {
        // 連続スクロール中は最後の希望値まで順番に反映する。
        id: setter
        onExited: {
            if (root.percent !== root.lastSentPercent)
                setDebounce.restart();
            else
                delayedRefresh.restart();
        }
    }

    Timer {
        id: setDebounce
        interval: 40
        onTriggered: {
            if (setter.running)
                return;
            root.lastSentPercent = root.percent;
            setter.command = ["brightnessctl", "--class=backlight", "set", String(root.lastSentPercent) + "%"];
            setter.running = true;
        }
    }

    Process {
        id: reader
        command: ["brightnessctl", "--class=backlight", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length < 4) {
                    root.available = false;
                    return;
                }
                root.deviceName = fields[0];
                root.percent = Number(fields[3].replace("%", ""));
                root.maxBrightness = fields.length >= 5 ? Number(fields[4]) : 0;
                root.available = !isNaN(root.percent);
            }
        }
    }

    // Fnキーや他アプリはsysfsへ直接書くため、ファイル監視で即時反映する。
    FileView {
        id: brightnessWatcher
        path: root.deviceName.length > 0
            ? "/sys/class/backlight/" + root.deviceName + "/brightness" : ""
        printErrors: false
        watchChanges: path.length > 0
        onFileChanged: reload()
        onLoaded: {
            const rawValue = Number(text().trim());
            if (!isNaN(rawValue) && root.maxBrightness > 0) {
                root.percent = Math.round(rawValue * 100 / root.maxBrightness);
                root.available = true;
            }
        }
    }

    Timer {
        // ファイル監視が利用できない環境向けの低頻度フォールバック。
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: delayedRefresh
        interval: 75
        onTriggered: root.refresh()
    }
}
