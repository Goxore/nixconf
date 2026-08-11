import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    required property var entry
    required property bool selected

    signal activated

    implicitHeight: 44
    radius: Style.radius
    color: selected ? Theme.surfaceHigh : hover.hovered ? Theme.surfaceVariant : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Style.animFast
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.panelPadding
        anchors.rightMargin: Style.panelPadding
        spacing: Style.panelPadding

        Item {
            implicitWidth: 28
            implicitHeight: 28

            IconImage {
                id: appIcon
                anchors.fill: parent
                source: Quickshell.iconPath(root.entry.icon, true)
                visible: status === Image.Ready
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !appIcon.visible
                text: Icons.application
                font.pixelSize: 22
                color: Theme.textDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.entry.name
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                color: Theme.text
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.entry.genericName || root.entry.comment || ""
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                color: Theme.textDim
            }
        }
    }
}
