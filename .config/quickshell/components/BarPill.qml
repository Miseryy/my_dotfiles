import QtQuick
import "Theme.js" as Theme

Item {
    id: root

    // 全モジュール共通のカプセル。表示内容と操作だけを各機能から受け取る。
    property alias text: label.text
    property color backgroundColor: Theme.barBackground
    property color foregroundColor: Theme.foreground
    property string tooltipText: ""
    property int horizontalPadding: Theme.horizontalPadding
    property int fontPixelSize: Theme.fontSize
    property bool interactive: true
    property alias hovered: hover_handler.hovered

    signal clicked(int button)
    signal wheel(int delta)

    HoverHandler {
        // クリックを奪わず、ホバー表示が必要なウィジェットへ状態だけを公開する。
        id: hover_handler
        enabled: root.interactive
    }

    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: Theme.pillHeight

    Rectangle {
        // 背景と境界線を一か所で描画し、各ウィジェットの見た目を統一する。
        anchors.fill: parent
        radius: Theme.radius
        color: root.backgroundColor
        border.width: 1
        border.color: Theme.border

        Text {
            id: label
            anchors.centerIn: parent
            color: root.foregroundColor
            font.family: Theme.fontFamily
            font.pixelSize: root.fontPixelSize
            font.weight: Theme.fontWeight
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        // ボタン種別とホイール量を呼び出し元へ渡し、機能固有処理は持たない。
        anchors.fill: parent
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => root.clicked(mouse.button)
        onWheel: wheel => root.wheel(wheel.angleDelta.y)
    }
}
