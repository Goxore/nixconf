local astal = require("astal")

local Astal = astal.require("Astal", "3.0")

local bind = astal.bind
local Widget = require("astal.gtk3.widget")
local lookup_icon = Astal.Icon.lookup_icon
local Variable = require("astal.variable")

local map = require("lib").map

local Mpris = astal.require("AstalMpris")

local json = require("dkjson")
local http_request = require("http.request")

ARTIST = ""
TITLE = ""
LYRICS = {}
SHOW_PLAYER = Variable(false)
SHOW_LYRICS = Variable(false)

local function sanitize_string(str)
    return str:gsub("%s", "-"):gsub("%W", "-") -- Removes spaces and non-alphanumeric characters
end

---@param length integer
local function length_str(length)
    local min = math.floor(length / 60)
    local sec = math.floor(length % 60)

    return string.format("%d:%s%d", min, sec < 10 and "0" or "", sec)
end

local function song_lyrics(artist, title)
    artist = sanitize_string(artist)
    title = sanitize_string(title)

    local url = "https://api.lyrics.ovh/v1/" .. artist .. "/" .. title
    print(url)

    local headers, stream = assert(http_request.new_from_uri(url):go())
    local body = assert(stream:get_body_as_string())
    if headers:get ":status" ~= "200" then
        return nil
    end

    local data = json.decode(body)
    if not data.lyrics then
        return nil
    end

    local lyrics = data.lyrics:gsub("\\r\\n", "\n")
    lyrics = lyrics:gsub("\n\n", "\n")
    lyrics = lyrics:gsub("\n\n+", "\n")
    lyrics = lyrics:gsub("\n%s+", "\n")
    lyrics = lyrics:gsub("^%s+", "")

    return lyrics
end

local function song_lyrics2(artist, title)
    artist = sanitize_string(artist)
    title = sanitize_string(title)

    local url = "https://lrclib.net/api/get?artist_name=" .. artist .. "&track_name=" .. title -- .. "&album_name=TEST"
    print(url)

    local headers, stream = assert(http_request.new_from_uri(url):go())
    local body = assert(stream:get_body_as_string())
    if headers:get ":status" ~= "200" then
        return nil
    end

    local data = json.decode(body)
    if not data.syncedLyrics then
        return nil
    end

    local lyrics = data.syncedLyrics:gsub("\\r\\n", "\n")
    lyrics = lyrics:gsub("\n\n", "\n")
    lyrics = lyrics:gsub("\n\n+", "\n")
    lyrics = lyrics:gsub("\n%s+", "\n")
    lyrics = lyrics:gsub("^%s+", "")

    return lyrics
end

local function parse_lyrics(lyrics_text)
    local lyrics = {}
    local lines = {}

    -- Split input into individual lines
    for line in lyrics_text:gmatch("[^\n]+") do
        -- Extract timestamp and lyric content
        local time_part, lyric = line:match("%[(%d+:%d+%.%d+)%](.*)")
        if time_part and lyric then
            -- Parse minutes and seconds with decimal
            local minutes, seconds_part = time_part:match("^(%d+):(%d+%.%d+)$")
            if minutes and seconds_part then
                local min = tonumber(minutes)
                local sec = tonumber(seconds_part)
                local start_time = min * 60 + sec

                -- Clean up lyric text and store
                table.insert(lines, {
                    start = start_time,
                    line = lyric:gsub("^%s+", ""):gsub("%s+$", "")
                })
            end
        end
    end

    -- Calculate end times for each entry
    for i = 1, #lines do
        if i < #lines then
            lines[i].end_time = lines[i + 1].start
        else
            lines[i].end_time = math.huge -- Last entry lasts indefinitely
        end
    end

    return lines
end


local function get_lyric(target_time)
    local lyrics_table = LYRICS
    for i, entry in ipairs(lyrics_table) do
        if target_time >= entry.start and target_time < entry.end_time then
            local prev = lyrics_table[i - 1] and lyrics_table[i - 1].line
            local next = lyrics_table[i + 1] and lyrics_table[i + 1].line
            return prev or "", entry.line or "", next or ""
        end
    end
    return "", "", ""
end

-- local function get_lyric(target_time)
--     for _, entry in ipairs(LYRICS) do
--         if target_time >= entry.start and target_time < entry.end_time then
--             return entry.line
--         end
--     end
--     return nil
-- end

local function updateState(artist, title)
    if artist ~= ARTIST or title ~= TITLE then
        ARTIST = artist
        TITLE = title
        print("REFRESHING SONG")
        local lyrics = song_lyrics2(artist, title)
        if lyrics == nil then return; end
        LYRICS = parse_lyrics(lyrics)
    end
end

local function MediaPlayer(player)
    local lyricpiece = bind(player, "position"):as(
        function(s)
            updateState(player:get_artist(), player:get_title())
            local prev, current, next = get_lyric(s)
            return prev .. "\n\n" .. current .. "\n\n" .. next
        end
    )

    local title = bind(player, "title"):as(
        function(t) return t or "Unknown Track" end
    )

    local artist = bind(player, "artist"):as(
        function(a) return a or "Unknown Artist" end
    )

    local cover_art = bind(player, "cover-art"):as(
        function(c) return string.format("background-image: url('%s');", c) end
    )

    local player_icon = bind(player, "entry"):as(
        function(e) return lookup_icon(e) and e or "audio-x-generic-symbolic" end
    )

    local position = bind(player, "position"):as(
        function(p) return player.length > 0 and p / player.length or 0 end
    )

    local play_icon = bind(player, "playback-status"):as(
        function(s)
            return s == "PLAYING" and "media-playback-pause-symbolic"
                or "media-playback-start-symbolic"
        end
    )

    return
        Widget.Revealer({
            reveal_child = bind(SHOW_PLAYER):as(function(s)
                return s
            end),
            transition_type = 2,

            SHOW_PLAYER():as(function(s)
                if not s then return nil end
                return Widget.Box({
                    class_name = "MediaPlayer",
                    vertical = true,
                    Widget.Box({
                        Widget.Box({
                            class_name = "cover-art",
                            css = cover_art,
                        }),
                        Widget.Box({
                            vertical = true,
                            Widget.Box({
                                class_name = "title",
                                Widget.Label({
                                    ellipsize = "END",
                                    hexpand = true,
                                    halign = "START",
                                    label = title,
                                }),
                                -- Widget.Icon({
                                --     icon = player_icon,
                                -- }),
                            }),
                            Widget.Label({
                                halign = "START",
                                valign = "START",
                                vexpand = true,
                                wrap = true,
                                label = artist,
                            }),
                            Widget.Slider({
                                visible = bind(player, "length"):as(
                                    function(l) return l > 0 end
                                ),
                                on_dragged = function(event)
                                    player.position = event.value * player.length
                                end,
                                value = position,
                            }),
                            Widget.CenterBox({
                                class_name = "actions",
                                Widget.Label({
                                    hexpand = true,
                                    class_name = "position",
                                    halign = "START",
                                    visible = bind(player, "length"):as(
                                        function(l) return l > 0 end
                                    ),
                                    label = bind(player, "position"):as(length_str),
                                }),
                                Widget.Box({
                                    Widget.Button({
                                        on_clicked = function() player:previous() end,
                                        visible = bind(player, "can-go-previous"),
                                        Widget.Icon({
                                            icon = "media-skip-backward-symbolic",
                                        }),
                                    }),
                                    Widget.Button({
                                        on_clicked = function() player:play_pause() end,
                                        visible = bind(player, "can-control"),
                                        Widget.Icon({
                                            icon = play_icon,
                                        }),
                                    }),
                                    Widget.Button({
                                        on_clicked = function() player:next() end,
                                        visible = bind(player, "can-go-next"),
                                        Widget.Icon({
                                            icon = "media-skip-forward-symbolic",
                                        }),
                                    }),
                                }),
                                Widget.Label({
                                    class_name = "length",
                                    hexpand = true,
                                    halign = "END",
                                    visible = bind(player, "length"):as(
                                        function(l) return l > 0 end
                                    ),
                                    label = bind(player, "length"):as(
                                        function(l) return l > 0 and length_str(l) or "0:00" end
                                    ),
                                }),
                            }),
                        }),
                    }),
                    Widget.Label({
                        halign = "START",
                        valign = "START",
                        vexpand = true,
                        wrap = true,
                        label = lyricpiece
                    }),
                })
            end),
        })
end

local Player = function()
    local mpris = Mpris.get_default()

    return Widget.Box({
        vertical = true,
        bind(mpris, "players"):as(
            function(players) return map(players, MediaPlayer) end
        ),
    })
end

local function LyricLabels(player)
    local lyricpiece = bind(player, "position"):as(
        function(s)
            updateState(player:get_artist(), player:get_title())
            local prev, current, next = get_lyric(s)
            return prev .. "\n\n" .. current .. "\n\n" .. next
        end
    )

    return Widget.Box({
        -- SHOW_LYRICS():as(function(s)
        --     if not s then return nil end
        --     return
        Widget.Label({
            halign = "CENTER",
            valign = "CENTER",
            vexpand = true,
            wrap = true,
            label = lyricpiece
        })
        -- end)
    })
end

local Lyrics = function()
    local mpris = Mpris.get_default()

    return Widget.Box({
        vertical = true,
        visible = bind(SHOW_LYRICS):as(
            function(s) return s end
        ),
        css = "min-width: 700px; margin-bottom: 150px;",
        bind(mpris, "players"):as(
            function(players) return map(players, LyricLabels) end
        )
    })
end


return function(gdkmonitor)
    local Anchor = astal.require("Astal").WindowAnchor
    local mpris = Mpris.get_default()

    Widget.Window({
        class_name = "Lyrics",
        gdkmonitor = gdkmonitor,
        layer = "OVERLAY",
        -- exclusivity = "EXCLUSIVE",
        click_through = true,
        anchor = Anchor.BOTTOM,
        Widget.Box({
            Lyrics()
        })
    })

    Widget.Window({
        class_name = "Player",
        gdkmonitor = gdkmonitor,
        layer = "OVERLAY",
        -- exclusivity = "EXCLUSIVE",
        click_through = true,
        anchor = Anchor.TOP + Anchor.LEFT,
        Widget.Box({
            css = "opacity: 1",
            Player()
        })
    })
end
