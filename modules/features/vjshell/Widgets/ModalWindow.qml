import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
    id: root

    required property ShellScreen modelData
    required property string namespace
    property bool open: false
    property Item surface: null
    property int enterDuration: Style.durEnter
    property int exitDuration: Style.durExit

    readonly property bool opened: reveal.open
    readonly property real progress: reveal.progress

    signal dismissed

    screen: modelData
    visible: reveal.active
    color: "transparent"
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-" + namespace
    WlrLayershell.keyboardFocus: reveal.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Reveal {
        id: reveal
        open: root.open
        enterDuration: root.enterDuration
        exitDuration: root.exitDuration
    }

    Shortcut {
        sequence: "Escape"
        enabled: reveal.open
        onActivated: root.dismissed()
    }

    TapHandler {
        enabled: reveal.open && root.surface !== null
        onTapped: point => {
            const local = root.surface.mapFromItem(root.contentItem, point.position.x, point.position.y);
            if (!root.surface.contains(local))
                root.dismissed();
        }
    }
}
