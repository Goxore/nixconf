return {
    "nvim-lspconfig",
    lazy = false,

    before = function()
        local on_attach = function(client, bufnr)
            local opts = { noremap = true, silent = true, buffer = bufnr }

            vim.keymap.set('v', 'F', vim.lsp.buf.format, opts)
            vim.keymap.set('n', '<leader>F', vim.lsp.buf.format, opts)
            vim.keymap.set('n', '<leader>k', vim.diagnostic.open_float, opts)
            vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)
            vim.keymap.set('n', 'gD', vim.lsp.buf.type_definition, opts)
        end

        vim.lsp.config('*', {
            capabilities = require("blink.cmp").get_lsp_capabilities(),
            on_attach = on_attach,
        })
    end,
}
