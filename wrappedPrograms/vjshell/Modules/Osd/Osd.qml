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

    readonly property bool showingYtMusic: source === "ytmusic"
    readonly property int contentHeight: showingYtMusic ? Style.osdHeight + 18 : Style.osdHeight

    property string source: "system"

    implicitWidth: Style.osdWidth + Style.surfacePad * 2
    implicitHeight: contentHeight + Style.surfacePad * 2
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-osd"

    mask: Region {}

    Connections {
        target: AudioService
        function onOsdRequested() {
            root.source = "system";
            hideTimer.restart();
        }
    }

    Connections {
        target: YtMusicAudioService
        function onOsdRequested() {
            root.source = "ytmusic";
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
        height: root.contentHeight

        level: 3
        radius: Style.radiusL

        opacity: reveal.progress
        scale: 0.90 + 0.10 * reveal.progress
        transformOrigin: Item.Bottom

        transform: Translate {
            y: 12 * (1 - reveal.progress)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.panelPadding
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.panelPadding

                MaterialIcon {
                    text: {
                        if (root.showingYtMusic)
                            return Icons.musicNote;
                        if (AudioService.muted)
                            return Icons.volumeMuted;
                        if (AudioService.volume < 0.34)
                            return Icons.volumeLow;
                        if (AudioService.volume < 0.67)
                            return Icons.volumeMedium;
                        return Icons.volumeHigh;
                    }
                    font.pixelSize: Style.iconSizeL
                    color: (!root.showingYtMusic && AudioService.muted) ? Theme.urgent : Theme.text
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Theme.surfaceHigh

                    Rectangle {
                        width: parent.width * (root.showingYtMusic ? YtMusicAudioService.volume : (AudioService.muted ? 0 : AudioService.volume))
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
                    text: Math.round((root.showingYtMusic ? YtMusicAudioService.volume : AudioService.volume) * 100)
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    color: Theme.textDim
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                visible: root.showingYtMusic
                text: "YouTube Music"
                horizontalAlignment: Text.AlignHCenter
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                color: Theme.textDim
            }
        }
    }
}
