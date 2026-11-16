-- Previews .docx files with doxx (`doxx --export ansi`), scrollable like the
-- built-in text previewers. Modeled on Yazi's built-in json previewer.
local M = {}

local function message(job, text)
	ya.preview_widget(job, ui.Text(text):area(job.area):wrap(ui.Wrap.YES))
end

function M:peek(job)
	local child = Command("doxx")
		:arg({ "--export", "ansi", "--no-images", "-w", tostring(job.area.w), tostring(job.file.path) })
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
		:spawn()
	if not child then
		return message(job, "doxx not found: rebuild the system to install it")
	end

	local opt = { ansi = true, tab_size = rt.preview.tab_size, wrap = rt.preview.wrap, width = job.area.w }
	local limit = job.area.h
	local i, lines = 0, {}
	repeat
		local next, event = child:read_line()
		if event ~= 0 then
			break
		end
		local wrapped = ui.lines(next, opt)
		local from = math.max(1, job.skip - i + 1)
		local to = math.min(#wrapped, job.skip + limit - i)
		i = i + #wrapped
		for j = from, to do
			lines[#lines + 1] = wrapped[j]
		end
	until i >= job.skip + limit
	child:start_kill()

	if job.skip > 0 and i < job.skip + limit then
		-- scrolled past the end: clamp back to the last page
		ya.emit("peek", { math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
	elseif i == 0 then
		message(job, "doxx could not render this file")
	else
		ya.preview_widget(job, ui.Text(lines):area(job.area))
	end
end

-- reuse the built-in text previewer's scrolling (J/K in the preview pane)
function M:seek(job) require("code"):seek(job) end

return M
