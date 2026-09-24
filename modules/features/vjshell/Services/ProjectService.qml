pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Singleton {
    id: root

    property int projectCount: 9
    property var visibleSlots: [1]

    property int active: 1
    property var mru: []
    property var entries: []
    property var agents: []
    property var places: []
    property var shelf: []

    property var peers: []

    readonly property var byProject: {
        const map = {};
        for (const place of root.places)
            map[place.project] = place;
        return map;
    }

    function placeOf(project) {
        return root.byProject[project] || null;
    }

    function named(project) {
        const place = root.placeOf(project);
        return place && place.name !== "" ? place.name : "";
    }

    function iconOf(project) {
        const place = root.placeOf(project);
        return place && place.icon !== "" ? place.icon : Icons.project;
    }

    readonly property int homeSlot: root.visibleSlots.length > 0 ? root.visibleSlots[0] : 1

    function blockStart(visible) {
        let start = 1;
        for (let v = 1; v < visible; v++)
            start += root.visibleSlots.includes(v) ? root.projectCount : 1;
        return start;
    }

    function realTag(project, visible) {
        const start = root.blockStart(visible);
        return root.visibleSlots.includes(visible) ? start + project - 1 : start;
    }

    function tagBusy(real) {
        for (const name in MangoService.outputs) {
            const tag = (MangoService.outputs[name].tags || [])[real - 1];
            if (tag && tag.clients > 0)
                return true;
        }
        return false;
    }

    readonly property var busyProjects: {
        const list = [];
        for (let project = 1; project <= root.projectCount; project++)
            if (root.tagBusy(root.realTag(project, root.homeSlot)))
                list.push(project);
        return list;
    }

    function hasWindows(project) {
        return root.busyProjects.indexOf(project) >= 0;
    }

    function firstFree() {
        for (let project = 1; project <= root.projectCount; project++)
            if (root.blank(project))
                return project;
        return root.active;
    }

    function blank(project) {
        return root.named(project) === "" && !root.hasWindows(project) && root.agentsFor(project).length === 0;
    }

    function assign(project, id) {
        Quickshell.execDetached(["vjproj", "project", "assign", String(project), String(id)]);
    }

    function describe(project, name, icon, dir) {
        const args = ["vjproj", "project", "describe", String(project)];
        if (name !== null && name !== undefined)
            args.push("--name", name);
        if (icon !== null && icon !== undefined)
            args.push("--icon", icon);
        if (dir !== null && dir !== undefined)
            args.push("--dir", dir);
        Quickshell.execDetached(args);
    }

    function reorder(from, to) {
        if (from !== to)
            Quickshell.execDetached(["vjproj", "project", "swap", String(from), String(to)]);
    }

    function forget(id) {
        Quickshell.execDetached(["vjproj", "project", "forget", String(id)]);
    }

    readonly property var signalRank: ["alert", "done", "working", "idle"]

    function agentSignal(agent) {
        if (agent.attention)
            return agent.activity === "blocked" ? "alert" : "done";
        return agent.activity === "idle" ? "idle" : "working";
    }

    function agentRank(agent) {
        return root.signalRank.indexOf(root.agentSignal(agent));
    }

    function byUrgency(a, b) {
        return root.agentRank(a) - root.agentRank(b) || a.pid - b.pid;
    }

    function agentsFor(project) {
        return root.agents.filter(a => a.project === project).sort(root.byUrgency);
    }

    function leadFor(project) {
        const stack = root.agentsFor(project);
        const top = stack.length > 0 ? stack[0] : null;
        const signal = top ? root.agentSignal(top) : "idle";
        if (signal === "idle")
            return {
                signal: "",
                kind: ""
            };
        return {
            signal: signal,
            kind: top.kind
        };
    }

    function countOf(signal) {
        return root.agents.filter(a => root.agentSignal(a) === signal).length;
    }

    readonly property int alertCount: root.countOf("alert")
    readonly property int doneCount: root.countOf("done")
    readonly property int workingCount: root.countOf("working")
    readonly property int idleCount: root.countOf("idle")

    function machineOf(peer) {
        return peer && typeof peer.host === "string" ? peer.host : "";
    }

    function agentsOn(machine) {
        for (const peer of root.peers)
            if (root.machineOf(peer) === machine) {
                const carried = peer.state && Array.isArray(peer.state.agents) ? peer.state.agents : [];
                return carried.slice().sort(root.byUrgency);
            }
        return [];
    }

    readonly property var machines: root.peers.map(peer => root.machineOf(peer)).filter(name => name !== "").sort()

    readonly property var elsewhere: {
        const list = [];
        for (const peer of root.peers) {
            const machine = root.machineOf(peer);
            for (const agent of root.agentsOn(machine))
                list.push(Object.assign({}, agent, {
                    machine: machine
                }));
        }
        return list.sort(root.byUrgency);
    }

    function leadOn(machine) {
        const stack = root.agentsOn(machine);
        return stack.length > 0 ? root.agentSignal(stack[0]) : "";
    }

    function countElsewhere(signal) {
        return root.elsewhere.filter(a => root.agentSignal(a) === signal).length;
    }

    readonly property int remoteAlertCount: root.countElsewhere("alert")
    readonly property int remoteDoneCount: root.countElsewhere("done")
    readonly property int remoteWorkingCount: root.countElsewhere("working")

    readonly property var limits: {
        for (const agent of root.agents)
            if (agent.status && agent.status.fiveHour !== null && agent.status.fiveHour !== undefined)
                return agent.status;
        return null;
    }

    readonly property string home: Quickshell.env("HOME") || ""

    function tilde(dir) {
        const cwd = (dir || "").replace(/\/+$/, "");
        if (root.home && cwd === root.home)
            return "~";
        if (root.home && cwd.startsWith(root.home + "/"))
            return "~" + cwd.slice(root.home.length);
        return cwd;
    }

    function expand(dir) {
        const path = (dir || "").trim();
        if (!root.home)
            return path;
        if (path === "~")
            return root.home;
        if (path.startsWith("~/"))
            return root.home + path.slice(1);
        return path;
    }

    function view(visible) {
        Quickshell.execDetached(["vjproj", "view", String(visible)]);
    }

    function switchTo(index) {
        Quickshell.execDetached(["vjproj", "switch", String(index)]);
    }

    RespawningProcess {
        command: ["vjproj", "watch"]
        label: "ProjectService: vjproj watch"
        onLineRead: line => root.handleLine(line)
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
            if (Array.isArray(parsed.agents))
                root.agents = parsed.agents;
            if (Array.isArray(parsed.places))
                root.places = parsed.places;
            if (Array.isArray(parsed.devices))
                DeviceService.devices = parsed.devices;
            if (Array.isArray(parsed.shelf))
                root.shelf = parsed.shelf;
            if (Array.isArray(parsed.peers))
                root.peers = parsed.peers;
        } catch (e) {
            console.warn("ProjectService: bad line", line, e);
        }
    }
}
