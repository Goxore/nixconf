pragma Singleton

import Quickshell

Singleton {
    id: root

    property var handle: null
    property real anchorY: 0
    property bool open: false

    function show(menuHandle, y) {
        handle = menuHandle;
        anchorY = y;
        open = true;
    }

    function close() {
        open = false;
    }
}
