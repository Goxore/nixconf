import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

Pressable {
    id: root

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""
    readonly property bool open: PanelService.isOpen("calendar", screenName)
    readonly property color timeColor: open ? Theme.primary : Theme.inkSurface

    implicitWidth: Style.itemSize
    implicitHeight: column.implicitHeight + Style.buttonGap * 2

    description: Qt.formatDateTime(clock.date, "dddd d MMMM, HH:mm")
    cornerRadius: Style.radiusS

    onClicked: PanelService.toggle("calendar", screenName)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        spacing: 0
        scale: root.pressed ? Style.pressScale : 1

        Behavior on scale {
            NumberMotion {
                duration: Style.durShort2
            }
        }

        Line {
            text: Qt.formatDateTime(clock.date, "HH")
            color: root.timeColor
        }

        Line {
            text: Qt.formatDateTime(clock.date, "mm")
            color: root.timeColor
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Style.spacing
            Layout.bottomMargin: Style.spacing
            implicitWidth: Style.clockRule
            implicitHeight: Style.dividerWidth * 2
            radius: height / 2
            color: Theme.outlineVariant
        }

        Line {
            text: Qt.formatDateTime(clock.date, "dd")
            color: Theme.inkSurfaceVariant
        }

        Line {
            text: Qt.formatDateTime(clock.date, "MM")
            color: Theme.outline
        }
    }

    component Line: Label {
        Layout.alignment: Qt.AlignHCenter
        role: "labelLarge"
        font.weight: Font.Bold
        lineHeight: Style.typeFor("labelLarge").size + 2

        Behavior on color {
            ColorMotion {}
        }
    }
}
