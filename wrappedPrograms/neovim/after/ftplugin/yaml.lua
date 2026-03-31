---@param path string
---@return boolean
local function file_exists(path)
    return vim.fn.filereadable(path) == 1
end

local function open_or_create_file()
    local buf = vim.api.nvim_get_current_buf()

    local fname = vim.fn.expand("<cfile>")
        :gsub("^['\"]", "")
        :gsub("['\"]$", "")

    local current_file_dir = vim.fn.expand('%:p:h')
    local path = current_file_dir .. '/' .. fname

    if file_exists(path) then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("gf", true, false, true), "n", false)
    end

    local extended_path = current_file_dir .. "/" .. fname .. '.vjxl'

    if file_exists(extended_path) then
        vim.cmd("edit " .. extended_path)
    else
        local newbuf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(newbuf, extended_path)
        vim.api.nvim_set_current_buf(newbuf)
        vim.api.nvim_set_option_value('filetype', 'videovisual', { buf = newbuf })

        vim.api.nvim_create_autocmd("BufWritePost", {
            buffer = newbuf,
            once = true,
            callback = function()
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd("write")
                end)
            end,
        })
    end
end

vim.keymap.set("n", "gf",
    open_or_create_file,
    { noremap = true, silent = true }
)
