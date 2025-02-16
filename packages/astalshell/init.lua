local astal = require("astal")
local App = require("astal.gtk3.app")
local Widget = require("astal.gtk3.widget")

local Bar = require("widget.Bar")
local Player = require("widget.Player")
local MicPopup = require("widget.MicPopup")
local src = require("lib").src

local scss = src("style.scss")
local css = "/tmp/style.css"

astal.exec("sass " .. scss .. " " .. css)

App:start({
    instance_name = "lua",
    css = css,
    request_handler = function(msg, res)
        print(msg)
        if msg == "toggleplayer" then
            SHOW_PLAYER:set(not SHOW_PLAYER:get())
        end
        if msg == "togglelyrics" then
            SHOW_LYRICS:set(not SHOW_LYRICS:get())
        end
        res("ok")
    end,
    main = function()
        for _, mon in pairs(App.monitors) do
            Bar(mon)
            MicPopup(mon)
            Player(mon)
        end
    end,
})
