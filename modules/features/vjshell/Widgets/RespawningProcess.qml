import QtQuick
import Quickshell.Io

Item {
    id: root

    property var command: []
    property string label: ""
    property bool active: true
    property int retryDelay: 500

    signal lineRead(string line)
    signal exited(int code)

    Process {
        id: process

        command: root.command
        running: root.active && !retry.running

        stdout: SplitParser {
            onRead: line => root.lineRead(line)
        }

        onExited: code => {
            if (root.label !== "")
                console.warn(root.label, "exited with", code, "- retrying");
            root.exited(code);
            retry.restart();
        }
    }

    Timer {
        id: retry
        interval: root.retryDelay
    }
}
