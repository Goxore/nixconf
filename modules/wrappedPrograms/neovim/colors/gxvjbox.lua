local COLORSCHEME = require("colorscheme")

local highlights = {
    Bold = { style = "bold" },
    ColorColumn = { bg = COLORSCHEME.base01 },
    Conceal = { fg = COLORSCHEME.base0D, bg = COLORSCHEME.base00 },
    Cursor = { fg = COLORSCHEME.base00, bg = COLORSCHEME.base05 },
    CursorColumn = { bg = COLORSCHEME.base01 },
    CursorLine = { bg = COLORSCHEME.gray },
    CursorLineNr = { fg = COLORSCHEME.base04, bg = COLORSCHEME.gray },
    Debug = { fg = COLORSCHEME.base08 },
    Directory = { fg = COLORSCHEME.base0D },
    Error = { fg = COLORSCHEME.base00, bg = COLORSCHEME.base08 },
    ErrorMsg = { fg = COLORSCHEME.base08, bg = COLORSCHEME.base00 },
    Exception = { fg = COLORSCHEME.base08 },
    FoldColumn = { fg = COLORSCHEME.base0C, bg = COLORSCHEME.base01 },
    Folded = { fg = COLORSCHEME.base03, bg = COLORSCHEME.base01 },
    IncSearch = { fg = COLORSCHEME.base01, bg = COLORSCHEME.base09 },
    Italic = { style = "italic" },
    LineNr = { fg = COLORSCHEME.base03, bg = COLORSCHEME.base00 },
    Macro = { fg = COLORSCHEME.base09 },
    MatchParen = { bg = COLORSCHEME.base03 },
    ModeMsg = { fg = COLORSCHEME.base0B },
    MoreMsg = { fg = COLORSCHEME.base0B },
    NonText = { fg = COLORSCHEME.base03 },
    Normal = { fg = COLORSCHEME.base06, bg = COLORSCHEME.base00 },
    PMenu = { fg = COLORSCHEME.base05, bg = COLORSCHEME.base01 },
    PMenuSel = { bg = COLORSCHEME.base00, style = "none" },
    Question = { fg = COLORSCHEME.base0D },
    QuickFixLine = { bg = COLORSCHEME.base01 },
    Search = { fg = COLORSCHEME.base01, bg = COLORSCHEME.base0A },
    SignColumn = { fg = COLORSCHEME.base03, bg = COLORSCHEME.base00 },
    SpecialKey = { fg = COLORSCHEME.base03 },
    StatusLine = { fg = COLORSCHEME.base04, bg = COLORSCHEME.base02 },
    StatusLineNC = { fg = COLORSCHEME.base03, bg = COLORSCHEME.base01 },
    Substitute = { fg = COLORSCHEME.base01, bg = COLORSCHEME.base0A },
    TabLine = { fg = COLORSCHEME.base03, bg = COLORSCHEME.base01 },
    TabLineFill = { fg = COLORSCHEME.base03, bg = COLORSCHEME.base01 },
    TabLineSel = { fg = COLORSCHEME.base0B, bg = COLORSCHEME.base01 },
    Title = { fg = COLORSCHEME.base0D },
    TooLong = { fg = COLORSCHEME.base08 },
    Underlined = { fg = COLORSCHEME.base08 },
    VertSplit = { fg = COLORSCHEME.base02, bg = COLORSCHEME.base02 },
    Visual = { bg = COLORSCHEME.base02 },
    VisualNOS = { fg = COLORSCHEME.base08 },
    WarningMsg = { fg = COLORSCHEME.base08 },
    WildMenu = { fg = COLORSCHEME.base08, bg = COLORSCHEME.base0A },
    DiagnosticError = { fg = COLORSCHEME.red },
    DiagnosticHint = { fg = COLORSCHEME.yellow },
    DiagnosticInfo = { fg = COLORSCHEME.yellow },
    DiagnosticWarn = { fg = COLORSCHEME.orange },
    NormalFloat = { bg = COLORSCHEME.bg },

    -- Syntax
    Boolean = { fg = COLORSCHEME.base0E },
    Character = { fg = COLORSCHEME.base0E },
    Comment = { fg = COLORSCHEME.base03 },
    Conditional = { fg = COLORSCHEME.base08 },
    Constant = { fg = COLORSCHEME.base0E },
    Define = { fg = COLORSCHEME.base0C },
    Delimiter = { fg = COLORSCHEME.base09 },
    Float = { fg = COLORSCHEME.base0E },
    Function = { fg = COLORSCHEME.base0B },
    Identifier = { fg = COLORSCHEME.base0D },
    Include = { fg = COLORSCHEME.base0C },
    Keyword = { fg = COLORSCHEME.base08 },
    Label = { fg = COLORSCHEME.base08 },
    Number = { fg = COLORSCHEME.base0E },
    Operator = { fg = COLORSCHEME.base09 },
    PreProc = { fg = COLORSCHEME.base0C },
    Repeat = { fg = COLORSCHEME.base08 },
    Special = { fg = COLORSCHEME.base09 },
    SpecialChar = { fg = COLORSCHEME.base08 },
    Statement = { fg = COLORSCHEME.base08 },
    StorageClass = { fg = COLORSCHEME.base09 },
    String = { fg = COLORSCHEME.base0B, style = "italic" },
    Structure = { fg = COLORSCHEME.base0C },
    Tag = { fg = COLORSCHEME.base09 },
    Todo = { fg = COLORSCHEME.base0A, bg = COLORSCHEME.base01 },
    Type = { fg = COLORSCHEME.base0A },
    Typedef = { fg = COLORSCHEME.base0A },

    -- Diff
    DiffAdd = { fg = COLORSCHEME.base0B, bg = COLORSCHEME.base01 },
    DiffChange = { fg = COLORSCHEME.base03, bg = COLORSCHEME.base01 },
    DiffDelete = { fg = COLORSCHEME.base08, bg = COLORSCHEME.base01 },
    DiffText = { fg = COLORSCHEME.base0D, bg = COLORSCHEME.base01 },

    -- Plugin-specific
    AlphaButtons = { fg = COLORSCHEME.green },
    AlphaHeader = { fg = COLORSCHEME.yellow },
    BionicReadingHL = { fg = COLORSCHEME.blue },
    FloatBorder = { fg = COLORSCHEME.blue, bg = COLORSCHEME.bg },
    GitSignsAdd = { fg = COLORSCHEME.green },
    GitSignsChange = { fg = COLORSCHEME.blue },
    GitSignsDelete = { fg = COLORSCHEME.red },
    LspSagaCodeActionBorder = { fg = COLORSCHEME.magenta },
    LspSagaCodeActionContent = { fg = COLORSCHEME.blue },
    LspSagaHoverBorder = { fg = COLORSCHEME.yellow },
    LspSagaLightBulb = { fg = COLORSCHEME.fg },
    LspSagaRenameBorder = { fg = COLORSCHEME.magenta },
    LspSagaSignatureHelpBorder = { fg = COLORSCHEME.yellow },
    NvimTreeImageFile = { fg = COLORSCHEME.yellow },
    NvimTreeSpecialFile = { fg = COLORSCHEME.red },
    TelescopeBorder = { fg = COLORSCHEME.red },
    TelescopeMatching = { fg = COLORSCHEME.orange, style = "bold" },
    TelescopePreviewBorder = { fg = COLORSCHEME.cyan },
    TelescopePromptBorder = { fg = COLORSCHEME.cyan },
    TelescopePromptPrefix = { fg = COLORSCHEME.green },
    TelescopeResultsBorder = { fg = COLORSCHEME.cyan },

    ["@vjv_embed"] = { bg = "#181818" },
    ["@type"] = { fg = COLORSCHEME.cyan, style = "bold" },
    ["@variable"] = { fg = COLORSCHEME.blue },
    ["@variable.parameter"] = { fg = COLORSCHEME.blue2, style = "bold" },
    ["@tag"] = { fg = COLORSCHEME.red },
    ["@tag.delimiter"] = { fg = COLORSCHEME.red },
    ["@function"] = { fg = COLORSCHEME.green, style = "italic,bold" },
    ["@text"] = { fg = COLORSCHEME.fg },
    ["@none"] = { fg = COLORSCHEME.fg },
    ["@punctuation"] = { fg = COLORSCHEME.orange },
    ["@lsp.type.class"] = { fg = COLORSCHEME.cyan },
    ["@lsp.mod.annotation"] = { fg = COLORSCHEME.orange },

    ["@lsp.type.enum"] = { link = "@type" },
    ["@lsp.type.interface"] = { link = "@type" },
    ["@lsp.type.namespace"] = { link = "@namespace" },
    ["@lsp.type.parameter"] = { link = "@variable.parameter" },
    ["@lsp.type.property"] = { link = "@property" },
    ["@lsp.type.variable"] = { link = "@variable" },
}

local lualine_theme = {
    normal = {
        a = { bg = COLORSCHEME.blue, fg = COLORSCHEME.bg, gui = 'bold' },
        b = { bg = COLORSCHEME.lightgray, fg = COLORSCHEME.fg },
        c = { bg = COLORSCHEME.lightgray, fg = COLORSCHEME.fg },
    },
    insert = {
        a = { bg = COLORSCHEME.green, fg = COLORSCHEME.bg, gui = 'bold' },
        b = { bg = COLORSCHEME.lightgray, fg = COLORSCHEME.fg },
        c = { bg = COLORSCHEME.lightgray, fg = COLORSCHEME.fg },
    },
    visual = {
        a = { bg = COLORSCHEME.yellow, fg = COLORSCHEME.bg, gui = 'bold' },
        b = { bg = COLORSCHEME.lightgray, fg = COLORSCHEME.fg },
        c = { bg = COLORSCHEME.lightgray, fg = COLORSCHEME.fg },
    },
    replace = {
        a = { bg = COLORSCHEME.red, fg = COLORSCHEME.bg, gui = 'bold' },
        b = { bg = COLORSCHEME.lightgray, fg = COLORSCHEME.fg },
        c = { bg = COLORSCHEME.bg, fg = COLORSCHEME.fg },
    },
    command = {
        a = { bg = COLORSCHEME.magenta, fg = COLORSCHEME.bg, gui = 'bold' },
        b = { bg = COLORSCHEME.lightgray, fg = COLORSCHEME.fg },
        c = { bg = COLORSCHEME.lightgray, fg = COLORSCHEME.fg },
    },
    inactive = {
        a = { bg = COLORSCHEME.bg, fg = COLORSCHEME.gray, gui = 'bold' },
        b = { bg = COLORSCHEME.bg, fg = COLORSCHEME.gray },
        c = { bg = COLORSCHEME.bg, fg = COLORSCHEME.gray },
    },
}

local function apply_highlights()
    vim.cmd("hi clear")
    if vim.fn.exists("syntax_on") == 1 then
        vim.cmd("syntax reset")
    end
    vim.o.termguicolors = true
    vim.g.colors_name = "vjbox"

    for group, settings in pairs(highlights) do
        local command = "highlight " .. group
        if settings.link then
            command = "highlight!" .. " link " .. group .. " " .. settings.link
        else
            if settings.fg then command = command .. " guifg=" .. settings.fg end
            if settings.bg then command = command .. " guibg=" .. settings.bg end
            if settings.style then command = command .. " gui=" .. settings.style end
            if settings.guisp then command = command .. " guisp=" .. settings.guisp end
        end
        vim.cmd(command)
    end

    -- Terminal colors
    vim.g.terminal_color_0 = COLORSCHEME.base00
    vim.g.terminal_color_1 = COLORSCHEME.base08
    vim.g.terminal_color_2 = COLORSCHEME.base0B
    vim.g.terminal_color_3 = COLORSCHEME.base0A
    vim.g.terminal_color_4 = COLORSCHEME.base0D
    vim.g.terminal_color_5 = COLORSCHEME.base0E
    vim.g.terminal_color_6 = COLORSCHEME.base0C
    vim.g.terminal_color_7 = COLORSCHEME.base05
    vim.g.terminal_color_8 = COLORSCHEME.base03
    vim.g.terminal_color_9 = COLORSCHEME.base08
    vim.g.terminal_color_10 = COLORSCHEME.base0B
    vim.g.terminal_color_11 = COLORSCHEME.base0A
    vim.g.terminal_color_12 = COLORSCHEME.base0D
    vim.g.terminal_color_13 = COLORSCHEME.base0E
    vim.g.terminal_color_14 = COLORSCHEME.base0C
    vim.g.terminal_color_15 = COLORSCHEME.base07
    vim.g.terminal_color_background = COLORSCHEME.base00
    vim.g.terminal_color_foreground = COLORSCHEME.base05
end

apply_highlights()

-- Additional config
vim.cmd [[
    set fillchars=fold:\ ,vert:\│,eob:\ ,msgsep:‾,diff:╱
]]
