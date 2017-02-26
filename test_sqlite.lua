FILE = '/Mateusz/bmark.md'

function main()
	local sqlite = (require 'luasql.sqlite3').sqlite3()
	local conn = sqlite:connect ':memory:'

	assert(conn:execute [[
		create table if not exists "bmark"(
			url text primary key asc not null,
			note text not null,
			time text not null,
			deleted boolean not null
		)
	]])

	-- read notes into sqlite
	local entry = {}
	for line in io.lines(FILE) do
		if line:match(timestamp_pattern) then
			finalize_entry(entry, conn)
			-- print('['..line..']')
		end
		entry[#entry+1] = line
	end
	finalize_entry(entry, conn)
end

timestamp_pattern = '^{#t(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)(%d%d)}$'

function finalize_entry(entry, conn)
	if #entry == 0 then return end
	local header = table.remove(entry, 1)
	local time = string.format('%s-%s-%s %s:%s:%s', header:match(timestamp_pattern))
	local note = table.concat(entry, '\n')
	local db_entry = {
		url = find_first_url(note),
		time = time,
		note = note,
		deleted = false,
	}
	if not db_entry.url then
		io.stderr:write('warning: no url in note ', header, ', merging with next\n')
		table.insert(entry, 1, header)
		return
	end
	local n, err = conn:execute(mk_insert('bmark', db_entry, conn))
	for k in pairs(entry) do entry[k] = nil end
	if not n then
		io.stderr:write('error: for '..db_entry.url..': '..err)
		return
	end
	if n~=1 then
		io.stderr:write('error: bad # of rows updated for '..db_entry.url..': '..tostring(n))
		return
	end
end

function mk_insert(table_name, entry, conn)
	local fields, values = {}, {}
	for k,v in pairs(entry) do
		fields[#fields+1] = k
		values[#values+1] =
			type(v)=='string' and "'"..conn:escape(v).."'" or
			type(v)=='number' and v or
			type(v)=='boolean' and (v and 1 or 0) or
			type(v)=='nil' and 'NULL' or
			error('unsupported type of '..k..': '..type(v))
	end
	local s= (string.format('insert into %s(%s) values (%s)',
		table_name, table.concat(fields, ','), table.concat(values, ',')))
	print(s) return s
end

local domains = [[.ac.ad.ae.aero.af.ag.ai.al.am.an.ao.aq.ar.arpa.as.asia.at.au
	.aw.ax.az.ba.bb.bd.be.bf.bg.bh.bi.biz.bj.bm.bn.bo.br.bs.bt.bv.bw.by.bz.ca
	.cat.cc.cd.cf.cg.ch.ci.ck.cl.cm.cn.co.com.coop.cr.cs.cu.cv.cx.cy.cz.dd.de
	.dj.dk.dm.do.dz.ec.edu.ee.eg.eh.er.es.et.eu.fi.firm.fj.fk.fm.fo.fr.fx.ga
	.gb.gd.ge.gf.gh.gi.gl.gm.gn.gov.gp.gq.gr.gs.gt.gu.gw.gy.hk.hm.hn.hr.ht.hu
	.id.ie.il.im.in.info.int.io.iq.ir.is.it.je.jm.jo.jobs.jp.ke.kg.kh.ki.km.kn
	.kp.kr.kw.ky.kz.la.lb.lc.li.lk.lr.ls.lt.lu.lv.ly.ma.mc.md.me.mg.mh.mil.mk
	.ml.mm.mn.mo.mobi.mp.mq.mr.ms.mt.mu.museum.mv.mw.mx.my.mz.na.name.nato.nc
	.ne.net.nf.ng.ni.nl.no.nom.np.nr.nt.nu.nz.om.org.pa.pe.pf.pg.ph.pk.pl.pm
	.pn.post.pr.pro.ps.pt.pw.py.qa.re.ro.ru.rw.sa.sb.sc.sd.se.sg.sh.si.sj.sk
	.sl.sm.sn.so.sr.ss.st.store.su.sv.sy.sz.tc.td.tel.tf.tg.th.tj.tk.tl.tm.tn
	.to.tp.tr.travel.tt.tv.tw.tz.ua.ug.uk.um.us.uy.va.vc.ve.vg.vi.vn.vu.web.wf
	.ws.xxx.ye.yt.yu.za.zm.zr.zw]]
local tlds = {}
for tld in domains:gmatch'%w+' do
	tlds[tld] = true
end
-- Source: http://stackoverflow.com/a/23592008/98528
function find_first_url(text_with_URLs)
	-- all characters allowed to be inside URL according to RFC 3986 but without
	-- comma, semicolon, apostrophe, equal, brackets and parentheses
	-- (as they are used frequently as URL separators)
	--[[
		<a href="http://www.lua.org:80/manual/5.2/contents.html">L.ua 5.2</a>
		[url=127.0.0.1:8080]forum link[/url]
		intranet links: http://test, http://retracker.local/announce
		[markdown link](https://74.125.143.101/search?q=Who+are+the+Lua+People%3F)
		long subdomain chain: very.long.name.of.my.site.co.uk
		auth link: ftp://user:pwd@site.com/path - not recognized yet :(
	]]

	local function max4(a,b,c,d) return math.max(a+0, b+0, c+0, d+0) end
	local protocols = {[''] = 0, ['http://'] = 0, ['https://'] = 0, ['ftp://'] = 0}
	local first, first_pos

-- () (( [%w_.~!*:@&+$/?%%#-]- )( %w [-.%w]* %.)( %w+ )( :? )( %d* )( /? )( [%w_.~!*:@&+$/?%%#=-]* ))
--      \----- "prot" --------/  \-- "subd" --/  \tld/  \- port* -/        \---- "path" ----------/

	for pos_start, url, prot, subd, tld, colon, port, slash, path in
		text_with_URLs:gmatch'()(([%w_.~!*:@&+$/?%%#-]-)(%w[-.%w]*%.)(%w+)(:?)(%d*)(/?)([%w_.~!*:@&+$/?%%#=-]*))'
	do
		-- protocols[prot:lower()] == 0 and
		-- (#slash=='/' or #path=='')
		if protocols[prot:lower()] == (1 - #slash) * #path and not subd:find'%W%W'
			and (colon == '' or port ~= '' and port + 0 < 65536)
			and (tlds[tld:lower()] or tld:find'^%d+$' and subd:find'^%d+%.%d+%.%d+%.$'
			and max4(tld, subd:match'^(%d+)%.(%d+)%.(%d+)%.$') < 256)
		then
			first, first_pos = url, pos_start
			break
		end
	end

	for pos_start, url, prot, dom, colon, port, slash, path in
		text_with_URLs:gmatch'()((%f[%w]%a+://)(%w[-.%w]*)(:?)(%d*)(/?)([%w_.~!*:@&+$/?%%#=-]*))'
	do
		if not (dom..'.'):find'%W%W'
			and protocols[prot:lower()] == (1 - #slash) * #path
			and (colon == '' or port ~= '' and port + 0 < 65536)
		then
			if pos_start < first_pos then
				first, first_pos = url, pos_start
			end
			break
		end
	end

	return first
end

main()

