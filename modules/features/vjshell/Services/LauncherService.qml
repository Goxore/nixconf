pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string query: ""

    property var usage: ({})

    readonly property var entries: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const scored = [];

        for (const entry of entries) {
            const score = rank(entry, q);
            if (score > 0)
                scored.push({
                    entry: entry,
                    score: score + Math.min(usage[entry.id] || 0, 20)
                });
        }

        scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return scored.map(s => s.entry);
    }

    function rank(entry, q) {
        if (q === "")
            return 1;

        const name = (entry.name || "").toLowerCase();
        if (name === q)
            return 200;
        if (name.startsWith(q))
            return 100;
        if (name.includes(q))
            return 80;

        const words = q.split(/\s+/);
        if (words.length > 1) {
            const scores = words.map(word => rank(entry, word));
            return scores.every(score => score > 0) ? scores.reduce((a, b) => a + b, 0) / words.length : 0;
        }

        const generic = (entry.genericName || "").toLowerCase();
        if (generic.includes(q))
            return 60;

        const keywords = (entry.keywords || []).join(" ").toLowerCase();
        if (keywords.includes(q))
            return 50;

        const comment = (entry.comment || "").toLowerCase();
        if (comment.includes(q))
            return 40;

        if ((entry.id || "").toLowerCase().includes(q))
            return 30;

        let i = 0;
        for (const ch of name) {
            if (ch === q[i])
                i++;
            if (i === q.length)
                return 10;
        }

        return 0;
    }

    function runInTerminal(command) {
        Quickshell.execDetached([Quickshell.env("VJSHELL_TERMINAL") || "kitty", "-e"].concat(command));
    }

    function launch(entry) {
        if (!entry)
            return;

        usage = Object.assign({}, usage, {
            [entry.id]: (usage[entry.id] || 0) + 1
        });
        usageFile.writeAdapter();

        if (entry.runInTerminal)
            runInTerminal(entry.command);
        else
            entry.execute();
    }

    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher.json")
        watchChanges: false
        printErrors: false
        onLoaded: root.usage = adapter.usage || ({})
        onLoadFailed: error => root.usage = ({})

        JsonAdapter {
            property var usage: root.usage
        }
    }
}
