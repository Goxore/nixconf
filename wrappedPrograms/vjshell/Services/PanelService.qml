pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string activePanel: ""

    function isOpen(name) {
        return activePanel === name;
    }

    function open(name) {
        activePanel = name;
    }

    function close(name) {
        if (activePanel === name)
            activePanel = "";
    }

    function closeAll() {
        activePanel = "";
    }

    function toggle(name) {
        activePanel = activePanel === name ? "" : name;
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            root.toggle("launcher");
        }
        function open(): void {
            root.open("launcher");
        }
        function close(): void {
            root.close("launcher");
        }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): void {
            root.toggle("bluetooth");
        }
    }

    IpcHandler {
        target: "wifi"
        function toggle(): void {
            root.toggle("wifi");
        }
    }

    IpcHandler {
        target: "shell"
        function close(): void {
            root.closeAll();
        }
    }
}
