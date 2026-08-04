import QtQuick
import QtQuick.Layouts
import "../components/Theme.js" as Theme

Rectangle {
    id: root

    required property int dayNumber
    required property int weekdayIndex
    required property bool today
    required property string holidayName
    required property color weekdayColor
    required property int cellHeight

    signal holidayEntered(string name)
    signal holidayExited(string name)

    Layout.fillWidth: true
    Layout.preferredHeight: cellHeight
    radius: Theme.radius
    color: today ? Theme.activeWorkspaceBackground : "transparent"

    Text {
        anchors.centerIn: parent
        text: root.dayNumber > 0 ? String(root.dayNumber) : ""
        color: root.today
            ? Theme.activeWorkspaceForeground
            : root.holidayName.length > 0
                ? Theme.calendarSunday
                : root.weekdayColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
        font.weight: root.today ? Theme.fontWeight : Font.Normal
        renderType: Text.NativeRendering
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.holidayName.length > 0
        width: 3
        height: 3
        radius: 2
        color: root.today
            ? Theme.activeWorkspaceForeground
            : Theme.calendarSunday
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.dayNumber > 0
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.holidayEntered(root.holidayName)
        onExited: root.holidayExited(root.holidayName)
    }
}
