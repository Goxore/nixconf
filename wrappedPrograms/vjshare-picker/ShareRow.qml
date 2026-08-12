import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    required property var item
    required property bool selected

    readonly property int thumbSize: 40

    signal activated

    implicitHeight: thumbSize + Style.panelPadding
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

        Rectangle {
            Layout.preferredWidth: root.thumbSize
            Layout.preferredHeight: root.thumbSize
            radius: Style.radiusXs
            color: Theme.surface
            clip: true

            ScreencopyView {
                id: thumb
                anchors.fill: parent
                captureSource: root.item.captureSource
                live: true
                paintCursor: false
                visible: hasContent
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !thumb.hasContent
                text: root.item.icon
                font.pixelSize: Style.iconSizeXl
                color: Theme.textDim
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.item.label
            elide: Text.ElideMiddle
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
            color: Theme.text
        }
    }
}
