pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
    id: root

    property var participants: []

    readonly property bool connected: root.participants.length > 0

    function parse(body) {
        try {
            const parsed = JSON.parse(body);
            root.participants = Array.isArray(parsed.participants) ? parsed.participants : [];
        } catch (e) {
            root.participants = [];
        }
    }

    FileView {
        path: Paths.runtime("discord-call.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse(text())
    }
}
