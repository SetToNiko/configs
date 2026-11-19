-- `u` on an archive extracts it next to itself (with ouch), into a folder
-- named after the archive ("photos.tar.gz" -> "photos/", or "photos (2)/" if
-- that exists). An archive holding a single item isn't nested: a lone folder
-- or file (e.g. "notes.txt.gz" -> "notes.txt") is moved up instead.
-- Works on the selected files, or the hovered one if none are selected;
-- anything that isn't an archive is skipped.

-- longest first, so "x.tar.gz" loses ".tar.gz" rather than just ".gz"
local EXTS = {
	".tar.gz", ".tar.xz", ".tar.bz2", ".tar.bz3", ".tar.zst", ".tar.lz4", ".tar.lzma", ".tar.sz", ".tar.br",
	".tgz", ".txz", ".tbz2", ".tbz", ".tzst", ".tlz4", ".tsz",
	".zip", ".7z", ".rar", ".tar", ".gz", ".xz", ".bz2", ".bz3", ".zst", ".lz4", ".lzma", ".sz", ".br",
}

-- "Photos.TAR.GZ" -> "Photos"; nil when it isn't an archive
local function stem(name)
	local lower = name:lower()
	for _, ext in ipairs(EXTS) do
		if #name > #ext and lower:sub(-#ext) == ext then
			return name:sub(1, -#ext - 1)
		end
	end
end

local targets = ya.sync(function()
	local urls = {}
	for _, f in pairs(cx.active.selected) do
		urls[#urls + 1] = tostring(f.path)
	end
	if #urls == 0 and cx.active.current.hovered then
		urls[1] = tostring(cx.active.current.hovered.path)
	end
	return urls
end)

local function exists(path)
	return fs.cha(Url(path)) ~= nil
end

-- "dir/name", then "dir/name (2)", "dir/name (3)", ...
-- (a file "name.txt" becomes "name (2).txt")
local function free_name(dir, name)
	local base, ext = name:match("^(.+)(%.[^.]+)$")
	if not base then
		base, ext = name, ""
	end
	local path, n = dir .. "/" .. name, 1
	while exists(path) do
		n = n + 1
		path = string.format("%s/%s (%d)%s", dir, base, n, ext)
	end
	return path
end

local function notify(content, level)
	ya.notify { title = "Extract", content = content, timeout = 4, level = level or "info" }
end

local function extract(archive, name)
	local dir, base = archive:match("^(.*)/([^/]+)$")
	-- ouch only fills a folder that doesn't exist yet (with -n it skips existing ones)
	local dest = free_name(dir, name)

	local out, err = Command("ouch")
		:arg({ "decompress", "-q", "-n", archive, "--dir", dest })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()
	if not out then
		return notify("Couldn't run ouch: " .. tostring(err), "error")
	end
	if not out.status.success then
		fs.remove("dir_clean", Url(dest)) -- drop the empty folder a failed run leaves
		local msg = out.stderr:gsub("\27%[[%d;]*m", ""):gsub("^%s+", ""):gsub("%s+$", "")
		return notify(base .. ": " .. (msg ~= "" and msg or "extraction failed"), "error")
	end

	-- a single item inside: move it up rather than nest it
	local entries = fs.read_dir(Url(dest), {})
	if entries and #entries == 1 then
		local tmp = dest .. ".extract-tmp"
		if os.rename(tostring(entries[1].url), tmp) and os.remove(dest) then
			local final = free_name(dir, entries[1].name)
			os.rename(tmp, final)
			dest = final
		end
	end

	notify(base .. " → " .. dest:match("[^/]+$"))
	ya.emit("reveal", { Url(dest) })
end

return {
	entry = function()
		local found = 0
		for _, path in ipairs(targets()) do
			local name = stem(path:match("[^/]+$"))
			if name then
				found = found + 1
				extract(path, name)
			end
		end
		if found == 0 then
			notify("Not an archive", "warn")
		end
	end,
}
