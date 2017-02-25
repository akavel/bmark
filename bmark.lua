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

local expat = require 'expat'
local ffi = require 'ffi'
local winapi = require 'winapi'
require 'winapi.monitor'
require 'winapi.editclass'
require 'winapi.windowclass'
require 'dragdrop'

-- -- info about the monitor which currently has mouse cursor
local moninfo = winapi.GetMonitorInfo(winapi.MonitorFromPoint(winapi.GetCursorPos(), winapi.MONITOR_DEFAULTTONEAREST))

local maxw, maxh = moninfo.work_rect.w, moninfo.work_rect.h
local w, h = maxw/4, maxh/3
local win = winapi.Window{
	title = 'bmark',
	autoquit = true,
	-- bottom-right corner of screen
	x = moninfo.work_rect.left + maxw-w,
	y = moninfo.work_rect.top  + maxh-h,
	w = w,
	h = h,
}

local edit = winapi.Edit{
	parent = win,
	multiline = true,
	autovscroll = true,
	autohscroll = true,
	want_return = true,
	dont_hide_selection = true,
	w = w,
	h = h,
}

function edit:on_parent_resizing(windowpos)
	local region = win:get_client_rect()
	self:resize(region.x2, region.y2)
end

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

		local text = dragDropGetData(pDataObj, f):gsub('\0.*$', '')
		print(text)
		-- print(string.format('0x%x',pdwEffect[0]))
		edit.text = html_to_md(extract_text(text))
		edit.enabled = false

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
	DragLeave = function()
		edit.text = ""
		edit.enabled = true
		return winapi.S_OK
	end,
	Drop = function(pDataObj, grfKeyState, pt, pdwEffect)
		edit.enabled = true
		pdwEffect[0] = effect
		return winapi.S_OK
	end,
}
winapi.RegisterDragDrop(win.hwnd, drop_target)
-- TODO: winapi.RevokeDragDrop()

--[[ example data from Firefox, in utf-8:
Version:0.9
StartHTML:00000178
EndHTML:00000273
StartFragment:00000212
EndFragment:00000237
SourceURL:http://piwnica.org/wiki/Teksty/Na_dunaj_Nastu%c5%9b_rano_po_wod%c4%99
<html><body>
<!--StartFragment--><em>Na dunaj Nastu┼Ť</em><!--EndFragment-->
</body>
</html>
--]]
function extract_text(raw_html_format)
	-- FIXME(akavel): verify Version and find out how old we support; also
	-- try to find some official info about the format and versions
	local function get(key)
		return raw_html_format:gmatch(key..':[^\n\r]*')():sub(#key+2)
	end
	local url = get 'SourceURL'
	local from, to = 1+get'StartFragment', 0+get'EndFragment'
	return url.."\r\n"..raw_html_format:sub(from, to)
end

-- NOTE: assumes XML-like HTML.
-- TODO(akavel): make more robust against more html? do we need?
function html_to_md(html)
	return html
	--[[
	local md = html
	expat.parse(html, 
	return md
	--]]
end

-- pass control to the GUI system & message loop
os.exit(winapi.MessageLoop())

