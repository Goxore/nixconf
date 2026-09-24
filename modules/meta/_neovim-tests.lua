local mode = assert(vim.env.NVIM_TEST_MODE)
local root = assert(vim.env.NVIM_TEST_ROOT)
assert(vim.g.colors_name == 'gxvjbox')
assert(vim.o.undofile)
assert(vim.o.directory ~= '/tmp')
assert(vim.fn.executable('git') == 1)
assert(vim.fn.executable('rg') == 1)
assert(vim.fn.executable('fd') == 1)
assert(not vim.lsp.is_enabled('vjcustom'))
assert(vim.fn.maparg('gr', 'n') == '')
assert(vim.fn.maparg('grr', 'n', false, true).desc == 'References')
assert(vim.fn.maparg('grn', 'n', false, true).desc == 'vim.lsp.buf.rename()')
assert(vim.fn.maparg('gra', 'n', false, true).desc == 'vim.lsp.buf.code_action()')

if mode == 'write' or mode == 'undo' then
    vim.cmd.edit(root .. '/undo.txt')
    if mode == 'write' then
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'second' })
        vim.cmd.write()
        assert(vim.fn.filereadable(vim.fn.undofile(root .. '/undo.txt')) == 1)
    else
        assert(vim.api.nvim_get_current_line() == 'second')
        vim.cmd.undo()
        assert(vim.api.nvim_get_current_line() == 'first')
    end
elseif mode == 'lsp' then
    assert(vim.fn.executable('gleam') == 1)
    vim.cmd.edit(root .. '/main.ts')
    local bufnr = vim.api.nvim_get_current_buf()
    assert(vim.wait(15000, function()
        return vim.fn.maparg('<leader>F', 'n', false, true).buffer == 1
            and vim.fn.exists(':LspTypescriptSourceAction') == 2
    end, 50), 'TypeScript did not attach with both standard and custom actions')
    local client = assert(vim.lsp.get_clients({ bufnr = bufnr, name = 'ts_ls' })[1])
    assert(client.config.capabilities.textDocument.completion.completionItem.snippetSupport)
    assert(vim.fn.maparg('F', 'v', false, true).buffer == 1)
    assert(vim.fn.maparg('<leader>k', 'n', false, true).buffer == 1)
    assert(vim.fn.maparg('gD', 'n', false, true).buffer == 1)
    vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 5000 })
    assert(vim.api.nvim_get_current_line() == 'const answer: number = 1', vim.api.nvim_get_current_line())
    vim.bo.modified = false
    vim.cmd.enew()
    assert(vim.fn.maparg('<leader>F', 'n') == '')
    assert(vim.fn.maparg('gD', 'n') == '')
    vim.lsp.config.rust_analyzer.on_attach(nil, vim.api.nvim_get_current_buf())
    assert(vim.fn.exists(':LspCargoReload') == 2)
    client:stop(true)
else
    error('unexpected test mode')
end
vim.cmd('qa!')
