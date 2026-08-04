import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // 常駐スクリプトが出す1行1JSONを、バー向けの状態へ変換する。
    property string text: "⧯ Cpu: N/A"
    property string tooltip: "System statistics are unavailable"
    property string state: "unavailable"

    readonly property string scriptPath: Quickshell.shellDir + "/scripts/system-stats.sh"

    property Process watcher: Process {
        running: true
        command: [root.scriptPath]

        stdout: SplitParser {
            onRead: line => {
                try {
                    const value = JSON.parse(line);
                    root.text = String(value.text || "");
                    root.tooltip = String(value.tooltip || "");
                    root.state = String(value.class || "unavailable");
                } catch (error) {
                    console.warn("System stats returned invalid JSON:", error);
                }
            }
        }

        onExited: restartTimer.restart()
    }

    // 一時的なセンサー障害などで終了しても監視を自動復旧する。
    property Timer restartTimer: Timer {
        interval: 2000
        onTriggered: root.watcher.running = true
    }
}
