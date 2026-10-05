-- BOSS-FRAMEWORK 전/후 하네스(판정 · 전조 · 피해 시각): 6보스 스킬표(전조 · 모양 · 피해 · 쿨 · 조건) 전부 + 묶음 길이(boundSeconds) + 회피 부등식(dodgeChecks)을
--   한 줄씩 정렬해 찍는다. 변경 전 src(ECON_SRC = git archive 사본)와 지금 src에서 각각 돌려 diff = 0이면 서버 판정 · 전조 · 피해 시각이 같다.
-- 실행: PRELUDE=motion_prelude.luau ECON_RES=timing_new.txt python build_run.py boss_timing_dump.luau (· ECON_SRC=<사본>/roblox/src ECON_RES=timing_old.txt)
local BossData = MODS.BossData
local BSM = MODS.BossSkillMath

local function ser(v, depth)
	depth = depth or 0
	local t = typeof and typeof(v) or type(v)
	if type(v) == "table" then
		if depth > 6 then
			return "{…}"
		end
		local keys = {}
		for k in pairs(v) do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local out = {}
		for _, k in ipairs(keys) do
			local x = v[k]
			if type(x) ~= "function" then
				table.insert(out, tostring(k) .. "=" .. ser(x, depth + 1))
			end
		end
		return "{" .. table.concat(out, ",") .. "}"
	elseif type(v) == "number" then
		return ("%.6g"):format(v)
	end
	return tostring(v) .. (t ~= type(v) and "" or "")
end

local ids = {}
for id in pairs(BossData.bosses) do
	table.insert(ids, id)
end
table.sort(ids)
for _, id in ipairs(ids) do
	local b = BossData.bosses[id]
	print(("BOSS %s move=%s chaseStop=%s gcd=%s hp=%s"):format(id, ser(b.moveSpeedStuds), ser(b.chaseStopDistanceStuds), ser(b.globalCooldownSeconds), ser(b.hpMultiplier)))
	for _, sid in ipairs(b.skillOrder or {}) do
		local sk = b.skills[sid]
		local okB, bound = pcall(BSM.boundSeconds, sk, 140, 2)
		print(("SKILL %s.%s bound=%s %s"):format(id, sid, okB and ser(bound) or "err", ser(sk)))
		local okD, checks = pcall(BSM.dodgeChecks, sk, 8, 16)
		if okD then
			for _, ch in ipairs(checks) do
				print(("DODGE %s.%s %s ok=%s avail=%s need=%s"):format(id, sid, tostring(ch.label), tostring(ch.ok), ser(ch.availableSeconds), ser(ch.requiredSeconds)))
			end
		end
	end
end
print("TIMING END")
