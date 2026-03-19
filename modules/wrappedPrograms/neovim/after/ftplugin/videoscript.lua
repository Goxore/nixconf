if vim.g.vjvsloaded == true then return end
vim.g.vjvsloaded = true

local api = vim.api
local colorscheme = require("colorscheme")

local AUDIO_DIR = "./audio/"

---@type uv.uv_process_t | nil
local job = nil

---@type integer | nil
local win_id = nil

---@type integer | nil
local buf_id = nil

vim.bo.commentstring = "# %s"

---@param filename string
---@param code string
---@return number | nil
local function find_file_param(filename, code)
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local escaped = filename:gsub("([%.%+%-%*%?%[%]%^%$%%()])", "%%%1")
    local pattern = escaped .. ".*" .. code .. "%s+(%-?%d+%.?%d*)"
    for _, line in ipairs(lines) do
        local value = line:match(pattern)
        if value then
            return tonumber(value)
        end
    end
    return nil
end

---@param filename string
---@return number | nil
local function get_file_trim_start(filename) return find_file_param(filename, "ts") end

---@param filename string
---@return number | nil
local function get_file_trim_end(filename) return find_file_param(filename, "te") end

---@param filename string
---@return number | nil
local function get_file_pad_start(filename) return find_file_param(filename, "ps") end

---@param filename string
---@return number | nil
local function get_file_pad_end(filename) return find_file_param(filename, "pe") end

---@param filename string
---@return number | nil
local function get_file_silence_start(filename) return find_file_param(filename, "ss") end

---@param filename string
---@return number | nil
local function get_file_silence_end(filename) return find_file_param(filename, "se") end

---@return nil
local function stop_process()
    if job then
        vim.uv.process_kill(job, "sigterm")
        job:close()
        job = nil
    end

    vim.schedule(function()
        if win_id and api.nvim_win_is_valid(win_id) then
            api.nvim_win_close(win_id, true)
            win_id = nil
        end
        if buf_id and api.nvim_buf_is_valid(buf_id) then
            api.nvim_buf_delete(buf_id, { force = true })
            buf_id = nil
        end
    end)
end

---@return nil
---@param params {cmd: string, name: string, on_exit: fun()?}
local function run_job(params)
    job = vim.uv.spawn("bash", {
        args = {
            "-c", params.cmd,
        },
        stdio = { nil, nil, nil }
    }, function()
        stop_process()
        if params.on_exit then
            params.on_exit()
        end
    end)

    buf_id = api.nvim_create_buf(false, true)
    local width = 20
    local height = 2
    local opts = {
        relative = "editor",
        width = width,
        height = height,
        col = vim.o.columns - width - 2,
        row = vim.o.lines - height - 3,
        -- col = vim.o.columns - width,
        -- row = 0,
        style = "minimal",
        border = "single",
    }
    win_id = api.nvim_open_win(buf_id, true, opts)
    api.nvim_buf_set_lines(buf_id, 0, -1, false, { params.name, "Press q to stop" })

    vim.keymap.set("n", "q", function()
        stop_process()
    end, { buffer = buf_id })
end

local function get_all_buffer_files(commented)
    local result = {}
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    for _, line in ipairs(lines) do
        if commented or not line:match("^#") then
            for word in line:gmatch("%S+%.(%w+)") do
                if word == "opus" or word == "wav" then
                    table.insert(result, line:match("%S+%." .. word))
                end
            end
        end
    end

    return result
end

---@return string[]
local function get_all_audio()
    return vim.fn.glob(AUDIO_DIR .. "*", true, true)
end

---@return string[]
local function get_unused_all_audio()
    return vim.iter(get_all_audio())
        :filter(function(filename)
            return not vim.iter(get_all_buffer_files(true)):any(function(f) return f == filename end)
        end)
        :totable()
end

local function show_to_clean()
    vim.iter(get_unused_all_audio())
        :each(function(f)
            print("TO REMOVE " .. f)
        end)
end

local function clean()
    vim.iter(get_unused_all_audio())
        :each(function(f)
            print("REMOVED " .. f)
            os.remove(f)
        end)
end

local function get_first_n_words_of_paragraph(n)
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
    local buf = vim.api.nvim_get_current_buf()

    local line_num = cursor_row
    while line_num > 1 do
        local line = vim.api.nvim_buf_get_lines(buf, line_num - 2, line_num - 1, false)[1]
        if line == "" or line:match("^[.#]") then
            break
        end
        line_num = line_num - 1
    end

    local lines = vim.api.nvim_buf_get_lines(buf, line_num - 1, cursor_row, false)
    local paragraph = table.concat(lines, " ")

    local words = {}
    for word in paragraph:gmatch("%S+") do
        table.insert(words, word)
        if #words == n then break end
    end

    return string.lower(table.concat(words, "_"):gsub("[^%w_]", ""))
end

---@return string new_filepath
local function increment_filename(filepath)
    local base_name, ext = filepath:match("^(.*)%.(.*)$")
    local counter = 1
    local new_filepath = filepath

    while vim.fn.filereadable(new_filepath) == 1 do
        new_filepath = string.format("%s%d.%s", base_name, counter, ext)
        counter = counter + 1
    end

    return new_filepath
end

---@return nil
local function start_recording()
    local filename =
        increment_filename(AUDIO_DIR .. get_first_n_words_of_paragraph(5) .. ".opus")

    if vim.fn.isdirectory(AUDIO_DIR) == 0 then
        vim.fn.mkdir(AUDIO_DIR, "p")
    end

    api.nvim_put({ filename }, "l", true, true)

    local cmd = ([[
set -euo pipefail
IFS=$'\n\t'

LOG="/tmp/recording.log"

exec > >(tee -a "$LOG") 2>&1

sox -v 1.0 -t alsa default -t wav - remix 1 silence 1 0.1 0.3%% 1 0.7 0.2%% | \
ffmpeg -hide_banner -loglevel info -y \
  -i - \
  -c:a libopus \
  -b:a 64k \
  "%s"
]]):format(filename)

    --     local cmd = ([[
    -- set -euo pipefail
    -- IFS=$'\n\t'
    --
    -- LOG="/tmp/recording.log"
    --
    -- exec > >(tee -a "$LOG") 2>&1
    --
    -- sox -v 1.0 -t alsa default -t wav - remix 1 silence 1 0.1 0.3%% 1 0.7 0.2%% | \
    -- ffmpeg -hide_banner -loglevel info -y \
    --   -i - \
    --   -af "loudnorm=I=-14:TP=-1.5:LRA=11" \
    --   -c:a libopus \
    --   -b:a 64k \
    --   "%s"
    -- ]]):format(filename)

    run_job({
        name = "recording",
        cmd = cmd,
    })
end

local function start_playback(file)
    run_job({
        cmd = "mpv " .. file,
        name = "playing"
    })
end

---@param filename string
---@return number
function get_file_pause_before(filename)
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local escaped = filename:gsub("([%.%+%-%*%?%[%]%^%$%%()])", "%%%1")
    local pause_keywords = { short = 0.2, medium = 0.4, long = 0.6 }

    local file_line = nil
    for i, line in ipairs(lines) do
        if line:match(escaped) then
            file_line = i
            break
        end
    end

    if not file_line then return 0 end

    for i = file_line - 1, 1, -1 do
        local trimmed = lines[i]:match("^%s*(.-)%s*$")
        if trimmed == "" then
            return 0
        elseif pause_keywords[trimmed] then
            return pause_keywords[trimmed]
        end
    end

    return 0
end

local function merge()
    local files = get_all_buffer_files()
    if #files == 0 then return end

    local filter_chains = vim.iter(ipairs(files)):map(function(i, v)
        local pad_start = ((get_file_pad_start(v) or 0.12) + get_file_pause_before(v)) * 1000

        -- local chain = {
        --     string.format("atrim=start=%s", get_file_trim_start(v) or 0),
        --     "asetpts=PTS-STARTPTS",
        --     "highpass=f=80,lowpass=f=15000",
        --     "adeclick=o=75",
        --     "silenceremove=start_threshold=-50dB:start_duration=0.3:stop_threshold=-50dB:stop_duration=0.3"
        -- }

        local chain = {
            string.format("atrim=start=%s", get_file_trim_start(v) or 0),
            "asetpts=PTS-STARTPTS",
            "highpass=f=80",
            "acompressor=threshold=-18dB:ratio=2:attack=10:release=80",
            -- "adeclick=o=75",
            -- "asetpts=PTS-STARTPTS",
            -- "highpass=f=90,lowpass=f=14000",
            -- "equalizer=f=200:width_type=o:width=1.0:g=-3",
            -- "equalizer=f=3500:width_type=o:width=1.0:g=2",
            -- "acompressor=threshold=-18dB:ratio=3:attack=5:release=50",
            -- "agate=threshold=-30dB:ratio=2:attack=20:release=250:range=0.05",
            -- "silenceremove=start_threshold=-40dB:start_duration=0.2:stop_threshold=-40dB:stop_duration=0.2"
            "silenceremove=start_threshold=-50dB:start_duration=0.3:stop_threshold=-50dB:stop_duration=0.3"
        }

        local trim_end = get_file_trim_end(v) or 0
        if trim_end ~= 0 then
            table.insert(chain, string.format("areverse,atrim=start=%s,asetpts=PTS-STARTPTS,areverse", trim_end))
        end

        table.insert(chain, string.format("adelay=%s|%s", pad_start, pad_start))
        table.insert(chain, string.format("apad=pad_len=%s", get_file_pad_end(v) or 0))

        return string.format("[%d:a]%s[a%d]", i - 1, table.concat(chain, ","), i)
    end):totable()

    local inputs = vim.iter(files):map(function(v)
        return "-i " .. v
    end):join(" ")

    local labels = vim.iter(ipairs(files)):map(function(i)
        return "[a" .. i .. "]"
    end):join("")

    local filter_complex = string.format(
        "%s;%sconcat=n=%d:v=0:a=1[out_raw];[out_raw]loudnorm=I=-14:TP=-1.5:LRA=11[out]",
        table.concat(filter_chains, ";"),
        labels,
        #files
    )

    run_job({
        cmd = string.format("ffmpeg -y %s -filter_complex \"%s\" -map '[out]' ./media/out.flac 2> /tmp/merge.log",
            inputs,
            filter_complex),
        name = "FFmpeg Merging",
    })
end

vim.keymap.set("n", "r", function()
    start_recording()
end, { buffer = vim.api.nvim_get_current_buf() })
vim.keymap.set("n", "R", function()
    start_recording()
end, { buffer = vim.api.nvim_get_current_buf() })

vim.keymap.set("n", "<RightMouse>", function()
    start_recording()
end, { buffer = vim.api.nvim_get_current_buf() })

vim.keymap.set("n", "l", function()
    local word = vim.fn.expand("<cfile>")
    if word:match("%.opus$") or word:match("%.wav$") then
        start_playback(word)
    else
        vim.api.nvim_feedkeys("l", "n", false)
    end
end, { noremap = true, silent = true })

vim.keymap.set("n", "do", function()
    local word = vim.fn.expand("<cWORD>")
    vim.fn.jobstart("ripdrag " .. word, { detach = true })
end, { desc = "Run ripdrag on <cWORD>" })

vim.fn.matchadd("Audiofile", "\\v\\S+\\.wav")
vim.fn.matchadd("Audiofile", "\\v\\S+\\.opus")
vim.cmd("highlight Audiofile guifg=" .. colorscheme.magenta)

vim.fn.matchadd("Comment", "\\v#.*")

vim.fn.matchadd("Pausekeyword", "\\v(short|medium|long)$")
vim.cmd("highlight Pausekeyword guifg=" .. colorscheme.red)

vim.api.nvim_create_user_command('Merge', function(args)
        merge()
    end,
    { nargs = 0, desc = 'Create Scene' }
)

vim.api.nvim_create_user_command('Clean', function(args)
        show_to_clean()
        local choice = vim.fn.input("Clean" .. " (y/n): ")
        if choice:lower() == "y" then
            clean()
        end
    end,
    { nargs = 0, desc = 'Create Scene' }
)
