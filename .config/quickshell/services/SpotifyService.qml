import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Spotify Web APIの監視結果。再生端末が別PCやスマートフォンでも取得できる。
    property string text: ""
    property string tooltip: ""
    property string state: "stopped"
    property string title: ""
    property string artist: ""
    property string coverUrl: ""
    property bool isPlaying: false

    readonly property string scriptPath: Quickshell.shellDir + "/scripts/spotify/spotawaybar.py"

    function control(action: string): void {
        // 操作ごとに短命プロセスを起動し、監視プロセスとは分離する。
        Quickshell.execDetached(["python3", scriptPath, action]);
    }

    function reset_playback(): void {
        // 再生が止まった後に前の曲のカードを残さない。戻り値はなく、公開状態を初期化する。
        root.text = "";
        root.tooltip = "";
        root.state = "stopped";
        root.title = "";
        root.artist = "";
        root.coverUrl = "";
        root.isPlaying = false;
    }

    property Process watcher: Process {
        running: true
        command: ["python3", root.scriptPath, "watch", "--width", "30"]

        stdout: SplitParser {
            // 不正JSONが来てもバー全体を停止させず、Spotifyだけ非表示にする。
            onRead: line => {
                try {
                    const value = JSON.parse(line);
                    root.text = String(value.text || "");
                    root.tooltip = String(value.tooltip || "");
                    root.state = String(value.class || "error");
                    root.title = String(value.title || "");
                    root.artist = String(value.artist || "");
                    root.coverUrl = String(value.cover_url || "");
                    root.isPlaying = value.is_playing === true;
                } catch (error) {
                    root.reset_playback();
                    root.state = "error";
                    console.warn("Spotify returned invalid JSON:", error);
                }
            }
        }

        onExited: restartTimer.restart()
    }

    property Timer restartTimer: Timer {
        interval: 5000
        onTriggered: root.watcher.running = true
    }
}
