-- TODO: window
-- TODO: make the window topmost & receiving drag&drop - should display drag&drop info details
-- TODO: the window should accept drag & drop of selected fragment of webpage
-- from firefox ("HTML Format" 0x18b -- see also ClipSpy.exe)
-- See: http://delphidabbler.com/articles?article=24
-- TODO: should then convert the HTML to Markdown
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

-- Work based on http://www.catch22.net/tuts/drop-target and https://www.codeproject.com/Articles/13601/COM-in-plain-C
local drop_target = winapi.simpleDropTarget{
	DragEnter = function(pDataObj, grfKeyState, pt, pdwEffect)
		print 'DragEnter!'
		local formats = dragDropFormats(pDataObj)
		local htmlFormat = formats['HTML Format']
		if not htmlFormat then
			return winapi.E_UNEXPECTED
		end
		local f = htmlFormat
		if f.dwAspect==1 and f.tymed==1 then
			-- print('good')
			print(dragDropGetData(pDataObj, f))
		else
			print(('got "HTML Format", but unexpected dwAspect=%d and tymed=%d'):format(
				f.dwAspect, f.tymed))
		end
		return winapi.E_UNEXPECTED
	end
}
winapi.RegisterDragDrop(win.hwnd, drop_target)
-- TODO: winapi.RevokeDragDrop()

-- pass control to the GUI system & message loop
os.exit(winapi.MessageLoop())

