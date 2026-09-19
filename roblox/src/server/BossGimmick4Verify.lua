-- 29-4 자동 검증(PRD 20.79) - 심해 군주(타이밍)·폭풍 군주(협동·유인)의 기믹과 "같은 층" 판정(높이 문제).
-- BossGimmickVerify(29-3)와 같은 패턴이고 DevTools가 그 뒤에 이어서 부른다(같은 플레이어·같은 아레나 - 동시에 돌면 안 된다).
--   (가) 순수 계산 - 단의 배치(어디서든 닿는가)·시한 창·스킬표(회피 부등식·인접 피해 합)·모형. 로컬 Luau 하네스와 같은 값.
--   (나) 실제 서버 경로 - 보스를 스폰해 BossPatterns·BossMechanics·BossTrap·GroundProbe를 직접 돌린다.
-- env = { ensureBackup, restore, applyStage, applyOptionStack } - DevTools의 로컬 헬퍼.
-- 주의(29-3의 교훈): 검증 캐릭터가 보스 25.6stud 안에 있으면 어그로가 붙어 MonsterAI도 같은 보스를 step한다 - 틱으로
-- 진행하는 구출(곁에 머물기)은 두 배로 돈다. 그런 구간은 캐릭터를 멀리 두고, 어그로가 필요한 구간(높이 문제)만 가까이 둔다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local BossPropMath = require(ReplicatedStorage.Shared.BossPropMath)
local Reach = require(ReplicatedStorage.Shared.Reach)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local BossEncounter = require(script.Parent.BossEncounter)
local BossPatterns = require(script.Parent.BossPatterns)
local BossMechanics = require(script.Parent.BossMechanics)
local BossTrap = require(script.Parent.BossTrap)
local GroundProbe = require(script.Parent.GroundProbe)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)

local BossGimmick4Verify = {}

local ABYSSAL, STORM, GUARDIAN = "abyssal_lord", "storm_lord", "section_guardian"
local ALL = { GUARDIAN, "frost_giant", ABYSSAL, "crystal_queen", "scorpion_queen", STORM }
-- 이번에 안 건드린 네 보스의 결정 모형 값(29-3 Play와 같아야 한다): { 지금 솔로/4인 · 설계 파훼 후 솔로/4인 · 파훼 전 솔로/4인 }.
local UNTOUCHED_SECONDS = {
	section_guardian = { 73.30, 37.85, 73.30, 37.85, 73.30, 37.85 },
	frost_giant = { 73.40, 35.10, 73.40, 35.10, 197.95, 82.95 },
	crystal_queen = { 76.65, 37.80, 74.00, 36.10, 194.60, 83.80 },
	scorpion_queen = { 73.70, 35.45, 73.70, 35.45, 214.25, 83.70 },
}
local MONTE_CARLO_RUNS = 100

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
		print(("[29-4][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function runPure()
	print("===29-4 검증 시작(가: 단 배치·시한 창·스킬표·모형)===")
	local r = newRecorder("가")
	local dodge = BossData.mechanics.dodge
	local walkSpeed = WorldConfig.playerWalkSpeedStuds

	-- [4][5] 단의 배치 - 아레나 어느 자리에서도 예고 안에 가장 가까운 단 윗면에 닿는가 · 넷이 한 단에 서는가
	r.section("단 배치", function()
		local boss = BossData.bosses[ABYSSAL]
		local flood = boss.skills.flood
		local half = WorldConfig.bossArena.halfSizeStuds
		local zones = BossPropMath.kitZones(boss.arenaKit, Vector3.zero, 0, flood.safeZone.tag)
		local worst = 0
		for x = -half, half, 2 do
			for z = -half, half, 2 do
				local best = math.huge
				for _, zone in ipairs(zones) do
					best = math.min(best, BossPropMath.distanceToBox(Vector3.new(x, 0, z), zone.center, zone.size))
				end
				worst = math.max(worst, best)
			end
		end
		local allowance = (flood.telegraphSeconds - dodge.perceptionSeconds) / dodge.marginFactor * walkSpeed
		local smallestTop, tallestStep = math.huge, 0
		for _, zone in ipairs(zones) do
			smallestTop = math.min(smallestTop, zone.size.X, zone.size.Z)
		end
		for _, part in ipairs(boss.arenaKit.parts) do
			tallestStep = math.max(tallestStep, part.size.Y)
		end
		r.check(("단 %d곳(kit %d파트 ≤ 40): 아레나 격자 전체에서 가장 가까운 단 윗면까지 최대 %.1fstud ≤ 회피 거리 %d ≤ 걸을 수 있는 거리 %.1f(전조 %.1f초) · 윗면 한 변 %dstud ≥ 네 명(몸통 폭 2 × 4) · 한 단 높이 %.1f ≤ 계단 한 단 %.1f"):format(
			#zones, #boss.arenaKit.parts, worst, flood.dodge.distanceStuds, allowance, flood.telegraphSeconds, smallestTop, tallestStep, TerrainConfig.maxStepHeightStuds),
			#zones == 4 and #boss.arenaKit.parts <= 40 and worst <= flood.dodge.distanceStuds and flood.dodge.distanceStuds <= allowance
				and smallestTop >= 8 and tallestStep <= TerrainConfig.maxStepHeightStuds)
	end)

	-- [4] 순서 - 범람은 다른 스킬에 기대지 않는다(단은 정적 kit · 시계는 범람마다 새로 돈다). 시한 창은 힌트 단계와 무관하게 같다.
	r.section("범람 시한 창", function()
		local flood = BossData.bosses[ABYSSAL].skills.flood
		local early = flood.telegraphSeconds - flood.safeZone.sinkSeconds
		local hinted = flood.telegraphSeconds * BossData.mechanics.hint.telegraphMultiplier
		local hintedSink = flood.safeZone.sinkSeconds + (hinted - flood.telegraphSeconds)
		local run = BossSim.run(ABYSSAL, { partySize = 1 })
		r.check(("범람 켜짐=%s · 밟은 뒤 %.1f초에 가라앉는다 → \"너무 이른\" 창 = 예고 뒤 %.1f초(안전한 도착 창 %.1f ~ %.1f초) · 힌트 2단계: 예고 %.1f초·가라앉기 %.1f초 → 창 %.1f초(그대로) · 모형의 첫 스킬 = %s@%.2f(선행 스킬 없음)"):format(
			tostring(flood.enabled ~= false), flood.safeZone.sinkSeconds, early, early, flood.telegraphSeconds, hinted, hintedSink, hinted - hintedSink,
			run.sequence[1].id, run.sequence[1].at),
			flood.enabled ~= false and early > 0 and early <= 1.0 + 1e-9 and near(hinted - hintedSink, early, 1e-9)
				and run.sequence[1].id == "flood" and near(run.sequence[1].at, flood.firstAvailableSeconds, 0.06))
	end)

	-- [12] 높이 문제의 산수 - 루트끼리 재면 곁에서 점프한 대상이 "다른 층"이 된다
	r.section("같은 층 판정의 산수", function()
		local playerRootAboveGround = 3 -- HipHeight 2 + 루트 반높이 1
		local jump = 7.2 -- StarterPlayer.CharacterJumpHeight(Studio 실측 - UseJumpPower = false)
		local resting = playerRootAboveGround - TerrainConfig.monsterFootOffsetStuds
		r.check(("같은 바닥에 선 몬스터·플레이어의 루트 높이차 %.1f(= 3 − %.1f) → 점프 꼭대기 %.1f > 상한 %d(원인) · 발밑 지면으로 재면 0 ≤ %d · 발밑 지면을 찾는 창 %d ≥ 단 위 점프 + 띄우기(3 + 2 + 7.2 + 6 = 18.2)"):format(
			resting, TerrainConfig.monsterFootOffsetStuds, resting + jump, TerrainConfig.heightToleranceStuds, TerrainConfig.heightToleranceStuds, TerrainConfig.airborneProbeDownStuds),
			resting + jump > TerrainConfig.heightToleranceStuds and TerrainConfig.airborneProbeDownStuds >= 18.2)
	end)

	-- [9] 솔로 해법이 실제로 성립하는가 - 피뢰침 간격·낙뢰의 원·넉백. 28-2의 24stud는 인지 0.5초·여유 x1.25를 넣으면 성립하지 않았다
	r.section("피뢰침 배치", function()
		local boss = BossData.bosses[STORM]
		local strike, overcharge = boss.skills.strike, boss.skills.overcharge
		local charge = strike.onImpact[1]
		local rods = BossPropMath.kitZones(boss.arenaKit, Vector3.zero, 0, charge.tag)
		local spacing = (rods[1].center - rods[2].center).Magnitude
		local reach = strike.radiusStuds + charge.reachStuds
		local maxReach = strike.radiusStuds * BossRules.maxSkillRangeScale() + charge.reachStuds
		local route = spacing - reach -- 첫 낙뢰를 A 곁(A의 자리)에서 받고 B의 충전 거리 안으로
		local required = dodge.perceptionSeconds + route / walkSpeed * dodge.marginFactor
		local oldRequired = dodge.perceptionSeconds + (24 - reach) / walkSpeed * dodge.marginFactor
		r.check(("피뢰침 %d개 · 간격 %.0fstud: 낙뢰의 원 하나(충전 거리 %.0f, 최대 배율 %.1f)로는 둘을 같이 못 채운다(%.0f > %.1f) · 솔로 경로 %.0fstud → 필요 %.2f초 ≤ 둘째 예고 %.1f초(데이터 route %d) · 28-2의 간격 24였다면 %.2f초 > %.1f초(성립 안 함)"):format(
			#rods, spacing, reach, maxReach, spacing, 2 * maxReach, route, required, strike.repeatTelegraphSeconds, strike.route.distanceStuds, oldRequired, strike.repeatTelegraphSeconds),
			#rods == 2 and spacing > 2 * maxReach and route <= strike.route.distanceStuds and required <= strike.repeatTelegraphSeconds
				and oldRequired > strike.repeatTelegraphSeconds)
		local launch = strike.onHit[1]
		r.check(("넉백(높이 %d·거리 %d)은 그대로: 둘째 낙뢰는 첫 낙뢰가 떨어진 **순간의 자리**(튕기기 전)에 예고된다 → 넉백은 둘째 원의 자리를 못 바꾼다(맞으면 그 회차는 실패할 뿐) · 피하면 넉백이 없다 · 충전 %d초 ≥ 한 회차 %.1f초"):format(
			launch.heightStuds, launch.distanceStuds, charge.seconds, strike.telegraphSeconds + strike.repeatTelegraphSeconds),
			launch.heightStuds == 5 and launch.distanceStuds == 8 and strike.sequential and charge.seconds >= strike.telegraphSeconds + strike.repeatTelegraphSeconds
				and strike.perMember == true and strike.gate.zoneTag == charge.tag)
		-- 과충전: 안전지대(피뢰침 곁)는 정적 kit이라 늘 있다 + 닿을 수 없는 사람이 있으면 쏘지 않는다
		local nearStuds = nil
		for _, condition in ipairs(overcharge.conditions) do
			if condition.type == "membersNearZone" then
				nearStuds = condition.studs
			end
		end
		local walk = nearStuds and (nearStuds - rods[1].radius + dodge.characterHalfWidthStuds) or math.huge
		local run = BossSim.run(STORM, { partySize = 1, breaks = "never" })
		local firstOvercharge = nil
		for _, entry in ipairs(run.sequence) do
			if entry.id == "overcharge" then
				firstOvercharge = firstOvercharge or entry.at
			end
		end
		r.check(("과충전 켜짐=%s · 안전 반경 %d(충전 여부 무관 - 정적 kit이라 첫 과충전 전에 반드시 있다) · 발동 조건: 전원이 피뢰침 %dstud 안 → 걸을 거리 %d = 회피 거리 %d → %.2f초 ≤ 예고 %.1f초 · 게이트를 안 바꾼다=%s · 모형: 첫 스킬 %s@%.2f, 첫 과충전 %.1f초(장막 30초 뒤)"):format(
			tostring(overcharge.enabled ~= false), rods[1].radius, nearStuds or -1, walk, overcharge.dodge.distanceStuds,
			dodge.perceptionSeconds + walk / walkSpeed * dodge.marginFactor, overcharge.telegraphSeconds, tostring(overcharge.judgesGate == false),
			run.sequence[1].id, run.sequence[1].at, firstOvercharge or -1),
			overcharge.enabled ~= false and walk <= overcharge.dodge.distanceStuds and overcharge.judgesGate == false
				and run.sequence[1].id == "strike" and firstOvercharge ~= nil and firstOvercharge >= strike.firstAvailableSeconds + 30)
	end)

	-- [10][11] 회오리(띄우기)와 감전 구출의 비용
	r.section("회오리·구출 비용", function()
		local boss = BossData.bosses[STORM]
		local lift = boss.skills.whirl.onHit[1]
		local fall = math.sqrt(2 * lift.heightStuds / 196.2)
		local helpless = 0.3 + lift.holdSeconds + fall
		r.check(("회오리: 낙뢰와 같은 조각(launch) - 높이 %d · 거리 %d(제자리) · 도는 시간 %.1f초(20.77의 1.5 ~ 2초) · 조작을 잃는 시간 %.2f초 ≤ 면역 %.1f초 ≤ 전역 쿨 %d초(내려온 직후 확정 피격 없음) · 뜬 루트 높이차 %.1f(점프 중이면 %.1f > 8 - 그래서 층은 발밑 지면으로 판단한다)"):format(
			lift.heightStuds, lift.distanceStuds, lift.holdSeconds, helpless, lift.immuneSeconds, boss.scheduler.globalCooldownSeconds,
			lift.heightStuds + 1.5, lift.heightStuds + 1.5 + 7.2),
			lift.type == "launch" and lift.distanceStuds == 0 and lift.holdSeconds >= 1.5 and lift.holdSeconds <= 2 and helpless <= lift.immuneSeconds
				and lift.immuneSeconds <= boss.scheduler.globalCooldownSeconds and lift.heightStuds < WorldConfig.walls.heightStuds)
		local mechanics = BossData.mechanics
		local slack = 1 - (mechanics.gimmickFailMaxHpFraction + 3 / 7)
		local old = mechanics.gimmickFailMaxHpFraction / mechanics.partialFailDivisor
		r.check(("감전 구출 비용 %.1f%%(28-2의 %.1f%%에서 내렸다): 기믹 실패 55%% + 강타류 42.9%% = 97.9%% → 여유 %.1f%% < %.1f%% - 보스전 자동회복이 없어(29-3) 구출자가 낸 체력은 전투 끝까지 남는다 → 구출한 사람이 다음 실수 한 번에 죽는다"):format(
			mechanics.rescue.touch.rescuerMaxHpFraction * 100, old * 100, slack * 100, old * 100),
			mechanics.rescue.touch.rescuerMaxHpFraction == 0 and slack < old and mechanics.bossFight.baseRegenEnabled == false)
	end)

	-- [3][13][14] 두 보스의 /gg boss check 전 항목 + 6종 인접 쌍 재검사
	r.section("스킬표 검사", function()
		local maxScale = BossRules.maxSkillRangeScale()
		for _, bossId in ipairs({ ABYSSAL, STORM }) do
			local rows, baseOk = BossSim.checkDodge(bossId, 1)
			local wideRows, wideOk = BossSim.checkDodge(bossId, maxScale)
			for index, row in ipairs(rows) do
				print(("[29-4][가]   %s | %s | %s | %.1f → %.1fstud | %.2f ≤ %.2f %s | %.2f ≤ %.2f %s"):format(bossId, row.skillId, row.label, row.distanceStuds,
					wideRows[index].distanceStuds, row.requiredSeconds, row.availableSeconds, row.ok and "O" or "X",
					wideRows[index].requiredSeconds, wideRows[index].availableSeconds, wideRows[index].ok and "O" or "X"))
			end
			r.check(("%s 회피 부등식 %d판정: 배율 1.00 %s · 최대 배율 %.3f %s"):format(bossId, #rows, baseOk and "통과" or "실패", maxScale, wideOk and "통과" or "실패"), baseOk and wideOk)
		end
		local total, violations, worst = 0, 0, 0
		for _, bossId in ipairs(ALL) do
			local rows, count = BossSim.checkPairs(bossId)
			total += #rows
			violations += count
			for _, row in ipairs(rows) do
				if row.possible then
					worst = math.max(worst, row.share)
				end
			end
		end
		r.check(("6종 인접 쌍 %d개 중 100%% 이상인 가능한 쌍 %d건(가능한 최악 %.1f%%)"):format(total, violations, worst * 100), violations == 0)
	end)

	-- [16] 안 건드린 네 보스 - 결정 모형 값이 29-3 Play와 같은가
	r.section("회귀", function()
		for _, bossId in ipairs({ GUARDIAN, "frost_giant", "crystal_queen", "scorpion_queen" }) do
			local expected = UNTOUCHED_SECONDS[bossId]
			local values = {
				BossSim.run(bossId, { partySize = 1 }).seconds, BossSim.run(bossId, { partySize = 4 }).seconds,
				BossSim.run(bossId, { partySize = 1, design = true, breaks = "always" }).seconds, BossSim.run(bossId, { partySize = 4, design = true, breaks = "always" }).seconds,
				BossSim.run(bossId, { partySize = 1, design = true, breaks = "never" }).seconds, BossSim.run(bossId, { partySize = 4, design = true, breaks = "never" }).seconds,
			}
			local same = true
			for index, value in ipairs(values) do
				same = same and near(value, expected[index], 0.06)
			end
			r.check(("%s: 결정 모형 6값 29-3과 동일=%s(%.2f/%.2f · %.2f/%.2f · %.2f/%.2f)"):format(
				bossId, tostring(same), values[1], values[2], values[3], values[4], values[5], values[6]), same)
		end
		local split = BossData.bosses.crystal_queen.skills.split
		r.check(("수정 여왕의 기믹은 그대로 꺼져 있음=%s"):format(tostring(split.enabled == false)), split.enabled == false)
	end)

	-- [15] 기믹을 켠 상태의 몬테카를로 - 파훼 후 기준 ±10%, 초회(파훼 전)가 파훼 후의 1.8 ~ 2.7배
	r.section("몬테카를로", function()
		for _, n in ipairs({ 1, 4 }) do
			local reference = BossSim.monteCarlo(GUARDIAN, { partySize = n }, MONTE_CARLO_RUNS).mean
			task.wait()
			for _, bossId in ipairs({ ABYSSAL, STORM }) do
				local after = BossSim.monteCarlo(bossId, { partySize = n, breaks = "always" }, MONTE_CARLO_RUNS)
				task.wait()
				local never = BossSim.monteCarlo(bossId, { partySize = n, breaks = "never" }, MONTE_CARLO_RUNS)
				task.wait()
				local ratio = never.mean / after.mean
				r.check(("%s | %d인 | 파훼 후 %.1f(%.1f ~ %.1f, 기준 %.1f 대비 %+.1f%%) | 파훼 전 %.1f(x%.2f) | 첫 기믹 %.2f초 · 최소 %d회"):format(
					bossId, n, after.mean, after.p5, after.p95, reference, (after.mean / reference - 1) * 100, never.mean, ratio, after.latestFirstGimmickAt, after.minGimmickCount),
					math.abs(after.mean / reference - 1) <= 0.10 and ratio >= 1.8 and ratio <= 2.7 and after.minGimmickCount >= 1)
			end
		end
	end)

	local passCount, totalCount = r.summary()
	print(("===29-4 검증 끝(가)=== %d/%d 통과"):format(passCount, totalCount))
end

-- ─────────────────────────── (나) 실제 서버 경로 ───────────────────────────

local function spawnBoss(player, env, bossId)
	BossEncounter.despawnFor(player)
	env.applyStage(player, BossData.stageInterval)
	BossEncounter.setDebugForcedBoss(player, bossId)
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

-- 실시간으로 보스를 돌린다(어그로와 무관하게 직접 step) - until()이 참이거나 seconds가 지나면 멈춘다.
local function drive(player, root, model, data, seconds, members, untilFn)
	local startedAt = os.clock()
	local stepSeconds, stepCount = 0, 0
	while os.clock() - startedAt < seconds do
		RunService.Heartbeat:Wait()
		PlayerState.setHp(player, PlayerState.getMaxHp(player))
		local before = os.clock()
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, members or { player })
		stepSeconds += os.clock() - before
		stepCount += 1
		if untilFn and untilFn() then
			break
		end
	end
	return stepSeconds / math.max(stepCount, 1), stepCount
end

local function moveTo(root, position)
	root.CFrame = CFrame.new(position)
	RunService.Heartbeat:Wait()
end

-- 스탠드인 멤버(테이블 Player - Studio에서 Instance가 아니다). root.Position을 바꿔 옮긴다.
local function newStandIn(model, members, name, position)
	local fakeRoot = { Position = position }
	local fake = { Name = name, UserId = -9400 - #members, Parent = workspace }
	fake.Character = {
		FindFirstChild = function(_, child)
			return child == "HumanoidRootPart" and fakeRoot or nil
		end,
		FindFirstChildOfClass = function()
			return nil
		end,
	}
	-- 피해를 받는 스탠드인은 Attribute 스텁이 있어야 한다 - PlayerDamage.syncHud가 SetAttribute를 부른다(29-4 Play 1회차:
	-- 방전·낙뢰가 스탠드인을 때리는 순간 여기서 에러가 나 두 구역이 통째로 X였다. 29-3의 전갈 구역 스탠드인과 같은 스텁이다).
	function fake:SetAttribute() end
	function fake:GetAttribute()
		return nil
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

local function runAbyssal(player, env, r, root)
	local perStepFlood = nil
	local arenaFloorY = nil

	-- [4] 첫 방전 전에 단이 반드시 존재하는가 - 실제 스케줄러를 실시간으로. 캐릭터는 어그로 밖(40stud)에 가만히 서 있는다.
	r.section("심해 군주 실시간", function()
		local model, data = spawnBoss(player, env, ABYSSAL)
		local bossPosition = model.PrimaryPart.Position
		local zone = WorldConfig.zones[BossEncounter.getEncounter(player).zoneKey]
		moveTo(root, bossPosition + Vector3.new(40, 1.5, 0))
		local platforms, tops = 0, {}
		for _, part in ipairs(GroundProbe.folder():GetChildren()) do
			if part.Name == "FloodPlatform" and math.abs(part.Position.X - zone.center.X) <= zone.halfSize and math.abs(part.Position.Z - zone.center.Z) <= zone.halfSize then
				platforms += 1
			end
		end
		local st = MonsterState.getBossPatternState(model)
		arenaFloorY = st.floorY
		for _, z in ipairs(BossPropMath.kitZones(data.arenaKit, zone.center, st.floorY, "platform")) do
			table.insert(tops, ("%.1f"):format((GroundProbe.surfaceY(z.center.X, z.center.Z, st.floorY) or -99) - st.floorY))
		end
		local starts, lastCurrent, freshAtFlood = {}, nil, nil
		local perStep = drive(player, root, model, data, 12, nil, function()
			local _, startedAt, current = BossPatterns.debugClocks(model)
			if current ~= lastCurrent then
				if current then
					table.insert(starts, ("%s@+%.1f"):format(current, os.clock() - startedAt))
					if current == "flood" then
						freshAtFlood = true
						for index = 1, 4 do
							freshAtFlood = freshAtFlood and BossMechanics.zoneExpiresAt(model, player, index) == nil
						end
						return true
					end
				end
				lastCurrent = current
			end
			return false
		end)
		perStepFlood = perStep
		r.check(("아레나 kit: FloodPlatform 파트 %d개(기대 8 = 단 4곳 × 2단), 단 윗면 높이(바닥 기준) [%s](기대 2.0 - 서버의 지면이라 단 위에 서 있어도 공중이 아니다 = 해일은 뛰어야 한다)"):format(
			platforms, table.concat(tops, ", ")), platforms == 8 and #tops == 4 and tops[1] == "2.0" and tops[4] == "2.0")
		r.check(("실시간 시퀀스: %s | 첫 범람이 시작된 순간 네 단이 전부 이 사람에게 새것=%s(선행 스킬 없이 첫 스킬이 범람이다)"):format(table.concat(starts, " "), tostring(freshAtFlood)),
			starts[1] ~= nil and starts[1]:match("^flood@%+10") ~= nil and freshAtFlood == true)
	end)

	-- [5][6] 같은 단에 넷 - 미리 올라가 있던 친구(A)의 시계가 나머지의 단을 가라앉히지 않는다
	r.section("범람 판정", function()
		local model, data = spawnBoss(player, env, ABYSSAL)
		local zone = WorldConfig.zones[BossEncounter.getEncounter(player).zoneKey]
		local st = MonsterState.getBossPatternState(model)
		local platform = BossPropMath.kitZones(data.arenaKit, zone.center, st.floorY, "platform")[4]
		local top = platform.center + Vector3.new(0, platform.size.Y / 2 + 3, 0)
		local water = platform.center + Vector3.new(-20, -1.5 + 3, 0) -- 단 밖 물속
		local members = { player }
		local early = newStandIn(model, members, "StandInEarly", platform.center + Vector3.new(5, 0, 5)) -- 예고 전부터 단 위
		local _, lateRoot = newStandIn(model, members, "StandInLate", water)
		local _, edgeRoot = newStandIn(model, members, "StandInEdge", water)
		local wet = newStandIn(model, members, "StandInWet", water) -- 끝까지 물속
		moveTo(root, water)
		fullHeal(player)
		BossPatterns.force(model, data, "flood")
		local function step()
			BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, members)
		end
		step()
		local gateAtTelegraph = BossMechanics.isGateArmed(model)
		local deadline = st.phaseEndsAt -- 예정된 방전 시각
		drive(player, root, model, data, 1.2, members) -- "너무 이른" 1초가 지나간다
		-- A의 기록은 drive 뒤에 읽는다: 강제 시작한 틱은 예고를 띄우기만 하고, 밟기 추적은 그다음 틱부터 돈다(29-4 Play 2회차 -
		-- 첫 틱 직후에 읽어 nil이었다. 로그의 "판정까지 5.99초"가 실제 값이다).
		local earlyExpires = BossMechanics.zoneExpiresAt(model, early, 4)
		local early2 = deadline - (earlyExpires or 0) -- 방전보다 몇 초 먼저 가라앉는가
		moveTo(root, top)
		lateRoot.Position = platform.center + Vector3.new(-5, 0, -5)
		edgeRoot.Position = platform.center + Vector3.new(platform.size.X / 2 + 0.9, 0, 0) -- 가장자리: 윗면 밖 0.9stud(몸통 반폭 1 안)
		step()
		local mineExpires = BossMechanics.zoneExpiresAt(model, player, 4)
		st.phaseEndsAt = os.clock() -- 남은 예고를 기다리지 않는다(판정은 예정된 방전 시각과 비교한다 - BossMechanics.zoneHolds)
		step()
		local trapped = {}
		for _, member in ipairs(members) do
			if BossTrap.isTrapped(member) then
				table.insert(trapped, member.Name)
			end
		end
		r.check(("같은 단에 넷: 미리 올라가 있던 A는 방전 %.2f초 전에 가라앉음(기대 1.0) · 본인은 +1.2초에 밟아 방전 뒤 %.2f초까지 버팀 → 잡힌 사람 [%s](기대 StandInEarly·StandInWet), 본인 체력 %.0f%%, 게이트 %s → %s"):format(
			early2, (mineExpires or 0) - deadline, table.concat(trapped, "·"), hpFraction(player) * 100,
			tostring(gateAtTelegraph), tostring(BossMechanics.isGateArmed(model))),
			near(early2, 1.0, 0.05) and #trapped == 2 and table.find(trapped, "StandInEarly") ~= nil and table.find(trapped, wet.Name) ~= nil
				and near(hpFraction(player), 1, 1e-9) and gateAtTelegraph and not BossMechanics.isGateArmed(model))
		r.check(("친구의 시계는 내 단과 무관: A가 밟은 시각의 만료 %.2f ≠ 본인의 만료 %.2f(차이 %.2f초 ≈ 1.2) · 기회 창 받는 피해 x%.2f(기대 %.2f)"):format(
			earlyExpires or -1, mineExpires or -1, (mineExpires or 0) - (earlyExpires or 0), MonsterState.getDamageTakenMultiplier(model), data.skills.flood.breakWindow.damageTakenMultiplier),
			earlyExpires ~= nil and mineExpires ~= nil and near(mineExpires - earlyExpires, 1.2, 0.15)
				and near(MonsterState.getDamageTakenMultiplier(model), data.skills.flood.breakWindow.damageTakenMultiplier, 1e-6))
		clearStandIns(player, members)

		-- [7] 단 밖에서 방전 → 55% + 침수 → 곁에 1.5초(벗어나면 0)
		BossPatterns.interrupt(model, data)
		moveTo(root, water)
		fullHeal(player)
		BossPatterns.force(model, data, "flood")
		step()
		st.phaseEndsAt = os.clock()
		step()
		local hpAfter = hpFraction(player)
		local kind, rescueType = player:GetAttribute("BossTrapKind"), player:GetAttribute("BossTrapRescueType")
		local rescuer, rescuerRoot = newStandIn(model, members, "StandInRescuer", water + Vector3.new(5, 0, 0))
		for _ = 1, 45 do -- 0.75초분(틱은 dt로 센다 - 실제 시간과 무관하다)
			step()
		end
		local half = player:GetAttribute("BossTrapRescue")
		rescuerRoot.Position = water + Vector3.new(12, 0, 0) -- 6stud 밖으로
		step()
		local afterLeave = player:GetAttribute("BossTrapRescue")
		rescuerRoot.Position = water + Vector3.new(5, 0, 0)
		local ticks = 0
		while BossTrap.isTrapped(player) and ticks < 120 do
			step()
			ticks += 1
		end
		local grace = PlayerState.getIncomingDamageMultiplier(player)
		r.check(("단 밖에서 방전: 체력 %.1f%%(기대 45), 잡힘 %s(구출 %s) → 구출자가 5stud 곁에 0.75초: 진행 %.2f(기대 0.50) → 벗어남: %.2f(기대 0) → 다시 곁에 %d틱(기대 90 = 1.5초) 만에 풀림=%s, 구출자 체력 %.0f%%(기대 100 - 대가는 시간), 루트 고정 해제=%s, 풀린 직후 유예 면역 x%.1f"):format(
			hpAfter * 100, tostring(kind), tostring(rescueType), half or -1, afterLeave or -1, ticks, tostring(not BossTrap.isTrapped(player)),
			PlayerState.getHp(rescuer) / PlayerState.getMaxHp(rescuer) * 100, tostring(root.Anchored == false), grace),
			near(hpAfter, 1 - BossData.mechanics.gimmickFailMaxHpFraction, 1e-6) and kind == "submerged" and rescueType == "proximity"
				and near(half, 0.5, 0.02) and afterLeave == 0 and ticks >= 89 and ticks <= 91 and not BossTrap.isTrapped(player)
				and PlayerState.getHp(rescuer) == PlayerState.getMaxHp(rescuer) and root.Anchored == false and grace == 0)
		clearStandIns(player, members)
		fullHeal(player)
	end)

	-- 힌트 2단계 - 예고와 가라앉는 시간이 같이 늘어난다
	r.section("심해 군주 힌트", function()
		local model, data = spawnBoss(player, env, ABYSSAL)
		moveTo(root, model.PrimaryPart.Position + Vector3.new(40, 1.5, 0))
		BossEncounter.resetFor(player)
		BossEncounter.resetFor(player)
		fullHeal(player)
		BossPatterns.force(model, data, "flood")
		local startedAt = os.clock()
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		local st = MonsterState.getBossPatternState(model)
		local flood = data.skills.flood
		r.check(("전멸 2회 → 힌트 %d단계, 범람 예고 %.2f초(기대 %.1f), 가라앉기 %.2f초(기대 %.1f) → \"너무 이른\" 창 %.2f초(그대로)"):format(
			BossPatterns.getHintLevel(model), st.phaseEndsAt - startedAt, flood.telegraphSeconds * 1.5, st.zoneSinkSeconds, flood.safeZone.sinkSeconds + flood.telegraphSeconds * 0.5,
			(st.phaseEndsAt - startedAt) - st.zoneSinkSeconds),
			BossPatterns.getHintLevel(model) == 2 and near(st.phaseEndsAt - startedAt, flood.telegraphSeconds * 1.5, 0.05)
				and near(st.zoneSinkSeconds, flood.safeZone.sinkSeconds + flood.telegraphSeconds * 0.5, 1e-6))
		BossPatterns.interrupt(model, data)
		BossEncounter.debugClearHints(player)
	end)
	return perStepFlood, arenaFloorY
end

local function runStorm(player, env, r, root)
	local perStepStrike = nil
	task.wait(BossData.mechanics.trap.releaseGraceSeconds + 0.2) -- 심해 군주 구역의 침수 구출이 남긴 해제 유예 면역이 끝나길 기다린다

	r.section("폭풍 군주 실시간", function()
		local model, data = spawnBoss(player, env, STORM)
		local zone = WorldConfig.zones[BossEncounter.getEncounter(player).zoneKey]
		moveTo(root, model.PrimaryPart.Position + Vector3.new(40, 1.5, 0))
		local rods = 0
		for _, part in ipairs(workspace:GetChildren()) do
			if part.Name == "LightningRod" and math.abs(part.Position.X - zone.center.X) <= zone.halfSize and math.abs(part.Position.Z - zone.center.Z) <= zone.halfSize then
				rods += 1
			end
		end
		local starts, lastCurrent = {}, nil
		perStepStrike = drive(player, root, model, data, 12, nil, function()
			local _, startedAt, current = BossPatterns.debugClocks(model)
			if current ~= lastCurrent then
				if current then
					table.insert(starts, ("%s@+%.1f"):format(current, os.clock() - startedAt))
				end
				lastCurrent = current
			end
			return #starts >= 1 and current == nil
		end)
		r.check(("아레나 kit: LightningRod %d개(기대 2) | 실시간 시퀀스: %s(기대 strike@+8.0 - 장막은 첫 낙뢰 예고와 함께 선다) · 피뢰침에서 40stud 떨어져 서 있었다 → 장막 %s"):format(
			rods, table.concat(starts, " "), tostring(BossMechanics.isGateArmed(model))),
			rods == 2 and starts[1] ~= nil and starts[1]:match("^strike@%+8") ~= nil and BossMechanics.isGateArmed(model))
	end)

	-- [8][9] 피뢰침 충전과 장막 - 솔로 경로(A 곁 → B 곁)·실패·파티(둘이 하나씩)
	r.section("피뢰침 충전", function()
		local model, data = spawnBoss(player, env, STORM)
		local zone = WorldConfig.zones[BossEncounter.getEncounter(player).zoneKey]
		local st = MonsterState.getBossPatternState(model)
		local rodZones = BossPropMath.kitZones(data.arenaKit, zone.center, st.floorY, "rod")
		local function beside(index, dx, dz)
			return Vector3.new(rodZones[index].center.X + dx, st.floorY + 3, rodZones[index].center.Z + dz)
		end
		local members = { player }
		local function step()
			BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, members)
		end
		local function charged(index)
			local charges = st.zoneCharges and st.zoneCharges.rod
			return charges ~= nil and (charges[index] or 0) > os.clock()
		end

		-- 솔로: 첫 낙뢰의 원은 예고 순간의 자리(A 곁)에 고정된다 → 그사이 B 곁으로 9stud → 둘째 원은 B 곁에 → 피한다
		moveTo(root, beside(1, 3, 3))
		fullHeal(player)
		BossPatterns.force(model, data, "strike")
		step()
		local armedAtTelegraph = BossMechanics.isGateArmed(model)
		moveTo(root, beside(2, -4, 3))
		local walked = (beside(2, -4, 3) - beside(1, 3, 3)).Magnitude
		st.phaseEndsAt = os.clock()
		step()
		local aOnly, gateMid = charged(1) and not charged(2), BossMechanics.isGateArmed(model)
		moveTo(root, beside(2, -4, 3) + Vector3.new(0, 0, 12))
		st.phaseEndsAt = os.clock()
		step()
		r.check(("솔로 경로: 장막이 첫 예고와 함께 섬=%s → A 곁에서 첫 낙뢰를 받고 %.1fstud 걸어 B 곁으로(첫 발 뒤 A만 충전=%s, 장막 %s) → 둘째 낙뢰가 B를 채운 순간 장막 %s, 받는 피해 x%.2f(기대 %.2f), 두 피뢰침 방전=%s, 본인 체력 %.0f%%(둘 다 피함)"):format(
			tostring(armedAtTelegraph), walked, tostring(aOnly), tostring(gateMid), tostring(BossMechanics.isGateArmed(model)),
			MonsterState.getDamageTakenMultiplier(model), data.skills.strike.gate.breakWindow.damageTakenMultiplier, tostring(not charged(1) and not charged(2)), hpFraction(player) * 100),
			armedAtTelegraph and aOnly and gateMid and not BossMechanics.isGateArmed(model)
				and near(MonsterState.getDamageTakenMultiplier(model), data.skills.strike.gate.breakWindow.damageTakenMultiplier, 1e-6)
				and not charged(1) and not charged(2) and near(hpFraction(player), 1, 1e-9) and walked <= data.skills.strike.route.distanceStuds + 0.5)

		-- 실패: 피뢰침에서 멀리서 두 발을 받는다 → 회차가 끝날 때 장막이 돌아온다(피해·잡힘은 없다)
		moveTo(root, beside(1, -40, 30))
		BossPatterns.force(model, data, "strike")
		step()
		moveTo(root, beside(1, -40, 45))
		st.phaseEndsAt = os.clock()
		step()
		moveTo(root, beside(1, -40, 30))
		st.phaseEndsAt = os.clock()
		step()
		r.check(("멀리서 받은 회차: 장막이 돌아옴=%s(받는 피해 x%.3f), 잡힘=%s, 체력 %.0f%%(실패의 대가는 장막뿐)"):format(
			tostring(BossMechanics.isGateArmed(model)), MonsterState.getDamageTakenMultiplier(model), tostring(BossTrap.isTrapped(player)), hpFraction(player) * 100),
			BossMechanics.isGateArmed(model) and near(MonsterState.getDamageTakenMultiplier(model), BossRules.gateDamageTakenMultiplier(), 1e-6)
				and not BossTrap.isTrapped(player) and near(hpFraction(player), 1, 1e-9))

		-- 파티: 둘이 피뢰침을 하나씩 맡으면 첫 발에 끝난다(낙뢰는 멤버 각자의 자리에 떨어진다)
		newStandIn(model, members, "StandInRodA", beside(1, 2, -2))
		newStandIn(model, members, "StandInRodB", beside(2, -2, 2))
		BossPatterns.force(model, data, "strike")
		step()
		local circles = #st.meteorPositions
		st.phaseEndsAt = os.clock()
		step()
		r.check(("파티(본인은 멀리 + 스탠드인 둘이 피뢰침 곁): 낙뢰의 원 %d개(기대 3 = 멤버 각자) → 첫 발에 장막이 걷힘=%s, 둘째 발 예고로 이어짐 phase=%s"):format(
			circles, tostring(not BossMechanics.isGateArmed(model)), BossPatterns.getPhase(model)),
			circles == 3 and not BossMechanics.isGateArmed(model) and BossPatterns.getPhase(model) == "meteorTelegraph")
		BossPatterns.interrupt(model, data)
		clearStandIns(player, members)
	end)

	-- [10] 과충전 → 감전 → 닿기 구출
	r.section("과충전·감전 구출", function()
		local model, data = spawnBoss(player, env, STORM)
		local zone = WorldConfig.zones[BossEncounter.getEncounter(player).zoneKey]
		local st = MonsterState.getBossPatternState(model)
		local rodZones = BossPropMath.kitZones(data.arenaKit, zone.center, st.floorY, "rod")
		local rodA = Vector3.new(rodZones[1].center.X, st.floorY + 3, rodZones[1].center.Z)
		local members = { player }
		local friend, friendRoot = newStandIn(model, members, "StandInFriend", rodA + Vector3.new(-6.5, 0, 0)) -- 안전 반경 6 + 몸통 1의 가장자리
		local function step()
			BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, members)
		end
		moveTo(root, rodA + Vector3.new(-20, 0, 0))
		step()
		local nearCondition = { type = "membersNearZone", tag = "rod", studs = 30 }
		local reachable = st.pickCtx.conditionMet(nearCondition)
		friendRoot.Position = rodA + Vector3.new(-80, 0, 0)
		local unreachable = st.pickCtx.conditionMet(nearCondition)
		friendRoot.Position = rodA + Vector3.new(-6.5, 0, 0)
		BossMechanics.debugSetGate(model, true)
		fullHeal(player)
		BossPatterns.force(model, data, "overcharge")
		step()
		st.phaseEndsAt = os.clock()
		step()
		local hpAfter, kind, rescueType = hpFraction(player), player:GetAttribute("BossTrapKind"), player:GetAttribute("BossTrapRescueType")
		r.check(("과충전: 발동 조건(전원이 피뢰침 30stud 안) 가까이=%s · 한 명이 80stud=%s(기대 true·false - 닿을 수 없으면 안 쏜다) | 피뢰침 20stud 밖의 본인 체력 %.1f%%(기대 45) 잡힘 %s(구출 %s), 피뢰침 곁 6.5stud의 친구 잡힘=%s, 장막은 그대로=%s(x%.3f - 과충전은 장막을 안 바꾼다)"):format(
			tostring(reachable), tostring(unreachable), hpAfter * 100, tostring(kind), tostring(rescueType), tostring(BossTrap.isTrapped(friend)),
			tostring(BossMechanics.isGateArmed(model)), MonsterState.getDamageTakenMultiplier(model)),
			reachable == true and unreachable == false and near(hpAfter, 1 - BossData.mechanics.gimmickFailMaxHpFraction, 1e-6) and kind == "shocked" and rescueType == "touch"
				and not BossTrap.isTrapped(friend) and BossMechanics.isGateArmed(model) and near(MonsterState.getDamageTakenMultiplier(model), BossRules.gateDamageTakenMultiplier(), 1e-6))

		local touch = BossData.mechanics.rescue.touch
		friendRoot.Position = root.Position + Vector3.new(touch.reachStuds + 2, 0, 0)
		step()
		local stillTrapped = BossTrap.isTrapped(player)
		friendRoot.Position = root.Position + Vector3.new(touch.reachStuds - 0.5, 0, 0)
		step()
		r.check(("감전 구출: %dstud 밖 = 그대로 잡힘=%s → %.1fstud 안에 닿은 그 틱에 풀림=%s, 구출자 체력 %.1f%%(기대 %.1f = 100 − 비용 %.1f%%), 풀린 직후 유예 면역 x%.1f, 루트 고정 해제=%s"):format(
			touch.reachStuds + 2, tostring(stillTrapped), touch.reachStuds - 0.5, tostring(not BossTrap.isTrapped(player)),
			PlayerState.getHp(friend) / PlayerState.getMaxHp(friend) * 100, (1 - touch.rescuerMaxHpFraction) * 100, touch.rescuerMaxHpFraction * 100,
			PlayerState.getIncomingDamageMultiplier(player), tostring(root.Anchored == false)),
			stillTrapped and not BossTrap.isTrapped(player) and near(PlayerState.getHp(friend) / PlayerState.getMaxHp(friend), 1 - touch.rescuerMaxHpFraction, 1e-6)
				and PlayerState.getIncomingDamageMultiplier(player) == 0 and root.Anchored == false)
		clearStandIns(player, members)
		fullHeal(player)
	end)

	-- [11] 회오리 - 같은 조각(launch)의 늘어난 파라미터 + 뜬 동안 면역 / 힌트 2단계의 낙뢰 예고
	r.section("회오리·힌트", function()
		task.wait(BossData.mechanics.trap.releaseGraceSeconds + 0.2)
		local model, data = spawnBoss(player, env, STORM)
		moveTo(root, model.PrimaryPart.Position + Vector3.new(40, 1.5, 0))
		fullHeal(player)
		BossPatterns.force(model, data, "whirl")
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		local st = MonsterState.getBossPatternState(model)
		st.phaseEndsAt = os.clock()
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		local launched = st.lastLaunch
		local lift = data.skills.whirl.onHit[1]
		r.check(("회오리에 맞음: 체력 %.1f%%(피해가 먼저 들어가고 그 뒤에 면역이 선다) → 띄우기 대상=%s, 높이 %s·거리 %s·도는 시간 %s초, 뜬 동안 받는 피해 x%.1f(기대 0 - %.1f초), 스킬은 정상 종료 phase=%s"):format(
			hpFraction(player) * 100, tostring(launched and launched.player and launched.player.Name), tostring(launched and launched.effect.heightStuds),
			tostring(launched and launched.effect.distanceStuds), tostring(launched and launched.effect.holdSeconds),
			PlayerState.getIncomingDamageMultiplier(player), lift.immuneSeconds, BossPatterns.getPhase(model)),
			launched ~= nil and launched.player == player and launched.effect.holdSeconds == lift.holdSeconds
				and launched.effect.distanceStuds == 0 and PlayerState.getIncomingDamageMultiplier(player) == 0 and BossPatterns.getPhase(model) == "normal")
		task.wait(lift.immuneSeconds + 0.3) -- 실제 클라가 캐릭터를 띄웠다 내려놓을 시간

		BossEncounter.resetFor(player)
		BossEncounter.resetFor(player)
		fullHeal(player)
		BossPatterns.force(model, data, "strike")
		local startedAt = os.clock()
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		r.check(("전멸 2회 → 힌트 %d단계, 낙뢰 예고 %.2f초(기대 %.2f - 장막의 판정 스킬도 기믹과 같은 힌트를 받는다)"):format(
			BossPatterns.getHintLevel(model), st.phaseEndsAt - startedAt, data.skills.strike.telegraphSeconds * 1.5),
			BossPatterns.getHintLevel(model) == 2 and near(st.phaseEndsAt - startedAt, data.skills.strike.telegraphSeconds * 1.5, 0.05))
		BossPatterns.interrupt(model, data)
		BossEncounter.debugClearHints(player)
	end)
	return perStepStrike
end

-- [11][12] 같은 층 판정 - 보스 곁에서 뜬 대상을 놓치지 않는가(점프 꼭대기 · 회오리 · 단 위 점프). 실제 MonsterAI 루프로 본다.
local function runLayer(player, env, r, root)
	r.section("같은 층 판정", function()
		local model, data = spawnBoss(player, env, GUARDIAN)
		local bossPosition = model.PrimaryPart.Position
		local ground = bossPosition - Vector3.new(0, TerrainConfig.monsterFootOffsetStuds, 0)
		local function at(heightAboveGround)
			return ground + Vector3.new(10, 3 + heightAboveGround, 0)
		end
		local jumpTop, lifted = at(7.2), at(7.2 + 6)
		r.check(("보스 곁 점프 꼭대기: 루트 높이차 %.1f → 옛 판정(Reach.sameLayer) %s · 새 판정(발밑 지면) %s | 점프 중 회오리에 뜸(%.1f): 옛 %s · 새 %s | 발밑에 지면이 없는 자리(아레나 밖 600stud): 새 %s(기대 false)"):format(
			jumpTop.Y - bossPosition.Y, tostring(Reach.sameLayer(bossPosition, jumpTop)), tostring(GroundProbe.sameGroundLayer(bossPosition, jumpTop)),
			lifted.Y - bossPosition.Y, tostring(Reach.sameLayer(bossPosition, lifted)), tostring(GroundProbe.sameGroundLayer(bossPosition, lifted)),
			tostring(GroundProbe.sameGroundLayer(bossPosition, lifted + Vector3.new(600, 0, 0)))),
			not Reach.sameLayer(bossPosition, jumpTop) and GroundProbe.sameGroundLayer(bossPosition, jumpTop)
				and not Reach.sameLayer(bossPosition, lifted) and GroundProbe.sameGroundLayer(bossPosition, lifted)
				and not GroundProbe.sameGroundLayer(bossPosition, lifted + Vector3.new(600, 0, 0)))

		-- 실제 루프: 어그로를 붙이고 스킬 예고 중에 캐릭터를 꼭대기 높이(8.7)에 0.4초 붙들어 둔다(점프의 0.17초보다 길게).
		moveTo(root, at(0))
		local waited = 0
		while MonsterState.getAiState(model) ~= "chasing" and waited < 3 do
			waited += RunService.Heartbeat:Wait()
		end
		BossPatterns.force(model, data, "heavy")
		local phaseBefore
		local _, clockBefore = BossPatterns.debugClocks(model)
		local started = os.clock()
		while os.clock() - started < 0.4 do
			RunService.Heartbeat:Wait()
			PlayerState.setHp(player, PlayerState.getMaxHp(player))
			phaseBefore = phaseBefore or BossPatterns.getPhase(model)
			root.CFrame = CFrame.new(lifted)
			root.AssemblyLinearVelocity = Vector3.zero
		end
		local phaseAfter, aiAfter = BossPatterns.getPhase(model), MonsterState.getAiState(model)
		local _, clockAfter = BossPatterns.debugClocks(model)
		r.check(("실제 MonsterAI 루프: 어그로 %s → 강공격 예고(%s) 중 대상을 높이차 %.1f(점프 + 회오리)에 0.4초 → 예고가 끊기지 않음 phase=%s, AI=%s(기대 heavyTelegraph·chasing), 스킬 시계가 다시 시작되지 않음=%s"):format(
			tostring(waited < 3), tostring(phaseBefore), lifted.Y - bossPosition.Y, tostring(phaseAfter), tostring(aiAfter), tostring(clockBefore == clockAfter)),
			waited < 3 and phaseAfter == "heavyTelegraph" and aiAfter == "chasing" and clockBefore == clockAfter)
		moveTo(root, at(0) + Vector3.new(40, 0, 0))
		fullHeal(player)
	end)
end

local function runLive(player, env)
	print("===29-4 검증 시작(나: 실제 서버 경로)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		r.check("캐릭터 준비 실패 - (나) 전체 건너뜀", false)
	else
		local perStepFlood = runAbyssal(player, env, r, root)
		local perStepStrike = runStorm(player, env, r, root)
		runLayer(player, env, r, root)
		if perStepStrike then
			print(("[29-4][나] 성능 폭풍 군주: BossPatterns.step 평균 %.1f마이크로초/틱 → 보스전 12개 x 60Hz = 프레임당 %.3fms"):format(perStepStrike * 1e6, perStepStrike * 12 * 1000))
			r.check("성능 폭풍 군주: step 평균 < 100마이크로초", perStepStrike < 100e-6)
		end
		-- [17] step 비용 - 범람 직전까지(단 4곳의 밟기 추적은 범람 예고 6초 동안만 돈다)
		if perStepFlood then
			print(("[29-4][나] 성능 심해 군주: BossPatterns.step 평균 %.1f마이크로초/틱 → 보스전 12개 x 60Hz = 프레임당 %.3fms (29-3 실측 35.2 ~ 37.8마이크로초 = 0.42 ~ 0.45ms, 예산 1.2ms)"):format(
				perStepFlood * 1e6, perStepFlood * 12 * 1000))
			r.check("성능 심해 군주: step 평균 < 100마이크로초", perStepFlood < 100e-6)
		end
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
	r.check(("검증 뒤 encounter 없는 보스 모델 %d개(기대 0 - 같은 슬롯의 다음 보스와 겹치지 않는다)"):format(orphans), orphans == 0)
	fullHeal(player)
	env.restore(player)
	local passCount, totalCount = r.summary()
	print(("===29-4 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

function BossGimmick4Verify.runPure()
	runPure()
end

function BossGimmick4Verify.runLive(player, env)
	runLive(player, env)
end

return BossGimmick4Verify
