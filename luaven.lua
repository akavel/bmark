-- Module luaven provides functions generating Lua string patterns for matching
-- fuzzy/similar strings with small Levenshtein-Damerau distance.

local luaven = {}

-- luaven.all iterates over all patterns similar to s with Levenshtein-Damerau
-- distance 1. Also, it calls function post (by default luaven.gsub_quote) on
-- retained fragments of s.
--
-- TODO: handle UTF-8 properly
function luaven.all(s, post)
	local post = post or luaven.gsub_quote
	return coroutine.wrap(function()
		-- patterns with distance 1 by insertion:
		-- build by inserting '.' between s[i-1] and s[i]
		for i = 1,#s+1 do
			local pre, suf = s:sub(1,i-1), s:sub(i)
			pre, suf = post(pre), post(suf)
			coroutine.yield(pre .. '.' .. suf)
		end
		-- patterns with distance 1 by replacement/deletion:
		-- build by replacing s[i] with '.?'
		for i = 1,#s do
			local pre, suf = s:sub(1,i-1), s:sub(i+1)
			pre, suf = post(pre), post(suf)
			coroutine.yield(pre .. '.?' .. suf)
		end
		-- patterns with distance 1 by swapping (Damerau)
		for i = 1,#s-1 do
			local first, second = s:sub(i,i), s:sub(i+1,i+1)
			local pre, suf = s:sub(1,i-1), s:sub(i+2)
			coroutine.yield(post(pre..second..first..suf))
		end
	end)
end

local quotepattern = '(['..("%^$().[]*+-?"):gsub("(.)", "%%%1")..'])'
-- Source: http://stackoverflow.com/a/20778724/98528
function luaven.gsub_quote(s)
	return s:gsub(quotepattern, "%%%1")
end

---- DEMO/TEST ----
if not ... then
	for s in luaven.all 'hello' do
		print(s)
	end
end

return luaven

