const audio = await Service.import("audio")

import Gtk from "gi://Gtk?version=3.0"

const DELAY = 4000

function MicrophoneMute() {
    const icon = Widget.Icon({
        class_name: "microphone",
        vexpand: true,
        hexpand: true,
    })

    const box = Widget.Box({
        child: icon,
        class_name: "microphone_box",
    })

    const outside_box = Widget.Box({
        child: box,
        css: "margin-bottom:100px;"
    })

    const revealer = Widget.Revealer({
        transition: "slide_up",
        child: outside_box,
    })

    let count = 0
    let mute = audio.microphone.stream?.is_muted ?? false

    return revealer.hook(audio.microphone, () => Utils.idle(() => {
        if (mute !== audio.microphone.stream?.is_muted) {
            mute = audio.microphone.stream!.is_muted
            icon.icon = mute ? "microphone-sensitivity-muted-symbolic" : "microphone-sensitivity-high-symbolic"
            App.applyCss(mute ? `.microphone_box { color: @red_1; }` : `.microphone_box { color: @green_1; }`)
            revealer.reveal_child = true
            count++

            Utils.timeout(DELAY, () => {
                count--
                if (count === 0)
                    revealer.reveal_child = false
            })
        }
    }))
}

export default (monitor) => Widget.Window({
    monitor,
    name: `indicator${monitor}`,
    class_name: "indicator",
    layer: "overlay",
    anchor: ["bottom"],
    click_through: true,
    child: Widget.Box({
        css: "padding: 2px;",
        expand: true,
        child: MicrophoneMute()
    }),
})
