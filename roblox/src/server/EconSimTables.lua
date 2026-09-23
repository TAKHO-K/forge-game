-- 경제 시뮬의 표 계산(P0 E4 강화표 · E5 태초 선택지 · E6 치유사 · 표본 대조). 진행 시뮬(E3)은 EconSim.runProgress.
-- 전부 게임 모듈을 그대로 불러 계산한다 - 여기서 새로 정한 것은 "무엇을 비교하는가"(모형)뿐이고, 그 모형은 각 함수 주석 + P0-log에 [가정]으로 적었다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconSimConfig = require(ReplicatedStorage.Shared.data.EconSimConfig)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local Loot = require(ReplicatedStorage.Shared.Loot)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local PartyShieldSim = require(ReplicatedStorage.Shared.PartyShieldSim)
local EconSim = require(script.Parent.EconSim)

local EconSimTables = {}

-- ═══ E5 태초 선택지 손익분기 ═══
-- 모형([가정]): 레벨 Lp 앵커 장비(BalanceSim.buildAnchorLoadout)의 플레이어가 "일반" 프로필의 사냥 기준(목표 처치 초 · 조작 효율 · 이동 시간)으로
--   (B) tier t(1 ~ 5)를 자기 스테이지 sB(tier1이 목표 초 안에 잡히는 가장 높은 스테이지 = 최고 스테이지로 본다)에서, (A) 드래곤(tier6)을 sA = sB − Δ에서 잡는다.
--   태초 기대 가치/분 = 분당 처치 × 처치당 장비 기대 개수(Loot.expectedArmorDropCount) × 태초 확률(DropTable.effectiveRate - 서버 굴림과 같은 함수, 레벨 감쇠 포함)
--   × 태초 위력 옵션 값(Option.valueOf, roll 1.0, 보석 레벨 = 잡은 스테이지 = 몬스터 레벨).
-- 결과 = A ÷ B. 1 초과면 "낮은 스테이지 드래곤"이 태초 기준 우세(지배 전략). 손익분기 배수 M* = 드래곤 ÷ tier t 확률 배수가 이 값일 때 A ÷ B = 1
-- (배수 ≤ M*면 지배 전략 아님). A ÷ B는 배수에 비례한다.
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

local function primValue(itemLevel, classId)
	return EconSim.gemValue(EconSim.makeGem("attackPercent", "primordial", itemLevel, 1.0), classId)
end

function EconSimTables.primordial()
	local cfg = EconSimConfig.primordial
	local profile = EconSimConfig.profiles.normal
	local classId = profile.classId
	local rows = {}
	local function evaluate(playerLevel, lowTier, stageA, stageB, loadout, label)
		local a = perMinute(loadout, cfg.highTier, stageA, profile)
		local b = perMinute(loadout, lowTier, stageB, profile)
		local player = { bestStage = stageB }
		local rateA = DropTable.effectiveRate(player, { tierIndex = cfg.highTier }, stageA)
		local rateB = DropTable.effectiveRate(player, { tierIndex = lowTier }, stageB)
		local valueA, valueB = primValue(stageA, classId), primValue(stageB, classId)
		-- 같은 기본 확률일 때의 A ÷ B(= X). M* = 1 ÷ X - 감쇠는 A에만(B는 자기 최고 스테이지).
		local x = (a.dropsPerMinute * DropTable.levelDecay(stageB, stageA) * valueA) / (b.dropsPerMinute * valueB)
		local perMinA, perMinB = a.dropsPerMinute * rateA * valueA, b.dropsPerMinute * rateB * valueB
		table.insert(rows, {
			label = label, playerLevel = playerLevel, lowTier = lowTier, delta = stageB - stageA, stageA = stageA, stageB = stageB,
			rateA = rateA, rateB = rateB, decayA = DropTable.levelDecay(stageB, stageA), valueA = valueA, valueB = valueB,
			killA = a.killSeconds, killB = b.killSeconds, perMinA = perMinA, perMinB = perMinB,
			ratio = perMinB > 0 and perMinA / perMinB or math.huge,
			breakEven = x > 0 and 1 / x or math.huge,
			multiplier = rateB > 0 and DropTable.primordialBaseRate(cfg.highTier) / DropTable.primordialBaseRate(lowTier) or math.huge,
			goldRatio = a.goldPerMinute / b.goldPerMinute, expRatio = a.expPerMinute / b.expPerMinute,
		})
	end
	for _, playerLevel in ipairs(cfg.playerLevels) do
		local loadout = BalanceSim.buildAnchorLoadout(classId, playerLevel, 0)
		local stageB = EconSim.highestStageByKill(loadout, 1, profile.targetKillSeconds, profile.dpsEfficiency, InfiniteStageConfig.safeStageCap)
		for _, lowTier in ipairs(cfg.lowTiers) do
			local seen = {}
			for _, delta in ipairs(cfg.deltas) do
				local stageA = math.max(1, stageB - delta) -- Δ가 sB보다 크면 스테이지 1에서 잘린다 - 같은 sA는 한 번만
				if not seen[stageA] then
					seen[stageA] = true
					evaluate(playerLevel, lowTier, stageA, stageB, loadout, "grid")
				end
			end
		end
	end
	-- 사용자 설계 예시: 레벨 10 플레이어 - 레벨 1 드래곤 vs 레벨 14 슬라임.
	evaluate(10, 1, 1, 14, BalanceSim.buildAnchorLoadout(classId, 10, 0), "example")
	return rows
end

-- ═══ E6 치유사(P2 F) ═══
-- 앵커 조건(S21-0 D2와 같다): 레벨 100 · 무기 등급 0 · +0강 · 장비 일반 등급 itemLevel 100. 60초 로테이션 총딜(EconSim.rotationDamage - 치명 옵션은 평타만).
-- 모형(P2 - P0-log 20의 "치유모드 공격에 딜 옵션 미적용"은 게임 코드와 달랐다: AttackServer는 직업 · 모드와 무관하게 평타에 위력% · 치명 · 신속 옵션을 넣는다):
--   딜링모드 원딜 = 치유사 로테이션(BalanceSim이 딜링모드를 켠다 - SkillData.healer.E.attackMultiplier) · 딜 옵션 적용.
--   치유모드 원딜 = 같은 로테이션을 attackMultiplier 1(딜링모드 꺼짐 = 평타 그대로)로 · 딜 옵션 100% 적용(F1 · 결정 7A).
--   보스전 치유모드 딜 = 치유모드 원딜 × healModeFightRatio([가정] 1.0 - 치유모드는 소모가 없어 딜러처럼 계속 싸운다, 딜러 가동률도 1로 본다).
--   비중 = 치유사 딜 ÷ (딜러 3명 딜 + 치유사 딜). 딜링모드 비 = 딜링모드 원딜 ÷ 검사 원딜(목표 0.875 - 결정 8A).
local function anchorSpec(classId, weaponLevel)
	local level = BalanceAnchorConfig.referenceLevel
	local grade = BalanceAnchorConfig.gearGrade
	return {
		classId = classId,
		level = level,
		weaponLevel = weaponLevel or BalanceAnchorConfig.weaponLevel, -- P2.5a: 장비 단계의 강화 단계(없으면 앵커 +0)
		weaponGrade = 0,
		gear = {
			armor = { grade = grade, itemLevel = level },
			gloves = { grade = grade, itemLevel = level },
			shoes = { grade = grade, itemLevel = level },
		},
	}
end

local function tierGems(tier)
	local gems = {}
	for slot, entry in ipairs(tier.gems) do
		gems[slot] = EconSim.makeGem(entry[1], entry[2], entry[3], entry[4])
	end
	return gems
end

local function share(r, dealers)
	return r / (dealers + r)
end
EconSimTables.healerShare = share

-- 치유사 로테이션 60초 총딜(atk 단위가 아니라 게임 피해). dealing = true면 딜링모드 배율 그대로, false면 배율 1(치유모드).
-- P2.5a: 치유모드는 딜링모드 배율 1 · 투자 기울기도 없다(딜링모드 버프가 없으니) - investmentScaling을 잠깐 뺀다.
local function healerDamage(gems, dealing, weaponLevel)
	if dealing then
		return EconSim.rotationDamage(anchorSpec("healer", weaponLevel), gems)
	end
	return EconSim.withOverrides({ dealingAttackMultiplier = 1, dealingInvestmentScaling = false }, function()
		return EconSim.rotationDamage(anchorSpec("healer", weaponLevel), gems)
	end)
end

function EconSimTables.healer()
	local cfg = EconSimConfig.healer
	local result = { tiers = {}, compositions = {}, dealerMixes = {} }

	local healerBase = EconSim.rotationDamage(anchorSpec("healer"), {})
	local gsBase = EconSim.rotationDamage(anchorSpec("greatsword"), {})
	result.healerDealing = healerBase -- 표본 D2가 읽는다(딜링모드 · 장비 없음)
	result.greatswordBase = gsBase

	-- 보스전 전투 비율(딜링모드 - 쉴드 · 치유 두 모드) + 필드 가동률(S13 simulateHealerCycle) - 딜링모드로 싸우는 치유사의 참고값 · 표본 D2.
	local scenario = cfg.fightRatioScenario
	result.fightRatio = {}
	for _, shield in ipairs({ true, false }) do
		local run = PartyShieldSim.run({
			dealers = 3, healers = 1, healerRaw = healerBase / gsBase, bossHpUnits = 4 * scenario.bossHpUnitsSeconds,
			hitsPerSecond = scenario.hitsPerSecond, hitRatio = scenario.hitRatio, shield = shield, regenPerSecond = 0,
		})
		result.fightRatio[shield and "shield" or "heal"] = run.healerFightRatio
	end
	result.fieldUptime = BalanceSim.simulateHealerCycle({ hitsPerSecond = scenario.hitsPerSecond, hitRatio = scenario.hitRatio }).uptime
	result.healModeFightRatio = cfg.healModeFightRatio
	result.healerBuff = PartyConfig.healerBuffFraction

	for _, tier in ipairs(cfg.gearTiers) do
		local gems = tierGems(tier)
		local row = { id = tier.id, displayName = tier.displayName, dps = {} }
		row.weaponLevel = tier.weaponLevel or 0
		for _, classId in ipairs(cfg.dealerClasses) do
			row.dps[classId] = EconSim.rotationDamage(anchorSpec(classId, tier.weaponLevel), gems)
		end
		row.healMode = healerDamage(gems, false, tier.weaponLevel) * cfg.healModeFightRatio
		row.dealingMode = healerDamage(gems, true, tier.weaponLevel)
		-- P2.5a: 치유사의 투자량 기준(강화 단계 · 공격력% 합) - SkillData.healer.E.investmentScaling의 평균 · 최상위 기준점을 이 값으로 맞춘다.
		local healerSpec = anchorSpec("healer", tier.weaponLevel)
		healerSpec.gems = gems
		row.healerAttackPercent = BalanceSim.buildLoadout(healerSpec).attackPercentBonus
		row.rDealing = row.dealingMode / row.dps.greatsword
		row.r = {}
		row.share = {}
		for _, classId in ipairs(cfg.dealerClasses) do
			row.r[classId] = row.healMode / row.dps[classId]
			row.share[classId] = share(row.r[classId], 3)
		end
		-- 혼합 구성(검사 · 도적 · 궁수 각 1 + 치유사 1)
		local mixed = 0
		for _, classId in ipairs(cfg.dealerClasses) do
			mixed += row.dps[classId]
		end
		row.share.mixed = row.healMode / (mixed + row.healMode)
		result.tiers[tier.id] = row
	end

	-- F2 · F3 풀이(지금 값과 무관하게 목표를 맞추는 값 - 게임 데이터에 넣을 값의 근거): 치유모드 딜은 ClassData.healer.atk에, 딜링모드 딜은 atk × attackMultiplier에 비례한다.
	local atkNow = ClassData.classes.healer.atk
	local need = 0
	local rTarget = 3 * cfg.shareTarget / (1 - cfg.shareTarget)
	for _, tier in ipairs(cfg.gearTiers) do
		need = math.max(need, rTarget / result.tiers[tier.id].r[cfg.shareDealerClass])
	end
	result.solvedAtk = atkNow * need -- 이 값 이상이면 "도적 3 + 치유사 1"이 모든 장비 단계에서 비중 ≥ shareTarget
	-- P2.5a(결정 8): 딜링모드 배율은 "평균 투자"에서 검사 × 목표가 되게 푼다(P2는 장비 없음). 평균 투자 기준점에서 투자 기울기 = 1이라 배율 하나로 풀린다.
	local refRow = result.tiers.average or result.tiers[cfg.gearTiers[1].id]
	local healModeAtSolved = refRow.healMode / cfg.healModeFightRatio * need
	result.solvedDealingMultiplier = cfg.dealingTarget * refRow.dps.greatsword / healModeAtSolved

	-- F4 파티 구성 속도: 파티 딜 = (딜러 딜 합 + 치유사 딜 합) × (치유사가 있으면 1 + 힐러 버프 b). 보스 HP는 인원(4)이 같아 같다 → 속도 = 파티 딜 ÷ 딜러 4명 딜.
	--   치유사 모드 두 가지: 치유모드(위 healMode) · 딜링모드(딜링모드 원딜 × 보스전 전투 비율(쉴드) - 소모 · 이탈 포함, S13b 모형).
	for _, tier in ipairs(cfg.gearTiers) do
		local row = result.tiers[tier.id]
		for _, dealerClass in ipairs(cfg.compositionDealerClasses) do
			local dealer = row.dps[dealerClass]
			-- 참고: PartyConfig의 b 식(b = N ÷ (N − 1 + r) − 1, r = 치유사 딜 ÷ 딜러 딜)에 지금 치유모드 r을 넣은 값 - "딜러 3 + 치유사 1 = 딜러 4"가 되는 b(게임 값은 안 바꾼다).
			local maxMembers = PartyConfig.maxMembers
			local rebuiltBuff = maxMembers / (maxMembers - 1 + row.healMode / dealer) - 1
			local entry = { tier = tier.id, dealerClass = dealerClass, speeds = {}, rebuiltBuff = rebuiltBuff }
			for _, composition in ipairs(cfg.compositions) do
				local hasHealer = composition.healers > 0
				local buff = hasHealer and (1 + PartyConfig.healerBuffFraction) or 1
				local heal = (composition.dealers * dealer + composition.healers * row.healMode) * buff
				local deal = (composition.dealers * dealer + composition.healers * row.dealingMode * result.fightRatio.shield) * buff
				local rebuilt = (composition.dealers * dealer + composition.healers * row.healMode) * (hasHealer and (1 + rebuiltBuff) or 1)
				table.insert(entry.speeds, { dealers = composition.dealers, healers = composition.healers, healMode = heal / (4 * dealer), dealingMode = deal / (4 * dealer), rebuiltBuff = rebuilt / (4 * dealer) })
			end
			table.insert(result.compositions, entry)
		end
	end
	result.contributionThreshold = CombatConfig.contributionRewardThreshold
	return result
end

-- ═══ 표본 대조(P2.5a 앵커 - 새 k에서 다시 푼 값) ═══
-- ① 생존 앵커(CombatConfig.damageReductionAlpha · maxHpBonusBase): 앵커 장비(레벨 = itemLevel = 스테이지)에서 스테이지 1,000 · 5,000 · 20,000 모두 7.0타
--    (옛 k의 레벨 100 비율을 새 k의 고스테이지에서 다시 풀었다 - 상수 +10 HP · +5 방어 몫이 사라지는 곳).
-- ② 처치 앵커(CharacterLevelConfig.levelStageOffset): 앵커 장비 레벨 L로 스테이지 L + 167의 tier1을 2.5초(BalanceAnchorConfig.killTargetSeconds)에 잡는다 - L = 100 · 1000.
-- ③ 치유사(결정 8): 딜링모드 ÷ 검사 = 평균 투자 0.875 · 최상위 투자 HealerTopScale(1.1) · 도적 3 + 1 비중(평균) ≥ 12%.
function EconSimTables.samples(healer)
	local samples = {}
	local classId = BalanceAnchorConfig.referenceClassId
	for _, entry in ipairs({ { 1000, 0.02 }, { 5000, 0.02 }, { 20000, 0.02 } }) do
		local stage = entry[1]
		local loadout = BalanceSim.buildAnchorLoadout(classId, stage, 0)
		local survive = BalanceSim.getSurviveHits(loadout, BalanceSim.getMonsterAttack(stage))
		table.insert(samples, {
			id = ("생존 앵커 %d"):format(stage), expected = 7, value = survive, ok = survive == survive and survive < math.huge and math.abs(survive - 7) <= entry[2],
		})
	end
	for _, level in ipairs({ 100, 1000 }) do
		local loadout = BalanceSim.buildAnchorLoadout(classId, level, 0)
		local stage = CharacterLevel.getStageForLevel(level)
		local kill = EconSim.killSeconds(loadout, BalanceSim.getMonsterHp(stage), 600)
		table.insert(samples, { id = ("처치 앵커 레벨 %d · 스테이지 %d"):format(level, stage), expected = BalanceAnchorConfig.killTargetSeconds, value = kill, ok = math.abs(kill - BalanceAnchorConfig.killTargetSeconds) <= 0.1 })
	end
	local scaling = SkillData.healer.E.investmentScaling
	for _, entry in ipairs({
		{ "치유사 딜링모드 ÷ 검사(평균 투자)", 0.875, healer.tiers.average.rDealing, 0.01 },
		{ "치유사 딜링모드 ÷ 검사(최상위 투자)", scaling and scaling.topScale or 1, healer.tiers.top.rDealing, 0.02 },
		{ "치유사 비중 도적 3 + 1(평균)", 0.122, healer.tiers.average.share.dualblade, 0.01 },
	}) do
		table.insert(samples, { id = entry[1], expected = entry[2], value = entry[3], ok = math.abs(entry[3] - entry[2]) <= entry[4] })
	end
	return samples
end

return EconSimTables
