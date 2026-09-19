-- 29-1 자동 검증(PRD 20.74 [C]) - 보스 공통 뼈대(체력 비례 피해·잡힘/구출·파훼 게이트·스케줄러 확장·
-- 힌트 단계)를 서버 안에서 직접 돌려 결과를 print한다. DevTools.server.lua의 26-2·27-4 블록과 같은
-- 패턴이고(execute_luau로는 shared 모듈을 require할 수 없다 - 20.67), DevTools가 너무 커지지 않게
-- 본문만 이 모듈로 뺐다. DevTools가 Studio에서만, 첫 플레이어의 프로필이 로드된 뒤 한 번 부른다.
--   (가) 도출값·처치 시간 모형 - 순수 계산(BossSim). python 모형(세션 스크래치패드)과 대조한 기대값.
--   (나) 실제 서버 경로 - 보스를 스폰해 PlayerDamage·BossTrap·BossMechanics·BossPatterns를 직접 호출.
-- env = { ensureBackup, restore, applyStage, applyOptionStack } - DevTools의 로컬 헬퍼(백업·복원 포함).
--
-- 29-2: 보스 데이터가 스킬표(data.skills)로 재편되면서 이 모듈도 새 이름으로 옮겼다(회귀용으로 계속 돈다).
-- 보스별 처치 시간표는 29-2 검증(BossSkillVerify.lua)으로 옮겼고, 실시간 첫 기믹 측정은 "시계 시작 시각 기준"으로
-- 고쳤다 - 29-1 Play에서 검증 중 보스에 어그로가 붙어 시계가 다시 시작되는 바람에 12초 창을 벗어났었다(20.74 [6]).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local BossEncounter = require(script.Parent.BossEncounter)
local BossPatterns = require(script.Parent.BossPatterns)
local BossMechanics = require(script.Parent.BossMechanics)
local BossTrap = require(script.Parent.BossTrap)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)

local BossMechanicsVerify = {}

local GUARDIAN = "section_guardian"

local EXPECTED_GUARDIAN = { 73.30, 37.85 }
local SIM_TOLERANCE_SECONDS = 0.06

local function near(actual, expected, tolerance)
	return actual ~= nil and math.abs(actual - expected) <= tolerance
end

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[29-1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	-- 구역 하나를 pcall로 감싼다 - 에러가 나도 다음 구역은 돈다(에러 자체가 X 한 건).
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

-- ─────────────────────────── (가) 도출값·모형 ───────────────────────────

local function runPure()
	print("===29-1 검증 시작(가: 도출값·처치 시간 모형)===")
	local r = newRecorder("가")
	local mechanics = BossData.mechanics
	local f = mechanics.gimmickFailMaxHpFraction

	r.section("도출값", function()
		local g = BossRules.gateDamageTakenMultiplier()
		local expectedG = 1 / InfiniteStageConfig.growthRate ^ BossData.stageInterval
		r.check(("게이트 g = N_max^(p-1) = %.4f (= 1/k^%d = %.4f, p=%.4f)"):format(
			g, BossData.stageInterval, expectedG, BossRules.partyHpExponent()), near(g, expectedG, 1e-9))
		r.check(("4인 x g = %.4f = 솔로 1.0 (기믹을 무시하는 정원 파티의 딜 = 기믹을 푸는 솔로의 딜)"):format(
			PartyConfig.maxMembers * g / BossRules.partySizeHpMultiplier(PartyConfig.maxMembers)),
			near(PartyConfig.maxMembers * g / BossRules.partySizeHpMultiplier(PartyConfig.maxMembers), 1, 1e-9))

		local heavyShare = BossData.bosses[GUARDIAN].skills.heavy.damage.multiplier / BalanceAnchorConfig.surviveTargetHits
		r.check(("기믹 실패 f = %.2f, 허용 구간 [0.50, %.4f) - 하한 2f>=1, 상한 f + 강타 %.4f < 1"):format(f, 1 - heavyShare, heavyShare),
			f >= 0.5 and f < 1 - heavyShare)
		r.check(("부분 실패 %.4f x %d = %.2f (기믹 1회 합계 상한 = f)"):format(f / mechanics.partialFailDivisor, mechanics.partialFailDivisor, f),
			near(f / mechanics.partialFailDivisor * mechanics.partialFailDivisor, f, 1e-9))
		r.check(("잡힘: 자동 해제 %.1f초 / 구출 %.1f초 = %.1f : 1, 잡힌 동안 받는 피해 x%.1f"):format(
			mechanics.trap.autoReleaseSeconds, mechanics.trap.rescueSeconds,
			mechanics.trap.autoReleaseSeconds / mechanics.trap.rescueSeconds, mechanics.trap.damageTakenMultiplier),
			mechanics.trap.autoReleaseSeconds == 9 and mechanics.trap.rescueSeconds == 1.5 and mechanics.trap.damageTakenMultiplier == 0)
		local lifestealSeconds = f / CombatConfig.lifestealMaxHpFractionPerSecond
		r.check(("흡혈 상한 %.0f%%/초로 f 회복 = 공격 %.2f초(< 기믹 주기 20초 + 예고) - 잡힘 %.0f초 동안은 0"):format(
			CombatConfig.lifestealMaxHpFractionPerSecond * 100, lifestealSeconds, mechanics.trap.autoReleaseSeconds),
			near(lifestealSeconds, 13.75, 1e-6))
	end)

	r.section("모형", function()
		local solo = BossSim.run(GUARDIAN, { partySize = 1 })
		local party = BossSim.run(GUARDIAN, { partySize = 4 })
		r.check(("구간 수호자(기믹·게이트 없음) 솔로 %.2f초(기대 %.2f) / 4인 %.2f초(기대 %.2f), 슬롯 강%d 진%d 낙%d 돌%d 십%d"):format(
			solo.seconds, EXPECTED_GUARDIAN[1], party.seconds, EXPECTED_GUARDIAN[2],
			solo.counts.heavy, solo.counts.shockwave, solo.counts.meteor, solo.counts.charge, solo.counts.cross),
			near(solo.seconds, EXPECTED_GUARDIAN[1], SIM_TOLERANCE_SECONDS) and near(party.seconds, EXPECTED_GUARDIAN[2], SIM_TOLERANCE_SECONDS)
				and solo.gimmickCount == 0)
	end)

	local passCount, totalCount = r.summary()
	print(("===29-1 검증 끝(가)=== %d/%d 통과"):format(passCount, totalCount))
end

-- ─────────────────────────── (나) 실제 서버 경로 ───────────────────────────

local function spawnGuardian(player, env)
	BossEncounter.despawnFor(player)
	env.applyStage(player, BossData.stageInterval)
	PlayerProfile.forceBossRotationNext(player, GUARDIAN)
	BossEncounter.spawnFor(player, BossData.stageInterval)
	local model = BossEncounter.getActive(player)
	return model, model and MonsterState.getData(model)
end

local function fullHeal(player)
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	PlayerDamage.syncHud(player)
end

local function hpFraction(player)
	return PlayerState.getHp(player) / PlayerState.getMaxHp(player)
end

-- 공통 기믹 스킬을 이 보스 인스턴스에만 얹는다. data는 스폰마다 새 테이블이지만 data.skills·skillOrder는
-- BossData 원본을 가리킬 수 있으므로(읽기 전용) 복사본으로 갈아 끼운다 - 원본은 절대 안 건드린다.
-- 시계 값은 서리 거인의 포효(20초·첫 10초·자리 비우기·기믹 우선순위)를 그대로 빌린다.
local function injectGimmick(model, data, telegraphSeconds)
	local design = BossData.bosses.frost_giant.skills.roar
	local skills = table.clone(data.skills)
	skills.gimmick = {
		primitive = "gimmick", bubble = "gimmick", role = "gimmick", kind = "verify29",
		cooldownSeconds = design.cooldownSeconds,
		firstAvailableSeconds = design.firstAvailableSeconds,
		reserveFirstUse = design.reserveFirstUse,
		priority = design.priority,
		telegraphSeconds = telegraphSeconds or design.telegraphSeconds,
		damage = design.damage, damageLabel = "기믹 실패(검증)",
	}
	local order = table.clone(data.skillOrder)
	table.insert(order, "gimmick")
	data.skills, data.skillOrder = skills, order
	BossPatterns.onAggro(model, data) -- 새 스킬표로 시계를 다시 잰다
	return design.firstAvailableSeconds
end

local function runLive(player, env)
	print("===29-1 검증 시작(나: 실제 서버 경로)===")
	local r = newRecorder("나")
	local mechanics = BossData.mechanics
	local f = mechanics.gimmickFailMaxHpFraction
	local g = BossRules.gateDamageTakenMultiplier()

	env.ensureBackup(player)
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		r.check("캐릭터 준비 실패 - (나) 전체 건너뜀", false)
		env.restore(player)
		local passCount, totalCount = r.summary()
		print(("===29-1 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
		return
	end

	-- [9] 구간 수호자 - 새 뼈대 위에서도 이전과 같은가
	r.section("구간 수호자 회귀", function()
		local model, data = spawnGuardian(player, env)
		local clocks = BossPatterns.debugClocks(model)
		local source = BossData.bosses[GUARDIAN]
		r.check(("구간 수호자: mechanics=%s, skills.gimmick=%s, 스킬표가 BossData 원본 그대로(스테이지 5 = 범위 배율 1)=%s"):format(
			tostring(data.mechanics), tostring(data.skills.gimmick), tostring(data.skills == source.skills)),
			data.id == GUARDIAN and data.mechanics == nil and data.skills.gimmick == nil and data.skills == source.skills)
		r.check(("패턴 시계(초): 강공격 %.1f 진동파 %.1f 낙석 %.1f 돌진 %.1f 십자 %.1f 기믹 %s (기대 6/11/13/15/17/없음)"):format(
			clocks.heavy or -1, clocks.shockwave or -1, clocks.meteor or -1, clocks.charge or -1, clocks.cross or -1, tostring(clocks.gimmick)),
			near(clocks.heavy, 6, 0.5) and near(clocks.shockwave, 11, 0.5) and near(clocks.meteor, 13, 0.5)
				and near(clocks.charge, 15, 0.5) and near(clocks.cross, 17, 0.5) and clocks.gimmick == nil)
		r.check(("게이트 없음: 받는 피해 배율 %.3f, GateArmed=%s, 힌트 단계 %d"):format(
			MonsterState.getDamageTakenMultiplier(model), tostring(model:GetAttribute("GateArmed")), BossPatterns.getHintLevel(model)),
			MonsterState.getDamageTakenMultiplier(model) == 1 and model:GetAttribute("GateArmed") ~= true and BossPatterns.getHintLevel(model) == 0)
		local _, maxHp = MonsterState.getBossHp(model)
		local hpBefore = MonsterState.getBossHp(model)
		local _, dealt = MonsterState.applyDamage(model, maxHp * 0.01, BossData.stageInterval, player)
		local hpAfter = MonsterState.getBossHp(model)
		r.check(("보스 피해: 넣은 값 %.2f = 들어간 값 %.2f = HP 감소 %.2f"):format(maxHp * 0.01, dealt, hpBefore - hpAfter),
			near(dealt, maxHp * 0.01, 1e-6) and near(hpBefore - hpAfter, maxHp * 0.01, 1e-6))
		fullHeal(player)
		local chargeFraction = data.skills.charge.damage.fraction
		BossMechanics.beginActivation(model)
		BossMechanics.applyGimmickDamage(model, player, chargeFraction, "돌진(검증)")
		r.check(("돌진 %%피해 경로: 풀피에서 %.0f%% → 남은 %.1f%%(기대 %.1f%%) - 29-2에서 80 → 55%%, 생존"):format(
			chargeFraction * 100, hpFraction(player) * 100, (1 - chargeFraction) * 100),
			near(hpFraction(player), 1 - chargeFraction, 1e-6) and PlayerState.getHp(player) > 0)
		fullHeal(player)
	end)

	-- [3][4] %최대체력 피해 - 방어 우회, 1회로 안 죽는다, 기믹 1회 합계 상한
	r.section("%최대체력 피해", function()
		local model, data = spawnGuardian(player, env)
		-- 기준선: 같은 등급·같은 itemLevel의 장비·보석 8자리를 방어와 무관한 옵션(위력)으로 채운다 - 아래에서
		-- 옵션만 방어로 바꿔 끼우므로 두 측정의 차이는 방어 옵션 하나뿐이다.
		env.applyOptionStack(player, "attackPercent")
		local defenseBefore = PlayerProfile.getOptionBonus(player, "defensePercent")
		local normalBefore = PlayerDamage.computeHitDamage(data.attack, player) / PlayerState.getMaxHp(player)
		fullHeal(player)
		BossMechanics.onGimmickStart(model)
		BossMechanics.applyGimmickDamage(model, player, f, "기믹 실패(검증·방어 전)")
		local lostBefore = 1 - hpFraction(player)

		local ok, reason = env.applyOptionStack(player, "defensePercent")
		local defenseAfter = PlayerProfile.getOptionBonus(player, "defensePercent")
		local normalAfter = PlayerDamage.computeHitDamage(data.attack, player) / PlayerState.getMaxHp(player)
		fullHeal(player)
		BossMechanics.onGimmickStart(model)
		BossMechanics.applyGimmickDamage(model, player, f, "기믹 실패(검증·방어 후)")
		local lostAfter = 1 - hpFraction(player)
		r.check(("방어 옵션 %.1f%% → %.1f%%(stack=%s %s): 일반 평타 %.2f%% → %.2f%% maxHp(줄어든다), 기믹 실패 %.2f%% → %.2f%%(그대로)"):format(
			defenseBefore * 100, defenseAfter * 100, tostring(ok), tostring(reason or ""),
			normalBefore * 100, normalAfter * 100, lostBefore * 100, lostAfter * 100),
			ok == true and defenseAfter > defenseBefore and normalAfter < normalBefore * 0.95
				and near(lostBefore, f, 1e-6) and near(lostAfter, f, 1e-6))
		r.check(("기믹 실패 1회(풀피 기준): 남은 체력 %.1f%% > 0 - 죽지 않는다"):format(hpFraction(player) * 100),
			PlayerState.getHp(player) > 0 and near(hpFraction(player), 1 - f, 1e-6))

		fullHeal(player)
		BossMechanics.onGimmickStart(model)
		local partial = f / mechanics.partialFailDivisor
		for _ = 1, mechanics.partialFailDivisor do
			BossMechanics.applyGimmickDamage(model, player, partial, "부분 실패(검증)")
		end
		local _, appliedExtra = BossMechanics.applyGimmickDamage(model, player, f, "같은 발동의 전체 실패(검증)")
		r.check(("기믹 1회 합계 상한: 부분 실패 %d회 + 전체 실패 1회 → 잃은 체력 %.1f%%(기대 %.0f%%), 넘친 몫 적용 %.4f"):format(
			mechanics.partialFailDivisor, (1 - hpFraction(player)) * 100, f * 100, appliedExtra),
			near(1 - hpFraction(player), f, 1e-6) and appliedExtra == 0 and PlayerState.getHp(player) > 0)
		BossMechanics.reset(model)
		fullHeal(player)
	end)

	-- [5][6] 잡힘 진입·자동 해제·구출·전원 잡힘
	r.section("잡힘/구출", function()
		local model, data = spawnGuardian(player, env)
		local encounter = BossEncounter.getEncounter(player)
		fullHeal(player)

		local trapped = BossTrap.trap(player, { kind = "frozen", rescueType = "hitCount", autoReleaseSeconds = 0.6 })
		local again = BossTrap.trap(player, { kind = "frozen", rescueType = "hitCount", autoReleaseSeconds = 30 })
		local hitDamage = PlayerDamage.applyHit(player, data.attack, "평타(검증·잡힘 중)", 3)
		local percentDamage = BossMechanics.applyMaxHpDamage(player, 0.8, "돌진(검증·잡힘 중)")
		r.check(("잡힘 진입: trap=%s 재잡힘=%s(무시) isTrapped=%s/%s Attribute=%s 루트 고정=%s"):format(
			tostring(trapped), tostring(again), tostring(BossTrap.isTrapped(player)), tostring(PlayerState.isTrapped(player)),
			tostring(player:GetAttribute("BossTrapKind")), tostring(root.Anchored)),
			trapped and not again and BossTrap.isTrapped(player) and PlayerState.isTrapped(player)
				and player:GetAttribute("BossTrapKind") == "frozen" and root.Anchored == true)
		r.check(("잡힘 중 피해: 강타 %.2f · 돌진 80%% %.2f → 체력 %.1f%%(면역)"):format(hitDamage, percentDamage, hpFraction(player) * 100),
			hitDamage == 0 and percentDamage == 0 and near(hpFraction(player), 1, 1e-9))
		task.wait(0.9)
		r.check(("자동 해제(0.6초로 줄인 타이머): isTrapped=%s Attribute=%s 루트 고정=%s"):format(
			tostring(BossTrap.isTrapped(player)), tostring(player:GetAttribute("BossTrapKind")), tostring(root.Anchored)),
			not BossTrap.isTrapped(player) and not PlayerState.isTrapped(player)
				and player:GetAttribute("BossTrapKind") == nil and root.Anchored == false)

		-- 구출: 기본 타이머(9초)로 잡고 스탠드인 구출자가 진행을 채운다.
		local rescuer = { Name = "StandInRescuer", UserId = -9101, Parent = workspace, Character = nil }
		local startedAt = os.clock()
		BossTrap.trap(player, { kind = "submerged", rescueType = "proximity" })
		local record = BossTrap.getRecord(player)
		local autoSeconds = record and (record.releaseAt - record.startedAt) or -1
		BossTrap.addRescueProgress(player, rescuer, 0.5)
		local half = player:GetAttribute("BossTrapRescue")
		BossTrap.trap(rescuer, { kind = "submerged", rescueType = "proximity", autoReleaseSeconds = 30 }) -- 구출자가 잡힌다
		local afterRescuerTrapped = player:GetAttribute("BossTrapRescue")
		local blocked = BossTrap.addRescueProgress(player, rescuer, 1) -- 잡힌 사람은 구출 못 한다
		BossTrap.release(rescuer, "debug")
		r.check(("구출자가 잡히면: 진행 %.2f → %.2f(소멸), 잡힌 구출자의 구출 시도=%s(무시), 먼저 잡힌 사람은 여전히 잡힘=%s, 기본 자동 해제 %.1f초"):format(
			half or -1, afterRescuerTrapped or -1, tostring(blocked), tostring(BossTrap.isTrapped(player)), autoSeconds),
			half == 0.5 and afterRescuerTrapped == 0 and blocked == false and BossTrap.isTrapped(player)
				and near(autoSeconds, mechanics.trap.autoReleaseSeconds, 1e-6))
		BossTrap.addRescueProgress(player, rescuer, 0.5)
		local released = BossTrap.addRescueProgress(player, rescuer, 0.5)
		r.check(("구출 해제: 진행 1.0에서 풀림=%s, 걸린 시간 %.2f초 < 자동 해제 %.0f초, 루트 고정=%s"):format(
			tostring(released), os.clock() - startedAt, mechanics.trap.autoReleaseSeconds, tostring(root.Anchored)),
			released and not BossTrap.isTrapped(player) and root.Anchored == false)

		-- 전원 잡힘: 스탠드인 3명을 멤버로 넣고 4명 전부 잡는다 - 전멸이 아니다.
		local standIns = {}
		for i = 1, 3 do
			local standIn = { Name = "StandInTrap" .. i, UserId = -9110 - i, Parent = workspace, Character = nil }
			table.insert(standIns, standIn)
			BossEncounter.debugAddMember(model, standIn)
		end
		local hpBefore = MonsterState.getBossHp(model)
		for _, member in ipairs(encounter.members) do
			BossTrap.trap(member, { kind = "shocked", rescueType = "touch", autoReleaseSeconds = 0.6 })
		end
		local allTrapped = BossTrap.allTrapped(encounter.members)
		local nearest = BossEncounter.nearestLivingMember(model, model.PrimaryPart.Position)
		r.check(("4인 전원 잡힘: allTrapped=%s, 보스전 유지=%s, 생존 멤버 %d(전멸 아님), 보스 조준 대상=%s, 보스 HP 그대로=%s"):format(
			tostring(allTrapped), tostring(BossEncounter.getEncounter(player) == encounter), BossEncounter.livingMemberCount(encounter),
			tostring(nearest and nearest.Name), tostring(MonsterState.getBossHp(model) == hpBefore)),
			allTrapped and #encounter.members == 4 and BossEncounter.getEncounter(player) == encounter
				and BossEncounter.livingMemberCount(encounter) == 1 and nearest == player and MonsterState.getBossHp(model) == hpBefore)
		task.wait(0.9)
		local anyTrapped = false
		for _, member in ipairs(encounter.members) do
			anyTrapped = anyTrapped or BossTrap.isTrapped(member)
		end
		r.check(("전원 잡힘 → 각자 타이머로 해제: 남은 잡힘=%s"):format(tostring(anyTrapped)), not anyTrapped)
	end)

	-- [7] 파훼 게이트 + [4] 실제 판정 경로의 기믹 실패 + 힌트 단계
	r.section("파훼 게이트", function()
		local model, data = spawnGuardian(player, env)
		local judgeSafe = true
		BossMechanics.registerJudge("verify29", function()
			return judgeSafe
		end)
		injectGimmick(model, data, 0.4)
		local _, maxHp = MonsterState.getBossHp(model)
		local probe = maxHp * 0.001
		local members = { player }
		local function step()
			BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, members)
		end
		local function dealt()
			local _, amount = MonsterState.applyDamage(model, probe, BossData.stageInterval, player)
			return amount / probe
		end

		r.check(("기믹 전: 게이트 %s, 받는 피해 x%.3f"):format(tostring(BossMechanics.isGateArmed(model)), dealt()),
			not BossMechanics.isGateArmed(model) and MonsterState.getDamageTakenMultiplier(model) == 1)

		BossPatterns.force(model, data, "gimmick")
		step()
		local armedRatio = dealt()
		r.check(("첫 기믹 예고: phase=%s, 게이트 %s, GateArmed=%s, 실제 들어간 피해 x%.4f(기대 g=%.4f)"):format(
			BossPatterns.getPhase(model), tostring(BossMechanics.isGateArmed(model)), tostring(model:GetAttribute("GateArmed")), armedRatio, g),
			BossPatterns.getPhase(model) == "gimmickTelegraph" and BossMechanics.isGateArmed(model)
				and model:GetAttribute("GateArmed") == true and near(armedRatio, g, 1e-9))

		fullHeal(player)
		judgeSafe = true
		task.wait(0.5)
		step()
		local openRatio = dealt()
		r.check(("파훼 성공: phase=%s, 게이트 %s, 받는 피해 x%.3f, 플레이어 체력 %.0f%%(피해 없음), 잡힘=%s"):format(
			BossPatterns.getPhase(model), tostring(BossMechanics.isGateArmed(model)), openRatio, hpFraction(player) * 100, tostring(BossTrap.isTrapped(player))),
			BossPatterns.getPhase(model) == "normal" and not BossMechanics.isGateArmed(model) and near(openRatio, 1, 1e-9)
				and near(hpFraction(player), 1, 1e-9) and not BossTrap.isTrapped(player))

		-- 실패: 잡힘 종류가 있는 보스처럼 굴도록 이 인스턴스에만 서리 거인의 종류를 빌린다.
		data.mechanics = BossData.bosses.frost_giant.mechanics
		judgeSafe = false
		fullHeal(player)
		BossPatterns.force(model, data, "gimmick")
		step()
		task.wait(0.5)
		step()
		local failRatio = dealt()
		r.check(("파훼 실패: 게이트 %s(받는 피해 x%.4f), 플레이어 체력 %.1f%%(기대 %.0f%% - 1회로 안 죽는다), 잡힘=%s(%s)"):format(
			tostring(BossMechanics.isGateArmed(model)), failRatio, hpFraction(player) * 100, (1 - f) * 100,
			tostring(BossTrap.isTrapped(player)), tostring(player:GetAttribute("BossTrapKind"))),
			BossMechanics.isGateArmed(model) and near(failRatio, g, 1e-9) and near(hpFraction(player), 1 - f, 1e-6)
				and PlayerState.getHp(player) > 0 and BossTrap.isTrapped(player) and player:GetAttribute("BossTrapKind") == "frozen")

		-- 전멸 리셋: 게이트·잡힘이 처음 상태로, 힌트가 한 단계 오른다.
		-- resetFor는 "죽는 당사자"를 생존자에서 빼고 세므로 솔로면 항상 전멸 리셋이다(실제 Humanoid는 안 건드린다).
		local levelBefore = BossPatterns.getHintLevel(model)
		BossEncounter.resetFor(player)
		fullHeal(player)
		r.check(("전멸 리셋: 게이트 %s, 받는 피해 x%.1f, 잡힘=%s, 힌트 단계 %d → %d"):format(
			tostring(BossMechanics.isGateArmed(model)), MonsterState.getDamageTakenMultiplier(model), tostring(BossTrap.isTrapped(player)),
			levelBefore, BossPatterns.getHintLevel(model)),
			not BossMechanics.isGateArmed(model) and MonsterState.getDamageTakenMultiplier(model) == 1
				and not BossTrap.isTrapped(player) and levelBefore == 0 and BossPatterns.getHintLevel(model) == 1)
		BossEncounter.resetFor(player)
		BossEncounter.resetFor(player)
		r.check(("힌트 단계 상한: 전멸 3회 → %d단계(상한 %d), 같은 보스로 다시 들어가도 유지=%d"):format(
			BossPatterns.getHintLevel(model), mechanics.hint.maxLevel, BossEncounter.getHintLevel(player)),
			BossPatterns.getHintLevel(model) == mechanics.hint.maxLevel and BossEncounter.getHintLevel(player) == mechanics.hint.maxLevel)
	end)

	-- [2][11] 스케줄러 실시간 - 첫 기믹이 "시계 시작 + firstAvailableSeconds"에 실제로 시작하는가 + 틱 비용.
	-- 시계는 어그로가 붙는 순간 다시 시작된다(MonsterAI → BossPatterns.onAggro) - 그래서 os.clock 절대 시각이 아니라
	-- BossPatterns.debugClocks가 돌려주는 시계 시작 시각을 기준으로 잰다(29-1 Play의 교훈, 20.74 [6]).
	r.section("스케줄러 실시간", function()
		local model, data = spawnGuardian(player, env) -- 위 구역의 힌트 2단계가 이어진다(같은 보스) - 예고 x1.5 확인
		BossMechanics.registerJudge("verify29", function()
			return true
		end)
		local firstAt = injectGimmick(model, data, 0.4)
		local members = { player }
		local loopStartedAt = os.clock()
		local gimmickAt, telegraphEndAt, earlier, restarts = nil, nil, nil, 0
		local _, clockStartedAt = BossPatterns.debugClocks(model)
		local stepSeconds, stepCount = 0, 0
		while os.clock() - loopStartedAt < firstAt * 4 do
			RunService.Heartbeat:Wait()
			local before = os.clock()
			BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, members)
			stepSeconds += os.clock() - before
			stepCount += 1
			local _, startedAt, currentId = BossPatterns.debugClocks(model)
			if startedAt ~= clockStartedAt then
				clockStartedAt, earlier = startedAt, nil -- 어그로로 시계가 다시 시작됐다 - 거기서부터 다시 잰다
				restarts += 1
			end
			if currentId == "gimmick" and not gimmickAt then
				gimmickAt = os.clock() - clockStartedAt
			elseif gimmickAt and not telegraphEndAt and currentId ~= "gimmick" then
				telegraphEndAt = os.clock() - clockStartedAt
			elseif currentId and not gimmickAt then
				earlier = currentId
			end
			if telegraphEndAt then
				break
			end
		end
		r.check(("첫 기믹 시작 = 시계 시작 + %.2f초(기대 %d, 허용 +-0.25) - 그 전에 끼어든 스킬=%s(자리 비우기), 어그로 재시작 %d회"):format(
			gimmickAt or -1, firstAt, tostring(earlier), restarts),
			near(gimmickAt, firstAt, 0.25) and earlier == nil)
		local telegraph = (telegraphEndAt or 0) - (gimmickAt or 0)
		r.check(("힌트 2단계 예고 시간: %.2f초(기대 0.4 x %.1f = %.2f)"):format(telegraph, mechanics.hint.telegraphMultiplier, 0.4 * mechanics.hint.telegraphMultiplier),
			near(telegraph, 0.4 * mechanics.hint.telegraphMultiplier, 0.1))
		local perStep = stepSeconds / math.max(stepCount, 1)
		print(("[29-1][나] 성능: BossPatterns.step 평균 %.1f마이크로초/틱(%d틱, 자리 비우기·구출 틱 포함) → 보스전 12개 동시 x 60Hz = 초당 %.2fms"):format(
			perStep * 1e6, stepCount, perStep * 12 * 60 * 1000))
		r.check("성능: step 평균 < 100마이크로초(12 보스전 x 60Hz < 72ms/초 = 프레임당 1.2ms)", perStep < 100e-6)
	end)

	-- [10] 흡혈 - 기믹 실패(55%)를 상한(4%/초)으로 몇 초에 되돌리는가(실시간 2초 측정)
	r.section("흡혈", function()
		local ok = env.applyOptionStack(player, "lifesteal")
		local maxHp = PlayerState.getMaxHp(player)
		PlayerState.setHp(player, maxHp * (1 - f))
		PlayerProfile.applyLifesteal(player, maxHp * 10) -- 가득 찬 버킷을 먼저 비운다
		local startHp = PlayerState.getHp(player)
		local startedAt = os.clock()
		for _ = 1, 20 do
			task.wait(0.1)
			PlayerProfile.applyLifesteal(player, maxHp * 10)
		end
		local rate = (PlayerState.getHp(player) - startHp) / maxHp / (os.clock() - startedAt)
		r.check(("흡혈(stack=%s): 실측 %.2f%%/초(상한 %.0f%%) → 기믹 실패 %.0f%% 회복에 공격 %.1f초(기대 13.75초 - 기믹 주기 안, 그래서 %%가 아니라 잡힘·게이트로 막는다)"):format(
			tostring(ok), rate * 100, CombatConfig.lifestealMaxHpFractionPerSecond * 100, f * 100, f / math.max(rate, 1e-9)),
			ok == true and rate > 0.035 and rate <= CombatConfig.lifestealMaxHpFractionPerSecond * 1.02)
		fullHeal(player)
	end)

	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player) -- 검증이 올린 힌트 단계를 남기지 않는다
	env.restore(player)
	local passCount, totalCount = r.summary()
	print(("===29-1 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

function BossMechanicsVerify.run(player, env)
	runPure()
	runLive(player, env)
end

return BossMechanicsVerify
