import Quickshell.WindowManager
import QtQuick
import QtQuick.Layouts
import "../components" as Components
import "../components/Theme.js" as Theme

Item {
    id: root

    // 対象画面に属するNiriのワークスペースだけを取得する。
    required property var screen
    readonly property var projection: WindowManager.screenProjection(screen)

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.pillHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.moduleSpacing

        Repeater {
            // 非表示指定のワークスペースはレイアウトからも除外する。
            model: root.projection.windowsets

            delegate: Components.BarPill {
                required property var modelData

                visible: modelData.shouldDisplay
                text: modelData.name !== "" ? modelData.name
                    : modelData.coordinates.length > 0 ? String(modelData.coordinates[0]) : "•"
                horizontalPadding: 12
                backgroundColor: modelData.urgent ? Theme.urgent
                    : modelData.active ? Theme.activeWorkspaceBackground
                    : Theme.workspaceBackground
                foregroundColor: modelData.active ? Theme.activeWorkspaceForeground
                    : Theme.workspaceForeground
                tooltipText: "Workspace " + text
                onClicked: button => {
                    if (button === Qt.LeftButton)
                        modelData.activate();
                }
            }
        }
    }
}
