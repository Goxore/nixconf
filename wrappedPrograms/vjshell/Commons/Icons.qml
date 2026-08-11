pragma Singleton

import Quickshell

Singleton {
    readonly property string bell: "notifications"
    readonly property string bellOff: "notifications_off"

    readonly property string volumeHigh: "volume_up"
    readonly property string volumeMedium: "volume_down"
    readonly property string volumeLow: "volume_mute"
    readonly property string volumeMuted: "volume_off"

    readonly property string micOn: "mic"
    readonly property string micOff: "mic_off"

    readonly property string keyboard: "keyboard"

    readonly property string bluetooth: "bluetooth"
    readonly property string bluetoothOff: "bluetooth_disabled"

    readonly property string wifi: "wifi"
    readonly property string wifiOff: "wifi_off"

    readonly property string headphones: "headphones"
    readonly property string mouse: "mouse"
    readonly property string phone: "smartphone"
    readonly property string speaker: "speaker"
    readonly property string gamepad: "sports_esports"
    readonly property string application: "apps"

    readonly property string calculate: "calculate"
    readonly property string copy: "content_copy"
    readonly property string close: "close"
    readonly property string clear: "clear_all"

    function forBluetoothDevice(iconName) {
        const name = iconName || "";
        if (name.includes("headset") || name.includes("headphone"))
            return headphones;
        if (name.includes("keyboard"))
            return keyboard;
        if (name.includes("mouse") || name.includes("pointing"))
            return mouse;
        if (name.includes("phone"))
            return phone;
        if (name.includes("audio") || name.includes("speaker"))
            return speaker;
        if (name.includes("gaming") || name.includes("joystick"))
            return gamepad;
        return bluetooth;
    }
}
