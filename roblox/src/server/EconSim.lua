-- 경제 시뮬 핵심(P0 E1). 게임의 실제 공식 모듈을 require해서 계산한다 - 공식을 여기 옮겨 적지 않는다(게임이 바뀌면 시뮬도 따라간다).
-- 플레이어 모형(프로필 · what-if)만 shared/data/EconSimConfig.lua에 있다. 개발자 · Studio 전용 - EconSim.isAllowed()가 거짓이면 아무것도 안 한다
-- (RunService:IsStudio() + DevToolsConfig.econSim). 부르는 곳은 DevTools.server.lua(/gg econ · 자동 검증 P0(가))뿐이고, 그 스크립트 자체가
-- 라이브 서버에서는 첫 줄에서 죽는다.
--
-- 계산은 한 번에 한다(매 프레임 금지). 다만 레벨업 수천 번을 한 틱에 몰면 스크립트 시간 초과가 나서 EconSimConfig.yieldSeconds마다(레벨업 사이에서) task.wait()로 양보한다.
-- what-if 덮어쓰기는 게임 데이터 표(InfiniteStageConfig 등)를 **양보 없는 구간 안에서만** 잠깐 바꾸고 되돌린다(withOverrides) - 양보하는 순간에는
-- 항상 원래 값이라 같은 서버의 다른 스크립트(몬스터 · 전투)는 바뀐 값을 절대 못 본다.
--
-- 공식을 직접 계산하지 않고 게임 함수로 대신한 자리(요약 - 자세한 건 각 함수 주석):
--   처치 시간 = BalanceSim.simulateCombat(targetHp) · 생존 = BalanceSim.getSurviveHits · 몬스터 수치 = InfiniteStage · 보스 = BossRules.buildInstanceData
--   레벨업 경험치 = CharacterLevel.getExpToNextLevel · 강화 = Enhance.tryEnhance/getCost · 드랍 개수 = Loot.expectedArmorDropCount · 재료 = Loot.expectedMaterialCount
--   장비 점수 = Loot.getArmorDefense/getGlovesAttackPercent/getShoesSpeedPercent · 보석 값 = Option.valueOf · 경험치 배수 = PlayerProfile.combineExpMultiplier

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EconSimConfig = require(ReplicatedStorage.Shared.data.EconSimConfig)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local GoldCostConfig = require(ReplicatedStorage.Shared.data.GoldCostConfig)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EquipSlots = require(ReplicatedStorage.Shared.data.EquipSlots)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local Option = require(ReplicatedStorage.Shared.Option)
local Gem = require(ReplicatedStorage.Shared.Gem)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local Milestone = require(ReplicatedStorage.Shared.Milestone) -- P2.5b D: 환생 후 레벨 마일스톤(영구 배율)
local MilestoneData = require(ReplicatedStorage.Shared.data.MilestoneData)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PartyState = require(script.Parent.PartyState)

local EconSim = {}

function EconSim.isAllowed()
	return RunService:IsStudio() and DevToolsConfig.econSim == true
end

-- ═══ what-if 덮어쓰기 ═══

-- 표 값 몇 개를 잠깐 바꾸고 fn을 부른 뒤 되돌린다. fn 안에서 양보(task.wait)하면 안 된다(위 모듈 주석).
function EconSim.withOverrides(whatIf, fn, ...)
	assert(EconSim.isAllowed(), "EconSim: Studio · DevToolsConfig.econSim 전용")
	whatIf = whatIf or {}
	local restore = {}
	local function set(tbl, key, value)
		table.insert(restore, { tbl, key, tbl[key] })
		tbl[key] = value
	end
	if whatIf.growthRate then
		set(InfiniteStageConfig, "growthRate", whatIf.growthRate)
	end
	if whatIf.weaponGrowthRate then
		set(CharacterLevelConfig, "weaponMultGrowthRate", whatIf.weaponGrowthRate)
	end
	if whatIf.dealingMultiplier then
		set(SkillData.healer.E, "attackMultiplier", SkillData.healer.E.attackMultiplier * whatIf.dealingMultiplier)
	end
	-- P2 칸(p2before what-if가 P2 전 값을 되살릴 때 쓴다).
	if whatIf.rebirthRequiredLevels then
		set(CharacterLevelConfig.rebirth, "requiredLevels", whatIf.rebirthRequiredLevels)
	end
	if whatIf.optionLevelLogSlope then
		set(OptionData, "levelLogSlope", whatIf.optionLevelLogSlope)
	end
	if whatIf.enhanceGoldAnchor then
		set(GoldCostConfig.anchorStage, "enhance", whatIf.enhanceGoldAnchor)
	end
	if whatIf.primordialDragonOverTier then
		set(DropTableData.primordial, "dragonOverTier", whatIf.primordialDragonOverTier)
	end
	if whatIf.primordialDecayPerLevel then
		set(DropTableData.primordial.levelDecay, "perLevel", whatIf.primordialDecayPerLevel)
	end
	if whatIf.healerAtk then
		set(ClassData.classes.healer, "atk", whatIf.healerAtk)
	end
	if whatIf.dealingAttackMultiplier then
		set(SkillData.healer.E, "attackMultiplier", whatIf.dealingAttackMultiplier)
	end
	if whatIf.dealingInvestmentScaling ~= nil then -- P2.5a: false = 딜링모드 투자 기울기 끄기(치유모드 딜 계산 · p25before)
		set(SkillData.healer.E, "investmentScaling", whatIf.dealingInvestmentScaling or nil)
	end
	if whatIf.partyExpRequiresPresence ~= nil then
		set(EconSimConfig, "partyExpRequiresPresence", whatIf.partyExpRequiresPresence)
	end
	if whatIf.milestoneStat ~= nil then -- P2.5c B2: 마일스톤 버킷이 붙는 곳("attack" · "survival" · "none" = 마일스톤 없음 - 곡선 영향 비교)
		set(MilestoneData, "stat", whatIf.milestoneStat)
	end
	if whatIf.enhanceCostScale then
		local scaled = {}
		for index, cost in ipairs(EnhanceConfig.goldCost) do
			scaled[index] = cost * whatIf.enhanceCostScale
		end
		set(EnhanceConfig, "goldCost", scaled)
	end
	local results = table.pack(pcall(fn, ...))
	for index = #restore, 1, -1 do
		local entry = restore[index]
		entry[1][entry[2]] = entry[3]
	end
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- ═══ 옵션 값 ═══

-- 보석 한 개(게임 모양 { grade, itemLevel, option = { id, roll, roll2 } }) - BalanceSim.buildLoadout이 이 보석을 그대로 읽는다.
-- P2 D1로 levelFactor의 125 동결이 없어져 P0의 "동결 해제 what-if"(선형 연장 배율) 기계는 지웠다 - 곡선은 이제 게임 함수(Option.levelFactor) 그대로다.
function EconSim.makeGem(optionId, grade, itemLevel, roll)
	return { grade = grade, itemLevel = itemLevel, option = { id = optionId, roll = roll, roll2 = roll } }
end

function EconSim.gemValue(gem, classId)
	if not gem then
		return 0
	end
	return Option.valueOf(gem.option, gem.grade, gem.itemLevel, classId)
end

-- ═══ 전투 ═══

local KILL_OPTS_TURN = 0.125 -- BalanceSim.measurePoint와 같은 첫 회전 시간(그 함수의 인자를 그대로 쓴다)

-- targetHp를 잡는 로테이션 처치 시간(초). limitSeconds 안에 못 잡으면 math.huge.
function EconSim.killSeconds(loadout, targetHp, limitSeconds)
	local result = BalanceSim.simulateCombat(loadout, {
		useSkills = true, targetHp = targetHp, durationSeconds = (limitSeconds or 600) + 0.5, turnDelaySeconds = KILL_OPTS_TURN,
	})
	return result.killTime or math.huge
end

-- 처치 시간은 "HP ÷ 공격력"에만 달려 있다(simulateCombat의 모든 피해가 atk에 비례 - 쿨다운 · 비행시간은 atk와 무관). 그래서 같은 직업 · 같은 공속이면
-- "목표 초 안에 잡는 HP ÷ atk"는 한 번만 이분법으로 구하고 재사용한다(키 = 직업 · 공속 보너스 · 목표 초).
local hpRatioCache = {}
function EconSim.maxHpPerAtk(loadout, seconds)
	local key = ("%s|%.9f|%.4f|%s"):format(loadout.classId, loadout.speedPercentBonus, seconds, tostring(SkillData.healer.E.attackMultiplier))
	local cached = hpRatioCache[key]
	if cached then
		return cached
	end
	assert(loadout.atk > 0 and loadout.atk < math.huge, "EconSim.maxHpPerAtk: atk가 유한한 양수가 아니다")
	local lo, hi = 0, 1
	local grow = 0
	while EconSim.killSeconds(loadout, hi * loadout.atk, seconds) <= seconds and grow < 60 do
		lo, hi = hi, hi * 4
		grow += 1
	end
	for _ = 1, 40 do
		local mid = (lo + hi) / 2
		if EconSim.killSeconds(loadout, mid * loadout.atk, seconds) <= seconds then
			lo = mid
		else
			hi = mid
		end
	end
	hpRatioCache[key] = lo
	return lo
end

function EconSim.clearCaches()
	hpRatioCache = {}
end

local function tierData(tierIndex)
	return MonsterData[MonsterData.tierOrder[tierIndex]]
end
EconSim.tierData = tierData

-- 이 loadout으로 tier 몬스터를 seconds 안에 잡을 수 있는 가장 높은 스테이지(1 ~ maxStage, 보스 스테이지 제외). efficiency = 조작 효율.
function EconSim.highestStageByKill(loadout, tierIndex, seconds, efficiency, maxStage)
	local hpLimit = EconSim.maxHpPerAtk(loadout, seconds) * loadout.atk * efficiency
	local baseHp = tierData(tierIndex).hp
	local stage = 1
	if hpLimit > baseHp then
		stage = math.floor(1 + math.log(hpLimit / baseHp) / math.log(InfiniteStageConfig.growthRate))
	end
	stage = math.clamp(stage, 1, maxStage)
	while stage < maxStage and InfiniteStage.getMonsterHp(baseHp, stage + 1) <= hpLimit do
		stage += 1
	end
	while stage > 1 and InfiniteStage.getMonsterHp(baseHp, stage) > hpLimit do
		stage -= 1
	end
	return stage
end

-- 생존 타수가 minHits 이상인 가장 높은 스테이지(1 ~ maxStage). 생존은 스테이지에 단조 감소라 이분법.
function EconSim.highestStageBySurvive(loadout, tierIndex, minHits, maxStage)
	local attackBase = tierData(tierIndex).attack
	local function ok(stage)
		return BalanceSim.getSurviveHits(loadout, InfiniteStage.getMonsterAttack(attackBase, stage), PlayerCombat.getNewbieDamageMultiplier(stage)) >= minHits -- P2.5c 신규 보호
	end
	if not ok(1) then
		return 1
	end
	if ok(maxStage) then
		return maxStage
	end
	local lo, hi = 1, maxStage
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if ok(mid) then
			lo = mid
		else
			hi = mid
		end
	end
	return lo
end

-- ═══ 60초 로테이션 총딜(치명 옵션 포함) ═══
-- BalanceSim.buildLoadout은 치명 옵션을 안 넣는다(gemBonusesFor가 공격력% · 공속% · 방어% · 체력%만). 실제 게임은 치명 옵션을 **평타에만** 더한다
-- (AttackServer가 PlayerProfile.getCritBonus를 critRateBonus · critDmgBonus로 넘긴다 - SkillServer 스킬 경로는 옵션 치명을 안 읽는다). 그래서:
--   평타 피해 = 직업 치명을 옵션만큼 올린 사본으로 돌린 simulateCombat의 autoDamage, 스킬 피해 = 원본으로 돌린 simulateCombat의 skillDamageTotal.
-- 사본에서 활 속사 배율(castSelfBuff는 ClassData.critRate만 읽는다 - 게임에서 옵션 치명은 속사 배율을 안 올린다)이 달라지지 않게
-- SkillData.bow.Q.attackSpeedBase를 같은 몫만큼 낮춰 둔다(속사 배율 = min(상한, base + 치확 × 계수)가 원본과 같다).
function EconSim.rotationDamage(spec, gems, durationSeconds)
	assert(EconSim.isAllowed(), "EconSim: Studio · DevToolsConfig.econSim 전용")
	local loadoutSpec = table.clone(spec)
	loadoutSpec.gems = gems
	local base = BalanceSim.simulateCombat(BalanceSim.buildLoadout(loadoutSpec), { useSkills = true, durationSeconds = durationSeconds or 60 })
	local sources = {}
	for _, gem in ipairs(gems or {}) do
		if type(gem) == "table" then
			table.insert(sources, gem)
		end
	end
	local critRate, critDmg = Option.critBonus(sources, spec.classId)
	if critRate == 0 and critDmg == 0 then
		return base.totalDamage, base
	end
	local classes = ClassData.classes
	local original = classes[spec.classId]
	local patched = table.clone(original)
	patched.critRate += critRate
	patched.critDmg += critDmg
	local bowQ = SkillData[spec.classId] and SkillData[spec.classId].Q
	local restoreSpeedBase = nil
	if bowQ and bowQ.shape == "selfBuff" then
		restoreSpeedBase = bowQ.attackSpeedBase
	end
	classes[spec.classId] = patched
	if restoreSpeedBase then
		bowQ.attackSpeedBase = restoreSpeedBase - critRate * bowQ.attackSpeedCritCoefficient
	end
	local ok, withCrit = pcall(function()
		return BalanceSim.simulateCombat(BalanceSim.buildLoadout(loadoutSpec), { useSkills = true, durationSeconds = durationSeconds or 60 })
	end)
	classes[spec.classId] = original
	if restoreSpeedBase then
		bowQ.attackSpeedBase = restoreSpeedBase
	end
	if not ok then
		error(withCrit, 0)
	end
	return withCrit.autoDamage + base.skillDamageTotal, base
end

-- ═══ 강화 몬테카를로(E4 · 진행 시뮬) ═══

-- level → level+1 기대 시도 수 · 골드 · 재료(천장 · 하락 · 초기화 포함, 방지권 없음). 게이지는 0에서 시작. Enhance.tryEnhance를 그대로 굴린다.
function EconSim.enhanceExpectedTable(trials, seed)
	local rng = Random.new(seed or EconSimConfig.seed)
	local rows = {}
	for startLevel = 0, EnhanceConfig.maxLevel - 1 do
		local attempts, gold, mats = 0, 0, {}
		for _ = 1, trials do
			local level, gauge = startLevel, 0
			local guard = 0
			while level <= startLevel and guard < 100000 do
				guard += 1
				attempts += 1
				gold += Enhance.getCost(level)
				local cost = EnhanceMaterialData.costByLevel[level]
				if cost then
					mats[cost.id] = (mats[cost.id] or 0) + cost.count
				end
				local result = Enhance.tryEnhance(level, gauge, nil, rng:NextNumber())
				level, gauge = result.level, result.gauge
			end
		end
		local row = { level = startLevel, attempts = attempts / trials, gold = gold / trials, materials = {} }
		for id, count in pairs(mats) do
			row.materials[id] = count / trials
		end
		rows[startLevel] = row
	end
	return rows
end

-- ═══ 진행 시뮬(E3 · E4) ═══

local function gradeIndex(gradeId)
	return table.find(ArmorData.gradeOrder, gradeId)
end

-- 가방 점검 한 번 사이에 주운 장비(기대 개수 drops개) 중 "기대 개수 1개 이상"인 (등급, itemLevel 편차) 조합들. 등급 ≥ g이고 편차 ≥ d인 장비의
-- 기대 개수 = drops × P(등급 ≥ g) × P(편차 ≥ d) ≥ 1인 가장 큰 d를 등급마다 하나씩. 두 표 = MonsterData.dropGradeTableByTier · ArmorData.itemLevelDelta
-- (Loot.rollArmorDrop이 굴리는 표 그대로). 등급과 편차는 독립으로 굴린다(Loot) - 그래서 곱이다.
-- P2 E: 등급 분포 = DropTable.gradeRow(tier, 태초 확률 = DropTable.effectiveRate - 서버 굴림과 같은 함수). 태초는 편차가 없다(itemLevel = 사냥 스테이지, E4).
local function expectedCandidates(tierIndex, drops, minGradeIndex, primordialRate)
	local row = DropTable.gradeRow(tierIndex, primordialRate)
	local deltas = table.clone(ArmorData.itemLevelDelta)
	table.sort(deltas, function(a, b)
		return a.delta > b.delta
	end)
	local totalWeight = 0
	for _, entry in ipairs(deltas) do
		totalWeight += entry.weight
	end
	local list = {}
	local gradeCumulative = 0
	for index = #ArmorData.gradeOrder, minGradeIndex or 1, -1 do
		local gradeId = ArmorData.gradeOrder[index]
		gradeCumulative += (row[gradeId] or 0)
		local deltaCumulative = 0
		if gradeId == "primordial" then
			if gradeCumulative > 0 and drops * gradeCumulative >= 1 then
				table.insert(list, { grade = gradeId, delta = 0 })
			end
		else
			for _, entry in ipairs(deltas) do
				deltaCumulative += entry.weight / totalWeight
				if gradeCumulative > 0 and drops * gradeCumulative * deltaCumulative >= 1 then
					table.insert(list, { grade = gradeId, delta = entry.delta })
					break
				end
			end
		end
	end
	return list
end

-- 이 사냥 자리(tier · 스테이지)의 태초 확률 - 최고 스테이지 = state.reach(설 수 있는 가장 높은 스테이지 = 게임의 infiniteBest).
local function primordialRateAt(state, tierIndex, stage)
	return DropTable.effectiveRate({ bestStage = state.reach }, { tierIndex = tierIndex }, stage)
end
EconSim.primordialRateAt = primordialRateAt

local PART_SCORE = {
	armor = Loot.getArmorDefense,
	gloves = Loot.getGlovesAttackPercent,
	shoes = Loot.getShoesSpeedPercent,
}

local function newState(profile)
	return {
		classId = profile.classId,
		level = 1,
		exp = 0,
		rebirth = 0,
		weaponLevel = 0,
		gauge = 0,
		weaponGrade = 0,
		gold = 0,
		materials = {},
		tickets = { drop = 0, reset = 0 },
		gear = {},
		gems = {},
		reach = BossData.stageInterval, -- 지금 설 수 있는 가장 높은 스테이지(= 아직 못 깬 첫 보스 스테이지)
		seconds = 0,
		huntSeconds = 0,
		bossSeconds = 0,
		enhanceAttempts = 0,
		rerollTickets = 0,
		gearReplacements = 0,
		gemReplacements = 0,
		bossClears = 0,
		pendingKills = 0,
		sinceCheck = 0,
		bossGold = 0,
		bossExp = 0,
		gearMode = false,
		poolKey = 0,
		milestoneLevel = 0, -- P2.5c B2: 받은 마지막 능력치 마일스톤 레벨 - 게임의 classState.milestoneLevel과 같은 값
	}
end

local function loadoutFor(state)
	return BalanceSim.buildLoadout({
		classId = state.classId,
		level = state.level,
		weaponLevel = state.weaponLevel,
		weaponGrade = state.weaponGrade,
		gear = state.gear,
		gems = state.gems,
		permanentMultiplier = Milestone.attackMultiplier(state.milestoneLevel), -- P2.5c B2: 마일스톤 버킷(붙는 곳 = MilestoneData.stat)
		permanentHpMultiplier = Milestone.maxHpMultiplier(state.milestoneLevel),
	})
end
EconSim.loadoutFor = loadoutFor

-- P2 G: 게임의 파티 경험치 보너스는 "같은 구역 · 반경 · 최근 활동" 파티원만 센다(PartyExpBonus) - 시뮬 사냥은 솔로라([가정] partyHuntsTogether = false)
-- EconSimConfig.partyExpRequiresPresence가 켜져 있으면 사냥 보너스가 없다. p2before(옛 규칙 - 파티 소속만 되면 거리 무관)는 이 스위치를 끈다.
local function expMultiplier(profile)
	local eligible = profile.partyExpBonus and (profile.partyHuntsTogether or not EconSimConfig.partyExpRequiresPresence)
	local partyBonus = eligible and PartyState.getExpBonusForCount(profile.partySize) or 0
	return PlayerProfile.combineExpMultiplier(0, partyBonus)
end

-- 무작위 축 보석의 기대값 - DPS 3축(위력 · 신속 · 치명 - OptionData category "dps", 20.67 [5] "카테고리 안에서 등가")이 풀에서 나올 확률만큼
-- 위력으로 환산한 roll(Option.valueOf가 roll에 선형이라 기대값이 정확히 이 roll의 값이다).
local function randomAxisRoll(classId)
	local pool = Option.poolFor(classId)
	local dps = 0
	for _, id in ipairs(pool) do
		if OptionData.options[id].category == "dps" then
			dps += 1
		end
	end
	return dps / #pool
end

-- 슬롯에 보석 후보를 놓아 본다. 변환권을 쓸 수 있는 등급(고대 · 태초 - Gem.isRerollableGrade)이고 프로필이 다시 굴리면 원하는 축(위력) · gemRoll로
-- 만들고 그 값이 지금 보석보다 좋을 때만 변환권 값(풀 크기 N회 기대 - 원하는 축 1개 / N)을 낸다. 아니면 무작위 축 기대값.
local function tryPlaceGem(state, profile, slot, gradeId, itemLevel, whatIf, forced)
	local old = state.gems[slot]
	local oldValue = type(old) == "table" and EconSim.gemValue(old, state.classId) or -1
	if profile.gemReroll and Gem.isRerollableGrade(gradeId) then
		local gem = EconSim.makeGem("attackPercent", gradeId, itemLevel, profile.gemRoll)
		local tickets = #Option.poolFor(state.classId)
		local price = GoldCost.cost(MonsterData.tier1.goldDrop, state.reach, "rerollTicket") * GemData.rerollTicketGoldMultiplier * tickets -- GemServer.rerollTicketPrice와 같은 식
		if (forced or EconSim.gemValue(gem, state.classId) > oldValue) and state.gold >= price then
			state.gold -= price
			state.rerollTickets += tickets
			state.gems[slot] = gem
			state.gemReplacements += forced and 0 or 1
			return
		end
	end
	local gem = EconSim.makeGem("attackPercent", gradeId, itemLevel, randomAxisRoll(state.classId))
	if forced or EconSim.gemValue(gem, state.classId) > oldValue then
		state.gems[slot] = gem
		state.gemReplacements += forced and 0 or 1
	end
end

local function doRebirth(state, profile, whatIf)
	local levelAtRebirth = state.level
	state.rebirth += 1
	state.level = 1
	state.exp = 0
	state.weaponGrade = state.rebirth
	local slot = state.rebirth
	-- 환생 지급 보석(PlayerProfile.rebirth): 그 슬롯 상한 등급 · itemLevel = 환생 순간 레벨의 스테이지 척도(P2.5a 결정 9 - CharacterLevel.getStageForLevel) · 옵션 무작위.
	tryPlaceGem(state, profile, slot, Gem.gradeCapForSlot(slot), CharacterLevel.getStageForLevel(levelAtRebirth), whatIf, true)
	if state.rebirth == GemData.maxRebirthCount and Gem.allSlotsFilled(state.gems) then
		state.weaponGrade = #ArmorData.gradeOrder - 1
	end
end

-- 가방 점검: 지난 점검 뒤 주운 장비(kills마리분의 기대 개수)로 부위마다 점수가 더 좋은 것이 있으면 바꾼다(점수 = Loot.getArmorDefense 등 게임 함수).
-- 보석: 영웅 이상 장비를 분해하면 그 등급 · itemLevel의 보석(PlayerProfile.dismantleItem). 슬롯 상한 등급까지만 박힌다(Gem.canSocket).
local function checkBag(state, profile, tierIndex, stage, kills, whatIf)
	local total = kills * Loot.expectedArmorDropCount(tierIndex, 1)
	local perPart = total / #EquipSlots.order
	local replaced = 0
	for _, part in ipairs(EquipSlots.order) do
		local score = PART_SCORE[part]
		local best, bestScore = nil, state.gear[part] and score(state.gear[part]) or -1
		for _, candidate in ipairs(expectedCandidates(tierIndex, perPart, nil, primordialRateAt(state, tierIndex, stage))) do
			local item = { grade = candidate.grade, itemLevel = math.max(1, stage + candidate.delta) }
			local value = score(item)
			if value > bestScore then
				best, bestScore = item, value
			end
		end
		if best then
			state.gear[part] = best
			replaced += 1
		end
	end
	state.gearReplacements += replaced
	local gemsBefore = state.gemReplacements
	local minGem = gradeIndex("epic")
	for slot = 1, state.rebirth do
		local capIndex = gradeIndex(Gem.gradeCapForSlot(slot))
		local bestGem, bestValue = nil, -1
		for _, candidate in ipairs(expectedCandidates(tierIndex, total, minGem, primordialRateAt(state, tierIndex, stage))) do
			if gradeIndex(candidate.grade) <= capIndex then
				local level = math.max(1, stage + candidate.delta)
				local value = EconSim.gemValue(EconSim.makeGem("attackPercent", candidate.grade, level, 1), state.classId)
				if value > bestValue then
					bestGem, bestValue = { grade = candidate.grade, itemLevel = level }, value
				end
			end
		end
		if bestGem then
			tryPlaceGem(state, profile, slot, bestGem.grade, bestGem.itemLevel, whatIf, false)
		end
	end
	return replaced, replaced > 0 or state.gemReplacements > gemsBefore
end

local function tryEnhanceWithGold(state, profile, rng)
	local guard = 0
	while state.weaponLevel < math.min(profile.enhanceTarget, EnhanceConfig.maxLevel) and guard < 5000 do
		guard += 1
		local level = state.weaponLevel
		local cost = Enhance.getCost(level, state.reach) -- P2 C1: 계정 최고 스테이지(= 설 수 있는 가장 높은 스테이지) 기준 GoldCost
		local mat = EnhanceMaterialData.costByLevel[level]
		if state.gold < cost or (mat and (state.materials[mat.id] or 0) < mat.count) then
			return
		end
		local gaugeFull = state.gauge >= EnhanceConfig.gauge.max
		if profile.useProtection and not gaugeFull then
			for _, kind in ipairs({ "drop", "reset" }) do
				if level >= EnhanceConfig.protection[kind].usableFromLevel and state.tickets[kind] < 1 then
					local price = Enhance.getProtectionPrice(kind, state.reach)
					if state.gold >= cost + price then
						state.gold -= price
						state.tickets[kind] += 1
					end
				end
			end
		end
		local useDrop, useReset = Enhance.resolveProtectionFlags(level, gaugeFull, profile.useProtection, profile.useProtection, state.tickets.drop, state.tickets.reset)
		state.gold -= cost
		if mat then
			state.materials[mat.id] -= mat.count
		end
		state.enhanceAttempts += 1
		local result = Enhance.tryEnhance(level, state.gauge, { useDrop, useReset }, rng:NextNumber())
		if result.blockedBy then
			state.tickets[result.blockedBy] -= 1
		end
		state.weaponLevel, state.gauge = result.level, result.gauge
	end
end

local function nextMilestoneRecord(run, state, cap)
	for _, milestone in ipairs(run.milestones) do
		if not run.reached[milestone] and state.reach >= milestone and milestone <= cap then
			run.reached[milestone] = { seconds = state.seconds, level = state.level, rebirth = state.rebirth, weaponLevel = state.weaponLevel, weaponGrade = state.weaponGrade }
		end
	end
end

-- 보스를 깰 수 있는 동안 계속 깬다(한 레벨에 여러 번 가능). 반환: 이번에 깬 수.
local function fightBosses(state, profile, loadout, run)
	local cleared = 0
	while state.reach < run.cap do
		local bossStage = state.reach
		local data = BossRules.buildInstanceData(bossStage, BossRules.bossIdForStage(bossStage), profile.partySize)
		-- 파티 딜 = 인원 × 내 딜(같은 수준의 파티원 가정 - [가정]). 보스 HP는 BossRules가 이미 인원 배율(N^p)을 곱했다.
		local effectiveHp = data.hp / (profile.bossDpsEfficiency * profile.partySize)
		-- 생존: 보스 평타(BossRules가 계산한 attack)에 최소 생존 타수를 버텨야 도전한다(잡몹과 같은 minSurviveHits).
		if BalanceSim.getSurviveHits(loadout, data.attack, PlayerCombat.getNewbieDamageMultiplier(bossStage)) < profile.minSurviveHits then -- P2.5c 신규 보호
			break
		end
		local seconds = EconSim.killSeconds(loadout, effectiveHp, profile.bossKillLimitSeconds)
		if seconds > profile.bossKillLimitSeconds then
			break
		end
		local spent = seconds * profile.bossAttemptsPerClear + profile.bossOverheadSeconds
		state.seconds += spent
		state.bossSeconds += spent
		state.gold += data.goldDrop
		state.bossGold += data.goldDrop
		local rebirthMult = CharacterLevel.getRebirthExpMultiplier(state.rebirth) -- P2.5c: 환생 경험치 배율(캐릭터 경험치에만 - 게임 PlayerProfile.addCharacterExp와 같다)
		state.exp += data.expReward * run.expMult * rebirthMult
		state.bossExp += data.expReward * run.expMult * rebirthMult
		local drop, reset = Enhance.getBossGrant(bossStage)
		state.tickets.drop += drop
		state.tickets.reset += reset
		state.bossClears += 1
		cleared += 1
		state.reach = bossStage + BossData.stageInterval
		if state.reach > run.cap then
			state.reach = run.cap
		end
		nextMilestoneRecord(run, state, run.cap)
	end
	return cleared
end

-- 이 loadout의 사냥 선택: 구역 tier 1 ~ huntTierMax마다 "목표 초 안에 잡히고 · 생존 타수 하한을 넘는" 가장 높은 스테이지를 찾고, 경험치/초가 가장 좋은
-- 구역을 고른다(최고의 95% 안이면 더 높은 tier - 같은 시간에 드랍 등급이 좋다). gearMode면 대신 가장 높은 스테이지(같으면 높은 tier)를 고른다 -
-- 방어구 itemLevel은 "잡은 스테이지 + 편차(최대 +2)"로만 오르므로, 높은 tier에서 생존 때문에 방어구 레벨보다 낮은 스테이지에 묶이면 방어구가 영영
-- 안 오른다(점검에서 방어구가 안 바뀌면 stepLevel이 gearMode를 켠다 - [가정] "장비가 막히면 더 높은 스테이지를 도는" 플레이어).
-- 반환: { tier, stage, killSeconds, expPerSecond, limiter }.
local function chooseHunt(loadout, profile, maxStage, gearMode)
	local options = {}
	local bestRate = 0
	for tierIndex = 1, profile.huntTierMax do
		local byKill = EconSim.highestStageByKill(loadout, tierIndex, profile.targetKillSeconds, profile.dpsEfficiency, maxStage)
		local bySurvive = EconSim.highestStageBySurvive(loadout, tierIndex, profile.minSurviveHits, maxStage)
		local stage = math.min(byKill, bySurvive)
		if BossRules.isBossStage(stage) and stage > 1 then
			stage -= 1
		end
		local tier = tierData(tierIndex)
		local kill = EconSim.killSeconds(loadout, InfiniteStage.getMonsterHp(tier.hp, stage) / profile.dpsEfficiency, 600)
		local rate = InfiniteStage.getExpReward(tier.expReward, stage) / (kill + profile.moveOverheadSeconds)
		local limiter = (bySurvive < byKill) and "생존 타수" or ((byKill >= maxStage) and "보스 게이트" or "처치 시간")
		table.insert(options, { tier = tierIndex, stage = stage, killSeconds = kill, expPerSecond = rate, limiter = limiter })
		if rate > bestRate then
			bestRate = rate
		end
	end
	local chosen = options[1]
	if gearMode then
		-- 장비 올리기: 한 시간 사냥(가방 누적) 뒤 기대 방어구 점수가 가장 높은 구역. 한 시간으로 지금보다 나은 곳이 없으면 시야를 4배씩(최대 64시간) 넓힌다.
		local armor = gearMode.armor
		local current = armor and Loot.getArmorDefense(armor) or -1
		local horizon = 3600
		while horizon <= 64 * 3600 do
			local bestScore = current
			for _, option in ipairs(options) do
				local kills = horizon / (option.killSeconds + profile.moveOverheadSeconds)
				local perPart = kills * Loot.expectedArmorDropCount(option.tier, 1) / #EquipSlots.order
				for _, candidate in ipairs(expectedCandidates(option.tier, perPart)) do
					local value = Loot.getArmorDefense({ grade = candidate.grade, itemLevel = math.max(1, option.stage + candidate.delta) })
					if value > bestScore then
						bestScore, chosen = value, option
					end
				end
			end
			if bestScore > current then
				return chosen
			end
			horizon *= 4
		end
		return options[1]
	end
	for _, option in ipairs(options) do
		if option.expPerSecond >= bestRate * 0.95 then
			chosen = option -- 뒤(높은 tier)일수록 덮어쓴다
		end
	end
	return chosen
end

-- 레벨업 1회분(청크). 레벨 하나를 "가방 점검 간격" 단위로 쪼개 돈다 - 점검마다 장비가 바뀌면 사냥 선택 · 보스 도전을 다시 한다.
-- 반환: 청크 기록 표, 또는 진행 정지 사유 문자열.
local function stepLevel(state, profile, run, rng, whatIf)
	local bossSecondsBefore, bossGoldBefore = state.bossSeconds, state.bossGold
	local bossExpBefore = state.bossExp
	local loadout, hunt, tier, expPerKill, perKillSeconds, goldPerKill, killUnits, primordialPerKill
	local need = nil
	local function refresh()
		loadout = loadoutFor(state)
		local expBeforeBoss = state.exp
		fightBosses(state, profile, loadout, run)
		-- 레벨 도중(장비가 바뀐 뒤) 깬 보스의 경험치는 이번 레벨의 남은 필요량에서 뺀다(리뷰 지적 1 - 전엔 끝에서 state.exp = -need가 덮어써 사라졌다).
		if need then
			need -= state.exp - expBeforeBoss
			state.exp = expBeforeBoss
		end
		hunt = chooseHunt(loadout, profile, math.max(1, state.reach - 1), state.gearMode and { armor = state.gear.armor }) -- 보스 스테이지(state.reach)는 아레나라 잡몹이 없다
		tier = tierData(hunt.tier)
		expPerKill = InfiniteStage.getExpReward(tier.expReward, hunt.stage) * run.expMult * CharacterLevel.getRebirthExpMultiplier(state.rebirth) -- P2.5c: 환생 경험치 배율(재료에는 안 곱한다)
		perKillSeconds = hunt.killSeconds + profile.moveOverheadSeconds
		goldPerKill = InfiniteStage.getGoldReward(tier.goldDrop, hunt.stage)
		-- 재료 마릿수분 = tier 보상 배율^p(MonsterState.getKillUnits와 같은 값 - 접두사 평균 1)
		killUnits = tier.rewardRatio ^ MonsterData.fairnessExponent
		-- P2 E5: 처치 1마리당 태초 장비 기대 개수(서버 굴림과 같은 effectiveRate - 레벨 감쇠 포함)
		primordialPerKill = Loot.expectedArmorDropCount(hunt.tier, 1) * primordialRateAt(state, hunt.tier, hunt.stage)
	end
	refresh()
	if hunt.killSeconds == math.huge then
		return ("레벨 %d(환생 %d)에서 스테이지 %d의 tier%d 몬스터를 600초 안에 못 잡는다"):format(state.level, state.rebirth, hunt.stage, hunt.tier)
	end
	need = CharacterLevel.getExpToNextLevel(state.level) - state.exp
	local checkSeconds = profile.gearCheckMinutes * 60
	local seconds, kills, gold, exp, replaced, primordial = 0, 0, 0, 0, 0, 0
	local firstStage = hunt.stage
	while need > 0 do
		local killsToLevel = math.max(1, math.ceil(need / expPerKill - 1e-9))
		local killsToCheck = math.max(1, math.ceil((checkSeconds - state.sinceCheck) / perKillSeconds - 1e-9))
		local batch = math.min(killsToLevel, killsToCheck)
		local batchSeconds = batch * perKillSeconds
		if seconds + batchSeconds > EconSimConfig.stallLevelHours * 3600 and batch == killsToLevel then
			return ("레벨 %d → %d 한 번에 %.3g시간 - 사냥 스테이지 %d(tier%d · 처치 %.2f초 · %.3g마리)가 레벨보다 %d칸 낮다. 사냥 스테이지를 막는 것: %s(방어구 %s · itemLevel %s)"):format(
				state.level, state.level + 1, (seconds + batchSeconds) / 3600, hunt.stage, hunt.tier, hunt.killSeconds, kills + batch, state.level - hunt.stage, hunt.limiter,
				state.gear.armor and state.gear.armor.grade or "없음", state.gear.armor and tostring(state.gear.armor.itemLevel) or "-")
		end
		if seconds > EconSimConfig.stallLevelHours * 3600 then
			return ("레벨 %d → %d가 %d시간을 넘었다(사냥 스테이지 %d · tier%d · 막는 것: %s)"):format(state.level, state.level + 1, EconSimConfig.stallLevelHours, hunt.stage, hunt.tier, hunt.limiter)
		end
		seconds += batchSeconds
		kills += batch
		gold += batch * goldPerKill
		exp += batch * expPerKill
		primordial += batch * primordialPerKill
		need -= batch * expPerKill
		state.gold += batch * goldPerKill
		state.seconds += batchSeconds
		state.huntSeconds += batchSeconds
		for id, def in pairs(EnhanceMaterialData.materials) do
			if hunt.stage >= def.minStage then
				state.materials[id] = (state.materials[id] or 0) + batch * Loot.expectedMaterialCount(id, killUnits, run.expMult)
			end
		end
		-- 가방 점검(gearCheckMinutes마다). 가방은 같은 사냥 자리(tier · 스테이지)에 있는 동안 계속 쌓인다 - 자리가 바뀌면 새 자리의 드랍이 옛 것을
		-- 앞서므로 그때 센다(옛 가방의 나머지는 이미 끼운 것보다 나쁘다).
		local poolKey = hunt.tier * 100000 + hunt.stage
		if state.poolKey ~= poolKey then
			state.poolKey, state.pendingKills = poolKey, 0
		end
		state.pendingKills += batch
		state.sinceCheck += batchSeconds
		if state.sinceCheck >= checkSeconds - 1e-9 then
			local armorBefore, modeBefore, weaponBefore = state.gear.armor, state.gearMode, state.weaponLevel
			local changed, anyChange = checkBag(state, profile, hunt.tier, hunt.stage, state.pendingKills, whatIf)
			state.sinceCheck = 0
			-- 방어구가 그대로인데 생존이 사냥 스테이지를 막고 있으면 장비 올리기 모드, 방어구가 바뀌면 경험치 모드로 돌아간다.
			if state.gear.armor ~= armorBefore then
				state.gearMode = false
			elseif hunt.limiter == "생존 타수" then
				state.gearMode = true
			end
			replaced += changed
			tryEnhanceWithGold(state, profile, rng)
			-- 아무것도 안 바뀐 점검이면 사냥 선택 · 보스 판정이 그대로라 다시 계산하지 않는다(긴 레벨에서 점검 수백 번 - 계산 시간).
			if anyChange or state.gearMode ~= modeBefore or state.weaponLevel ~= weaponBefore then
				refresh()
			end
		end
	end
	state.exp = -need -- 넘친 경험치는 다음 레벨로
	tryEnhanceWithGold(state, profile, rng)
	local levelBefore = state.level
	state.level += 1
	-- P2.5b D · P2.5c B2: 게임과 같은 규칙(Milestone.plan)으로 능력치 마일스톤을 받는다(환생 5회 뒤 사다리 - 해금은 전투에 무관해 안 센다).
	local plan = Milestone.plan(state.rebirth, state.level, state.milestoneLevel, 0)
	if plan and plan.statGained > 0 then
		state.milestoneLevel = plan.claimedLevel
	end
	local requiredLevel = CharacterLevel.getRebirthRequiredLevel(state.rebirth)
	if profile.rebirth and state.rebirth < GemData.maxRebirthCount and requiredLevel and state.level >= requiredLevel then
		doRebirth(state, profile, whatIf)
		run.rebirthAt[state.rebirth] = state.seconds -- P2 B1: 환생 k회차를 마친 누적 플레이 초(레벨 1 상태)
	end
	local gemLevels, gemCount, gemBonus = 0, 0, 0
	for slot = 1, Gem.slotCount do
		local gem = state.gems[slot]
		if type(gem) == "table" then
			gemCount += 1
			gemLevels += gem.itemLevel
			gemBonus += EconSim.gemValue(gem, state.classId)
		end
	end
	return {
		bossSeconds = state.bossSeconds - bossSecondsBefore, bossGold = state.bossGold - bossGoldBefore, bossExp = state.bossExp - bossExpBefore,
		reach = state.reach, stage = hunt.stage, firstStage = firstStage, tier = hunt.tier, limiter = hunt.limiter, level = levelBefore, rebirth = state.rebirth,
		seconds = seconds, kills = kills, killSeconds = hunt.killSeconds,
		gold = gold, exp = exp, gearReplaced = replaced, weaponLevel = state.weaponLevel,
		primordial = primordial, -- P2 E5: 이 청크 사냥의 태초 장비 기대 개수
		goldBalance = state.gold, goldPerKill = goldPerKill, -- P2 C2: 보유 골드 대비 처치 1회 골드(상대 정밀도)
		gemShare = 1 - BalanceSim.buildLoadout({ classId = state.classId, level = state.level, weaponLevel = state.weaponLevel, weaponGrade = state.weaponGrade, gear = state.gear, gems = {}, permanentMultiplier = Milestone.attackMultiplier(state.milestoneLevel), permanentHpMultiplier = Milestone.maxHpMultiplier(state.milestoneLevel) }).atk / loadoutFor(state).atk, -- P2 D1: 보석이 공격력에서 차지하는 비중
		milestoneLevel = state.milestoneLevel, -- P2.5c B2: 청크 끝의 받은 마지막 능력치 마일스톤 레벨(버킷 = Milestone.bonusFor)
		armorGrade = state.gear.armor and state.gear.armor.grade or "-", armorLevel = state.gear.armor and state.gear.armor.itemLevel or 0,
		-- P2.5a E(스테이지 환산 표): 청크 끝의 출처별 값 - 무기 등급(환생) · 장갑 공격력% · 방어구(방어 · 최대체력은 itemLevel · 등급)
		weaponGrade = state.weaponGrade, levelAfter = state.level,
		glovesAttack = Loot.getGlovesAttackPercent(state.gear.gloves), armorDefense = Loot.getArmorDefense(state.gear.armor),
		gemCount = gemCount, gemAvgLevel = gemCount > 0 and gemLevels / gemCount or 0, gemAttackBonus = gemBonus,
	}
end

-- 프로필 하나의 진행 시뮬. 반환: { profileId, reached = { [이정표] = 기록 }, chunks = { 청크 }, stall = 사유 or nil, final = state }.
function EconSim.runProgress(profileId, whatIf)
	assert(EconSim.isAllowed(), "EconSim: Studio · DevToolsConfig.econSim 전용")
	local profile = EconSimConfig.profiles[profileId]
	assert(profile, "알 수 없는 프로필: " .. tostring(profileId))
	local cap = InfiniteStageConfig.safeStageCap
	local milestones = table.clone(EconSimConfig.milestones)
	table.insert(milestones, InfiniteStageConfig.designMaxStage) -- P2.5a R2: 설계 최대 스테이지(안전 상한은 진행 끝 조건으로만 쓴다)
	local run = { profileId = profileId, milestones = milestones, reached = {}, rebirthAt = {}, chunks = {}, cap = cap, stall = nil }
	run.expMult = EconSim.withOverrides(whatIf, expMultiplier, profile) -- what-if(p2before의 옛 파티 규칙)를 따른다
	local state = newState(profile)
	local rng = Random.new(EconSimConfig.seed)
	nextMilestoneRecord(run, state, cap)
	local lastYield = os.clock()
	while state.reach < cap do
		local chunk = EconSim.withOverrides(whatIf, stepLevel, state, profile, run, rng, whatIf)
		if type(chunk) == "string" then
			run.stall = chunk
			break
		end
		table.insert(run.chunks, chunk)
		nextMilestoneRecord(run, state, cap)
		if state.seconds > EconSimConfig.maxPlayHours * 3600 then
			run.stall = ("누적 플레이 %d시간 상한(EconSimConfig.maxPlayHours)에서 멈춤 - 최고 스테이지 %d · 레벨 %d"):format(EconSimConfig.maxPlayHours, state.reach, state.level)
			break
		end
		if os.clock() - lastYield >= EconSimConfig.yieldSeconds then
			task.wait()
			lastYield = os.clock()
		end
	end
	run.final = state
	return run
end

return EconSim
