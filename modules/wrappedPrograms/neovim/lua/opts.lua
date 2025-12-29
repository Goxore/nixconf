local g = vim.g
local o = vim.opt

o.swapfile = true
o.dir = '/tmp'
o.smartcase = true
o.laststatus = 3
o.hlsearch = true
o.incsearch = true
o.ignorecase = true
o.relativenumber = true
o.wrap = false
o.clipboard = "unnamedplus"
o.encoding = "utf-8"
o.hidden = true
o.tabstop = 4
o.shiftwidth = 4
o.expandtab = true
o.updatetime = 300
o.termguicolors = true
o.mouse = "a"
o.splitbelow = true
o.splitright = true
o.scrolloff = 9
o.cursorline = true
o.scroll = 6
o.signcolumn = "yes"
o.pumheight = 16
o.winborder = "single"
o.langmap =
[[ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ,фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz]]

g.mapleader = " "

vim.cmd.colorscheme("gxvjbox")
