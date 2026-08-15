pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property bool paused: false

    property string query: ""
    property string sortKey: "cpu"
    property bool showKernel: false

    property var entries: []

    readonly property var sortKeys: ["cpu", "memory", "name"]
    readonly property var sortLabels: ({
            cpu: "CPU",
            memory: "MEM",
            name: "A-Z"
        })

    readonly property var results: {
        const needle = query.trim().toLowerCase();
        const list = entries.filter(entry => {
            if (!showKernel && entry.kernel)
                return false;
            if (needle === "")
                return true;
            return entry.name.toLowerCase().includes(needle) || String(entry.pid).startsWith(needle);
        });

        if (sortKey === "memory")
            list.sort((a, b) => b.memory - a.memory || b.cpu - a.cpu);
        else if (sortKey === "name")
            list.sort((a, b) => a.name.localeCompare(b.name) || a.pid - b.pid);
        else
            list.sort((a, b) => b.cpu - a.cpu || b.memory - a.memory);

        return list;
    }

    function cycleSort() {
        const next = (sortKeys.indexOf(sortKey) + 1) % sortKeys.length;
        sortKey = sortKeys[next];
    }

    function stateLabel(state) {
        switch (state) {
        case "R":
            return "running";
        case "D":
            return "waiting";
        case "T":
        case "t":
            return "stopped";
        case "Z":
            return "zombie";
        case "I":
            return "idle";
        default:
            return "sleeping";
        }
    }

    function sendSignal(pid, name) {
        Quickshell.execDetached(["kill", "-" + name, String(pid)]);
        settle.restart();
    }

    function terminate(pid) {
        sendSignal(pid, "TERM");
    }

    function forceKill(pid) {
        sendSignal(pid, "KILL");
    }

    function toggleStopped(entry) {
        sendSignal(entry.pid, entry.state === "T" || entry.state === "t" ? "CONT" : "STOP");
    }

    readonly property real pageSize: 4096
    readonly property string collectScript: "cat /proc/stat /proc/[0-9]*/stat 2>/dev/null; stat -c '%u %n' /proc/[0-9]* 2>/dev/null"

    property var users: ({})
    property var previous: ({})
    property real previousTotal: 0

    onActiveChanged: {
        if (active) {
            collect();
            settle.restart();
        } else {
            paused = false;
            previous = ({});
            previousTotal = 0;
        }
    }

    onPausedChanged: if (active && !paused) {
        collect();
        settle.restart();
    }

    function collect() {
        if (collector.running)
            return;
        collector.running = true;
    }

    function parse(text) {
        const list = [];
        const next = {};
        const uids = {};
        let total = 0;
        let cores = 0;

        for (const line of text.split("\n")) {
            if (line.startsWith("cpu")) {
                if (line.startsWith("cpu "))
                    total = line.split(/\s+/).slice(1).map(Number).reduce((a, b) => a + b, 0);
                else
                    cores++;
                continue;
            }

            const owner = /^(\d+) \/proc\/(\d+)$/.exec(line);
            if (owner) {
                uids[owner[2]] = owner[1];
                continue;
            }

            const open = line.indexOf(" (");
            const close = line.lastIndexOf(") ");
            if (open < 0 || close < 0)
                continue;

            const pid = Number(line.slice(0, open));
            const fields = line.slice(close + 2).split(" ");
            const ppid = Number(fields[1]);
            const key = pid + ":" + fields[19];
            const ticks = Number(fields[11]) + Number(fields[12]);

            next[key] = ticks;
            list.push({
                pid: pid,
                key: key,
                name: line.slice(open + 2, close),
                state: fields[0],
                threads: Number(fields[17]),
                memory: Number(fields[21]) * root.pageSize,
                kernel: ppid === 2 || pid === 2,
                ticks: ticks,
                cpu: 0,
                user: ""
            });
        }

        const delta = total - previousTotal;
        const scale = Math.max(1, cores) * 100;

        for (const entry of list) {
            const before = previous[entry.key];
            if (before !== undefined && delta > 0)
                entry.cpu = Math.max(0, (entry.ticks - before) / delta * scale);
            entry.user = users[uids[entry.pid]] || "";
        }

        previous = next;
        previousTotal = total;
        entries = list;
    }

    Timer {
        id: poll
        running: root.active && !root.paused
        interval: 2000
        repeat: true
        onTriggered: root.collect()
    }

    Timer {
        id: settle
        interval: 600
        onTriggered: root.collect()
    }

    Process {
        id: collector
        command: ["sh", "-c", root.collectScript]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    FileView {
        path: "/etc/passwd"
        onLoaded: {
            const map = {};
            for (const line of text().split("\n")) {
                const fields = line.split(":");
                if (fields.length > 2)
                    map[fields[2]] = fields[0];
            }
            root.users = map;
        }
    }
}
