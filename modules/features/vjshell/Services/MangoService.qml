pragma Singleton

import QtQuick
import Quickshell
import qs.Widgets

Singleton {
    id: root

    property var outputs: ({})
    property string focusedScreen: ""
    property string keyboardLayout: ""

    readonly property var screenNames: Quickshell.screens.map(screen => screen.name)
    readonly property string targetScreen: screenOr(focusedScreen)

    function screenOr(preferred) {
        return screenNames.includes(preferred) ? preferred : screenNames[0] ?? "";
    }

    function tagsFor(name) {
        return outputs[name]?.tags ?? [];
    }

    function readTags(line) {
        const list = JSON.parse(line)?.all_tags;
        if (!Array.isArray(list))
            return;
        const next = {};
        for (const entry of list.filter(entry => entry?.monitor))
            next[entry.monitor] = {
                tags: (entry.tags || []).map(tag => ({
                            index: tag.index,
                            active: !!tag.is_active,
                            urgent: !!tag.is_urgent,
                            clients: tag.client_count | 0
                        }))
            };
        outputs = next;
    }

    function readLayout(line) {
        try {
            const parsed = JSON.parse(line);
            keyboardLayout = typeof parsed === "string" ? parsed : parsed.layout || parsed.keyboardlayout || parsed.name || "";
        } catch (error) {
            keyboardLayout = line;
        }
    }

    RespawningProcess {
        command: ["mmsg", "watch", "all-monitors"]
        label: "MangoService: mmsg watch all-monitors"
        onLineRead: line => {
            try {
                root.focusedScreen = (JSON.parse(line).monitors || []).find(monitor => monitor.active)?.name || "";
            } catch (error) {}
        }
    }

    RespawningProcess {
        command: ["mmsg", "watch", "all-tags"]
        label: "MangoService: mmsg watch all-tags"
        onLineRead: line => {
            try {
                root.readTags(line);
            } catch (error) {
                console.warn("MangoService: bad tags line", line, error);
            }
        }
    }

    RespawningProcess {
        command: ["mmsg", "watch", "keyboardlayout"]
        label: "MangoService: mmsg watch keyboardlayout"
        onLineRead: line => root.readLayout(line)
    }
}
