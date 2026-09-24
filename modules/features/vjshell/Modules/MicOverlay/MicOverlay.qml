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
    color: "transparent"
    exclusiveZone: 0
    aboveWindows: true
    implicitWidth: Style.touchTarget + Style.panelPadding
    implicitHeight: Style.touchTarget + Style.panelPadding
    anchors.bottom: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-mic-overlay"

    mask: Region {}

    Reveal {
        id: reveal
        open: AudioService.micMuted
    }

    Rectangle {
        anchors.centerIn: parent
        width: Style.iconButtonSize
        height: width
        radius: width / 2
        color: Theme.errorContainer
        opacity: reveal.progress
        scale: 0.8 + 0.2 * reveal.progress

        MaterialIcon {
            anchors.centerIn: parent
            text: Icons.micOff
            font.pixelSize: Style.iconSizeXl
            fill: 1
            color: Theme.inkErrorContainer
        }
    }
}
