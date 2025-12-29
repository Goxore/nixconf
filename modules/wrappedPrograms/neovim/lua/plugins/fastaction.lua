return {
    "fastaction.nvim",
    after = function()
        require("fastaction").setup({
            dismiss_keys = { "j", "k", "<c-c>", "q" },
            keys = "wertyuiopasdfghlzxcvbnm",
            popup = {
                border = "single",
                hide_cursor = false,
                highlight = {
                    divider = "FloatBorder",
                    key = "MoreMsg",
                    -- title = "Title",
                    window = "NormalFloat",
                },
                title = "Select one of:",
            },
            priority = {
                dart = {
                    { pattern = "organize import", key = "o", order = 1 },
                    { pattern = "extract method",  key = "x", order = 2 },
                    { pattern = "extract widget",  key = "e", order = 3 },
                },
                typescript = {
                    { pattern = 'to existing import declaration', key = 'a', order = 2 },
                    { pattern = 'from module',                    key = 'i', order = 1 },
                }
            }
        })
    end,
    keys = {
        { "<leader>a", function() require("fastaction").code_action() end, desc = "fast action" },
    }
}
