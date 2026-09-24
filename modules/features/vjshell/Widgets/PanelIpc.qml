import QtQuick
import Quickshell.Io
import qs.Services

IpcHandler {
    function toggle(): void {
        PanelService.toggle(target);
    }

    function open(): void {
        PanelService.open(target);
    }

    function close(): void {
        PanelService.close(target);
    }
}
