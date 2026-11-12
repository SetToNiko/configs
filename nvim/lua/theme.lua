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

-- Blend hex colour a towards b by t (0..1)
local function mix(a, b, t)
	local out = "#"
	for i = 2, 6, 2 do
		local x, y = tonumber(a:sub(i, i + 1), 16), tonumber(b:sub(i, i + 1), 16)
		out = out .. string.format("%02x", math.floor(x + (y - x) * t + 0.5))
	end
	return out
end

local function apply()
	local p = read_palette()
	if not (p and p.bg and p.fg and p.green and p.magenta and p.cyan) then
		vim.cmd.colorscheme("gruvbox-material") -- no usable global theme
		return
	end
	require("mini.base16").setup({
		palette = {
			base00 = p.bg, -- background
			base01 = mix(p.bg, p.fg, 0.08), -- cursorline, statusline
			base02 = p.bg2, -- selection
			base03 = mix(p.bg, p.fg, 0.45), -- comments
			base04 = p.fg_dim,
			base05 = p.fg, -- text
			base06 = p.fg,
			base07 = p.fg,
			base08 = p.red, -- variables
			base09 = p.red_lit, -- constants, numbers
			base0A = p.yellow, -- types
			base0B = p.green, -- strings
			base0C = p.cyan, -- special
			base0D = p.blue, -- functions
			base0E = p.magenta, -- keywords
			base0F = p.fg_dim, -- delimiters
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
