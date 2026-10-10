-- HP-SCALE-1 측정 · 시나리오 라이브러리(설계 시뮬 전용 - 하네스 메모리 안에서만 MODS 함수를 덮는다. 게임 데이터 · 코드 파일은 안 바뀐다).
-- 손잡이 = HPCFG(시나리오 파일 · 없으면 지금 게임):
--   H = { mode = "none" | "exp" | "seg", rate = 스테이지당 배율(exp), seg = { { 스테이지, 배율 }, ... }(로그 보간), base = 스테이지 1 배율 }
--     체력 출처(기본 · 갑옷) · 방어 출처(기본 · 갑옷) · 몹 · 보스 공격 = 같은 H. 키 = 갑옷 = itemLevel · 기본 = 캐릭터 스테이지(레벨 → 스테이지) · 몹 = 그 스테이지.
--   기본 체력 10 · 기본 방어 5 = × H(레벨 스테이지 = 레벨 + levelStageOffset) - 플레이어 쪽은 지금 스테이지를 안 본다(스테이지 바뀔 때 최대 체력이 튀지 않게)
-- 출력: HP| 줄(목표 스테이지 첫 도달 청크의 표).
local CFG = HPCFG or {}
HPS = { rows = {} }
local M = MODS
local EconSim, BalanceSim, MonsterStats, CombatConfig, Loot, CharacterLevel, BossRules, BossData, MonsterData, PlayerCombat, CombatFormula, InfiniteStage =
	M.EconSim, M.BalanceSim, M.MonsterStats, M.CombatConfig, M.Loot, M.CharacterLevel, M.BossRules, M.BossData, M.MonsterData, M.PlayerCombat, M.CombatFormula, M.InfiniteStage

local function interpLog(points, s)
	if s <= points[1][1] then return points[1][2] end
	for i = 2, #points do
		local b = points[i]
		if s <= b[1] then
			local a = points[i - 1]
			local u = (s - a[1]) / (b[1] - a[1])
			return math.exp(math.log(a[2]) + (math.log(b[2]) - math.log(a[2])) * u)
		end
	end
	return points[#points][2]
end

local function H(s)
	s = math.max(1, s or 1)
	if CFG.H == nil or CFG.H.mode == "none" then return 1 end
	if CFG.H.mode == "exp" then return (CFG.H.base or 1) * CFG.H.rate ^ (s - 1) end
	return interpLog(CFG.H.seg, s)
end
HPS.H = H

-- ── 시나리오: 같은 H를 체력 · 방어 · 몹 공격에 ──
if CFG.H and CFG.H.mode ~= "none" then
	local oldHpBonus, oldArmorDef = Loot.getMaxHpBonus, Loot.getArmorDefense
	Loot.getMaxHpBonus = function(item)
		if not item then return 0 end
		return oldHpBonus(item) * H(item.itemLevel)
	end
	Loot.getArmorDefense = function(item)
		if not item then return 0 end
		return oldArmorDef(item) * H(item.itemLevel)
	end
	-- 기본 체력 · 방어: buildLoadout이 CombatConfig.playerMaxHp · playerDefense를 읽는다 → 청크마다 레벨 스테이지로 바꿔 둔다(loadoutFor 감싸기)
	local oldTrash, oldBoss = MonsterStats.trashAttack, MonsterStats.bossAttack
	MonsterStats.trashAttack = function(base, stage) return oldTrash(base, stage) * H(stage) end
	MonsterStats.bossAttack = function(base, stage, boss) return oldBoss(base, stage, boss) * H(stage) end
end

local BASE_HP, BASE_DEF = CombatConfig.playerMaxHp, CombatConfig.playerDefense
local function setBaseFor(level)
	if CFG.H and CFG.H.mode ~= "none" then
		local s = CharacterLevel.getStageForLevel and CharacterLevel.getStageForLevel(level) or level
		local h = H(s)
		CombatConfig.playerMaxHp = BASE_HP * h
		CombatConfig.playerDefense = BASE_DEF * h
	end
end

-- ── 측정: 청크마다 loadout을 붙인다(stepLevel 호출 = withOverrides(whatIf, stepLevel, state, ...)) ──
local oldWith = EconSim.withOverrides
EconSim.withOverrides = function(whatIf, fn, state, ...)
	if type(state) == "table" and state.gear and state.level then
		setBaseFor(state.level)
	end
	local r = oldWith(whatIf, fn, state, ...)
	if type(r) == "table" and r.reach and type(state) == "table" and state.gear then
		setBaseFor(state.level)
		r.__lo = EconSim.loadoutFor(state)
		r.__ilArmor = state.gear.armor and state.gear.armor.itemLevel or 0
	end
	return r
end

-- 보스 강공격 배율(attack 종류 · bubble heavy 중 최대) · 평타 배율
local function bossMults(bossId)
	local boss = BossData.bosses[bossId]
	local heavy, basic = 0, 1
	for _, sk in pairs(boss.skills or {}) do
		if type(sk) == "table" and sk.bubble == "heavy" and type(sk.damage) == "table" and sk.damage.kind == "attack" and sk.damage.multiplier then
			heavy = math.max(heavy, sk.damage.multiplier)
		end
	end
	if boss.basicAttack and boss.basicAttack.damageMultiplier then basic = boss.basicAttack.damageMultiplier end
	return heavy, basic
end

local TARGETS = CFG.targets or { 1, 10, 46, 100, 500, 1000, 5000, 8500, 25300 }
function HPS.report(run, prof)
	local tierIndex = 5 -- 기준 구역(CombatFormulaData.representative.referenceTier)
	local tier = MonsterData[MonsterData.tierOrder[tierIndex]]
	local profTier = MonsterData[MonsterData.tierOrder[({ casual = 3, normal = 5, top = 6, unluckyP90 = 6 })[prof] or 5]] -- HP 줄(목표 스테이지 표) = 프로필 최고 구역
	-- 청크마다: 사냥 스테이지 기준 몹 생존 타수 · 도달 스테이지 보스 강공격 생존 타수(시나리오 대조용 - 청크 번호로 맞춘다)
	for i, c in ipairs(run.chunks) do
		local lo = c.__lo
		if lo then
			local s = math.max(1, c.stage or 1)
			local A = MonsterStats.trashAttack(tier.attack, s)
			local take = PlayerCombat.getNewbieDamageMultiplier(c.reach) * CharacterLevel.levelGapTakeMultiplier(lo.level, s) * CombatFormula.takeMultiplier(lo.defense, s, A) * (lo.guardTake or 1)
			local hits = BalanceSim.getSurviveHits(lo, A, take)
			local bs = c.reach
			local bid = BossRules.isBossStage(bs) and BossRules.bossIdForStage(bs)
			local bhits = 0
			if bid then
				local data = BossRules.buildInstanceData(bs, bid, 1)
				local heavy = bossMults(bid)
				local _, one = BalanceSim.getSurviveHits(lo, data.attack, PlayerCombat.getNewbieDamageMultiplier(c.reach) * CharacterLevel.levelGapTakeMultiplier(lo.level, bs) * (lo.guardTake or 1))
				bhits = lo.maxHp / (one * heavy)
			end
			print(("HC|%d|%d|%d|%.6g|%.6g|%.6g|%.6g"):format(i, c.reach, s, hits, bhits, lo.maxHp, (c.__ilArmor or 0)))
		end
	end
	local ti = 1
	print("HPH|목표|reach|level|maxHp|def|atk|critAvg|mobAtk|mobHit|mobHits|bossStage|bossAtk|bossBasicHit|bossHeavyHit|bossHeavyHits|regen|takeMob|H")
	for _, c in ipairs(run.chunks) do
		while ti <= #TARGETS and c.reach >= TARGETS[ti] and c.__lo do
			local s = TARGETS[ti]
			local lo = c.__lo
			local newbie = PlayerCombat.getNewbieDamageMultiplier(c.reach)
			local A = MonsterStats.trashAttack(profTier.attack, s)
			local take = newbie * CharacterLevel.levelGapTakeMultiplier(lo.level, s) * CombatFormula.takeMultiplier(lo.defense, s, A) * (lo.guardTake or 1)
			local hits, hit = BalanceSim.getSurviveHits(lo, A, take)
			local bs = BossRules.isBossStage(s) and s or (BossRules.getBossStageBelow(s) or s)
			if bs < 1 then bs = s end
			local bid = BossRules.bossIdForStage(bs)
			local bh, bhits, bbasic, batk = 0, 0, 0, 0
			if bid then
				local data = BossRules.buildInstanceData(bs, bid, 1)
				batk = data.attack
				local heavy, basic = bossMults(bid)
				local btake = PlayerCombat.getNewbieDamageMultiplier(c.reach) * CharacterLevel.levelGapTakeMultiplier(lo.level, bs) * (lo.guardTake or 1)
				local _, one = BalanceSim.getSurviveHits(lo, batk, btake)
				bh, bbasic = one * heavy, one * basic
				bhits = bh > 0 and lo.maxHp / bh or 0
			end
			print(("HP|%d|%d|%d|%.6g|%.6g|%.6g|%.6g|%.6g|%.6g|%.3f|%d|%.6g|%.6g|%.6g|%.3f|%.6g|%.4f|%.6g"):format(s, c.reach, lo.level, lo.maxHp, lo.defense, lo.atk, lo.atk * (lo.critMultAvg or 1),
				A, hit, hits, bs, batk, bbasic, bh, bhits, lo.maxHp * CombatConfig.regenPercentPerSecond, take, H(s)))
			ti += 1
		end
	end
end
