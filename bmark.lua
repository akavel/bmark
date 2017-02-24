-- TODO: window
-- TODO: make the window topmost & receiving drag&drop - should display drag&drop info details
-- TODO: the window should accept drag & drop of selected fragment of webpage
-- from firefox ("HTML Format" 0x18b -- see also ClipSpy.exe)
-- See: http://delphidabbler.com/articles?article=24
-- TODO: should then convert the HTML to Markdown
-- TODO: [LATER]: use SQLite to save bookmarks with full text search & display
-- them for browsing & clicking.
-- TODO: [LATER] tray icon

local winapi = require 'winapi'
-- require 'winapi.monitor'
require 'winapi.windowclass'
-- require 'winapi.ole'  -- TODO: remove, should not be needed because included via winapi.dragdrop
require 'winapi.dragdrop_fix'
require 'winapi.uuid'
local ffi = require 'ffi'

-- -- info about the monitor which currently has mouse cursor
-- local moninfo = GetMonitorInfo(MonitorFromPoint(GetCursorPos(), MONITOR_DEFAULTTONEAREST))

local win = winapi.Window{
	title = 'bmark',
	autoquit = true,
}

-- Work based on http://www.catch22.net/tuts/drop-target and https://www.codeproject.com/Articles/13601/COM-in-plain-C
IID_IUnknown    = winapi.UuidFromString '00000000-0000-0000-C000-000000000046'
IID_IDropTarget = winapi.UuidFromString '00000122-0000-0000-C000-000000000046'
E_UNEXPECTED = 0x8000FFFF
-- TODO(akavel): is [1] required in both of the below structs? or maybe in none?
IDropTargetVtbl = ffi.new 'IDropTargetVtbl[1]'
IDropTarget = ffi.new 'IDropTarget[1]'
IDropTarget[0].lpVtbl = IDropTargetVtbl
IDropTargetVtbl[0].QueryInterface = function(this, riid, ppvObject)
	-- NOTE(akavel): REFIID = *IID = *GUID
	print('QueryInterface!')
	print(riid)
	print(riid == IID_IUnknown)
	print(riid == IID_IDropTarget)
	return winapi.E_NOINTERFACE
end
IDropTargetVtbl[0].AddRef = function(this)
	print('AddRef!')
	return 0
end
IDropTargetVtbl[0].Release = function(this)
	return 0
end
IDropTargetVtbl[0].DragEnter = function(this, pDataObj, grfKeyState, pt, pdwEffect)
	print 'DragEnter!'
	return E_UNEXPECTED
end
print(winapi.E_NOINTERFACE)
-- if false then
	winapi.RegisterDragDrop(win.hwnd, IDropTarget)
	-- TODO: winapi.RevokeDragDrop()
-- end

-- pass control to the GUI system & message loop
os.exit(winapi.MessageLoop())
