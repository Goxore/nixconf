import QtQuick
import Quickshell.Widgets
import qs.Commons

Item {
    id: root

    property color layerColor: Theme.inkSurface
    property real cornerRadius: Style.radiusS
    property real topRadius: cornerRadius
    property real bottomRadius: cornerRadius
    property bool hovered: false
    property bool focused: false
    property bool pressed: false

    readonly property bool rippleEnabled: width >= Style.rippleMinSize && height >= Style.rippleMinSize
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
        ripple.opacity = Style.stateRipple;
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
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
        color: root.layerColor
        opacity: root.pressed ? Style.statePress : root.focused ? Style.stateFocus : root.hovered ? Style.stateHover : 0

        Behavior on opacity {
            NumberMotion {}
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
        color: "transparent"
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

        NumberMotion {
            id: grow
            target: ripple
            property: "r"
            duration: Style.durRipple
            easing.bezierCurve: Style.emphasizedDecelerate
            onFinished: {
                if (root.pendingFade) {
                    root.pendingFade = false;
                    fade.restart();
                }
            }
        }

        NumberMotion {
            id: fade
            target: ripple
            property: "opacity"
            to: 0
            duration: Style.durShort4
        }
    }
}
