import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Devices
import qs.Services

ShellRoot {
    id: root

    property int stage: 0

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    function same(actual, expected) {
        check(actual === expected, "expected '" + expected + "', got '" + actual + "'");
    }

    FloatingWindow {
        visible: true
        implicitWidth: 540
        implicitHeight: 600

        DeviceList {
            width: parent.width
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (!DeviceService.words.this_device)
                return;
            if (root.stage === 0) {
                const now = 1790000000;
                DeviceService.now = now * 1000;

                root.same(DeviceService.ago(now - 30), "just now");
                root.same(DeviceService.ago(now - 300), "5 min ago");
                root.same(DeviceService.ago(now - 7200), "2 h ago");
                root.same(DeviceService.ago(now - 3 * 86400), "3 d ago");
                root.same(DeviceService.ago(now + 60), "just now");

                root.same(DeviceService.revision("a1b2c3d4e5f6"), "a1b2c3d");
                root.same(DeviceService.revision("a1b2c3d4e5f6-dirty"), "a1b2c3d-dirty");

                const built = new Date(2026, 8, 24, 14, 25).getTime() / 1000;
                const full = new Date(2026, 8, 24, 15, 40).getTime() / 1000;
                DeviceService.devices = [
                    {
                        id: "main",
                        name: "main",
                        kind: "computer",
                        here: true,
                        online: true,
                        seen: null,
                        system: {
                            release: "26.11",
                            revision: "a1b2c3d4e5f6-dirty",
                            built: built
                        },
                        battery: null,
                        android: null,
                        wivrn: null
                    },
                    {
                        id: "mini",
                        name: "mini",
                        kind: "computer",
                        here: false,
                        online: false,
                        seen: null,
                        system: null,
                        battery: null,
                        android: null,
                        wivrn: null
                    },
                    {
                        id: "pixel-8a",
                        name: "Pixel 8a",
                        kind: "phone",
                        here: false,
                        online: true,
                        seen: null,
                        system: null,
                        battery: {
                            level: 76,
                            charging: true,
                            at: now,
                            full_at: full
                        },
                        android: null,
                        wivrn: null
                    },
                    {
                        id: "headset-1",
                        name: "Quest 3",
                        kind: "headset",
                        here: false,
                        online: false,
                        seen: now - 3 * 86400,
                        system: null,
                        battery: {
                            level: 64,
                            charging: false,
                            at: now
                        },
                        android: "14",
                        wivrn: "26.9"
                    }
                ];
                root.stage = 1;
                return;
            }
            if (root.stage === 1) {
                const [main, mini, phone, headset] = DeviceService.devices;
                root.same(DeviceService.summary(main), "This device\nNixOS 26.11 · a1b2c3d-dirty · 24 Sep 14:25");
                root.same(DeviceService.summary(mini), "Never seen");
                root.same(DeviceService.summary(phone), "Online\nBattery 76% · Charging, full at 15:40");
                root.same(DeviceService.summary(headset), "Last seen 3 d ago\nBattery 64% · WiVRn 26.9 · Android 14");
                root.same(DeviceService.battery({
                    level: 50,
                    charging: true
                }), "Battery 50% · Charging");
                root.same(DeviceService.iconOf(phone), Icons.phone);
                root.same(DeviceService.iconOf(headset), Icons.vr);
                root.same(DeviceService.iconOf(main), Icons.machine);
                root.same(DeviceService.text("devices"), "Devices");
                console.log("PASS devices");
                Qt.quit();
            }
        }
    }
}
