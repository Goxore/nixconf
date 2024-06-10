import micPopup from "mic"
import { applauncher } from "applauncher"
import { NotificationPopups } from "notifications"
// import Gtk from "gi://Gtk?version=3.0"

const hyprland = await Service.import("hyprland")
const notifications = await Service.import("notifications")
const mpris = await Service.import("mpris")
const audio = await Service.import("audio")
const battery = await Service.import("battery")
const systemtray = await Service.import("systemtray")

const date = Variable("", {
    poll: [5000, `bash -c 'LANG=en_us_8859_1  date "+%H:%M %b %e."'`],
})
const iconSize = 14;

function Workspaces() {
    const activeId = hyprland.active.workspace.bind("id");
    const workspaces = hyprland.bind("workspaces").as((ws) =>
        ws
            .filter(({ id }) => id > 0)
            .sort((a, b) => a.id - b.id)
            .map(({ id }) =>
                Widget.Button({
                    on_clicked: () => hyprland.messageAsync(`dispatch workspace ${id}`),
                    class_name: activeId.as((i) => `${i === id ? "focused" : ""}`),
                })
            )
    );

    return Widget.Box({
        class_name: "workspaces",
        children: workspaces,
    });
}


function ClientTitle() {
    return Widget.Label({
        class_name: "client-title",
        label: hyprland.active.client.bind("title"),
    })
}


function Clock() {
    return Widget.Label({
        class_name: "yellow container",
        label: date.bind(),
    })
}


// we don't need dunst or any other notification daemon
// because the Notifications module is a notification daemon itself
function Notification() {
    const popups = notifications.bind("popups")
    return Widget.Box({
        class_name: "notification",
        visible: popups.as(p => p.length > 0),
        children: [
            Widget.Icon({
                icon: "preferences-system-notifications-symbolic",
                size: iconSize,

                className: "icon"
            }),
            Widget.Label({
                label: popups.as(p => p[0]?.summary || ""),
            }),
        ],
    })
}


function Media() {
    const label = Utils.watch("", mpris, "player-changed", () => {
        if (mpris.players[0]) {
            const { track_artists, track_title } = mpris.players[0]
            return `${track_artists.join(", ")} - ${track_title}`
        } else {
            return "Nothing is playing"
        }
    })

    return Widget.Button({
        class_name: "media",
        on_primary_click: () => mpris.getPlayer("")?.playPause(),
        on_scroll_up: () => mpris.getPlayer("")?.next(),
        on_scroll_down: () => mpris.getPlayer("")?.previous(),
        child: Widget.Label({ label }),
    })
}


function Volume() {
    const icons = {
        101: "overamplified",
        67: "high",
        34: "medium",
        1: "low",
        0: "muted",
    }

    function getIcon() {
        const icon = audio.speaker.is_muted ? 0 : [101, 67, 34, 1, 0].find(
            threshold => threshold <= audio.speaker.volume * 100)

        return `audio-volume-${icons[icon!]}-symbolic`
    }

    const icon = Widget.Icon({
        icon: Utils.watch(getIcon(), audio.speaker, getIcon),

        size: iconSize,
        className: "icon"
    })

    const slider = Widget.Slider({
        hexpand: true,
        draw_value: false,
        on_change: ({ value }) => audio.speaker.volume = value,
        setup: self => self.hook(audio.speaker, () => {
            self.value = audio.speaker.volume || 0
        }),
    })

    return Widget.Box({
        class_name: "yellow container",
        css: "min-width: 120px",
        children: [icon, slider],
    })
}

function Microphone() {

    function getIcon() {

        if (audio.microphone.is_muted || audio.microphone.volume == 0) {
            return "microphone-sensitivity-muted-symbolic"
        } else {
            return "microphone-sensitivity-high-symbolic";
        }
    }

    function getTextStatus() {
        if (audio.microphone.is_muted || audio.microphone.volume == 0) {
            return "off"
        } else {
            return "on ";
        }
    }

    const icon = Widget.Icon({
        icon: Utils.watch(getIcon(), audio.microphone, getIcon),

        className: "icon",
        size: iconSize,
    })

    const label = Widget.Label({
        label: Utils.watch(getTextStatus(), audio.microphone, getTextStatus),
    })

    return Widget.Box({
        class_name: "red container",
        css: "min-width: 30px",
        children: [icon, label],
    })

}

function Kblayout() {

    const languages = {
        "English": "english",
        "Ukrainian": "державна",
        "Russian": "русский",
    }

    var label = Widget.Label({
        label: "english",
    })

    const icon = Widget.Icon({
        icon: "transporter-symbolic",

        className: "icon",
        size: iconSize,
    })

    label.hook(hyprland, (self: any, keyboardname: string, layoutname: string) => {
        var maskedName = layoutname;
        for (const [key, value] of Object.entries(languages)) {
            if (layoutname.includes(key))
                maskedName = value;
        }
        label.label = maskedName;
    }, "keyboard-layout");


    return Widget.Box({
        class_name: "orange container",
        children: [icon, label],
    })
}

function Battery() {
    const value = battery.bind("percent").as(p => p > 0 ? p / 100 : 0)
    // const icon = battery.bind("percent").as(p =>
    //     `battery-${Math.floor(p / 10) * 10}`)
        
    const icon = battery.bind("percent").as(p =>
        `battery-full-charging-symbolic`)

    return Widget.Box({
        class_name: "battery container green",
        visible: battery.bind("available"),
        children: [
            Widget.Icon({
                icon: icon,
                icon_size: iconSize,

                className: "icon"
            }),
            Widget.LevelBar({
                widthRequest: 140,
                vpack: "center",
                value,
            }),
        ],
    })
}


function SysTray() {
    const items = systemtray.bind("items")
        .as(items => items.map(item => Widget.Button({
            child: Widget.Icon({
                icon: item.bind("icon"),
                size: iconSize,

                className: "icon"
            }),
            on_primary_click: (_, event) => item.activate(event),
            on_secondary_click: (_, event) => item.openMenu(event),
            tooltip_markup: item.bind("tooltip_markup"),
        })))

    return Widget.Box({
        children: items,
    })
}

function NixLogo() {
    return Widget.Label({
        label: "",
        css: `
        padding-left: 7px;
        padding-right: 7px;
        color: @blue_1
        `,
    })
}


// layout of the bar
function Left() {
    return Widget.Box({
        spacing: 8,
        children: [
            NixLogo(),
            Workspaces(),
            // ClientTitle(),
        ],
    })
}

function Center() {
    return Widget.Box({
        spacing: 8,
        children: [
            Media(),
            Notification(),
        ],
    })
}

function Right() {
    return Widget.Box({
        hpack: "end",
        spacing: 8,
        children: [
            Volume(),
            Microphone(),
            Kblayout(),
            Battery(),
            // BatteryLabel(),
            Clock(),
            SysTray(),
        ],
    })
}

function Bar(monitor = 0) {
    return Widget.Window({
        name: `bar-${monitor}`, // name has to be unique
        class_name: "bar bottombarshadow",
        monitor,
        anchor: ["top", "left", "right"],
        exclusivity: "exclusive",
        child: Widget.CenterBox({
            start_widget: Left(),
            center_widget: Center(),
            end_widget: Right(),
        }),
    })
}

// function Exclusivity(monitor = 0) {
//     return Widget.Window({
//         name: `exclusivity-${monitor}`, // name has to be unique
//         class_name: "bar bottombarshadow",
//         monitor,
//         anchor: ["top", "left", "right"],
//         exclusivity: "exclusive",
//         css: "background-color:transparent;",
//         height_request: 35,
//     })
// }

var bars = hyprland.monitors.map((m, i) => Bar(i))
// var exclusivity = hyprland.monitors.map((m, i) => Exclusivity(i))
var micPopups = hyprland.monitors.map((m, i) => micPopup(i))

App.config({
    style: "./style.scss",
    windows: [
        // ...exclusivity,
        ...bars,
        ...micPopups,
        applauncher,
        NotificationPopups()
    ],
})

export { }
