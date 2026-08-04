import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // ルートファイルシステムの使用率を全モニターで共有する。
    property string usedPercent: "N/A"
    property string tooltip: "Disk usage is unavailable"

    function refresh(): void {
        if (!diskProcess.running)
            diskProcess.running = true;
    }

    property Process diskProcess: Process {
        command: ["sh", "-c", "df -P / | awk 'NR == 2 { print $2, $3, $4, $5 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(/\s+/);
                if (fields.length !== 4)
                    return;
                root.usedPercent = fields[3];
                root.tooltip = "Root disk: " + fields[3] + " used\n" +
                    Math.round(Number(fields[1]) / 1048576) + " GiB total · " +
                    Math.round(Number(fields[2]) / 1048576) + " GiB used · " +
                    Math.round(Number(fields[3 - 1]) / 1048576) + " GiB available";
            }
        }
    }

    property Timer timer: Timer {
        // ディスク容量は頻繁に変わらないため5分間隔に抑える。
        interval: 300000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
