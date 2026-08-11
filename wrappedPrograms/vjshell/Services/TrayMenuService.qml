pragma Singleton

import Quickshell

Singleton {
    id: root

    property var handle: null
    property real anchorY: 0

    readonly property bool open: handle !== null

    function show(menuHandle, y) {
        handle = menuHandle;
        anchorY = y;
    }

    function close() {
        handle = null;
    }
}
