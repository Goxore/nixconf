pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var outputs: ({})

    readonly property string focusedOutput: {
        for (const name in outputs) {
            if (outputs[name].tags.some(t => t && t.focused))
                return name;
        }
        for (const first in outputs)
            return first;
        return "";
    }

    function stateFor(name) {
        return outputs[name] || emptyState;
    }

    function tagsFor(name) {
        return stateFor(name).tags;
    }

    function kbLayoutFor(name) {
        return stateFor(name).kbLayout;
    }

    function view(index, output) {
        const cmd = ["mmsg"];
        if (output)
            cmd.push("-o", output);
        cmd.push("-s", "-t", String(index));
        Quickshell.execDetached(cmd);
    }

    function dispatch(...args) {
        Quickshell.execDetached(["mmsg", "-s", "-d", args.join(",")]);
    }

    readonly property var emptyState: ({
            tags: [],
            kbLayout: "",
            title: "",
            appId: ""
        })

    property var pending: ({})

    function bucketFor(name) {
        if (!pending[name])
            pending[name] = {
                tags: [],
                kbLayout: "",
                title: "",
                appId: ""
            };
        return pending[name];
    }

    function handleLine(line) {
        const parts = line.split(" ");
        if (parts.length < 3)
            return;

        const bucket = bucketFor(parts[0]);

        switch (parts[1]) {
        case "tag":
            const index = parseInt(parts[2], 10);
            const state = parseInt(parts[3], 10);
            if (isNaN(index) || isNaN(state))
                return;
            bucket.tags[index - 1] = {
                index: index,
                active: (state & 1) !== 0,
                urgent: (state & 2) !== 0,
                clients: parseInt(parts[4], 10) || 0,
                focused: parts[5] === "1"
            };
            break;
        case "kb_layout":
            bucket.kbLayout = parts.slice(2).join(" ");
            break;
        case "title":
            bucket.title = parts.slice(2).join(" ");
            break;
        case "appid":
            bucket.appId = parts.slice(2).join(" ");
            break;
        default:
            return;
        }

        commit.restart();
    }

    Timer {
        id: commit
        interval: 1
        onTriggered: {
            const next = {};
            for (const name in root.pending) {
                const bucket = root.pending[name];
                next[name] = {
                    tags: bucket.tags.slice(),
                    kbLayout: bucket.kbLayout,
                    title: bucket.title,
                    appId: bucket.appId
                };
            }
            root.outputs = next;
        }
    }

    Process {
        id: watcher
        command: ["mmsg", "-w", "-t", "-k", "-c"]
        running: true
        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }
        onExited: code => {
            console.warn("MangoService: mmsg watch exited with", code, "- retrying");
            respawn.restart();
        }
    }

    Timer {
        id: respawn
        interval: 500
        onTriggered: watcher.running = true
    }
}
