-- Module luaven provides functions generating Lua string patterns for matching
-- fuzzy/similar strings with small Levenshtein-Damerau distance.

local luaven = {}

-- luaven.all iterates over all patterns similar to s with Levenshtein-Damerau
-- distance 1.
--
-- IMPORTANT NOTE: create patterns are *not* Lua gsub patterns. To convert a
-- created pattern to Lua gsub pattern, replace every "?" with ".?".
--
-- Example:
--  for s in luaven.all "hi" do io.write(s.." ") end
--  -- ?i h? .hi h.i hi. ih
--
-- TODO: handle UTF-8 properly
function luaven.all(s)
	return coroutine.wrap(function()
		-- patterns with distance 1 by replacement/deletion:
		-- build by replacing s[i] with '?'
		for i = 1,#s do
			local pre, suf = s:sub(1,i-1), s:sub(i+1)
			coroutine.yield(pre .. '?' .. suf)
		end
		-- patterns with distance 1 by insertion:
		-- build by inserting '.' between s[i-1] and s[i]
		for i = 1,#s+1 do
			local pre, suf = s:sub(1,i-1), s:sub(i)
			coroutine.yield(pre .. '.' .. suf)
		end
		-- patterns with distance 1 by swapping (Damerau)
		for i = 1,#s-1 do
			local first, second = s:sub(i,i), s:sub(i+1,i+1)
			local pre, suf = s:sub(1,i-1), s:sub(i+2)
			coroutine.yield(pre..second..first..suf)
		end
	end)
end


---- DEMO/TEST ----
if not ... then
	-- local word = 'hello'
	local word = 'hi'

	-- luaven.all
	for s in luaven.all(word) do
		print(s)
	end

	-- luaven.all + luaven.all
	local dist2 = {}
	for s in luaven.all(word) do
		for s2 in luaven.all(s) do
			dist2[s2] = true
		end
	end
	print()
	local dist2sort = {}
	for k in pairs(dist2) do
		dist2sort[#dist2sort+1] = k
	end
	table.sort(dist2sort)
	for _, v in ipairs(dist2sort) do
		print(v)
	end
end

return luaven

