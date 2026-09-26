-- C1 자동 검증(기준 스테이지 · 스테이지 전환 · 보상 자격 · 토벌 스테이지). id = "C1(가)" · "C1(나)".
--   (가) 순수: MobShare 규칙(오르기 재정규화 · 내리기 비율 유지 · 스테이지 변경 지우기 · 혼자면 초기화 · 도움 참여 · 자격) · RaidRules · 악용 시뮬레이터(C1Sim - 전/후 표) · 고스테이지 표본
--   (나) 실제 서버: 실제 잡몹 + 실제 Player + 스탠드인 - applyDamage 기준 상승 · 자격 · 스테이지 Attribute 변경 → 지우기/초기화 · 8초 만료 → 기준 내리기 · 실제 처치 보상(자격 없는 스탠드인 = 에러 0) ·
--        치유 참여(noteSupport) · 어그로 참여(MonsterAI) · 파티 활동 지우기 · BossGate.raidCheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobShare = require(ReplicatedStorage.Shared.MobShare)
local RaidRules = require(ReplicatedStorage.Shared.RaidRules)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local MonsterPrefixData = require(ReplicatedStorage.Shared.data.MonsterPrefixData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local C1Sim = require(script.Parent.C1Sim)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[C1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[C1][%s] %s"):format(tag, label))
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

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9)
end

local function fmt(v)
	if v == nil then
		return "-"
	end
	if math.abs(v) >= 1e6 then
		return ("%.3e"):format(v)
	end
	return ("%.2f"):format(v)
end

function V.runPure()
	print("===C1 검증 시작(가)===")
	local r = newRecorder("가")
	local k = InfiniteStageConfig.growthRate
	local W = CombatConfig.participationWindowSeconds

	r.section("기준 스테이지 규칙", function()
		local low, high, mid = {}, {}, {}
		local mob = MobShare.fresh({})
		local ref = MobShare.touch(mob, low, 10, 0)
		MobShare.applyRatio(mob, low, 0.6, 0)
		r.check(("첫 참여 = 기준 %s · 비율 %.2f"):format(tostring(ref), mob.hpRatio), ref == 10 and near(mob.hpRatio, 0.4))
		ref = MobShare.touch(mob, high, 30, 1)
		local expect = 1 - 0.6 * k ^ (10 - 30)
		r.check(("오를 때 재정규화 10 → 30: 비율 %.6f(기대 %.6f) · 낮은 기여 0.6 → %.6f(× k^−20) · 첫 타격 다시(%s) · 타격 수 다시(%s)"):format(mob.hpRatio, expect, mob.contributions[low], tostring(mob.firstHitAt[low]), tostring(mob.hitCounts[low])),
			ref == 30 and near(mob.hpRatio, expect) and near(mob.contributions[low], 0.6 * k ^ -20) and mob.firstHitAt[low] == 1 and mob.hitCounts[low] == nil)
		MobShare.touch(mob, mid, 20, 2)
		r.check("낮은 사람이 더 와도 기준 그대로(30)", mob.refStage == 30)
		local before = mob.hpRatio
		ref = MobShare.touch(mob, low, 10, 1 + W + 0.5) -- high · mid 만료(마지막 1 · 2) - mid는 2 + W 이후라 아직 남음
		r.check(("최고 참여자 %d초 무참여 → 기준 %s(참여자 중 최고 = 20) · 비율 유지 %.6f = %.6f"):format(W, tostring(ref), mob.hpRatio, before), ref == 20 and near(mob.hpRatio, before))
		r.check("기준이 20으로 내려감 → 스테이지 30 사람 자격 없음(above_ref)", select(2, MobShare.eligible(mob, high, 30)) ~= nil)
	end)

	r.section("스테이지 변경 · 초기화", function()
		local a, b = {}, {}
		local solo = MobShare.fresh({})
		MobShare.touch(solo, a, 50, 0)
		MobShare.applyRatio(solo, a, 0.7, 0)
		local wasReset = MobShare.purge(solo, a)
		r.check(("나만 참여한 몹: 지우면 체력 가득(%.2f) · 기준 없음"):format(solo.hpRatio), wasReset and solo.hpRatio == 1 and solo.refStage == nil and next(solo.contributions) == nil)
		local shared = MobShare.fresh({})
		MobShare.touch(shared, a, 50, 0)
		MobShare.applyRatio(shared, a, 0.3, 0)
		MobShare.touch(shared, b, 40, 0)
		MobShare.applyRatio(shared, b, 0.3, 0)
		wasReset = MobShare.purge(shared, a)
		MobShare.refresh(shared, 0)
		r.check(("다른 참여자가 있으면 초기화 안 함 · 내 기록만 지움 · 기준 50 → %s · 비율 %.2f 유지"):format(tostring(shared.refStage), shared.hpRatio),
			not wasReset and shared.contributions[a] == nil and shared.firstHitAt[a] == nil and shared.refStage == 40 and near(shared.hpRatio, 0.4))
		-- 기록된 스테이지와 다른 스테이지로 다시 닿으면(견습 전환 등 놓친 경로) 먼저 지운다
		local lazy = MobShare.fresh({})
		MobShare.touch(lazy, a, 50, 0)
		MobShare.applyRatio(lazy, a, 0.5, 0)
		local _, reset2 = MobShare.touch(lazy, a, 49, 0.5)
		r.check("기록 스테이지 ≠ 지금 스테이지로 닿음 → 먼저 지움(혼자 = 초기화)", reset2 and lazy.hpRatio == 1 and lazy.partStage[a] == 49)
		local ok, why = MobShare.eligible(shared, b, 41)
		r.check(("자격: 기록 스테이지 40 · 지금 41 → 없음(%s)"):format(tostring(why)), not ok and why == "stage_changed")
	end)

	r.section("도움 참여", function()
		local fighter, healer, idle = {}, {}, {}
		local mob = MobShare.fresh({})
		MobShare.touch(mob, fighter, 10, 0)
		r.check("참여 중인 사람을 도움 → 도운 사람도 참여(기준 = 도운 사람 60)", MobShare.support(mob, healer, 60, fighter, 1) and mob.refStage == 60)
		r.check(("%d초 넘게 안 싸운 사람을 도움 → 참여 아님"):format(W), not MobShare.support(mob, idle, 90, fighter, 1 + W + 1))
	end)

	r.section("토벌 스테이지(RaidRules)", function()
		local boss = BossRules.bossIdForStage(BossData.stageInterval)
		local cases = {
			{ 38, 35, true, 35 }, { 20, 35, true, 20 }, { 36, 35, true, 35 }, { 35, 35, true, 35 },
		}
		for _, c in ipairs(cases) do
			local ok, why, stage = RaidRules.check({ currentStage = c[1], bestBossCleared = c[2], bossId = boss, remote = false, gateUsable = false })
			r.check(("선택 %d · 최고 클리어 %d → 토벌 %s(%s)"):format(c[1], c[2], tostring(stage), tostring(why)), ok == c[3] and stage == c[4])
		end
		local ok1, why1 = RaidRules.check({ currentStage = 40, bestBossCleared = 35, bossId = boss, remote = false, gateUsable = true })
		r.check(("미클리어 보스 스테이지 40에 서 있음 → 불가(%s)"):format(tostring(why1)), not ok1 and why1 == "boss_stage_uncleared")
		local ok2, why2 = RaidRules.check({ currentStage = 33, bestBossCleared = 35, bossId = boss, remote = true, gateUsable = false })
		r.check(("원격 + 관문 미등록 → 불가(%s)"):format(tostring(why2)), not ok2 and why2 == "gate_unregistered")
		local ok3, why3 = RaidRules.check({ currentStage = 3, bestBossCleared = 0, bossId = boss, remote = false, gateUsable = true })
		r.check(("깬 보스 없음 → 불가(%s)"):format(tostring(why3)), not ok3 and why3 == "no_clear")
		local later = BossRules.bossIdForStage(BossData.stageInterval * 6)
		local ok4, why4 = RaidRules.check({ currentStage = 12, bestBossCleared = 10, bossId = later, remote = false, gateUsable = true })
		r.check(("아직 못 만난 보스(첫 스테이지 %s) → 불가(%s)"):format(tostring(RaidRules.firstStageOf(later)), tostring(why4)), not ok4 and why4 == "boss_not_met")
		r.check("파티 보스 레벨 = 멤버 토벌 스테이지 중 최고(30 · 300 · 3,000 → 3,000)", RaidRules.partyBossStage({ 30, 300, 3000 }) == 3000)
	end)

	r.section("악용 시뮬레이터", function()
		local rows = C1Sim.runAll()
		local worst = "O"
		for _, row in ipairs(rows) do
			local isFun = row.id:match("^e") ~= nil
			r.note(("SIM|%s|%s|정상 %s|전 %s(%s) %s|후 %s(%s) %s|%s"):format(row.id, row.label, fmt(row.normal),
				fmt(row.beforeRate), row.gainBefore and ("%+.1f%%"):format(row.gainBefore * 100) or "-", row.verdictBefore,
				fmt(row.afterRate), ("%+.1f%%"):format(row.gainAfter * 100), row.verdictAfter, row.note or ""))
			if not isFun and row.verdictAfter ~= "O" then
				worst = row.verdictAfter
			end
		end
		r.check(("악용 a ~ d · f ~ h 후 = 전부 O(+5%% 이하) · 최악 %s"):format(worst), worst == "O")
		local e0 = true
		for _, row in ipairs(rows) do
			if row.id:match("^e%d%-0$") and math.abs(row.gainAfter) > 0.05 then
				e0 = false
			end
		end
		r.check("섞인 파티(각자 몹만 · 스침 0) = 솔로 대비 ±5% 안(각자 처치 속도 유지)", e0)
	end)

	r.section("고스테이지 표본", function()
		local rows = C1Sim.samples(C1Sim.SAMPLE_STAGES, MonsterData, MonsterPrefixData, ArmorData)
		local allOk = true
		for _, row in ipairs(rows) do
			r.note(("SAMPLE|%d|log10최대HP %.1f|4%%틱 %.6f(오차 %.1e)|%d→%d 50%% → 비율 %.6f · 낮은 기여 %.3e|%d→%d 50%% → 비율 %.4f · 기여 %.4f|잡몹 itemLevel %d ~ %d|토벌 %s · 보스 itemLevel ≤ %d|%s"):format(
				row.stage, row.log10MaxHp, row.tick, row.tickErr, row.riseFrom, row.stage, row.riseRatio, row.riseContrib or 0,
				row.nearFrom, row.stage, row.nearRatio, row.nearContrib or 0, row.itemMin, row.itemMax, tostring(row.raid), row.bossItemMax, row.ok and "O" or "X"))
			allOk = allOk and row.ok
		end
		r.check(("표본 %d개 전부 유한 · 0 ≤ 비율 ≤ 1 · 정수 < 2^53 · 기준 = 그 스테이지"):format(#rows), allOk)
		r.check(("최고 스테이지 %d 최대 HP < 1e308(%.1f)"):format(InfiniteStageConfig.safeStageCap, rows[#rows].log10MaxHp), rows[#rows].log10MaxHp < 308)
	end)

	local pass, total = r.summary()
	print(("===C1 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===C1 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local MonsterState = require(script.Parent.MonsterState)
	local MonsterSpawner = require(script.Parent.MonsterSpawner)
	local CombatResolution = require(script.Parent.CombatResolution)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local PartyState = require(script.Parent.PartyState)
	local BossGate = require(script.Parent.BossGate)
	local data = MonsterData.tier1
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	assert(root, "캐릭터 없음")
	local far = root.Position + Vector3.new(0, 0, 400)
	local spawned = {}
	local function spawnMob(offset)
		local model = MonsterSpawner.spawn(data, far + (offset or Vector3.zero), nil, {})
		table.insert(spawned, model)
		return model
	end
	local function hp(stage)
		return InfiniteStage.getMonsterHp(data.hp, stage)
	end
	local k = InfiniteStageConfig.growthRate

	r.section("기준 상승 · 자격(실제 applyDamage)", function()
		env.applyStage(player, 30)
		task.wait()
		local low = { Name = "C1Low", Parent = true }
		local model = spawnMob()
		MonsterState.applyDamage(model, hp(1) * 0.5, 1, low)
		local ref1 = MonsterState.getRefStage(model)
		r.check(("낮은 스탠드인(스테이지 1) 50%% → 기준 %s · 비율 %.3f"):format(tostring(ref1), MonsterState.getHpRatio(model)), ref1 == 1 and near(MonsterState.getHpRatio(model), 0.5, 1e-6))
		MonsterState.applyDamage(model, 0, 30, player)
		local expect = 1 - 0.5 * k ^ -29
		local ref2, count = MonsterState.getRefStage(model)
		r.check(("실제 Player(30) 참여 → 기준 %s · 참여 %d · 비율 %.4f(기대 %.4f) - 낮은 곳 깎은 몫이 30으로 안 샘"):format(tostring(ref2), count, MonsterState.getHpRatio(model), expect),
			ref2 == 30 and count == 2 and near(MonsterState.getHpRatio(model), expect, 1e-6))
		MonsterState.applyDamage(model, hp(30) * 0.2, 30, player)
		r.check(("Player 20%% → 자격 %s · 스탠드인(기여 %.3f) 자격 %s"):format(tostring(MonsterState.isRewardEligible(model, player, 30)),
			MonsterState.getContributors(model)[low] or 0, tostring(MonsterState.isRewardEligible(model, low, 1))),
			MonsterState.isRewardEligible(model, player, 30) == true and MonsterState.isRewardEligible(model, low, 1) == true)
		-- 스테이지를 바꾸면(실제 Attribute 경로 - StageServer 감시) 내 기록만 지운다 · 다른 참여자 있으니 초기화 안 함 · 기준 1로 내려감(비율 유지)
		PartyState.noteActivity(player)
		local ratioBefore = MonsterState.getHpRatio(model)
		env.applyStage(player, 31)
		task.wait()
		local ref3 = MonsterState.getRefStage(model)
		r.check(("스테이지 30 → 31: 내 기여 %s · 기준 %s · 비율 %.4f = %.4f · 파티 활동 %s"):format(tostring(MonsterState.getContributors(model)[player]), tostring(ref3),
			MonsterState.getHpRatio(model), ratioBefore, tostring(PartyState.getLastActivity(player))),
			MonsterState.getContributors(model)[player] == nil and ref3 == 1 and near(MonsterState.getHpRatio(model), ratioBefore, 1e-9) and PartyState.getLastActivity(player) == nil)
	end)

	r.section("나만 참여한 몹 = 초기화 · HP바", function()
		local model = spawnMob(Vector3.new(30, 0, 0))
		MonsterState.applyDamage(model, hp(31) * 0.6, 31, player)
		MonsterSpawner.updateHpLabel(model)
		env.applyStage(player, 32)
		task.wait()
		local fill = model:FindFirstChild("HpBarFill", true)
		r.check(("혼자 60%% 깎은 몹 → 스테이지 변경 즉시 비율 %.2f · 기준 %s · HP바 %.2f"):format(MonsterState.getHpRatio(model), tostring(MonsterState.getRefStage(model)), fill and fill.Size.X.Scale or -1),
			MonsterState.getHpRatio(model) == 1 and MonsterState.getRefStage(model) == nil and fill ~= nil and fill.Size.X.Scale == 1)
	end)

	r.section("만료 → 기준 내리기 · 높은 사람 자격 잃음 · 실제 처치 보상", function()
		local model = spawnMob(Vector3.new(-30, 0, 0))
		local high = { Name = "C1High", Parent = true }
		MonsterState.applyDamage(model, hp(40) * 0.3, 40, high) -- 스탠드인 40이 30%
		MonsterState.applyDamage(model, hp(40) * 0.1, 32, player) -- 기준 40에서 Player 10%
		r.check(("스탠드인 40 참여 중 기준 %s"):format(tostring(MonsterState.getRefStage(model))), MonsterState.getRefStage(model) == 40)
		task.wait(CombatConfig.participationWindowSeconds + 0.5)
		MonsterState.applyDamage(model, 0, 32, player)
		local ok, why = MonsterState.isRewardEligible(model, high, 40)
		r.check(("%d초 무참여 → 기준 %s · 스탠드인 40 자격 %s(%s)"):format(CombatConfig.participationWindowSeconds, tostring(MonsterState.getRefStage(model)), tostring(ok), tostring(why)),
			MonsterState.getRefStage(model) == 32 and not ok and why == "above_ref")
		local goldBefore = PlayerProfile.getGold(player)
		local isDead = MonsterState.applyDamage(model, hp(32) * 2, 32, player)
		local okCall, err = pcall(CombatResolution.resolveHit, player, model, isDead)
		local goldAfter = PlayerProfile.getGold(player)
		r.check(("실제 처치(resolveHit): Player 골드 %d → %d · 자격 없는 스탠드인에 지급 시도 없음(에러 %s)"):format(goldBefore, goldAfter, okCall and "없음" or tostring(err)),
			isDead and okCall and goldAfter > goldBefore)
	end)

	r.section("치유 참여 · 어그로 참여", function()
		local model = spawnMob(Vector3.new(0, 0, 30))
		MonsterState.applyDamage(model, hp(32) * 0.1, 32, player)
		local healer = { Name = "C1Healer", Parent = true }
		local mobPos = model.PrimaryPart.Position
		MonsterState.noteSupport(healer, 500, player, mobPos + Vector3.new(CombatConfig.supportRadiusStuds + 20, 0, 0))
		local farRef = MonsterState.getRefStage(model)
		MonsterState.noteSupport(healer, 500, player, mobPos + Vector3.new(10, 0, 0))
		local nearRef = MonsterState.getRefStage(model)
		MonsterState.clearPlayerContributions(healer)
		r.check(("치유사(500)가 참여 중인 Player를 도움: 몹에서 %d 밖 → 기준 %s(그대로 32) · 10 안 → 기준 %s"):format(CombatConfig.supportRadiusStuds, tostring(farRef), tostring(nearRef)),
			farRef == 32 and nearRef == 500)
		-- 어그로: 몹을 Player 곁에 두고 MonsterAI가 쫓게 한다
		local chaser = MonsterSpawner.spawn(data, root.Position + Vector3.new(8, 0, 0), nil, {})
		table.insert(spawned, chaser)
		local t0 = os.clock()
		local ref, count
		repeat
			task.wait(0.2)
			ref, count = MonsterState.getRefStage(chaser)
		until ref ~= nil or os.clock() - t0 > 3
		r.check(("곁의 몹이 쫓기 시작(MonsterAI) → 때리지 않아도 참여 · 기준 %s · 참여 %d"):format(tostring(ref), count or 0), ref == 32 and count == 1)
		if MonsterState.getData(chaser) then
			MonsterSpawner.despawn(chaser) -- 개발 캐릭터를 계속 때리지 않게 바로 치운다
		end
	end)

	r.section("토벌 입장 검사(BossGate.raidCheck - 실제 프로필)", function()
		local boss = BossRules.bossIdForStage(BossData.stageInterval)
		local ok, why, stage = BossGate.raidCheck(player, boss, true)
		local expectOk, expectWhy, expectStage = RaidRules.check({ currentStage = PlayerProfile.getInfiniteStage(player), bestBossCleared = PlayerProfile.getBestBossCleared(player),
			bossId = boss, remote = true, gateUsable = BossGate.usableFor(player, boss) })
		r.check(("raidCheck(%s, 원격) = %s · %s · %s(순수 규칙과 같음)"):format(boss, tostring(ok), tostring(why), tostring(stage)), ok == expectOk and why == expectWhy and stage == expectStage)
	end)

	for _, model in ipairs(spawned) do
		if model.Parent and MonsterState.getData(model) then
			MonsterSpawner.despawn(model)
		end
	end
	env.restore(player)
	local pass, total = r.summary()
	print(("===C1 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
