pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Widgets

Singleton {
    id: root

    property var entries: []

    readonly property var actions: ({
            "bluetooth.toggle": () => PanelService.toggle("bluetooth"),
            "wifi.toggle": () => PanelService.toggle("wifi"),
            "vr.toggle": () => PanelService.toggle("vr"),
            "music.toggle": () => PanelService.toggle("music"),
            "processes.toggle": () => PanelService.toggle("processes"),
            "notifications.toggle": () => PanelService.toggle("notifications"),
            "recorder.toggle": () => RecorderService.toggle(),
            "projects.create": () => PanelService.pick(PanelService.fresh)
        })

    function find(key) {
        return root.entries.find(entry => entry.key === key) || null;
    }

    function run(entry) {
        PanelService.close("menu");

        if (entry.action !== "") {
            const perform = root.actions[entry.action];
            if (perform)
                perform();
            else
                console.warn("MenuService: no such action", entry.action);
            return;
        }

        Quickshell.execDetached(["bash", "-c", entry.cmd]);
    }

    FileView {
        path: Quickshell.env("VJSHELL_MENU") || ""
        printErrors: false
        onLoaded: root.entries = JSON.parse(text())
    }

    PanelIpc {
        target: "menu"
    }
}
