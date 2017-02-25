local expat = require 'expat'

sample = [[
<?xml version="1"?>
<em>hello</em>
]]

expat.parse({string=sample}, {
	-- element = function(name, model) print(name,model) end,
	start_tag = function(...) print('st',...) end,
	cdata = function(...) print('cd',...) end,
})
