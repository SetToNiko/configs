require("conform").setup({
	formatters_by_ft = {
		c = { "clang-format" },
		cpp = { "clang-format" },
		css = { "prettier" },
		go = { "goimports", "gofumpt" },
		html = { "prettier" },
		javascript = { "prettier" },
		json = { "prettier" },
		jsonc = { "prettier" },
		lua = { "stylua" },
		markdown = { "prettier" },
		nix = { "nixfmt" },
		plsql = { "sqlfluff_oracle" },
		sql = { "sqlfluff" },
		typescript = { "prettier" },
		yaml = { "prettier" },
		-- rust, svelte, toml: no entry, so the LSP formats them
	},
	formatters = {
		sqlfluff = { args = { "fix", "--dialect", "ansi", "-" }, require_cwd = false },
		sqlfluff_oracle = {
			command = "sqlfluff",
			args = { "fix", "--dialect", "oracle", "-" },
			stdin = true,
		},
	},
	format_on_save = { timeout_ms = 2000, lsp_format = "fallback" },
})
