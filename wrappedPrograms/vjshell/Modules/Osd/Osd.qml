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

    screen: modelData
    visible: reveal.active

    anchors {
        bottom: true
    }
    margins.bottom: Style.osdMargin - Style.surfacePad
    exclusiveZone: 0

    implicitWidth: Style.osdWidth + Style.surfacePad * 2
    implicitHeight: Style.osdHeight + Style.surfacePad * 2
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-osd"

    mask: Region {}

    Connections {
        target: AudioService
        function onOsdRequested() {
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 2000
    }

    Reveal {
        id: reveal
        open: hideTimer.running
    }

    Surface {
        anchors.centerIn: parent
        width: Style.osdWidth
        height: Style.osdHeight

        level: 3
        radius: Style.radiusL

        opacity: reveal.progress
        scale: 0.90 + 0.10 * reveal.progress
        transformOrigin: Item.Bottom

        transform: Translate {
            y: 12 * (1 - reveal.progress)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Style.panelPadding
            spacing: Style.panelPadding

            MaterialIcon {
                text: {
                    if (AudioService.muted)
                        return Icons.volumeMuted;
                    if (AudioService.volume < 0.34)
                        return Icons.volumeLow;
                    if (AudioService.volume < 0.67)
                        return Icons.volumeMedium;
                    return Icons.volumeHigh;
                }
                font.pixelSize: Style.iconSizeL
                color: AudioService.muted ? Theme.urgent : Theme.text
            }

            Rectangle {
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
                            duration: Style.durShort3
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Style.standard
                        }
                    }
                }
            }

            Text {
                text: Math.round(AudioService.volume * 100)
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                color: Theme.textDim
            }
        }
    }
}
