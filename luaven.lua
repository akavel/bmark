-- Module luaven provides functions generating Lua string patterns for matching
-- fuzzy/similar strings with small Levenshtein-Damerau distance.

local luaven = {}

-- luaven.all iterates over all patterns similar to s with Levenshtein-Damerau
-- distance 1. Only ANSI strings are handled properly.
--
-- IMPORTANT NOTE: create patterns are *not* Lua gsub patterns. To convert a
-- created pattern to Lua gsub pattern, for default UTF-8, replace every "?"
-- with ".?".
--
-- Example:
--  for s in luaven.all "hi" do io.write(s.." ") end
--  -- ?i h? .hi h.i hi. ih
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

-- luaven.all_utf8 is an experimental variant of luaven.all, trying to handle
-- UTF-8 strings appropriately.
function luaven.all_utf8(s)
	-- regexp: ([0x00-0x7f]|[0xc0-0xff][0x80-0xbf]*)
	local utf8_char = '[^\128-\191][\128-\191]*'
	local offs = {}  -- n-th character start offsets
	s:gsub('()'..utf8_char, function(i, c) offs[#offs+1] = i end)
	offs[#offs+1] = #s+1  -- first offset out of string bounds
	-- for _,v in ipairs(offs) do print(v) end
	return coroutine.wrap(function()
		-- patterns with distance 1 by replacement/deletion:
		-- build by replacing s[i] with '?'
		for i = 1,#offs-1 do
			local pre, suf = s:sub(1,offs[i]-1), s:sub(offs[i+1])
			coroutine.yield(pre .. '?' .. suf)
		end
		-- patterns with distance 1 by insertion:
		-- build by inserting '.' between s[i-1] and s[i]
		for i = 1,#offs do
			local pre, suf = s:sub(1,offs[i]-1), s:sub(offs[i])
			coroutine.yield(pre .. '.' .. suf)
		end
		-- patterns with distance 1 by swapping (Damerau)
		for i = 1,#offs-2 do
			local first, second = s:sub(offs[i],offs[i+1]-1), s:sub(offs[i+1],offs[i+2]-1)
			local pre, suf = s:sub(1,offs[i]-1), s:sub(offs[i+2])
			coroutine.yield(pre..second..first..suf)
		end
	end)
end


---- DEMO/TEST ----
if not ... then
	-- local word = 'hello'
	local word = 'hi'

	-- luaven.all
	local expect = {'?i', 'h?', '.hi', 'h.i', 'hi.', 'ih'}
	local i = 1
	for s in luaven.all(word) do
		print(s)
		if s ~= expect[i] then print(' FAIL: wanted '..expect[i]) end
		i = i+1
	end

	-- luaven.all_utf8 on ANSI string
	print()
	local i = 1
	for s in luaven.all(word) do
		print(s)
		if s ~= expect[i] then print(' FAIL: wanted '..expect[i]) end
		i = i+1
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

	-- luaven.all_utf8
	print()
	local expect = {'?ż', 'ł?', '.łż', 'ł.ż', 'łż.', 'żł'}
	local i = 1
	for s in luaven.all_utf8 'łż' do
		print(s)
		if s ~= expect[i] then print(' FAIL: wanted '..expect[i]) end
		i = i+1
	end
end

return luaven

