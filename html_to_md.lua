local expat = require 'expat'

-- NOTE: assumes XML-like HTML.
-- TODO(akavel): make more robust against more html? do we need?
function html_to_md(html)
	local html = '<?xml version="1.0" encoding="UTF-8"?>\n' .. html
	print(html)

	local handler = coroutine.wrap(function()
		return html_to_md_loop(function()
			return coroutine.yield(main)
		end)
	end)

	expat.parse({string=html}, {
		start_tag = function(tag, attrs)
			handler{tag=tag, attrs=attrs}
		end,
		cdata = function(s)
			handler{cdata=s}
		end,
	})
	return handler(nil)
end

function html_to_md_loop(next)
	local buf = setmetatable({}, {__index={
		print = function(self, s) self[#self+1] = s end,
		printf = function(self, s, ...) self[#self+1] = s:format(...) end,
		string = function(self) return table.concat(self) end,
	}})

	while true do
		local el = next()
		if el == nil then
			return buf:string()
		-- elseif el.tag == 'em' or el.tag == 'i' then
		-- 	buf:print'*'
		-- elseif el.tag == 'strong' or el.tag == 'b' then
		-- 	buf:print'**'
		elseif el.cdata then
			buf:print(el.cdata)
		end
	end
end

