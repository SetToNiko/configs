vim.pack.add({
	-- { src = "https://github.com/sainnhe/gruvbox-material" },
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
	{ src = "https://github.com/neovim/nvim-lspconfig" },
	{ src = "https://github.com/nvim-mini/mini.nvim", version = "stable" },
	{ src = "https://github.com/nvim-lua/plenary.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope.nvim" },
	{ src = "https://github.com/mrcjkb/rustaceanvim" },
	{ src = "https://github.com/stevearc/conform.nvim" },
	{ src = "https://github.com/mfussenegger/nvim-lint" },
	{ src = "https://github.com/mikavilpas/yazi.nvim" },
})

-- Colorscheme
require("theme")

-- Telescope
require("telescope").setup({})

-- Yazi
require("yazi").setup({})

----  Various Mini plugins
-- Mini Highlight Patterns
require("mini.hipatterns").setup({
	highlighters = {
		fixme = { pattern = "FIXME", group = "MiniHipatternsFixme" },
		hack = { pattern = "HACK", group = "MiniHipatternsHack" },
		todo = { pattern = "TODO:", group = "MiniHipatternsTodo" },
		note = { pattern = "NOTE", group = "MiniHipatternsNote" },
	},
})

-- Mini Indenscope
require("mini.indentscope").setup({
	draw = {
		delay = 0,
		animation = function()
			return 0
		end,
	},
})
require("mini.indentscope").gen_animation.none()
require("mini.notify").setup()
require("mini.icons").setup()
require("mini.diff").setup()
require("mini.git").setup()
require("mini.statusline").setup({
	use_icons = true,
	set_vim_settings = true,
})
require("mini.snippets").setup()

-- mini completions --
local MiniCompletions = require("mini.completion")
MiniCompletions.setup({
	lsp_completion = {
		auto_setup = true,
		process_items = function(items, base)
			return MiniCompletions.default_process_items(items, base, {
				filtersort = "fuzzy",
			})
		end,
	},
})
-- completion menu keys: only active while the popup is visible
local function pum_map(lhs, when_visible, otherwise)
	vim.keymap.set("i", lhs, function()
		return vim.fn.pumvisible() == 1 and when_visible or otherwise
	end, { expr = true })
end

pum_map("<C-j>", "<C-n>", "<C-j>") -- next item
pum_map("<C-k>", "<C-p>", "<C-k>") -- previous item
pum_map("<Tab>", "<C-y>", "<Tab>") -- confirm selection
pum_map("<CR>", "", "<CR>") -- Enter does nothing while the menu is open
