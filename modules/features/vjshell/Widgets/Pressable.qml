import QtQuick
import qs.Commons

Item {
    id: root

    property string description: ""
    property bool selected: false
    property int acceptedButtons: Qt.LeftButton
    property real cornerRadius: Style.radiusS
    property real topRadius: cornerRadius
    property real bottomRadius: cornerRadius
    property color layerColor: Theme.inkSurface
    property real layerWidth: width
    property real layerHeight: height
    property real layerOffset: 0
    property bool keyboardPressed: false
    property bool wheelEnabled: false
    property bool interactive: true

    readonly property bool live: enabled && interactive

    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed || keyboardPressed

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int direction)

    function activationKey(event) {
        return event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
    }

    activeFocusOnTab: live
    Accessible.role: Accessible.Button
    Accessible.name: description
    Accessible.checked: selected
    Accessible.onPressAction: if (root.live)
        root.clicked()

    onActiveFocusChanged: if (!activeFocus)
        keyboardPressed = false

    Keys.onPressed: event => {
        if (!root.live || !root.activationKey(event))
            return;
        keyboardPressed = true;
        event.accepted = true;
    }

    Keys.onReleased: event => {
        if (!root.live || !root.activationKey(event))
            return;
        if (!event.isAutoRepeat && keyboardPressed) {
            keyboardPressed = false;
            root.clicked();
        }
        event.accepted = true;
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
        cursorShape: root.live ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        id: tap
        enabled: root.live
        acceptedButtons: root.acceptedButtons
        gesturePolicy: TapHandler.ReleaseWithinBounds

        onPressedChanged: {
            if (pressed)
                layer.press(point.position.x - layer.x, point.position.y - layer.y);
            else
                layer.release();
        }

        onTapped: (point, button) => {
            if (button === Qt.RightButton) {
                root.rightClicked();
                return;
            }
            if (button === Qt.MiddleButton) {
                root.middleClicked();
                return;
            }
            root.clicked();
        }
    }

    WheelHandler {
        enabled: root.live && root.wheelEnabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.y || event.pixelDelta.y;
            if (delta !== 0)
                root.scrolled(delta > 0 ? 1 : -1);
        }
    }

    StateLayer {
        id: layer

        anchors.fill: undefined
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.layerOffset
        width: root.layerWidth
        height: root.layerHeight
        z: 1
        topRadius: root.topRadius
        bottomRadius: root.bottomRadius
        layerColor: root.layerColor
        hovered: root.live && root.hovered
        focused: root.activeFocus && !root.pressed
        pressed: root.pressed
    }
}
