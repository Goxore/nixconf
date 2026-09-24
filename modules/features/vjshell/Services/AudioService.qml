pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property int percent: Math.round(volume * 100)
    readonly property int step: 5

    readonly property string volumeIcon: {
        if (muted)
            return Icons.volumeMuted;
        if (volume < 0.34)
            return Icons.volumeLow;
        if (volume < 0.67)
            return Icons.volumeMedium;
        return Icons.volumeHigh;
    }

    signal changed

    function setVolume(fraction) {
        if (sink?.ready)
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

    onVolumeChanged: changed()
    onMutedChanged: changed()

    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
