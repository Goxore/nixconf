return {
    'mini.files',
    after = function()
        require("mini.files").setup({
            windows = {
                preview = true,
                max_number = 3,
            },
            mappings = {
                mark_goto = "`",
            },
        })

        local function map_mini_files(buf, key, path, desc)
            vim.keymap.set("n", key, function()
                local mf = require("mini.files")
                if type(path) == "function" then
                    mf.open(path(), false)
                else
                    mf.open(path, false)
                end
            end, { buffer = buf, desc = desc })
        end

        vim.api.nvim_create_autocmd("User", {
            pattern = "MiniFilesBufferCreate",
            callback = function(args)
                local buf = args.data.buf_id

                local mf = require("mini.files")
                local current_path = function() return mf.get_path() end

                map_mini_files(buf, "gm", function() return vim.api.nvim_buf_get_name(0) end, "Go to parent directory")
                map_mini_files(buf, "gv", function() return vim.fn.expand("~/Videos") end, "Open ~/Videos")
                map_mini_files(buf, "g~", function() return vim.fn.expand("~") end, "Go to home directory")
                map_mini_files(buf, "gp", function() return vim.fn.expand("~/Projects") end, "Go to projects directory")
                map_mini_files(buf, "go", function() return vim.fn.expand("~/Downloads/") end, "Go to downloads")
                map_mini_files(buf, "gd", function() return vim.fn.expand("~/Documents/") end, "Go to docs directory")
                map_mini_files(buf, "gc", function() return vim.fn.expand("~/.config") end, "Go to config")
                map_mini_files(buf, "gs", function() return vim.fn.expand("~/.local/share/") end, "Go to share")
                map_mini_files(buf, "gt", "/tmp", "Go to /tmp directory")
            end,
        })
    end,
    keys = {
        {
            "<leader>e",
            function() MiniFiles.open(vim.api.nvim_buf_get_name(0), false) end,
            desc = "open mini.files cwd"
        },
        {
            "<leader>E",
            function() MiniFiles.open(nil, false) end,
            desc = "open mini.files"
        },
    },
}
