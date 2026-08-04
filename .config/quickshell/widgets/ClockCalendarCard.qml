import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components/JapaneseHolidays.js" as JapaneseHolidays
import "../components/Theme.js" as Theme

PopupWindow {
    id: root

    required property var anchorItem
    required property date currentDate
    required property var holidayService
    required property var screen
    property alias hovered: card_hover_handler.hovered

    property int displayYear: currentDate.getFullYear()
    property int displayMonth: currentDate.getMonth()
    property string hoveredHolidayName: ""

    readonly property int cardWidth: 304
    readonly property int cardHeight: 304
    readonly property int cardMargin: 6
    readonly property int cardPadding: 12
    readonly property int headerHeight: 34
    readonly property int weekdayHeight: 22
    readonly property int dayCellHeight: 29
    readonly property int dayColumnCount: 7
    readonly property int dayCellCount: 42
    readonly property int navigationButtonSize: 28
    readonly property int holidayLabelHeight: 20
    readonly property var weekdayLabels: ["日", "月", "火", "水", "木", "金", "土"]
    readonly property var calculatedHolidays: JapaneseHolidays.holidays_for_year(displayYear)

    implicitWidth: cardWidth
    implicitHeight: cardHeight
    visible: false
    color: "transparent"

    anchor.item: anchorItem
    anchor.rect.x: horizontal_offset()
    anchor.rect.y: anchorItem ? anchorItem.height + cardMargin : 0

    onVisibleChanged: {
        if (visible)
            reset_to_current_month();
    }

    function horizontal_offset(): real {
        // カードを時計の中央に置き、画面外へのはみ出しだけを補正する。アンカーからのX座標を返し、副作用はない。
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

    function reset_to_current_month(): void {
        // 再表示したカレンダーを必ず今月へ戻す。戻り値はなく、表示年月を更新する。
        displayYear = currentDate.getFullYear();
        displayMonth = currentDate.getMonth();
        hoveredHolidayName = "";
    }

    function change_month(offset: int): void {
        // 指定された月数だけ表示月を進め、年越しもDateに委ねる。戻り値はなく、表示年月を更新する。
        const target_date = new Date(displayYear, displayMonth + offset, 1);
        displayYear = target_date.getFullYear();
        displayMonth = target_date.getMonth();
        hoveredHolidayName = "";
    }

    function day_for_cell(cell_index: int): int {
        // 6週固定グリッドのセルに対応する日を返し、対象月外は0を返す。副作用はない。
        const first_weekday = new Date(displayYear, displayMonth, 1).getDay();
        const days_in_month = new Date(displayYear, displayMonth + 1, 0).getDate();
        const day_number = cell_index - first_weekday + 1;
        return day_number >= 1 && day_number <= days_in_month ? day_number : 0;
    }

    function is_today(day_number: int): bool {
        // 表示中の日がローカル時間の今日かを返す。副作用はない。
        return day_number > 0
            && displayYear === currentDate.getFullYear()
            && displayMonth === currentDate.getMonth()
            && day_number === currentDate.getDate();
    }

    function weekday_color(weekday_index: int): color {
        // 日曜と土曜だけを色分けし、平日は通常の前景色を返す。副作用はない。
        if (weekday_index === 0)
            return Theme.calendarSunday;
        if (weekday_index === dayColumnCount - 1)
            return Theme.calendarSaturday;
        return Theme.foreground;
    }

    function holiday_name(day_number: int): string {
        // 公式キャッシュを優先して祝日名を返し、未収録年だけローカル計算へ戻る。副作用はない。
        if (day_number <= 0)
            return "";
        if (holidayService.has_year(displayYear))
            return holidayService.holiday_name(displayYear, displayMonth + 1, day_number);
        return JapaneseHolidays.holiday_name(
            calculatedHolidays,
            displayYear,
            displayMonth + 1,
            day_number
        );
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius * 2
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.border

        HoverHandler {
            // 月送りボタンの入力を妨げず、カード全体のホバー状態を保持する。
            id: card_hover_handler
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.cardPadding
            spacing: 3

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.headerHeight

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.navigationButtonSize
                    height: root.navigationButtonSize
                    radius: width / 2
                    color: previous_mouse_area.containsMouse ? Theme.purple : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: Theme.foreground
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: previous_mouse_area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.change_month(-1)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.displayYear + "年" + (root.displayMonth + 1) + "月"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.weight: Theme.fontWeight
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.navigationButtonSize
                    height: root.navigationButtonSize
                    radius: width / 2
                    color: next_mouse_area.containsMouse ? Theme.purple : Theme.surface

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: Theme.foreground
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: next_mouse_area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.change_month(1)
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: root.weekdayHeight
                columns: root.dayColumnCount
                columnSpacing: 2
                rowSpacing: 0

                Repeater {
                    model: root.weekdayLabels

                    delegate: Text {
                        required property int index
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: root.weekdayHeight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: root.weekday_color(index)
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Theme.fontWeight
                        renderType: Text.NativeRendering
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: root.dayColumnCount
                columnSpacing: 2
                rowSpacing: 2

                Repeater {
                    model: root.dayCellCount

                    delegate: CalendarDayCell {
                        id: day_cell

                        required property int index
                        dayNumber: root.day_for_cell(index)
                        weekdayIndex: index % root.dayColumnCount
                        today: root.is_today(dayNumber)
                        holidayName: root.holiday_name(dayNumber)
                        weekdayColor: root.weekday_color(weekdayIndex)
                        cellHeight: root.dayCellHeight
                        onHolidayEntered: name => root.hoveredHolidayName = name
                        onHolidayExited: name => {
                            if (root.hoveredHolidayName === name)
                                root.hoveredHolidayName = "";
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: root.holidayLabelHeight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.hoveredHolidayName
                color: Theme.calendarSunday
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
                renderType: Text.NativeRendering
            }
        }
    }
}
