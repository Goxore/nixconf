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

    implicitHeight: Style.rowHeight
    radius: Style.radiusS
    color: selected ? Theme.surfaceHigh : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Style.durState
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.standard
        }
    }

    StateLayer {
        id: state
        cornerRadius: root.radius
        hovered: hover.hovered
        pressed: tap.pressed
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        id: tap
        onPressedChanged: {
            if (pressed)
                state.press(point.position.x, point.position.y);
            else
                state.release();
        }
        onTapped: root.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.panelPadding
        anchors.rightMargin: Style.panelPadding
        spacing: Style.panelPadding

        Item {
            implicitWidth: Style.iconBoxS
            implicitHeight: Style.iconBoxS

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
                font.pixelSize: Style.iconSizeXl
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
