pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int maxSeconds: 300
    readonly property string outputDir: Quickshell.env("HOME") + "/Videos/screenrec"

    readonly property bool recording: recorder.running
    property string activeFile: ""
    property string lastFile: ""

    function start() {
        if (recording)
            return;
        activeFile = outputDir + "/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss-zzz") + ".webm";
        const record = ["timeout", "-s", "INT", "-k", "5", String(maxSeconds), "wf-recorder", "--no-damage", "-r", "30", "-c", "libvpx-vp9", "-p", "deadline=realtime", "-p", "cpu-used=4", "-f", activeFile];
        if (MangoService.targetScreen !== "")
            record.push("-o", MangoService.targetScreen);
        recorder.command = ["bash", "-c", "mkdir -p \"$0\" && exec \"$@\"", outputDir].concat(record);
        recorder.running = true;
    }

    function stop() {
        if (recording && recorder.processId > 0)
            recorder.signal(2);
    }

    function toggle() {
        if (recording)
            stop();
        else
            start();
    }

    Process {
        id: recorder

        onExited: (code, status) => {
            if (status === 0 && (code === 0 || code === 124 || code === 130)) {
                verify.command = ["test", "-s", root.activeFile];
                verify.running = true;
            }
        }
    }

    Process {
        id: verify

        onExited: code => {
            if (code === 0)
                root.lastFile = command[2];
        }
    }

    IpcHandler {
        target: "recorder"

        function toggle(): void {
            root.toggle();
        }

        function start(): void {
            root.start();
        }

        function stop(): void {
            root.stop();
        }

        function status(): string {
            return JSON.stringify({
                recording: root.recording,
                file: root.recording ? root.activeFile : root.lastFile,
                maxSeconds: root.maxSeconds
            });
        }
    }
}
