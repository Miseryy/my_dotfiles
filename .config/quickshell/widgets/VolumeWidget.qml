import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../components" as Components
import "../components/Theme.js" as Theme

Components.BarPill {
    id: root

    // PipeWireのデフォルト出力を直接監視するため、音量変化はポーリング不要。
    readonly property var sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property int percent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: !sink || !sink.audio || sink.audio.muted

    text: muted ? "X" : percent + "% " + (percent < 35 ? "" : "")
    tooltipText: sink ? (sink.name || "Default audio output") + "\nVolume: " + percent + "%" : "No audio output"
    backgroundColor: Theme.red
    foregroundColor: Theme.foreground

    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached(["pavucontrol"]);
        else if ((button === Qt.MiddleButton || button === Qt.RightButton) && sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    onWheel: delta => {
        if (!sink || !sink.audio)
            return;
        const next = sink.audio.volume + (delta > 0 ? 0.01 : -0.01);
        sink.audio.volume = Math.max(0, Math.min(1.5, next));
    }

    PwObjectTracker {
        // sink.audioの音量・ミュート変更をQMLへ通知させる。
        objects: root.sink ? [root.sink] : []
    }
}
