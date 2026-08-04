import Quickshell.Bluetooth
import QtQuick
import "../components" as Components
import "../components/Theme.js" as Theme

Components.BarPill {
    id: root

    // 先頭の接続機器をバーへ表示し、全機器の情報は内部で保持する。
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: adapter && adapter.devices && adapter.devices.values
        ? adapter.devices.values.filter(device => device && device.connected) : []
    readonly property var primaryDevice: connectedDevices.length > 0 ? connectedDevices[0] : null

    visible: adapter !== null
    text: !adapter || !adapter.enabled ? " Off"
        : primaryDevice ? " " + primaryDevice.name + batteryText(primaryDevice)
        : " On"
    tooltipText: !adapter ? "Bluetooth adapter unavailable"
        : adapter.name + "\n" + connectedDevices.length + " connected" + deviceDetails()
    backgroundColor: Theme.green
    foregroundColor: Theme.foreground

    function batteryText(device): string {
        return device && device.batteryAvailable ? " " + Math.round(device.battery * 100) + "%" : "";
    }

    function deviceDetails(): string {
        if (connectedDevices.length === 0)
            return "";
        return "\n\n" + connectedDevices.map(device => device.name + batteryText(device)).join("\n");
    }

    onClicked: button => {
        // 外部シェルスクリプトを使わずBlueZ APIで直接電源を切り替える。
        if (button === Qt.LeftButton && adapter)
            adapter.enabled = !adapter.enabled;
    }
}
