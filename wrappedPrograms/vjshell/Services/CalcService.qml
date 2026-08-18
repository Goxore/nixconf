pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string result: ""
    property string evaluated: ""

    readonly property bool active: result !== ""

    function looksLikeMath(query) {
        const q = query.trim();
        if (q === "")
            return false;
        if (q.startsWith("="))
            return true;
        if (!/[0-9]/.test(q))
            return false;

        return /[-+*/^%()]/.test(q) || /\b(to|in)\b/i.test(q) || /[0-9]\s*[a-zA-Z°$€£¥]/.test(q);
    }

    function update(query) {
        if (!looksLikeMath(query)) {
            debounce.stop();
            result = "";
            evaluated = "";
            return;
        }

        pending = query.trim().replace(/^=\s*/, "");
        debounce.restart();
    }

    function clear() {
        debounce.stop();
        result = "";
        evaluated = "";
    }

    property string pending: ""

    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            proc.running = false;
            proc.command = ["qalc", "-t", root.pending];
            proc.running = true;
        }
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                root.result = out === "" || out === "0" ? "" : out;
                root.evaluated = root.pending;
            }
        }
    }
}
