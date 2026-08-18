import QtQuick
import Quickshell.Io

Item {
    id: root

    property var command: []
    property string label: ""
    property int retryDelay: 500

    signal lineRead(string line)

    Process {
        id: proc

        command: root.command
        running: true

        stdout: SplitParser {
            onRead: line => root.lineRead(line)
        }

        onExited: code => {
            console.warn(root.label, "exited with", code, "- retrying");
            retry.restart();
        }
    }

    Timer {
        id: retry
        interval: root.retryDelay
        onTriggered: proc.running = true
    }
}
