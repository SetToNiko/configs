-- `z` zips the selected files (or the hovered one if none are selected) into
-- the current folder, with ouch. Asks for the archive name first, suggesting
-- the item's name for one item ("report.pdf" -> "report.zip") or the current
-- folder's name for several. Typing another archive extension (".tar.gz",
-- ".7z", ...) makes that format instead; with none, ".zip" is added.
-- Never overwrites: a taken name becomes "name (2).zip".

local ARCHIVE_EXTS = {
	".tar.gz", ".tar.xz", ".tar.bz2", ".tar.bz3", ".tar.zst", ".tar.lz4", ".tar.lzma", ".tar.sz", ".tar.br",
	".tgz", ".txz", ".tbz2", ".tbz", ".tzst", ".tlz4", ".tsz", ".zip", ".7z", ".tar",
}

local state = ya.sync(function()
	local paths = {}
	for _, f in pairs(cx.active.selected) do
		paths[#paths + 1] = tostring(f.path)
	end
	local hovered = cx.active.current.hovered
	if #paths == 0 and hovered then
		paths[1] = tostring(hovered.path)
	end
	local is_dir = #paths == 1 and hovered and tostring(hovered.path) == paths[1] and hovered.cha.is_dir
	return paths, tostring(cx.active.current.cwd), is_dir
end)

local function notify(content, level)
	ya.notify { title = "Zip", content = content, timeout = 4, level = level or "info" }
end

-- split "name.tar.gz" into "name", ".tar.gz" (ext nil if not an archive name)
local function split_ext(name)
	local lower = name:lower()
	for _, ext in ipairs(ARCHIVE_EXTS) do
		if #name > #ext and lower:sub(-#ext) == ext then
			return name:sub(1, -#ext - 1), name:sub(-#ext)
		end
	end
	return name, nil
end

-- "dir/name.zip", then "dir/name (2).zip", ...
local function free_path(dir, base, ext)
	local path, n = dir .. "/" .. base .. ext, 1
	while fs.cha(Url(path)) do
		n = n + 1
		path = string.format("%s/%s (%d)%s", dir, base, n, ext)
	end
	return path
end

return {
	entry = function()
		local paths, cwd, is_dir = state()
		if #paths == 0 then
			return notify("Nothing to zip", "warn")
		end

		local suggest
		if #paths == 1 then
			suggest = paths[1]:match("[^/]+$")
			if not is_dir then
				suggest = suggest:match("^(.+)%.[^.]+$") or suggest -- drop the file's own extension
			end
		else
			suggest = cwd:match("[^/]+$") or "archive"
		end

		local value, event = ya.input {
			title = string.format("Zip %d item%s as:", #paths, #paths == 1 and "" or "s"),
			value = suggest .. ".zip",
			pos = { "top-center", y = 3, w = 50 },
		}
		if event ~= 1 then
			return -- cancelled
		end
		value = (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if value == "" or value:find("/") then
			return notify("Invalid name", "warn")
		end

		local base, ext = split_ext(value)
		local dest = free_path(cwd, base, ext or ".zip")

		local args = { "compress", "-q", "-n" }
		for _, p in ipairs(paths) do
			args[#args + 1] = p
		end
		args[#args + 1] = dest

		local out, err = Command("ouch"):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):output()
		if not out then
			return notify("Couldn't run ouch: " .. tostring(err), "error")
		end
		if not out.status.success then
			fs.remove("file", Url(dest)) -- don't leave a half-written archive
			local msg = out.stderr:gsub("\27%[[%d;]*m", ""):gsub("^%s+", ""):gsub("%s+$", "")
			return notify(msg ~= "" and msg or "zipping failed", "error")
		end

		ya.emit("escape", { select = true }) -- clear the selection
		ya.emit("reveal", { Url(dest) })
		notify(string.format("%d item%s → %s", #paths, #paths == 1 and "" or "s", dest:match("[^/]+$")))
	end,
}
