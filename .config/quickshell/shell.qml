import Quickshell
import QtQuick
import "services" as Services
import "widgets" as Widgets

ShellRoot {
    // 画面ごとに重複させたくない監視処理は、ここで一度だけ生成する。
    Services.SystemStatsService { id: systemStats }
    Services.DiskService { id: disk }
    Services.NetworkStatsService { id: networkStats }
    Services.SpotifyService { id: spotify }
    Services.HolidayService { id: holidays }

    Variants {
        // 接続中の各モニターに同じバーを1つずつ配置する。
        model: Quickshell.screens

        delegate: Component {
            Widgets.Bar {
                required property var modelData

                screen: modelData
                systemStatsService: systemStats
                diskService: disk
                networkStatsService: networkStats
                spotifyService: spotify
                holidayService: holidays
            }
        }
    }
}
