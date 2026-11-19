-- Middle-click a file to drag it into another program: opens dragon-drop under
-- the mouse with the selected files (or just the clicked one if none are
-- selected); drop them anywhere and the window closes.
-- (Ctrl+click isn't possible: yazi's mouse events carry no modifier keys.)
local click = Current.click
function Current:click(event, up)
	if not event.is_middle then
		return click(self, event, up)
	end
	if up then
		return
	end

	local file = self._folder.window[event.y - self._area.y + 1]
	if file then
		ya.emit("reveal", { file.url })
		-- %s = the selected files, or the hovered one (yazi quotes them)
		ya.emit("shell", { "dragon-drop --and-exit --all %s", orphan = true })
	end
end
