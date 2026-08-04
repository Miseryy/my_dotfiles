import QtQuick
import "../components" as Components
import "../components/Theme.js" as Theme

Components.BarPill {
    id: root

    // 停止中や認証エラー時は空のカプセルを残さない。
    required property var service
    required property var screen

    readonly property int showDelayMilliseconds: 150
    readonly property int hideDelayMilliseconds: 250

    visible: service.text.length > 0 && service.state !== "stopped" && service.state !== "error"
    text: service.text
    tooltipText: service.tooltip
    backgroundColor: service.state === "paused" ? Theme.spotifyPaused : Theme.spotify
    foregroundColor: Theme.foreground

    onHoveredChanged: update_card_visibility()

    function update_card_visibility(): void {
        // カプセルとカードの間を移動する間は閉じない。戻り値はなく、表示タイマーを更新する。
        if (root.hovered || player_card.hovered) {
            hide_timer.stop();
            if (!player_card.visible)
                show_timer.restart();
            return;
        }

        show_timer.stop();
        hide_timer.restart();
    }

    onClicked: button => {
        // Waybar時代と同じマウスボタン割り当てを維持する。
        if (button === Qt.LeftButton)
            service.control("toggle");
        else if (button === Qt.MiddleButton)
            service.control("previous");
        else if (button === Qt.RightButton)
            service.control("next");
    }

    Timer {
        id: show_timer
        interval: root.showDelayMilliseconds
        onTriggered: {
            if (root.hovered && root.visible)
                player_card.visible = true;
        }
    }

    Timer {
        id: hide_timer
        interval: root.hideDelayMilliseconds
        onTriggered: {
            if (!root.hovered && !player_card.hovered)
                player_card.visible = false;
        }
    }

    SpotifyPlayerCard {
        id: player_card
        anchorItem: root
        screen: root.screen
        service: root.service
        onHoveredChanged: root.update_card_visibility()
    }
}
