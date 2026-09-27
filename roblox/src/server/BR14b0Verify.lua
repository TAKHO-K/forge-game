-- BR1-4b 파트 0 자동 검증 - 후속 정리(docs/phase/BR1-4b0-report.md).
--   (가) 순수: 속사 중 공속 상한(×6.25 - 옛 규칙과 같은 값) · 상한 3종이 도달 최대를 안 자름 · 낙하 표(안전 · 25 · 50 · 75% · 세 번째 정거장) · 치명 확률 100% 초과 처리.
--   (나) 실제 서버: 공중 대시 = 서버 낙하 궤적 최고점 재측정(DashHook) · 구간 수호자 대공 잡기 → 돌진 연속 금지(실제 보스 step 스케줄러 - 대조군 = 강공격 뒤엔 돌진이 나온다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local Option = require(ReplicatedStorage.Shared.Option)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)

local V = {}

local function near(a, b, tol)
	return a ~= nil and b ~= nil and math.abs(a - b) <= tol
end

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[BR1-4b0][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[BR1-4b0][%s] %s"):format(tag, label))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return pass, total
	end
	return r
end

function V.runPure()
	print("===BR1-4b0 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("0-1 속사 중 공속 상한", function()
		-- 옛 규칙 = min(1 + s, 2.5) × 버프(버프 ≤ 속사 상한 2.5) - 새 규칙은 이 범위에서 값이 같아야 한다(EconSim 불변)
		local worst = 0
		for _, s in ipairs({ 0, 0.5, 1.0, 1.5, 3.0, 9.8 }) do
			for _, buff in ipairs({ 1, 1.225, 1.96, 2.5 }) do
				local old = math.min(1 + s, CombatConfig.attackSpeedMaxMultiplier) * buff
				worst = math.max(worst, math.abs(PlayerCombat.getTotalSpeedMultiplier(s, buff) - old))
			end
		end
		local future = PlayerCombat.getTotalSpeedMultiplier(9.8, 4) -- 앞으로 버프가 더 커져도
		local noBuff = PlayerCombat.getTotalSpeedMultiplier(9.8, 1)
		local quickMax = CombatConfig.attackSpeedMaxMultiplier * SkillData.bow.Q.attackSpeedCap
		r.check(("옛 규칙과 차이 최대 %.2g · 속사 최대 실효 %.2f = 상한 %.2f · 버프 ×4(가상) → %.2f · 버프 없음 → %.2f"):format(worst, quickMax, CombatConfig.attackSpeedMaxMultiplierBuffed, future, noBuff),
			worst < 1e-9 and near(quickMax, CombatConfig.attackSpeedMaxMultiplierBuffed, 1e-9) and near(future, CombatConfig.attackSpeedMaxMultiplierBuffed, 1e-9) and near(noBuff, CombatConfig.attackSpeedMaxMultiplier, 1e-9))
	end)

	r.section("0-2 상한 3종 = 도달 최대 위", function()
		local L = InfiniteStageConfig.hardMaxStage
		local function mx(id, classId)
			return 8 * Option.valueOf({ id = id, roll = OptionData.rollMax, roll2 = OptionData.rollMax }, "primordial", L, classId)
		end
		local crit = Option.valueOf({ id = "crit", roll = OptionData.rollMax, roll2 = OptionData.rollMax }, "primordial", L)
		local rows, ok = {}, true
		local function row(label, value, id)
			local cap = OptionData.options[id].cap
			table.insert(rows, ("%s %.3f ≤ %.2f"):format(label, value, cap or -1))
			ok = ok and cap ~= nil and value < cap
		end
		row("위력", mx("attackPercent"), "attackPercent")
		row("치명 확률", 8 * crit.critRate, "crit")
		row("치명 피해", 8 * crit.critDmg, "crit")
		row("대검 Q", mx("skill_greatsword_Q", "greatsword"), "skill_greatsword_Q")
		row("대검 E", mx("skill_greatsword_E", "greatsword"), "skill_greatsword_E")
		row("쌍검 E", mx("skill_dualblade_E", "dualblade"), "skill_dualblade_E")
		r.check(("8자리 태초 · 롤 최대 · 레벨 %d: %s(안 잘림)"):format(L, table.concat(rows, " · ")), ok)
		local sources = {}
		for i = 1, 9 do
			sources[i] = { option = { id = "attackPercent", roll = OptionData.rollMax }, grade = "primordial", itemLevel = L }
		end
		r.check(("9자리(가상) 위력 합 → 상한 %.2f에서 잘림"):format(Option.sumAxisBonus(sources, "attackPercent")), near(Option.sumAxisBonus(sources, "attackPercent"), OptionData.options.attackPercent.cap, 1e-9))
		-- 치명 확률 100% 초과(현황 보고 - 처리 방식은 K5): 평소 = 넘친 몫 버려짐(늘 치명) · 확정 치명 버프 중 = 고정 +guaranteedCritOverflowBonus
		local force, bonus = PlayerCombat.resolveGuaranteedCrit("bow", true, 1.5)
		local _, bonus2 = PlayerCombat.resolveGuaranteedCrit("bow", false, 1.5)
		r.note(("치명 확률 100%% 초과: 확정 치명 버프 중 → 강제 %s · 치명 피해 +%.2f(넘친 양과 무관한 고정값) · 버프 없음 → +%.2f(넘친 몫 버려짐)"):format(tostring(force), bonus, bonus2))
	end)

	r.section("0-4 낙하 표", function()
		local F = MovementConfig.fall
		local safe = MoveRules.fallSafeHeight()
		local apex = JumpMath.maxClimbStuds(MovementConfig.airJump.charges, false, MovementConfig.jumpHeightBonusCap)
		local rows, ok = {}, true
		for _, want in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
			local h = safe + want * (F.lethalHeight - safe)
			local out = MoveRules.fallOutcome(JumpMath.fallSpeedFromHeight(h) + (want == 1 and 1e-6 or 0))
			table.insert(rows, ("%.1f → %.0f%%(%s)"):format(h, out.fraction * 100, out.kind))
			ok = ok and near(out.fraction, want, 1e-6)
		end
		r.check(("안전 높이 %.2f(데이터 고정 · 3단 정점 %.2f + %.2f) · 높이별 피해: %s · 세 번째 정거장 = %d"):format(safe, apex, safe - apex, table.concat(rows, " · "), F.lethalHeight),
			ok and safe == F.safeHeight and safe > apex)
		-- 사용자 보충: 안전 높이 = max(고정값, 그 플레이어의 최대 합법 정점 + 여유) - 환생 0 · 3 지금 값 + 점프력이 높아진 가상 경우(상한 +50%)
		local function fakePlayer(tier)
			return { GetAttribute = function(_, name)
				return name == "MoveTier" and tier or nil
			end }
		end
		local s0, s3 = MoveRules.fallSafeHeight(fakePlayer(0)), MoveRules.fallSafeHeight(fakePlayer(3))
		local oldCap = MovementConfig.jumpHeightBonusCap
		MovementConfig.jumpHeightBonusCap = 0.5
		local ok2, err = pcall(function()
			local bigApex = JumpMath.maxClimbStuds(MovementConfig.airJump.charges, false, 0.5)
			local sBig = MoveRules.fallSafeHeight(fakePlayer(3))
			local own = MoveRules.fallOutcome(JumpMath.fallSpeedFromHeight(bigApex), fakePlayer(3))
			local base0 = MoveRules.fallOutcome(JumpMath.fallSpeedFromHeight(safe - 0.01), fakePlayer(0))
			r.check(("플레이어별 안전 높이: 환생 0 %.3f · 환생 3 %.3f(지금 ≈ 고정값 - 정점 21.384 + 3) · 점프력 +50%%(가상) 환생 3 → %.2f(자기 정점 %.2f 낙하 = %s) · 환생 0 고정 높이 낙하 = %s"):format(s0, s3, sBig, bigApex, own.kind, base0.kind),
				near(s0, F.safeHeight, 0.01) and near(s3, F.safeHeight, 0.01) and near(sBig, bigApex + F.apexMarginStuds, 1e-6) and own.kind == "none" and base0.kind == "none")
		end)
		MovementConfig.jumpHeightBonusCap = oldCap
		assert(ok2, err)
	end)

	local pass, total = r.summary()
	print(("===BR1-4b0 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===BR1-4b0 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local AirState = require(script.Parent.AirState)
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local MonsterState = require(script.Parent.MonsterState)
	local HeightGuard = require(script.Parent.HeightGuard)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		r.check("캐릭터 없음", false)
		print("===BR1-4b0 검증 끝(나)=== 0/1 통과")
		return
	end
	local origin = root.CFrame

	r.section("0-4 공중 대시 = 낙하 궤적 최고점 재측정(DashHook)", function()
		local spot = Vector3.new(0, WorldMapData.floorTopY + 30, WorldMapData.progress.treeRadius + 45) -- 나무 둘레 밖
		root.Anchored = true
		root.CFrame = CFrame.new(spot)
		AirState.debugPaused = true
		local st = AirState.stateOf(player)
		st.takeoffCount += 1
		st.grounded = false
		st.session = { id = st.takeoffCount, since = os.clock() - 3, takeoffPos = spot, fromLadder = false, airDashes = 0, airAttacks = 0, ledgeUsed = false, counted = true, peakY = spot.Y + 300, lowY = spot.Y }
		local session = st.session
		local before = MoveRules.fallOutcome((AirState.fallSpeedOf({ peakY = session.peakY }, spot.Y - 20)))
		local status = ServerStorage.DashHook:Invoke(player, true)
		local after = MoveRules.fallOutcome((AirState.fallSpeedOf(session, spot.Y - 20)))
		r.check(("300 위에서 떨어지다 공중 대시(%s) → 최고점 %.1f(대시 자리 %.1f) · 20 아래 착지: 대시 없음 %s %.0f%% → 대시 %s %.0f%%"):format(tostring(status), session.peakY, spot.Y,
			before.kind, before.fraction * 100, after.kind, after.fraction * 100), status == "ok" and near(session.peakY, spot.Y, 0.5) and before.kind ~= "none" and after.kind == "none")
		st.session, st.lastSession, st.grounded, st.groundPos = nil, nil, true, spot
		AirState.debugPaused = false
		HeightGuard.reset(player)
	end)

	r.section("0-3 수호자 대공 잡기 → 돌진 연속 금지(실제 보스 step)", function()
		local H = require(script.Parent.BR1Verify).helpers
		local function run(firstId, seed)
			local model, data = H.spawnBoss(player, env, "section_guardian", seed, 15)
			assert(model, "보스 스폰 실패")
			local pst = MonsterState.getBossPatternState(model) or {}
			BossPatterns.force(model, data, firstId)
			H.drive(player, root, model, data, 25, function()
				pst = MonsterState.getBossPatternState(model) or pst
				return pst.sched and pst.sched.lastSkillId == firstId and pst.current == nil
			end)
			pst = MonsterState.getBossPatternState(model) or pst
			local last = pst.sched and pst.sched.lastSkillId
			-- 돌진만 준비된 상태로 둔다(다른 스킬은 먼 미래) → 실제 step이 무엇을 고르나
			for id in pairs(pst.sched and pst.sched.readyAt or {}) do
				pst.sched.readyAt[id] = id == "charge" and 0 or math.huge
			end
			local picked = nil
			H.drive(player, root, model, data, 12, function()
				local cur = (MonsterState.getBossPatternState(model) or {}).current
				if cur ~= nil and cur ~= firstId then
					picked = cur
					return true
				end
				return false
			end)
			BossEncounter.despawnFor(player)
			return last, picked
		end
		local lastA, pickedA = run("grab", 4701)
		local lastB, pickedB = run("heavy", 4702)
		r.check(("대공 잡기 뒤 돌진만 준비 → 12초 동안 고른 것 %s(기대 없음 - 직전 %s) · 대조군 강공격 뒤 → %s(기대 charge - 직전 %s)"):format(tostring(pickedA), tostring(lastA), tostring(pickedB), tostring(lastB)),
			lastA == "grab" and pickedA == nil and lastB == "heavy" and pickedB == "charge")
	end)

	root.Anchored = false
	root.CFrame = origin
	HeightGuard.reset(player)
	env.restore(player)
	local pass, total = r.summary()
	print(("===BR1-4b0 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
