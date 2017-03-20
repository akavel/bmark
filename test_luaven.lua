FILE = '/Mateusz/bmark.md'

local luaven = require 'luaven'

matches = {}
patterns = {}

function main(...)
	if #({...}) == 0 then
		print [[USAGE: lua test_luaven.lua PATTERN...]]
		os.exit(1)
	end
	patterns = { [0]={} }
	for _, p in ipairs{...} do
		patterns[0][p] = true
	end

	local watch = Stopwatch()

	-- generate patterns up to Levenshtein-Damerau distance 2 from original
	-- pattern
	for i = 1,2 do
		patterns[i] = {}
		for p in pairs(patterns[i-1]) do
			for s in luaven.all(p) do
				patterns[i][s] = true
			end
		end
	end

	-- remove very stupid patterns, if generated
	for i = 1,2 do
		patterns[i]['.'] = nil
		patterns[i]['?'] = nil
		patterns[i]['..'] = nil
		patterns[i]['?.'] = nil
		patterns[i]['.?'] = nil
		patterns[i]['??'] = nil
	end

	-- convert patterns to Lua search patterns
	do
		local searches = {}
		for i = 0,2 do
			searches[i] = {}
			for k in pairs(patterns[i]) do
				searches[i]['()'..k:gsub('%?', '.?')..'()'] = true
				-- print('()'..k:gsub('%?', '.?')..'()')
			end
		end
		patterns = searches
	end

	watch:lap('-- +%fs patterns generated')

	-- iterate entries and try to rank them by how they match pattern. Keep
	-- at most max_n results.
	-- TODO: keep *most recent* results (reverse order)
	local max_n = 10
	local results = {}
	for note, time in iterate_entries(FILE) do
		-- rank patterns[0] match as e.g.: 1.0 * n_matches
		-- rank patterns[1] match as e.g.: 0.01 * n_matches
		-- rank patterns[2] match as e.g.: 0.0001 * n_matches
		local rank = 0
		local factor = 1.0
		local snippet = nil
		for i = 0,2 do
			for p in pairs(patterns[i]) do
				for before, after in note:gmatch(p) do
					rank = rank + factor
					if not snippet then
						before = math.max(before-20, 0)
						after = math.min(after+20, #note)
						snippet = note:sub(before, after):gsub('[\n\t ]+', ' ')
					end
				end
			end
			factor = factor*0.01
		end
		if rank > 0 then
			results[#results+1] = {rank, time, note, snippet}
		end
	end
	watch:lap('-- +%fs entries read and ranked')
	table.sort(results, function(a, b)
		if a[1]~=b[1] then return a[1]>b[1] end
		return a[2]>b[2]
	end)
	while #results > max_n do
		table.remove(results)
	end
	watch:lap('-- +%fs entries sorted and trimmed')
	watch:total('-- %fs total')

	-- print top ranking results and snippets
	for _, v in ipairs(results) do
		print(string.format('%f \t ...%s...\n\t%s\n\n', v[1], v[4], v[3]:gsub('\n', '\n\t')))
	end
end

function Stopwatch()
	return setmetatable({t0=os.time(), t1=os.time()}, {__index={
		lap = function(self, fmt_secs, ...)
			local t2 = os.time()
			print(string.format(fmt_secs, os.difftime(t2, self.t1), ...))
			self.t1 = t2
		end,
		total = function(self, fmt_secs, ...)
			local t2 = os.time()
			print(string.format(fmt_secs, os.difftime(t2, self.t0), ...))
		end,
	}})
end

function iterate_entries(file)
	local timestamp_pattern = '^{#t(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)(%d%d)}$'
	local function finalize_entry(entry, conn)
		if #entry == 0 then return end
		local header = entry[1]
		local time = string.format('%s-%s-%s %s:%s:%s', header:match(timestamp_pattern))
		local note = table.concat(entry, '\n')
		coroutine.yield(note, time)
		for k in pairs(entry) do entry[k] = nil end
	end
	return coroutine.wrap(function()
		local entry = {}
		for line in io.lines(FILE) do
			if line:match(timestamp_pattern) then
				finalize_entry(entry, conn)
				-- print('['..line..']')
			end
			entry[#entry+1] = line
		end
		finalize_entry(entry, conn)
	end)
end

main(...)

