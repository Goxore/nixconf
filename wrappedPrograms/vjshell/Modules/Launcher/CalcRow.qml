import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services

Rectangle {
    id: root

    required property bool selected

    signal activated

    implicitHeight: Style.rowHeightL
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

        Text {
            text: "="
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeXxl
            font.weight: Font.Bold
            color: Theme.accent
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: CalcService.result
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeXl
                font.weight: Font.Bold
                color: Theme.textBright
            }

            Text {
                Layout.fillWidth: true
                text: CalcService.evaluated
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                color: Theme.textDim
            }
        }

        MaterialIcon {
            text: Icons.copy
            font.pixelSize: Style.fontSizeLarge
            color: root.selected ? Theme.accent : Theme.textDim
        }
    }
}
