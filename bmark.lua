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
-- require'winapi.monitor'
require'winapi.windowclass'

-- -- info about the monitor which currently has mouse cursor
-- local moninfo = GetMonitorInfo(MonitorFromPoint(GetCursorPos(), MONITOR_DEFAULTTONEAREST))

local win = winapi.Window{
	title = 'bmark',
	autoquit = true,
}

-- pass control to the GUI system & message loop
os.exit(winapi.MessageLoop())
