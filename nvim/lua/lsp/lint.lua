local lint = require("lint")

lint.linters_by_ft = {
	css = { "stylelint" },
	go = { "golangcilint" },
	html = { "htmlhint" },
	javascript = { "eslint_d" },
	markdown = { "markdownlint-cli2" },
	nix = { "statix", "deadnix" },
	plsql = { "sqlfluff" },
	sql = { "sqlfluff" },
	svelte = { "eslint_d" },
	typescript = { "eslint_d" },
	yaml = { "yamllint" },
	-- c/c++: clangd runs clang-tidy; rust: clippy runs via rust_analyzer
}

-- sqlfluff needs a dialect; a .sqlfluff file in the project root overrides this
lint.linters.sqlfluff.args = {
	"lint",
	"--format=json",
	"--dialect",
	"ansi",
	"-",
}

vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
	callback = function()
		lint.try_lint()
	end,
})
