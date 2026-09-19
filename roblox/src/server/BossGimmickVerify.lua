-- 29-3 자동 검증(PRD 20.76) - 서리 거인(위치 선정)·전갈 여왕(판단)의 기믹과 보스전 중 기본 자동회복 차단.
-- BossMechanicsVerify(29-1)·BossSkillVerify(29-2)와 같은 패턴이고 DevTools가 그 뒤에 이어서 부른다(같은 플레이어·같은
-- 아레나를 쓰므로 동시에 돌면 안 된다).
--   (가) 순수 계산 - 기둥 뒤 판정의 기하, 스킬표(순서 보장·회피 부등식·인접 피해 합), 모형. 로컬 Luau 하네스와 같은 값.
--   (나) 실제 서버 경로 - 보스를 스폰해 BossPatterns·BossMechanics·BossTrap·BossArenaProps·PlayerRegen을 직접 돌린다.
-- env = { ensureBackup, restore, applyStage, applyOptionStack } - DevTools의 로컬 헬퍼.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local BossPropMath = require(ReplicatedStorage.Shared.BossPropMath)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local BossEncounter = require(script.Parent.BossEncounter)
local BossPatterns = require(script.Parent.BossPatterns)
local BossMechanics = require(script.Parent.BossMechanics)
local BossArenaProps = require(script.Parent.BossArenaProps)
local BossTrap = require(script.Parent.BossTrap)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)

local BossGimmickVerify = {}

local FROST, SCORPION, GUARDIAN = "frost_giant", "scorpion_queen", "section_guardian"
-- 29-4: 심해 군주·폭풍 군주의 기믹이 켜졌다 - 그 둘의 값은 BossGimmick4Verify(29-4)가 본다. 여기 남는 것은 수정 여왕뿐이다.
local UNTOUCHED = { "crystal_queen" }
-- 29-2 Play에서 찍힌 결정 모형 값(지금 솔로/4인 · 설계 파훼 후 솔로/4인 · 파훼 전 솔로/4인) - 아직 안 건드린 보스는 그대로여야 한다.
local UNTOUCHED_SECONDS = {
	crystal_queen = { 76.65, 37.80, 74.00, 36.10, 194.60, 83.80 },
}

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
		print(("[29-3][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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
	print("===29-3 검증 시작(가: 기둥 판정·스킬표·모형)===")
	local r = newRecorder("가")

	-- [5] 기둥 뒤 판정 - 가장자리 포함 정의대로인가. 보스 (0,0), 기둥 (20,0) 반경 3, 몸통 반폭 1.
	r.section("기둥 뒤 판정", function()
		local half = BossData.mechanics.dodge.characterHalfWidthStuds
		local pillar = BossData.bosses[FROST].props.pillar
		local boss, center = Vector3.new(0, 0, 0), Vector3.new(20, 0, 0)
		local cases = {
			{ "기둥 바로 뒤", Vector3.new(25, 0, 0), true }, { "그림자 안", Vector3.new(40, 0, 5), true },
			{ "그림자 가장자리(선분-중심 3.87 ≤ 반경+반폭 4)", Vector3.new(40, 0, 7.9), true }, { "그림자 밖(4.11 > 4)", Vector3.new(40, 0, 8.4), false },
			{ "기둥 옆에 붙음(3.9)", Vector3.new(20, 0, 3.9), true }, { "기둥 옆에서 떨어짐(4.2)", Vector3.new(20, 0, 4.2), false },
			{ "기둥 앞", Vector3.new(15, 0, 0), false }, { "기둥 안(낙빙을 맞은 자리)", Vector3.new(20.5, 0, 0), false },
			{ "보스 반대편", Vector3.new(-25, 0, 0), false },
		}
		local parts, allOk = {}, true
		for _, case in ipairs(cases) do
			local got = BossPropMath.isShielded(boss, case[2], center, pillar.radiusStuds, half)
			allOk = allOk and got == case[3]
			table.insert(parts, ("%s=%s"):format(case[1], tostring(got)))
		end
		r.check("기둥 뒤 판정 9자리: " .. table.concat(parts, " · "), allOk)
		local rayHit = BossPropMath.rayHitDistance(boss, Vector3.new(1, 0, 0), 90, 3, center, pillar.radiusStuds)
		local rayMiss = BossPropMath.rayHitDistance(boss, Vector3.new(1, 0, 0), 90, 3, Vector3.new(20, 0, 6.5), pillar.radiusStuds)
		r.check(("얼음 가시가 기둥에서 끊기는 자리: 정면 기둥 %.1fstud(기대 17) · 옆으로 6.5 비낀 기둥 %s(기대 nil - 반폭 3 + 반경 3 = 6)"):format(rayHit or -1, tostring(rayMiss)),
			near(rayHit, 17, 1e-6) and rayMiss == nil)
	end)

	-- [3][4] 순서 보장(데이터) - 첫 포효 전에 낙빙이 반드시 온다
	r.section("순서 보장", function()
		local boss = BossData.bosses[FROST]
		local roar, icefall = boss.skills.roar, boss.skills.icefall
		local gcd = boss.scheduler.globalCooldownSeconds
		local icefallEnd = math.max(gcd, icefall.firstAvailableSeconds) + icefall.telegraphSeconds
		r.check(("첫 낙빙 %.1f초 시작 → %.1f초 끝(기둥 생성) → + 전역 쿨 %d = %.1f초 ≤ 첫 포효 %d초(자리 비우기가 낙빙을 막지 않는다) · 포효 선행 조건 → 대체 스킬 = %s"):format(
			math.max(gcd, icefall.firstAvailableSeconds), icefallEnd, gcd, icefallEnd + gcd, roar.firstAvailableSeconds, tostring(roar.precondition and roar.precondition.otherwise)),
			roar.enabled ~= false and icefallEnd + gcd <= roar.firstAvailableSeconds and roar.precondition.otherwise == "icefall"
				and icefall.perMember == true and icefall.onImpact[1].type == "spawnProp")
		local run = BossSim.run(FROST, { partySize = 1 })
		r.check(("모형 시퀀스: %s@%.2f → %s@%.2f (기대 icefall → roar@16)"):format(run.sequence[1].id, run.sequence[1].at, run.sequence[2].id, run.sequence[2].at),
			run.sequence[1].id == "icefall" and run.sequence[2].id == "roar" and near(run.sequence[2].at, roar.firstAvailableSeconds, 0.06))
		-- 4인: 낙빙 원 = 인원 + 2, 멤버 각자 발밑에 하나씩. 기둥 하나의 그림자(폭 6)에 네 명(폭 2)이 한 줄로 선다.
		local circles = icefall.count + icefall.countPerMember * 4
		r.check(("4인 낙빙 %d개(각자 1 + 흩뿌림 2) ≤ 기둥 상한 %d · 그림자 폭 %dstud ≥ 몸통 폭 2"):format(circles, boss.props.pillar.maxCount, boss.props.pillar.radiusStuds * 2),
			circles == 6 and circles <= boss.props.pillar.maxCount and boss.props.pillar.radiusStuds * 2 >= 2)
	end)

	-- [8] 갑각 태세의 뼈대 상한(데이터) - 한 번의 태세에서 받는 반사 합계가 55%를 넘지 못한다
	r.section("반사 상한", function()
		local mechanics = BossData.mechanics
		local shell = BossData.bosses[SCORPION].skills.shell
		local partial = mechanics.gimmickFailMaxHpFraction / mechanics.partialFailDivisor
		local stanceSeconds = shell.telegraphSeconds - shell.stance.afterSeconds
		local windows = math.ceil(stanceSeconds / mechanics.reflect.windowSeconds)
		local tail = shell.finisher.damage.multiplier / 7
		r.check(("반사 1회 %.2f%%(= %.0f%% ÷ %d), 태세 %.1f초 ÷ 창 %.2f초 = 최대 %d창 → %.1f%% 요청, 발동당 상한 %.0f%%에서 잘림(28-2의 20%% x 3 = 60%%는 상한 밖이었다) · 같은 태세의 꼬리 x%d(앵커 %.1f%%)까지 다 맞아도 %.1f%% < 100%%"):format(
			partial * 100, mechanics.gimmickFailMaxHpFraction * 100, mechanics.partialFailDivisor, stanceSeconds, mechanics.reflect.windowSeconds, windows,
			windows * partial * 100, mechanics.gimmickFailMaxHpFraction * 100, shell.finisher.damage.multiplier, tail * 100, (mechanics.gimmickFailMaxHpFraction + tail) * 100),
			shell.enabled ~= false and shell.failPenalty == false and windows * partial >= mechanics.gimmickFailMaxHpFraction
				and mechanics.gimmickFailMaxHpFraction + tail < 1 and shell.stance.damageTakenMultiplier == 0)
	end)

	-- 29-3 추가(잠행 찌르기·모래 구덩이·낙뢰 넉백)의 안전선 - 전부 데이터에서 읽는다
	r.section("잠행·구덩이·넉백", function()
		local scorpion, storm = BossData.bosses[SCORPION], BossData.bosses.storm_lord
		local burrow, pit = scorpion.skills.stab.burrow, scorpion.props.pit
		local spawn = scorpion.skills.stab.onStart[1]
		local launch = storm.skills.strike.onHit[1]
		local tolerance = TerrainConfig.heightToleranceStuds
		r.check(("잠행 깊이 %.1fstud < 판정 높이차 상한 %d(보스가 대상을 놓치지 않는다) · 들어가기 %.1f초 ≤ 첫 예고 %.1f초 · 보이는 파트 = %s"):format(
			burrow.depthStuds, tolerance, burrow.enterSeconds, scorpion.skills.stab.telegraphSeconds, table.concat(burrow.visibleParts, ",")),
			burrow.depthStuds < tolerance and burrow.enterSeconds <= scorpion.skills.stab.telegraphSeconds)
		local maxTicks = math.ceil(12 / pit.coreTickSeconds)
		r.check(("모래 구덩이: 끌림 %dstud/s ≤ 걷기 %d의 절반(못 나오는 구덩이는 없다 - 빠져나오는 속도 %d) · 멤버에게서 반경 %d + %d 안에는 안 생긴다 · 바닥 %.2f%%/%.2f초 → 12초를 서 있어도(%d틱) 발동당 상한 %.0f%% · 무장 %.1f초 = 돌진 첫 예고"):format(
			pit.pullStudsPerSecond, WorldConfig.playerWalkSpeedStuds, WorldConfig.playerWalkSpeedStuds - pit.pullStudsPerSecond, pit.radiusStuds, spawn.clearStuds,
			pit.coreFraction * 100, pit.coreTickSeconds, maxTicks, BossData.mechanics.gimmickFailMaxHpFraction * 100, pit.armSeconds),
			pit.pullStudsPerSecond <= WorldConfig.playerWalkSpeedStuds / 2 and spawn.clearStuds > 0 and spawn.minStuds >= pit.radiusStuds + spawn.clearStuds
				and pit.coreFraction <= BossData.mechanics.gimmickFailMaxHpFraction and pit.armSeconds >= scorpion.skills.stab.telegraphSeconds)
		r.check(("낙뢰 넉백: 높이 %d < 판정 높이차 상한 %d · 아레나 벽 %d(맵 밖으로 못 나간다) · 거리 %d > 낙뢰 반경 %d(둘째 낙뢰의 원 밖에 떨어진다)"):format(
			launch.heightStuds, tolerance, WorldConfig.walls.heightStuds, launch.distanceStuds, storm.skills.strike.radiusStuds),
			launch.heightStuds < tolerance and launch.heightStuds < WorldConfig.walls.heightStuds and launch.distanceStuds > storm.skills.strike.radiusStuds)
	end)

	-- [2][11][12] 두 보스의 /gg boss check 전 항목 + 6종 인접 쌍 재검사
	r.section("스킬표 검사", function()
		local maxScale = BossRules.maxSkillRangeScale()
		for _, bossId in ipairs({ FROST, SCORPION }) do
			local rows, baseOk = BossSim.checkDodge(bossId, 1)
			local wideRows, wideOk = BossSim.checkDodge(bossId, maxScale)
			for index, row in ipairs(rows) do
				print(("[29-3][가]   %s | %s | %s | %.1f → %.1fstud | %.2f ≤ %.2f %s | %.2f ≤ %.2f %s"):format(bossId, row.skillId, row.label, row.distanceStuds,
					wideRows[index].distanceStuds, row.requiredSeconds, row.availableSeconds, row.ok and "O" or "X",
					wideRows[index].requiredSeconds, wideRows[index].availableSeconds, wideRows[index].ok and "O" or "X"))
			end
			r.check(("%s 회피 부등식 %d판정: 배율 1.00 %s · 최대 배율 %.3f %s"):format(bossId, #rows, baseOk and "통과" or "실패", maxScale, wideOk and "통과" or "실패"), baseOk and wideOk)
		end
		local total, violations = 0, 0
		for _, bossId in ipairs({ GUARDIAN, FROST, "abyssal_lord", "crystal_queen", SCORPION, "storm_lord" }) do
			local rows, count = BossSim.checkPairs(bossId)
			total += #rows
			violations += count
		end
		r.check(("6종 인접 쌍 %d개 중 100%% 이상인 가능한 쌍 %d건"):format(total, violations), violations == 0)
	end)

	-- [17] 안 건드린 세 보스 - 결정 모형 값이 29-2 Play와 같은가(기믹은 여전히 꺼져 있다)
	r.section("회귀", function()
		for _, bossId in ipairs(UNTOUCHED) do
			local expected = UNTOUCHED_SECONDS[bossId]
			local values = {
				BossSim.run(bossId, { partySize = 1 }).seconds, BossSim.run(bossId, { partySize = 4 }).seconds,
				BossSim.run(bossId, { partySize = 1, design = true, breaks = "always" }).seconds, BossSim.run(bossId, { partySize = 4, design = true, breaks = "always" }).seconds,
				BossSim.run(bossId, { partySize = 1, design = true, breaks = "never" }).seconds, BossSim.run(bossId, { partySize = 4, design = true, breaks = "never" }).seconds,
			}
			local same, gimmickOff = true, true
			for index, value in ipairs(values) do
				same = same and near(value, expected[index], 0.06)
			end
			for _, id in ipairs(BossData.bosses[bossId].skillOrder) do
				local skill = BossData.bosses[bossId].skills[id]
				if skill.role == "gimmick" then
					gimmickOff = gimmickOff and skill.enabled == false
				end
			end
			r.check(("%s: 기믹 enabled=false 그대로=%s, 결정 모형 6값 29-2와 동일=%s(%.2f/%.2f · %.2f/%.2f · %.2f/%.2f)"):format(
				bossId, tostring(gimmickOff), tostring(same), values[1], values[2], values[3], values[4], values[5], values[6]), same and gimmickOff)
		end
		local guardian = BossSim.run(GUARDIAN, { partySize = 1 })
		r.check(("구간 수호자 솔로 %.2f초(기준 73.30)"):format(guardian.seconds), near(guardian.seconds, 73.30, 0.06))
	end)

	local passCount, totalCount = r.summary()
	print(("===29-3 검증 끝(가)=== %d/%d 통과"):format(passCount, totalCount))
end

-- ─────────────────────────── (나) 실제 서버 경로 ───────────────────────────

local function spawnBoss(player, env, bossId)
	BossEncounter.despawnFor(player)
	env.applyStage(player, BossData.stageInterval)
	PlayerProfile.clearBossRotationPending(player)
	PlayerProfile.forceBossRotationNext(player, bossId)
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

-- 실시간으로 보스를 돌린다(어그로와 무관하게 직접 step) - until()이 참이거나 seconds가 지나면 멈춘다. 검증 캐릭터는
-- 스킬을 피하지 않으므로 keepAlive면 매 틱 체력을 채운다.
local function drive(player, root, model, data, seconds, keepAlive, untilFn)
	local startedAt = os.clock()
	local stepSeconds, stepCount = 0, 0
	while os.clock() - startedAt < seconds do
		RunService.Heartbeat:Wait()
		if keepAlive then
			PlayerState.setHp(player, PlayerState.getMaxHp(player))
		end
		local before = os.clock()
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
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

local function runFrost(player, env, r, root)
	-- [3] 첫 포효 전에 기둥이 반드시 존재하는가 - 실제 스케줄러를 실시간으로. 플레이어는 가만히 서 있는다(최악의 경우).
	local perStepRoar = nil
	r.section("서리 거인 실시간", function()
		local model, data = spawnBoss(player, env, FROST)
		local bossPosition = model.PrimaryPart.Position
		moveTo(root, bossPosition + Vector3.new(12, 0, 0))
		local _, clockStartedAt = BossPatterns.debugClocks(model)
		local starts, pillarsAtRoar, lastCurrent = {}, nil, nil
		local perStep = drive(player, root, model, data, 22, true, function()
			local _, startedAt, current = BossPatterns.debugClocks(model)
			clockStartedAt = startedAt
			if current ~= lastCurrent then
				if current then
					table.insert(starts, ("%s@+%.1f"):format(current, os.clock() - clockStartedAt))
					if current == "roar" then
						pillarsAtRoar = BossArenaProps.count(model, "pillar")
						return true
					end
				end
				lastCurrent = current
			end
			return false
		end)
		perStepRoar = perStep
		r.check(("실시간 시퀀스: %s | 첫 포효가 시작된 순간의 기둥 %s개(기대 ≥ 1, 솔로 낙빙 3개)"):format(table.concat(starts, " "), tostring(pillarsAtRoar)),
			starts[1] ~= nil and starts[1]:match("^icefall@") ~= nil and starts[2] ~= nil and starts[2]:match("^roar@%+16") ~= nil
				and pillarsAtRoar ~= nil and pillarsAtRoar >= 1)
	end)

	-- [3] 기둥이 하나도 없으면 포효 대신 낙빙 → 그다음이 포효
	r.section("포효 선행 조건", function()
		local model, data = spawnBoss(player, env, FROST)
		moveTo(root, model.PrimaryPart.Position + Vector3.new(12, 0, 0))
		BossArenaProps.clear(model)
		local st = MonsterState.getBossPatternState(model)
		st.graceUntil = 0
		st.sched.readyAt.roar, st.sched.readyAt.icefall, st.sched.readyAt.slam, st.sched.readyAt.spike = 0, math.huge, math.huge, math.huge -- 포효만 준비된 상태
		st.sched.lastEndAt, st.sched.lastSkillId = -math.huge, nil
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		local _, _, first = BossPatterns.debugClocks(model)
		r.check(("기둥 0개 + 포효만 준비됨 → 실제로 시작한 스킬 = %s(기대 icefall - 피할 방법이 없는 포효는 없다), 포효의 자리 비우기 유지=%s"):format(
			tostring(first), tostring(st.sched.seen.roar == nil)), first == "icefall" and st.sched.seen.roar == nil)
		drive(player, root, model, data, 3, true, function()
			return BossPatterns.getPhase(model) == "normal"
		end)
		local made = BossArenaProps.count(model, "pillar")
		st.sched.lastEndAt = -math.huge
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		local _, _, second = BossPatterns.debugClocks(model)
		r.check(("낙빙이 끝난 뒤 기둥 %d개 → 다음 스킬 = %s(기대 roar)"):format(made, tostring(second)), made >= 1 and second == "roar")
	end)

	-- [4][5] 포효 판정 - 기둥 뒤/밖, 4인(스탠드인 3명 + 본인)이 한 기둥 뒤에 한 줄로
	r.section("포효 판정", function()
		local model, data = spawnBoss(player, env, FROST)
		local encounter = BossEncounter.getEncounter(player)
		local bossPosition = model.PrimaryPart.Position
		local pillarDef = data.props.pillar
		local pillarPosition = Vector3.new(bossPosition.X + 25, 1, bossPosition.Z)
		BossArenaProps.clear(model)
		BossArenaProps.spawn(model, "pillar", pillarDef, pillarPosition)
		local members = { player }
		local function standIn(name, offset)
			local fakeRoot = { Position = bossPosition + offset }
			local fake = { Name = name, UserId = -9300 - #members, Parent = workspace }
			fake.Character = { FindFirstChild = function(_, child)
				return child == "HumanoidRootPart" and fakeRoot or nil
			end }
			PlayerState.init(fake)
			table.insert(members, fake)
			BossEncounter.debugAddMember(model, fake)
			return fake
		end
		local behind2 = standIn("StandInBehind2", Vector3.new(32, 0, 0))
		local behind3 = standIn("StandInBehind3", Vector3.new(35, 0, 1))
		local edge = standIn("StandInEdge", Vector3.new(38, 0, 5.5)) -- 가장자리: 선분-중심 거리 3.6 ≤ 4
		moveTo(root, bossPosition + Vector3.new(29, 0, 0))
		fullHeal(player)
		BossPatterns.force(model, data, "roar")
		local function step()
			BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, members)
		end
		step()
		local gateAtTelegraph = BossMechanics.isGateArmed(model)
		local st = MonsterState.getBossPatternState(model)
		st.phaseEndsAt = os.clock() -- 예고 3초를 기다리지 않는다(판정 로직만 본다)
		step()
		local trappedCount = 0
		for _, member in ipairs(members) do
			trappedCount += BossTrap.isTrapped(member) and 1 or 0
		end
		r.check(("4인이 한 기둥 뒤에(29·32·35·가장자리 38): 잡힌 사람 %d명(기대 0), 본인 체력 %.0f%%, 게이트 예고 때 %s → 판정 뒤 %s, 가려 준 기둥은 부서짐(남은 기둥 %d)"):format(
			trappedCount, hpFraction(player) * 100, tostring(gateAtTelegraph), tostring(BossMechanics.isGateArmed(model)), BossArenaProps.count(model, "pillar")),
			trappedCount == 0 and near(hpFraction(player), 1, 1e-9) and gateAtTelegraph and not BossMechanics.isGateArmed(model)
				and BossArenaProps.count(model, "pillar") == 0 and behind2 ~= nil and behind3 ~= nil and edge ~= nil)
		for index = #members, 2, -1 do
			PlayerState.clear(members[index])
			table.remove(encounter.members, table.find(encounter.members, members[index]))
			table.remove(members, index)
		end

		-- 기둥 밖: 55% + 빙결 + 얼음 덩어리
		BossArenaProps.spawn(model, "pillar", pillarDef, pillarPosition)
		moveTo(root, bossPosition + Vector3.new(0, 0, 30))
		fullHeal(player)
		BossPatterns.interrupt(model, data)
		BossPatterns.force(model, data, "roar")
		step()
		MonsterState.getBossPatternState(model).phaseEndsAt = os.clock()
		step()
		task.wait(0.1)
		local iceBlock = nil
		for _, candidate in ipairs(MonsterState.getAllModels()) do
			if MonsterState.isRescueTarget(candidate) then
				iceBlock = candidate
			end
		end
		r.check(("기둥 밖에서 포효: 체력 %.1f%%(기대 45), 잡힘=%s(%s), 게이트 %s, 안 가려 준 기둥은 그대로(%d개), 얼음 덩어리=%s"):format(
			hpFraction(player) * 100, tostring(BossTrap.isTrapped(player)), tostring(player:GetAttribute("BossTrapKind")), tostring(BossMechanics.isGateArmed(model)),
			BossArenaProps.count(model, "pillar"), tostring(iceBlock ~= nil)),
			near(hpFraction(player), 1 - BossData.mechanics.gimmickFailMaxHpFraction, 1e-6) and BossTrap.isTrapped(player)
				and player:GetAttribute("BossTrapKind") == "frozen" and BossMechanics.isGateArmed(model) and BossArenaProps.count(model, "pillar") == 1 and iceBlock ~= nil)

		-- [6] 빙결 구출 - 얼음을 실제 피해 경로(MonsterState.applyDamage)로 때린다. 구출자는 스탠드인 둘(근접·원거리 구분은
		-- 이 경로에 없다 - AttackServer의 근접·투사체 분기와 SkillServer가 전부 같은 applyDamage로 들어온다).
		if iceBlock then
			local rescuerA = { Name = "StandInRescuerA", UserId = -9320, Parent = workspace }
			local rescuerB = { Name = "StandInRescuerB", UserId = -9321, Parent = workspace }
			local config = BossData.mechanics.rescue.hitCount
			local _, dealt = MonsterState.applyDamage(iceBlock, 1e9, BossData.stageInterval, rescuerA)
			local afterOne = player:GetAttribute("BossTrapRescue")
			MonsterState.applyDamage(iceBlock, 1e9, BossData.stageInterval, rescuerA) -- 0.5초 안의 연타는 안 센다
			local afterSpam = player:GetAttribute("BossTrapRescue")
			MonsterState.applyDamage(iceBlock, 1e9, BossData.stageInterval, player) -- 잡힌 본인은 못 센다
			MonsterState.applyDamage(iceBlock, 1e9, BossData.stageInterval, rescuerB) -- 다른 구출자는 합산된다
			local afterTwo = player:GetAttribute("BossTrapRescue")
			task.wait(config.hitIntervalSeconds + 0.05)
			MonsterState.applyDamage(iceBlock, 1e9, BossData.stageInterval, rescuerA)
			task.wait(0.1)
			r.check(("빙결 구출: 1타 %.2f → 연타 %.2f(그대로) → 다른 구출자 %.2f(합산) → %.1f초 뒤 3타째 풀림=%s, 얼음에 들어간 피해 %.0f(보상·흡혈 없음), 얼음 치워짐=%s, 루트 고정 해제=%s"):format(
				afterOne or -1, afterSpam or -1, afterTwo or -1, config.hitIntervalSeconds, tostring(not BossTrap.isTrapped(player)), dealt,
				tostring(iceBlock.Parent == nil), tostring(root.Anchored == false)),
				near(afterOne, 1 / 3, 1e-6) and afterSpam == afterOne and near(afterTwo, 2 / 3, 1e-6) and not BossTrap.isTrapped(player)
					and dealt == 0 and iceBlock.Parent == nil and root.Anchored == false)
		end

		-- 빙결 강타가 범위 안 기둥을 부수고, 얼음 가시가 기둥에서 끊기는가
		BossPatterns.interrupt(model, data)
		BossArenaProps.clear(model)
		BossArenaProps.spawn(model, "pillar", pillarDef, Vector3.new(bossPosition.X + 15, 1, bossPosition.Z)) -- 강타 반경 18 안
		BossArenaProps.spawn(model, "pillar", pillarDef, Vector3.new(bossPosition.X + 40, 1, bossPosition.Z)) -- 밖
		moveTo(root, bossPosition + Vector3.new(60, 0, 0))
		BossPatterns.force(model, data, "slam")
		step()
		MonsterState.getBossPatternState(model).phaseEndsAt = os.clock()
		step()
		local afterSlam = BossArenaProps.count(model, "pillar")
		fullHeal(player)
		BossPatterns.force(model, data, "spike") -- 대상(60stud)과 보스 사이에 기둥(40stud)이 있다
		step()
		local beamLength = MonsterState.getBossPatternState(model).crossBeams[1].length
		MonsterState.getBossPatternState(model).phaseEndsAt = os.clock()
		step()
		r.check(("빙결 강타: 기둥 2개 → %d개(반경 안 하나만 부서짐) · 얼음 가시: 길이 %.1fstud(기둥 앞 37에서 끊김), 기둥 뒤 60stud의 본인 체력 %.0f%%(안 맞음), 막아 준 기둥 부서짐(남은 %d)"):format(
			afterSlam, beamLength, hpFraction(player) * 100, BossArenaProps.count(model, "pillar")),
			afterSlam == 1 and near(beamLength, 37, 0.5) and near(hpFraction(player), 1, 1e-9) and BossArenaProps.count(model, "pillar") == 0)
	end)

	-- 힌트 단계 - 전멸할 때마다 전조가 친절해지는가(1 = 안전지대 화살표, 2 = 예고 x1.5)
	r.section("서리 거인 힌트", function()
		local model, data = spawnBoss(player, env, FROST)
		BossEncounter.resetFor(player)
		BossEncounter.resetFor(player)
		fullHeal(player)
		BossArenaProps.spawn(model, "pillar", data.props.pillar, model.PrimaryPart.Position + Vector3.new(25, 0, 0))
		BossPatterns.force(model, data, "roar")
		local startedAt = os.clock()
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		local st = MonsterState.getBossPatternState(model)
		local telegraph = st.phaseEndsAt - startedAt
		r.check(("전멸 2회 → 힌트 %d단계, 포효 예고 %.2f초(기대 3.0 x 1.5 = 4.5), 전멸 리셋 때 기둥도 치워짐 → 다시 세운 1개만=%s"):format(
			BossPatterns.getHintLevel(model), telegraph, tostring(BossArenaProps.count(model, "pillar") == 1)),
			BossPatterns.getHintLevel(model) == 2 and near(telegraph, 4.5, 0.05) and BossArenaProps.count(model, "pillar") == 1)
		BossEncounter.debugClearHints(player)
	end)
	return perStepRoar
end

local function runScorpion(player, env, r, root)
	local mechanics = BossData.mechanics
	local partial = mechanics.gimmickFailMaxHpFraction / mechanics.partialFailDivisor
	local function newStandIn(name, position)
		local fakeRoot = { Position = position }
		local humanoid = { MoveDirection = Vector3.zero }
		local fake = { Name = name, UserId = -9400, Parent = workspace }
		fake.Character = {
			FindFirstChild = function(_, child)
				return child == "HumanoidRootPart" and fakeRoot or nil
			end,
			FindFirstChildOfClass = function()
				return humanoid
			end,
		}
		function fake:SetAttribute() end
		function fake:GetAttribute()
			return nil
		end
		PlayerState.init(fake)
		return fake, fakeRoot, humanoid
	end
	local function lostOf(member)
		return 1 - PlayerState.getHp(member) / PlayerState.getMaxHp(member)
	end
	-- 서리 거인 구역의 빙결 구출이 남긴 해제 유예 면역(2초)이 끝나길 기다린다. 29-3 첫 Play: 구역들이 쉬지 않고 이어져
	-- 구출 뒤 2초 안에 반사를 쟀고, 본인의 반사 피해가 0.00으로 찍혔다(같은 순간 스탠드인 B는 18.3%) - 유예가 일한 것이다.
	task.wait(mechanics.trap.releaseGraceSeconds + 0.2)

	-- [7][8][9] 반사 - 때린 사람에게만, 0.75초 창당 1회, 합계 55% 상한, 태세 전에 떠난 공격은 반사 없음
	r.section("갑각 반사", function()
		local model, data = spawnBoss(player, env, SCORPION)
		local encounter = BossEncounter.getEncounter(player)
		local kitCount, quicksand = #(encounter.kitParts or {}), 0
		for _, part in ipairs(encounter.kitParts or {}) do
			quicksand += (part.Name == "Quicksand") and 1 or 0
		end
		r.check(("전갈 여왕 아레나 kit: 파트 %d개(유사 웅덩이 %d, 상한 40)"):format(kitCount, quicksand), kitCount == #data.arenaKit.parts and quicksand == 2 and kitCount <= 40)

		local bossPosition = model.PrimaryPart.Position
		local hitterB = newStandIn("StandInHitterB", bossPosition + Vector3.new(0, 0, 40))
		local archerC = newStandIn("StandInArcherC", bossPosition + Vector3.new(0, 0, -40))
		local members = { player, hitterB, archerC }
		BossEncounter.debugAddMember(model, hitterB)
		BossEncounter.debugAddMember(model, archerC)
		fullHeal(player)
		local _, maxHp = MonsterState.getBossHp(model)
		local probe = maxHp * 0.001
		local function step()
			BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, members)
		end
		local function hit(attacker, info)
			local _, dealt = MonsterState.applyDamage(model, probe, BossData.stageInterval, attacker, info)
			return dealt / probe
		end

		BossPatterns.force(model, data, "shell")
		step()
		local st = MonsterState.getBossPatternState(model)
		local noticeDealt = hit(player)
		r.check(("예고 1초(태세 전): phase=%s, 때리면 들어간 피해 x%.3f(게이트 g), 반사 %d회, 체력 %.0f%% - 아직 때려도 된다"):format(
			BossPatterns.getPhase(model), noticeDealt, BossMechanics.reflectCount(model, player), hpFraction(player) * 100),
			BossPatterns.getPhase(model) == "gimmickTelegraph" and near(noticeDealt, BossRules.gateDamageTakenMultiplier(), 1e-6)
				and BossMechanics.reflectCount(model, player) == 0 and near(hpFraction(player), 1, 1e-9))

		local beforeStance = os.clock()
		task.wait(0.05)
		st.stanceAt = os.clock() -- 예고 1초를 기다리지 않고 태세로
		st.phaseEndsAt = os.clock() + 30 -- 판정은 아래에서 직접 당긴다
		step()
		local first = hit(player)
		local afterFirst = 1 - hpFraction(player)
		hit(player)
		hit(player)
		local afterSpam = 1 - hpFraction(player)
		hit(hitterB)
		local bLost = lostOf(hitterB)
		hit(archerC, { committedAt = beforeStance }) -- 태세가 서기 전에 쏜 화살이 태세 중에 닿았다
		hit(archerC, { indirect = true }) -- 꽂힌 화살의 지연 폭발
		local cLost = lostOf(archerC)
		r.check(("태세 중 1타: 보스에 들어간 피해 x%.1f, 때린 본인 -%.1f%%(기대 %.1f) → 같은 창의 연타 2회 뒤 -%.1f%%(그대로) | 다른 멤버 B가 때림: B -%.1f%%, 본인은 그대로 | C(태세 전에 쏜 화살·꽂힌 화살): -%.1f%%, 반사 %d회"):format(
			first, afterFirst * 100, partial * 100, afterSpam * 100, bLost * 100, cLost * 100, BossMechanics.reflectCount(model, archerC)),
			first == 0 and near(afterFirst, partial, 1e-6) and near(afterSpam, partial, 1e-6) and near(bLost, partial, 1e-6)
				and cLost == 0 and BossMechanics.reflectCount(model, archerC) == 0)

		for _ = 1, 3 do
			task.wait(mechanics.reflect.windowSeconds + 0.05)
			hit(player)
		end
		local total = 1 - hpFraction(player)
		r.check(("0.75초마다 3번 더 때림(합 4창): 본인 -%.1f%%(기대 상한 %.0f%% - 한 번의 태세로 죽지 않는다), 반사 %d회, B는 여전히 -%.1f%%"):format(
			total * 100, mechanics.gimmickFailMaxHpFraction * 100, BossMechanics.reflectCount(model, player), lostOf(hitterB) * 100),
			near(total, mechanics.gimmickFailMaxHpFraction, 1e-6) and PlayerState.getHp(player) > 0 and near(lostOf(hitterB), partial, 1e-6))

		st.phaseEndsAt = os.clock()
		step()
		local afterResolve = hit(archerC)
		r.check(("판정: 반사 받은 둘은 실패(추가 피해·잡힘 없음 - 잡힘 %s/%s), 안 받은 C가 성공 → 게이트 %s, 꼬리 박힘 창 x%.2f(기대 %.1f), phase=%s(헤롱 자세 %d초), 태세 뒤에는 반사 없음(C 반사 %d회)"):format(
			tostring(BossTrap.isTrapped(player)), tostring(BossTrap.isTrapped(hitterB)), tostring(BossMechanics.isGateArmed(model)), afterResolve,
			data.skills.shell.breakWindow.damageTakenMultiplier, BossPatterns.getPhase(model), data.skills.shell.recoverSeconds, BossMechanics.reflectCount(model, archerC)),
			not BossTrap.isTrapped(player) and not BossTrap.isTrapped(hitterB) and not BossMechanics.isGateArmed(model)
				and near(afterResolve, data.skills.shell.breakWindow.damageTakenMultiplier, 1e-6) and BossPatterns.getPhase(model) == "gimmickRecover"
				and near(total, 1 - hpFraction(player), 1e-6))
		for _, fake in ipairs({ hitterB, archerC }) do
			PlayerState.clear(fake)
			table.remove(encounter.members, table.find(encounter.members, fake))
		end
		fullHeal(player)
	end)

	-- [10] 꼬리 내려찍기 → 속박(모래 무덤) → 밀어서 꺼낸다. 본인은 입장점(보스에서 86stud)에 둔다 - 보스 곁에 서면 어그로가
	-- 붙어 MonsterAI도 같은 보스를 step하고(구출 틱이 두 번 돌아 시간이 절반으로 잡힌다), 스탠드인이 AI의 대상이 된다.
	r.section("속박 push 구출", function()
		local model, data = spawnBoss(player, env, SCORPION)
		local encounter = BossEncounter.getEncounter(player)
		local bossPosition = model.PrimaryPart.Position
		local finisher = data.skills.shell.finisher
		-- (1) 꼬리에 맞으면 속박되는가: 근접 자리(보스 앞 8stud = 꼬리가 떨어지는 원의 한가운데)의 스탠드인
		local victim, victimRoot = newStandIn("StandInTailVictim", bossPosition + Vector3.new(0, 0, finisher.offsetStuds))
		local bystander = newStandIn("StandInBystander", bossPosition + Vector3.new(0, 0, finisher.offsetStuds + finisher.radiusStuds + 2))
		BossEncounter.debugAddMember(model, victim)
		BossEncounter.debugAddMember(model, bystander)
		local members = { victim, bystander, player }
		BossPatterns.force(model, data, "shell")
		BossPatterns.step(model, data, bossPosition, victim, victimRoot, 1 / 60, members)
		MonsterState.getBossPatternState(model).phaseEndsAt = os.clock()
		BossPatterns.step(model, data, bossPosition, victim, victimRoot, 1 / 60, members)
		local victimRecord = BossTrap.getRecord(victim)
		r.check(("꼬리 내려찍기(보스 앞 %dstud의 원 r%d): 원 한가운데의 멤버 잡힘=%s(%s, 구출 %s, 무덤 자리 기록=%s), 원 밖 %dstud의 멤버 잡힘=%s"):format(
			finisher.offsetStuds, finisher.radiusStuds, tostring(victimRecord ~= nil), tostring(victimRecord and victimRecord.kind),
			tostring(victimRecord and victimRecord.rescueType), tostring(victimRecord and victimRecord.context and victimRecord.context.origin ~= nil),
			finisher.radiusStuds + 2, tostring(BossTrap.isTrapped(bystander))),
			victimRecord ~= nil and victimRecord.kind == "buried" and victimRecord.rescueType == "push" and victimRecord.context.origin ~= nil
				and not BossTrap.isTrapped(bystander))
		BossTrap.release(victim, "reset")
		for _, fake in ipairs({ victim, bystander }) do
			PlayerState.clear(fake)
			table.remove(encounter.members, table.find(encounter.members, fake))
		end
		BossPatterns.interrupt(model, data)

		-- (2) 밀기: 본인을 같은 함수(BossMechanics.trapMember - 꼬리가 부르는 그 함수)로 묻고 스탠드인이 민다.
		fullHeal(player)
		BossMechanics.trapMember(model, data, player)
		local origin = player:GetAttribute("BossTrapOrigin")
		local rescuer, rescuerRoot, rescuerHumanoid = newStandIn("StandInPusher", root.Position - Vector3.new(3, 0, 0))
		BossEncounter.debugAddMember(model, rescuer)
		members = { player, rescuer }
		local startPosition = root.Position
		rescuerHumanoid.MoveDirection = Vector3.new(0, 0, 1) -- 먼저 엉뚱한 방향(친구 쪽이 아니다)
		drive(player, root, model, data, 0.5, true)
		local wrongDirection = player:GetAttribute("BossTrapRescue") or 0
		rescuerHumanoid.MoveDirection = Vector3.new(1, 0, 0)
		local pushStartedAt = os.clock()
		local function pushStep()
			rescuerRoot.Position = root.Position - Vector3.new(3, 0, 0) -- 밀리는 만큼 따라붙는다
			BossPatterns.step(model, data, bossPosition, player, root, 1 / 60, members)
		end
		while BossTrap.isTrapped(player) and os.clock() - pushStartedAt < 4 do
			RunService.Heartbeat:Wait()
			pushStep()
		end
		local elapsed = os.clock() - pushStartedAt
		local pushed = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(startPosition.X, 0, startPosition.Z)).Magnitude
		r.check(("밀기: 잡힘 종류 %s·무덤 자리 Attribute=%s·루트 고정 → 엉뚱한 방향으로 걸으면 진행 %.2f(기대 0) → 친구 쪽으로 걸어 %.2f초 만에 풀림(기대 %.1f), 밀린 거리 %.1fstud(기대 무덤 반경 %d), 풀린 직후 유예 면역 x%.1f(%.0f초), 루트 고정 해제=%s"):format(
			tostring(victimRecord and "buried"), tostring(origin ~= nil), wrongDirection, elapsed, mechanics.trap.rescueSeconds, pushed,
			mechanics.rescue.push.graveRadiusStuds, PlayerState.getIncomingDamageMultiplier(player), mechanics.trap.releaseGraceSeconds, tostring(root.Anchored == false)),
			origin ~= nil and wrongDirection == 0 and not BossTrap.isTrapped(player) and near(elapsed, mechanics.trap.rescueSeconds, 0.3)
				and near(pushed, mechanics.rescue.push.graveRadiusStuds, 0.5) and PlayerState.getIncomingDamageMultiplier(player) == 0 and root.Anchored == false)
		PlayerState.clear(rescuer)
		table.remove(encounter.members, table.find(encounter.members, rescuer))
	end)

	-- 실시간: 첫 스킬 = 갑각 10초(자리 비우기) + step 비용(태세·반사 듣는 귀 포함)
	local perStep = nil
	r.section("전갈 여왕 실시간", function()
		local model, data = spawnBoss(player, env, SCORPION)
		local starts, lastCurrent = {}, nil
		perStep = drive(player, root, model, data, 16, true, function()
			local _, startedAt, current = BossPatterns.debugClocks(model)
			if current ~= lastCurrent then
				if current then
					table.insert(starts, ("%s@+%.1f"):format(current, os.clock() - startedAt))
				end
				lastCurrent = current
			end
			return #starts >= 1 and current == nil
		end)
		r.check(("실시간 시퀀스: %s (기대 첫 스킬 = shell@+10 - 자리 비우기)"):format(table.concat(starts, " ")),
			starts[1] ~= nil and starts[1]:match("^shell@%+10") ~= nil)
	end)
	return perStep
end

-- 29-3 추가: 잠행 찌르기(겉모습만 바뀐 돌진)·모래 구덩이·낙뢰 넉백. 본인은 입장점(보스에서 86stud)에 둔다 - 어그로가 붙지 않는다.
local function runExtras(player, env, r, root)
	local mechanics = BossData.mechanics
	task.wait(mechanics.trap.releaseGraceSeconds + 0.2) -- 앞 구역의 밀기 구출이 남긴 해제 유예 면역이 끝나길 기다린다

	r.section("잠행 찌르기·모래 구덩이", function()
		local model, data = spawnBoss(player, env, SCORPION)
		local skill, pit = data.skills.stab, data.props.pit
		local surfaceY = model.PrimaryPart.Position.Y
		local head, tail = model:FindFirstChild("Head"), model:FindFirstChild("TailSpike")
		fullHeal(player)
		BossPatterns.force(model, data, "stab")
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		local pits = BossArenaProps.list(model)
		local nearest = math.huge
		for _, prop in ipairs(pits) do
			nearest = math.min(nearest, (Vector3.new(prop.position.X, 0, prop.position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude)
		end
		r.check(("잠행 찌르기 시작: 모래 구덩이 %d개(기대 3), 가장 가까운 구덩이 중심까지 %.1fstud(기대 ≥ 반경 %d + 여유 %d)"):format(
			#pits, nearest, pit.radiusStuds, skill.onStart[1].clearStuds), #pits == 3 and nearest >= pit.radiusStuds + skill.onStart[1].clearStuds - 1e-3)

		-- 구덩이 바닥에 서 있는다: 무장(1.5초) 직후 첫 틱만 잰다 - 돌진이 86stud를 달려오기(≈ 2.9초) 전이다.
		local startedAt = os.clock()
		moveTo(root, pits[1].position + Vector3.new(0, 3, 0))
		local sunkY, headHidden, tailShown = nil, nil, nil
		drive(player, root, model, data, 3, false, function()
			local elapsed = os.clock() - startedAt
			if not sunkY and elapsed > skill.burrow.enterSeconds + 0.2 then
				sunkY, headHidden, tailShown = model.PrimaryPart.Position.Y, head and head.Transparency == 1, tail and tail.Transparency < 1
			end
			return elapsed > pit.armSeconds + 0.3
		end)
		local lost = 1 - hpFraction(player)
		r.check(("들어가는 모션 뒤: 몸통 %.1fstud 아래(기대 %.1f), 머리 가림=%s · 꼬리 보임=%s | 구덩이 바닥에서 무장 %.1f초 뒤 첫 틱: 체력 -%.2f%%(기대 %.2f)"):format(
			surfaceY - (sunkY or surfaceY), skill.burrow.depthStuds, tostring(headHidden), tostring(tailShown), pit.armSeconds, lost * 100, pit.coreFraction * 100),
			near(surfaceY - (sunkY or surfaceY), skill.burrow.depthStuds, 0.05) and headHidden == true and tailShown == true and near(lost, pit.coreFraction, 1e-6))

		BossPatterns.interrupt(model, data) -- 땅속에서 중단(대상 사망·전멸 리셋과 같은 길) - 땅속에 남으면 안 된다
		r.check(("잠행 중 중단: 몸통 높이 복귀=%s(%.2f → %.2f), 머리 다시 보임=%s, 구덩이 %d개(기대 0), phase=%s"):format(
			tostring(near(model.PrimaryPart.Position.Y, surfaceY, 0.01)), sunkY or -1, model.PrimaryPart.Position.Y, tostring(head and head.Transparency < 1),
			BossArenaProps.count(model, "pit"), BossPatterns.getPhase(model)),
			near(model.PrimaryPart.Position.Y, surfaceY, 0.01) and head ~= nil and head.Transparency < 1 and BossArenaProps.count(model, "pit") == 0
				and BossPatterns.getPhase(model) == "normal")
		fullHeal(player)

		-- 끝까지: 두 번 달리고 솟아올라 헤롱, 끝나면 지표·전부 보임·구덩이 0. 본인은 매 틱 체력을 채운다(돌진을 안 피한다).
		BossPatterns.force(model, data, "stab")
		local phases, lastPhase = {}, nil
		drive(player, root, model, data, 20, true, function()
			local phase = BossPatterns.getPhase(model)
			if phase ~= lastPhase then
				table.insert(phases, phase)
				lastPhase = phase
			end
			return phase == "normal" and #phases > 1
		end)
		r.check(("잠행 찌르기 끝까지: %s | 끝난 뒤 몸통 높이 복귀=%s, 머리 보임=%s, 구덩이 %d개"):format(table.concat(phases, " → "),
			tostring(near(model.PrimaryPart.Position.Y, surfaceY, 0.01)), tostring(head and head.Transparency < 1), BossArenaProps.count(model, "pit")),
			table.concat(phases, ">") == "focus>charge>focus>charge>chargeRecover>normal" and near(model.PrimaryPart.Position.Y, surfaceY, 0.01)
				and head ~= nil and head.Transparency < 1 and BossArenaProps.count(model, "pit") == 0)
		fullHeal(player)
	end)

	r.section("낙뢰 넉백", function()
		local model, data = spawnBoss(player, env, "storm_lord")
		fullHeal(player)
		BossPatterns.force(model, data, "strike")
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		local st = MonsterState.getBossPatternState(model)
		st.phaseEndsAt = os.clock()
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		local launched = st.lastLaunch
		r.check(("낙뢰에 맞음 → 넉백 대상=%s(본인), 둘째 낙뢰 예고로 이어짐 phase=%s, 넉백은 29-3 값 그대로(높이 %s·거리 %s - 29-4의 회오리는 다른 스킬이다)"):format(
			tostring(launched and launched.player and launched.player.Name), BossPatterns.getPhase(model),
			tostring(launched and launched.effect.heightStuds), tostring(launched and launched.effect.distanceStuds)),
			launched ~= nil and launched.player == player and BossPatterns.getPhase(model) == "meteorTelegraph"
				and launched.effect.heightStuds == 5 and launched.effect.distanceStuds == 8 and launched.effect.holdSeconds == nil)
		BossPatterns.interrupt(model, data)
		task.wait(1) -- 튕겨 난 캐릭터가 내려앉을 시간
		fullHeal(player)
	end)
end

local function runRegen(player, env, r)
	-- [14][15] 보스전 중 기본 자동회복 꺼짐 / 재생 옵션 몫은 작동 / 끝나면 다시 켜짐
	r.section("자동회복", function()
		local function measure(seconds)
			PlayerState.setHp(player, PlayerState.getMaxHp(player) * 0.4)
			PlayerState.setLastCombatActionAt(player, os.clock() - CombatConfig.regenDelaySeconds - 1) -- "5초 쉬었다"
			local before = hpFraction(player)
			local startedAt = os.clock()
			task.wait(seconds)
			return (hpFraction(player) - before) / (os.clock() - startedAt)
		end
		BossEncounter.despawnFor(player)
		env.applyOptionStack(player, "attackPercent") -- 재생 옵션 0인 기준 빌드
		local outside = measure(1)
		spawnBoss(player, env, GUARDIAN)
		local inside = measure(1)
		local attribute = player:GetAttribute("Regenerating")
		env.applyOptionStack(player, "healingPower")
		local bonus = PlayerProfile.getHealingPowerMultiplier(player) - 1
		local insideOption = measure(1)
		BossEncounter.despawnFor(player) -- 이탈(스테이지 이동과 같은 경로)
		local afterLeave = measure(1)
		spawnBoss(player, env, GUARDIAN)
		BossEncounter.resetFor(player) -- 전멸 리셋 - 보스전은 이어진다
		local afterWipe = measure(0.5)
		-- 처치와 같은 경로(endEncounter) - 실제 처치(CombatResolution.resolveHit)는 clearForModel 뒤에 despawn까지 부른다.
		-- clearFor만 부르면 encounter만 지워지고 모델이 아레나에 고아로 남아, 같은 슬롯에 다음 보스가 들어올 때 두 마리가 된다.
		local killed = BossEncounter.getActive(player)
		BossEncounter.clearFor(player)
		MonsterSpawner.despawn(killed)
		local afterKill = measure(1)
		local base = CombatConfig.regenPercentPerSecond
		r.check(("자동회복 %%/초: 보스전 밖 %.2f(기대 %.0f) → 보스전 중 %.2f(기대 0, Regenerating=%s) → 재생 옵션 +%.0f%% %.2f(기대 %.2f = 옵션 몫만) → 이탈 뒤 %.2f → 전멸 리셋 뒤(보스전 계속) %.2f → 처치 뒤 %.2f"):format(
			outside * 100, base * 100, inside * 100, tostring(attribute), bonus * 100, insideOption * 100, base * bonus * 100,
			afterLeave * 100, afterWipe * 100, afterKill * 100),
			near(outside, base, base * 0.15) and near(inside, 0, 1e-6) and attribute ~= true and bonus > 0 and near(insideOption, base * bonus, base * bonus * 0.15)
				and near(afterLeave, base * (1 + bonus), base * (1 + bonus) * 0.15) and near(afterWipe, base * bonus, base * bonus * 0.3)
				and near(afterKill, base * (1 + bonus), base * (1 + bonus) * 0.15))
		fullHeal(player)
	end)
end

local function runLive(player, env)
	print("===29-3 검증 시작(나: 실제 서버 경로)===")
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
		local perStepFrost = runFrost(player, env, r, root)
		local perStepScorpion = runScorpion(player, env, r, root)
		runExtras(player, env, r, root)
		runRegen(player, env, r)
		-- [18] step 비용 - 기둥·선행 조건(서리 거인)과 태세·반사(전갈 여왕)가 도는 구간
		for label, perStep in pairs({ ["서리 거인(낙빙 → 포효 직전, 기둥 3개)"] = perStepFrost, ["전갈 여왕(갑각 태세 포함)"] = perStepScorpion }) do
			if perStep then
				print(("[29-3][나] 성능 %s: BossPatterns.step 평균 %.1f마이크로초/틱 → 보스전 12개 x 60Hz = 초당 %.2fms = 프레임당 %.3fms (29-2 실측 38.7 ~ 43.4마이크로초, 예산 프레임당 1.2ms)"):format(
					label, perStep * 1e6, perStep * 12 * 60 * 1000, perStep * 12 * 1000))
				r.check(("성능 %s: step 평균 < 100마이크로초"):format(label), perStep < 100e-6)
			end
		end
	end
	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	-- 검증이 끝난 뒤 encounter 없는 보스 모델이 남아 있으면 안 된다(29-4: 고아 수호자가 같은 슬롯의 다음 보스와 겹쳐 "보스 두 마리"가 됐다)
	local orphans = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d개(기대 0)"):format(orphans), orphans == 0)
	fullHeal(player)
	env.restore(player)
	local passCount, totalCount = r.summary()
	print(("===29-3 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

function BossGimmickVerify.runPure()
	runPure()
end

function BossGimmickVerify.runLive(player, env)
	runLive(player, env)
end

return BossGimmickVerify
