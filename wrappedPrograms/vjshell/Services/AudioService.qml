pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    signal osdRequested()

    readonly property int step: 5

    function setVolume(fraction) {
        if (!sink?.ready)
            return;
        sink.audio.volume = Math.max(0, Math.min(1, fraction));
    }

    function stepVolume(percent) {
        setVolume(volume + percent / 100);
    }

    function toggleMute() {
        if (sink?.ready)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMicMute() {
        if (source?.ready)
            source.audio.muted = !source.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    property bool settled: false

    Timer {
        running: true
        interval: 1000
        onTriggered: root.settled = true
    }

    onVolumeChanged: if (settled)
        osdRequested()
    onMutedChanged: if (settled)
        osdRequested()
}
