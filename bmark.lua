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
require 'winapi.clipboard'
require 'winapi.memory'
require 'dragdrop'

-- -- info about the monitor which currently has mouse cursor
-- local moninfo = GetMonitorInfo(MonitorFromPoint(GetCursorPos(), MONITOR_DEFAULTTONEAREST))

local win = winapi.Window{
	title = 'bmark',
	autoquit = true,
}

-- Work based on http://www.catch22.net/tuts/drop-target and https://www.codeproject.com/Articles/13601/COM-in-plain-C
dragenter = function(pDataObj, grfKeyState, pt, pdwEffect)
	print 'DragEnter!'
	local formats = dragDropFormats(pDataObj)
	local htmlFormat = formats['HTML Format']
	if not htmlFormat then
		return
	end
	local f = htmlFormat
	if f.dwAspect==1 and f.tymed==1 then
		local medium = ffi.new 'STGMEDIUM'
		winapi.checkz(pDataObj:GetData(f, medium))
		print(stgMediumData(medium))
		winapi.ReleaseStgMedium(medium)
	else
		print(('got "HTML Format", but unexpected dwAspect=%d and tymed=%d'):format(
			f.dwAspect, f.tymed))
	end
	return winapi.E_UNEXPECTED
end
winapi.RegisterDragDrop(win.hwnd, winapi.simpleDropTarget{DragEnter = dragenter})
-- TODO: winapi.RevokeDragDrop()

function stgMediumData(medium)
	assert(ffi.istype('STGMEDIUM', medium))
	assert(medium.tymed == winapi.TYMED_HGLOBAL, "expected TYMED_HGLOBAL, got "..tostring(medium.tymed))
	local hglobal = medium.hGlobal
	local p = winapi.GlobalLock(hglobal)
	local sz = winapi.GlobalSize(hglobal)
	-- TODO(akavel): conditionally call winapi.mbs instead?
	local s = ffi.string(p, sz) -- TODO: cut at '\0' byte
	winapi.GlobalUnlock(hglobal)
	return s
end
function dragDropFormats(pDataObj)
	local result = {}
	local enum = ffi.new 'IEnumFORMATETC*[1]'
	winapi.checkz(pDataObj:EnumFormatEtc(winapi.DATADIR_GET, enum))
	for i = 1,100 do
		local f = ffi.new 'FORMATETC'
		f.ptd = nil  -- TODO(akavel): do we need this, or is it already 0 by default?
		local next = enum[0]:Next(1, f, nil)
		if next ~= winapi.S_OK then
			break
		end
		if f.ptd ~= nil then
			winapi.CoTaskMemFree(f.ptd)
			f.ptd = nil
		end
		f.lindex = -1  -- make it easy to use the result immediately with pDataObj:GetData()
		local name = winapi.CF_NAMES[f.cfFormat] or winapi.mbs(winapi.GetClipboardFormatName(f.cfFormat)) or ''
		result[name] = f
	end
	enum[0]:Release()
	return result
end

-- pass control to the GUI system & message loop
os.exit(winapi.MessageLoop())
