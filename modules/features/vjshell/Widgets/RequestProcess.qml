import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var request: null
    property int delay: 0
    property int timeout: 15000

    readonly property bool loading: request !== null && completedRevision !== revision

    property int revision: 0
    property int runningRevision: -1
    property int completedRevision: -1
    property var runningRequest: null
    property string output: ""

    signal finished(int exitCode, string output, var context)

    function start() {
        if (!request || debounce.running || process.running || runningRevision === revision)
            return;
        runningRevision = revision;
        runningRequest = request;
        output = "";
        process.command = request.command;
        process.running = true;
    }

    function complete(code) {
        if (runningRevision !== revision || completedRevision === revision)
            return;
        completedRevision = revision;
        finished(code, output, runningRequest.context);
    }

    onRequestChanged: {
        revision++;
        debounce.stop();
        process.running = false;
        if (request)
            debounce.restart();
    }

    property Timer debounce: Timer {
        interval: root.delay
        onTriggered: root.start()
    }

    property Timer deadline: Timer {
        interval: root.timeout
        running: process.running && interval > 0
        onTriggered: process.signal(9)
    }

    property Process process: Process {
        id: process

        stdout: StdioCollector {
            onStreamFinished: root.output = text
        }

        onExited: (code, status) => root.complete(status === 0 ? code : -1)
        onRunningChanged: {
            if (!running) {
                root.complete(-1);
                if (!debounce.running)
                    Qt.callLater(root.start);
            }
        }
    }
}
