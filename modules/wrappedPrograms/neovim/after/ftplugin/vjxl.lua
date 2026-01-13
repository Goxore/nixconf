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

ls.add_snippets("vjxl", {

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
        S.t("spawn delay(0.4, @vj.jump(\""),
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
