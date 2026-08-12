import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    visible: AudioService.micMuted

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-mic-overlay"
    aboveWindows: true

    width: 50
    height: 50
    anchors.bottom: true
    exclusiveZone: 0

    color: "transparent"

    MaterialIcon {
        anchors.centerIn: parent
        text: Icons.micOff
        font.pixelSize: 24
        color: Theme.urgent
    }
}
