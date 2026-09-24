import QtQuick
import Quickshell
import qs.Widgets

ShellRoot {
    id: root
    property int stage: 0
    property int completed: 0
    function check(value, message) {
        if (!value)
            throw new Error(message);
    }
    RequestProcess {
        id: request
        timeout: 1000
        onFinished: (code, output, context) => {
            root.completed++;
            if (root.stage === 1) {
                root.check(code === 0 && output === "fresh" && context === 2, "stale result");
                root.stage = 2;
                request.request = {
                    command: ["sh", "-c", "sleep 0.1; printf cancelled"]
                };
                advance.interval = 30;
                advance.start();
            } else if (root.stage === 4) {
                root.check(code !== 0 && !request.loading, "timeout did not finish");
                root.stage = 5;
                request.request = {
                    command: ["/does-not-exist-vjshell-test"]
                };
            } else if (root.stage === 5) {
                root.check(code !== 0 && !request.loading, "failed start did not finish");
                root.stage = 6;
                request.request = {
                    command: ["sh", "-c", "printf done"]
                };
            } else if (root.stage === 6) {
                root.check(code === 0 && output === "done" && root.completed === 4, "recovery failed");
                console.log("PASS request replacement, cancellation, timeout, failed start and recovery");
                Qt.quit();
            } else {
                throw new Error("unexpected completion " + root.stage);
            }
        }
    }
    Timer {
        id: advance
        interval: 30
        running: true
        onTriggered: {
            if (root.stage === 0) {
                root.stage = 1;
                request.request = {
                    command: ["sh", "-c", "printf fresh"],
                    context: 2
                };
            } else if (root.stage === 2) {
                root.stage = 3;
                request.request = null;
                advance.interval = 180;
                advance.start();
            } else if (root.stage === 3) {
                root.check(root.completed === 1 && !request.loading, "cancelled result escaped");
                root.stage = 4;
                request.timeout = 40;
                request.request = {
                    command: ["sleep", "0.3"]
                };
            }
        }
    }
    Component.onCompleted: request.request = {
        command: ["sh", "-c", "trap '' TERM; sleep 0.15; printf stale"],
        context: 1
    }
}
