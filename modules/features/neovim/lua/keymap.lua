local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set

keymap("n", "<M-h>", "<C-w>h", opts)
keymap("n", "<M-j>", "<C-w>j", opts)
keymap("n", "<M-k>", "<C-w>k", opts)
keymap("n", "<M-l>", "<C-w>l", opts)

keymap("i", "<M-h>", "<Left>", opts)
keymap("i", "<M-l>", "<Right>", opts)

keymap("v", "J", ":m '>+1<CR>gv=gv", opts)
keymap("v", "K", ":m '<-2<CR>gv=gv", opts)

keymap("n", "<A-w>", "<C-w><C-w>", opts)

keymap("n", "z{", "zfi{", opts)
keymap("n", "z(", "zfi(", opts)

keymap("n", "<leader><esc>", "<cmd>:noh<return>", opts)

keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-h>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-l>", ":vertical resize +2<CR>", opts)
keymap("n", "<C-k>", ":resize -2<CR>", opts)
keymap("n", "<C-j>", ":resize +2<CR>", opts)

keymap("n", "<C-d>", "5<C-d>", opts)
keymap("n", "<C-u>", "5<C-u>", opts)
