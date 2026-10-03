-- QUEUE-B1 결정 14: 캐릭터 경험치 곡선 이관 왕복(v34 이하 · v44 표본 → 지금 곡선). 레벨 · 진행률이 그대로여야 한다.
-- 표본은 그 버전 시절의 **옛 곡선**으로 만든다(지금 코드의 CharacterLevel로 만들면 v35 버그를 못 잡는다 - QUEUE-6h-b 감사 ①).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=SaveSystem ECON_RES=res_mig.txt python build_run.py migrate_curve_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[MIG] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

local ok, err = pcall(function()
	local SaveSystem = MODS.SaveSystem
	local CharacterLevel = MODS.CharacterLevel

	-- v34 ~ v44 시절 목표 마릿수(v45 단계의 OLD 리터럴과 같다 - 126부터 150) · v35 ~ v44의 126+ 배수(20,000 ÷ 150 · 레벨당 ×0.99 · 하한 1)
	local OLD = { { 1, 5 }, { 25, 15 }, { 50, 60 }, { 75, 350 }, { 100, 2500 }, { 125, 20000 } }
	local function oldKills(level)
		if level <= OLD[1][1] then return OLD[1][2] end
		for i = 2, #OLD do
			local a, b = OLD[i - 1], OLD[i]
			if level <= b[1] then return a[2] + (b[2] - a[2]) * (level - a[1]) / (b[1] - a[1]) end
		end
		return 150
	end
	local function need34(level)
		return math.floor(oldKills(level) * CharacterLevel.getMonsterExpAtLevel(level) + 0.5)
	end
	local function need44(level)
		local scale = level > 125 and math.max((20000 / 150) * 0.99 ^ (level - 126), 1) or 1
		return math.floor(oldKills(level) * CharacterLevel.getMonsterExpAtLevel(level) * scale + 0.5)
	end
	local function sample(needFn, L, frac)
		local acc = 0
		for level = 1, L - 1 do acc += needFn(level) end
		return acc + needFn(L) * frac
	end
	local function roundTrip(version, exp)
		local d = SaveSystem.defaultProfile()
		d.version = version
		local cid = next(d.classes)
		d.classes[cid].characterExp = exp
		local m = SaveSystem.migrate(d)
		local e = m.classes[cid].characterExp
		local lv = CharacterLevel.getLevelFromExp(e)
		return lv, CharacterLevel.getProgress(e, lv).ratio, m
	end

	-- 1) v34 표본(옛 곡선 · 배수 없음): 126 아래 · 126 · 200 · 300
	for _, L in ipairs({ 30, 80, 120, 126, 200, 300 }) do
		local lv, ratio = roundTrip(34, sample(need34, L, 0.4))
		check(("v34 레벨 %d · 0.4"):format(L), lv == L and math.abs(ratio - 0.4) < 0.002, ("→ 레벨 %d · %.3f"):format(lv, ratio))
	end
	-- 2) v34보다 옛 표본(v33 · v30 - 앞 단계가 경험치를 안 건드림 · 옛 곡선 그대로)
	for _, v in ipairs({ 30, 33 }) do
		local lv, ratio = roundTrip(v, sample(need34, 200, 0.25))
		check(("v%d 레벨 200 · 0.25"):format(v), lv == 200 and math.abs(ratio - 0.25) < 0.002, ("→ 레벨 %d · %.3f"):format(lv, ratio))
	end
	-- 3) v35 ~ v44 표본(126+ 배수 곡선) → v45 단계만: 바뀌지 않아야 한다
	for _, L in ipairs({ 30, 126, 200, 300 }) do
		local lv, ratio = roundTrip(44, sample(need44, L, 0.4))
		check(("v44 레벨 %d · 0.4"):format(L), lv == L and math.abs(ratio - 0.4) < 0.002, ("→ 레벨 %d · %.3f"):format(lv, ratio))
	end
	-- 4) 경계: 0 · 레벨 1 · v34 정확히 126 임계값
	local lv0 = roundTrip(34, 0)
	check("v34 경험치 0", lv0 == 1, ("→ 레벨 %d"):format(lv0))
	local lvB, rB = roundTrip(34, sample(need34, 126, 0))
	check("v34 레벨 126 · 0(경계)", lvB == 126 and rB < 0.002, ("→ 레벨 %d · %.3f"):format(lvB, rB))
	-- 6) QUEUE-ALL9B 2-4 v65: 공용 수련 최대 50단계(51 이상 = 50 · 나머지 · 직업 능력 그대로 · 멱등)
	do
		local d = SaveSystem.defaultProfile()
		d.version = 64
		d.training = { attack = 100, hp = 73, defense = 12 }
		local cid = next(d.classes)
		d.classes[cid].abilities = { gs_might = 50, bow_might = 50 }
		local m = SaveSystem.migrate(d)
		check("v64 → v65 수련 100/73/12 → 50/50/12", m.version >= 65 and m.training.attack == 50 and m.training.hp == 50 and m.training.defense == 12,
			("→ %s/%s/%s"):format(tostring(m.training.attack), tostring(m.training.hp), tostring(m.training.defense)))
		check("v65 직업 능력 그대로", m.classes[cid].abilities.gs_might == 50 and m.classes[cid].abilities.bow_might == 50)
		local again = SaveSystem.migrate(m)
		check("v65 이관 멱등(다시 돌려도 50/50/12)", again.training.attack == 50 and again.training.hp == 50 and again.training.defense == 12)
	end
	-- 7) QUEUE-ALL9B v66: 시즌 패스 건너뛰기 기록(옛 계정 = 0 · 빈 표 · 받은 칸 그대로)
	do
		local d = SaveSystem.defaultProfile()
		d.version = 65
		d.seasonPass = { season = 3, premium = true, claimedFree = { ["1"] = true }, claimedPaid = {} }
		local m = SaveSystem.migrate(d)
		check("v65 → v66 seasonPass.skipBought 0 · skipTiers 빈 표 · 받은 칸 유지", m.version >= 66 and m.seasonPass.skipBought == 0 and type(m.seasonPass.skipTiers) == "table" and m.seasonPass.claimedFree["1"] == true and m.seasonPass.premium == true)
	end
	-- 8) QUEUE-ALL9B v67: 시즌 출석판(옛 계정 = 빈 판 · 7일 출석 · 퀘스트 그대로)
	do
		local d = SaveSystem.migrate({})
		d.version = 66
		d.quests.board = nil
		d.quests.attendance = { count = 3, lastDay = 5, claimed = { ["1"] = true } }
		local m = SaveSystem.migrate(d)
		check("v66 → v67 quests.board 빈 판 · 7일 출석 유지", m.version >= 67 and type(m.quests.board) == "table" and m.quests.board.count == 0 and m.quests.attendance.count == 3)
		local fresh = SaveSystem.migrate({})
		check("새 계정 = 출석판 있음(count 0)", type(fresh.quests.board) == "table" and fresh.quests.board.count == 0)
	end
	-- 5) 새 계정 빈 표
	local okEmpty, m = pcall(SaveSystem.migrate, {})
	check("migrate({})", okEmpty and type(m) == "table" and m.version == MODS.SaveConfig.saveVersion, okEmpty and ("v" .. tostring(m.version)) or tostring(m))
end)
if not ok then print("[MIG] 에러 " .. tostring(err)) end
print(("[MIG] 끝 %d/%d"):format(pass, total))
