-- S13 자동 검증(PRD 20.81 [B-1] · [B-2] · [B-3] 파티 회복 · [C-5]) - 밸런스 결정 반영.
--   (가) 순수 함수 - 서버 시작 때(플레이어 없이): 4직업 앵커 로테이션 DPS(대검 615.5 · 쌍검 812.4 · 활 789.3 ±1%) · 쌍검 ÷ 대검 ≤ 1.322 · 서열 · 활 기준 앵커 · p · b 불변 ·
--     딜링모드 기존 세 줄(0.5992 · 0.6775 · 0.7258) · 보스전(회복률 0) 두 줄(기록용) · 직업 특화 옵션 색 데이터(ItemDescribe · classAccent).
--   (나) 실제 Player + 스탠드인 파티 - 보스 검증 체인의 끝에서: 파티 회복 실제 경로(HealCast.cast) 7 ~ 13번.
-- env = { ensureBackup, restore, applyOptionStack } - DevTools의 로컬 헬퍼. 검증이 바꾼 것(파티 · 옵션 · HP · 버프)은 (나)가 끝날 때 전부 되돌린다.
--
-- (나)의 멤버 자리: Studio에는 실제 Player가 한 명뿐이라 두 방향으로 짠다. (B) 실제 Player = 힐러, 스탠드인(테이블 - HP는 PlayerState 함수로 읽는다) = 멤버 - 7 · 8 · 9 · 11.
-- (A) 스탠드인 = 힐러(프로필이 없어 재생 배수 1), 실제 Player = 멤버(재생 옵션 +100%를 붙여 둔다) - 12번(멤버의 재생 옵션은 영향 없음) · FireClient 실제 발신 · 버프 13번.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local BuffState = require(script.Parent.BuffState)
local HealCast = require(script.Parent.HealCast)
local PartyState = require(script.Parent.PartyState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local TutorialState = require(script.Parent.TutorialState)

local BalanceDecisionVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S13][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function near(value, expected, tolerance)
	return math.abs(value - expected) <= tolerance
end

-- /gg anchor <직업>과 같은 조건(레벨 100 · 무기 등급 0 · 일반 등급 장비)의 60초 로테이션 총딜 ÷ 무기 기본 atk(atk-단위 - 20.44 [1] 표와 같은 눈금).
local function anchorRotationUnits(classId)
	local loadout = BalanceSim.buildAnchorLoadout(classId, BalanceAnchorConfig.referenceLevel, 0)
	local total = BalanceSim.simulateCombat(loadout, { useSkills = true }).totalDamage
	return total / (loadout.atk / loadout.class.atk)
end

function BalanceDecisionVerify.runPure()
	print("===S13 검증 시작(가)===")
	local r = newRecorder("가")

	local dps = {}
	r.section("[1] 앵커 로테이션 DPS", function()
		for _, classId in ipairs({ "greatsword", "dualblade", "bow", "healer" }) do
			dps[classId] = anchorRotationUnits(classId)
		end
		print(("[S13][가][측정] 앵커(레벨 100 · 등급 0) 60초 로테이션 총딜(atk-단위): 대검 %.1f · 쌍검 %.1f · 활 %.1f · 힐러(딜링모드 100%% 가동) %.1f"):format(
			dps.greatsword, dps.dualblade, dps.bow, dps.healer))
		r.check(("1 대검 %.1f(기대 615.5 ± 1%%) · 쌍검 %.1f(기대 812.4 ± 1%%) · 활 %.1f(기대 789.3 ± 1%%)"):format(dps.greatsword, dps.dualblade, dps.bow),
			near(dps.greatsword, 615.5, 615.5 * 0.01) and near(dps.dualblade, 812.4, 812.4 * 0.01) and near(dps.bow, 789.3, 789.3 * 0.01))
		local ratio = dps.dualblade / dps.greatsword
		r.check(("2 쌍검 ÷ 대검 = %.4f(기대 ≤ 1.322 - 1.32 규칙 + 허용 오차 0.002) ★진짜 합격 기준"):format(ratio), ratio <= 1.322)
		r.check(("3 서열 쌍검 %.1f > 활 %.1f > 대검 %.1f ★진짜 합격 기준"):format(dps.dualblade, dps.bow, dps.greatsword), dps.dualblade > dps.bow and dps.bow > dps.greatsword)
	end)

	r.section("[4] 활 기준 앵커 · p · b 불변", function()
		-- 처치 시간은 타수(정수)로 정해지는 계단 함수라 rec 스테이지(이분법이 찾은 경계)에서 정확히 2.5초가 나오지 않는다 - 경계 양쪽이 목표를 사이에 끼는지로 잰다.
		local offset = BalanceSim.solveKillOffset()
		local stage = BalanceAnchorConfig.referenceLevel + offset
		local bowLoadout = BalanceSim.buildAnchorLoadout(BalanceAnchorConfig.referenceClassId, BalanceAnchorConfig.referenceLevel, 0)
		local point = BalanceSim.measurePoint(bowLoadout, stage)
		local below = BalanceSim.measurePoint(bowLoadout, stage - 0.05).killRotationSeconds
		local above = BalanceSim.measurePoint(bowLoadout, stage + 0.05).killRotationSeconds
		local target = BalanceAnchorConfig.killTargetSeconds
		local p = BossRules.partyHpExponent()
		local b = PartyConfig.healerBuffFraction
		r.check(("4 활 앵커(rec 스테이지 %.2f = 레벨 100 + 오프셋 %+.3f): 생존 %.3f타(기대 7 ± 0.02) · 처치(로테이션) 경계 %.3f초 < %.1f ≤ %.3f초(기대 경계가 목표를 낀다) · 오프셋 |%.3f| ≤ 0.1 · 보스 p %.4f(기대 0.4803 ± 0.001) · 힐러 b %.5f(기대 0.01289 ± 0.0001) - 전부 이 세션 전 문서값 그대로"):format(
			stage, offset, point.surviveHits, below, target, above, offset, p, b),
			near(point.surviveHits, BalanceAnchorConfig.surviveTargetHits, 0.02) and below < target and above >= target and math.abs(offset) <= 0.1
				and near(p, 0.4803, 0.001) and near(b, 0.01289, 0.0001))
		-- 참고(합격 조건 아님): b는 r = 힐러 실효 DPS ÷ 대검 DPS(PartyConfig 주석 · 24-4)에서 나왔다. 대검이 598.6 → 615.5로 올랐으므로 같은 식의 r · b를 다시 적어 둔다.
		if dps.greatsword and dps.healer then
			local healerEffective = dps.healer * BalanceSim.simulateHealerCycle({ hitsPerSecond = 0.25, hitRatio = 0.1026 }).uptime
			local rNow = healerEffective / dps.greatsword
			local bNow = PartyConfig.maxMembers / (PartyConfig.maxMembers - 1 + rNow) - 1
			print(("[S13][가][참고] r = 힐러 실효 %.1f ÷ 대검 %.1f = %.4f(PartyConfig.healerDpsRatio %.4f) → 같은 식의 b = %.5f(PartyConfig.healerBuffFraction %.5f) - 값은 안 바꾼다(PRD 20.98 미결)"):format(
				healerEffective, dps.greatsword, rNow, PartyConfig.healerDpsRatio, bNow, PartyConfig.healerBuffFraction))
		end
	end)

	r.section("[5][6] 딜링모드 가동률", function()
		local baseDrain = SkillData.healer.E.drainPercentPerSecond
		local hitParams = { hitsPerSecond = 0.25, hitRatio = 0.1026 }
		local function uptime(drain, regenPerSecond)
			return BalanceSim.simulateHealerCycle({ hitsPerSecond = hitParams.hitsPerSecond, hitRatio = hitParams.hitRatio, drainPerSecond = drain, regenPerSecond = regenPerSecond }).uptime
		end
		local reducedDrain = baseDrain * (1 + OptionData.options.skill_healer_E.baseValue)
		local cappedDrain = baseDrain * (1 - OptionData.options.skill_healer_E.cap)
		local base, reduced, capped = uptime(baseDrain), uptime(reducedDrain), uptime(cappedDrain)
		r.check(("5 딜링모드 기존 세 줄(회복률 기본): %.4f · %.4f · %.4f(기대 0.5992 · 0.6775 · 0.7258 그대로 - 회복률 인자 기본값이 지금 값)"):format(base, reduced, capped),
			near(base, 0.5992, 0.0005) and near(reduced, 0.6775, 0.0005) and near(capped, 0.7258, 0.0005))
		local a0, a1 = uptime(baseDrain, 0), uptime(reducedDrain, 0)
		r.check(("6 딜링모드 보스전(회복률 0) 두 줄(기록용 - 합격 조건 없음): drain %.4f → a0 %.4f · drain %.4f(옵션 -60%%) → a1 %.4f · 환산 a1 ÷ a0 - 1 = %+.1f%%"):format(
			baseDrain, a0, reducedDrain, a1, (a1 / a0 - 1) * 100), a0 > 0 and a1 > 0)
	end)

	r.section("[14] 데이터: 치유 파티 회복 · 대검 계수 · 옵션 색", function()
		local healQ, gsQ, gsE = SkillData.healer.Q, SkillData.greatsword.Q, SkillData.greatsword.E
		r.check(("14 데이터: healer.Q.partyHeal %s(기대 true) · healPercentOfMaxHp %.2f(기대 0.30 그대로) · 대검 Q %.1f(기대 7.6) · E %.1f(기대 8.2)"):format(
			tostring(healQ.partyHeal), healQ.healPercentOfMaxHp, gsQ.coefficient, gsE.coefficient),
			healQ.partyHeal == true and healQ.healPercentOfMaxHp == 0.3 and gsQ.coefficient == 7.6 and gsE.coefficient == 8.2)

		local missing = {}
		for optionId, def in pairs(OptionData.options) do
			if def.classId and UIColors.classAccent[def.classId] == nil then
				table.insert(missing, optionId)
			end
		end
		table.sort(missing)
		r.check(("15 직업 특화 옵션 8종의 classId가 모두 UIColors.classAccent에 있다: 빠진 옵션 %d개 [%s](기대 0)"):format(#missing, table.concat(missing, ",")), #missing == 0)

		local function line(optionId, classId)
			local item = { grade = "primordial", part = "gloves", itemLevel = 100, dropStage = 100, option = { id = optionId, roll = 1.0, roll2 = 1.0 } }
			return ItemDescribe.item(item, classId).options[1]
		end
		local match, mismatch, common, crit = line("skill_bow_Q", "bow"), line("skill_bow_Q", "healer"), line("attackPercent", "bow"), line("crit", "bow")
		r.check(("16 ItemDescribe 옵션 줄의 색 신호: 내 직업과 맞는 특화 → accentClassId %s(기대 bow) · dim %s(기대 false) / 불일치 → accentClassId %s(기대 nil) · dim %s(기대 true - 회색이 우선) / 공통 → %s(기대 nil) / 치명 → %s(기대 nil)"):format(
			tostring(match.accentClassId), tostring(match.dim), tostring(mismatch.accentClassId), tostring(mismatch.dim), tostring(common.accentClassId), tostring(crit.accentClassId)),
			match.accentClassId == "bow" and match.dim == false and mismatch.accentClassId == nil and mismatch.dim == true and common.accentClassId == nil and crit.accentClassId == nil)
	end)

	local pass, total = r.summary()
	print(("===S13 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ═══ (나) ═══

local function standIn(name, userId)
	return { Name = name, UserId = userId, Parent = workspace, Character = nil }
end

local function setHpFraction(who, fraction)
	local maxHp = PlayerState.getMaxHp(who)
	PlayerState.setHp(who, maxHp * fraction)
	if typeof(who) == "Instance" then
		who:SetAttribute("Hp", maxHp * fraction)
	end
end

local function hpFraction(who)
	return PlayerState.getHp(who) / PlayerState.getMaxHp(who)
end

local function leaveAll(...)
	for _, who in ipairs({ ... }) do
		if PartyState.getParty(who) then
			PartyState.leave(who, "leave")
		end
	end
end

function BalanceDecisionVerify.runLive(player, env)
	print("===S13 검증 시작(나: 실제 castHeal 경로 · 실제 Player + 스탠드인 파티)===")
	local r = newRecorder("나")
	if not PlayerProfile.getProfile(player) or not PlayerState.getMaxHp(player) then
		r.check("프로필 또는 HP 상태가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S13 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end
	if PartyState.getParty(player) or TutorialState.isActive(player) then
		r.check("이미 파티에 있거나 견습 진행 중이라 검증을 건너뜀(파티를 나가고 견습을 끝낸 뒤 다시)", false)
		local pass, total = r.summary()
		print(("===S13 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player)
	local def = SkillData.healer.Q
	local cooldown = def.cooldownSeconds
	local savedHp = PlayerState.getHp(player)
	local member = standIn("S13Member", -9501)
	local healerStandIn = standIn("S13Healer", -9502)
	local memberMax = PlayerState.getMaxHp(player) * 2.5 -- 힐러와 다른 최대체력 - "받는 사람 자신의 최대체력 기준"을 가른다
	PlayerState.init(member)
	PlayerState.setMaxHp(member, memberMax)
	PlayerState.init(healerStandIn)

	-- 옵션을 재생 0인 기준 빌드로 바꾼 뒤 시작한다(개발 계정의 장비 옵션이 기대값을 흔들지 않게).
	env.applyOptionStack(player, "attackPercent")
	local baseMultiplier = PlayerProfile.getHealingPowerMultiplier(player)

	r.section("[7] 멤버 HP 45% → 45% + 30% × 재생 배수(치명이면 ×2) · 상한 100%", function()
		PartyState.create(player)
		PartyState.attachMember(PartyState.getParty(player), member)
		local allOk, crits, casts, lines = true, 0, 8, {}
		for _ = 1, casts do
			setHpFraction(member, 0.45)
			setHpFraction(player, 0.5)
			local ok, healAmount, isCrit, healed = pcall(HealCast.cast, player, def, "healer", cooldown)
			local expected = math.min(0.45 + def.healPercentOfMaxHp * baseMultiplier * (isCrit and def.critHealMultiplier or 1), 1)
			local memberOk = ok and near(hpFraction(member), expected, 1e-6) and #healed == 1 and healed[1] == member
			allOk = allOk and memberOk
			crits += isCrit and 1 or 0
			table.insert(lines, ("%s→%.2f(기대 %.2f)"):format(isCrit and "치명" or "일반", ok and hpFraction(member) or -1, expected))
		end
		r.check(("7 실제 HealCast 경로 %d회(치명 %d회): %s · 재생 배수 %.2f ★진짜 합격 기준(45%% → 75%%)"):format(casts, crits, table.concat(lines, " · "), baseMultiplier), allOk)
	end)

	r.section("[8] 더미 · 스탠드인이 낀 파티: 에러 0 · FireClient 시도 없음", function()
		local ok, added = PartyState.addDummies(player, 2, function(index)
			return { classId = ClassData.order[(index - 1) % #ClassData.order + 1], level = 1, stage = 1, hp = 1, maxHp = 1 }
		end)
		local party = PartyState.getParty(player)
		setHpFraction(member, 0.45)
		local castOk, healAmount, isCrit, healed = pcall(HealCast.cast, player, def, "healer", cooldown)
		local expected = math.min(0.45 + def.healPercentOfMaxHp * baseMultiplier * (isCrit and def.critHealMultiplier or 1), 1)
		r.check(("8 더미 %s명 + 스탠드인 1명 파티(인원 %s · 실제 Player 표 %d개 - 더미는 안 들어온다): 에러 없음=%s · 회복 받은 멤버 %s명(기대 1 - 스탠드인만) · 스탠드인 HP %.2f(기대 %.2f, PlayerState로 읽음) ★진짜 합격 기준"):format(
			tostring(added), tostring(party and PartyState.getSize(party)), #PartyState.getMemberPlayers(party), tostring(castOk), castOk and tostring(#healed) or "-",
			hpFraction(member), expected), ok and added == 2 and castOk and #healed == 1 and near(hpFraction(member), expected, 1e-6))
		PartyState.clearDummies(player)
	end)

	r.section("[9] 죽은 멤버(HP 0)는 회복하지 않는다", function()
		PlayerState.setHp(member, 0)
		local castOk, _, _, healed = pcall(HealCast.cast, player, def, "healer", cooldown)
		r.check(("9 HP 0 멤버: 에러 없음=%s · 회복 받은 멤버 %s명(기대 0) · HP %.2f(기대 0)"):format(tostring(castOk), castOk and tostring(#healed) or "-", PlayerState.getHp(member)),
			castOk and #healed == 0 and PlayerState.getHp(member) == 0)
		leaveAll(member, player)
	end)

	r.section("[10] 솔로 힐러", function()
		BuffState.clear(player, "healerBuff") -- 앞의 파티 시전([7] · [8])이 실제 Player인 힐러 자신에게 남긴 버프를 먼저 치운다 - 솔로 시전이 새로 거는지를 보려는 것
		setHpFraction(player, 0.45)
		local castOk, healAmount, isCrit, healed = pcall(HealCast.cast, player, def, "healer", cooldown)
		local expected = math.min(0.45 + def.healPercentOfMaxHp * baseMultiplier * (isCrit and def.critHealMultiplier or 1), 1)
		r.check(("10 솔로: 파티 %s(기대 nil) · 에러 없음=%s · 회복 받은 멤버 %s명(기대 0 - 이벤트 0) · 자기 HP %.2f(기대 %.2f = 자기만) · 버프 %s(기대 nil - 솔로 자기 버프 차단)"):format(
			tostring(PartyState.getParty(player)), tostring(castOk), castOk and tostring(#healed) or "-", hpFraction(player), expected, tostring(BuffState.get(player, "healerBuff"))),
			PartyState.getParty(player) == nil and castOk and #healed == 0 and near(hpFraction(player), expected, 1e-6) and BuffState.get(player, "healerBuff") == nil)
	end)

	r.section("[11] 힐러의 재생 옵션 +100% → 멤버 +60%", function()
		local okStack = env.applyOptionStack(player, "healingPower")
		local multiplier = PlayerProfile.getHealingPowerMultiplier(player)
		PartyState.create(player)
		PartyState.attachMember(PartyState.getParty(player), member)
		local allOk, lines = okStack and near(multiplier, 2, 1e-6), {}
		for _ = 1, 4 do
			setHpFraction(member, 0.2)
			setHpFraction(player, 0.5)
			local castOk, _, isCrit, healed = pcall(HealCast.cast, player, def, "healer", cooldown)
			local expected = math.min(0.2 + def.healPercentOfMaxHp * multiplier * (isCrit and def.critHealMultiplier or 1), 1)
			allOk = allOk and castOk and near(hpFraction(member), expected, 1e-6) and #healed == 1
			table.insert(lines, ("%s→%.2f(기대 %.2f)"):format(isCrit and "치명" or "일반", castOk and hpFraction(member) or -1, expected))
		end
		r.check(("11 재생 +100%%(배수 %.2f · 적용 %s): 20%% 멤버 → %s(일반 +60%% · 치명 +120%%)"):format(multiplier, tostring(okStack), table.concat(lines, " · ")), allOk)
		leaveAll(member, player)
	end)

	r.section("[12][13] 멤버의 재생 옵션은 영향 없음 · 치유 버프는 그대로", function()
		-- (A) 스탠드인 힐러(재생 배수 1 - 프로필 없음) + 실제 Player 멤버(위에서 재생 +100%를 붙여 둔 상태 - 그 배수 2가 곱해지면 X).
		local memberMultiplier = PlayerProfile.getHealingPowerMultiplier(player)
		BuffState.clear(player, "healerBuff")
		PartyState.create(healerStandIn)
		PartyState.attachMember(PartyState.getParty(healerStandIn), player)
		setHpFraction(player, 0.2)
		local castOk, _, isCrit, healed = pcall(HealCast.cast, healerStandIn, def, "healer", cooldown)
		local expected = math.min(0.2 + def.healPercentOfMaxHp * 1 * (isCrit and def.critHealMultiplier or 1), 1)
		local hp = hpFraction(player)
		local attributeSynced = near((player:GetAttribute("Hp") or -1) / PlayerState.getMaxHp(player), hp, 1e-6)
		r.check(("12 멤버(실제 Player)의 재생 배수 %.2f · 힐러 배수 1: 20%% → %.2f(기대 %.2f = 힐러 배수만 · %s) · 에러 없음=%s · 받은 멤버 %s명(기대 1) · Hp Attribute 동기화=%s"):format(
			memberMultiplier, hp, expected, isCrit and "치명" or "일반", tostring(castOk), castOk and tostring(#healed) or "-", tostring(attributeSynced)),
			memberMultiplier > 1.5 and castOk and near(hp, expected, 1e-6) and #healed == 1 and healed[1] == player and attributeSynced)
		local buff = BuffState.get(player, "healerBuff")
		local remaining = buff and buff.expiresAt and (buff.expiresAt - os.clock()) or -1
		r.check(("13 치유 버프: 실제 Player 멤버에게 걸림=%s · 배율 %.4f(기대 %.4f = 1 + b) · 남은 시간 %.1f초(기대 %.1f = 쿨다운 %d × %.1f)"):format(
			tostring(buff ~= nil), buff and buff.multiplier or 0, 1 + PartyConfig.healerBuffFraction, remaining, cooldown * def.partyBuffDurationMultiplier, cooldown, def.partyBuffDurationMultiplier),
			buff ~= nil and near(buff.multiplier, 1 + PartyConfig.healerBuffFraction, 1e-9) and near(remaining, cooldown * def.partyBuffDurationMultiplier, 1))
	end)

	-- 되돌리기: 파티 · 버프 · 스탠드인 상태 · 옵션 · HP.
	leaveAll(player, healerStandIn, member)
	BuffState.clear(player, "healerBuff")
	PlayerState.clear(member)
	PlayerState.clear(healerStandIn)
	env.restore(player)
	PlayerState.setHp(player, savedHp)
	player:SetAttribute("Hp", savedHp)
	r.check(("정리: 파티 %s(기대 nil) · 치유 버프 %s(기대 nil) · 옵션 복원 재생 배수 %.2f(기대 시작 전 원래 값) · 스탠드인 HP 상태 %s %s(기대 nil nil)"):format(
		tostring(PartyState.getParty(player)), tostring(BuffState.get(player, "healerBuff")), PlayerProfile.getHealingPowerMultiplier(player),
		tostring(PlayerState.getHp(member)), tostring(PlayerState.getHp(healerStandIn))),
		PartyState.getParty(player) == nil and BuffState.get(player, "healerBuff") == nil and PlayerState.getHp(member) == nil and PlayerState.getHp(healerStandIn) == nil)

	local pass, total = r.summary()
	print(("===S13 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return BalanceDecisionVerify
