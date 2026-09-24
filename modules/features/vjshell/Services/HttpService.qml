pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property int defaultTimeout: 15000

    property var pending: []

    function ok(status) {
        return status >= 200 && status < 300;
    }

    function send(method, url, body, done, timeout) {
        const xhr = new XMLHttpRequest();
        const call = {
            xhr: xhr,
            done: done,
            deadline: Date.now() + (timeout || defaultTimeout),
            settled: false
        };
        xhr.open(method, url);
        if (body)
            xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE)
                root.settle(call, xhr.status, xhr.responseText);
        };
        pending = pending.concat([call]);
        xhr.send(body ? JSON.stringify(body) : undefined);
        return call;
    }

    function settle(call, status, text) {
        if (!call || call.settled)
            return;
        call.settled = true;
        pending = pending.filter(entry => entry !== call);
        if (call.done)
            call.done(status, text);
    }

    function cancel(call) {
        if (!call || call.settled)
            return;
        call.settled = true;
        pending = pending.filter(entry => entry !== call);
        call.xhr.abort();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.pending.length > 0
        onTriggered: {
            const now = Date.now();
            for (const call of root.pending.filter(entry => entry.deadline <= now)) {
                call.xhr.abort();
                root.settle(call, 0, "");
            }
        }
    }
}
