-- Colours from the global theme (~/.config/colors/colors.sh, written by theme-switch.sh)
local path = vim.fn.expand("~/.config/colors/colors.sh")

local function read_palette()
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil
	end
	local p = {}
	for _, line in ipairs(lines) do
		local key, value = line:match("^([%w_]+)=(#%x%x%x%x%x%x)$")
		if key then
			p[key] = value
		end
	end
	return p
end


local function apply()
	local p = read_palette()
	if not (p and p.bg0 and p.fg0 and p.grey1 and p.orange and p.purple and p.aqua) then
		vim.cmd.colorscheme("gruvbox-material") -- no usable global theme
		return
	end
	require("mini.base16").setup({
		palette = {
			base00 = p.bg0, -- background
			base01 = p.bg1, -- cursorline, statusline
			base02 = p.bg3, -- selection
			base03 = p.grey1, -- comments
			base04 = p.grey2,
			base05 = p.fg0, -- text
			base06 = p.fg1,
			base07 = p.fg1,
			base08 = p.red, -- variables
			base09 = p.orange, -- constants, numbers
			base0A = p.yellow, -- types
			base0B = p.green, -- strings
			base0C = p.aqua, -- special
			base0D = p.blue, -- functions
			base0E = p.purple, -- keywords
			base0F = p.grey2, -- delimiters
		},
	})
	vim.g.colors_name = "global"
end

apply()

-- Re-apply as soon as theme-switch.sh rewrites the colours file
local watcher = vim.uv.new_fs_event()
local timer = vim.uv.new_timer()
watcher:start(vim.fs.dirname(path), {}, function(err, filename)
	if err or filename ~= "colors.sh" then
		return
	end
	-- short delay so we don't read the file half-written
	timer:start(100, 0, vim.schedule_wrap(apply))
end)
