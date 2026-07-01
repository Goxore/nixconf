vim.bo.commentstring = "// %s"

vim.bo.tabstop = 2
vim.bo.shiftwidth = 2
vim.bo.expandtab = true

AUTOWAIT = true

-- ================================================================ --
-- =                           Snippets                           = --
-- ================================================================ --
--- @type LuaSnip.API
local ls = require("luasnip")
local S = require("ls-shorthands")

--- @alias UsedSymbols table<string, boolean>

--- @return string[]
local function build_symbol_sequence()
    local seq = {}

    for c = string.byte('a'), string.byte('z') do
        seq[#seq + 1] = string.char(c)
    end
    for c = string.byte('A'), string.byte('Z') do
        seq[#seq + 1] = string.char(c)
    end
    for c = string.byte('0'), string.byte('9') do
        seq[#seq + 1] = string.char(c)
    end
    local extras = { '+', '-', '_', '=', '@', '#', '$', '%', '&', '*', '🐟', '🐴' }
    for _, sym in ipairs(extras) do
        seq[#seq + 1] = sym
    end

    return seq
end

--- @return UsedSymbols
local function collect_used_symbols()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local pattern = 'waitUntil%(%s*"(.-)"%s*%)'

    local used = {}
    vim.iter(lines)
        :map(function(line) return line:match(pattern) end)
        :filter(function(sym) return sym ~= nil end)
        :each(function(sym) used[sym] = true end)

    return used
end

--- @param used UsedSymbols
--- @return string
local function pick_next_unused(used)
    local sequence = build_symbol_sequence()
    for _, sym in ipairs(sequence) do
        if not used[sym] then
            return sym
        end
    end
    return "0"
end

--- @return string
local function next_unused_from_buffer()
    local used = collect_used_symbols()
    return pick_next_unused(used)
end

--- @return table<number, boolean>
local function collect_used_p_numbers()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    local used = {}

    vim.iter(lines)
        :map(function(line)
            return vim.iter(line:gmatch("@p(%d+)"))
                :map(tonumber)
                :totable()
        end)
        :flatten()
        :each(function(n)
            used[n] = true
        end)

    return used
end

--- @return number
local function next_p_number_from_buffer()
    local used = collect_used_p_numbers()

    return vim.iter(vim.tbl_keys(used))
        :map(tonumber)
        :fold(0, math.max) + 1
end

--- @param index number
--- @param nav_method string
local function nav_snippet(index, nav_method)
    return S.sn(index, {
        S.t("await @nav."),
        S.t(nav_method),
        S.t("("),
        S.f(function() return "@p" .. tostring(next_p_number_from_buffer()) end),
        S.t(" Rect { size: [1920,1080]"),
        S.t({ "", "  " }),
        S.i(1),
        S.t({ "", "})" }),
    })
end


--- @return number|nil
local function latest_p_before_cursor()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor_line - 1, false)

    local nums = vim.iter(lines)
        :map(function(line)
            return vim.iter(line:gmatch("@p(%d+)"))
                :map(tonumber)
                :totable()
        end)
        :flatten()
        :totable()

    if #nums == 0 then return nil end
    return nums[#nums]
end


--- @type LuaSnip.Opts.AddSnippets
local opts = {
    key = "vjxlmain"
}

--- @return boolean
local function wait_until_before_cursor()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor_line - 1, false)

    --- @type string
    local nonempty = vim.iter(lines)
        :rfind(function(v)
            return string.len(v) ~= 0 and v ~= ""
        end)

    return string.match(nonempty, "waitUntil") ~= nil
end


local anchornode = function()
    return S.sn(nil,
        {
            S.t("await waitUntil(\""),
            S.f(next_unused_from_buffer),
            S.t("\")")
        }
    )
end

--- @param insert_new_line boolean?
--- @param index number?
--- @return LuaSnip.Node
local opt_anchornode = function(index, insert_new_line)
    return S.sn(index, {
        S.d(1, function(args)
            if not wait_until_before_cursor() then
                if insert_new_line == true then
                    return S.sn(1, { anchornode(), S.t({ "", "" }) })
                end
                return S.sn(1, { anchornode() })
            end
            return S.sn(1, { S.t(""), })
        end)
    })
end

--- @param index number?
local autowait = function(index)
    return S.sn(index, {
        S.d(1, function(args)
            if not AUTOWAIT then return S.sn(1, { S.t("") }) end
            return opt_anchornode(1, true)
        end)
    })
end

local function fetch_github_data(repo_path)
    local cmd = string.format(
        "curl -s https://api.github.com/repos/%s | jq -rc '.name, .owner.login, .stargazers_count, .forks_count, .description'",
        repo_path
    )
    local handle = io.popen(cmd)
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()

    local lines = {}
    for line in result:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    if #lines < 5 then return nil end

    return {
        name = lines[1],
        user = lines[2],
        stars = lines[3],
        forks = lines[4],
        desc = lines[5]
    }
end

ls.add_snippets("vjxl", {
    S.s("gh", {
        S.t("Github { \""),
        S.i(1, "owner/repo"),
        S.t("\""),
        S.d(2, function(args)
            local path = args[1][1]
            if not path:match(".+/.+") then
                return S.sn(nil, { S.t(" }") })
            end

            local data = fetch_github_data(path)
            if not data then
                return S.sn(nil, { S.t("") })
            end

            return S.sn(nil, {
                S.t(string.format(
                    ' user: "%s" repo: "%s" desc: "%s" forks: "%s" stars: %s }',
                    data.user, data.name, data.desc, data.forks, data.stars
                ))
            })
        end, { 1 }),
    }),

    S.s("point", {
        S.d(2, function()
            local register_data = vim.fn.getreg() .. "";
            if string.match(register_data, "[%d-]+,%s*[%d-]+") then
                return S.sn(nil, {
                    autowait(1),
                    S.t("await @scene.point([" .. register_data .. "], 90)"),
                })
            else
                print("register does not contain the pattern")
                return S.sn(nil, {
                    S.t(""),
                })
            end
        end),
        S.i(1),
    }),

    S.s("back", {
        autowait(1),
        S.t([[await @scene.back()]])
    }),

    S.s("slide", {
        S.t("await @scene.slide(\"right\")")
    }),

    S.s("yw", { opt_anchornode(1) }),

    S.s("ya", S.fmt(
        [[
    {}await @scene.add(
        {}
    )
    ]],
        {
            autowait(1), S.i(2)
        })),

    S.s("right", {
        autowait(1),
        nav_snippet(2, "right")
    }),

    S.s("push", {
        autowait(1),
        nav_snippet(2, "push")
    }),

    S.s("size1", { S.t("size: [1920,1080]") }),
    S.s("size2", { S.t("size: [1800,960]") }),
    S.s("size3", { S.t("size: [1720,880]") }),


    S.s("jump", {
        autowait(1),
        S.t("await @vj.jump(\""),
        S.i(2, "idle"),
        S.t("\")"),
    }),

    S.s("djump", {
        autowait(1),
        S.t("spawn delay(0.1, @vj.jump(\""),
        S.i(2, "idle"),
        S.t("\"))"),
    }),

    S.s("all", {
        autowait(1),
        S.t("await allPrime(["),
        S.newline(), S.t("  "), S.i(2), S.t(","),
        S.newline(), S.t("])"),
    }),

    S.s("add",
        S.fmt(
            [[
{}await addReveal({}, Rect {{
  Opacity {{
      {}
  }}
}})
        ]],
            {
                autowait(1),
                S.f(function()
                    local n = latest_p_before_cursor()
                    return "@p" .. tostring(n or 1)
                end),
                S.i(2)
            }
        ))

}, opts)


vim.fn.matchadd("Comment", "\\v\\await waitUntil\\(\".*\"\\)")

local run = function(cmd, input)
    local result = vim.system(cmd, { stdin = input, text = true }):wait()
    return result.stdout
end

local format = function()
    local buf = 0
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local input = table.concat(lines, "\n")

    local output = run({ "format-vjxl" }, input)

    local new_lines = vim.split(output, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
end

vim.keymap.set("n", "<leader>FF", format)

-- ================================================================ --
-- =                            AUDIO                             = --
-- ================================================================ --

if vim.g.vjvsloaded == true then return end
vim.g.vjvsloaded = true

local api = vim.api
local colorscheme = require("colorscheme")

local AUDIO_DIR = "./audio/"
local AUDIO_SIGIL = "§"

---@type uv.uv_process_t | nil
local job = nil

---@type integer | nil
local job_pid = nil

---@type integer | nil
local win_id = nil

---@type integer | nil
local buf_id = nil

vim.bo.commentstring = "// %s"

---@param short string e.g. "§whatever.flac"
---@return string e.g. "./audio/whatever.flac"
local function short_to_path(short)
    local name = short:gsub("^" .. AUDIO_SIGIL, "")
    return AUDIO_DIR .. name
end

---@param path string e.g. "./audio/whatever.flac"
---@return string e.g. "§whatever.flac"
local function path_to_short(path)
    local name = path:gsub("^" .. AUDIO_DIR:gsub("([%.%+%-%*%?%[%]%^%$%%()])", "%%%1"), "")
    return AUDIO_SIGIL .. name
end

---@param filename string short form, e.g. "§whatever.flac", or bare name
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
    if job and job_pid then
        -- kill the whole process group (sox + ffmpeg piped under bash),
        -- not just the bash handle libuv is tracking
        pcall(function() vim.uv.kill(-job_pid, "sigterm") end)
        if job:is_active() then
            job:close()
        end
        job = nil
        job_pid = nil
    end

    vim.schedule(function()
        pcall(function()
            if win_id and api.nvim_win_is_valid(win_id) then
                api.nvim_win_close(win_id, true)
            end
        end)
        win_id = nil

        pcall(function()
            if buf_id and api.nvim_buf_is_valid(buf_id) then
                api.nvim_buf_delete(buf_id, { force = true })
            end
        end)
        buf_id = nil
    end)
end

---@return nil
---@param params {cmd: string, name: string, on_exit: fun()?}
local function run_job(params)
    local handle, pid = vim.uv.spawn("bash", {
        args = {
            "-c", params.cmd,
        },
        stdio = { nil, nil, nil },
        detached = true, -- own process group so we can kill children too
    }, function()
        stop_process()
        if params.on_exit then
            params.on_exit()
        end
    end)

    job = handle
    job_pid = pid

    buf_id = api.nvim_create_buf(false, true)
    local width = 20
    local height = 2
    local opts = {
        relative = "editor",
        width = width,
        height = height,
        col = vim.o.columns - width - 2,
        row = vim.o.lines - height - 3,
        style = "minimal",
        border = "single",
    }
    win_id = api.nvim_open_win(buf_id, true, opts)
    api.nvim_buf_set_lines(buf_id, 0, -1, false, { params.name, "Press q to stop" })

    vim.keymap.set("n", "q", function()
        stop_process()
    end, { buffer = buf_id })
end

---@param commented boolean | nil
---@return string[] full ./audio/ paths referenced via §name.ext in the buffer
local function get_all_buffer_files(commented)
    local result = {}
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    for _, line in ipairs(lines) do
        if commented or not line:match("^//") then
            for short in line:gmatch(AUDIO_SIGIL .. "%S+%.%w+") do
                table.insert(result, short_to_path(short))
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
        if line == "" or line:match("^[.#/]") then
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

---@return boolean true if the line under the cursor referenced a §file and got commented out
local function comment_out_audio_line_under_cursor()
    local bufnr = vim.api.nvim_get_current_buf()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]

    if not line then return false end
    if line:match("^%s*//") then return false end -- already commented out
    if not line:match(AUDIO_SIGIL .. "%S+%.%w+") then return false end

    local commented = "// " .. line
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { commented })
    return true
end

---@return nil
local function start_recording()
    local filename =
        increment_filename(AUDIO_DIR .. get_first_n_words_of_paragraph(5) .. ".opus")

    if vim.fn.isdirectory(AUDIO_DIR) == 0 then
        vim.fn.mkdir(AUDIO_DIR, "p")
    end

    -- if we're re-recording over an existing §file line, comment the old
    -- one out first so we don't end up with two live references
    comment_out_audio_line_under_cursor()

    api.nvim_put({ path_to_short(filename) }, "l", false, true)

    local cmd = ([[
set -euo pipefail
IFS=$'\n\t'
trap 'kill 0 2>/dev/null' EXIT TERM INT

LOG="/tmp/recording.log"

exec > >(tee -a "$LOG") 2>&1

sox -v 1.0 -t alsa default -t wav - remix 1 silence 1 0.1 0.3%% 1 0.7 0.2%% | \
ffmpeg -hide_banner -loglevel info -y \
  -i - \
  -c:a libopus \
  -b:a 64k \
  "%s"
]]):format(filename)

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
    local pause_keywords = {
        [AUDIO_SIGIL .. "veryshort"] = 0.1,
        [AUDIO_SIGIL .. "short"] = 0.2,
        [AUDIO_SIGIL .. "medium"] = 0.4,
        [AUDIO_SIGIL .. "long"] = 0.6,
        [AUDIO_SIGIL .. "verylong"] = 1,
        [AUDIO_SIGIL .. "superlong"] = 1.5,
        [AUDIO_SIGIL .. "megalong"] = 2,
        [AUDIO_SIGIL .. "gigalong"] = 2.5,
    }

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
        local pad_start = ((get_file_pad_start(path_to_short(v)) or 0.12) + get_file_pause_before(path_to_short(v))) * 1000

        local chain = {
            string.format("atrim=start=%s", get_file_trim_start(path_to_short(v)) or 0),
            "asetpts=PTS-STARTPTS",
            "highpass=f=80",
            "acompressor=threshold=-18dB:ratio=2:attack=10:release=80",
            "silenceremove=start_threshold=-50dB:start_duration=0.3:stop_threshold=-50dB:stop_duration=0.3"
        }

        local trim_end = get_file_trim_end(path_to_short(v)) or 0
        if trim_end ~= 0 then
            table.insert(chain, string.format("areverse,atrim=start=%s,asetpts=PTS-STARTPTS,areverse", trim_end))
        end

        table.insert(chain, string.format("adelay=%s|%s", pad_start, pad_start))
        table.insert(chain, string.format("apad=pad_len=%s", get_file_pad_end(path_to_short(v)) or 0))

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
        cmd = string.format("ffmpeg -y %s -filter_complex \"%s\" -map '[out]' -c:a libopus -b:a 64k ./media/out.opus 2> /tmp/merge.log",
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
    if word:match("^" .. AUDIO_SIGIL) then
        start_playback(short_to_path(word))
    elseif word:match("%.opus$") or word:match("%.wav$") then
        start_playback(word)
    else
        vim.api.nvim_feedkeys("l", "n", false)
    end
end, { noremap = true, silent = true })

vim.keymap.set("n", "do", function()
    local word = vim.fn.expand("<cWORD>")
    vim.fn.jobstart("ripdrag " .. word, { detach = true })
end, { desc = "Run ripdrag on <cWORD>" })

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
-- ================================================================ --
-- =                            OTHER                             = --
-- ================================================================ --

local vim = vim
local opt = vim.opt

vim.wo.foldmethod = "expr"
vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.wo.foldlevel = 99  -- start with everything unfolded

vim.api.nvim_create_autocmd("FileType", {
  pattern = "vjxl",
  callback = function()
    vim.wo.foldmethod = "expr"
    vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
  end,
})

-- vim.treesitter.set_query("vjxl", "folds", [[
--   (Statement_UltraComent) @fold
-- ]])
