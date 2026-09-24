pragma Singleton

import Quickshell

Singleton {
    id: root

    property var handle: null
    property real anchorY: 0
    property bool open: false
    property string screenName: ""

    function show(menuHandle, y, screen) {
        PanelService.closeAll();
        TooltipService.hide();
        handle = menuHandle;
        anchorY = y;
        screenName = MangoService.screenOr(screen || MangoService.focusedScreen);
        open = true;
    }

    function close() {
        open = false;
    }
}
