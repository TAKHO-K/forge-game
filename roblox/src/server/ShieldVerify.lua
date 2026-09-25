-- S13b 자동 검증(힐러 딜링모드 쉴드). PRD 20.99.
--   (가) 순수 - 서버 시작 때(플레이어 없이): 층 순서 · 다 깎인 층 제거 · 만료 제거 · 3 · 4번째 층 반감 · 5겹째 거절 · 같은 시전자 교체 · 데이터(가동률 초안) ·
--     공통 피해 함수(PlayerDamage.takeDamage · applyMaxHpFraction 진입점 · ignoresShield · 죽음 시 쉴드 제거) · 측정(PartyShieldSim 5개 조합 - 기록 + 어긋난 값) · ★① 쌍검 ÷ 대검 1.3201.
 --   (나) 실제 Player + 스탠드인 파티 - 보스 검증 체인의 끝에서: 실제 HealCast 경로 쉴드(자신 포함 · 힐 HP 그대로) · 치명 2배 · 재시전 교체 · 반감 · 5겹째 거절 · 버프 유지 ·
 --     실제 피해 경로 흡수(applyHit) · ignoresShield · 만료 Attribute 동기화 · 솔로는 기존 회복 · 실제 딜링모드 소모 루프.
-- env = { ensureBackup, restore, applyOptionStack } - DevTools의 로컬 헬퍼(S13과 같다). 검증이 바꾼 것(파티 · 옵션 · HP · 버프 · 쉴드)은 (나)가 끝날 때 전부 되돌린다.
-- "우회 피해 경로 0"은 자동 검증 밖이다 - 소스 전수 grep(PRD 20.99 [3])으로 확인하고, 여기서는 그 결과 위에서 진입점(applyHit · applyMaxHpFraction · 딜링모드 소모 = takeDamage)이 쉴드를 거치는지만 잰다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local ShieldConfig = require(ReplicatedStorage.Shared.data.ShieldConfig)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local PartyShieldSim = require(ReplicatedStorage.Shared.PartyShieldSim)
local BuffState = require(script.Parent.BuffState)
local HealCast = require(script.Parent.HealCast)
local PartyState = require(script.Parent.PartyState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerShield = require(script.Parent.PlayerShield)
local PlayerState = require(script.Parent.PlayerState)
local TutorialState = require(script.Parent.TutorialState)

local ShieldVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S13b][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

-- 피해 통로(PlayerDamage)가 만지는 것만 갖춘 스탠드인. PlayerState 상태가 있고 SetAttribute · Name이 있으면 takeDamage가 돈다(Attribute는 Player에만 쓰이므로 값은 PlayerState로 읽는다).
local function standInWithHp(name, userId)
	local who = { Name = name, UserId = userId, Parent = workspace, Character = nil, SetAttribute = function() end }
	PlayerState.init(who)
	return who
end

local function anchorRotationUnits(classId)
	local loadout = BalanceSim.buildAnchorLoadout(classId, BalanceAnchorConfig.referenceLevel, 0)
	local total = BalanceSim.simulateCombat(loadout, { useSkills = true }).totalDamage
	return total / (loadout.atk / loadout.class.atk)
end

-- ═══ (가) ═══

function ShieldVerify.runPure()
	print("===S13b 검증 시작(가)===")
	local r = newRecorder("가")
	local shieldDef = SkillData.healer.Q.shield

	-- 층 규칙은 서버 상태 모듈(PlayerShield)로 - 시계를 주입해(now) 기다리지 않고 만료를 잰다. 대상 · 시전자는 테이블 스탠드인.
	local function newTarget()
		return { Name = "S13bTarget" }
	end
	local casters = { {}, {}, {}, {}, {} }

	r.section("[1] 층 순서: 만료가 빠른 층부터 흡수", function()
		local t = newTarget()
		PlayerShield.add(t, casters[1], 100, 10, 0) -- 만료 10
		PlayerShield.add(t, casters[2], 100, 5, 1) -- 만료 6 - 늦게 걸었지만 먼저 만료
		local remaining, absorbed = PlayerShield.absorb(t, 130, 2)
		local left = PlayerShield.getTotal(t, 2)
		r.check(("1 층 순서: 130 피해 → 만료 빠른 층(100) + 나머지 층 30 · 흡수 %.0f(기대 130) 나머지 %.0f(기대 0) · 남은 총량 %.0f(기대 70) · 겹 %d(기대 1)"):format(
			absorbed, remaining, left, PlayerShield.getLayerCount(t, 2)), near(absorbed, 130, 1e-9) and near(remaining, 0, 1e-9) and near(left, 70, 1e-9) and PlayerShield.getLayerCount(t, 2) == 1)
		PlayerShield.clear(t)
	end)

	r.section("[2] 다 깎인 층 제거", function()
		local t = newTarget()
		PlayerShield.add(t, casters[1], 100, 10, 0)
		local _, absorbed = PlayerShield.absorb(t, 100, 1)
		local exactCount = PlayerShield.getLayerCount(t, 1)
		local remaining = PlayerShield.absorb(t, 10, 1)
		r.check(("2 다 깎인 층 즉시 제거: 정확히 100 피해 → 겹 %d(기대 0) · 흡수 %.0f · 이어서 10 피해는 전부 통과 %.0f(기대 10)"):format(exactCount, absorbed, remaining),
			exactCount == 0 and near(absorbed, 100, 1e-9) and near(remaining, 10, 1e-9))
		PlayerShield.clear(t)
	end)

	r.section("[3] 만료 제거", function()
		local t = newTarget()
		PlayerShield.add(t, casters[1], 100, 10, 0)
		PlayerShield.add(t, casters[2], 100, 20, 0)
		local before = PlayerShield.getTotal(t, 9.9)
		local afterFirst, countFirst = PlayerShield.getTotal(t, 10), PlayerShield.getLayerCount(t, 10)
		local afterSecond = PlayerShield.getTotal(t, 20)
		r.check(("3 만료: 9.9초 %.0f(기대 200) · 10초(먼저 건 층 만료 - 남은 양과 함께 사라짐) %.0f · 겹 %d(기대 100 · 1) · 20초 %.0f(기대 0)"):format(before, afterFirst, countFirst, afterSecond),
			near(before, 200, 1e-9) and near(afterFirst, 100, 1e-9) and countFirst == 1 and near(afterSecond, 0, 1e-9))
		PlayerShield.clear(t)
	end)

	r.section("[4][5] 3 · 4번째 층 반감 · 5겹째 거절", function()
		local t = newTarget()
		local results = {}
		for index = 1, 5 do
			results[index] = PlayerShield.add(t, casters[index], 100, 10, 0)
		end
		local halfOk = near(results[1].amount, 100, 1e-9) and near(results[2].amount, 100, 1e-9) and near(results[3].amount, 100 * ShieldConfig.halveMultiplier, 1e-9) and near(results[4].amount, 100 * ShieldConfig.halveMultiplier, 1e-9)
		r.check(("4 층별 양: %.0f · %.0f · %.0f · %.0f(기대 100 · 100 · 50 · 50 - 시전 순간 겹 수 기준 3번째부터 반감) · 총량 %.0f(기대 300)"):format(
			results[1].amount, results[2].amount, results[3].amount, results[4].amount, PlayerShield.getTotal(t, 0)), halfOk and near(PlayerShield.getTotal(t, 0), 300, 1e-9))
		r.check(("5 5겹째 거절: 적용 %s(기대 false) · 사유 %s(기대 full) · 겹 %d(기대 %d = ShieldConfig.maxLayers)"):format(
			tostring(results[5].applied), tostring(results[5].reason), PlayerShield.getLayerCount(t, 0), ShieldConfig.maxLayers),
			not results[5].applied and results[5].reason == "full" and PlayerShield.getLayerCount(t, 0) == ShieldConfig.maxLayers)
		PlayerShield.clear(t)
	end)

	r.section("[6] 같은 시전자 재시전 = 교체", function()
		local t = newTarget()
		for index = 1, 4 do
			PlayerShield.add(t, casters[index], 100, 10, 0)
		end
		local replaceFull = PlayerShield.add(t, casters[1], 100, 10, 5) -- 4겹이 꽉 찬 상태에서 첫 시전자가 다시 - 새 층이 아니라 교체
		local countFull = PlayerShield.getLayerCount(t, 5)
		local t2 = newTarget()
		PlayerShield.add(t2, casters[1], 100, 10, 0)
		PlayerShield.add(t2, casters[2], 100, 10, 0)
		local replaceTwo = PlayerShield.add(t2, casters[1], 80, 10, 1) -- 2겹 중 자기 층을 뺀 겹 수 1 → 반감 아님
		r.check(("6 재시전 교체: 4겹 꽉 찬 상태에서 교체 적용 %s · 교체 %s · 겹 %d(기대 true · true · 4 - 불변) · 자기 뺀 겹 수 3 → 반감 %s 양 %.0f(기대 true · 50) | 2겹에서 재시전: 겹 %d(기대 2) · 반감 %s(기대 false) · 양 %.0f(기대 80)"):format(
			tostring(replaceFull.applied), tostring(replaceFull.replaced), countFull, tostring(replaceFull.halved), replaceFull.amount,
			PlayerShield.getLayerCount(t2, 1), tostring(replaceTwo.halved), replaceTwo.amount),
			replaceFull.applied and replaceFull.replaced and countFull == 4 and replaceFull.halved and near(replaceFull.amount, 50, 1e-9)
				and PlayerShield.getLayerCount(t2, 1) == 2 and replaceTwo.replaced and not replaceTwo.halved and near(replaceTwo.amount, 80, 1e-9))
		PlayerShield.clear(t)
		PlayerShield.clear(t2)
	end)

	r.section("[7] 데이터: 쉴드 설정값", function()
		local uptime = shieldDef.durationSeconds / shieldDef.cooldownSeconds
		r.check(("7 데이터: healRatio %.2f(기대 0.6) · 지속 %d초 ÷ 쿨타임 %d초 = 설계 가동률 %.0f%%(기대 40 ~ 50%%) · 최대 %d겹 · 반감 %d겹째부터 × %.1f(기대 4 · 2 · 0.5) - 전부 shared/data"):format(
			shieldDef.healRatio, shieldDef.durationSeconds, shieldDef.cooldownSeconds, uptime * 100, ShieldConfig.maxLayers, ShieldConfig.halveFromExistingLayers + 1, ShieldConfig.halveMultiplier),
			near(shieldDef.healRatio, 0.6, 1e-9) and uptime >= 0.40 and uptime <= 0.50 and ShieldConfig.maxLayers == 4 and ShieldConfig.halveFromExistingLayers == 2 and near(ShieldConfig.halveMultiplier, 0.5, 1e-9))
	end)

	r.section("[8] 공통 피해 함수: 진입점 · ignoresShield · 죽음", function()
		local who = standInWithHp("S13bDummyA")
		local maxHp = PlayerState.getMaxHp(who)
		local caster = {}
		PlayerShield.add(who, caster, maxHp * 0.5, 60)
		-- (a) 진입점 applyMaxHpFraction(보스 돌진 · 기믹 실패가 타는 경로): 20% 피해 전부 쉴드가 막는다.
		PlayerDamage.applyMaxHpFraction(who, 0.2, "S13b")
		local hpAfterAbsorbed = PlayerState.getHp(who)
		local shieldAfter = PlayerShield.getTotal(who)
		r.check(("8a applyMaxHpFraction 20%% ← 쉴드 50%%: HP %.0f(기대 %.0f 그대로) · 남은 쉴드 %.0f(기대 %.0f)"):format(hpAfterAbsorbed, maxHp, shieldAfter, maxHp * 0.3),
			near(hpAfterAbsorbed, maxHp, 1e-6) and near(shieldAfter, maxHp * 0.3, 1e-6))
		-- (b) 쉴드를 넘는 피해 50%: 쉴드 30% 흡수 + HP 20% 손실.
		PlayerDamage.applyMaxHpFraction(who, 0.5, "S13b")
		r.check(("8b 쉴드를 넘는 피해 50%%: HP %.0f(기대 %.0f = 20%% 손실) · 쉴드 %.0f(기대 0)"):format(PlayerState.getHp(who), maxHp * 0.8, PlayerShield.getTotal(who)),
			near(PlayerState.getHp(who), maxHp * 0.8, 1e-6) and near(PlayerShield.getTotal(who), 0, 1e-6))
		-- (c) ignoresShield: 쉴드를 건드리지 않고 HP만 깎는다(낙사 같은 판정형 · 딜링모드 소모).
		PlayerShield.add(who, caster, maxHp * 0.5, 60)
		local _, absorbed = PlayerDamage.takeDamage(who, maxHp * 0.1, { ignoresShield = true, silent = true })
		r.check(("8c ignoresShield 10%%: 흡수 %.0f(기대 0) · HP %.0f(기대 %.0f) · 쉴드 %.0f(기대 %.0f 그대로)"):format(absorbed, PlayerState.getHp(who), maxHp * 0.7, PlayerShield.getTotal(who), maxHp * 0.5),
			near(absorbed, 0, 1e-9) and near(PlayerState.getHp(who), maxHp * 0.7, 1e-6) and near(PlayerShield.getTotal(who), maxHp * 0.5, 1e-6))
		-- (d) 죽으면 쉴드가 사라진다(쉴드 50% 위에 HP 70% + 쉴드 초과 피해).
		PlayerDamage.applyMaxHpFraction(who, 2, "S13b")
		r.check(("8d 치명 피해: HP %.0f(기대 0) · 쉴드 %.0f(기대 0 - 죽으면 사라짐)"):format(PlayerState.getHp(who), PlayerShield.getTotal(who)),
			PlayerState.getHp(who) == 0 and PlayerShield.getTotal(who) == 0)
		PlayerState.clear(who)
		PlayerShield.clear(who)
	end)

	-- 측정(값 확정 금지) - 앵커 로테이션 DPS로 힐러 딜 비(healerRaw)를 잡아 5개 조합을 잰다.
	r.section("[9] 측정: 파티 조합 5종 × (치유 · 쉴드) × (필드 회복 · 보스전 회복 0)", function()
		local dps = {}
		for _, classId in ipairs({ "greatsword", "dualblade", "bow", "healer" }) do
			dps[classId] = anchorRotationUnits(classId)
		end
		local ratio = dps.dualblade / dps.greatsword
		r.check(("9 ★① 도적 ÷ 검사 = %.4f(기대 1.3201 ± 0.0005 - 이 세션 전과 같다 · 검사 %.1f · 도적 %.1f)"):format(ratio, dps.greatsword, dps.dualblade), near(ratio, 1.3201, 0.0005))

		local healerRaw = dps.healer / dps.greatsword
		local referenceSeconds = 600
		local hits = { hitsPerSecond = 0.25, hitRatio = 0.1026 } -- BalanceSim.simulateHealerCycle 기준 시나리오(S13 딜링모드 가동률 측정과 같다)
		local function run(dealers, healers, shield, regen)
			return PartyShieldSim.run({
				dealers = dealers, healers = healers, healerRaw = healerRaw, bossHpUnits = 4 * referenceSeconds,
				hitsPerSecond = hits.hitsPerSecond, hitRatio = hits.hitRatio, shield = shield, regenPerSecond = regen,
			})
		end
		print(("[S13b][가][측정] 모형 가정: 딜러는 항상 전투 중 · 안 죽음 / 피격 초당 %.2f회 × 최대체력 %.2f%% / 치유사 딜 비 %.4f(검사 1) / 파티 딜 = (딜러 + 전투 중 치유사 × 비) × (1 + 치유사 버프 b) / 보스 HP = 딜러 4명이 %d초 / 쉴드는 쿨타임이 차면 바로 시전(시전이 겹치는 쪽) / 피해 단위 = 멤버 최대체력 비율의 합"):format(
			hits.hitsPerSecond, hits.hitRatio * 100, healerRaw, referenceSeconds))
		local table_ = {}
		for _, regen in ipairs({ "field", "boss" }) do
			local regenValue = regen == "boss" and 0 or nil
			for _, shield in ipairs({ false, true }) do
				for healers = 0, 4 do
					local result = run(4 - healers, healers, shield, regenValue)
					table_[regen .. (shield and "S" or "H") .. healers] = result
					print(("[S13b][가][측정] %s · %s · 딜러%d+치유사%d: 처치 %s초 · 받은 피해 %.2f · 쉴드 흡수 %.2f(흡수율 %.1f%%) · 순 HP 손실 %.2f(초당 %.4f) · 대상별 쉴드 가동률 %.1f%% · 평균 겹 %.2f(쉴드 있을 때 %.2f) · 치유사 전투 비율 %s · 시전 %d · 5겹 거절 %d · 반감 %d · 교체 %d"):format(
						regen == "boss" and "보스전(회복 0)" or "필드(회복 기본)", shield and "쉴드" or "치유(옛 동작)", 4 - healers, healers, result.killSeconds and ("%.1f"):format(result.killSeconds) or "상한",
						result.damageIn, result.absorbed, result.damageIn > 0 and result.absorbed / result.damageIn * 100 or 0, result.hpLoss, result.hpLoss / result.elapsed, result.shieldUptime * 100, result.avgLayers, result.avgLayersWhileShielded,
						result.healerFightRatio and ("%.3f"):format(result.healerFightRatio) or "-", result.casts, result.rejected, result.halved, result.replaced))
				end
			end
		end

		-- 참고: 힐러가 이탈하지 않고 계속 전투하는 경우(딜링모드 소모 0 · 이탈 없음) - 층 겹침 규칙(반감 · 5겹)과 가동률 상한만 본다. 설계 가동률은 지속 ÷ 쿨타임이고, 실제는 피격이 쉴드를 깎아 그보다 낮다.
		for healers = 1, 4 do
			local result = PartyShieldSim.run({
				dealers = 4 - healers, healers = healers, healerRaw = healerRaw, bossHpUnits = 4 * referenceSeconds, hitsPerSecond = hits.hitsPerSecond, hitRatio = hits.hitRatio,
				shield = true, reserveRatio = -100, drainPerSecond = 0, maxSeconds = referenceSeconds,
			})
			print(("[S13b][가][측정][참고] 치유사가 이탈하지 않는 경우 · 딜러%d+치유사%d(%d초): 대상별 쉴드 가동률 %.1f%%(설계 %.0f%% = 지속 ÷ 쿨타임) · 평균 겹 %.2f(쉴드 있을 때 %.2f) · 흡수율 %.1f%% · 시전 %d · 반감 %d · 5겹 거절 %d"):format(
				4 - healers, healers, referenceSeconds, result.shieldUptime * 100, shieldDef.durationSeconds / shieldDef.cooldownSeconds * 100, result.avgLayers, result.avgLayersWhileShielded,
				result.damageIn > 0 and result.absorbed / result.damageIn * 100 or 0, result.casts, result.halved, result.rejected))
		end

		-- 모형 정합: 힐러 1명 치유 모드의 전투 비율 = BalanceSim.simulateHealerCycle(같은 조건) 가동률 · 딜러 4명 = 기준 처치 시간.
		local cycle = BalanceSim.simulateHealerCycle({ hitsPerSecond = hits.hitsPerSecond, hitRatio = hits.hitRatio }).uptime
		local base = table_.fieldH0
		local oneHealer = table_.fieldH1
		r.check(("9b 모형 정합: 딜러4 처치 %.1f초(기대 %d) · 치유 모드 치유사 1명 전투 비율 %.4f(기대 simulateHealerCycle %.4f ± 0.01) · 딜러3+치유사1 처치 %.1f초(딜러4 대비 %+.2f%% - 옛 앵커의 b 결과)"):format(
			base.killSeconds, referenceSeconds, oneHealer.healerFightRatio, cycle, oneHealer.killSeconds, (oneHealer.killSeconds / base.killSeconds - 1) * 100),
			near(base.killSeconds, referenceSeconds, 0.1) and near(oneHealer.healerFightRatio, cycle, 0.01))

		-- 어긋난 값(지시 기준 - 값은 안 만진다). 기준 문장 그대로 판정하고 어긋난 것만 따로 찍는다. "확실히 · 크게"의 수치는 이 검증이 임의로 정한 것이다(아래 줄에 적는다).
		local function report(regen)
			local prefix = regen
			local d4 = table_[prefix .. "S0"]
			local d3h1, d2h2, d1h3, h4 = table_[prefix .. "S1"], table_[prefix .. "S2"], table_[prefix .. "S3"], table_[prefix .. "S4"]
			local misses = {}
			local function miss(text)
				table.insert(misses, text)
			end
			if math.abs(d3h1.killSeconds / d4.killSeconds - 1) > 0.02 then
				miss(("딜러3+힐러1 ≈ 딜러4(±2%%) 어긋남: %+.1f%%"):format((d3h1.killSeconds / d4.killSeconds - 1) * 100))
			end
			if not (d2h2.killSeconds > d4.killSeconds and d2h2.killSeconds <= d4.killSeconds * 1.10) then
				miss(("딜러2+힐러2 '약간 느림'(딜러4 초과 · +10%% 이내) 어긋남: %+.1f%%"):format((d2h2.killSeconds / d4.killSeconds - 1) * 100))
			end
			local d4Rate, d2h2Rate = d4.hpLoss / d4.elapsed, d2h2.hpLoss / d2h2.elapsed
			if not (d2h2Rate <= d4Rate * 0.8) then
				miss(("딜러2+힐러2 '받은 피해 크게 적음'(딜러4의 80%% 이하 - 초당 순 HP 손실) 어긋남: %.4f vs 딜러4 %.4f(%.0f%%)"):format(d2h2Rate, d4Rate, d2h2Rate / d4Rate * 100))
			end
			for _, entry in ipairs({ { "딜러1+힐러3", d1h3 }, { "힐러4", h4 } }) do
				if not (entry[2].killSeconds >= d4.killSeconds * 1.10) then
					miss(("%s '처치 시간 확실히 느림'(딜러4 대비 +10%% 이상) 어긋남: %+.1f%%"):format(entry[1], (entry[2].killSeconds / d4.killSeconds - 1) * 100))
				end
			end
			if not (d1h3.shieldUptime > d3h1.shieldUptime and h4.shieldUptime > d3h1.shieldUptime) then
				miss(("힐러3~4 '가동률은 높음'(힐러1보다 높음) 어긋남: 힐러1 %.1f%% · 힐러3 %.1f%% · 힐러4 %.1f%%"):format(d3h1.shieldUptime * 100, d1h3.shieldUptime * 100, h4.shieldUptime * 100))
			end
			local function absorbRate(result)
				return result.damageIn > 0 and result.absorbed / result.damageIn or 0
			end
			local gain12 = absorbRate(d2h2) - absorbRate(d3h1)
			local gain23 = absorbRate(d1h3) - absorbRate(d2h2)
			local gain34 = absorbRate(h4) - absorbRate(d1h3)
			if not (gain23 < gain12 and gain34 < gain12) then
				miss(("힐러3~4 '반감 때문에 흡수량 증가가 둔함'(흡수율 = 흡수 ÷ 받은 피해의 증가분이 힐러 1→2보다 작음) 어긋남: 1→2 %+.1f%%p · 2→3 %+.1f%%p · 3→4 %+.1f%%p"):format(gain12 * 100, gain23 * 100, gain34 * 100))
			end
			print(("[S13b][가][어긋남] %s: %s"):format(regen == "field" and "필드(회복 기본)" or "보스전(회복 0)", #misses == 0 and "없음" or table.concat(misses, " / ")))
		end
		print("[S13b][가][어긋남] 판정 기준(임의): ≈ = ±2% · 약간 느림 = 딜러4 초과 ~ +10% · 크게 적음 = 딜러4 초당 순 HP 손실의 80% 이하 · 확실히 느림 = +10% 이상 · 가동률 높음 = 치유사1보다 높음 · 증가 둔함 = 흡수율 증가분이 치유사 1→2 증가분보다 작음")
		report("field")
		report("boss")
	end)

	local pass, total = r.summary()
	print(("===S13b 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ═══ (나) ═══

local function leaveAll(...)
	for _, who in ipairs({ ... }) do
		if PartyState.getParty(who) then
			PartyState.leave(who, "leave")
		end
	end
end

function ShieldVerify.runLive(player, env)
	print("===S13b 검증 시작(나: 실제 HealCast · 피해 경로 · 실제 Player + 스탠드인 파티)===")
	local r = newRecorder("나")
	local function finish()
		local pass, total = r.summary()
		print(("===S13b 검증 끝(나)=== %d/%d 통과"):format(pass, total))
	end
	if not PlayerProfile.getProfile(player) or not PlayerState.getMaxHp(player) then
		r.check("프로필 또는 HP 상태가 없어 검증을 건너뜀", false)
		return finish()
	end
	if PartyState.getParty(player) or TutorialState.isActive(player) then
		r.check("이미 파티에 있거나 견습 진행 중이라 검증을 건너뜀(파티를 나가고 견습을 끝낸 뒤 다시)", false)
		return finish()
	end

	env.ensureBackup(player)
	local def = SkillData.healer.Q
	local shieldDef = def.shield
	local cooldown = shieldDef.cooldownSeconds
	local savedHp = PlayerState.getHp(player)
	local member = standInWithHp("S13bMember", -9601)
	local memberMax = PlayerState.getMaxHp(player) * 2.5 -- 힐러와 다른 최대체력 - "받는 사람 자신의 최대체력 기준"을 가른다
	PlayerState.setMaxHp(member, memberMax)
	local extra = { {}, {}, {} } -- 다른 시전자(스탠드인 테이블)

	-- 옵션을 재생 0인 기준 빌드로(개발 계정의 장비 옵션이 기대값을 흔들지 않게).
	env.applyOptionStack(player, "attackPercent")
	-- G1-0(P3d-F 결정 4): 기대식은 게임과 같은 치유 배수(재생 옵션 × (1 + 무기 최종 데미지 버킷)) - 개발 계정 무기 강화 단계가 기대값을 흔들지 않게.
	local healingPower = HealCast.healingPower(player)
	local originalRoll = HealCast.rollCrit
	local function forceCrit(value)
		HealCast.rollCrit = function()
			return value
		end
	end

	-- 딜링모드를 켠 채로 파티를 만든다.
	BuffState.apply(player, "dealingMode", { attackMultiplier = SkillData.healer.E.attackMultiplier, displayName = SkillData.healer.E.name, colorName = "danger" })
	PartyState.create(player)
	PartyState.attachMember(PartyState.getParty(player), member)

	local function cast()
		local ok, healAmount, isCrit, healed, shielded = pcall(HealCast.cast, player, def, "healer", cooldown)
		return ok, healAmount, isCrit, healed, shielded
	end
	local function shieldOf(who)
		return PlayerShield.getTotal(who)
	end

	r.section("[10] 쉴드 시전(딜링모드 + 파티): 자신 포함 · 회복 없음 · 양 = 힐량 × 0.6", function()
		PlayerState.setHp(member, memberMax * 0.45)
		PlayerState.setHp(player, PlayerState.getMaxHp(player) * 0.5)
		forceCrit(false)
		local usesShield = HealCast.usesShield(player, def)
		local ok, healAmount, _, healed, shielded = cast()
		local playerMax = PlayerState.getMaxHp(player)
		local expectedMember = memberMax * def.healPercentOfMaxHp * healingPower * shieldDef.healRatio
		local expectedSelf = playerMax * def.healPercentOfMaxHp * healingPower * shieldDef.healRatio
		local memberHpKept = near(PlayerState.getHp(member), memberMax * 0.45, 1e-6)
		local selfHpKept = near(PlayerState.getHp(player), playerMax * 0.5, 1e-6)
		r.check(("10 쉴드 모드=%s(기대 true) · 에러 없음=%s · 자기 회복 %.0f(기대 0) · 회복받은 멤버 %d명(기대 0) · 쉴드 받은 %d명(기대 2 - 자신 포함) · 멤버 쉴드 %.1f(기대 %.1f) · 자기 쉴드 %.1f(기대 %.1f) · HP 그대로 멤버 %s 자기 %s · Shield Attribute %.1f ★진짜 합격 기준"):format(
			tostring(usesShield), tostring(ok), healAmount or -1, #(healed or {}), #(shielded or {}), shieldOf(member), expectedMember, shieldOf(player), expectedSelf,
			tostring(memberHpKept), tostring(selfHpKept), player:GetAttribute("Shield") or -1),
			usesShield and ok and healAmount == 0 and #healed == 0 and #shielded == 2 and near(shieldOf(member), expectedMember, 1e-6) and near(shieldOf(player), expectedSelf, 1e-6)
				and memberHpKept and selfHpKept and near(player:GetAttribute("Shield") or -1, expectedSelf, 1e-6))
		local buff = BuffState.get(player, "healerBuff")
		r.check(("11 치유사 버프는 쉴드를 줄 때도 걸린다: 걸림 %s · 배율 %.4f(기대 1 + b)"):format(tostring(buff ~= nil), buff and buff.multiplier or 0),
			buff ~= nil and near(buff.multiplier, 1 + PartyConfig.healerBuffFraction, 1e-9))
	end)

	r.section("[12] 재시전: 교체(겹 수 불변)", function()
		local ok, _, _, _, shielded = cast()
		r.check(("12 같은 치유사 재시전: 에러 없음=%s · 겹 수 멤버 %d 자기 %d(기대 1 · 1) · 교체 %s · 멤버 쉴드 %.1f(기대 %.1f 그대로 - 새 층 아님)"):format(
			tostring(ok), PlayerShield.getLayerCount(member), PlayerShield.getLayerCount(player), tostring(ok and shielded[1].result.replaced),
			shieldOf(member), memberMax * def.healPercentOfMaxHp * healingPower * shieldDef.healRatio),
			ok and PlayerShield.getLayerCount(member) == 1 and PlayerShield.getLayerCount(player) == 1 and shielded[1].result.replaced
				and near(shieldOf(member), memberMax * def.healPercentOfMaxHp * healingPower * shieldDef.healRatio, 1e-6))
	end)

	r.section("[13] 치명 굴림은 힐과 같은 함수: 치명 → 쉴드 2배 · 회복 2배", function()
		PlayerShield.clear(member)
		PlayerShield.clear(player)
		local perHit = memberMax * def.healPercentOfMaxHp * healingPower
		forceCrit(true)
		local _, _, isCrit = cast()
		local critShield = shieldOf(member)
		-- 같은 함수가 회복 쪽도 굴리는가: 딜링모드를 잠깐 끄고(쉴드 모드 해제) 파티 회복을 받는다.
		BuffState.clear(player, "dealingMode")
		-- G1-0: 시작 HP를 낮게(5%) - 계정 치유 배수가 커도 치명 회복이 최대체력 상한에 덜 잘린다. 기대는 상한으로 자른 값.
		local startHp = memberMax * 0.05
		PlayerState.setHp(member, startHp)
		cast()
		local critHeal = PlayerState.getHp(member) - startHp
		forceCrit(false)
		PlayerState.setHp(member, startHp)
		cast()
		local plainHeal = PlayerState.getHp(member) - startHp
		local critHealExpected = math.min(plainHeal * def.critHealMultiplier, memberMax - startHp)
		BuffState.apply(player, "dealingMode", { attackMultiplier = SkillData.healer.E.attackMultiplier, displayName = SkillData.healer.E.name, colorName = "danger" })
		r.check(("13 치명: 쉴드 %.1f(기대 %.1f = 힐량 × 0.6 × %.1f) · 힐량 %.1f(기대 %.1f = 힐 일반 %.1f × 2 - 같은 굴림 함수) ★진짜 합격 기준"):format(
			critShield, perHit * shieldDef.healRatio * def.critHealMultiplier, def.critHealMultiplier, critHeal, critHealExpected, plainHeal),
			isCrit == true and near(critShield, perHit * shieldDef.healRatio * def.critHealMultiplier, 1e-6) and near(critHeal, critHealExpected, 1e-6) and near(plainHeal, math.min(perHit, memberMax - startHp), 1e-6))
		forceCrit(false)
		PlayerShield.clear(member)
		PlayerShield.clear(player)
	end)

	r.section("[14] 3 · 4번째 층 반감 · 5겹째 거절(실제 시전이 세 번째)", function()
		PlayerShield.add(member, extra[1], 1000, 60)
		PlayerShield.add(member, extra[2], 1000, 60)
		local _, _, _, _, shielded = cast() -- 멤버에게 이미 2겹 → 힐러의 층이 3번째 = 반감
		local result
		for _, entry in ipairs(shielded or {}) do
			if entry.member == member then -- 목록 순서는 파티 순서(힐러 자신이 먼저) - 멤버 몫을 찾는다
				result = entry.result
			end
		end
		local base = memberMax * def.healPercentOfMaxHp * healingPower * shieldDef.healRatio
		local thirdOk = result and result.applied and result.halved and near(result.amount, base * ShieldConfig.halveMultiplier, 1e-6)
		local fourth = PlayerShield.add(member, extra[3], 1000, 60)
		local fifth = PlayerShield.add(member, {}, 1000, 60)
		r.check(("14 실제 시전이 3번째 층: 반감 %s · 양 %.1f(기대 %.1f) | 4번째 층 반감 %s 양 %.0f(기대 500) | 5겹째 적용 %s(기대 false) · 겹 %d(기대 4)"):format(
			tostring(result and result.halved), result and result.amount or -1, base * ShieldConfig.halveMultiplier, tostring(fourth.halved), fourth.amount, tostring(fifth.applied), PlayerShield.getLayerCount(member)),
			thirdOk and fourth.halved and near(fourth.amount, 500, 1e-9) and not fifth.applied and PlayerShield.getLayerCount(member) == 4)
		PlayerShield.clear(member)
		PlayerShield.clear(player)
	end)

	r.section("[15] 실제 피해 경로(PlayerDamage.applyHit)가 쉴드를 먼저 깎는다 · 만료 동기화", function()
		BuffState.clear(player, "dealingMode") -- 딜링모드 소모(Heartbeat)가 HP 차이 측정을 흔들지 않게 - [16]에서 다시 켠다
		-- 개발 계정은 방어력이 커서 작은 공격력은 피해가 0에 가깝다 - 한 방이 최대체력의 0.01% 안팎이 되도록 공격력을 키운다(방어 감소식은 공격력에 단조 증가).
		local attack = 1
		local targetHit = PlayerState.getMaxHp(player) * 1e-4
		while PlayerDamage.computeHitDamage(attack, player) < targetHit and attack < 1e15 do
			attack *= 2
		end
		local hit = PlayerDamage.computeHitDamage(attack, player)
		PlayerShield.add(player, extra[1], hit * 3.5, 60)
		local hpBefore = PlayerState.getHp(player)
		for _ = 1, 3 do
			PlayerDamage.applyHit(player, attack, "S13b")
		end
		local afterThree = PlayerState.getHp(player)
		local shieldLeft = shieldOf(player)
		local attribute = player:GetAttribute("Shield")
		PlayerDamage.applyHit(player, attack, "S13b") -- 쉴드 0.5타분이 남아 이 타는 반만 HP로
		local afterFour = PlayerState.getHp(player)
		r.check(("15 applyHit 4번(쉴드 3.5타분): 3번 뒤 HP 변화 %.4f(기대 0) · 남은 쉴드 %.4f(기대 %.4f) · Attribute %.4f · 4번째 뒤 HP 손실 %.4f(기대 %.4f = 반 타) ★진짜 합격 기준"):format(
			hpBefore - afterThree, shieldLeft, hit * 0.5, attribute or -1, afterThree - afterFour, hit * 0.5),
			near(hpBefore - afterThree, 0, 1e-6 * hpBefore) and near(shieldLeft, hit * 0.5, 1e-6 * hit) and near(attribute or -1, hit * 0.5, 1e-6 * hit) and near(afterThree - afterFour, hit * 0.5, 1e-6 * hit))
		-- ignoresShield: 딜링모드 소모가 타는 방식(silent) - 쉴드는 그대로 두고 HP만.
		PlayerShield.add(player, extra[1], hit * 2, 60)
		local hpBeforeIgnore = PlayerState.getHp(player)
		PlayerDamage.takeDamage(player, hit, { ignoresShield = true, silent = true })
		r.check(("15b ignoresShield(딜링모드 소모 방식): HP 손실 %.4f(기대 %.4f) · 쉴드 %.4f(기대 %.4f 그대로)"):format(hpBeforeIgnore - PlayerState.getHp(player), hit, shieldOf(player), hit * 2),
			near(hpBeforeIgnore - PlayerState.getHp(player), hit, 1e-6 * hit) and near(shieldOf(player), hit * 2, 1e-6 * hit))
		PlayerShield.clear(player)
		-- 만료 동기화: 0.3초 쉴드 → Attribute가 다시 0으로.
		PlayerShield.add(player, extra[2], hit, 0.3)
		local up = player:GetAttribute("Shield") or -1
		task.wait(0.6)
		local down = player:GetAttribute("Shield") or -1
		r.check(("15c 만료 Attribute 동기화: 걸린 직후 %.4f(기대 %.4f) → 0.6초 뒤 %.4f(기대 0)"):format(up, hit, down), near(up, hit, 1e-6 * hit) and down == 0)
	end)

	r.section("[16] 솔로 딜링모드 = 기존 자기 회복(쉴드 없음)", function()
		leaveAll(player, member)
		PlayerShield.clear(player)
		BuffState.apply(player, "dealingMode", { attackMultiplier = SkillData.healer.E.attackMultiplier, displayName = SkillData.healer.E.name, colorName = "danger" })
		PlayerState.setHp(player, PlayerState.getMaxHp(player) * 0.5)
		forceCrit(false)
		local usesShield = HealCast.usesShield(player, def)
		local ok, healAmount, _, _, shielded = cast()
		local playerMax = PlayerState.getMaxHp(player)
		local expected = math.min(playerMax * 0.5 + playerMax * def.healPercentOfMaxHp * healingPower, playerMax)
		r.check(("16 솔로 딜링모드: 쉴드 모드=%s(기대 false) · 에러 없음=%s · 자기 HP %.0f(기대 %.0f = 기존 자기 회복) · 쉴드 %.0f(기대 0) · 시전한 쉴드 %d건(기대 0)"):format(
			tostring(usesShield), tostring(ok), PlayerState.getHp(player), expected, shieldOf(player), #(shielded or {})),
			not usesShield and ok and healAmount > 0 and near(PlayerState.getHp(player), expected, 1e-6 * playerMax) and shieldOf(player) == 0 and #shielded == 0)
	end)

	r.section("[17] 실제 딜링모드 소모 루프(HealerDealingMode - PlayerDamage.takeDamage · ignoresShield 경로): 쉴드 그대로 · HP만", function()
		PlayerShield.clear(player)
		local maxHp = PlayerState.getMaxHp(player)
		PlayerState.setHp(player, maxHp)
		player:SetAttribute("Hp", maxHp)
		PlayerShield.add(player, extra[1], maxHp, 60) -- 소모가 쉴드를 깎는다면 눈에 띄게 줄 만큼 크게
		BuffState.apply(player, "dealingMode", { attackMultiplier = SkillData.healer.E.attackMultiplier, displayName = SkillData.healer.E.name, colorName = "danger" })
		local startedAt = os.clock()
		task.wait(0.5)
		BuffState.clear(player, "dealingMode")
		local elapsed = os.clock() - startedAt
		local dropped = maxHp - PlayerState.getHp(player)
		local expected = maxHp * SkillData.healer.E.drainPercentPerSecond * (1 + PlayerProfile.getOptionBonus(player, "skill_healer_E")) * elapsed
		local shieldLeft = shieldOf(player)
		r.check(("17 실제 소모 %.2f초: HP 손실 %.0f(기대 %.0f ± 35%% = 최대체력 × %.3f/초 × 시간) · 쉴드 %.0f(기대 %.0f 그대로) · Shield Attribute %.0f"):format(
			elapsed, dropped, expected, SkillData.healer.E.drainPercentPerSecond, shieldLeft, maxHp, player:GetAttribute("Shield") or -1),
			dropped > 0 and near(dropped / expected, 1, 0.35) and near(shieldLeft, maxHp, 1e-6 * maxHp) and near(player:GetAttribute("Shield") or -1, maxHp, 1e-6 * maxHp))
		PlayerShield.clear(player)
		PlayerState.setHp(player, savedHp)
		player:SetAttribute("Hp", savedHp)
	end)

	-- 되돌리기: 굴림 함수 · 파티 · 버프 · 쉴드 · 스탠드인 · 옵션 · HP.
	HealCast.rollCrit = originalRoll
	leaveAll(player, member)
	BuffState.clear(player, "dealingMode")
	BuffState.clear(player, "healerBuff")
	PlayerShield.clear(player)
	PlayerShield.clear(member)
	PlayerState.clear(member)
	env.restore(player)
	PlayerState.setHp(player, savedHp)
	player:SetAttribute("Hp", savedHp)
	r.check(("정리: 치명 굴림 원복 %s · 파티 %s(기대 nil) · 딜링모드 %s · 치유 버프 %s(기대 nil nil) · 쉴드 %.0f · Shield Attribute %s(기대 0) · 스탠드인 HP 상태 %s(기대 nil)"):format(
		tostring(HealCast.rollCrit == originalRoll), tostring(PartyState.getParty(player)), tostring(BuffState.get(player, "dealingMode")), tostring(BuffState.get(player, "healerBuff")),
		shieldOf(player), tostring(player:GetAttribute("Shield")), tostring(PlayerState.getHp(member))),
		HealCast.rollCrit == originalRoll and PartyState.getParty(player) == nil and BuffState.get(player, "dealingMode") == nil and BuffState.get(player, "healerBuff") == nil
			and shieldOf(player) == 0 and (player:GetAttribute("Shield") or 0) == 0 and PlayerState.getHp(member) == nil)

	finish()
end

return ShieldVerify
