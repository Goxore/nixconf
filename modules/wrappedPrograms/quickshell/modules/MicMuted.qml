import QtQuick 2.15
import Quickshell.Services.Pipewire

Text {
    readonly property var source: Pipewire.defaultAudioSource

    anchors.horizontalCenter: parent.horizontalCenter

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource]
    }

    color: Pipewire.defaultAudioSource?.audio.muted ? "#fb4934" : "#b8bb26"
    text: Pipewire.defaultAudioSource?.audio.muted ? "" : ""
}
