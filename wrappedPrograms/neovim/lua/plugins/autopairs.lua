return {
    "nvim-autopairs",
    event = "DeferredUIEnter",
    after = function()
        require("nvim-autopairs").setup({
        })
    end
}
