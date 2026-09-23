-- P2.5a 자동 검증 - 성장 모델 재설계(k 1.02) · 강화 +30 · 등급 ×1.45 · 골드 성장률 · 태초 · 보석 · P2 결정 5 ~ 10(docs/phase/P25a-log.md). DevTools.server.lua가 부른다.
--   (가) runPure = 순수 함수 · 합성 데이터(서버 시작 때, 플레이어 없이).
--   (나) runLive = 실제 Player(보스 검증 체인의 끝): 파티 경험치 칩(결정 7) · 명중 활동(결정 10) · 환생 지급 보석 itemLevel(결정 9) · 강화 +30 실제 공격력.
--        검증이 바꾼 것(파티 · 스탠드인 · 프로필 · 몬스터)은 끝날 때 전부 되돌린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local EnhanceVisualData = require(ReplicatedStorage.Shared.data.EnhanceVisualData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local GoldCostConfig = require(ReplicatedStorage.Shared.data.GoldCostConfig)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local PartyState = require(script.Parent.PartyState)
local PartyExpBonus = require(script.Parent.PartyExpBonus)
local PlayerProfile = require(script.Parent.PlayerProfile)
local HealCast = require(script.Parent.HealCast)
local CombatResolution = require(script.Parent.CombatResolution)

local P25aVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[P25a][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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
	return math.abs(a - b) <= (tolerance or 1e-9) * math.max(1, math.abs(b))
end

-- 그 스테이지에서 게임이 만드는 가장 큰 수치 후보(보스 6종 × 4인 HP · 공격 · 골드 · 경험치 · 잡몹 tier6 · 레벨 경험치 누적 - 레벨 = 스테이지로 보수적으로).
local function largestValue(stage)
	local largest = 0
	for id in pairs(BossData.bosses) do
		local data = BossRules.buildInstanceData(stage, id, PartyConfig.maxMembers)
		if data then
			largest = math.max(largest, data.hp, data.attack, data.goldDrop, data.expReward)
		end
	end
	largest = math.max(largest, InfiniteStage.getMonsterHp(MonsterData.tier6.hp, stage), InfiniteStage.getExpReward(MonsterData.tier6.expReward, stage), CharacterLevel.getExpForLevel(stage + 1))
	return largest
end

function P25aVerify.runPure()
	print("===P25a 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("[C1] k · 기준값 · 상한", function()
		local hp10 = InfiniteStage.getMonsterHp(MonsterData.tier1.hp, 10)
		r.check(("C1.1 k = %.3f(기대 1.02) · 스테이지 1 tier1 HP %.0f · 공격 %.0f · 골드 %.0f(기대 80 · 8 · 6 - 기준값 고정) · 스테이지 10 HP %.4f(기대 80 × 1.02^9 = %.4f)"):format(
			InfiniteStageConfig.growthRate, InfiniteStage.getMonsterHp(MonsterData.tier1.hp, 1), InfiniteStage.getMonsterAttack(MonsterData.tier1.attack, 1), InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, 1), hp10, 80 * 1.02 ^ 9),
			InfiniteStageConfig.growthRate == 1.02 and MonsterData.tier1.hp == 80 and MonsterData.tier1.attack == 8 and MonsterData.tier1.goldDrop == 6 and near(hp10, 80 * 1.02 ^ 9, 1e-12))
		local cap = InfiniteStageConfig.safeStageCap
		local atCap, afterCap = largestValue(cap), largestValue(cap + 1)
		r.check(("C1.2 안전 상한 %d: 최대 수치 %.3g < 1e300 · %d = %.3g ≥ 1e300(같은 정의를 새 k로)"):format(cap, atCap, cap + 1, afterCap), atCap < 1e300 and afterCap >= 1e300)
		local design = InfiniteStageConfig.designMaxStage
		local atDesign = largestValue(design)
		r.check(("C1.3 설계 최대 %d: 최대 수치(보스 4인 · 레벨 경험치 누적) %.3g < 1e250(R2)"):format(design, atDesign), atDesign < 1e250)
	end)

	r.section("[C1] 앵커", function()
		local classId = BalanceAnchorConfig.referenceClassId
		local cells, ok = {}, true
		for _, stage in ipairs({ 1000, 5000, 20000 }) do
			local loadout = BalanceSim.buildAnchorLoadout(classId, stage, 0)
			local hits = BalanceSim.getSurviveHits(loadout, BalanceSim.getMonsterAttack(stage))
			table.insert(cells, ("%d → %.4f"):format(stage, hits))
			ok = ok and math.abs(hits - BalanceAnchorConfig.surviveTargetHits) <= 0.02
		end
		r.check(("C1.4 생존 앵커(α %.6f · 최대체력 기준 %.4f): %s(기대 7.0 ± 0.02)"):format(CombatConfig.damageReductionAlpha, CombatConfig.maxHpBonusBase, table.concat(cells, " · ")), ok)
		local offset = BalanceSim.solveKillOffset()
		r.check(("C1.5 처치 앵커 오프셋 %.3f(반올림 = CharacterLevelConfig.levelStageOffset %d)"):format(offset, CharacterLevelConfig.levelStageOffset),
			math.floor(offset + 0.5) == CharacterLevelConfig.levelStageOffset)
	end)

	r.section("[C2 · C3] 무기 성장 · 경험치 · 환생", function()
		-- P2.5c 결정 1: 천장 = 구간 목록(weaponGrowthSegments - g = k^kShare). 첫 구간 전 = g · 각 구간 첫 레벨 → 다음 레벨 = k^몫.
		local segments = CharacterLevelConfig.weaponGrowthSegments
		local late = segments[1]
		local main = CharacterLevel.getWeaponExpMultiplier(101) / CharacterLevel.getWeaponExpMultiplier(100)
		local before = CharacterLevel.getWeaponExpMultiplier(late.fromLevel) / CharacterLevel.getWeaponExpMultiplier(late.fromLevel - 1)
		local segOk, cells = true, {}
		for _, segment in ipairs(segments) do
			local ratio = CharacterLevel.getWeaponExpMultiplier(segment.fromLevel + 1) / CharacterLevel.getWeaponExpMultiplier(segment.fromLevel)
			local expected = InfiniteStageConfig.growthRate ^ segment.kShare
			segOk = segOk and near(ratio, expected, 1e-12)
			table.insert(cells, ("%d→ %.6f(k^%.3f)"):format(segment.fromLevel, ratio, segment.kShare))
		end
		r.check(("C2.1 무기 계수 한 레벨 비: 100→101 %.6f(기대 g %.3f) · %d→%d %.6f(기대 g) · 구간 %d개 %s"):format(
			main, CharacterLevelConfig.weaponMultGrowthRate, late.fromLevel - 1, late.fromLevel, before, #segments, table.concat(cells, " · ")),
			near(main, CharacterLevelConfig.weaponMultGrowthRate, 1e-12) and near(before, CharacterLevelConfig.weaponMultGrowthRate, 1e-12) and segOk)
		local expOk = true
		for _, level in ipairs({ 1, 25, 100, 5000, 20000 }) do
			local expected = math.floor(CharacterLevel.getTargetKills(level) * math.floor(MonsterData.tier1.expReward * InfiniteStage.getMultiplier(level + CharacterLevelConfig.levelStageOffset)) + 0.5)
			expOk = expOk and CharacterLevel.getExpToNextLevel(level) == expected
		end
		r.check(("C3.1 필요 경험치 = round(K(L) × 스테이지 L + %d의 tier1 경험치) %s"):format(CharacterLevelConfig.levelStageOffset, tostring(expOk)), expOk)
		-- 이분 탐색(getLevelFromExp) = 1부터 세는 옛 반복과 같은 레벨(무작위 누적 경험치 400개 · 레벨 1 ~ 3000)
		local rng = Random.new(20260923)
		local mismatch = 0
		for _ = 1, 400 do
			local target = rng:NextInteger(1, 3000)
			local exp = CharacterLevel.getExpForLevel(target) + rng:NextNumber() * CharacterLevel.getExpToNextLevel(target) * 0.999
			local linear = 1
			while exp >= CharacterLevel.getExpForLevel(linear + 1) do
				linear += 1
			end
			if CharacterLevel.getLevelFromExp(exp) ~= linear then
				mismatch += 1
			end
		end
		r.check(("C3.2 getLevelFromExp(두 배 + 이분 탐색) = 옛 반복: 400개 중 어긋남 %d(기대 0) · inf → %d(끝난다)"):format(mismatch, CharacterLevel.getLevelFromExp(math.huge)), mismatch == 0)
		local levels = {}
		for count = 0, 4 do
			levels[count + 1] = CharacterLevel.getRebirthRequiredLevel(count)
		end
		-- P2.5c 결정 3: 필요 레벨 25 · 50 · 75 · 100 · 125(사용자 확정 - 옛 P2.5a 78 · 155 · 202 · 248 · 279). 스테이지 척도(레벨 + 167)는 그대로.
		r.check(("C3.3 환생 필요 레벨 %s(기대 25 · 50 · 75 · 100 · 125 - P2.5c) · 레벨 125의 스테이지 척도 %d(기대 292)"):format(table.concat(levels, " · "), CharacterLevel.getStageForLevel(125)),
			table.concat(levels, ",") == "25,50,75,100,125" and CharacterLevel.getStageForLevel(125) == 292)
	end)

	r.section("[C5] 강화 +30", function()
		local total = Enhance.getTotalMultiplier(30)
		r.check(("C5.1 최대 %d · +30 누적 %.9f(기대 20) · 공격력 몫 %.6f · 최종 데미지 몫 +%.3f(기대 +1.05) · 한 단계 공격력 ×%.5f(기대 ≈ 1.0789)"):format(
			EnhanceConfig.maxLevel, total, Enhance.getDamageMultiplier(30), Enhance.getFinalDamageBonus(30), 1 + EnhanceConfig.attackGrowthPerLevel),
			EnhanceConfig.maxLevel == 30 and near(total, 20, 1e-9) and near(Enhance.getFinalDamageBonus(30), 1.05, 1e-12) and math.abs(EnhanceConfig.attackGrowthPerLevel - 0.0789) < 0.0005)
		local rowsOk = #EnhanceConfig.probability == 30 and #EnhanceConfig.goldCost == 30 and Enhance.getCost(30) == nil and Enhance.getCost(29) ~= nil
		local monotone = true
		for level = 1, 29 do
			monotone = monotone and Enhance.getCost(level) > Enhance.getCost(level - 1)
		end
		local matsOk = true
		for level = 25, 29 do
			matsOk = matsOk and EnhanceMaterialData.costByLevel[level] ~= nil
		end
		local visual30 = false
		for _, step in ipairs(EnhanceVisualData.steps) do
			if step.level == 30 and step.title and step.title.text == "+30" then
				visual30 = true
			end
		end
		r.check(("C5.2 확률표 · 비용표 30행 %s · 비용 단조 증가 %s · 25 ~ 29강 재료 %s · +30 칭호 %s · 25 ~ 29강 실패 = 하락 + 초기화(최악 단계 = %d)"):format(
			tostring(rowsOk), tostring(monotone), tostring(matsOk), tostring(visual30), Enhance.getWorstLevel(29)),
			rowsOk and monotone and matsOk and visual30 and Enhance.getWorstLevel(29) == EnhanceConfig.resetToLevel)
		local weapon0 = { id = WeaponData.starterId, level = 0, grade = 0 }
		local weapon30 = { id = WeaponData.starterId, level = 30, grade = 0 }
		local ratio = PlayerCombat.getAttack(weapon30, "greatsword", 100, 0) / PlayerCombat.getAttack(weapon0, "greatsword", 100, 0)
		local withOption = PlayerCombat.getAttack(weapon30, "greatsword", 100, 0, 0.5) / PlayerCombat.getAttack(weapon30, "greatsword", 100, 0)
		r.check(("C5.3 공격력(최종 데미지 버킷 포함) +30 ÷ +0 = %.9f(기대 20) · 옵션 최종 데미지 +50%% → ×%.6f(기대 (1 + 1.05 + 0.5) ÷ 2.05 = %.6f - 합연산)"):format(ratio, withOption, 2.55 / 2.05),
			near(ratio, 20, 1e-9) and near(withOption, 2.55 / 2.05, 1e-12))
	end)

	r.section("[C6 · C8 · C9 · C10] 등급 · 골드 · 태초 · 보석", function()
		local ok = true
		for i = 2, #ArmorData.gradeOrder do
			local a, b = ArmorData.gradeOrder[i - 1], ArmorData.gradeOrder[i]
			ok = ok and near(ItemVisualData.gradeVisuals[b].statMultiplier / ItemVisualData.gradeVisuals[a].statMultiplier, 1.45, 1e-12)
				and near(ArmorData.grades[b].defenseGradeMultiplier / ArmorData.grades[a].defenseGradeMultiplier, 1.45, 1e-12)
		end
		r.check(("C6 등급 1단계 ×1.45(무기 · 장갑 · 신발 · 옵션 표와 갑옷 표 모두) %s · 일반 1.0 · 갑옷 일반 %.3f · 태초 %.4f · tier6 r %.4f"):format(tostring(ok), ArmorData.grades.normal.defenseGradeMultiplier,
			ItemVisualData.gradeVisuals.primordial.statMultiplier, MonsterData.getRewardRatio(6)), ok and ItemVisualData.gradeVisuals.normal.statMultiplier == 1 and ArmorData.grades.normal.defenseGradeMultiplier == 1.184)
		local goldOk = InfiniteStage.getGoldReward(6, 1000) == math.floor(6 * InfiniteStageConfig.goldGrowthRate ^ 999) and GoldCostConfig.anchorStage.enhance == 1
		local ratio = Enhance.getCost(20, 5001) / Enhance.getCost(20, 5000)
		r.check(("C8 골드 성장률 %.3f · 잡몹 골드(스테이지 1000) = floor(6 × 1.001^999) %s · 강화 비용 기준 1 · 한 스테이지 비용 비 %.6f(기대 = 골드 성장률)"):format(
			InfiniteStageConfig.goldGrowthRate, tostring(goldOk), ratio), goldOk and near(ratio, InfiniteStageConfig.goldGrowthRate, 1e-6))
		r.check(("C10 보석 곡선 p = %.3f(기대 0.025)"):format(OptionData.levelLogSlope), OptionData.levelLogSlope == 0.025)
	end)

	r.section("[D] P2 결정 5 · 8 · 10(순수)", function()
		local crits = 0
		for _ = 1, 200 do
			crits += HealCast.rollCrit(100, "healer", 1) and 1 or 0
		end
		r.check(("D5 치유 치명 굴림에 옵션 치명 확률 +100%% → 200번 중 치명 %d(기대 200)"):format(crits), crits == 200)
		local scaling = SkillData.healer.E.investmentScaling
		local average = PlayerCombat.getInvestmentScale(scaling.average.enhance, scaling.average.attackPercent, scaling)
		local top = PlayerCombat.getInvestmentScale(scaling.top.enhance, scaling.top.attackPercent, scaling)
		local none = PlayerCombat.getInvestmentScale(0, 0, scaling)
		r.check(("D8 딜링모드 투자 기울기: 평균 %.6f(기대 1) · 최상위 %.6f(기대 HealerTopScale ÷ 기울기 없는 최상위 비 = %.6f) · 투자 없음 %.4f(기대 하한 %s) · 기울기 없는 버프 = %s(기대 1)"):format(
			average, top, scaling.topScale / scaling.unscaledTopRatio, none, tostring(scaling.floor), tostring(PlayerCombat.getInvestmentScale(30, 1, nil))),
			near(average, 1, 1e-12) and near(top, scaling.topScale / scaling.unscaledTopRatio, 1e-9) and none == scaling.floor and PlayerCombat.getInvestmentScale(30, 1, nil) == 1)
		local stand = { Name = "P25aStand", UserId = -9801 }
		local fakeTarget = {}
		local beforeActivity = PartyState.getLastActivity(stand)
		CombatResolution.resolveHit(stand, fakeTarget, false)
		local afterActivity = PartyState.getLastActivity(stand)
		r.check(("D10 명중(CombatResolution.resolveHit, 안 죽음)이 활동을 남긴다: 전 %s → 후 %s"):format(tostring(beforeActivity), tostring(afterActivity)), beforeActivity == nil and afterActivity ~= nil)
	end)

	local pass, total = r.summary()
	print(("===P25a 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ── (나) ──

local function standIn(name, userId)
	return { Name = name, UserId = userId, Parent = workspace, Character = nil }
end

function P25aVerify.runLive(player, env)
	print("===P25a 검증 시작(나: 실제 Player · 파티 칩 · 명중 활동 · 환생 보석 · 강화 공격력)===")
	local r = newRecorder("나")
	local character = player.Character
	if not PlayerProfile.getProfile(player) or not (character and character:FindFirstChild("HumanoidRootPart")) or PartyState.getParty(player) then
		r.check("프로필 · 캐릭터가 없거나 이미 파티에 있어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===P25a 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end
	env.ensureBackup(player) -- 경험치 · 환생 · 무기(보석) · 스테이지는 env.restore가 되돌린다
	local B = standIn("P25aStandB", -9811)

	r.section("[D7] 파티 칩 = 실제 적용 보너스", function()
		PartyState.invite(player, B)
		PartyState.respondInvite(B, true)
		local zone = "P25a-verify-zone"
		PartyExpBonus.debugSetPresence(player, { zone = zone, position = Vector3.new(0, 0, 0) })
		PartyExpBonus.debugSetPresence(B, { zone = zone, position = Vector3.new(10, 0, 0) })
		PartyState.noteActivity(B)
		PlayerProfile.getExpGainMultiplier(player)
		local near1 = player:GetAttribute("PartyExpBonus")
		PartyExpBonus.debugSetPresence(B, { zone = zone, position = Vector3.new(500, 0, 0) })
		PlayerProfile.getExpGainMultiplier(player)
		local far = player:GetAttribute("PartyExpBonus")
		PartyState.pushState(PartyState.getParty(player))
		local pushed = player:GetAttribute("PartyExpBonus")
		r.check(("D7 2인 파티: 조건 충족 칩 %s(기대 %.2f) · 파티원이 반경 밖 칩 %s(기대 0 - 옛 규칙은 인원 보너스 %.2f) · 파티 알림 뒤 칩 %s(기대 0)"):format(
			tostring(near1), PartyConfig.expBonusByMemberCount[2], tostring(far), PartyConfig.expBonusByMemberCount[2], tostring(pushed)),
			near1 ~= nil and near(near1, PartyConfig.expBonusByMemberCount[2], 1e-12) and far == 0 and pushed == 0)
		PartyExpBonus.debugSetPresence(player, nil)
		PartyExpBonus.debugSetPresence(B, nil)
		PartyState.leave(B, "leave")
		if PartyState.getParty(player) then
			PartyState.leave(player, "leave")
		end
	end)

	r.section("[D9] 환생 지급 보석 itemLevel = 환생 순간 레벨의 스테이지 척도", function()
		local classState = PlayerProfile.getProfile(player).classes[PlayerProfile.getClassId(player)]
		local count = classState.rebirthCount
		if count >= GemData.maxRebirthCount then
			r.check(("D9 건너뜀 - 이미 환생 %d회(최대)"):format(count), true)
			return
		end
		local required = CharacterLevel.getRebirthRequiredLevel(count)
		local level = required + 7
		PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(level))
		local ok, reason = PlayerProfile.rebirth(player)
		local gem = classState.weapon.gems[count + 1]
		r.check(("D9 환생 %d → %d(레벨 %d): 결과 %s%s · 지급 보석 itemLevel %s(기대 %d = 레벨 + %d)"):format(count, count + 1, level, tostring(ok), reason and (" " .. tostring(reason)) or "",
			gem and tostring(gem.itemLevel) or "없음", level + CharacterLevelConfig.levelStageOffset, CharacterLevelConfig.levelStageOffset),
			ok == true and type(gem) == "table" and gem.itemLevel == level + CharacterLevelConfig.levelStageOffset)
	end)

	r.section("[D10 · R5] 실제 명중 활동 · +30 공격력", function()
		local MonsterSpawner = require(script.Parent.MonsterSpawner)
		local MonsterState = require(script.Parent.MonsterState)
		local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
		local spot = WorldConfig.zones[WorldConfig.tierZoneOrder[1]].center + Vector3.new(0, 5, 0)
		local model = MonsterSpawner.spawn(MonsterData.tier1, spot, nil, {})
		local before = PartyState.getLastActivity(player) or -1
		task.wait(0.05)
		local isDead = MonsterState.applyDamage(model, 1, 1, player)
		CombatResolution.resolveHit(player, model, isDead)
		local after = PartyState.getLastActivity(player) or -1
		r.check(("D10 실제 잡몹에 명중(안 죽음) → 활동 시각 %.3f → %.3f(기대 늘어남)"):format(before, after), after > before and not isDead)
		MonsterState.clear(model)
		if model.Parent then
			model:Destroy()
		end
		local weapon = PlayerProfile.getWeapon(player)
		local savedLevel = weapon.level
		weapon.level = 0
		local classId, level = PlayerProfile.getClassId(player), PlayerProfile.getCharacterLevel(player)
		local base = PlayerCombat.getAttack(weapon, classId, level, PlayerProfile.getAttackPercentBonus(player), PlayerProfile.getOptionBonus(player, "finalDamage"))
		weapon.level = 30
		local top = PlayerCombat.getAttack(weapon, classId, level, PlayerProfile.getAttackPercentBonus(player), PlayerProfile.getOptionBonus(player, "finalDamage"))
		weapon.level = savedLevel
		r.check(("R5 실제 무기(AttackServer와 같은 인자) +30 ÷ +0 = %.9f(기대 20)"):format(top / base), near(top / base, 20, 1e-9))
	end)

	-- 되돌리기
	PartyExpBonus.debugSetPresence(player, nil)
	PartyExpBonus.debugSetPresence(B, nil)
	if PartyState.getParty(B) then
		PartyState.leave(B, "leave")
	end
	if PartyState.getParty(player) then
		PartyState.leave(player, "leave")
	end
	env.restore(player)
	r.check(("검증 뒤 되돌림: 파티 %s · 스탠드인 파티 %s(기대 nil · nil)"):format(tostring(PartyState.getParty(player)), tostring(PartyState.getParty(B))),
		PartyState.getParty(player) == nil and PartyState.getParty(B) == nil)

	local pass, total = r.summary()
	print(("===P25a 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return P25aVerify
