import Quickshell
import Quickshell.Networking
import QtQuick
import "../components" as Components
import "../components/Theme.js" as Theme

Components.BarPill {
    id: root

    // 接続状態はQuickshell API、IPと通信量は共有サービスから取得する。
    required property var statsService

    readonly property var devices: Networking.devices && Networking.devices.values
        ? Networking.devices.values : []
    readonly property var activeDevice: devices.find(device => device && device.connected) || null
    readonly property var activeNetwork: {
        // Wi-Fiの場合は接続中のSSIDをデバイス配下から探す。
        if (!activeDevice || !activeDevice.networks || !activeDevice.networks.values)
            return null;
        return activeDevice.networks.values.find(network => network && network.connected) || null;
    }
    readonly property bool wireless: activeNetwork && activeNetwork.signalStrength !== undefined
    readonly property int strength: wireless ? Math.round(activeNetwork.signalStrength * 100) : 0
    readonly property string icon: !activeDevice ? "󰖪"
        : !wireless ? "󰀂"
        : strength < 20 ? "󰤯" : strength < 40 ? "󰤟"
        : strength < 60 ? "󰤢" : strength < 80 ? "󰤥" : "󰤨"

    text: !activeDevice ? icon : icon + (statsService.address ? " " + statsService.address : "")
    tooltipText: !activeDevice ? "Disconnected"
        : (activeNetwork ? activeNetwork.name : activeDevice.name) +
          "\nInterface: " + (statsService.interfaceName || activeDevice.name) +
          "\n⇣ " + statsService.download + "  ⇡ " + statsService.upload
    backgroundColor: Theme.green
    foregroundColor: Theme.foreground

    onClicked: button => {
        if (button === Qt.LeftButton || button === Qt.RightButton)
            Quickshell.execDetached(["kitty", "--class", "nmtui", "-e", "nmtui"]);
    }
}
