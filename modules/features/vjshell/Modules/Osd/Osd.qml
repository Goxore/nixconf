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

    property string source: "system"
    property bool armed: false

    readonly property bool ytMusic: source === "ytmusic"
    readonly property real level: ytMusic ? YtMusicAudioService.volume : AudioService.volume
    readonly property bool muted: !ytMusic && AudioService.muted

    function show(from) {
        if (!armed)
            return;
        source = from;
        hideTimer.restart();
    }

    screen: modelData
    visible: reveal.active
    color: "transparent"
    exclusiveZone: 0

    anchors.bottom: true
    margins.bottom: Style.osdMargin - Style.surfacePad

    implicitWidth: Style.osdWidth + Style.surfacePad * 2
    implicitHeight: box.height + Style.surfacePad * 2

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-osd"

    mask: Region {}

    Connections {
        target: AudioService
        function onChanged() {
            root.show("system");
        }
    }

    Connections {
        target: YtMusicAudioService
        function onChanged() {
            root.show("ytmusic");
        }
    }

    Timer {
        running: true
        interval: Style.osdSettle
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: Style.osdTimeout
    }

    Reveal {
        id: reveal
        open: hideTimer.running
    }

    Surface {
        id: box

        anchors.centerIn: parent
        width: Style.osdWidth
        height: column.implicitHeight + Style.groupSpacing * 2

        level: 3
        radius: height / 2
        color: Theme.surfaceContainer

        opacity: reveal.progress
        scale: 0.9 + 0.1 * reveal.progress
        transformOrigin: Item.Bottom

        transform: Translate {
            y: 12 * (1 - reveal.progress)
        }

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.panelPadding + Style.spacing
            anchors.rightMargin: Style.panelPadding + Style.spacing
            spacing: Style.spacing

            Label {
                Layout.fillWidth: true
                visible: root.ytMusic
                text: "YouTube Music"
                role: "labelMedium"
                color: Theme.inkSurfaceVariant
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.groupSpacing

                MaterialIcon {
                    text: root.ytMusic ? Icons.musicNote : AudioService.volumeIcon
                    font.pixelSize: Style.iconSizeXl
                    fill: 1
                    color: root.muted ? Theme.error : Theme.primary
                }

                LinearProgress {
                    Layout.fillWidth: true
                    implicitHeight: Style.osdTrack
                    value: root.level
                    color: root.muted ? Theme.error : Theme.primary
                }

                Label {
                    Layout.minimumWidth: Style.osdValueWidth
                    text: Math.round(root.level * 100) + "%"
                    role: "labelLarge"
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
