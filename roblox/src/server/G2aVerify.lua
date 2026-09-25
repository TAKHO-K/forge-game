-- G2a 자동 검증(docs/phase/G2a-report.md) - 이동 수치 확정 · G1 결정 반영.
--   (가) 회피 부등식 전 보스(한 체공 두 박자 줄 없음 - M1-0에서 폐기) · 높이 검증 판정(합성 표본) · 이속 · 점프력 상한.
--   M1-0: 이단점프 상한형 · 한 체공 두 박자 · 점프력 옵션 아레나 무시가 폐기돼 그 항목을 새 규칙으로 바꿨다(공중 점프 식 · 체공 표는 M1_0Verify(가)).
--   (나) 실제 Player: 높이 검증(띄워 두기 = 되돌림 · 점프 = 오탐 0) · 리더보드 거절(height_guard) · 보스 기여도 = 계수 전 피해 · 걷기 상한 ×1.5와 공속 그대로.
--   클라 이단점프 · 공중대시 배타 · 구조물 낙하 · 카메라는 서버에서 못 누른다 - 스크린샷 Play에서 MCP로 잰다(보고서 ③).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local HeightGuard = require(script.Parent.HeightGuard)

local G2aVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[G2a][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return passCount, totalCount
	end
	return r
end

local function near(a, b, tol)
	return math.abs(a - b) <= (tol or 1e-6)
end

function G2aVerify.runPure()
	print("===G2a 검증 시작(가)===")
	local r = newRecorder("가")
	local h1 = MovementConfig.jumpHeightStuds

	r.section("회피 부등식(전 보스)", function()
		local allOk, air = true, 0
		for _, scale in ipairs({ 1, BossRules.maxSkillRangeScale() }) do
			for bossId in pairs(BossData.bosses) do
				local rows, ok = BossSim.checkDodge(bossId, scale)
				allOk = allOk and ok
				for _, row in ipairs(rows) do
					if row.label:find("체공", 1, true) then
						air += 1
					end
				end
			end
		end
		r.check(("회피 부등식 전 보스 × 범위 배율 1 · 최대 전부 통과 %s · 한 체공 두 박자 줄 %d(기대 0 - M1-0 폐기) - 박자 값 그대로"):format(tostring(allOk), air), allOk and air == 0)
	end)

	r.section("높이 검증 판정(합성)", function()
		local allow = JumpMath.heightGuardAllowance()
		local function run(samples)
			local st = { strikes = 0, graceUntil = 0, exemptUntil = 0, reverts = 0 }
			local out = {}
			for i, s in ipairs(samples) do
				if s.exempt then
					st.exemptUntil = s.exempt
				end
				table.insert(out, HeightGuard.evaluate(st, s, i * 0.5)) -- 표본 0.5초 간격(첫 표본의 기준 잡기 유예 1초가 셋째 표본 전에 끝난다)
			end
			return table.concat(out, ","), st
		end
		local function at(y, grounded, x)
			return { feetY = y, pos = Vector3.new(x or 0, y + 3, 0), grounded = grounded }
		end
		local jump = run({ at(0, true), at(0, true), at(5, false), at(7.2, false), at(4, false), at(0, true) })
		local over = allow + 3 -- M1-0: 허용치가 공중 점프 최대 도달까지 올라갔다(8.92 → 22.38) - 날기 표본은 허용치 기준으로
		local fly = run({ at(0, true), at(0, true), at(4, false), at(over, false), at(over, false), at(over, false) })
		local platform = run({ at(0, true), at(0, true), at(6, false), at(3.5, true), at(3.5 + allow - 1, false), at(3.5, true) })
		local launchSamples = { at(0, true), at(0, true), at(12, false), at(over, false), at(8, false), at(0, true) }
		launchSamples[3].exempt = 3
		local launch = run(launchSamples)
		local teleport = run({ at(0, true), at(0, true), at(40, false, 200), at(40, false, 200), at(44, false, 200) })
		local probeSamples = { at(0, true), at(0, true), at(over, false), at(over, false) }
		probeSamples[3].probe = function() return over end -- FloorMaterial이 늦어 공중으로 보이지만 발 바로 아래가 지면
		probeSamples[4].probe = function() return over end
		local probe = run(probeSamples)
		-- 리뷰 1: 테라스(6)에 올라선 착지를 폴링이 놓치고 곧바로 다시 뜀(발 6 + 최대 도달 > 기준 0 + 허용) → 발 아래 지면 6 기준으로 통과
		local missedSamples = { at(0, true), at(0, true), at(4, false), at(12, false), at(6 + allow - 1, false), at(8, false) }
		for i = 4, 6 do
			missedSamples[i].probe = function() return 6 end
		end
		local missed = run(missedSamples)
		-- 날기: 발 아래 지면이 멀리(0)면 그대로 걸린다
		local flyProbe = { at(0, true), at(0, true), at(4, false), at(over, false), at(over, false) }
		for i = 3, 5 do
			flyProbe[i].probe = function() return 0 end
		end
		local flyWithGround = run(flyProbe)
		local anchored = run({ at(0, true), at(0, true), { feetY = over, pos = Vector3.new(0, over + 3, 0), grounded = false, skip = true }, { feetY = over, pos = Vector3.new(0, over + 3, 0), grounded = false, skip = true } })
		local ok = jump == "reset,ok,ok,ok,ok,ok" and fly == "reset,ok,ok,strike,revert,strike" and platform == "reset,ok,ok,ok,ok,ok" and launch == "reset,ok,ok,ok,ok,ok"
			and teleport == "reset,ok,reset,ok,ok" and probe == "reset,ok,ok,ok" and anchored == "reset,ok,ok,ok"
			and missed == "reset,ok,ok,ok,ok,ok" and flyWithGround == "reset,ok,ok,strike,revert"
		r.check(("허용 %.2f(M1-0 = 7.92 × 2.7 + 1) · 점프 [%s] · 띄워 두기 [%s](기대 둘째 넘음에서 revert) · 단상 위 점프 [%s] · 넉백 예외 [%s] · 순간이동 [%s] · 서 있음(광선) [%s] · 루트 고정 [%s] · 착지 놓친 테라스 재점프 [%s] · 날기(아래 지면 멀리) [%s]"):format(
			allow, jump, fly, platform, launch, teleport, probe, anchored, missed, flyWithGround), ok and near(allow, 22.384, 1e-3))
	end)

	r.section("이속 · 점프력 상한", function()
		local shoes = 5.49 -- 태초 신발(D0 (f) ≈ 104 stud/s)
		local walk = JumpMath.moveSpeedMultiplier(shoes) * MovementConfig.walkSpeedStuds
		local oldWalk = PlayerCombat.getSpeedMultiplier(shoes) * MovementConfig.walkSpeedStuds
		r.check(("걷기 배율: 0 → %.2f · +30%% → %.2f · 태초 신발 +549%% → %.2f(= %.0f stud/s, 옛 %.0f) · 공속 배율 그대로 %.2f(상한 없음)"):format(
			JumpMath.moveSpeedMultiplier(0), JumpMath.moveSpeedMultiplier(0.3), JumpMath.moveSpeedMultiplier(shoes), walk, oldWalk, PlayerCombat.getSpeedMultiplier(shoes)),
			JumpMath.moveSpeedMultiplier(0) == 1 and near(JumpMath.moveSpeedMultiplier(0.3), 1.3) and JumpMath.moveSpeedMultiplier(shoes) == MovementConfig.moveSpeedMaxMultiplier
				and near(PlayerCombat.getSpeedMultiplier(shoes), 6.49))
		local capped = JumpMath.jumpHeight(0.5)
		r.check(("점프력 +50%% 요청 → %.2f(상한 +%.0f%%) < 판정 층 %.1f · 옵션 없음 %.2f(M1-0: 보스 아레나도 같은 값)"):format(
			capped, MovementConfig.jumpHeightBonusCap * 100, TerrainConfig.heightToleranceStuds, JumpMath.jumpHeight(0)),
			near(capped, 7.92) and capped < TerrainConfig.heightToleranceStuds and JumpMath.jumpHeight(0) == h1)
		local g = MovementConfig.gravity
		local natural = math.sqrt(2 * 3.5 / g)
		local v = MovementConfig.structureDropSpeedStuds
		local dropped = (-v + math.sqrt(v * v + 2 * g * 3.5)) / g
		r.check(("구조물 무너짐 낙하(윗면 3.5): 그냥 %.3f초 → 아래 속도 %d로 %.3f초"):format(natural, v, dropped), dropped < natural)
	end)

	local pass, count = r.summary()
	print(("===G2a 검증 끝(가)=== %d/%d 통과"):format(pass, count))
end

function G2aVerify.runLive(player, env)
	print("===G2a 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local MonsterState = require(script.Parent.MonsterState)
	local BossEncounter = require(script.Parent.BossEncounter)
	local Leaderboard = require(script.Parent.Leaderboard)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	r.section("높이 검증 실제 Player", function()
		assert(root and humanoid, "캐릭터 없음")
		BossEncounter.despawnFor(player)
		HeightGuard.debugOff = false
		HeightGuard.reset(player)
		task.wait(1.5) -- 서 있는 자리를 기준으로
		local st = HeightGuard.getState(player)
		local reverts0 = st.reverts
		-- ① 점프 = 오탐 0(서버가 Jump를 켠다 - 1단)
		local base0 = root.Position.Y
		humanoid.Jump = true
		task.wait(1.2)
		local afterJump = st.reverts - reverts0
		-- ①-2 넉백(높이 12 > 허용 8.92): 보스 패턴과 같은 길(exempt + BossPatternEvent "launch") → 되돌림 0
		local patternEvent = ReplicatedStorage:FindFirstChild("BossPatternEvent")
		local launchHeight = 12
		HeightGuard.exempt(player, JumpMath.launchAirSeconds(launchHeight))
		local launchPeak = root.Position.Y
		if patternEvent then
			patternEvent:FireClient(player, "launch", { from = root.Position + Vector3.new(1, 0, 0), heightStuds = launchHeight, distanceStuds = 4 })
		end
		local tl = os.clock()
		while os.clock() - tl < 2 do
			task.wait(0.05)
			launchPeak = math.max(launchPeak, root.Position.Y)
		end
		local afterLaunch = st.reverts - reverts0 - afterJump
		local launchRise = launchPeak - base0
		-- ② 띄워 두기(날기 부정 흉내): AlignPosition으로 루트를 기준 + (허용 + 3)에 붙잡는다 → 0.5초 안팎에 되돌림(M1-0: 옛 +14는 이제 합법 높이)
		local base = root.Position
		local revertsBeforeAlign = st.reverts
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local align = Instance.new("AlignPosition")
		align.Mode = Enum.PositionAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.RigidityEnabled = true
		align.Position = base + Vector3.new(0, JumpMath.heightGuardAllowance() + 3, 0)
		align.Parent = root
		local t0 = os.clock()
		local caught
		while os.clock() - t0 < 3 do
			task.wait(0.05)
			if st.reverts > revertsBeforeAlign then
				caught = os.clock() - t0
				break
			end
		end
		align:Destroy()
		attachment:Destroy()
		task.wait(1)
		r.check(("넉백 높이 %d(허용 %.2f 초과): 서버가 본 루트 최고 +%.1f · 되돌림 %d(기대 0 - 넉백 예외)"):format(launchHeight, JumpMath.heightGuardAllowance(), launchRise, afterLaunch),
			afterLaunch == 0 and patternEvent ~= nil)
		r.check(("1단 점프 되돌림 %d(기대 0) · 띄워 두기(허용 + 3) 되돌림 %s초 뒤(기대 ≤ 1.5 - 폴링 0.25 × 연속 2) · 기록 시각 있음 %s"):format(
			afterJump, caught and ("%.2f"):format(caught) or "없음", tostring(st.flaggedAt ~= nil)),
			afterJump == 0 and caught ~= nil and caught <= 1.5 and st.flaggedAt ~= nil)
		-- ③ 리더보드: 이 판(10초 전 시작)에 되돌림이 있었다 → 거절
		local judged = Leaderboard.onBossCleared({ stage = 10, bossId = "x", bossMaxHp = 1, seconds = 10, isParty = false, members = { { player = player, advanced = false, reason = "verify", ratio = 1 } }, contributors = {} })
		local clean = Leaderboard.onBossCleared({ stage = 10, bossId = "x", bossMaxHp = 1, seconds = 0.01, isParty = false, members = { { player = player, advanced = false, reason = "verify", ratio = 1 } }, contributors = {} })
		r.check(("리더보드: 보스전 중 되돌림 → 거절 %s(기대 height_guard) · 되돌림 전에 시작한 판이 아니면(0.01초) %s(기대 nil)"):format(tostring(judged.rejected), tostring(clean.rejected)),
			judged.rejected == "height_guard" and clean.rejected == nil)
		st.flaggedAt = nil
	end)
	HeightGuard.debugOff = true -- 리뷰: 절 안에서 에러가 나도 체인에는 꺼진 채로 돌아간다

	r.section("보스 기여도 = 계수 전 피해", function()
		local STAGE = 500
		local saved = CharacterLevel.debugLevelGapOff
		PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(1))
		env.applyStage(player, STAGE)
		BossEncounter.despawnFor(player)
		BossEncounter.spawnFor(player, STAGE)
		local encounter = BossEncounter.getEncounter(player)
		assert(encounter and encounter.model, "보스 스폰 실패")
		CharacterLevel.debugLevelGapOff = false
		local hp0, maxHp = MonsterState.getBossHp(encounter.model)
		MonsterState.applyDamage(encounter.model, maxHp * 0.01, STAGE, player)
		local hp1 = MonsterState.getBossHp(encounter.model)
		local contribution = MonsterState.getContributors(encounter.model)[player] or 0
		local floor = CharacterLevel.levelGapDealMultiplier(1, STAGE) -- 계수를 켠 채로 읽는다(Play 2: 스위치를 되돌린 뒤 읽어 1.00이 나왔다 - 검증 쪽)
		CharacterLevel.debugLevelGapOff = saved
		local dealt = (hp0 - hp1) / maxHp
		local taken = contribution / 0.01 -- 보스가 받는 피해 배율(파훼 창 등 - 스폰 직후 보통 1)
		r.check(("Lv.1 · 보스 스테이지 %d: 최대 HP 1%% 피해 → 실제 깎인 HP %.4f%% · 기여 %.4f%%(받는 배율 ×%.2f) · 깎인 ÷ 기여 = %.3f(기대 계수 ×%.2f - 기여는 계수 전) · 문턱 10%%와 알림이 이 값"):format(
			STAGE, dealt * 100, contribution * 100, taken, dealt / math.max(contribution, 1e-12), floor),
			near(dealt / math.max(contribution, 1e-12), floor, 1e-6) and taken > 0 and floor < 1)
		BossEncounter.despawnFor(player)
	end)

	r.section("걷기 상한 실제", function()
		assert(humanoid, "캐릭터 없음")
		local original = PlayerProfile.getSpeedPercentBonus
		PlayerProfile.getSpeedPercentBonus = function()
			return 5.49
		end
		PlayerProfile.refreshMovementSpeed(player)
		local walk, attr = humanoid.WalkSpeed, player:GetAttribute("SpeedPercentBonus")
		PlayerProfile.getSpeedPercentBonus = original
		PlayerProfile.refreshMovementSpeed(player)
		r.check(("신속 합 +549%%: WalkSpeed %.1f(기대 %.0f = 16 × %.1f) · 공속용 SpeedPercentBonus %.2f(기대 5.49 그대로) · 되돌린 뒤 %.1f"):format(
			walk, MovementConfig.walkSpeedStuds * MovementConfig.moveSpeedMaxMultiplier, MovementConfig.moveSpeedMaxMultiplier, attr or -1, humanoid.WalkSpeed),
			near(walk, MovementConfig.walkSpeedStuds * MovementConfig.moveSpeedMaxMultiplier, 0.01) and near(attr or 0, 5.49))
	end)

	env.restore(player)
	local orphan = 0
	for _, m in ipairs(MonsterState.getAllModels()) do
		local d = MonsterState.getData(m)
		if d and d.isBoss and not BossEncounter.getEncounterByModel(m) then
			orphan += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d(기대 0)"):format(orphan), orphan == 0)
	local pass, count = r.summary()
	print(("===G2a 검증 끝(나)=== %d/%d 통과"):format(pass, count))
end

return G2aVerify
