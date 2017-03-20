local ffi = require 'ffi'
local glue = require 'glue'
local winapi = require 'winapi'
require 'winapi.clipboard'
require 'winapi.memory'
require 'winapi_dragdrop_fix'

-- Work based on http://www.catch22.net/tuts/drop-target and https://www.codeproject.com/Articles/13601/COM-in-plain-C
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
-- NOTE: only TYMED_HGLOBAL supported as of now
function dragDropGetData(pDataObj, formatEtc)
	assert(ffi.istype('FORMATETC', formatEtc))
	local medium = ffi.new 'STGMEDIUM'
	winapi.checkz(pDataObj:GetData(formatEtc, medium))
	if medium.tymed ~= winapi.TYMED_HGLOBAL then
		winapi.ReleaseStgMedium(medium)
		error('expected TYMED_HGLOBAL, got '..tostring(medium.tymed))
	end
	local hglobal = medium.hGlobal
	local p = winapi.GlobalLock(hglobal)
	local sz = winapi.GlobalSize(hglobal)
	-- TODO(akavel): conditionally call winapi.mbs instead? or copy a blob of bytes?
	local s = ffi.string(p, sz) -- TODO: cut at '\0' byte
	winapi.GlobalUnlock(hglobal)
	winapi.ReleaseStgMedium(medium)
	return s
end
-- Work based on http://www.catch22.net/tuts/drop-target and https://www.codeproject.com/Articles/13601/COM-in-plain-C
function simpleDropTarget(methods)
	assert(type(methods)=='table')
	local IDropTarget = ffi.new 'IDropTarget'
	local vtable = ffi.new 'IDropTargetVtbl'
	IDropTarget.lpVtbl = vtable
	-- NOTE(akavel): it looks like the default IUnknown methods can be "empty" and RegisterDragDrop will work OK
	IDropTarget.lpVtbl.QueryInterface = function(this, riid, ppvObject)
		-- print '\n** QueryInterface **\n'
		return winapi.E_NOINTERFACE end
	IDropTarget.lpVtbl.AddRef = function(this)
		-- print '\n** AddRef **\n'
		return 0 end
	IDropTarget.lpVtbl.Release = function(this)
		-- print '\n** Release **\n'
		return 0 end
	-- set user-provided functions, wrapped for security
	local function wrap(f)
		return function(this, ...)
			if f == nil then return winapi.E_UNEXPECTED end
			local ok, res = glue.pcall(f, ...)
			if not ok then
				io.stderr:write('error: '..tostring(res)..'\n')
				return winapi.E_UNEXPECTED
			end
			return res
		end
	end
	IDropTarget.lpVtbl.DragEnter = wrap(methods.DragEnter)
	IDropTarget.lpVtbl.DragOver  = wrap(methods.DragOver)
	IDropTarget.lpVtbl.DragLeave = wrap(methods.DragLeave)
	IDropTarget.lpVtbl.Drop      = wrap(methods.Drop)
	-- NOTE(akavel): below object tries to prevent
	-- lpVtbl from being GCed.
	local drop_target = {
		handle = IDropTarget,
		vtable = vtable,
		RegisterDragDrop = function(self, hwnd)
			local hwnd = type(hwnd)=='table' and hwnd.hwnd or hwnd
			return winapi.RegisterDragDrop(hwnd, self.handle)
		end,
		-- TODO: winapi.RevokeDragDrop()
	}
	-- TODO(akavel): remove below debugging functions once it's confirmed stuff works ok
	ffi.gc(IDropTarget, function()
		print '\nGC IDROPTARGET !!!!\n'
	end)
	ffi.gc(vtable, function()
		print '\nGC IDROPTARGET.LPVTBL !!!\n'
	end)
	setmetatable(drop_target, {__gc=function()
		print '\nGC drop_target !!!\n'
	end})
	return drop_target
end

