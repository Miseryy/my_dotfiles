import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // デフォルト経路のNIC、IPv4、送受信速度を常駐スクリプトから受け取る。
    property string interfaceName: ""
    property string address: ""
    property string download: "0 B/s"
    property string upload: "0 B/s"

    readonly property string scriptPath: Quickshell.shellDir + "/scripts/network-stats.sh"

    property Process watcher: Process {
        running: true
        command: [root.scriptPath]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const value = JSON.parse(line);
                    root.interfaceName = String(value.interface || "");
                    root.address = String(value.address || "");
                    root.download = String(value.download || "0 B/s");
                    root.upload = String(value.upload || "0 B/s");
                } catch (error) {
                    console.warn("Network stats returned invalid JSON:", error);
                }
            }
        }
        onExited: restartTimer.restart()
    }

    property Timer restartTimer: Timer {
        // ネットワーク切替などでプロセスが落ちた場合に自動再開する。
        interval: 2000
        onTriggered: root.watcher.running = true
    }
}
