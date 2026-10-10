-- BOSS-NIGHT-3 0단계: 6보스 새 몸 인스턴스(스테이지 100 · 솔로 · applyBodyEdge → applyV3) 스킬 필드 덤프
local BR, BF = MODS.BossRules, MODS.BossFramework
local walk = MODS.WorldConfig.playerWalkSpeedStuds
local function flat(t, prefix, out, depth)
	for k, v in pairs(t) do
		local key = prefix .. tostring(k)
		if type(v) == "table" and depth < 3 then
			if #v > 0 and type(v[1]) ~= "table" then
				local parts = {}
				for _, x in ipairs(v) do table.insert(parts, tostring(x)) end
				out[key] = "{" .. table.concat(parts, ",") .. "}"
			else
				flat(v, key .. ".", out, depth + 1)
			end
		elseif type(v) ~= "table" and type(v) ~= "function" then
			out[key] = type(v) == "number" and string.format("%.3g", v) or tostring(v)
		end
	end
end
for _, id in ipairs({ "section_guardian", "crystal_queen", "abyssal_lord", "scorpion_queen", "storm_lord", "frost_giant" }) do
	local stage = STAGE or 100
	local d = BR.buildInstanceData(stage, id, 1)
	local e = BF.applyBodyEdge(d, id .. "_v2", walk)
	local g = BF.applyV3(e, id .. "_v2")
	print(("BOSS\t%s\tstage %d\torder %s\treactive %s\tbasic %s"):format(id, stage, table.concat(g.skillOrder, ","), table.concat(g.reactiveOrder or {}, ","), (function()
		local o = {}
		flat(g.basicAttack or {}, "", o, 0)
		local t = {}
		for k, v in pairs(o) do table.insert(t, k .. "=" .. v) end
		table.sort(t)
		return table.concat(t, " ")
	end)()))
	local ids = {}
	for sid in pairs(g.skills) do table.insert(ids, sid) end
	table.sort(ids)
	for _, sid in ipairs(ids) do
		local o = {}
		flat(g.skills[sid], "", o, 0)
		local t = {}
		for k, v in pairs(o) do table.insert(t, k .. "=" .. v) end
		table.sort(t)
		print(("SKILL\t%s\t%s\t%s"):format(id, sid, table.concat(t, "|")))
	end
end
