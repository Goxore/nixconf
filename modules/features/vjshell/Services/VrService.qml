pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Widgets

Singleton {
    id: root

    property var state: ({})
    property bool enabled: false
    property bool online: false
    property string requestError: ""
    property string tab: "connection"
    property string search: ""
    property var confirmation: null

    readonly property string executable: Quickshell.env("VJVR_BIN") || "vjvr"
    readonly property string fixture: Quickshell.env("VJVR_UI_FIXTURE") || ""
    readonly property bool busy: state.operation?.running ?? false
    readonly property var headsets: state.headsets || []
    readonly property var headset: headsets.find(h => h.serial === state.selected) || null
    readonly property bool manageable: online && headset?.status === "device"
    readonly property var software: headset?.software || []
    readonly property var client: software.find(p => p.package === "org.meumeu.wivrn.github") || software.find(p => p.package === "org.meumeu.wivrn") || null
    readonly property bool connected: state.runtime?.connected ?? false
    readonly property bool compatible: client !== null && client.version === state.runtime?.version
    readonly property string problem: requestError || state.operation?.error || state.problem || ""
    readonly property var applications: software.filter(p => (p.package + " " + p.version).toLowerCase().includes(search.toLowerCase()))

    readonly property var words: copy.words

    property Copy copy: Copy {
        source: Quickshell.shellPath("Modules/VR/copy.json")
    }

    function text(key, values) {
        return copy.text(key, values);
    }

    function errorText(code) {
        return text("error_" + code) || text("error_service_unavailable");
    }

    property var pending: []

    function send(request) {
        if (fixture || !online || (busy && request.action !== "cancel"))
            return;
        requestError = "";
        if (action.loading) {
            pending = pending.concat([request]);
            return;
        }
        dispatch(request);
    }

    function dispatch(request) {
        action.request = {
            command: [executable, "request", JSON.stringify(request)],
            context: request
        };
    }

    function confirm(request, key) {
        confirmation = {
            request: request,
            key: key
        };
    }

    function accept() {
        const request = confirmation?.request;
        confirmation = null;
        if (request)
            send(request);
    }

    function install() {
        if (!software.some(p => p.package === "org.meumeu.wivrn.github") && software.some(p => p.package === "org.meumeu.wivrn"))
            confirm({
                action: "install",
                confirm: true
            }, "confirm_channel");
        else
            send({
                action: "install"
            });
    }

    function toggleHotspot() {
        const active = state.hotspot?.state === "active";
        if (active && connected)
            confirm({
                action: "hotspot",
                enabled: false,
                confirm: true
            }, "confirm_disconnect");
        else
            send({
                action: "hotspot",
                enabled: !active
            });
    }

    function preference(key, value) {
        const preferences = Object.assign({}, state.preferences);
        preferences[key] = value;
        if (key === "auto_connect" && value)
            preferences.headset_audio = true;
        send({
            action: "preferences",
            preferences: preferences
        });
    }

    function size(bytes) {
        return bytes === null || bytes === undefined ? text("unavailable") : (bytes / 1073741824).toFixed(1) + " GiB";
    }

    function seen(time) {
        return time ? Qt.formatDateTime(new Date(time * 1000), "ddd HH:mm") : text("not_checked");
    }

    FileView {
        path: root.fixture || Quickshell.env("VJVR_CONFIG") || "/etc/vjvr.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.enabled = true;
            if (root.fixture) {
                try {
                    root.state = JSON.parse(text());
                    root.online = true;
                } catch (error) {
                    root.online = false;
                }
            }
        }
        onLoadFailed: root.enabled = false
    }

    RespawningProcess {
        command: [root.executable, "watch"]
        active: root.enabled && !root.fixture
        retryDelay: 2000
        onExited: root.online = false
        onLineRead: line => {
            try {
                root.state = JSON.parse(line);
                root.online = true;
            } catch (error) {
                root.online = false;
            }
        }
    }

    RequestProcess {
        id: action
        timeout: 10000
        onFinished: (code, output, context) => {
            try {
                const response = JSON.parse(output);
                if (!response.ok)
                    root.requestError = response.error || "service_unavailable";
            } catch (error) {
                root.requestError = "service_unavailable";
            }
            const [next, ...rest] = root.pending;
            root.pending = rest;
            if (next)
                Qt.callLater(() => root.dispatch(next));
        }
    }

    PanelIpc {
        target: "vr"
    }
}
