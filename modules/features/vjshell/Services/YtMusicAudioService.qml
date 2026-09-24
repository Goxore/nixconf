pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
    id: root

    readonly property real volume: stateFile.adapter.volume

    signal changed

    onVolumeChanged: changed()

    FileView {
        id: stateFile

        path: Paths.state("vjshell-ytmusic-volume.json")
        printErrors: false
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            property real volume: 0.5
        }
    }
}
