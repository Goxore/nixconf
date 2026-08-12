pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property real volume: stateFile.adapter.volume

    signal osdRequested()

    property bool settled: false

    Timer {
        running: true
        interval: 1000
        onTriggered: root.settled = true
    }

    onVolumeChanged: if (settled)
        osdRequested()

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/vjshell-ytmusic-volume.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            property real volume: 0.5
        }
    }
}
