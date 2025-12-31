vim.bo.commentstring = "// %s"

vim.bo.tabstop = 2
vim.bo.shiftwidth = 2
vim.bo.expandtab = true

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

--- @param nav_method string
local function nav_snippet(nav_method)
    return S.fmt(
        [[
await @nav.{}(@p{} Rect {{ size: [1920,1080]
  {}
}})
        ]],
        {
            S.t(nav_method),
            S.f(function() return tostring(next_p_number_from_buffer()) end),
            S.i(1)
        }
    )
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

ls.add_snippets("vjxl", {

    S.s("point", {
        S.d(2, function()
            local register_data = vim.fn.getreg() .. "";
            if string.match(register_data, "[%d-]+,%s*[%d-]+") then
                return S.sn(nil, {
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

    S.s("back", S.fmt(
        [[await @scene.back()]],
        {
        })),

    S.s("slide", {
        S.t("await @scene.slide(\"right\")")
    }),

    S.s("yw", {
        S.t("await waitUntil(\""), S.f(next_unused_from_buffer), S.t("\")")
    }),

    S.s("ya", S.fmt(
        [[
    await @scene.add(
        {}
    )
    ]],
        {
            S.i(1)
        })),

    S.s("right", nav_snippet("right")),

    S.s("push", nav_snippet("push")),

    S.s("size1", { S.t("size: [1920,1080]") }),
    S.s("size2", { S.t("size: [1800,960]") }),
    S.s("size3", { S.t("size: [1720,880]") }),

    S.s("jump", S.fmt([[
    await @vj.jump("{}")
    ]], { S.i(1, "idle") })),

    S.s("all", S.fmt([[
    await allPrime([
      {},
    ])
    ]], { S.i(1, "idle") })),

    S.s("add",
        S.fmt(
            [[
await addReveal(@p{}, Rect {{
  Opacity {{
      {}
  }}
}})
        ]],
            {
                S.f(function()
                    local n = latest_p_before_cursor()
                    return tostring(n or 1)
                end),
                S.i(1)
            }
        ))

}, opts)
