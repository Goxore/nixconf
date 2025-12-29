local colorscheme = require("colorscheme")
return {
    "lualine.nvim",
    lazy = false,
    after = function()
        require("lualine").setup({
            options = {
                theme = {
                    normal = {
                        a = { bg = colorscheme.blue, fg = colorscheme.bg, gui = 'bold' },
                        b = { bg = colorscheme.lightgray, fg = colorscheme.fg },
                        c = { bg = colorscheme.lightgray, fg = colorscheme.fg },
                    },
                    insert = {
                        a = { bg = colorscheme.green, fg = colorscheme.bg, gui = 'bold' },
                        b = { bg = colorscheme.lightgray, fg = colorscheme.fg },
                        c = { bg = colorscheme.lightgray, fg = colorscheme.fg },
                    },
                    visual = {
                        a = { bg = colorscheme.yellow, fg = colorscheme.bg, gui = 'bold' },
                        b = { bg = colorscheme.lightgray, fg = colorscheme.fg },
                        c = { bg = colorscheme.lightgray, fg = colorscheme.fg },
                    },
                    replace = {
                        a = { bg = colorscheme.red, fg = colorscheme.bg, gui = 'bold' },
                        b = { bg = colorscheme.lightgray, fg = colorscheme.fg },
                        c = { bg = colorscheme.bg, fg = colorscheme.fg },
                    },
                    command = {
                        a = { bg = colorscheme.magenta, fg = colorscheme.bg, gui = 'bold' },
                        b = { bg = colorscheme.lightgray, fg = colorscheme.fg },
                        c = { bg = colorscheme.lightgray, fg = colorscheme.fg },
                    },
                    inactive = {
                        a = { bg = colorscheme.bg, fg = colorscheme.gray, gui = 'bold' },
                        b = { bg = colorscheme.bg, fg = colorscheme.gray },
                        c = { bg = colorscheme.bg, fg = colorscheme.gray },
                    }
                },
                icons_enabled = true,
                component_separators = { left = '', right = '' },
                section_separators = { left = '', right = '' },
                disabled_filetypes = {
                    statusline = {},
                    winbar = {},
                },
                ignore_focus = {},
                always_divide_middle = true,
                always_show_tabline = true,
                globalstatus = true,
            },
            sections = {
                lualine_a = { 'mode' },
                lualine_b = {},
                lualine_c = { 'filename', 'branch', 'diff', 'diagnostics' },
                lualine_x = { 'encoding', 'fileformat', 'filetype' },
                lualine_y = { 'progress' },
                lualine_z = { 'location' }
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = { 'filename' },
                lualine_x = { 'location' },
                lualine_y = {},
                lualine_z = {}
            },
            tabline = {},
            winbar = {},
            inactive_winbar = {},
            extensions = {}
        })
    end
}
