pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Widgets

Singleton {
    id: root

    property var outputs: ({})

    function stateFor(name) {
        return outputs[name] || emptyState;
    }

    function tagsFor(name) {
        return stateFor(name).tags;
    }

    function kbLayoutFor(name) {
        return stateFor(name).kbLayout;
    }

    function view(index) {
        Quickshell.execDetached(["mmsg", "dispatch", `view,${index},0`]);
    }

    function dispatch(...args) {
        Quickshell.execDetached(["mmsg", "dispatch", args.join(",")]);
    }

    readonly property var emptyState: ({
            tags: [],
            kbLayout: ""
        })

    property var pending: ({})

    function bucketFor(name) {
        if (!pending[name])
            pending[name] = {
                tags: [],
                kbLayout: ""
            };
        return pending[name];
    }

    function handleTagsLine(line) {
        try {
            const parsed = JSON.parse(line);
            const list = parsed && parsed.all_tags;
            if (!Array.isArray(list))
                return;
            for (const entry of list) {
                if (!entry || !entry.monitor)
                    continue;
                const bucket = bucketFor(entry.monitor);
                bucket.tags = (entry.tags || []).map(t => ({
                            index: t.index,
                            active: !!t.is_active,
                            urgent: !!t.is_urgent,
                            clients: t.client_count | 0,
                            focused: !!t.is_active
                        }));
            }
            commit.restart();
        } catch (e) {
            console.warn("MangoService: bad tags line", line, e);
        }
    }

    function handleKbLine(line) {
        try {
            const parsed = JSON.parse(line);
            const layout = typeof parsed === "string" ? parsed : (parsed.layout || parsed.keyboardlayout || parsed.name || "");
            for (const name in root.outputs)
                bucketFor(name).kbLayout = layout;
            if (!Object.keys(root.pending).length && Object.keys(root.outputs).length === 0)
                bucketFor("").kbLayout = layout;
            commit.restart();
        } catch (e) {
            for (const name in root.outputs)
                bucketFor(name).kbLayout = line;
            commit.restart();
        }
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
                    kbLayout: bucket.kbLayout
                };
            }
            root.outputs = next;
        }
    }

    RespawningProcess {
        command: ["mmsg", "watch", "all-tags"]
        label: "MangoService: mmsg watch all-tags"
        onLineRead: line => root.handleTagsLine(line)
    }

    RespawningProcess {
        command: ["mmsg", "watch", "keyboardlayout"]
        label: "MangoService: mmsg watch keyboardlayout"
        onLineRead: line => root.handleKbLine(line)
    }
}
