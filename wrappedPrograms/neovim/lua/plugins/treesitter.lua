return {
    "nvim-treesitter",
    after = function()
        -- fixes vjxl highlighting
        vim.api.nvim_create_autocmd("FileType", {
            callback = function()
                pcall(vim.treesitter.start)
            end,
        })
    end
}
