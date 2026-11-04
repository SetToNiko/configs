vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 4 -- col width of the number column

vim.opt.scrolloff = 10 -- keeps a specified amount of lines above and below the cursor
vim.opt.sidescrolloff = 10

vim.opt.tabstop = 4 -- col display width of a literal tab character
vim.opt.shiftwidth = 4 -- literal amount of column width for an indent action
vim.opt.softtabstop = 4 -- number of cols inserted or deleted by <TAB> and <BS>
vim.opt.expandtab = true -- makes tab insert amount of spaces instead of tab if true (on by default)

vim.opt.autoindent = true
vim.opt.wrap = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.cmdheight = 0 -- sets command line height, 0 hides it unless a command is being typed
vim.opt.timeoutlen = 200

vim.opt.list = true -- enables list mode, showing invisible space characters and more

vim.opt.ignorecase = true
vim.opt.smartcase = true -- search becomes case sensitive if pattern contains uppercase
vim.opt.hlsearch = true -- highlights all matching search results (on by default)
vim.opt.incsearch = true -- incremental highlight of search pattern ( on by default)
vim.opt.clipboard = "unnamedplus" -- uses system clipboard as yank buffer
vim.opt.undofile = true -- commits undo history to machine. Maintains history after program close & reopen

vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.termguicolors = true -- enable 24bit rgb color

-- vim.opt.autocomplete = true -- NATIVE autocomplete in insert mode
vim.opt.completeopt = { "fuzzy", "menuone", "popup", "noinsert" } -- options for how the autocomplete is shown. fuzzy: fuzzy finding, menuone: shows menu even if only one opt is available, popup: show extra info in popup menu

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlights text on yank",
	callback = function()
		vim.hl.on_yank()
	end,
})
