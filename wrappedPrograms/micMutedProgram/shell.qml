import QtQuick 2.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            screen: modelData

            WlrLayershell.layer: WlrLayer.Overlay
            aboveWindows: true

            width: 50
            height: 50

            anchors.bottom: true
            exclusiveZone: 0

            color: "transparent"

            PwObjectTracker {
                objects: [Pipewire.defaultAudioSource]
            }

            Text {
                anchors.centerIn: parent

                font.pixelSize: 24
                color: Pipewire.defaultAudioSource?.audio.muted ? "#fb4934" : "transparent"

                text: Pipewire.defaultAudioSource?.audio.muted ? "" : ""
            }
        }
    }
}
