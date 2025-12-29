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
            -- bufmap(bufnr, 'n', 'gE', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
            -- bufmap(bufnr, 'n', 'ge', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
        end

        local capabilities = require("blink.cmp").get_lsp_capabilities()

        -- Lua LSP
        vim.lsp.config("lua_ls", {
            settings = {
                Lua = {
                    diagnostics = { globals = { "vim" } },
                    telemetry = {

                        enable = false
                    }
                },
            },
        })

        vim.lsp.config("lua_ls", { on_attach = on_attach, capabilities = capabilities })
        vim.lsp.enable("lua_ls")

        vim.lsp.config("ts_ls", {
            on_attach = on_attach,
            capabilities = capabilities,
            settings = {
                suggestionActions = {
                    enabled = false
                }
            }
        })
        vim.lsp.enable("ts_ls")

        vim.lsp.config("qmlls", {
            cmd = { "qmlls", "-E" },
            on_attach = on_attach,
            capabilities = capabilities
        })
        vim.lsp.enable("qmlls")

        vim.lsp.config("rust_analyzer", { on_attach = on_attach, capabilities = capabilities })
        vim.lsp.enable("rust_analyzer")

        vim.lsp.config("nixd", {
            on_attach = on_attach,
            capabilities = capabilities,
            cmd = { "nixd" },
            settings = {
                nixd = {
                    nixpkgs = {
                        expr = "import <nixpkgs> { }",
                    },
                    formatting = {
                        command = { "alejandra" },
                    },
                },
            },
        })
        vim.lsp.enable("nixd")

        -- ============================= VJXL ============================= --

        vim.lsp.config['parser4'] = {
            cmd = { '/home/yurii/Videos/parser4/target/release/parser4', 'lsp' },
            filetypes = { 'vjxl' },
            root_markers = { '.git' },
            root_dir = vim.fn.getcwd(),
        }
        vim.lsp.config("parser4", { on_attach = on_attach, capabilities = capabilities })
        vim.lsp.enable('parser4')
    end,
}
