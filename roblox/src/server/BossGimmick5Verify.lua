-- 29-5 자동 검증(PRD 20.80) - 보스 배치 고정 · F 홀드 구출 · 수정 여왕(대상 선택) · 6종 튜닝 · 탱커 훅.
-- BossGimmick4Verify(29-4)와 같은 패턴이고 DevTools가 그 뒤에 이어서 부른다(같은 플레이어·같은 아레나 - 동시에 돌면 안 된다).
--   (가) 순수 계산 - 배치표·스킬표·모형. 로컬 Luau 하네스와 같은 값.
--   (나) 실제 서버 경로 - 실제 Player의 프로필·스폰 경로를 그대로 탄다.
-- env = { ensureBackup, restore, applyStage, applyOptionStack } - DevTools의 로컬 헬퍼.
-- 29-4의 교훈(X 4건이 전부 스탠드인과 읽는 시점): 스탠드인은 실제 Player가 받는 호출(SetAttribute·GetAttribute·FireClient 대상)을
-- 전부 받을 수 있어야 하고, 상태는 그것을 만드는 틱이 **지난 뒤에** 읽는다(drive 뒤).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local BossScheduler = require(ReplicatedStorage.Shared.BossScheduler)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossEncounter = require(script.Parent.BossEncounter)
local BossMechanics = require(script.Parent.BossMechanics)
local BossPatterns = require(script.Parent.BossPatterns)
local BossTrap = require(script.Parent.BossTrap)
local MonsterState = require(script.Parent.MonsterState)
local PartyState = require(script.Parent.PartyState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)

local BossGimmick5Verify = {}

local GUARDIAN = "section_guardian"

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[29-5][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

-- ─────────────────────────── (가) 순수 계산 ───────────────────────────

-- 보스 배치(PRD 20.80 [A]) - 다른 구역이 아직 없는 로컬 하네스에서도 이 함수만 따로 부를 수 있게 떼어 둔다.
function BossGimmick5Verify.checkPlacement(r)
	local interval = BossData.stageInterval
	local allIds = BossData.pools[1].bossIds

	r.section("배치표 규칙", function()
		local problems = BossRules.validatePlacement()
		local laps = BossData.placement.laps
		-- 이웃 쌍(A 다음에 B)이 주기 안에서 되풀이되지 않는가 - 바퀴마다 흐름이 다르다는 것의 검사
		local pairSeen, repeatedPairs = {}, 0
		for _, lap in ipairs(laps) do
			for i = 1, #lap - 1 do
				local key = lap[i] .. ">" .. lap[i + 1]
				if pairSeen[key] then
					repeatedPairs += 1
				end
				pairSeen[key] = true
			end
		end
		r.check(("배치표 %d바퀴 × %d마리: 규칙 위반 %d건%s · 바퀴 안에서 되풀이되는 이웃 쌍 %d건(기대 0 - 바퀴마다 흐름이 다르다)"):format(
			#laps, #laps[1], #problems, #problems > 0 and (" [" .. table.concat(problems, " / ") .. "]") or "", repeatedPairs),
			#problems == 0 and repeatedPairs == 0)
	end)

	r.section("첫 바퀴", function()
		local seen, names = {}, {}
		for n = 2, #allIds do
			local id = BossRules.bossIdForStage(n * interval)
			seen[id] = (seen[id] or 0) + 1
			table.insert(names, ("%d=%s"):format(n * interval, tostring(id)))
		end
		local allOnce = seen[GUARDIAN] == nil
		for _, id in ipairs(allIds) do
			if id ~= GUARDIAN then
				allOnce = allOnce and seen[id] == 1
			end
		end
		r.check(("첫 보스 스테이지 %d = %s(기대 %s = 견습 보스) · 그다음 다섯 [%s]에 나머지 5종이 한 번씩=%s"):format(
			interval, tostring(BossRules.bossIdForStage(interval)), BossData.tutorialBossId, table.concat(names, " "), tostring(allOnce)),
			BossRules.bossIdForStage(interval) == BossData.tutorialBossId and BossData.tutorialBossId == GUARDIAN and allOnce)
	end)

	r.section("연속 등장·바퀴 경계", function()
		local perLap = #BossData.placement.laps[1]
		local minGap, consecutive, boundaryRepeats, checked = math.huge, 0, 0, 2000
		local lastAt = {}
		local previous
		for n = 1, checked do
			local id = BossRules.bossIdForStage(n * interval)
			if id == previous then
				consecutive += 1
				if (n - 1) % perLap == 0 then
					boundaryRepeats += 1
				end
			end
			if lastAt[id] then
				minGap = math.min(minGap, n - lastAt[id])
			end
			lastAt[id] = n
			previous = id
		end
		r.check(("보스 스테이지 %d개(스테이지 %d까지): 같은 보스 연속 %d건(바퀴 경계 %d건) · 같은 보스가 다시 나오기까지 최소 %d마리(기대 ≥ %d)"):format(
			checked, checked * interval, consecutive, boundaryRepeats, minGap, BossData.placement.minRepeatGap),
			consecutive == 0 and boundaryRepeats == 0 and minGap >= BossData.placement.minRepeatGap)
	end)

	r.section("스테이지만의 함수", function()
		-- 인자가 stage 하나뿐인가(플레이어·프로필을 받을 자리가 없다) · 같은 입력 = 같은 출력 · 보스 스테이지가 아니면 nil · 아주 큰 스테이지
		local arity, isVararg = debug.info(BossRules.bossIdForStage, "a")
		local stable = true
		for n = 1, 200 do
			local first = BossRules.bossIdForStage(n * interval)
			for _ = 1, 3 do
				stable = stable and BossRules.bossIdForStage(n * interval) == first
			end
		end
		local period = #BossData.placement.laps * #BossData.placement.laps[1] * interval
		local far = 1e9 * interval
		r.check(("bossIdForStage의 인자 %d개(가변 %s) · 같은 스테이지 200개 × 4회 같은 값=%s · 일반 스테이지 %d·0 → %s·%s · 주기 %d스테이지: f(20)=%s = f(20 + 주기)=%s · 스테이지 %.0f → %s"):format(
			arity, tostring(isVararg), tostring(stable), interval + 1, tostring(BossRules.bossIdForStage(interval + 1)), tostring(BossRules.bossIdForStage(0)),
			period, tostring(BossRules.bossIdForStage(20)), tostring(BossRules.bossIdForStage(20 + period)), far, tostring(BossRules.bossIdForStage(far))),
			arity == 1 and not isVararg and stable and BossRules.bossIdForStage(interval + 1) == nil and BossRules.bossIdForStage(0) == nil
				and BossRules.bossIdForStage(20) == BossRules.bossIdForStage(20 + period) and BossData.bosses[BossRules.bossIdForStage(far)] ~= nil)
	end)
end

-- 수정 여왕(PRD 20.80 [C]) - 분열이 켜진 스킬표의 회피 부등식·인접 피해 합·모형, 그리고 "한 번의 분열에서 받는 벌의 합 ≤ 55%"의 산수.
local function checkCrystal(r)
	local CRYSTAL = "crystal_queen"
	r.section("수정 여왕 스킬표", function()
		local boss = BossData.bosses[CRYSTAL]
		local skill = boss.skills.split
		local mechanics = BossData.mechanics
		local _, dodgeOk = BossSim.checkDodge(CRYSTAL, 1, WorldConfig.playerWalkSpeedStuds)
		local _, wideOk = BossSim.checkDodge(CRYSTAL, BossRules.maxSkillRangeScale(), WorldConfig.playerWalkSpeedStuds)
		local _, violations = BossSim.checkPairs(CRYSTAL)
		local reach, guard = skill.dodge.distanceStuds, nil
		for _, condition in ipairs(skill.conditions or {}) do
			if condition.type == "memberWithin" then
				guard = condition.studs
			end
		end
		local partial = mechanics.gimmickFailMaxHpFraction / mechanics.partialFailDivisor
		local decoys = skill.split.count - 1
		r.check(("분열 켜짐=%s · 회피 부등식 통과(배율 1·최대)=%s·%s · 인접 쌍 위반 %d건 · 도달 가능성: 발동 조건 %s + 분열 반경 %d = 회피 거리 %d · 벌의 합: 분신 %d체 × %.1f%% = %.1f%% ≤ 상한 %.0f%%(폭풍은 나머지까지만) · 말풍선 키 %s(보스 머리 위 말풍선은 진짜를 가리킨다)"):format(
			tostring(skill.enabled ~= false), tostring(dodgeOk), tostring(wideOk), violations, tostring(guard), skill.split.radiusStuds, reach,
			decoys, partial * 100, decoys * partial * 100, mechanics.gimmickFailMaxHpFraction * 100, tostring(skill.bubble)),
			skill.enabled ~= false and dodgeOk and wideOk and violations == 0 and guard ~= nil and guard + skill.split.radiusStuds == reach
				and decoys * partial <= mechanics.gimmickFailMaxHpFraction + 1e-9 and skill.bubble == "none" and skill.failTraps == false)
	end)
	r.section("수정 여왕 모형", function()
		local base = BossSim.run("section_guardian", { partySize = 1 }).seconds
		local live, live4 = BossSim.run(CRYSTAL, { partySize = 1 }).seconds, BossSim.run(CRYSTAL, { partySize = 4 }).seconds
		local design = BossSim.run(CRYSTAL, { partySize = 1, design = true, breaks = "always" }).seconds
		local never = BossSim.run(CRYSTAL, { partySize = 1, design = true, breaks = "never" }).seconds
		local first = BossSim.run(CRYSTAL, { partySize = 1 }).sequence[1]
		r.check(("결정 모형: 지금 %.2f / %.2f초 = 설계 %.2f초(기준 %.2f 대비 %+.1f%%) · 파훼 전 %.2f초(x%.2f) · 첫 스킬 %s@%.2f"):format(
			live, live4, design, base, (live / base - 1) * 100, never, never / live, first.id, first.at),
			math.abs(live - design) < 0.06 and math.abs(live / base - 1) <= 0.10 and never / live >= 1.8 and never / live <= 2.7)
	end)
end

-- [9][10][11] 6종 튜닝(PRD 20.80 [D]) - 기믹이 전부 켜진 상태의 몬테카를로·회피 부등식·2연타·첫 기믹.
--   파훼 후 = 구간 수호자의 같은 인원 평균 ±10% / 초회(파훼 전) = 파훼 후의 1.8 ~ 2.7배 / 회피 부등식은 배율 1과 최대 배율 둘 다 /
--   인접 쌍의 "실수 2회" 합 100% 미만 / 첫 기믹은 자리 비우기로 보장된 시각(서리 16 · 폭풍 8 · 나머지 10초)에.
local TUNING_RUNS = 100
local function checkTuning(r)
	local ids = BossData.pools[1].bossIds
	r.section("6종 몬테카를로", function()
		local base = {}
		for _, n in ipairs({ 1, 4 }) do
			base[n] = BossSim.monteCarlo(GUARDIAN, { partySize = n, breaks = "always" }, TUNING_RUNS).mean
		end
		for _, bossId in ipairs(ids) do
			if bossId ~= GUARDIAN then
				local cells, ok = {}, true
				for _, n in ipairs({ 1, 4 }) do
					local after = BossSim.monteCarlo(bossId, { partySize = n, breaks = "always" }, TUNING_RUNS)
					local never = BossSim.monteCarlo(bossId, { partySize = n, breaks = "never" }, TUNING_RUNS)
					local delta, ratio = after.mean / base[n] - 1, never.mean / after.mean
					ok = ok and math.abs(delta) <= 0.10 and ratio >= 1.8 and ratio <= 2.7 and after.minGimmickCount >= 1
					table.insert(cells, ("%d인 파훼 후 %.1f초(%+.1f%%) · 초회 %.1f초(x%.2f) · 첫 기믹 %.2f초·최소 %d회"):format(
						n, after.mean, delta * 100, never.mean, ratio, after.latestFirstGimmickAt, after.minGimmickCount))
				end
				r.check(("%s: %s"):format(bossId, table.concat(cells, " | ")), ok)
			end
		end
	end)
	r.section("6종 회피 부등식·2연타", function()
		local rows, failed, pairCount, violations, worst = 0, {}, 0, 0, 0
		for _, bossId in ipairs(ids) do
			for _, scale in ipairs({ 1, BossRules.maxSkillRangeScale() }) do
				local checks = BossSim.checkDodge(bossId, scale, WorldConfig.playerWalkSpeedStuds)
				for _, check in ipairs(checks) do
					rows += 1
					if not check.ok then
						table.insert(failed, ("%s.%s x%.2f"):format(bossId, check.skillId, scale))
					end
				end
			end
			local pairRows, bad = BossSim.checkPairs(bossId)
			pairCount += #pairRows
			violations += bad
			for _, row in ipairs(pairRows) do
				if row.possible then
					worst = math.max(worst, row.share)
				end
			end
		end
		r.check(("회피 부등식 %d판정(6종 × 배율 1·최대, 속도 %d) 실패 %d건%s · 인접 쌍 %d개 중 100%% 이상인 가능한 쌍 %d건(최악 %.1f%%)"):format(
			rows, WorldConfig.playerWalkSpeedStuds, #failed, #failed > 0 and (" [" .. table.concat(failed, ", ") .. "]") or "", pairCount, violations, worst * 100),
			#failed == 0 and violations == 0 and worst < 1)
	end)
end

-- [12] 탱커 대비 훅 4종(PRD 20.80 [F]) - 자리가 있고, **비어 있는가**(지금의 전투를 하나도 바꾸지 않는가).
local function checkTankHooks(r)
	r.section("탱커 훅", function()
		local flagged, total = {}, 0
		for _, bossId in ipairs(BossData.pools[1].bossIds) do
			for id, skill in pairs(BossData.bosses[bossId].skills) do
				total += 1
				if BossSkillMath.isReflectable(skill) then
					table.insert(flagged, bossId .. "." .. id)
				end
			end
		end
		table.sort(flagged)
		local state = BossScheduler.newState({ a = { cooldownSeconds = 5, priority = 0 } }, { "a" }, 0)
		local beforeEnd, beforeLast = state.lastEndAt, state.lastSkillId
		BossScheduler.noteTaunt(state, 3)
		local untouched = state.lastEndAt == beforeEnd and state.lastSkillId == beforeLast and state.tauntedAt == 3
		local fakeModel = {}
		local emptyBefore = BossMechanics.reflectBufferOf(fakeModel) == nil
		local buffer = BossMechanics.addToReflectBuffer(fakeModel, "tank", "dealer", 10)
		BossMechanics.addToReflectBuffer(fakeModel, "tank", "dealer", 5)
		local taken = BossMechanics.clearReflectBuffer(fakeModel)
		local bufferOk = emptyBefore and buffer.total == 15 and buffer.byPlayer.dealer == 15 and buffer.bounces == 0 and buffer.owner == "tank"
			and taken == buffer and BossMechanics.reflectBufferOf(fakeModel) == nil
		r.check(("① 반사 가능 플래그: 스킬 %d개 중 %d개[%s] · ② 도발 진입점: BossPatterns.onTaunt=%s, 스케줄러는 시각만 적는다(전역 쿨·직전 스킬 그대로)=%s · ③ 무게 계수: 기본 %.1f(전원) = weightFactorOf %.1f · ④ 반사 버퍼: 비어 있음 → 쌓기 15 → 비우기=%s(채우는 제품 코드 없음)"):format(
			total, #flagged, table.concat(flagged, " "), type(BossPatterns.onTaunt), tostring(untouched), BossData.mechanics.tank.defaultWeightFactor,
			BossMechanics.weightFactorOf(nil), tostring(bufferOk)),
			#flagged == 5 and type(BossPatterns.onTaunt) == "function" and untouched and BossData.mechanics.tank.defaultWeightFactor == 1
				and BossMechanics.weightFactorOf(nil) == 1 and bufferOk)
	end)
end

local function runPure()
	print("===29-5 검증 시작(가: 배치표·수정 여왕·6종 튜닝·탱커 훅)===")
	local r = newRecorder("가")
	BossGimmick5Verify.checkPlacement(r)
	checkCrystal(r)
	checkTuning(r)
	checkTankHooks(r)
	local pass, total = r.summary()
	print(("===29-5 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 서버 경로 ───────────────────────────

local function spawnAt(player, env, stage)
	BossEncounter.despawnFor(player)
	env.applyStage(player, stage)
	BossEncounter.spawnFor(player, stage)
	local model = BossEncounter.getActive(player)
	return model, model and MonsterState.getData(model)
end

local function spawnBoss(player, env, bossId)
	BossEncounter.setDebugForcedBoss(player, bossId)
	return spawnAt(player, env, BossData.stageInterval)
end

local function fullHeal(player)
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	PlayerDamage.syncHud(player)
end

local function moveTo(root, position)
	root.CFrame = CFrame.new(position)
	RunService.Heartbeat:Wait()
end

-- 스탠드인 멤버(테이블 Player - Studio에서 Instance가 아니다). 실제 Player가 받는 호출을 전부 받는다(29-4의 교훈):
-- 피해를 받으면 PlayerDamage.syncHud가 SetAttribute를, 잡히면 BossTrap이 Name·Character를 읽는다.
local function newStandIn(model, members, name, position)
	local fakeRoot = { Position = position, Anchored = false }
	local attributes = {}
	local fake = { Name = name, DisplayName = name, UserId = -9500 - #members, Parent = workspace }
	fake.Character = {
		FindFirstChild = function(_, child)
			return child == "HumanoidRootPart" and fakeRoot or nil
		end,
		FindFirstChildOfClass = function()
			return nil
		end,
	}
	function fake:SetAttribute(key, value)
		attributes[key] = value
	end
	function fake:GetAttribute(key)
		return attributes[key]
	end
	PlayerState.init(fake)
	table.insert(members, fake)
	BossEncounter.debugAddMember(model, fake)
	return fake, fakeRoot
end

local function clearStandIns(player, members)
	local encounter = BossEncounter.getEncounter(player)
	for index = #members, 2, -1 do
		BossTrap.release(members[index], "reset")
		PlayerState.clear(members[index])
		if encounter then
			local at = table.find(encounter.members, members[index])
			if at then
				table.remove(encounter.members, at)
			end
		end
		table.remove(members, index)
	end
end

-- [6] F 홀드 구출(PRD 20.80 [B]). 잡히는 쪽은 **실제 Player**다 - 실제 루트에 실제 ProximityPrompt가 붙는지(= PC F · 모바일 화면
-- 버튼 · 게임패드)를 인스턴스로 본다. 누르는 쪽은 프롬프트의 신호가 부르는 바로 그 함수(BossTrap.beginHold/endHold)를 부른다.
-- 캐릭터는 어그로 밖(60stud)에 둔다 - 가까우면 MonsterAI도 같은 보스를 step해 홀드가 두 배로 찬다(29-3의 교훈).
local function runHoldRescue(player, env, r, root)
	local mechanics = BossData.mechanics
	local holdSeconds = mechanics.trap.rescueSeconds

	r.section("F 홀드 프롬프트", function()
		local rows, allOk = {}, true
		for _, bossId in ipairs(BossData.pools[1].bossIds) do
			local species = BossData.bosses[bossId].mechanics
			local reach = species and mechanics.rescue[species.rescueType] and mechanics.rescue[species.rescueType].reachStuds
			if reach then
				local model, data = spawnBoss(player, env, bossId)
				moveTo(root, model.PrimaryPart.Position + Vector3.new(60, 1.5, 0))
				BossMechanics.trapMember(model, data, player)
				local prompt = root:FindFirstChild("BossRescuePrompt")
				local ok = prompt ~= nil and prompt:IsA("ProximityPrompt") and prompt.HoldDuration == holdSeconds
					and prompt.KeyboardKeyCode == Enum.KeyCode[mechanics.rescue.hold.keyCode] and prompt.MaxActivationDistance == reach
					and prompt.RequiresLineOfSight == false and prompt.ClickablePrompt == true and prompt.Enabled == true
					and prompt.Style == Enum.ProximityPromptStyle.Default
				BossTrap.release(player, "reset")
				ok = ok and root:FindFirstChild("BossRescuePrompt") == nil -- 풀리면 프롬프트도 사라진다
				allOk = allOk and ok
				table.insert(rows, ("%s(%s·%dstud)=%s"):format(bossId, species.rescueType, reach, ok and "O" or "X"))
			end
		end
		-- 모바일: 기본 스타일 + ClickablePrompt면 터치 기기에서 로블록스가 누르고 있을 수 있는 화면 버튼을 그린다(직접 짠 입력이 없다)
		r.check(("잡힌 실제 Player의 루트에 구출 프롬프트(홀드 %.1f초 · 키 %s · 시야 무시 · 기본 스타일 + ClickablePrompt = 모바일 화면 버튼): %s · 끊김 알림 RemoteEvent=%s"):format(
			holdSeconds, mechanics.rescue.hold.keyCode, table.concat(rows, " "), tostring(ReplicatedStorage:FindFirstChild("BossRescueHoldBroken") ~= nil)),
			allOk and #rows == 5 and ReplicatedStorage:FindFirstChild("BossRescueHoldBroken") ~= nil)
	end)

	r.section("F 홀드 진행·피격 리셋", function()
		local model, data = spawnBoss(player, env, "frost_giant")
		local st = MonsterState.getBossPatternState(model)
		local bossPosition = model.PrimaryPart.Position
		local members = { player }
		moveTo(root, bossPosition + Vector3.new(60, 1.5, 0))
		local function step(count)
			for _ = 1, count or 1 do
				BossPatterns.step(model, data, bossPosition, player, root, 1 / 60, members)
			end
		end
		fullHeal(player)
		BossMechanics.trapMember(model, data, player)
		local rescuer, rescuerRoot = newStandIn(model, members, "StandInHolder", root.Position + Vector3.new(5, 0, 0))
		step(30)
		local idle = player:GetAttribute("BossTrapRescue") or 0
		local accepted = BossTrap.beginHold(player, rescuer)
		step(60)
		local held = player:GetAttribute("BossTrapRescue") or 0
		PlayerDamage.applyHit(rescuer, data.attack, nil, data.basicAttackDamageMultiplier) -- 보스 평타의 경로(MonsterAI가 부르는 함수)
		step(1)
		local afterBasic = player:GetAttribute("BossTrapRescue") or 0
		-- 예고 있는 피격: 실제 스킬 경로 - 낙빙은 (안 잡힌) 멤버 각자의 발밑에 떨어진다. 가만히 서서 누르던 구출자가 맞는다.
		BossPatterns.force(model, data, "icefall")
		step(1)
		st.phaseEndsAt = os.clock()
		step(2)
		local afterSkill = player:GetAttribute("BossTrapRescue") or 0
		local rescuerHp = PlayerState.getHp(rescuer) / PlayerState.getMaxHp(rescuer)
		step(30)
		local withoutRepress = player:GetAttribute("BossTrapRescue") or 0
		BossPatterns.interrupt(model, data)
		BossTrap.beginHold(player, rescuer)
		local ticks = 0
		while BossTrap.isTrapped(player) and ticks < 150 do
			step(1)
			ticks += 1
		end
		r.check(("곁에 서 있기만 하면 진행 %.2f(기대 0) → F 홀드 받아들임=%s, 1.0초 뒤 %.2f(기대 0.67) → 보스 평타를 맞아도 %.2f(그대로 - 평타는 끊지 않는다) → 낙빙(예고 있는 스킬)에 맞음(체력 %.0f%%): %.2f(기대 0 - 처음부터) → 다시 안 누르면 %.2f → 다시 눌러 %d틱(기대 90 = %.1f초) 만에 풀림=%s"):format(
			idle, tostring(accepted), held, afterBasic, rescuerHp * 100, afterSkill, withoutRepress, ticks, holdSeconds, tostring(not BossTrap.isTrapped(player))),
			idle == 0 and accepted and math.abs(held - 60 / 90) < 0.03 and afterBasic >= held and rescuerHp < 1 and afterSkill == 0 and withoutRepress == 0
				and ticks >= 89 and ticks <= 92 and not BossTrap.isTrapped(player))

		-- 둘이 같이 누르면 절반 + 누르는 쪽이 실제 Player일 때(끊김 알림이 실제 클라로 간다)
		task.wait(mechanics.trap.releaseGraceSeconds + 0.2)
		BossPatterns.interrupt(model, data)
		fullHeal(player)
		BossMechanics.trapMember(model, data, player)
		local second, secondRoot = newStandIn(model, members, "StandInHolder2", root.Position + Vector3.new(-5, 0, 0))
		rescuerRoot.Position = root.Position + Vector3.new(5, 0, 0)
		BossTrap.beginHold(player, rescuer)
		BossTrap.beginHold(player, second)
		local pairTicks = 0
		while BossTrap.isTrapped(player) and pairTicks < 150 do
			step(1)
			pairTicks += 1
		end

		task.wait(mechanics.trap.releaseGraceSeconds + 0.2)
		fullHeal(player)
		BossTrap.trap(second, { kind = "frozen", rescueType = "hitCount", context = { origin = secondRoot.Position } })
		moveTo(root, secondRoot.Position + Vector3.new(4, 0, 0))
		local realAccepted = BossTrap.beginHold(second, player)
		step(45)
		-- 진행은 기록에서 읽는다 - BossTrapRescue Attribute는 잡힌 쪽이 실제 Player일 때만 쓴다(1회차 Play: 스탠드인의 Attribute를 읽어 0이 나왔다)
		local function progressOf(trapped, rescuer)
			local record = BossTrap.getRecord(trapped)
			return record and record.progressBy[rescuer] or 0
		end
		local realHeld = progressOf(second, player)
		BossMechanics.beginActivation(model)
		BossMechanics.applyGimmickDamage(model, player, 0.1, "검증 - 예고 있는 피격") -- %피해 문(기믹 실패·돌진·구덩이·반사가 지나는 곳)
		local realAfter = progressOf(second, player)
		r.check(("둘이 같이 누르면 %d틱(기대 45 = %.2f초) · 실제 Player가 누르는 쪽: 받아들임=%s, 0.75초 뒤 %.2f(기대 0.50) → %%피해를 맞으면 %.2f(기대 0), 본인 체력 %.0f%%"):format(
			pairTicks, holdSeconds / 2, tostring(realAccepted), realHeld, realAfter, PlayerState.getHp(player) / PlayerState.getMaxHp(player) * 100),
			pairTicks >= 44 and pairTicks <= 47 and realAccepted and math.abs(realHeld - 0.5) < 0.03 and realAfter == 0)
		clearStandIns(player, members)
		fullHeal(player)
	end)
end

-- [8][13] 수정 여왕의 프리즘 분열(PRD 20.80 [C]). 분신을 때리는 쪽은 **실제 Player**이고 실제 피해 경로(MonsterState.applyDamage -
-- 평타·스킬·투사체가 전부 지나는 곳)로 때린다. 캐릭터는 어그로 밖(30stud - 발동 조건 40 안)에 둔다.
local function decoyModels()
	local list = {}
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isDecoy then
			table.insert(list, model)
		end
	end
	return list
end

local function runSplit(player, env, r, root)
	local mechanics = BossData.mechanics
	r.section("프리즘 분열", function()
		local model, data = spawnBoss(player, env, "crystal_queen")
		local st = MonsterState.getBossPatternState(model)
		local bossPosition = model.PrimaryPart.Position
		local members = { player }
		moveTo(root, bossPosition + Vector3.new(30, 1.5, 0))
		fullHeal(player)
		local function step(count)
			for _ = 1, count or 1 do
				BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, members)
			end
		end
		local skill = data.skills.split
		local spawnStartedAt = os.clock()
		BossPatterns.force(model, data, "split")
		step(1)
		local spawnSeconds = os.clock() - spawnStartedAt
		local decoys = decoyModels()
		local sameLook = #decoys == skill.split.count - 1
		local bossParts = #model:GetDescendants()
		for _, decoy in ipairs(decoys) do
			sameLook = sameLook and decoy.Name == model.Name and decoy.Body.Size == model.Body.Size and decoy.Body.Color == model.Body.Color
				and decoy.Head.Color == model.Head.Color and #decoy:GetDescendants() == bossParts and decoy:GetAttribute("GateArmed") == true
				and MonsterState.getHpRatio(decoy) == MonsterState.getHpRatio(model)
		end
		local moved = (model.PrimaryPart.Position - bossPosition).Magnitude
		r.check(("분열 시작: 분신 %d체 · 진짜와 겉모습이 같다(이름·몸통 크기·색·하위 인스턴스 %d개·게이트 표식·HP바)=%s · 보스가 분열 반경 %dstud 자리로 옮겨 감 %.1f · 게이트 x%.3f · 켜짐=%s"):format(
			#decoys, bossParts, tostring(sameLook), skill.split.radiusStuds, moved, MonsterState.getDamageTakenMultiplier(model), tostring(skill.enabled ~= false)),
			sameLook and math.abs(moved - skill.split.radiusStuds) < 0.5 and BossMechanics.isGateArmed(model) and skill.enabled ~= false)

		-- 분신을 때린다(실제 Player · 실제 피해 경로) → 18.3% + 결정화 + 그 분신만 깨진다. 결정화에도 F 홀드 프롬프트가 붙는다
		local _, dealt = MonsterState.applyDamage(decoys[1], 1e9, BossData.stageInterval, player)
		task.wait() -- 벌은 그 틱이 끝난 뒤에 매긴다(task.defer - 같은 틱에 진짜도 맞은 광역기를 면제하려고)
		step(1)
		local hpAfterDecoy = PlayerState.getHp(player) / PlayerState.getMaxHp(player)
		local kind = player:GetAttribute("BossTrapKind")
		local prompt = root:FindFirstChild("BossRescuePrompt")
		r.check(("분신을 때림: 들어간 피해 %.0f(기대 0 - 보상·흡혈 없음), 체력 %.1f%%(기대 %.1f), 잡힘 %s, 남은 분신 %d, 결정화에도 구출 프롬프트=%s"):format(
			dealt, hpAfterDecoy * 100, (1 - mechanics.gimmickFailMaxHpFraction / mechanics.partialFailDivisor) * 100, tostring(kind), #decoyModels(), tostring(prompt ~= nil)),
			dealt == 0 and math.abs(hpAfterDecoy - (1 - mechanics.gimmickFailMaxHpFraction / mechanics.partialFailDivisor)) < 1e-6
				and kind == "crystallized" and #decoyModels() == skill.split.count - 2 and prompt ~= nil)

		-- 친구(스탠드인)가 진짜를 때린다 → 분신 소멸 · 결정화 해제 · 기절(기회 창)
		local friend = newStandIn(model, members, "StandInFinder", model.PrimaryPart.Position + Vector3.new(8, 0, 0))
		MonsterState.applyDamage(model, 1, BossData.stageInterval, friend)
		step(2)
		r.check(("진짜를 때림: 남은 분신 %d, 본인 결정화 풀림=%s, phase=%s, 받는 피해 x%.2f(기대 %.2f), 본인 체력 %.1f%%(폭풍 없음)"):format(
			#decoyModels(), tostring(not BossTrap.isTrapped(player)), tostring(BossPatterns.getPhase(model)), MonsterState.getDamageTakenMultiplier(model),
			skill.breakWindow.damageTakenMultiplier, PlayerState.getHp(player) / PlayerState.getMaxHp(player) * 100),
			#decoyModels() == 0 and not BossTrap.isTrapped(player) and BossPatterns.getPhase(model) == "gimmickRecover"
				and math.abs(MonsterState.getDamageTakenMultiplier(model) - skill.breakWindow.damageTakenMultiplier) < 1e-6)

		-- 제한 시간을 넘긴다 → 파편 폭풍: 이미 받은 몫을 뺀 나머지까지만(합계 55%), 잡힘 없음. 셋 다 틀린 사람에게 폭풍은 0
		task.wait(mechanics.trap.releaseGraceSeconds + 0.2)
		BossPatterns.interrupt(model, data)
		clearStandIns(player, members)
		fullHeal(player)
		BossPatterns.force(model, data, "split")
		step(1)
		MonsterState.applyDamage(decoyModels()[1], 1e9, BossData.stageInterval, player)
		task.wait()
		BossTrap.release(player, "debug")
		task.wait(mechanics.trap.releaseGraceSeconds + 0.2) -- 풀려난 뒤의 유예 면역이 폭풍을 가리지 않게
		st.phaseEndsAt = os.clock()
		step(2)
		local hpAfterStorm = PlayerState.getHp(player) / PlayerState.getMaxHp(player)
		r.check(("분신 1회 + 제한 시간 초과: 체력 %.1f%%(기대 45.0 - 한 번의 분열에서 합계 55%% 상한), 폭풍은 잡지 않는다=%s, 남은 분신 %d, 게이트 유지=%s"):format(
			hpAfterStorm * 100, tostring(not BossTrap.isTrapped(player)), #decoyModels(), tostring(BossMechanics.isGateArmed(model))),
			math.abs(hpAfterStorm - (1 - mechanics.gimmickFailMaxHpFraction)) < 1e-6 and not BossTrap.isTrapped(player) and #decoyModels() == 0
				and BossMechanics.isGateArmed(model))

		-- 분열 도중에 보스전이 끝난다(이탈) → 분신이 남지 않는다 + 부하: 분신 3체를 세우는 데 걸린 시간
		BossPatterns.interrupt(model, data)
		fullHeal(player)
		BossPatterns.force(model, data, "split")
		step(1)
		local during = #decoyModels()
		BossEncounter.despawnFor(player)
		r.check(("분열 도중 보스전 종료: 분신 %d → %d(기대 0) · 분신 %d체 세우기 %.2fms → 12 보스전이 같은 틱에 분열해도 %.1fms(20초에 한 번, 상시 비용 0)"):format(
			during, #decoyModels(), skill.split.count - 1, spawnSeconds * 1000, spawnSeconds * 1000 * 12),
			during == skill.split.count - 1 and #decoyModels() == 0 and spawnSeconds < 0.05)
		fullHeal(player)
	end)
end

local function activeClassState(player)
	local profile = PlayerProfile.getProfile(player)
	return profile and profile.classId and profile.classes[profile.classId]
end

local function runLive(player, env)
	print("===29-5 검증 시작(나: 실제 서버 경로)===")
	local r = newRecorder("나")
	env.ensureBackup(player)

	-- [2][5] "유저 둘이 같은 스테이지에서 같은 보스" + "순환이 진행된 기존 세이브의 전환". 실제 Player의 실제 프로필에 서로 다른
	-- 두 유저의 세이브 상태(23-5 순환 필드)를 차례로 넣고 실제 스폰 경로(BossEncounter.spawnFor)를 탄다 - 23-5 코드였다면
	-- A는 순환의 첫 자리(기본형), B는 pending의 storm_lord가 나왔을 상태다.
	r.section("유저 상태와 무관한 보스", function()
		local classState = activeClassState(player)
		local stage = 4 * BossData.stageInterval
		local expected = BossRules.bossIdForStage(stage)

		classState.bossRotation = { order = {}, index = 1, pending = false, history = {}, debugForceNextId = false } -- 유저 A: 새 세이브
		local _, dataA = spawnAt(player, env, stage)

		local saved = { -- 유저 B: 순환이 한창 진행된 옛 세이브(다른 보스가 확정돼 있고 강제 지정까지 남아 있다)
			order = { "storm_lord", "abyssal_lord", "frost_giant", "scorpion_queen", "section_guardian", "crystal_queen" },
			index = 4, pending = { stage = stage, bossId = "storm_lord" }, history = { "storm_lord", "abyssal_lord", "frost_giant" },
			debugForceNextId = "frost_giant",
		}
		classState.bossRotation = saved
		local _, dataB = spawnAt(player, env, stage)
		local untouched = saved.index == 4 and saved.pending.bossId == "storm_lord" and #saved.history == 3 and saved.debugForceNextId == "frost_giant"

		classState.bossRotation = nil -- 필드가 아예 없는 경우에도 스폰 경로가 읽지 않는가
		local _, dataC = spawnAt(player, env, stage)

		r.check(("스테이지 %d: 새 세이브 → %s · 순환 4/6 진행 + pending storm_lord + 강제 frost_giant → %s · bossRotation 없음 → %s (기대 전부 %s) · 옛 필드를 쓰지도 않았다=%s"):format(
			stage, tostring(dataA and dataA.id), tostring(dataB and dataB.id), tostring(dataC and dataC.id), expected, tostring(untouched)),
			dataA ~= nil and dataA.id == expected and dataB ~= nil and dataB.id == expected and dataC ~= nil and dataC.id == expected and untouched)
		classState.bossRotation = saved
	end)

	-- 파티 경로도 같은 함수를 보는가(리더가 누구든 같은 보스) + 첫 보스 = 기본형 + Studio 전용 강제 지정은 한 번만
	r.section("파티·첫 보스·강제 지정", function()
		local interval = BossData.stageInterval
		local _, first = spawnAt(player, env, interval)

		BossEncounter.despawnFor(player)
		local stage = 6 * interval
		PartyState.addDummies(player, 1, function()
			return { classId = "bow", level = 100, stage = stage, hp = 1, maxHp = 1 } -- "/gg party dummy"와 같은 모양(HUD 표시용 값)
		end)
		local party = PartyState.getParty(player)
		env.applyStage(player, stage)
		BossEncounter.spawnForParty(party, player, stage)
		local partyModel = BossEncounter.getActive(player)
		local partyData = partyModel and MonsterState.getData(partyModel)
		BossEncounter.despawnFor(player)
		PartyState.leave(player, "leave")

		BossEncounter.setDebugForcedBoss(player, "scorpion_queen")
		local _, forced = spawnAt(player, env, stage)
		local _, after = spawnAt(player, env, stage)
		r.check(("첫 보스 스테이지 %d = %s · 파티(인원 %s) 스테이지 %d = %s(기대 %s) · 강제 지정 scorpion_queen → %s → 다음 스폰은 다시 %s"):format(
			interval, tostring(first and first.id), tostring(partyData and partyData.partySize), stage, tostring(partyData and partyData.id),
			BossRules.bossIdForStage(stage), tostring(forced and forced.id), tostring(after and after.id)),
			first ~= nil and first.id == GUARDIAN and partyData ~= nil and partyData.id == BossRules.bossIdForStage(stage) and partyData.partySize == 2
				and forced ~= nil and forced.id == "scorpion_queen" and after ~= nil and after.id == BossRules.bossIdForStage(stage))
	end)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		runHoldRescue(player, env, r, root)
		runSplit(player, env, r, root)
	else
		r.check("캐릭터가 없어 F 홀드 구역을 건너뜀", false)
	end

	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	local orphans = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d개(기대 0)"):format(orphans), orphans == 0)
	env.restore(player)
	local pass, total = r.summary()
	print(("===29-5 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

BossGimmick5Verify.runPure = runPure
BossGimmick5Verify.runLive = runLive

return BossGimmick5Verify
