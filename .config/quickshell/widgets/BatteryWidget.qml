import Quickshell.Services.UPower
import QtQuick
import "../components" as Components
import "../components/Theme.js" as Theme

Components.BarPill {
    id: root

    // UPowerの集約バッテリーを使い、搭載されていない環境では非表示にする。
    readonly property var battery: UPower.displayDevice
    readonly property bool ready: battery && battery.ready && battery.isPresent
    readonly property int percent: ready ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: ready && battery.state === UPowerDeviceState.Charging
    readonly property bool full: ready && battery.state === UPowerDeviceState.FullyCharged
    readonly property string icon: charging ? "󰂄" : percent < 10 ? "󰁺"
        : percent < 20 ? "󰁻" : percent < 30 ? "󰁼" : percent < 40 ? "󰁽"
        : percent < 50 ? "󰁾" : percent < 60 ? "󰁿" : percent < 70 ? "󰂀"
        : percent < 80 ? "󰂁" : percent < 90 ? "󰂂" : "󰁹"

    visible: ready
    text: full ? "Charged " : percent + "% " + icon + timeText()
    tooltipText: ready ? "Battery: " + percent + "%" +
        (battery.healthSupported ? "\nHealth: " + Math.round(battery.healthPercentage) + "%" : "") : "No battery detected"
    backgroundColor: charging ? Theme.green : percent <= 20 ? Theme.red : Theme.urgent
    foregroundColor: Theme.foreground
    interactive: false

    function timeText(): string {
        // 状態に応じて満充電まで、または空になるまでの時間を表示する。
        const seconds = charging ? battery.timeToFull : battery.timeToEmpty;
        if (!seconds || seconds <= 0)
            return "";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return " " + hours + ":" + String(minutes).padStart(2, "0");
    }
}
