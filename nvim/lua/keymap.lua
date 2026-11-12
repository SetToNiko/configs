vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set("n", "<leader>q", "<cmd>q<cr>")

-- General navigation
vim.keymap.set("n", "<leader>o", "<C-o>", { desc = "Previous jump" })
vim.keymap.set("n", "<leader>i", "<C-i>", { desc = "Next jump" })

-- Pane navigation
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")

-- Pane creation
vim.keymap.set("n", "<C-s>", "<C-w>s")
vim.keymap.set("n", "<C-v>", "<C-w>v")

-- Lsp
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set({ "n", "v" }, "<leader>f", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })

-- Telescope
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>")
vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>")
vim.keymap.set({ "n", "v" }, "<leader>fs", "<cmd>Telescope grep_string<cr>")
vim.keymap.set("n", "<leader>fm", "<cmd>Telescope keymaps<cr>")
vim.keymap.set("n", "<leader>fd", "<cmd>Telescope diagnostics bufnr=0<cr>")

-- Yazi single column (like Neotree)
local function yazi_sidebar(path)
	local width = 40
	require("yazi").yazi({
		config_home = vim.fn.stdpath("config") .. "/yazi-sidebar",
		floating_window_scaling_factor = { height = 1, width = width },
		hooks = {
			before_opening_window = function(opts)
				opts.row = 0
				opts.col = 0
				opts.width = width
				opts.height = vim.o.lines - vim.o.cmdheight - 3 -- leave the statusline visible
			end,
		},
	}, path)
end

-- Yazi file explorer
vim.keymap.set({ "n", "v" }, "<leader>y", "<cmd>Yazi<cr>", { desc = "Yazi at current file" })
vim.keymap.set("n", "<leader>Y", "<cmd>Yazi cwd<cr>", { desc = "Yazi in working directory" })

vim.keymap.set("n", "<leader>t", function()
	yazi_sidebar(vim.uv.cwd())
end, { desc = "Yazi sidebar at current file" })
