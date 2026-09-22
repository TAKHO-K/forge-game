-- 경제 시뮬의 표 계산(P0 E4 강화표 · E5 태초 선택지 · E6 치유사 · 표본 대조). 진행 시뮬(E3)은 EconSim.runProgress.
-- 전부 게임 모듈을 그대로 불러 계산한다 - 여기서 새로 정한 것은 "무엇을 비교하는가"(모형)뿐이고, 그 모형은 각 함수 주석 + P0-log에 [가정]으로 적었다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconSimConfig = require(ReplicatedStorage.Shared.data.EconSimConfig)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PartyShieldSim = require(ReplicatedStorage.Shared.PartyShieldSim)
local EconSim = require(script.Parent.EconSim)

local EconSimTables = {}

-- ═══ E5 태초 선택지 손익분기 ═══
-- 모형([가정]): 레벨 Lp 앵커 장비(BalanceSim.buildAnchorLoadout)의 플레이어가 "일반" 프로필의 사냥 기준(목표 처치 초 · 조작 효율 · 이동 시간)으로
--   (B) 저tier를 자기 사냥 스테이지 sB(목표 초 안에 잡히는 가장 높은 스테이지)에서, (A) 고tier를 sA = sB − Δ에서 잡는다.
--   태초 기대 가치/분 = 분당 처치 × 처치당 장비 기대 개수(Loot.expectedArmorDropCount) × 태초 확률 × 태초 위력 옵션 값(Option.valueOf, roll 1.0).
--   보석 레벨: 스위치 ①이 켜지면 잡은 스테이지(= 몬스터 레벨), 끄면 A도 sB(플레이어 사냥 스테이지). 동결 없음 = EconSim.levelFactorScale(선형 연장).
-- 결과 = A ÷ B. 1 초과면 "낮은 레벨 고tier만 도는 것"이 태초 기준 우세(지배 전략 후보), 1 이하면 아니다.
local function primordialChance(tierIndex, whatIf)
	local table_ = (whatIf and whatIf.primordialByTier) or EconSimConfig.primordial.primordialByTier
	if table_ then
		return table_[tierIndex] or 0
	end
	return MonsterData.dropGradeTableByTier[tierIndex].primordial or 0
end
EconSimTables.primordialChance = primordialChance

local function perMinute(loadout, tierIndex, stage, profile)
	local hp = InfiniteStage.getMonsterHp(EconSim.tierData(tierIndex).hp, stage)
	local kill = EconSim.killSeconds(loadout, hp / profile.dpsEfficiency, 600)
	local killsPerMinute = 60 / (kill + profile.moveOverheadSeconds)
	return {
		stage = stage,
		killSeconds = kill,
		killsPerMinute = killsPerMinute,
		dropsPerMinute = killsPerMinute * Loot.expectedArmorDropCount(tierIndex, 1),
		goldPerMinute = killsPerMinute * InfiniteStage.getGoldReward(EconSim.tierData(tierIndex).goldDrop, stage),
		expPerMinute = killsPerMinute * InfiniteStage.getExpReward(EconSim.tierData(tierIndex).expReward, stage),
	}
end

local function primValue(itemLevel, classId, cap)
	return EconSim.gemValue(EconSim.makeGem("attackPercent", "primordial", itemLevel, 1.0, { levelFactorCap = cap }), classId)
end

function EconSimTables.primordial(whatIf)
	local cfg = EconSimConfig.primordial
	local profile = EconSimConfig.profiles.normal
	local classId = profile.classId
	local switchOn = cfg.gemLevelIsMonsterLevel
	local custom = (whatIf and whatIf.primordialByTier) or cfg.primordialByTier
	local rows = {}
	local function evaluate(playerLevel, stageA, stageB, loadout, label)
		local a = perMinute(loadout, cfg.highTier, stageA, profile)
		local b = perMinute(loadout, cfg.lowTier, stageB, profile)
		local levelA = switchOn and stageA or stageB
		for _, freeze in ipairs({ true, false }) do
			local cap = (not freeze) and math.huge or nil
			local valueA, valueB = primValue(levelA, classId, cap), primValue(stageB, classId, cap)
			local pA = primordialChance(cfg.highTier, whatIf)
			local multipliers = custom and { "표" } or cfg.probabilityMultipliers
			for _, multiplier in ipairs(multipliers) do
				local pB = custom and primordialChance(cfg.lowTier, whatIf) or pA / multiplier
				local perMinA = a.dropsPerMinute * pA * valueA
				local perMinB = b.dropsPerMinute * pB * valueB
				-- 손익분기 배수 M* = B의 확률이 A의 1/M*일 때 A÷B = 1(A÷B는 배수에 비례한다). 배수 ≤ M*면 지배 전략이 아니다.
				local perMinBAtEqual = b.dropsPerMinute * pA * valueB
				table.insert(rows, {
					label = label, playerLevel = playerLevel, delta = stageB - stageA, stageA = stageA, stageB = stageB, freeze = freeze,
					multiplier = multiplier, pA = pA, pB = pB, valueA = valueA, valueB = valueB,
					killA = a.killSeconds, killB = b.killSeconds, perMinA = perMinA, perMinB = perMinB,
					ratio = perMinB > 0 and perMinA / perMinB or math.huge,
					breakEven = perMinA > 0 and perMinBAtEqual / perMinA or math.huge,
					goldRatio = a.goldPerMinute / b.goldPerMinute, expRatio = a.expPerMinute / b.expPerMinute,
				})
			end
		end
	end
	for _, playerLevel in ipairs(cfg.playerLevels) do
		local loadout = BalanceSim.buildAnchorLoadout(classId, playerLevel, 0)
		local stageB = EconSim.highestStageByKill(loadout, cfg.lowTier, profile.targetKillSeconds, profile.dpsEfficiency, InfiniteStageConfig.safeStageCap)
		local seen = {}
		for _, delta in ipairs(cfg.deltas) do
			local stageA = math.max(1, stageB - delta) -- Δ가 sB보다 크면 스테이지 1에서 잘린다 - 같은 sA는 한 번만
			if not seen[stageA] then
				seen[stageA] = true
				evaluate(playerLevel, stageA, stageB, loadout, "grid")
			end
		end
	end
	-- 사용자 설계 예시: 레벨 10 플레이어 - 레벨 1 드래곤 vs 레벨 14 슬라임.
	evaluate(10, 1, 14, BalanceSim.buildAnchorLoadout(classId, 10, 0), "example")
	return rows
end

-- ═══ E6 치유사 r과 장비 성장 ═══
-- 앵커 조건(S21-0 D2와 같다): 레벨 100 · 무기 등급 0 · +0강 · 장비 일반 등급 itemLevel 100. 60초 로테이션 총딜(EconSim.rotationDamage - 치명 옵션은 평타만).
-- 치유모드 치유사의 딜 = 딜 옵션을 안 받은 딜링모드 총딜 × 보스전 전투 비율(PartyShieldSim - S13b 시나리오의 "치유" 모드 = Q가 회복. S21-0 D2의 0.266이
-- 이 값이다. 쉴드 모드(파티 + 딜링모드면 Q가 쉴드) 비율도 같이 재서 보고서에 참고로 적는다).
-- r = 치유모드 치유사 딜 ÷ 검사 딜(같은 장비 단계), 비중 = r ÷ (딜러 3 + r)(4인 = 딜러 3 + 치유사 1, D2와 같은 식).
-- (가) a: 치유모드 딜 × (1 + a × (치유사가 같은 딜 옵션을 꼈을 때의 배율 − 1)). (나) m: 치유모드 전용 보석 - 같은 칸 수 · 등급 · itemLevel · roll의 보석이
--   "태초 기준값 m인 위력"을 준다(위력 옵션의 roll을 m ÷ 위력 기준값 0.30배로 - Option.valueOf가 roll에 선형이라 정확히 그 값이다).
local function anchorSpec(classId)
	local level = BalanceAnchorConfig.referenceLevel
	local grade = BalanceAnchorConfig.gearGrade
	return {
		classId = classId,
		level = level,
		weaponLevel = BalanceAnchorConfig.weaponLevel,
		weaponGrade = 0,
		gear = {
			armor = { grade = grade, itemLevel = level },
			gloves = { grade = grade, itemLevel = level },
			shoes = { grade = grade, itemLevel = level },
		},
	}
end

local function tierGems(tier, optionOverride, rollScale)
	local gems = {}
	for slot, entry in ipairs(tier.gems) do
		gems[slot] = EconSim.makeGem(optionOverride or entry[1], entry[2], entry[3], entry[4] * (rollScale or 1), nil)
	end
	return gems
end

local function share(r, dealers)
	return r / (dealers + r)
end
EconSimTables.healerShare = share

function EconSimTables.healer(whatIf)
	local cfg = EconSimConfig.healer
	local attackBase = OptionData.options.attackPercent.baseValue
	local result = { tiers = {}, dealers = {}, fightRatio = {}, applyRates = {}, gemCoefficients = {} }

	local healerBase = EconSim.rotationDamage(anchorSpec("healer"), {})
	local gsBase = EconSim.rotationDamage(anchorSpec("greatsword"), {})
	result.healerDealing = healerBase
	result.greatswordBase = gsBase

	-- 보스전 전투 비율(쉴드 · 치유 두 모드) + 필드 가동률(S13 simulateHealerCycle).
	local scenario = cfg.fightRatioScenario
	for _, shield in ipairs({ true, false }) do
		local run = PartyShieldSim.run({
			dealers = 3, healers = 1, healerRaw = healerBase / gsBase, bossHpUnits = 4 * scenario.bossHpUnitsSeconds,
			hitsPerSecond = scenario.hitsPerSecond, hitRatio = scenario.hitRatio, shield = shield, regenPerSecond = 0,
		})
		result.fightRatio[shield and "shield" or "heal"] = run.healerFightRatio
	end
	result.fieldUptime = BalanceSim.simulateHealerCycle({ hitsPerSecond = scenario.hitsPerSecond, hitRatio = scenario.hitRatio }).uptime
	local fight = result.fightRatio.heal

	local mGainMemo = {}
	local healModeFactor = function(tier, a, m)
		local own = result.tiers[tier.id].healerOwnGain
		local mGain = 1
		if m and m > 0 then
			local key = ("%s|%.6f"):format(tier.id, m)
			mGain = mGainMemo[key]
			if not mGain then
				mGain = EconSim.rotationDamage(anchorSpec("healer"), tierGems(tier, "attackPercent", m / attackBase)) / healerBase
				mGainMemo[key] = mGain
			end
		end
		return (1 + (a or 0) * (own - 1)) * mGain
	end

	-- 표시 단위: 장비 없음 loadout의 무기 기본 atk 단위(D2 · S13 anchorRotationUnits와 같은 눈금 - 검사 615.4). 비율 계산에는 안 쓴다.
	result.units = {}
	for _, classId in ipairs({ "greatsword", "dualblade", "bow", "healer" }) do
		local loadout = BalanceSim.buildLoadout(anchorSpec(classId))
		result.units[classId] = loadout.atk / loadout.class.atk
	end
	for _, tier in ipairs(cfg.gearTiers) do
		local gems = tierGems(tier)
		local row = { id = tier.id, displayName = tier.displayName, dps = {} }
		for _, classId in ipairs({ "greatsword", "dualblade", "bow" }) do
			row.dps[classId] = EconSim.rotationDamage(anchorSpec(classId), gems)
		end
		row.healerWithOptions = EconSim.rotationDamage(anchorSpec("healer"), gems)
		row.healerOwnGain = row.healerWithOptions / healerBase
		row.dealerGain = row.dps.greatsword / gsBase
		result.tiers[tier.id] = row
	end

	local function rFor(tier, a, m, dealerClass)
		local row = result.tiers[tier.id]
		return healerBase * healModeFactor(tier, a, m) * fight / row.dps[dealerClass or "greatsword"]
	end
	result.rFor = rFor

	for _, tier in ipairs(cfg.gearTiers) do
		local row = result.tiers[tier.id]
		row.r = rFor(tier, 0, 0)
		row.share = share(row.r, 3)
		row.rByDealer = {}
		for _, classId in ipairs(cfg.dealerClasses) do
			row.rByDealer[classId] = rFor(tier, 0, 0, classId)
		end
		row.rDealing = row.healerWithOptions / row.dps.greatsword
	end

	-- 비중이 문턱(shareFloor)으로 떨어지는 검사 장비 배율(연속값): r = 치유모드 딜 × 전투 비율 ÷ (검사 기준 × G) → G* = r_없음 ÷ r*.
	local rNone = result.tiers[cfg.gearTiers[1].id].r
	local rAtFloor = 3 * cfg.shareFloor / (1 - cfg.shareFloor)
	result.dealerGainAtFloor = rNone / rAtFloor

	-- 모든 장비 단계에서 비중 ≥ shareTarget이 되는 최소 a · m(격자 0.01 · 0.01).
	local function allTiersOk(a, m)
		for _, tier in ipairs(cfg.gearTiers) do
			if share(rFor(tier, a, m), 3) < cfg.shareTarget then
				return false
			end
		end
		return true
	end
	for _, a in ipairs(cfg.applyRates) do
		local row = { a = a, shares = {} }
		for _, tier in ipairs(cfg.gearTiers) do
			row.shares[tier.id] = share(rFor(tier, a, 0), 3)
		end
		table.insert(result.applyRates, row)
	end
	for _, m in ipairs(cfg.gemCoefficients) do
		local row = { m = m, shares = {} }
		for _, tier in ipairs(cfg.gearTiers) do
			row.shares[tier.id] = share(rFor(tier, 0, m), 3)
		end
		table.insert(result.gemCoefficients, row)
	end
	result.minApplyRate = nil
	for step = 0, 100 do
		if allTiersOk(step / 100, 0) then
			result.minApplyRate = step / 100
			break
		end
	end
	result.minGemCoefficient = nil
	for step = 0, 300 do
		if allTiersOk(0, step / 100) then
			result.minGemCoefficient = step / 100
			break
		end
	end
	if whatIf and (whatIf.healerApplyRate or whatIf.healerGemCoefficient) then
		result.whatIfRow = { a = whatIf.healerApplyRate or 0, m = whatIf.healerGemCoefficient or 0, shares = {} }
		for _, tier in ipairs(cfg.gearTiers) do
			result.whatIfRow.shares[tier.id] = share(rFor(tier, result.whatIfRow.a, result.whatIfRow.m), 3)
		end
	end

	-- 딜링모드 목표(딜러 × 0.85 ~ 0.9)에 필요한 배율 - 장비 없음 기준. 배율은 SkillData.healer.E.attackMultiplier에 곱한다(딜링모드 딜은 그 배율에 비례 -
	-- 계산한 배율을 실제로 덮어써 다시 돌린 값으로 확인한다).
	for _, classId in ipairs(cfg.dealerClasses) do
		local dealer = result.tiers[cfg.gearTiers[1].id].dps[classId]
		local row = { classId = classId, dealer = dealer, targets = {} }
		for _, target in ipairs(cfg.dealingTargetRange) do
			local factor = target * dealer / healerBase
			local check = EconSim.withOverrides({ dealingMultiplier = factor }, function()
				return EconSim.rotationDamage(anchorSpec("healer"), {})
			end)
			table.insert(row.targets, { target = target, factor = factor, attackMultiplier = SkillData.healer.E.attackMultiplier * factor, checkRatio = check / dealer })
		end
		table.insert(result.dealers, row)
	end
	result.contributionThreshold = CombatConfig.contributionRewardThreshold
	return result
end

-- ═══ 표본 대조(S21a · S21-0) ═══
-- ① S21-0 A6: BalanceSim 생존 타수 - 앵커(궁수, 레벨 = 스테이지) 2448 · 2500 · 3000에서 유한 · 7타(S21a §2-1 "스테이지 내내 정확히 7").
-- ② S21a §2-1: 앵커 궁수 로테이션 처치 시간 - 스테이지 100 = 2.66초 · 500 = 16.7초(EconSim.killSeconds가 BalanceSim.measurePoint와 같은 조건).
-- ③ S21-0 D2: 치유사 r - 딜링모드 1.5412 · 필드 0.9236 · 보스전 0.410 · 4인 보스전 비중 12.0%.
function EconSimTables.samples(healer)
	local samples = {}
	local classId = BalanceAnchorConfig.referenceClassId
	for _, stage in ipairs({ 2448, 2500, 3000 }) do
		local loadout = BalanceSim.buildAnchorLoadout(classId, stage, 0)
		local survive = BalanceSim.getSurviveHits(loadout, BalanceSim.getMonsterAttack(stage))
		table.insert(samples, {
			id = ("A6 생존 %d"):format(stage), expected = 7, value = survive, ok = survive == survive and survive < math.huge and math.abs(survive - 7) <= 0.01,
		})
	end
	for _, entry in ipairs({ { 100, 2.66 }, { 500, 16.7 } }) do
		local loadout = BalanceSim.buildAnchorLoadout(classId, entry[1], 0)
		local kill = EconSim.killSeconds(loadout, BalanceSim.getMonsterHp(entry[1]), 600)
		table.insert(samples, { id = ("S21a 처치 %d"):format(entry[1]), expected = entry[2], value = kill, ok = math.abs(kill - entry[2]) <= entry[2] * 0.01 + 0.005 })
	end
	local rDealing = healer.healerDealing / healer.greatswordBase
	local rField = rDealing * healer.fieldUptime
	local rBoss = rDealing * healer.fightRatio.heal
	local shareBoss = share(rBoss, 3)
	for _, entry in ipairs({
		{ "D2 r 딜링모드", 1.5412, rDealing, 0.0005 },
		{ "D2 r 필드", 0.9236, rField, 0.0005 },
		{ "D2 r 보스전", 0.410, rBoss, 0.0005 },
		{ "D2 비중 4인 보스전", 0.120, shareBoss, 0.0005 },
	}) do
		table.insert(samples, { id = entry[1], expected = entry[2], value = entry[3], ok = math.abs(entry[3] - entry[2]) <= entry[4] })
	end
	return samples
end

return EconSimTables
