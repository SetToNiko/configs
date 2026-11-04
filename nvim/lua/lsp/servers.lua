vim.lsp.config("lua_ls", {
	settings = { Lua = { diagnostics = { globals = { "vim" } } } },
})

vim.lsp.config("gopls", {
	settings = { gopls = { gofumpt = true, staticcheck = true } },
})

vim.lsp.config("nixd", {
	settings = { nixd = { formatting = { command = { "nixfmt" } } } },
})

vim.lsp.enable({
	"clangd", -- c + c++
	"cssls",
	"gopls",
	"html",
	"jsonls",
	"lua_ls",
	"marksman", -- markdown
	"nixd",
	"sqls", -- sql / plsql (basic)
	"svelte",
	"tombi",
	"ts_ls", -- javascript + typescript
	"yamlls",
})

-- keymaps/diagnostics on attach
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local map = function(keys, fn, desc)
			vim.keymap.set("n", keys, fn, { buffer = ev.buf, desc = desc })
		end
		map("gd", vim.lsp.buf.definition, "Go to definition")
		map("gr", vim.lsp.buf.references, "References")
		map("K", vim.lsp.buf.hover, "Hover")
		map("<leader>rn", vim.lsp.buf.rename, "Rename")
		map("<leader>ca", vim.lsp.buf.code_action, "Code action")
	end,
})

vim.diagnostic.config({ virtual_text = true, severity_sort = true })
