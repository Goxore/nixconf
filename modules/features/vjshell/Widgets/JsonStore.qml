import QtQuick
import Quickshell.Io

FileView {
    id: root

    property int writeDelay: 3000

    function save() {
        writeback.restart();
    }

    watchChanges: false
    printErrors: false

    property Timer writeback: Timer {
        interval: root.writeDelay
        onTriggered: root.writeAdapter()
    }
}
