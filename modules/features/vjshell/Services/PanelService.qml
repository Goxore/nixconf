pragma Singleton

import Quickshell
import Quickshell.Io
import qs.Widgets

Singleton {
    id: root

    property string activePanel: ""
    property string screenName: ""

    readonly property int here: 0
    readonly property int fresh: -1

    property int subject: root.here

    property bool projectBar: false

    function isOpen(name, screen) {
        return activePanel === name && (screen === undefined || screenName === screen);
    }

    function pick(project) {
        root.subject = project;
        root.open("projectPicker");
    }

    function edit(project) {
        root.subject = project;
        root.open("projectEditor");
    }

    function open(name, screen) {
        TrayMenuService.close();
        screenName = MangoService.screenOr(screen || MangoService.focusedScreen);
        TooltipService.hide();
        activePanel = name;
    }

    function close(name) {
        if (activePanel === name)
            activePanel = "";
    }

    function closeAll() {
        activePanel = "";
    }

    function toggle(name, screen) {
        if (isOpen(name) && (!screen || screenName === screen))
            close(name);
        else
            open(name, screen);
    }

    PanelIpc {
        target: "launcher"
    }

    PanelIpc {
        target: "bluetooth"
    }

    PanelIpc {
        target: "wifi"
    }

    PanelIpc {
        target: "processes"
    }

    IpcHandler {
        target: "projects"
        function toggle(): void {
            root.projectBar = !root.projectBar;
        }
        function edit(): void {
            root.edit(root.here);
        }
        function pick(): void {
            root.pick(root.here);
        }
        function create(): void {
            root.pick(root.fresh);
        }
    }

    PanelIpc {
        target: "calendar"
    }

    PanelIpc {
        target: "lyricsControl"
    }

    IpcHandler {
        target: "shell"
        function close(): void {
            root.closeAll();
        }
    }
}
