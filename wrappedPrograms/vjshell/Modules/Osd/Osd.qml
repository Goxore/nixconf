import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData

    property string kind: "volume"

    screen: modelData
    visible: hideTimer.running

    anchors {
        bottom: true
    }
    margins.bottom: 80
    exclusiveZone: 0

    implicitWidth: 260
    implicitHeight: 56
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-osd"

    mask: Region {}

    Connections {
        target: AudioService
        function onOsdRequested(kind) {
            root.kind = kind;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 2000
    }

    Rectangle {
        anchors.fill: parent
        radius: Style.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.surfaceHigh

        RowLayout {
            anchors.fill: parent
            anchors.margins: Style.panelPadding
            spacing: Style.panelPadding

            MaterialIcon {
                text: {
                    if (root.kind === "mic")
                        return AudioService.micMuted ? Icons.micOff : Icons.micOn;
                    if (AudioService.muted)
                        return Icons.volumeMuted;
                    if (AudioService.volume < 0.34)
                        return Icons.volumeLow;
                    if (AudioService.volume < 0.67)
                        return Icons.volumeMedium;
                    return Icons.volumeHigh;
                }
                font.pixelSize: Style.iconSize + 4
                color: {
                    if (root.kind === "mic")
                        return AudioService.micMuted ? Theme.urgent : Theme.active;
                    return AudioService.muted ? Theme.urgent : Theme.text;
                }
            }

            Text {
                visible: root.kind === "mic"
                Layout.fillWidth: true
                text: AudioService.micMuted ? "Microphone muted" : "Microphone live"
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                color: Theme.text
            }

            Rectangle {
                visible: root.kind !== "mic"
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.surfaceHigh

                Rectangle {
                    width: parent.width * (AudioService.muted ? 0 : AudioService.volume)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Style.animFast
                        }
                    }
                }
            }

            Text {
                visible: root.kind !== "mic"
                text: Math.round(AudioService.volume * 100)
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                color: Theme.textDim
            }
        }
    }
}
