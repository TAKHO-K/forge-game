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
local AlphaStats = require(script.Parent.AlphaStats)

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

	r.section("기준 스테이지 · 스테이지 차 규칙", function()
		local GAP = CombatConfig.stealStageGap
		local low, high, mid = {}, {}, {}
		local mob = MobShare.fresh({})
		local ref = MobShare.touch(mob, low, 10, 0)
		MobShare.applyRatio(mob, low, 0.6, 0)
		r.check(("첫 참여 = 기준 %s · 비율 %.2f"):format(tostring(ref), mob.hpRatio), ref == 10 and near(mob.hpRatio, 0.4))
		local ref1, _, _, blocked = MobShare.touch(mob, high, 30, 1)
		r.check(("참여자 최저 10 · 공격자 30(차 20 > %d) → 막힘 · 기준 %s · 비율 %.2f 그대로"):format(GAP, tostring(ref1), mob.hpRatio), blocked and ref1 == 10 and near(mob.hpRatio, 0.4) and mob.participants[high] == nil)
		local t = W + 1
		local ref2, _, rose = MobShare.touch(mob, high, 30, t)
		local expect = 1 - 0.6 * k ^ (10 - 30)
		r.check(("낮은 참여자 %d초 무참여 → 풀림 · 재정규화 10 → 30: 비율 %.6f(기대 %.6f) · 낮은 기여 0.6 → %.6f · 첫 타격 다시(%s) · 타격 수 다시(%s)"):format(W, mob.hpRatio, expect, mob.contributions[low], tostring(mob.firstHitAt[low]), tostring(mob.hitCounts[low])),
			rose and ref2 == 30 and near(mob.hpRatio, expect) and near(mob.contributions[low], 0.6 * k ^ -20) and mob.firstHitAt[low] == t and mob.hitCounts[low] == nil)
		MobShare.applyRatio(mob, high, 0.1, t)
		local _, _, _, midBlocked = MobShare.touch(mob, mid, 20, t + 1)
		MobShare.applyRatio(mob, mid, 0.05, t + 1)
		r.check("높은 사람 몹에 낮은 사람(20)은 참여 가능(피해 = 기준 30 HP로 환산) · 기준 그대로 30", not midBlocked and mob.refStage == 30)
		local _, _, _, highBlocked = MobShare.touch(mob, high, 30, t + 2)
		r.check("먼저 참여한 높은 사람은 낮은 사람이 뒤에 끼어도 안 막힘(먼저 온 사람 우선 - 낮은 사람의 방해 차단)", not highBlocked)
		local before = mob.hpRatio
		ref = MobShare.touch(mob, low, 10, t + 2 + W + 0.5)
		r.check(("참여자 전부 %d초 지나 낮은 사람만 → 기준 %s · 비율 유지 %.6f = %.6f"):format(W, tostring(ref), mob.hpRatio, before), ref == 10 and near(mob.hpRatio, before))
		r.check("기준이 10으로 내려감 → 스테이지 30 사람 자격 없음(above_ref)", select(2, MobShare.eligible(mob, high, 30)) ~= nil)
		-- 스틸 동작: 차 5 · 10 · 11
		for _, gap in ipairs({ 5, 10, 11 }) do
			local owner, thief = {}, {}
			local m = MobShare.fresh({})
			MobShare.touch(m, owner, 100, 0)
			MobShare.applyRatio(m, owner, 0.5, 0)
			local r2, _, rose2, b = MobShare.touch(m, thief, 100 + gap, 1)
			if gap <= GAP then
				local e2 = 1 - 0.5 * k ^ -gap
				r.check(("스틸 차 %d: 참여 · 기준 %s · 재정규화 비율 %.4f(기대 %.4f) · 주인 기여 0.5 → %.4f"):format(gap, tostring(r2), m.hpRatio, e2, m.contributions[owner]),
					not b and rose2 and r2 == 100 + gap and near(m.hpRatio, e2) and near(m.contributions[owner], 0.5 * k ^ -gap))
			else
				r.check(("스틸 차 %d: 막힘 · 기준 %s 그대로 · 비율 %.2f 그대로"):format(gap, tostring(r2), m.hpRatio), b and r2 == 100 and near(m.hpRatio, 0.5))
			end
		end
		-- 쫓기기만 한 참여자(passive)는 잡는 사람이 아니다 → 막지 않는다 · 대신 기준이 오르면 몹이 안 쫓는다(canChase 조건)
		local chased, dealer = {}, {}
		local m2 = MobShare.fresh({})
		MobShare.touch(m2, chased, 1, 0, true)
		local ref3, _, _, b2 = MobShare.touch(m2, dealer, 3000, 0.5)
		local weak = MobShare.tooWeakFor(m2, chased, 1)
		r.check(("쫓기기만 한 스테이지 1(passive) → 스테이지 3,000 딜러 안 막힘 · 기준 %s · 스테이지 1은 3,000과 스틸 불가라 몹이 안 쫓음(tooWeakFor %s)"):format(tostring(ref3), tostring(weak)),
			not b2 and ref3 == 3000 and weak)
		-- C1 마무리: 스틸 불가한 낮은 사람은 막히지 않고 같이 때린다(follower) - 주인(잡는 사람 집합)은 그대로라 그 파티원(305)은 계속 낄 수 있다(대칭 판정의 목적 유지)
		local hi, lo1, friend = {}, {}, {}
		local m3 = MobShare.fresh({})
		MobShare.touch(m3, hi, 300, 0)
		MobShare.applyRatio(m3, hi, 0.1, 0)
		local _, _, _, bl1 = MobShare.touch(m3, lo1, 1, 1)
		local _, _, _, bl2 = MobShare.touch(m3, friend, 305, 1.5)
		r.check(("잡는 사람 300 몹에 스테이지 1 → 막힘 %s · 참여 %s · 잡는 사람 %s(기대 아님) · 뒤에 온 305(300과 차 5) → 막힘 %s · 기준 %s"):format(tostring(bl1),
			tostring(m3.participants[lo1] ~= nil), tostring(m3.activeAt[lo1] ~= nil), tostring(bl2), tostring(m3.refStage)),
			not bl1 and m3.participants[lo1] ~= nil and m3.activeAt[lo1] == nil and not bl2 and m3.refStage == 305)
		MobShare.touch(m3, lo1, 1, 1.5 + W + 1)
		r.check("주인들이 8초 떠난 뒤 낮은 사람이 다시 치면 → 잡는 사람(새 주인)", m3.activeAt[lo1] ~= nil)
		-- 리뷰 1: 쫓기기만 하는 높은 H(3,000)가 있는 몹을 낮은 L(1)이 먼저 쳐도 주인이 안 된다 → H가 친 뒤 H의 파티원 M(3,000)이 막히지 않는다
		local H, L, M = {}, {}, {}
		local m4 = MobShare.fresh({})
		MobShare.touch(m4, H, 3000, 0, true)
		MobShare.touch(m4, L, 1, 0.5)
		MobShare.touch(m4, H, 3000, 1)
		local _, _, _, mBlocked = MobShare.touch(m4, M, 3000, 1.5)
		r.check(("쫓김 중인 3,000 몹을 1이 먼저 침 → 1 주인 %s(기대 아님) · 3,000 주인 %s · 파티원 3,000 막힘 %s(기대 아님)"):format(tostring(m4.activeAt[L] ~= nil), tostring(m4.activeAt[H] ~= nil), tostring(mBlocked)),
			m4.activeAt[L] == nil and m4.activeAt[H] ~= nil and not mBlocked)
	end)

	r.section("스틸 가능 판정 canShare(환생 · 레벨 구간 · 스테이지 차)", function()
		local function P(stage, level, rebirth)
			return { stage = stage, level = level, rebirth = rebirth or 0 }
		end
		-- 레벨 구간 경계: 낮은 레벨 기준 gap - (낮은 레벨, 허용 최대 차)
		local rows = { { 1, 20 }, { 99, 20 }, { 100, 50 }, { 499, 50 }, { 500, 100 }, { 999, 100 }, { 1000, 250 }, { 4999, 250 }, { 5000, 500 }, { 9000, 500 } }
		for _, row in ipairs(rows) do
			local low, gap = row[1], row[2]
			local inside = MobShare.canShare(P(100, low), P(100, low + gap))
			local outside = MobShare.canShare(P(100, low), P(100, low + gap + 1))
			local swapped = MobShare.canShare(P(100, low + gap), P(100, low)) -- 대칭
			r.check(("TABLE|레벨|낮은 %d|허용 %d|차 %d → %s|차 %d → %s|순서 바꿈 %s"):format(low, MobShare.levelGapFor(low), gap, inside and "가능" or "불가", gap + 1, outside and "가능" or "불가", swapped and "가능" or "불가"),
				MobShare.levelGapFor(low) == gap and inside and not outside and swapped)
		end
		r.check("TABLE|레벨|99 vs 120(차 21 - 낮은 99 구간 20) → 불가 · 100 vs 150(차 50 - 낮은 100 구간 50) → 가능", not MobShare.canShare(P(1, 99), P(1, 120)) and MobShare.canShare(P(1, 100), P(1, 150)))
		r.check("TABLE|스테이지|차 10 → 가능 · 차 11 → 불가(레벨 · 환생 같음)", MobShare.canShare(P(100, 50), P(110, 50)) and not MobShare.canShare(P(100, 50), P(111, 50)))
		r.check("TABLE|환생|0 vs 1(레벨 · 스테이지 같음) → 불가 · 3 vs 3 → 가능", not MobShare.canShare(P(100, 50, 0), P(100, 50, 1)) and MobShare.canShare(P(100, 50, 3), P(100, 50, 3)))
		-- l · m 판정(시뮬과 같은 사람)
		local lOwner, lThief = { level = 300, rebirth = 2 }, { level = 300, rebirth = 2 }
		local ml = MobShare.fresh({})
		MobShare.touch(ml, lOwner, 1, 0)
		local _, _, _, lBlocked = MobShare.touch(ml, lThief, 3000, 1)
		r.check("l: 환생 · 레벨 같고 스테이지 1(주인) vs 3,000 → 막힘", lBlocked)
		local mOwner, mThief, mLow = { level = 150, rebirth = 0 }, { level = 150, rebirth = 1 }, { level = 150, rebirth = 1 }
		local mm = MobShare.fresh({})
		MobShare.touch(mm, mOwner, 100, 0)
		local _, _, _, mBlocked = MobShare.touch(mm, mThief, 105, 1)
		local _, _, _, mLowBlocked = MobShare.touch(mm, mLow, 95, 1)
		r.check(("m: 환생 0(주인 100) vs 1 · 레벨 같음 → 105 막힘 %s · 95(낮은 쪽) → 같이 때림(막힘 %s · 주인 그대로 %s)"):format(tostring(mBlocked), tostring(mLowBlocked), tostring(mm.activeAt[mLow] == nil)),
			mBlocked and not mLowBlocked and mm.activeAt[mLow] == nil and mm.refStage == 100)
		-- 클라 자물쇠: 서버 목록 문자열 → lockedFor(서버 isBlocked와 같은 판정)
		local enc = MobShare.encodeHunters(mm, 1, function(at)
			return 1000 + at
		end)
		local me = { userId = 77, stage = 105, level = 150, rebirth = 1 }
		local friendMe = { userId = 78, stage = 104, level = 150, rebirth = 0 }
		r.check(("자물쇠 목록 \"%s\" → 환생 다른 105 = 잠김 %s · 같은 환생 104 = 잠김 %s · 만료 뒤(서버 시각 +%d) = 잠김 %s"):format(enc,
			tostring(MobShare.lockedFor(enc, me, 1001)), tostring(MobShare.lockedFor(enc, friendMe, 1001)), W + 1, tostring(MobShare.lockedFor(enc, me, 1001 + W + 1))),
			MobShare.lockedFor(enc, me, 1001) and not MobShare.lockedFor(enc, friendMe, 1001) and not MobShare.lockedFor(enc, me, 1001 + W + 1))
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
		r.check("참여 중인 사람(10)을 치유사(18 - 차 8)가 도움 → 치유사도 참여(기준 = 18)", MobShare.support(mob, healer, 18, fighter, 1) and mob.refStage == 18)
		local hitMob, hitter, bigHealer = MobShare.fresh({}), {}, {}
		MobShare.touch(hitMob, hitter, 10, 0)
		r.check("참여 중인 사람(10)을 치유사(60 - 차 50)가 도움 → 막힘(기준 그대로 10)", not MobShare.support(hitMob, bigHealer, 60, hitter, 1) and hitMob.refStage == 10)
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
			local isFun = row.id:match("^e") ~= nil or (row.id:match("^j%-") ~= nil and row.id ~= "j-0") -- 끌기 변형 = 잔여(결정 대기 - 보고서 ⑧)
			r.note(("SIM|%s|%s|정상 %s|전 %s(%s) %s|후 %s(%s) %s|%s"):format(row.id, row.label, fmt(row.normal),
				fmt(row.beforeRate), row.gainBefore and ("%+.1f%%"):format(row.gainBefore * 100) or "-", row.verdictBefore,
				fmt(row.afterRate), ("%+.1f%%"):format(row.gainAfter * 100), row.verdictAfter, row.note or ""))
			if not isFun and row.verdictAfter ~= "O" then
				worst = row.verdictAfter
			end
		end
		r.check(("악용 a ~ d · f ~ k(j = 끌기 0초) 후 = 전부 O(+5%% 이하) · 최악 %s - j 끌기 1 · 2초는 잔여로 따로 보고"):format(worst), worst == "O")
		local e0 = true
		for _, row in ipairs(rows) do
			if row.id:match("^e%d%-0%-") and math.abs(row.gainAfter) > 0.05 then
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
		local _, dealtBlocked = MonsterState.applyDamage(model, hp(30) * 0.2, 30, player)
		r.check(("스탠드인(1) 참여 중 실제 Player(30 - 차 29) → 막힘: 들어간 피해 %s · 기준 %s · 비율 %.3f · 기여 %s"):format(tostring(dealtBlocked), tostring(MonsterState.getRefStage(model)),
			MonsterState.getHpRatio(model), tostring(MonsterState.getContributors(model)[player])),
			dealtBlocked == 0 and MonsterState.getRefStage(model) == 1 and near(MonsterState.getHpRatio(model), 0.5, 1e-6) and MonsterState.getContributors(model)[player] == nil)
		task.wait(CombatConfig.participationWindowSeconds + 0.5)
		MonsterState.applyDamage(model, 0, 30, player)
		local expect = 1 - 0.5 * k ^ -29
		local ref2, count = MonsterState.getRefStage(model)
		r.check(("%d초 뒤(스탠드인 무참여) 실제 Player(30) 참여 → 기준 %s · 참여 %d · 비율 %.4f(기대 %.4f) - 낮은 곳 깎은 몫이 30으로 안 샘"):format(CombatConfig.participationWindowSeconds, tostring(ref2), count, MonsterState.getHpRatio(model), expect),
			ref2 == 30 and count == 1 and near(MonsterState.getHpRatio(model), expect, 1e-6))
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
		r.check(("스테이지 30 → 31: 내 기여 %s · 기준 %s(참여자 없음 = 유지) · 비율 %.4f = %.4f(스탠드인 기여가 남아 초기화 안 함) · 파티 활동 %s"):format(tostring(MonsterState.getContributors(model)[player]), tostring(ref3),
			MonsterState.getHpRatio(model), ratioBefore, tostring(PartyState.getLastActivity(player))),
			MonsterState.getContributors(model)[player] == nil and ref3 == 30 and near(MonsterState.getHpRatio(model), ratioBefore, 1e-9) and PartyState.getLastActivity(player) == nil)
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
		local mirror = { level = player:GetAttribute("CharacterLevel") or 1, rebirth = player:GetAttribute("RebirthCount") or 0 } -- C1 마무리: 스탠드인 레벨 · 환생 = 개발 계정(스테이지 차만 보게)
		local healer = { Name = "C1Healer", Parent = true, level = mirror.level, rebirth = mirror.rebirth }
		local mobPos = model.PrimaryPart.Position
		MonsterState.noteSupport(healer, 40, player, mobPos + Vector3.new(CombatConfig.supportRadiusStuds + 20, 0, 0))
		local farRef = MonsterState.getRefStage(model)
		local bigHealer = { Name = "C1BigHealer", Parent = true, level = mirror.level, rebirth = mirror.rebirth }
		MonsterState.noteSupport(bigHealer, 500, player, mobPos + Vector3.new(10, 0, 0))
		local bigRef = MonsterState.getRefStage(model)
		MonsterState.noteSupport(healer, 40, player, mobPos + Vector3.new(10, 0, 0))
		local nearRef = MonsterState.getRefStage(model)
		local attackStage = MonsterState.getAttackStage(model, 32)
		MonsterState.clearPlayerContributions(healer)
		MonsterState.clearPlayerContributions(bigHealer)
		r.check(("참여 중인 Player(32)를 도움: 치유사 40이 %d 밖 → 기준 %s(그대로) · 치유사 500이 10 안(차 468) → 막힘 %s · 치유사 40이 10 안(차 8) → 기준 %s · 몹이 주는 피해 스테이지 %s"):format(
			CombatConfig.supportRadiusStuds, tostring(farRef), tostring(bigRef), tostring(nearRef), tostring(attackStage)),
			farRef == 32 and bigRef == 32 and nearRef == 40 and attackStage == 40)
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
		-- 리뷰 1: 높은 사람이 이 몹을 치면(쫓기기만 한 Player는 잡는 사람이 아니라 안 막힘) 기준 500 → 몹이 Player(32)를 놓는다(기준 공격력 즉사 방지)
		local tagger = { Name = "C1Tagger", Parent = true }
		local pullsBefore = AlphaStats.snapshot().pullCount
		local _, taggedDealt = MonsterState.applyDamage(chaser, hp(500) * 0.01, 500, tagger)
		local pullSnap = AlphaStats.snapshot()
		r.check(("결정 6 계측: 쫓기기만 하던 몹을 500이 침(기준 32 → 500) → 끌어오기 %d → %d회 · 최대 상승 %d"):format(pullsBefore, pullSnap.pullCount, pullSnap.pullMaxJump),
			pullSnap.pullCount == pullsBefore + 1 and pullSnap.pullMaxJump >= 468)
		task.wait(0.5)
		local stillChasing = MonsterState.getAiTarget(chaser) == player
		r.check(("쫓기던 몹을 높은 스탠드인(500)이 침 → 들어간 피해 %s · 기준 %s · 0.5초 뒤 Player를 계속 쫓음 %s(기대 false)"):format(
			tostring(taggedDealt and taggedDealt > 0), tostring(MonsterState.getRefStage(chaser)), tostring(stillChasing)),
			taggedDealt > 0 and MonsterState.getRefStage(chaser) == 500 and not stillChasing)
		MonsterState.clearPlayerContributions(tagger)
		if MonsterState.getData(chaser) then
			MonsterSpawner.despawn(chaser) -- 개발 캐릭터를 계속 때리지 않게 바로 치운다
		end
	end)

	r.section("스틸 차 5 · 10 · 11(실제 applyDamage · 스탠드인)", function()
		for i, gap in ipairs({ 5, 10, 11 }) do
			local model = spawnMob(Vector3.new(60 + i * 20, 0, 0))
			local owner = { Name = "C1Owner", Parent = true }
			local thief = { Name = "C1Thief", Parent = true }
			MonsterState.applyDamage(model, hp(100) * 0.5, 100, owner)
			local encodedOwner = model:GetAttribute("MobHunters")
			local _, dealt = MonsterState.applyDamage(model, hp(100 + gap) * 0.1, 100 + gap, thief)
			local ref = MonsterState.getRefStage(model)
			if i == 1 then
				local lockMe = { userId = 1, stage = 120, level = 1, rebirth = 0 }
				r.check(("자물쇠 Attribute MobHunters = \"%s\" → 스테이지 120 화면 잠김 %s · 스테이지 105 화면 잠김 %s"):format(tostring(encodedOwner),
					tostring(MobShare.lockedFor(encodedOwner, lockMe, workspace:GetServerTimeNow())), tostring(MobShare.lockedFor(encodedOwner, { userId = 1, stage = 105, level = 1, rebirth = 0 }, workspace:GetServerTimeNow()))),
					encodedOwner ~= nil and MobShare.lockedFor(encodedOwner, lockMe, workspace:GetServerTimeNow()) and not MobShare.lockedFor(encodedOwner, { userId = 1, stage = 105, level = 1, rebirth = 0 }, workspace:GetServerTimeNow()))
			end
			local ratio = MonsterState.getHpRatio(model)
			if gap <= CombatConfig.stealStageGap then
				local e = 1 - 0.5 * k ^ -gap - 0.1
				r.check(("차 %d: 스틸 참여 · 기준 %s · 비율 %.4f(기대 %.4f) · 몹이 주는 피해 스테이지 %s"):format(gap, tostring(ref), ratio, e, tostring(MonsterState.getAttackStage(model, 1))),
					dealt > 0 and ref == 100 + gap and near(ratio, e, 1e-6) and MonsterState.getAttackStage(model, 1) == 100 + gap)
			else
				r.check(("차 %d: 막힘 · 들어간 피해 %s · 기준 %s · 비율 %.2f 그대로"):format(gap, tostring(dealt), tostring(ref), ratio), dealt == 0 and ref == 100 and near(ratio, 0.5, 1e-6))
			end
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
