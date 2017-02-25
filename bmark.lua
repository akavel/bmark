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
require 'dragdrop_fix'
require 'winapi.uuid'
require 'winapi.clipboard'
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
S_OK = 0
S_FALSE = 1
-- TODO(akavel): is [1] required in both of the below structs? or maybe in none?
IDropTargetVtbl = ffi.new 'IDropTargetVtbl'
IDropTarget = ffi.new 'IDropTarget'
IDropTarget.lpVtbl = IDropTargetVtbl
IDropTargetVtbl.QueryInterface = function(this, riid, ppvObject)
	-- NOTE(akavel): REFIID = *IID = *GUID
	print('QueryInterface!')
	print(riid)
	print(riid == IID_IUnknown)
	print(riid == IID_IDropTarget)
	return winapi.E_NOINTERFACE
end
IDropTargetVtbl.AddRef = function(this)
	print('AddRef!')
	return 0
end
IDropTargetVtbl.Release = function(this)
	return 0
end
IDropTargetVtbl.DragEnter = function(this, pDataObj, grfKeyState, pt, pdwEffect)
	print 'DragEnter!'
	local enum = ffi.new 'IEnumFORMATETC*[1]'
	winapi.checkz(pDataObj.lpVtbl.EnumFormatEtc(pDataObj, winapi.DATADIR_GET, enum))
	local f = ffi.new 'FORMATETC'
	for i = 1,20 do
		-- print(i)
		f.ptd = nil
		local ok, next = pcall(enum[0].lpVtbl.Next, enum[0], 1, f, nil)
		if not ok then
			print('err:', next)
			next = S_FALSE
		end
		-- print('next-ed')
		if next == S_OK then
			local name = winapi.CF_NAMES[f.cfFormat] or winapi.mbs(winapi.GetClipboardFormatName(f.cfFormat)) or ''
			print(('%d\t0x%04x 0x%x 0x%02x %s'):format(i, f.cfFormat, f.dwAspect, f.tymed, name))
			if f.ptd ~= nil then
				winapi.CoTaskMemFree(f.ptd)
			end
		else
			-- print(i)
		end
	end
	pDataObj.lpVtbl.Release(enum[0])
	return E_UNEXPECTED
end
winapi.RegisterDragDrop(win.hwnd, IDropTarget)
-- TODO: winapi.RevokeDragDrop()

-- pass control to the GUI system & message loop
os.exit(winapi.MessageLoop())
