import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    visible: reveal.active

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-mic-overlay"
    aboveWindows: true

    implicitWidth: 50
    implicitHeight: 50
    anchors.bottom: true
    exclusiveZone: 0

    color: "transparent"

    mask: Region {}

    Reveal {
        id: reveal
        open: AudioService.micMuted
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: Icons.micOff
        font.pixelSize: 24
        color: Theme.urgent

        opacity: reveal.progress
        scale: 0.80 + 0.20 * reveal.progress
        transformOrigin: Item.Center
    }
}
