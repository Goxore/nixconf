import QtQuick
import qs.Commons

Item {
    id: root

    property real value: 0
    property real step: 0.05
    property int trackHeight: Style.sliderTrack
    property string description: ""
    property bool live: true

    signal moved(real value)
    signal committed(real value)

    readonly property real shown: drag.active ? drag.value : Math.max(0, Math.min(1, value))

    implicitWidth: Style.listMin
    implicitHeight: Math.max(trackHeight, Style.touchTarget)

    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: description
    Accessible.onIncreaseAction: root.nudge(root.step)
    Accessible.onDecreaseAction: root.nudge(-root.step)

    function nudge(delta) {
        if (!enabled)
            return;
        const next = Math.max(0, Math.min(1, shown + delta));
        root.moved(next);
        root.committed(next);
    }

    Keys.onLeftPressed: nudge(-step)
    Keys.onRightPressed: nudge(step)

    QtObject {
        id: drag
        property bool active: false
        property real value: 0
    }

    function positionFor(x) {
        return Math.max(0, Math.min(1, (x - root.trackHeight / 2) / Math.max(1, root.width - root.trackHeight)));
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    DragHandler {
        id: dragger
        enabled: root.enabled
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (active) {
                drag.active = true;
            } else {
                drag.active = false;
                root.committed(drag.value);
            }
        }

        onCentroidChanged: if (active) {
            drag.value = root.positionFor(centroid.position.x);
            if (root.live)
                root.moved(drag.value);
        }
    }

    TapHandler {
        enabled: root.enabled
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            const next = root.positionFor(point.position.x);
            root.moved(next);
            root.committed(next);
        }
    }

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: root.enabled ? Theme.surfaceContainerHighest : Theme.disabledContainer
    }

    Rectangle {
        id: active

        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(root.trackHeight, handle.x - Style.spacing)
        height: root.trackHeight
        radius: height / 2
        color: root.enabled ? Theme.primary : Theme.disabledContent

        Behavior on width {
            enabled: !drag.active
            NumberMotion {
                duration: Style.durShort3
            }
        }
    }

    Rectangle {
        id: handle

        anchors.verticalCenter: parent.verticalCenter
        x: root.shown * (root.width - root.trackHeight) + root.trackHeight / 2 - width / 2
        width: Style.sliderHandle
        height: root.trackHeight + Style.spacing * 2
        radius: width / 2
        color: root.enabled ? Theme.primary : Theme.disabledContent
        scale: dragger.active ? 1.15 : 1

        Behavior on x {
            enabled: !drag.active
            NumberMotion {
                duration: Style.durShort3
            }
        }

        Behavior on scale {
            NumberMotion {
                duration: Style.durShort2
                easing.bezierCurve: Style.emphasizedDecelerate
            }
        }
    }

    Rectangle {
        anchors.centerIn: handle
        width: Style.touchTarget
        height: Style.touchTarget
        radius: width / 2
        color: Theme.primary
        opacity: root.activeFocus ? Style.stateFocus : hover.hovered ? Style.stateHover : 0

        Behavior on opacity {
            NumberMotion {}
        }
    }
}
