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

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Style.barPadding
        anchors.bottomMargin: Style.barPadding
        spacing: Style.groupSpacing

        Logo {}

        Workspaces {
            Layout.alignment: Qt.AlignHCenter
            screenName: root.screenName
        }

        Item {
            Layout.fillHeight: true
        }

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
