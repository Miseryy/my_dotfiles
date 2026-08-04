import "../components" as Components
import "../components/Theme.js" as Theme

Components.BarPill {
    // サービスが3秒ごとにCPU・温度・メモリを切り替える。
    required property var service

    text: service.text
    tooltipText: service.tooltip
    foregroundColor: Theme.foreground
    backgroundColor: service.state === "memory" ? Theme.cyan
        : service.state === "temperature-warning" ? Theme.warning
        : service.state === "temperature-critical" || service.state === "temperature-unavailable"
            ? Theme.red : Theme.green
    interactive: false
}
