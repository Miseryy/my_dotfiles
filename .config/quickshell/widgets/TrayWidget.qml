import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../components/Theme.js" as Theme

Item {
    id: root

    // passive項目も含め、StatusNotifierItemをWaybarと同じく横並びにする。
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.pillHeight
    visible: SystemTray.items && SystemTray.items.values && SystemTray.items.values.length > 0

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.barBackground
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 10

        Repeater {
            model: SystemTray.items && SystemTray.items.values ? SystemTray.items.values : []

            delegate: Item {
                id: trayItem

                required property var modelData

                Layout.preferredWidth: 21
                Layout.preferredHeight: Theme.pillHeight

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 21
                    source: trayItem.modelData.icon
                }

                QsMenuAnchor {
                    id: menuAnchor

                    menu: trayItem.modelData.menu
                    anchor.item: trayItem
                    anchor.edges: Edges.Bottom | Edges.Left
                    anchor.gravity: Edges.Bottom | Edges.Right
                }

                MouseArea {
                    // 操作はトレイ項目自身へ転送し、アプリ固有の挙動を維持する。
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton && !trayItem.modelData.onlyMenu) {
                            trayItem.modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            trayItem.modelData.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                            menuAnchor.open();
                        }
                    }
                    onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }
}
