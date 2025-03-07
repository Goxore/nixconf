local astal = require("astal")
local Widget = require("astal.gtk3.widget")
local Gtk = require("astal.gtk3")
local Variable = astal.Variable
local interval = astal.interval
local timeout = astal.timeout
local GLib = astal.require("GLib")
local bind = astal.bind
local Mpris = astal.require("AstalMpris")
local Battery = astal.require("AstalBattery")
local Wp = astal.require("AstalWp")
local Network = astal.require("AstalNetwork")
local Tray = astal.require("AstalTray")
local Hyprland = astal.require("AstalHyprland")
local map = require("lib").map

return function(gdkmonitor)
    local Anchor = astal.require("Astal").WindowAnchor
    local microphone = Wp.get_default().audio.default_microphone

    local muted = bind(microphone, "mute"):as(
        function(m) return m end
    )

    return Widget.Window({
        class_name = "MicPopup",
        gdkmonitor = gdkmonitor,
        click_through = true,
        layer = "OVERLAY",
        anchor = Anchor.BOTTOM,
        Widget.Revealer({
            reveal_child = muted,
            transition_type = 4,
            Widget.Box({
                css = "margin-bottom: 100px;",
                Widget.Icon({
                    icon = "microphone-sensitivity-high-symbolic",
                })
            })
        }),
    })
end
