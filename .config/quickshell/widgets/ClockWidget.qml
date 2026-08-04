import Quickshell
import QtQuick
import "../components" as Components
import "../components/Theme.js" as Theme

Components.BarPill {
    id: root

    // 右クリックで通常表記と長い日付表記を切り替える。
    required property var screen
    required property var holidayService
    property bool alternate: false

    readonly property int showDelayMilliseconds: 150
    readonly property int hideDelayMilliseconds: 250

    text: alternate
        ? Qt.formatDateTime(clock.date, "dddd, MMMM dd, yyyy (HH:mm)") + " 🗓️"
        : Qt.formatDateTime(clock.date, "MM-dd dddd MMMM HH:mm:ss")
    tooltipText: Qt.formatDateTime(clock.date, "dddd, MMMM dd, yyyy")
    backgroundColor: Theme.purple
    foregroundColor: Theme.foreground
    fontPixelSize: 14

    onHoveredChanged: update_calendar_visibility()

    function update_calendar_visibility(): void {
        // 時計とカレンダーの間を移動する間は閉じない。戻り値はなく、表示タイマーを更新する。
        if (root.hovered || calendar_card.hovered) {
            hide_timer.stop();
            if (!calendar_card.visible)
                show_timer.restart();
            return;
        }

        show_timer.stop();
        hide_timer.restart();
    }

    onClicked: button => {
        if (button === Qt.RightButton)
            alternate = !alternate;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Timer {
        id: show_timer
        interval: root.showDelayMilliseconds
        onTriggered: {
            if (root.hovered && root.visible)
                calendar_card.visible = true;
        }
    }

    Timer {
        id: hide_timer
        interval: root.hideDelayMilliseconds
        onTriggered: {
            if (!root.hovered && !calendar_card.hovered)
                calendar_card.visible = false;
        }
    }

    ClockCalendarCard {
        id: calendar_card
        anchorItem: root
        currentDate: clock.date
        holidayService: root.holidayService
        screen: root.screen
        onHoveredChanged: root.update_calendar_visibility()
    }
}
