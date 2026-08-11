import QtQuick
import qs.Commons

Rectangle {
    id: root

    property string text: ""
    property bool accent: false
    property bool enabled: true

    signal clicked

    implicitWidth: label.implicitWidth + Style.panelPadding * 2
    implicitHeight: Style.buttonHeight
    radius: Style.radiusS

    opacity: enabled ? 1.0 : Style.opacityDisabled

    color: root.accent ? Theme.accent : Theme.surfaceVariant

    Behavior on color {
        ColorAnimation {
            duration: Style.durState
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.standard
        }
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
    }

    TapHandler {
        id: tap
        enabled: root.enabled
        onPressedChanged: {
            if (pressed)
                state.press(point.position.x, point.position.y);
            else
                state.release();
        }
        onTapped: root.clicked()
    }

    StateLayer {
        id: state
        cornerRadius: root.radius
        layerColor: root.accent ? Theme.surface : Theme.stateLayer
        hovered: hover.hovered
        pressed: tap.pressed
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        color: root.accent ? Theme.surface : Theme.text
    }
}
