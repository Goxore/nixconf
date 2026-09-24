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

    readonly property string headsetOff: "headset_off"
    readonly property string screenShare: "screen_share"

    readonly property string keyboard: "keyboard"

    readonly property string bluetooth: "bluetooth"

    readonly property string wifi: "wifi"
    readonly property string lock: "lock"
    readonly property string wifiOff: "wifi_off"
    readonly property string wifiGood: "network_wifi_3_bar"
    readonly property string wifiFair: "network_wifi_2_bar"
    readonly property string wifiWeak: "network_wifi_1_bar"

    readonly property string headphones: "headphones"
    readonly property string mouse: "mouse"
    readonly property string phone: "smartphone"
    readonly property string machine: "computer"
    readonly property string speaker: "speaker"
    readonly property string gamepad: "sports_esports"
    readonly property string vr: "head_mounted_device"
    readonly property string devices: "devices"
    readonly property string application: "apps"

    readonly property string calculate: "calculate"
    readonly property string translate: "translate"
    readonly property string copy: "content_copy"
    readonly property string close: "close"
    readonly property string clear: "clear_all"

    readonly property string today: "today"
    readonly property string chevronLeft: "chevron_left"
    readonly property string chevronRight: "chevron_right"

    readonly property string search: "search"
    readonly property string terminal: "terminal"
    readonly property string remove: "delete"
    readonly property string link: "link"
    readonly property string linkOff: "link_off"
    readonly property string expandLess: "expand_less"
    readonly property string expandMore: "expand_more"
    readonly property string checkBox: "check_box"
    readonly property string checkBoxOff: "check_box_outline_blank"
    readonly property string radioOn: "radio_button_checked"
    readonly property string radioOff: "radio_button_unchecked"
    readonly property string moreHoriz: "more_horiz"
    readonly property string emptyBell: "notifications_none"
    readonly property string emptyApps: "apps"
    readonly property string emptySearch: "search_off"

    readonly property string gpu: "developer_board"
    readonly property string uptime: "schedule"
    readonly property string load: "speed"
    readonly property string swap: "swap_horiz"
    readonly property string sort: "swap_vert"
    readonly property string pause: "pause"
    readonly property string resume: "play_arrow"
    readonly property string forceKill: "bolt"

    readonly property string lyrics: "lyrics"
    readonly property string check: "check"
    readonly property string reset: "restart_alt"
    readonly property string refresh: "refresh"
    readonly property string hourglassTop: "hourglass_top"
    readonly property string checkCircle: "check_circle"
    readonly property string help: "help"
    readonly property string error: "error"
    readonly property string musicNote: "music_note"
    readonly property string resize: "open_in_full"
    readonly property string rotate: "sync"
    readonly property string dragIndicator: "drag_indicator"

    readonly property string here: "person"

    readonly property string battery: "battery_full"
    readonly property string batteryLow: "battery_alert"
    readonly property string batteryCharging: "battery_charging_full"
    readonly property string play: "play_arrow"
    readonly property string stop: "stop"
    readonly property string preview: "cast"
    readonly property string autoconnect: "autorenew"
    readonly property string install: "system_update_alt"
    readonly property string update: "update"
    readonly property string info: "info"
    readonly property string desktop: "desktop_windows"
    readonly property string warning: "warning"
    readonly property string worn: "visibility"

    readonly property string pausePlayback: "pause"
    readonly property string skipNext: "skip_next"
    readonly property string skipPrevious: "skip_previous"
    readonly property string shuffle: "shuffle"
    readonly property string repeatAll: "repeat"
    readonly property string repeatOne: "repeat_one"
    readonly property string queue: "queue_music"
    readonly property string liked: "favorite"
    readonly property string like: "favorite_border"
    readonly property string album: "album"
    readonly property string openExternal: "open_in_new"
    readonly property string emptyQueue: "queue_music"
    readonly property string emptyMusic: "music_off"

    readonly property string project: "square"
    readonly property string projects: "grid_view"
    readonly property string add: "add"

    readonly property var palette: [
        {
            name: "Terminal",
            icon: "terminal"
        },
        {
            name: "Code",
            icon: "code"
        },
        {
            name: "Web",
            icon: "language"
        },
        {
            name: "Video",
            icon: "videocam"
        },
        {
            name: "Music",
            icon: "music_note"
        },
        {
            name: "Game",
            icon: "sports_esports"
        },
        {
            name: "Lock",
            icon: "lock"
        },
        {
            name: "Cloud",
            icon: "cloud"
        },
        {
            name: "Database",
            icon: "database"
        },
        {
            name: "Design",
            icon: "brush"
        },
        {
            name: "Notes",
            icon: "description"
        },
        {
            name: "Chat",
            icon: "forum"
        },
        {
            name: "Mail",
            icon: "mail"
        },
        {
            name: "Build",
            icon: "handyman"
        },
        {
            name: "Science",
            icon: "science"
        },
        {
            name: "Folder",
            icon: "folder"
        }
    ]

    readonly property string agents: "smart_toy"
    readonly property string agentsIdle: "robot_2"
    readonly property string jump: "arrow_outward"
    readonly property string folder: "folder_open"
    readonly property string model: "neurology"
    readonly property string context: "data_usage"
    readonly property string waiting: "pan_tool"

    function forSignal(strength) {
        if (strength >= 0.75)
            return wifi;
        if (strength >= 0.5)
            return wifiGood;
        if (strength >= 0.25)
            return wifiFair;
        return wifiWeak;
    }

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
