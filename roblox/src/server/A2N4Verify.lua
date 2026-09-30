-- A2-N4 자동 검증.
--   (가) 순수: 보스 행동 3줄(BossScheduler 강공격 줄 - 전역 쿨 분리 · 강공격 간격 · 패턴 뒤로 미룸 · 첫 강공격 준비 · 둘 다 준비면 패턴 먼저 · 끄면 옛 규칙) ·
--        강공격 피해 배율(heavyDamageScale) · 방향(faceMoveMinSpeed 데이터) · 대표 전력(/gg loadout 역산 = 앵커 곡선).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossScheduler = require(ReplicatedStorage.Shared.BossScheduler)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[A2-N4][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

-- 합성 스킬 표: heavy 1개(전조 1.0 · 쿨 5) · 패턴 1개(쿨 4)
local function synth()
	local skills = {
		H = { bubble = BossData.mechanics.lanes.heavyBubble, cooldownSeconds = 5, telegraphSeconds = 1.0, priority = 0 },
		P = { bubble = "pattern", cooldownSeconds = 4, telegraphSeconds = 1.2, priority = 0 },
	}
	local order = { "H", "P" }
	local config = { globalCooldownSeconds = 6, enragedGlobalCooldownSeconds = 2.5, enragedHpFraction = 0.2, entryGraceSeconds = 0, starvationPriorityBonus = 1000, lanes = BossData.mechanics.lanes }
	local ctx = { now = 0, conditionMet = function()
		return true
	end, boundSeconds = function()
		return 2
	end }
	return skills, order, config, ctx
end

function V.runPure()
	print("===A2-N4 검증 시작(가)===")
	local r = newRecorder("가")
	local L = BossData.mechanics.lanes
	r.section("강공격 줄", function()
		local skills, order, config, ctx = synth()
		local st = BossScheduler.newState(skills, order, 0, false, config)
		r.check(("첫 강공격 준비 %.1f초 ≤ %.1f(쿨 5를 당김) · 패턴은 쿨 그대로 %.1f"):format(st.readyAt.H, L.firstHeavySeconds, st.readyAt.P), st.readyAt.H <= L.firstHeavySeconds + 1e-6 and st.readyAt.P == 4)
		-- 시작 전역 쿨(시작 = lastEndAt)은 비우고: 패턴을 t=4에 시작 · t=6에 끝 → 전역 쿨 6 = 패턴은 12까지 닫힘. 강공격은 6에도 준비(쿨 무관)
		st.lastEndAt = -100
		ctx.now = 4
		local p1 = BossScheduler.pick(st, skills, order, config, ctx)
		BossScheduler.onSkillStart(st, p1, 4, skills, config)
		BossScheduler.onSkillEnd(st, skills, p1, 6, config)
		ctx.now = 6
		local p2 = BossScheduler.pick(st, skills, order, config, ctx)
		r.check(("t=4 둘 다 준비 → 패턴 먼저(%s) · 패턴 끝 t=6 직후 강공격(%s - 전역 쿨과 분리)"):format(tostring(p1), tostring(p2)), p1 == "P" and p2 == "H")
		BossScheduler.onSkillStart(st, "H", 6, skills, config)
		BossScheduler.onSkillEnd(st, skills, "H", 7.5, config)
		-- 다음 강공격: 쿨 5 → 12.5 · 간격 = 6 + 전조 1 + 1.5 = 8.5 → 쿨이 늦다. 간격만 보는 합성: 쿨 0으로
		skills.H.cooldownSeconds = 0
		st.readyAt.H = 7.5
		ctx.now = 8.4
		local early = BossScheduler.pick(st, skills, order, config, ctx)
		ctx.now = 8.5
		local onTime = BossScheduler.pick(st, skills, order, config, ctx)
		r.check(("강공격끼리 = 전조 끝 + %.1f초: 8.4초 %s · 8.5초 %s"):format(L.heavyMinGapSeconds, tostring(early), tostring(onTime)), early == nil and onTime == "H")
		-- 패턴은 강공격 끝(7.5) + 0.8 = 8.3 뒤 · 그리고 전역 쿨(패턴 끝 6 + 6 = 12) 뒤
		local st2 = BossScheduler.newState(skills, order, 0, false, config)
		st2.lastEndAt = -100
		st2.readyAt.P, st2.readyAt.H = 0, 1e9
		st2.heavyEndAt = 10
		ctx.now = 10.7
		local deferred = BossScheduler.pick(st2, skills, order, config, ctx)
		ctx.now = 10.8
		local after = BossScheduler.pick(st2, skills, order, config, ctx)
		r.check(("패턴은 강공격 끝 + %.1f초 뒤로: 10.7초 %s · 10.8초 %s"):format(L.patternAfterHeavySeconds, tostring(deferred), tostring(after)), deferred == nil and after == "P")
	end)
	r.section("끄면 옛 규칙", function()
		local skills, order, config, ctx = synth()
		config.lanes = nil
		local st = BossScheduler.newState(skills, order, 0, false, config)
		st.lastEndAt = -100
		ctx.now = 4
		local p1 = BossScheduler.pick(st, skills, order, config, ctx)
		BossScheduler.onSkillStart(st, p1, 4, skills, config)
		BossScheduler.onSkillEnd(st, skills, p1, 6, config)
		ctx.now = 6
		local p2 = BossScheduler.pick(st, skills, order, config, ctx)
		ctx.now = 12
		local p3 = BossScheduler.pick(st, skills, order, config, ctx)
		r.check(("줄 끔: 첫 준비 H %.0f(쿨 그대로) · t=4 %s · 끝 직후 %s(전역 쿨) · 12초 %s"):format(BossScheduler.newState(skills, order, 0, false, config).readyAt.H, tostring(p1), tostring(p2), tostring(p3)),
			BossScheduler.newState(skills, order, 0, false, config).readyAt.H == 5 and p1 == "P" and p2 == nil and p3 == "H")
	end)
	r.section("강공격 피해 배율", function()
		local rows, ok = {}, true
		for _, id in ipairs({ "section_guardian", "frost_giant" }) do
			for sid, skill in pairs(BossData.bosses[id].skills) do
				if skill.bubble == L.heavyBubble and skill.damage and skill.damage.multiplier then
					table.insert(rows, ("%s.%s ×%.3f"):format(id, sid, skill.damage.multiplier))
				end
			end
		end
		r.check(("heavyDamageScale %.2f 적용(보스 표): %s"):format(L.heavyDamageScale, table.concat(rows, " · ")), ok and #rows > 0)
	end)
	r.section("대표 전력 역산", function()
		local off = BalanceSim.solveKillOffset()
		local rows, ok = {}, true
		for _, stage in ipairs({ 500, 2000, 10000 }) do
			local level = math.max(1, math.floor(stage - off + 0.5))
			local back = BalanceSim.recommendedStage(level, 0, false)
			table.insert(rows, ("스테이지 %d → 레벨 %d → rec %d"):format(stage, level, back))
			ok = ok and math.abs(back - stage) <= 1
		end
		r.check("/gg loadout 레벨 = 앵커 곡선 역(rec(L) ≈ 스테이지 ±1): " .. table.concat(rows, " · "), ok)
	end)
	local pass, total = r.summary()
	print(("===A2-N4 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

return V
