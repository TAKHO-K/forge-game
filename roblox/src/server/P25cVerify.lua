-- P2.5c 자동 검증 - 수치 조정(천장 경사 · 신규 보호 · 환생 25단위 · 구매력 · 보석 비중 · 보스 드랍 · 태초 · 임계값 · 마일스톤)(docs/phase/P25c-log.md). DevTools.server.lua가 부른다.
--   (가) runPure = 순수 함수 · 데이터(서버 시작 때, 플레이어 없이) - shared 모듈만 쓴다(하네스에서도 돈다). 곡선 목표(시간)는 P0(가) 9 · /gg econ(P25c-after)이 잰다.
--   (나) runLive = 실제 Player(보스 검증 체인의 끝): 신규 보호가 실제 피해 경로(PlayerDamage)에 걸리는가 · 환생 경험치 배율이 실제 경험치 지급에만 걸리는가 ·
--        새 방지권 지급 스테이지. 검증이 바꾼 것(스테이지 · 경험치 · 환생 횟수 · 체력 · 방지권)은 env.ensureBackup/restore가 되돌린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local MilestoneData = require(ReplicatedStorage.Shared.data.MilestoneData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local Option = require(ReplicatedStorage.Shared.Option)
local Milestone = require(ReplicatedStorage.Shared.Milestone)
local Loot = require(ReplicatedStorage.Shared.Loot)

local P25cVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[P25c][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function recorder.section(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			recorder.check(("%s 실행 중 에러: %s"):format(label, tostring(err)), false)
		end
	end
	function recorder.summary()
		return passCount, totalCount
	end
	return recorder
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-9) * math.max(1, math.abs(a), math.abs(b))
end

-- ═══ (가) ═══
function P25cVerify.runPure()
	print("===P25c 검증 시작(가)===")
	local r = newRecorder("가")
	local k = InfiniteStageConfig.growthRate

	r.section("[H] 스테이지 번호 임계값 - 힘 비율 환산", function()
		local legacy = InfiniteStageConfig.legacyGrowthRate
		-- 힘 비율: 새 스테이지 s에서 몬스터 힘 k^(s − 1)이 옛 1.155^(옛 − 1)과 반올림 한 칸 안에서 같다.
		local function samePower(newStage, oldStage, snap)
			return math.abs((newStage - 1) - math.log(legacy ^ (oldStage - 1)) / math.log(k)) <= (snap or 1) / 2 + 1e-9
		end
		local stone, high = EnhanceMaterialData.materials.enhanceStone.minStage, EnhanceMaterialData.materials.highEnhanceStone.minStage
		local grant = EnhanceConfig.protection.bossGrant
		local density = BossData.mechanics.stageDensity
		local interval = BossData.stageInterval
		r.check(("H1 재료 해금 강화석 %d · 상급 %d(기대 358 · 539 = 옛 50 · 75의 힘) · fromLegacyStage(1) = %d(기대 1)"):format(stone, high, InfiniteStage.fromLegacyStage(1)),
			stone == 358 and high == 539 and samePower(stone, 50) and samePower(high, 75) and InfiniteStage.fromLegacyStage(1) == 1)
		r.check(("H2 방지권 첫 지급 %d · 간격 %d · 초기화 %d(기대 360 · 180 · 720 - 보스 간격 %d의 배수)"):format(grant.firstStage, grant.stepStages, grant.resetFromStage, interval),
			grant.firstStage == 360 and grant.stepStages == 180 and grant.resetFromStage == 720 and samePower(grant.firstStage, 50, interval) and samePower(grant.resetFromStage, 100, interval)
				and grant.firstStage % interval == 0 and grant.stepStages % interval == 0 and grant.resetFromStage % interval == 0)
		local cells, grantsOk = {}, true
		for _, row in ipairs({ { 355, 0, 0 }, { 360, 1, 0 }, { 365, 0, 0 }, { 540, 1, 0 }, { 720, 1, 1 }, { 900, 1, 1 }, { 50, 0, 0 }, { 100, 0, 0 } }) do
			local drop, reset = Enhance.getBossGrant(row[1])
			grantsOk = grantsOk and drop == row[2] and reset == row[3]
			table.insert(cells, ("%d→%d·%d"):format(row[1], drop, reset))
		end
		local total = 0
		for stage = interval, InfiniteStageConfig.designMaxStage, interval do
			total += Enhance.getBossGrant(stage)
		end
		r.check(("H2 지급 표 %s(기대 355 없음 · 360 하락 · 365 없음 · 540 하락 · 720 · 900 둘 다 · 옛 50 · 100 없음) · 설계 최대까지 하락 %d장(옛 번호면 약 850)"):format(table.concat(cells, " "), total),
			grantsOk and total > 100 and total < 150)
		local extras = {}
		for _, stage in ipairs({ 350, 355, 535, 715, 5000 }) do
			table.insert(extras, BossRules.densityExtra(stage))
		end
		r.check(("H3 보스 밀도 시작 %d · 간격 %d(기대 175 · 180) · extra 350 · 355 · 535 · 715 · 5000 = %s(기대 0 · 1 · 2 · 3 · 3)"):format(density.startStage, density.stepStages, table.concat(extras, " · ")),
			density.startStage == 175 and density.stepStages == 180 and table.concat(extras, ",") == "0,1,2,3,3" and samePower(density.startStage, 25, interval))
	end)

	r.section("[F · G] 보스 드랍 · 태초 tier", function()
		local deltas, weights = {}, {}
		for _, entry in ipairs(ArmorData.bossItemLevelDelta) do
			table.insert(deltas, entry.delta)
			table.insert(weights, entry.weight)
		end
		local counts, samples, bad = {}, 30000, 0
		for _ = 1, samples do
			local delta = Loot.rollItemLevel(1000, ArmorData.bossItemLevelDelta) - 1000
			counts[delta] = (counts[delta] or 0) + 1
			if delta ~= 0 and delta ~= 7 and delta ~= 15 then
				bad += 1
			end
		end
		r.check(("F 보스 드랍 편차 %s · 가중치 %s(기대 0 · 7 · 15 · 3 : 2 : 1) · 굴림 %d회 비율 %.3f · %.3f · %.3f(기대 0.5 · 0.333 · 0.167 ± 0.015) · 표 밖 %d(기대 0)"):format(
			table.concat(deltas, " · "), table.concat(weights, " : "), samples, (counts[0] or 0) / samples, (counts[7] or 0) / samples, (counts[15] or 0) / samples, bad),
			table.concat(deltas, ",") == "0,7,15" and table.concat(weights, ",") == "3,2,1" and bad == 0
				and math.abs((counts[0] or 0) / samples - 0.5) <= 0.015 and math.abs((counts[7] or 0) / samples - 1 / 3) <= 0.015 and math.abs((counts[15] or 0) / samples - 1 / 6) <= 0.015)
		local rates, rising = {}, true
		for tier = 1, 6 do
			rates[tier] = DropTable.primordialBaseRate(tier)
			if tier > 1 then
				rising = rising and rates[tier] > rates[tier - 1]
			end
		end
		local dragon = DropTableData.primordial.dragonRate
		r.check(("G 태초 기본 확률 tier1 ~ 6 = %.4f%% · %.4f%% · %.4f%% · %.4f%% · %.4f%% · %.4f%% · tier가 오를수록 커진다 %s · tier4 · 5 ÷ 드래곤 = %.3f · %.3f(기대 0.94 · 0.97 - 드래곤 최고)"):format(
			rates[1] * 100, rates[2] * 100, rates[3] * 100, rates[4] * 100, rates[5] * 100, rates[6] * 100, tostring(rising), rates[4] / dragon, rates[5] / dragon),
			rising and rates[6] == dragon and near(rates[4] / dragon, 0.94, 1e-9) and near(rates[5] / dragon, 0.97, 1e-9))
	end)

	r.section("[B] 신규 보호", function()
		local p = CombatConfig.newbieProtection
		local m1, m10, m20, m21 = PlayerCombat.getNewbieDamageMultiplier(1), PlayerCombat.getNewbieDamageMultiplier(10), PlayerCombat.getNewbieDamageMultiplier(20), PlayerCombat.getNewbieDamageMultiplier(21)
		local monotone = true
		for stage = 2, p.untilStage + 2 do
			monotone = monotone and PlayerCombat.getNewbieDamageMultiplier(stage) >= PlayerCombat.getNewbieDamageMultiplier(stage - 1)
		end
		r.check(("B1 받는 피해 배율 스테이지 1 %.3f · 10 %.3f · 20 %.3f · 21 %.3f · nil %s(기대 %.2f · %.3f · %.3f · 1 · 1 - 기하 감소) · 단조 증가 %s"):format(
			m1, m10, m20, m21, tostring(PlayerCombat.getNewbieDamageMultiplier(nil)), p.atStage1, p.atStage1 ^ (1 - 9 / p.untilStage), p.atStage1 ^ (1 - 19 / p.untilStage), tostring(monotone)),
			near(m1, p.atStage1, 1e-12) and near(m10, p.atStage1 ^ (1 - 9 / p.untilStage), 1e-12) and near(m20, p.atStage1 ^ (1 - 19 / p.untilStage), 1e-12) and m21 == 1
				and PlayerCombat.getNewbieDamageMultiplier(nil) == 1 and monotone and p.untilStage == 20)
		local loadout = BalanceSim.buildAnchorLoadout("bow", 1, 0)
		local attack = BalanceSim.getMonsterAttack(1)
		local plain = BalanceSim.getSurviveHits(loadout, attack)
		local protected = BalanceSim.getSurviveHits(loadout, attack, m1)
		r.check(("B2 시뮬 생존 타수(스테이지 1 앵커): %.2f → %.2f(기대 ÷ %.2f = ×%.1f)"):format(plain, protected, m1, 1 / m1), near(protected, plain / m1, 1e-9))
	end)

	r.section("[C] 환생 · 경험치", function()
		local levels, mults = {}, {}
		for count = 0, 4 do
			levels[count + 1] = CharacterLevel.getRebirthRequiredLevel(count)
		end
		for count = 0, 6 do
			mults[count + 1] = CharacterLevel.getRebirthExpMultiplier(count)
		end
		r.check(("C1 환생 필요 레벨 %s(기대 25 · 50 · 75 · 100 · 125) · 경험치 배율 환생 0 ~ 6회 %s(기대 1 ~ 6 · 표 밖 = 마지막 6)"):format(table.concat(levels, " · "), table.concat(mults, " · ")),
			table.concat(levels, ",") == "25,50,75,100,125" and table.concat(mults, ",") == "1,2,3,4,5,6,6" and CharacterLevel.getRebirthRequiredLevel(5) == nil)
		local anchors = CharacterLevelConfig.killTargetAnchors
		r.check(("C2 목표 마릿수: 마지막 앵커 레벨 %d(기대 125 - Option 동결 레벨) · K(125) %g · K(126) %g(기대 150 = 25 × 5회 뒤 배율 %g) · K(20000) %g · 앵커 사이 증가 %s"):format(
			anchors[#anchors].level, CharacterLevel.getTargetKills(125), CharacterLevel.getTargetKills(126), CharacterLevel.getRebirthExpMultiplier(5), CharacterLevel.getTargetKills(20000),
			tostring(CharacterLevel.getTargetKills(100) > CharacterLevel.getTargetKills(75) and CharacterLevel.getTargetKills(75) > CharacterLevel.getTargetKills(50))),
			anchors[#anchors].level == 125 and CharacterLevel.getTargetKills(126) == 25 * CharacterLevel.getRebirthExpMultiplier(5) and CharacterLevel.getTargetKills(20000) == CharacterLevel.getTargetKills(126)
				and CharacterLevel.getTargetKills(100) > CharacterLevel.getTargetKills(75))
		-- 5회 뒤 "레벨이 스테이지를 따라가는 간격"이 옛 곡선(25마리 · 배율 1)과 같다: K ÷ 배율 = 25.
		r.check(("C3 5회 뒤 K ÷ 배율 = %g(기대 25 - 옛 곡선과 같은 간격)"):format(CharacterLevel.getTargetKills(500) / CharacterLevel.getRebirthExpMultiplier(5)),
			CharacterLevel.getTargetKills(500) / CharacterLevel.getRebirthExpMultiplier(5) == 25)
	end)

	r.section("[D] 강화 비용(구매력)", function()
		local costs, monotone = {}, true
		for level = 0, EnhanceConfig.maxLevel - 1 do
			if level >= 1 then
				monotone = monotone and EnhanceConfig.goldCost[level + 1] >= EnhanceConfig.goldCost[level]
			end
			if level >= 20 then
				table.insert(costs, EnhanceConfig.goldCost[level + 1])
			end
		end
		local ratio = EnhanceConfig.goldCost[30] / EnhanceConfig.goldCost[21]
		r.check(("D1 +20 ~ +29 1회 %s · +29 ÷ +20 = %.3f(기대 약 1.365 = 1.035^9 - 1회 20 → 29분) · 0 ~ 29 단조 증가 %s · +16 %d(그대로)"):format(table.concat(costs, " · "), ratio, tostring(monotone), EnhanceConfig.goldCost[17]),
			EnhanceConfig.goldCost[21] == 20000 and math.abs(ratio - 1.035 ^ 9) <= 0.01 and monotone and EnhanceConfig.goldCost[17] == 14900)
	end)

	r.section("[E] 보석 등급 몫", function()
		local order = ArmorData.gradeOrder
		local ratiosOk = true
		for index = 2, #order do
			ratiosOk = ratiosOk and near(Option.gradeFactor(order[index]) / Option.gradeFactor(order[index - 1]), OptionData.gradeStep, 1e-12)
		end
		local primordial = Option.gradeFactor("primordial")
		local value = Option.valueOf({ id = "attackPercent", roll = 1 }, "primordial", 100, nil)
		r.check(("E1 등급당 ×%.2f(장비 ×%.2f) · 일반 %.4f(= 1 ÷ 장비 태초 %.2f) · 태초 %.4f(기대 (%.2f ÷ %.2f)^6 = %.4f) · 태초 위력 Lv.100 = %.4f(= 0.30 × 몫) · 모든 등급 ≤ 장비 몫 %s"):format(
			OptionData.gradeStep, ItemVisualData.gradeStep, Option.gradeFactor("normal"), ItemVisualData.gradeVisuals.primordial.statMultiplier, primordial, OptionData.gradeStep, ItemVisualData.gradeStep,
			(OptionData.gradeStep / ItemVisualData.gradeStep) ^ 6, value, tostring(Option.gradeFactor("epic") <= ItemVisualData.gradeVisuals.epic.statMultiplier / ItemVisualData.gradeVisuals.primordial.statMultiplier)),
			ratiosOk and near(Option.gradeFactor("normal"), 1 / ItemVisualData.gradeVisuals.primordial.statMultiplier, 1e-12) and near(primordial, (OptionData.gradeStep / ItemVisualData.gradeStep) ^ 6, 1e-9)
				and near(value, 0.30 * primordial, 1e-12) and OptionData.gradeStep < ItemVisualData.gradeStep)
	end)

	r.section("[I] 마일스톤 상한", function()
		r.check(("I1 버킷 상한 %.4f(= 1.02^10 − 1 - 힘 비율 상수) · 스테이지 환산 %.2f(기대 10 - k 1.02에서) · 붙는 곳 %s(기대 attack - E1 비교) · 상한 레벨 %d"):format(
			Milestone.bonusCap(), math.log(MilestoneData.capRatio) / math.log(k), MilestoneData.stat, Milestone.capLevel()),
			near(Milestone.bonusCap(), 1.02 ^ 10 - 1, 1e-12) and math.abs(math.log(MilestoneData.capRatio) / math.log(k) - 10) < 1e-9 and MilestoneData.stat == "attack")
	end)

	r.section("[A] 천장 구간", function()
		local segments = CharacterLevelConfig.weaponGrowthSegments
		local ascending, sharesOk = true, true
		for index, segment in ipairs(segments) do
			sharesOk = sharesOk and segment.kShare > 0 and segment.kShare <= 1
			if index > 1 then
				ascending = ascending and segment.fromLevel > segments[index - 1].fromLevel
			end
		end
		-- 구간 경계에서 한 레벨 비가 앞 구간 · 뒤 구간 몫과 같다(이어짐 - 계단 없음).
		local continuous = true
		for index, segment in ipairs(segments) do
			local before = CharacterLevel.getWeaponExpMultiplier(segment.fromLevel) / CharacterLevel.getWeaponExpMultiplier(segment.fromLevel - 1)
			local after = CharacterLevel.getWeaponExpMultiplier(segment.fromLevel + 1) / CharacterLevel.getWeaponExpMultiplier(segment.fromLevel)
			local previousShare = index > 1 and segments[index - 1].kShare or math.log(CharacterLevelConfig.weaponMultGrowthRate) / math.log(k)
			continuous = continuous and near(before, k ^ previousShare, 1e-12) and near(after, k ^ segment.kShare, 1e-12)
		end
		local deficit = 0
		for level = 26, InfiniteStageConfig.designMaxStage do
			deficit += 1 - math.log(CharacterLevel.getWeaponExpMultiplier(level) / CharacterLevel.getWeaponExpMultiplier(level - 1)) / math.log(k)
		end
		r.check(("A1 구간 %d개 · 오름차순 %s · 몫 (0, 1] %s · 경계 이어짐 %s · 설계 최대 %d까지 레벨 결손 %.0f스테이지(g = k였다면 0)"):format(#segments, tostring(ascending), tostring(sharesOk), tostring(continuous), InfiniteStageConfig.designMaxStage, deficit),
			#segments >= 5 and ascending and sharesOk and continuous and deficit > 365 and deficit < 2000)
		r.check(("A2 설계 최대 %d(기대 25,300 - 상위 1%% 2,190시간 · 하네스) · 안전 상한 %d(기대 34,230)"):format(InfiniteStageConfig.designMaxStage, InfiniteStageConfig.safeStageCap),
			InfiniteStageConfig.designMaxStage == 25300 and InfiniteStageConfig.safeStageCap == 34230)
	end)

	local pass, total = r.summary()
	print(("===P25c 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total
end

-- ═══ (나) ═══
function P25cVerify.runLive(player, env)
	print("===P25c 검증 시작(나: 실제 Player · 신규 보호 · 환생 경험치 배율 · 방지권 지급)===")
	local r = newRecorder("나")
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	local PlayerState = require(script.Parent.PlayerState)
	local ProtectionTickets = require(script.Parent.ProtectionTickets)
	local profile = PlayerProfile.getProfile(player)
	if not profile or not profile.classId then
		r.check("프로필 · 직업이 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===P25c 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end
	env.ensureBackup(player) -- 스테이지 · 경험치 · 환생 · 방지권은 env.restore가 되돌린다
	local classState = profile.classes[profile.classId]

	r.section("[B] 신규 보호 - 실제 피해 경로", function()
		-- 같은 공격을 스테이지 1 · 10 · 30에서 PlayerDamage.applyHit로 넣고, 감소식만 거친 피해(computeHitDamage)와 비교한다. 체력은 매번 가득 채운다(쓰러지지 않게).
		local attack = 1
		local function hitAt(stage)
			env.applyStage(player, stage)
			PlayerState.setHp(player, PlayerState.getMaxHp(player))
			local raw = PlayerDamage.computeHitDamage(attack, player)
			local dealt = PlayerDamage.applyHit(player, attack, "P25c 신규 보호 검증")
			PlayerState.setHp(player, PlayerState.getMaxHp(player))
			PlayerDamage.syncHud(player)
			return dealt, raw
		end
		local d1, raw1 = hitAt(1)
		local d10, raw10 = hitAt(10)
		local d30, raw30 = hitAt(30)
		local ok = raw1 > 0 and near(d1 / raw1, PlayerCombat.getNewbieDamageMultiplier(1), 1e-6) and near(d10 / raw10, PlayerCombat.getNewbieDamageMultiplier(10), 1e-6) and near(d30 / raw30, 1, 1e-6)
		r.check(("B 실제 applyHit ÷ 감소식 피해: 스테이지 1 %.4f · 10 %.4f · 30 %.4f(기대 %.3f · %.3f · 1 - 받는 사람의 무한 스테이지로 · 대시 · 잡힘 배율 1 상태)"):format(
			d1 / raw1, d10 / raw10, d30 / raw30, PlayerCombat.getNewbieDamageMultiplier(1), PlayerCombat.getNewbieDamageMultiplier(10)), ok)
	end)

	r.section("[C] 환생 경험치 배율 - 실제 지급 경로", function()
		env.applyStage(player, 30)
		classState.rebirthCount = 0
		local base = PlayerProfile.getExpGainMultiplier(player)
		classState.characterExp = 0
		PlayerProfile.addCharacterExp(player, 100)
		local gain0 = classState.characterExp
		classState.rebirthCount = 3
		local baseAt3 = PlayerProfile.getExpGainMultiplier(player)
		classState.characterExp = 0
		PlayerProfile.addCharacterExp(player, 100)
		local gain3 = classState.characterExp
		r.check(("C 경험치 100 지급: 환생 0회 +%g · 3회 +%g(기대 ×%g = 100 × 옵션 · 파티 %.3f × 환생 배율) · getExpGainMultiplier(재료가 쓰는 배수) 0회 %.3f = 3회 %.3f(기대 같음 - 재료에는 환생 배율 없음)"):format(
			gain0, gain3, CharacterLevel.getRebirthExpMultiplier(3), base, base, baseAt3),
			near(gain0, 100 * base, 1e-9) and near(gain3, 100 * base * CharacterLevel.getRebirthExpMultiplier(3), 1e-9) and near(base, baseAt3, 1e-12))
	end)

	r.section("[H] 방지권 지급 - 새 스테이지(계정 첫 클리어 지급 함수)", function()
		local grant = EnhanceConfig.protection.bossGrant
		profile.purchases.protectionClaimedStages = {}
		local drop0, reset0 = ProtectionTickets.grantForBoss(player, 50)
		local drop1, reset1 = ProtectionTickets.grantForBoss(player, grant.firstStage)
		local drop2, reset2 = ProtectionTickets.grantForBoss(player, grant.resetFromStage)
		local drop3, reset3 = ProtectionTickets.grantForBoss(player, grant.firstStage)
		r.check(("H 옛 50 → 하락 %s · 초기화 %s(기대 0 · 0) · %d → %s · %s(기대 1 · 0) · %d → %s · %s(기대 1 · 1) · %d 다시 → %s · %s(기대 0 · 0 - 계정 1회)"):format(
			tostring(drop0), tostring(reset0), grant.firstStage, tostring(drop1), tostring(reset1), grant.resetFromStage, tostring(drop2), tostring(reset2), grant.firstStage, tostring(drop3), tostring(reset3)),
			(drop0 or 0) == 0 and (reset0 or 0) == 0 and drop1 == 1 and (reset1 or 0) == 0 and drop2 == 1 and reset2 == 1 and (drop3 or 0) == 0 and (reset3 or 0) == 0)
	end)

	env.restore(player)
	local pass, total = r.summary()
	print(("===P25c 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return P25cVerify
