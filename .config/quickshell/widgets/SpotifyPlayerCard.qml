import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components/Theme.js" as Theme

PopupWindow {
    id: root

    required property var anchorItem
    required property var screen
    required property var service
    property alias hovered: card_hover_handler.hovered

    readonly property int cardWidth: 280
    readonly property int cardHeight: 96
    readonly property int cardMargin: 6
    readonly property int cardPadding: 12
    readonly property int coverSize: 72
    readonly property int controlSize: 28
    readonly property int controlSpacing: 8

    implicitWidth: cardWidth
    implicitHeight: cardHeight
    visible: false
    color: "transparent"

    anchor.item: anchorItem
    anchor.rect.x: horizontal_offset()
    anchor.rect.y: anchorItem ? anchorItem.height + cardMargin : 0

    function horizontal_offset(): real {
        // カードを対象の中央に置き、画面外へのはみ出しだけを補正する。アンカーからのX座標を返し、副作用はない。
        if (!anchorItem || !screen)
            return 0;

        const centered_offset = (anchorItem.width - cardWidth) / 2;
        const global_position = anchorItem.mapToGlobal(centered_offset, 0);
        const minimum_x = screen.x + cardMargin;
        const maximum_x = screen.x + screen.width - cardWidth - cardMargin;
        if (global_position.x < minimum_x)
            return centered_offset + minimum_x - global_position.x;
        if (global_position.x > maximum_x)
            return centered_offset - (global_position.x - maximum_x);
        return centered_offset;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius * 2
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.border

        HoverHandler {
            // 操作ボタンの入力を妨げず、カード全体のホバー状態を保持する。
            id: card_hover_handler
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.cardPadding
            spacing: root.cardPadding

            Rectangle {
                Layout.preferredWidth: root.coverSize
                Layout.preferredHeight: root.coverSize
                radius: Theme.radius
                color: Theme.spotify
                clip: true

                Image {
                    id: cover_image
                    anchors.fill: parent
                    source: root.service.coverUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: cover_image.status !== Image.Ready
                    text: ""
                    color: Theme.foregroundMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    renderType: Text.NativeRendering
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.service.title
                    color: Theme.foreground
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: Theme.fontWeight
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    text: root.service.artist
                    color: Theme.foregroundMuted
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    renderType: Text.NativeRendering
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: root.controlSpacing

                    Repeater {
                        model: [
                            { "action": "previous", "icon": "", "label": "前の曲" },
                            {
                                "action": "toggle",
                                "icon": root.service.isPlaying ? "" : "",
                                "label": root.service.isPlaying ? "一時停止" : "再生"
                            },
                            { "action": "next", "icon": "", "label": "次の曲" }
                        ]

                        delegate: Rectangle {
                            id: control_button

                            required property var modelData

                            Layout.preferredWidth: root.controlSize
                            Layout.preferredHeight: root.controlSize
                            radius: root.controlSize / 2
                            color: control_mouse_area.containsMouse
                                ? Theme.spotify
                                : Theme.surface

                            Text {
                                anchors.centerIn: parent
                                text: control_button.modelData.icon
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 2
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: control_mouse_area
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.service.control(control_button.modelData.action)
                            }
                        }
                    }
                }
            }
        }
    }
}
