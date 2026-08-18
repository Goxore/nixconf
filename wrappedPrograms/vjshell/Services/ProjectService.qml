pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int projectCount: 5
    property var visibleSlots: [1]

    property int active: 1
    property var mru: []
    property var entries: []

    function view(visible) {
        Quickshell.execDetached(["vjproj", "view", String(visible)]);
    }

    function switchTo(index) {
        Quickshell.execDetached(["vjproj", "switch", String(index)]);
    }

    function next() {
        Quickshell.execDetached(["vjproj", "next"]);
    }

    Process {
        id: watcher
        command: ["vjproj", "watch"]
        running: true
        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }
        onExited: code => {
            console.warn("ProjectService: vjproj watch exited with", code, "- retrying");
            respawn.restart();
        }
    }

    Timer {
        id: respawn
        interval: 500
        onTriggered: watcher.running = true
    }

    function handleLine(line) {
        if (!line)
            return;
        try {
            const parsed = JSON.parse(line);
            if (typeof parsed.active === "number")
                root.active = parsed.active;
            if (typeof parsed.project_count === "number")
                root.projectCount = parsed.project_count;
            if (Array.isArray(parsed.visible_slots))
                root.visibleSlots = parsed.visible_slots;
            if (Array.isArray(parsed.mru))
                root.mru = parsed.mru;
            if (Array.isArray(parsed.tags))
                root.entries = parsed.tags;
        } catch (e) {
            console.warn("ProjectService: bad line", line, e);
        }
    }
}
