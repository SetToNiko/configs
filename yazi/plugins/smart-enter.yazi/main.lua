--- @sync entry
-- Enter on a directory inside nvim (yazi.nvim) navigates into it instead of
-- opening it in nvim. Files, and yazi outside nvim, keep the normal "open".
return {
	entry = function()
		local h = cx.active.current.hovered
		local in_nvim = os.getenv("NVIM") ~= nil
		ya.emit(h and h.cha.is_dir and in_nvim and "enter" or "open", { hovered = true })
	end,
}
