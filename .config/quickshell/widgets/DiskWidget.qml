import "../components" as Components
import "../components/Theme.js" as Theme

Components.BarPill {
    // 容量取得は全画面共通のDiskServiceに集約する。
    required property var service

    text: "🖴 Disk: " + service.usedPercent + " used"
    tooltipText: service.tooltip
    backgroundColor: Theme.orange
    foregroundColor: Theme.foreground
    interactive: false
}
