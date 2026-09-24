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

    readonly property string screenName: modelData.name

    screen: modelData
    color: Theme.surface
    exclusiveZone: Style.barExclusive ? Style.barWidth : 0
    implicitWidth: Style.barWidth

    anchors {
        top: true
        bottom: true
        left: Style.barOnLeft
        right: !Style.barOnLeft
    }

    WlrLayershell.namespace: "vjshell-bar"

    Divider {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: Style.barOnLeft ? undefined : parent.left
        anchors.right: Style.barOnLeft ? parent.right : undefined
        vertical: true
    }

    Flickable {
        id: scrolling

        anchors.fill: parent
        anchors.topMargin: Style.barPadding
        anchors.bottomMargin: Style.barPadding
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column

            width: parent.width
            height: Math.max(implicitHeight, scrolling.height)
            spacing: Style.groupSpacing

            Logo {}

            Places {
                Layout.alignment: Qt.AlignHCenter
                screenName: root.screenName
            }

            Item {
                Layout.fillHeight: true
            }

            Call {
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Style.barWidth - Style.barInset * 2
                implicitHeight: cluster.implicitHeight + Style.buttonGap * 2
                radius: width / 2
                color: Theme.surfaceContainer

                ColumnLayout {
                    id: cluster

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.buttonGap

                    Agents {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    NotificationBell {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    BarButton {
                        Layout.alignment: Qt.AlignHCenter
                        visible: RecorderService.recording
                        icon: Icons.screenShare
                        iconColor: Theme.error
                        iconFill: 1
                        tooltip: "Stop recording"
                        onClicked: RecorderService.stop()
                    }

                    Volume {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Mic {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    LyricsButton {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    BarButton {
                        readonly property bool open: PanelService.isOpen("devices", root.screenName)

                        Layout.alignment: Qt.AlignHCenter
                        icon: Icons.devices
                        iconColor: open ? Theme.primary : Theme.inkSurfaceVariant
                        iconFill: open ? 1 : 0
                        tooltip: DeviceService.text("devices")
                        onClicked: PanelService.toggle("devices", root.screenName)
                    }

                    BarButton {
                        readonly property bool open: PanelService.isOpen("vr", root.screenName)

                        Layout.alignment: Qt.AlignHCenter
                        visible: VrService.enabled
                        icon: Icons.vr
                        iconColor: VrService.connected ? Theme.success : open ? Theme.primary : Theme.inkSurfaceVariant
                        iconFill: VrService.connected || open ? 1 : 0
                        tooltip: VrService.text("vr")
                        onClicked: PanelService.toggle("vr", root.screenName)
                    }

                    KeyboardLayout {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Clock {
                        Layout.alignment: Qt.AlignHCenter
                    }

                    SysTray {
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
