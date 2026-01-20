if vim.g.vjvsloaded == true then return end
vim.g.vjvsloaded = true

local api = vim.api
local colorscheme = require("colorscheme")

local format = "opus"

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
local function get_file_trim_start(filename)
    return find_file_param(filename, "ts")
end

---@param filename string
---@return number | nil
local function get_file_trim_end(filename)
    return find_file_param(filename, "te")
end

---@param filename string
---@return number | nil
local function get_file_pad_start(filename)
    return find_file_param(filename, "ps")
end

---@param filename string
---@return number | nil
local function get_file_pad_end(filename)
    return find_file_param(filename, "pe")
end

---@param filename string
---@return number | nil
local function get_file_silence_start(filename)
    return find_file_param(filename, "ss")
end

---@param filename string
---@return number | nil
local function get_file_silence_end(filename)
    return find_file_param(filename, "se")
end

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
        col = vim.o.columns - width,
        row = 0,
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

-- local function get_all_buffer_files(commented)
--     local result = {}
--     local bufnr = vim.api.nvim_get_current_buf()
--     local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
--
--     for _, line in ipairs(lines) do
--         if commented or not line:match("^#") then
--             for word in string.gmatch(line, "%S+%.opus") do
--                 table.insert(result, word)
--             end
--         end
--     end
--
--     return result
-- end

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

local function merge_ffmpeg()
    local OUTPUT_DIR = "./Merged.opus"
    local list_file = "vaudiolist.txt"
    local files = get_all_buffer_files();

    local file = io.open(list_file, "w")
    for _, filename in ipairs(files) do
        file:write("file '" .. filename .. "'\n")
    end
    file:close()
    os.remove(OUTPUT_DIR)

    local output_file = "Merged.opus"
    local cmd = string.format("ffmpeg -f concat -safe 0 -i %s -c copy %s", list_file, output_file)

    vim.fn.jobstart(cmd, {
        on_exit = function(_, code)
            if code == 0 then
                print("Merge completed successfully.")
                os.remove(list_file)
            else
                print("FFmpeg failed with exit code: " .. code)
                os.remove(list_file)
            end
        end,
    })
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
    local filename = increment_filename(AUDIO_DIR .. get_first_n_words_of_paragraph(5) .. ".opus")

    if vim.fn.isdirectory(AUDIO_DIR) == 0 then
        vim.fn.mkdir(AUDIO_DIR, "p")
    end

    api.nvim_put({ filename }, "l", true, true)

    local cmd = [[
TEMPFILE="/tmp/temprec1.flac"
TRIMMED="/tmp/trimmed.wav"
OUTPUT="]] .. filename .. [["

rm -f "$TEMPFILE" "$TRIMMED" "$OUTPUT"

ffmpeg -hide_banner -loglevel error \
  -f pulse -i default \
  -ac 1 \
  -af "loudnorm=I=-14:TP=-1.5:LRA=11" \
  -c:a flac "$TEMPFILE" &

FFMPEG_PID=$!

sox -t alsa default -n silence 1 0.1 0.3% 1 0.7 0.2% &> /dev/null

kill $FFMPEG_PID 2>/dev/null
wait "$FFMPEG_PID"

sox "$TEMPFILE" "$TRIMMED" silence 1 0.1 0.3% 1 0.7 0.2%

ffmpeg -i "$TRIMMED" -c:a libopus -b:a 64k "$OUTPUT"

rm "$TEMPFILE" "$TRIMMED"
]]

    run_job({
        cmd = cmd,
        name = "recording",
    })
end

local function start_playback(file)
    run_job({
        cmd = "mpv " .. file,
        name = "playing"
    })
end

local function merge()
    local files = get_all_buffer_files()
    if #files == 0 then return end

    local filter_complex = ""
    local inputs = ""

    for i, v in ipairs(files) do
        local silence_start = get_file_silence_start(v) or 0
        local silence_end   = get_file_silence_end(v) or 0
        local pad_start     = (get_file_pad_start(v) or 0.12) * 1000
        local pad_end       = get_file_pad_end(v) or 0
        local trim_start    = get_file_trim_start(v) or 0
        local trim_end      = get_file_trim_end(v) or 0

        inputs              = inputs .. " -i " .. v

        local stream        = "[" .. (i - 1) .. ":a]"

        -- Build the trim logic
        -- 1. Trim the start normally
        -- Build the trim logic
        local filter_chain  = string.format("atrim=start=%s", trim_start)

        -- 1. Reset timestamps immediately after the first trim
        filter_chain        = filter_chain .. ",asetpts=PTS-STARTPTS"

        -- 2. Silence removal
        filter_chain        = filter_chain ..
        ",silenceremove=start_threshold=-50dB:start_duration=0.3:stop_threshold=-50dB:stop_duration=0.3"

        -- 3. The Reverse Sandwich (if needed)
        if trim_end ~= 0 then
            -- We reset PTS again after the reverse-trim to ensure the 'new' start is 0
            filter_chain = filter_chain ..
            string.format(",areverse,atrim=start=%s,asetpts=PTS-STARTPTS,areverse", trim_end)
        end

        -- 4. Delay and Padding
        -- Note: adelay naturally shifts audio forward, which is usually what you want.
        filter_chain = filter_chain .. string.format(",adelay=%s|%s,apad=pad_len=%s", pad_start, pad_start, pad_end)

        local filter = string.format("%s%s[a%d];", stream, filter_chain, i)
        filter_complex = filter_complex .. filter
    end

    -- Concatenate all processed streams
    local concat_input = ""
    for i = 1, #files do
        concat_input = concat_input .. "[a" .. i .. "]"
    end

    filter_complex = filter_complex .. concat_input .. "concat=n=" .. #files .. ":v=0:a=1[out]"

    local cmd = string.format(
        "ffmpeg -y %s -filter_complex \"%s\" -map '[out]' ./media/out.opus",
        inputs,
        filter_complex
    )

    run_job({
        cmd = cmd,
        name = "FFmpeg Merging",
    })
end

-- local function merge()
--     local command = vim.iter(get_all_buffer_files())
--         :fold("", function(acc, v)
--             local file          = v
--
--             local silence_start = get_file_silence_start(v) or 0
--             local silence_end   = get_file_silence_end(v) or 0
--             local pad_start     = get_file_pad_start(v) or 0.15
--             local pad_end       = get_file_pad_end(v) or 0
--             local trim_start    = get_file_trim_start(v) or 0
--             local trim_end      = get_file_trim_end(v) or 0
--
--             local trim_end_str  = ""
--             if trim_end ~= 0 then
--                 trim_end_str = -trim_end
--             end
--
--             file = string.format(
--                 "<(sox %s -p silence 1 0.3 %s%% reverse silence 1 0.3 %s%% reverse trim %s %s pad %s %s)",
--                 v, silence_start, silence_end, trim_start, trim_end_str, pad_start, pad_end
--             )
--
--             -- file = string.format(
--             --     "<(sox %s -p silence 1 0.3 %s%% reverse silence 1 0.3 %s%% reverse trim %s %s pad %s %s)",
--             --     v, silence_start, silence_end, trim_start, trim_end_str, pad_start, pad_end
--             -- )
--
--             return acc .. " " .. file
--         end)
--
--     local cmd = "sox" .. command .. " ./media/out.opus"
--
--     run_job({
--         cmd = cmd,
--         name = "merging",
--         on_exit = function()
--             -- local dest = "./code/src/scenes/media/out.opus"
--             -- if vim.fn.filereadable(dest) == 1 then
--             --     os.execute(string.format("cp out.opus %s", dest))
--             -- end
--         end
--     })
-- end

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
