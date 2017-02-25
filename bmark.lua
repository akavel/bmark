-- (done) window
-- TODO: make the window topmost
-- (done) receiving drag&drop - should display drag&drop info details
-- (done) the window should accept drag & drop of selected fragment of webpage
-- from firefox ("HTML Format" 0x18b -- see also ClipSpy.exe)
-- See: http://delphidabbler.com/articles?article=24
-- TODO: should then convert the HTML to Markdown
-- TODO: should display the Markdown in textarea, with possibility of editing
-- TODO: should provide button to append into an .md file, with <a
-- name="DATETIME"/> anchor [ideally as a markdown extension, e.g. [#...] or
-- pandoc's {#...} or [](...) or [][...] or [](#...) or #... or []{#...} or something]
-- TODO: [LATER]: use SQLite to save bookmarks with full text search & display
-- them for browsing & clicking.
-- TODO: [LATER] tray icon

local ffi = require 'ffi'
local winapi = require 'winapi'
-- require 'winapi.monitor'
require 'winapi.windowclass'
-- require 'winapi.ole'  -- TODO: remove, should not be needed because included via winapi.dragdrop
require 'dragdrop'

-- -- info about the monitor which currently has mouse cursor
-- local moninfo = GetMonitorInfo(MonitorFromPoint(GetCursorPos(), MONITOR_DEFAULTTONEAREST))

local win = winapi.Window{
	title = 'bmark',
	autoquit = true,
}

local effect
local drop_target = simpleDropTarget{
	DragEnter = function(pDataObj, grfKeyState, pt, pdwEffect)
		local formats = dragDropFormats(pDataObj)
		local f = formats['HTML Format']
		if not f then
			return winapi.E_UNEXPECTED
		end
		if not winapi.getbit(f.tymed, winapi.TYMED_HGLOBAL) then
			print(('error: got "HTML format", but without expected TYMED_HGLOBAL; tymed=%d'):format(f.tymed))
			return winapi.E_UNEXPECTED
		end
		f.dwAspect = winapi.DVASPECT_CONTENT
		f.tymed = winapi.TYMED_HGLOBAL
		print(dragDropGetData(pDataObj, f))
		print(string.format('0x%x',pdwEffect[0]))
		if winapi.getbit(pdwEffect[0], winapi.DROPEFFECT_LINK) then
			effect = winapi.DROPEFFECT_LINK
		elseif winapi.getbit(pdwEffect[0], winapi.DROPEFFECT_COPY) then
			effect = winapi.DROPEFFECT_COPY
		else
			effect = winapi.DROPEFFECT_NONE
		end
		pdwEffect[0] = effect
		return winapi.S_OK
	end,
	DragOver = function(grfKeyState, pt, pdwEffect)
		pdwEffect[0] = effect
		return winapi.S_OK
	end,
}
winapi.RegisterDragDrop(win.hwnd, drop_target)
-- TODO: winapi.RevokeDragDrop()

-- pass control to the GUI system & message loop
os.exit(winapi.MessageLoop())

