import QtQuick
import Quickshell
import qs.Modules.VR
import qs.Services

ShellRoot {
    id: root

    property int stage: 0

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    FloatingWindow {
        visible: true
        implicitWidth: 540
        implicitHeight: 900
        Column {
            anchors.left: parent.left
            anchors.right: parent.right

            VrSummary {
                width: parent.width
            }

            VrPages {
                width: parent.width
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (!VrService.words.start_vr)
                return;
            if (root.stage === 0) {
                VrService.state = {
                    selected: "quest",
                    headsets: [
                        {
                            serial: "quest",
                            model: "Quest 3",
                            status: "device",
                            transport: "wifi",
                            battery: 86,
                            software: [
                                {
                                    package: "org.meumeu.wivrn.github",
                                    version: "26.9",
                                    source: "github"
                                }
                            ]
                        }
                    ],
                    runtime: {
                        connected: false,
                        version: "26.9"
                    },
                    preferences: {
                        start_hotspot: true,
                        open_desktop: true,
                        headset_audio: true
                    },
                    operation: {
                        running: false
                    }
                };
                VrService.online = true;
                root.stage++;
            } else if (root.stage === 1) {
                root.check(VrService.manageable && !VrService.connected, "ADB was mistaken for VR streaming");
                root.check(VrService.compatible, "matching client version rejected");
                root.check(VrService.text("last_seen_value", {
                    time: "12:34"
                }) === "Last seen 12:34", "dynamic text substitution");
                VrService.search = "missing";
                root.check(VrService.applications.length === 0, "application search did not filter");
                VrService.tab = "software";
                root.stage++;
            } else if (root.stage === 2) {
                const state = JSON.parse(JSON.stringify(VrService.state));
                state.headsets[0].status = "offline";
                state.runtime.connected = true;
                VrService.state = state;
                VrService.tab = "applications";
                root.stage++;
            } else if (root.stage === 3) {
                root.check(!VrService.manageable && VrService.connected, "wireless control loss hid VR streaming");
                root.check(VrService.client.version === "26.9", "cached software version disappeared");
                VrService.tab = "settings";
                root.stage++;
            } else {
                root.check(typeof MenuService.actions["vr.toggle"] === "function", "VR menu action missing");
                console.log("PASS VR connection independence, versions, search, settings, and menu action");
                Qt.quit();
            }
        }
    }
}
