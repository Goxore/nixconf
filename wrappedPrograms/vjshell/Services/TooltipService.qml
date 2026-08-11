pragma Singleton

import Quickshell

Singleton {
    id: root

    property string text: ""
    property real anchorY: 0
    property string screenName: ""
    property bool shown: false

    function show(label, y, screen) {
        if (!label)
            return;
        text = label;
        anchorY = y;
        screenName = screen;
        shown = true;
    }

    function hide() {
        shown = false;
    }
}
