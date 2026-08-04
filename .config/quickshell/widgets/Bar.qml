import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../components/Theme.js" as Theme

PanelWindow {
    id: bar

    // 値の監視は shell.qml 側の共有サービスに任せ、バーは配置だけを担当する。
    required property var screen
    required property var systemStatsService
    required property var diskService
    required property var networkStatsService
    required property var spotifyService
    required property var holidayService

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Theme.barHeight
    color: "#e6171a1f"
    exclusionMode: ExclusionMode.Auto

    // 入力領域を表示中のバーだけに限定し、画面全体のクリックを遮らないようにする。
    mask: Region {
        x: 0
        y: 0
        width: bar.width
        height: Theme.barHeight
    }

    RowLayout {
        // 左側: ワークスペースと現在のSpotify再生情報。
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.moduleSpacing

        WorkspaceWidget { screen: bar.screen }
        SpotifyWidget {
            screen: bar.screen
            service: bar.spotifyService
        }
    }

    ClockWidget {
        // 左右の幅に影響されず、時計だけは常に画面中央へ固定する。
        anchors.centerIn: parent
        screen: bar.screen
        holidayService: bar.holidayService
    }

    RowLayout {
        // 右側: ハードウェア・接続・システム状態をまとめる。
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.moduleSpacing

        DiskWidget { service: bar.diskService }
        BrightnessWidget {}
        VolumeWidget {}
        NetworkWidget { statsService: bar.networkStatsService }
        SystemStatsWidget { service: bar.systemStatsService }
        BluetoothWidget {}
        BatteryWidget {}
        TrayWidget { barWindow: bar }
    }
}
