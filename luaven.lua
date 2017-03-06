-- Module luaven provides functions generating Lua string patterns for matching
-- fuzzy/similar strings with small Levenshtein-Damerau distance.

local luaven = {}

-- luaven.all iterates over all patterns similar to s with Levenshtein-Damerau
-- distance 1.
--
-- TODO: handle UTF-8 properly
function luaven.all(s)
	return coroutine.wrap(function()
		-- patterns with distance 1 by insertion:
		-- build by inserting '.' between s[i-1] and s[i]
		for i = 1,#s+1 do
			local pre, suf = s:sub(1,i-1), s:sub(i)
			coroutine.yield(pre .. '.' .. suf)
		end
		-- patterns with distance 1 by replacement/deletion:
		-- build by replacing s[i] with '.?'
		for i = 1,#s do
			local pre, suf = s:sub(1,i-1), s:sub(i+1)
			coroutine.yield(pre .. '.?' .. suf)
		end
		-- -- patterns with distance 1 by swapping (Damerau)
		-- for i = 1,#s-1 do
		-- 	local first, second = s:sub(i,i), s:sub(i+1,i+1)
		-- 	local pre, suf = s:sub(1,i-1), s:sub(i+2)
		-- 	coroutine.yield(pre..second..first..suf)
		-- end
	end)
end

local cowrap, yield = coroutine.wrap, coroutine.yield
-- luaven.extend generates all new patterns (of Levenhstein distance +1) based
-- on pattern, which become possible only when suffix is added. Suffix is
-- assumed atomic (nondivisable) - usually it should be a single character
-- (possibly UTF-8 one).
--
-- In other words: if pattern has distance L from a word, then result has
-- distance L+1 from word+suffix.
--
-- Example:
--  luaven.extend("worl", "d") -> "worl.d", "world.", "worl.?"
--  -- but not: "world"
--  luaven.extend("", "w") -> ".w", "w.", ".?"
--  -- but not: "w"
--
-- TODO: handle Damerau too; probably requires new function
function luaven.extend(pattern, suffix)
	return cowrap(function()
		-- IMPORTANT: if modifying below, modify luaven.append too
		yield(pattern .. '.' .. suffix)
		yield(pattern .. suffix .. '.')
		yield(pattern .. '.?')
	end)
end

-- luaven.append generates all new patterns (of Levenhstein distance up to
-- max_level) which become possible only when suffix is added to old patterns.
-- Suffix is assumed atomic (nondivisable) - usually it should be a single
-- character (possibly UTF-8 one).
--
-- In other words: if pattern has distance L from a word, then result has
-- distance L+1 from word+suffix.
--
-- Example:
--  t = lua.append(nil, 'h', 2)
--  assert(t.suffix=='h')
--  assert(t[0]['h'])
--  assert(t[1]['.h'] and t[1]['h.'] and t[1]['.?'])
--  t0, t = t, lua.append(t, 'i', 2)
--  assert(t.suffix=='i' and t.old==t0)
--  assert(t[0]['hi'])
--  for _,s in ipairs{'.hi', 'h.i', '.?i', 'hi.', 'h.?'} do
--    assert(t[1][s])
--  end
--  for _,s in ipairs{'.h.i', '.hi.', 'h..i', 'h.i.', 'hi..', 
--  assert(t[1]['.hi'] and t[1]['
--  -- {suffix="h",
--  --  [0]={ ["h"]=true },
--  --  [1]={ [".]
--
-- TODO: doc
-- TODO: example
-- TODO: Damerau
-- TODO: merge into luaven.extend, depending on 1st arg
function luaven.append(old, suffix, max_level)
	local old = old or {}

	local new = {
		old=old,
		suffix=suffix,
	}
	local init = { [0]={ ['']=true } }
	for i = 0,max_level do
		local new_level = {}
		-- level L .. suffix = level L
		for k in pairs(old[i] or init[i] or {}) do
			new_level[k..suffix] = true
		end
		-- luaven.extend(level L-1, suffix) = level L
		if i>=1 then
			for k in pairs(old[i-1] or init[i-1] or {}) do
				-- IMPORTANT: if modifying below, modify luaven.extend too
				new_level[k .. '.' .. suffix] = true
				new_level[k .. suffix .. '.'] = true
				new_level[k .. '.?'] = true
			end
		end
		-- other...
		-- FIXME: generate 'hello..' for i==2 etc.
		-- if i>=2 then
		-- 	for k in pairs(old[i-2] or init[i-2] or {}) do
		-- 		new_level[k .. ('.'):rep(

		-- -- older(L-1) + suffix + old(suffix) = L  -- Damerau 1
		-- local older = old.old
		-- if i>0 and older then
		-- 	for k in pairs(older[i-1] or start) do
		-- 		new_level[k .. suffix .. old.suffix] = true
		-- 	end
		-- end
		-- local even_older = (older or {}).old
		-- -- Damerau 2
		-- if i>0 and even_older then
		-- 	for k in pairs(
		-- end
		-- store
		new[i] = new_level
	end
	return new
end

---- DEMO/TEST ----
if not ... then
	-- local word = 'hello'
	local word = 'hi'

	-- luaven.all
	for s in luaven.all(word) do
		print(s)
	end

	-- luaven.append
	local app = {}
	for i=1,#word do
		app = luaven.append(app, word:sub(i,i), 2)
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
		if app[2][v] then
			print('  '..v)
			app[2][v] = nil
		else
			print('- '..v)
		end
	end
	for k in pairs(app[2]) do
		print('+ '..k)
	end
end

return luaven

