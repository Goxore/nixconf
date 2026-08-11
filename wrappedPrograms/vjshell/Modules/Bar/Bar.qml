import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property string screenName: modelData.name

    screen: modelData

    anchors {
        top: true
        bottom: true
        left: Style.barOnLeft
        right: !Style.barOnLeft
    }
    exclusiveZone: Style.barExclusive ? Style.barWidth : 0

    implicitWidth: Style.barWidth
    color: Theme.surface

    WlrLayershell.namespace: "vjshell-bar"

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: Style.barOnLeft ? undefined : parent.left
        anchors.right: Style.barOnLeft ? parent.right : undefined
        width: Style.dividerWidth
        color: Theme.surfaceVariant
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Style.barPadding
        anchors.bottomMargin: Style.barPadding
        spacing: Style.groupSpacing

        Logo {}

        Projects {
            Layout.alignment: Qt.AlignHCenter
        }

        Workspaces {
            Layout.alignment: Qt.AlignHCenter
            screenName: root.screenName
        }

        Item {
            Layout.fillHeight: true
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Style.barWidth - Style.barInset * 2
            implicitHeight: cluster.implicitHeight + Style.spacing * 4

            Rectangle {
                anchors.fill: parent
                radius: Style.radiusL
                color: Theme.surfaceVariant
            }

            ColumnLayout {
                id: cluster

                x: 0
                y: Style.spacing * 2
                width: Style.barWidth - Style.barInset * 2
                spacing: Style.spacing * 2

                NotificationBell {
                    Layout.alignment: Qt.AlignHCenter
                }

                Volume {
                    Layout.alignment: Qt.AlignHCenter
                }

                Mic {
                    Layout.alignment: Qt.AlignHCenter
                }

                KeyboardLayout {
                    Layout.alignment: Qt.AlignHCenter
                    screenName: root.screenName
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
