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
require 'winapi.clipboard'
require 'winapi.memory'
local ffi = require 'ffi'

-- -- info about the monitor which currently has mouse cursor
-- local moninfo = GetMonitorInfo(MonitorFromPoint(GetCursorPos(), MONITOR_DEFAULTTONEAREST))

local win = winapi.Window{
	title = 'bmark',
	autoquit = true,
}

-- Work based on http://www.catch22.net/tuts/drop-target and https://www.codeproject.com/Articles/13601/COM-in-plain-C
-- TODO(akavel): is [1] required in both of the below structs? or maybe in none?
IDropTargetVtbl = ffi.new 'IDropTargetVtbl'
IDropTarget = ffi.new 'IDropTarget'
IDropTarget.lpVtbl = IDropTargetVtbl
IDropTargetVtbl.QueryInterface = function(this, riid, ppvObject)
	-- NOTE(akavel): REFIID = *IID = *GUID
	print('QueryInterface!')
	-- print(riid)
	-- print(riid == winapi.IID_IUnknown)
	-- print(riid == winapi.IID_IDropTarget)
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
	ok, res = pcall(dragenter, this, pDataObj, grfKeyState, pt, pdwEffect)
	if not ok then
		print('ERROR: '..res)
		return winapi.E_UNEXPECTED
	end
	return res
end
dragenter = function(this, pDataObj, grfKeyState, pt, pdwEffect)
	print 'DragEnter!'
	local enum = ffi.new 'IEnumFORMATETC*[1]'
	winapi.checkz(pDataObj:EnumFormatEtc(winapi.DATADIR_GET, enum))
	local f = ffi.new 'FORMATETC'
	for i = 1,20 do
		f.ptd = nil
		local next = enum[0]:Next(1, f, nil)
		if next == winapi.S_OK then
			local name = winapi.CF_NAMES[f.cfFormat] or winapi.mbs(winapi.GetClipboardFormatName(f.cfFormat)) or ''
			print(('%d\t0x%04x 0x%x 0x%02x %s'):format(i, f.cfFormat, f.dwAspect, f.tymed, name))
			if f.ptd ~= nil then
				winapi.CoTaskMemFree(f.ptd)
				f.ptd = nil
			end
			if name == 'HTML Format' then
				if f.dwAspect==1 and f.tymed==1 then
					local medium = ffi.new 'STGMEDIUM'
					winapi.checkz(pDataObj:GetData(f, medium))
					local hglobal = medium.hGlobal
					p = winapi.checknz(winapi.GlobalLock(hglobal))
					local sz = winapi.GlobalSize(hglobal)
					print('#', sz)
					print(ffi.string(p, sz)) -- TODO: cut at '\0' byte
					-- print(winapi.mbs(ffi.cast('CHAR*', p)))
					winapi.GlobalUnlock(hglobal)
					winapi.ReleaseStgMedium(medium)
				else
					print(('got "HTML Format", but unexpected dwAspect=%d and tymed=%d'):format(
						f.dwAspect, f.tymed))
				end
			end
		end
	end
	enum[0]:Release()
	return winapi.E_UNEXPECTED
end
winapi.RegisterDragDrop(win.hwnd, IDropTarget)
-- TODO: winapi.RevokeDragDrop()

-- pass control to the GUI system & message loop
os.exit(winapi.MessageLoop())
