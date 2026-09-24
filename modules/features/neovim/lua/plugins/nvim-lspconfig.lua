return {
    "nvim-lspconfig",
    lazy = false,
    after = function()
        vim.lsp.config('*', {
            capabilities = require("blink.cmp").get_lsp_capabilities(),
        })

        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('nixconf_lsp', { clear = true }),
            callback = function(args)
                local opts = { noremap = true, silent = true, buffer = args.buf }

                vim.keymap.set('v', 'F', vim.lsp.buf.format, opts)
                vim.keymap.set('n', '<leader>F', vim.lsp.buf.format, opts)
                vim.keymap.set('n', '<leader>k', vim.diagnostic.open_float, opts)
                vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)
                vim.keymap.set('n', 'gD', vim.lsp.buf.type_definition, opts)
            end,
        })
    end,
}
