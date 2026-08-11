import QtQuick
import qs.Commons

Item {
    id: root

    property color layerColor: Theme.stateLayer
    property int cornerRadius: Style.radiusS
    property bool hovered: false
    property bool pressed: false

    property real hoverOpacity: Style.stateHover
    property real pressOpacity: Style.statePress
    property real rippleOpacity: Style.stateRipple

    property bool rippleEnabled: width >= Style.rippleMinSize && height >= Style.rippleMinSize
    property bool pendingFade: false

    anchors.fill: parent

    function press(px, py) {
        if (!rippleEnabled)
            return;
        grow.stop();
        fade.stop();
        pendingFade = false;
        ripple.cx = px;
        ripple.cy = py;
        ripple.r = 0;
        ripple.opacity = rippleOpacity;
        grow.to = ripple.maxRadius;
        grow.start();
    }

    function release() {
        if (!rippleEnabled || ripple.opacity <= 0)
            return;
        if (grow.running)
            pendingFade = true;
        else
            fade.restart();
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.layerColor
        opacity: root.pressed ? root.pressOpacity : root.hovered ? root.hoverOpacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Style.durState
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.standard
            }
        }
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: ripple.opacity > 0

        Rectangle {
            id: ripple

            property real cx: 0
            property real cy: 0
            property real r: 0
            readonly property real maxRadius: Math.max(Math.hypot(cx, cy), Math.hypot(root.width - cx, cy), Math.hypot(cx, root.height - cy), Math.hypot(root.width - cx, root.height - cy))

            x: cx - r
            y: cy - r
            width: r * 2
            height: r * 2
            radius: r
            color: root.layerColor
            opacity: 0
        }

        NumberAnimation {
            id: grow
            target: ripple
            property: "r"
            duration: Style.durRipple
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.emphasizedDecelerate
            onFinished: {
                if (root.pendingFade) {
                    root.pendingFade = false;
                    fade.restart();
                }
            }
        }

        NumberAnimation {
            id: fade
            target: ripple
            property: "opacity"
            to: 0
            duration: Style.durShort4
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.standard
        }
    }
}
