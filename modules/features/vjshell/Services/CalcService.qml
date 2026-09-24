pragma Singleton

import QtQuick
import Quickshell
import qs.Widgets

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
        clear();
        if (!looksLikeMath(query))
            return;
        const expression = query.trim().replace(/^=\s*/, "");
        calculation.request = {
            command: ["qalc", "-t", expression],
            context: expression
        };
    }

    function clear() {
        calculation.request = null;
        result = "";
        evaluated = "";
    }

    RequestProcess {
        id: calculation
        delay: 120
        onFinished: (code, output, expression) => {
            root.result = code === 0 ? output.trim() : "";
            root.evaluated = expression;
        }
    }
}
