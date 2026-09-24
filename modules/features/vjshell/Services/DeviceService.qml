pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets

Singleton {
    id: root

    property var devices: []
    property real now: Date.now()

    property Copy copy: Copy {
        source: Quickshell.shellPath("Modules/Devices/copy.json")
    }
    readonly property var words: copy.words

    function text(key, values) {
        return copy.text(key, values);
    }

    function iconOf(device) {
        if (device.kind === "phone")
            return Icons.phone;
        if (device.kind === "headset")
            return Icons.vr;
        return Icons.machine;
    }

    function ago(seconds) {
        const elapsed = Math.max(0, Math.floor(root.now / 1000 - seconds));
        if (elapsed < 60)
            return text("just_now");
        if (elapsed < 3600)
            return text("minutes_ago", {
                count: Math.floor(elapsed / 60)
            });
        if (elapsed < 86400)
            return text("hours_ago", {
                count: Math.floor(elapsed / 3600)
            });
        return text("days_ago", {
            count: Math.floor(elapsed / 86400)
        });
    }

    function stamp(seconds) {
        return Qt.formatDateTime(new Date(seconds * 1000), "d MMM HH:mm");
    }

    function clock(seconds) {
        return Qt.formatDateTime(new Date(seconds * 1000), "HH:mm");
    }

    function revision(value) {
        const dirty = value.endsWith("-dirty");
        const short = value.slice(0, 7);
        return dirty ? short + "-dirty" : short;
    }

    function status(device) {
        if (device.here)
            return text("this_device");
        if (device.online)
            return text("online");
        if (device.seen)
            return text("last_seen", {
                time: ago(device.seen)
            });
        return text("never_seen");
    }

    function battery(value) {
        const level = text("battery", {
            level: value.level
        });
        if (!value.charging)
            return level;
        const charging = value.full_at ? text("charging_until", {
            time: clock(value.full_at)
        }) : text("charging");
        return level + " · " + charging;
    }

    function details(device) {
        const parts = [];
        if (device.system) {
            parts.push(text("nixos", {
                release: device.system.release
            }));
            if (device.system.revision)
                parts.push(revision(device.system.revision));
            if (device.system.built)
                parts.push(stamp(device.system.built));
        }
        if (device.battery)
            parts.push(battery(device.battery));
        if (device.wivrn)
            parts.push(text("wivrn", {
                version: device.wivrn
            }));
        if (device.android)
            parts.push(text("android", {
                version: device.android
            }));
        return parts.join(" · ");
    }

    function summary(device) {
        const more = details(device);
        return more ? status(device) + "\n" + more : status(device);
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    PanelIpc {
        target: "devices"
    }
}
