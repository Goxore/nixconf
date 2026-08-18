pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false

    property int cpuCount: 1
    property real cpuUsage: 0
    property real cpuTemp: 0

    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0

    property real gpuUsage: 0
    property real gpuTemp: 0
    property real gpuPower: 0
    property real vramUsed: 0
    property real vramTotal: 0

    property real load1: 0
    property real uptime: 0

    property var disks: []

    readonly property bool hasGpu: gpuBusyPath !== ""
    readonly property bool hasVram: vramTotal > 0

    readonly property real memFraction: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real vramFraction: vramTotal > 0 ? vramUsed / vramTotal : 0

    function formatBytes(bytes) {
        const units = ["B", "K", "M", "G", "T"];
        let value = bytes;
        let unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }
        return (unit === 0 || value >= 100 ? Math.round(value) : value.toFixed(1)) + units[unit];
    }

    function parseDisks(text) {
        const seen = {};
        const found = [];
        for (const line of text.trim().split("\n")) {
            const parts = line.trim().split(/\s+/);
            if (parts.length < 4)
                continue;
            const source = parts[0];
            const total = Number(parts[1]);
            const free = Number(parts[2]);
            if (seen[source] || !(total > 0))
                continue;
            seen[source] = true;
            found.push({
                "source": source,
                "mount": parts.slice(3).join(" "),
                "total": total,
                "free": free,
                "used": total - free
            });
        }
        root.disks = found;
    }

    function formatUptime(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor(seconds / 3600) % 24;
        const minutes = Math.floor(seconds / 60) % 60;
        if (days > 0)
            return days + "d " + hours + "h";
        if (hours > 0)
            return hours + "h " + minutes + "m";
        return minutes + "m";
    }

    property string gpuBusyPath: ""
    property string vramUsedPath: ""
    property string vramTotalPath: ""
    property string gpuTempPath: ""
    property string gpuPowerPath: ""
    property string cpuTempPath: ""

    property var cpuPrev: null

    onActiveChanged: if (!active)
        cpuPrev = null

    function parseStat(text) {
        let cores = 0;
        for (const line of text.split("\n")) {
            if (!line.startsWith("cpu"))
                break;
            if (!line.startsWith("cpu ")) {
                cores++;
                continue;
            }
            const fields = line.split(/\s+/).slice(1).map(Number);
            const total = fields.reduce((a, b) => a + b, 0);
            const idle = fields[3] + fields[4];
            if (cpuPrev) {
                const deltaTotal = total - cpuPrev.total;
                const deltaIdle = idle - cpuPrev.idle;
                if (deltaTotal > 0)
                    cpuUsage = Math.max(0, Math.min(1, 1 - deltaIdle / deltaTotal));
            }
            cpuPrev = {
                total: total,
                idle: idle
            };
        }
        cpuCount = Math.max(1, cores);
    }

    function parseMeminfo(text) {
        const values = {};
        for (const line of text.split("\n")) {
            const match = /^(\w+):\s+(\d+)/.exec(line);
            if (match)
                values[match[1]] = Number(match[2]) * 1024;
        }
        memTotal = values.MemTotal || 0;
        memUsed = Math.max(0, memTotal - (values.MemAvailable || 0));
        swapTotal = values.SwapTotal || 0;
        swapUsed = Math.max(0, swapTotal - (values.SwapFree || 0));
    }

    function refresh() {
        statFile.reload();
        meminfoFile.reload();
        uptimeFile.reload();
        loadFile.reload();
        if (cpuTempPath !== "")
            cpuTempFile.reload();
        if (gpuBusyPath !== "") {
            gpuBusyFile.reload();
            vramUsedFile.reload();
        }
        if (gpuTempPath !== "")
            gpuTempFile.reload();
        if (gpuPowerPath !== "")
            gpuPowerFile.reload();
    }

    Timer {
        running: root.active
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    readonly property string diskScript: "df -P -B1 2>/dev/null | awk 'NR > 1 && index($1, \"/dev/\") == 1 { print $1, $2, $4, $6 }'"

    Process {
        id: diskProbe
        command: ["sh", "-c", root.diskScript]

        stdout: StdioCollector {
            onStreamFinished: root.parseDisks(text)
        }
    }

    Timer {
        running: root.active
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProbe.running = true
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root.parseStat(text())
    }

    FileView {
        id: meminfoFile
        path: "/proc/meminfo"
        onLoaded: root.parseMeminfo(text())
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = Number(text().split(" ")[0]) || 0
    }

    FileView {
        id: loadFile
        path: "/proc/loadavg"
        onLoaded: root.load1 = Number(text().split(" ")[0]) || 0
    }

    FileView {
        id: cpuTempFile
        path: root.cpuTempPath
        printErrors: false
        onLoaded: root.cpuTemp = Number(text()) / 1000
    }

    FileView {
        id: gpuBusyFile
        path: root.gpuBusyPath
        printErrors: false
        onLoaded: root.gpuUsage = Math.max(0, Math.min(1, Number(text()) / 100))
    }

    FileView {
        id: gpuTempFile
        path: root.gpuTempPath
        printErrors: false
        onLoaded: root.gpuTemp = Number(text()) / 1000
    }

    FileView {
        id: gpuPowerFile
        path: root.gpuPowerPath
        printErrors: false
        onLoaded: root.gpuPower = Number(text()) / 1000000
    }

    FileView {
        id: vramUsedFile
        path: root.vramUsedPath
        printErrors: false
        onLoaded: root.vramUsed = Number(text()) || 0
    }

    FileView {
        id: vramTotalFile
        path: root.vramTotalPath
        printErrors: false
        onLoaded: root.vramTotal = Number(text()) || 0
    }

    readonly property string discoverScript: `
best=0
gpu=""
for card in /sys/class/drm/card[0-9]*/device; do
    [ -r "$card/gpu_busy_percent" ] || continue
    total=$(cat "$card/mem_info_vram_total" 2>/dev/null) || total=0
    [ "$total" -gt "$best" ] || continue
    best=$total
    gpu=$card
done
if [ -n "$gpu" ]; then
    echo "gpuBusy $gpu/gpu_busy_percent"
    [ -r "$gpu/mem_info_vram_used" ] && echo "vramUsed $gpu/mem_info_vram_used"
    [ -r "$gpu/mem_info_vram_total" ] && echo "vramTotal $gpu/mem_info_vram_total"
    for hwmon in "$gpu"/hwmon/hwmon[0-9]*; do
        [ -r "$hwmon/temp1_input" ] && echo "gpuTemp $hwmon/temp1_input"
        [ -r "$hwmon/power1_average" ] && echo "gpuPower $hwmon/power1_average"
    done
fi
for hwmon in /sys/class/hwmon/hwmon[0-9]*; do
    case "$(cat "$hwmon/name" 2>/dev/null)" in
        k10temp | zenpower | coretemp)
            [ -r "$hwmon/temp1_input" ] && echo "cpuTemp $hwmon/temp1_input" && break
            ;;
    esac
done
`

    Process {
        running: true
        command: ["sh", "-c", root.discoverScript]

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const space = line.indexOf(" ");
                    if (space < 0)
                        continue;
                    const path = line.slice(space + 1);
                    switch (line.slice(0, space)) {
                    case "gpuBusy":
                        root.gpuBusyPath = path;
                        break;
                    case "vramUsed":
                        root.vramUsedPath = path;
                        break;
                    case "vramTotal":
                        root.vramTotalPath = path;
                        break;
                    case "gpuTemp":
                        root.gpuTempPath = path;
                        break;
                    case "gpuPower":
                        root.gpuPowerPath = path;
                        break;
                    case "cpuTemp":
                        root.cpuTempPath = path;
                        break;
                    }
                }
            }
        }
    }
}
