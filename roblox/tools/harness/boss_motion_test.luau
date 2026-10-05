-- A2-M1 보스 모션 하네스(오프라인 - 게임 안 client/MotionProbe와 같은 잣대): 보스 6종 × 스킬 동작 · 평타 · 피격 · 기절 · 사망 · 걷기를 60fps로 평가 →
--   FK(BossRig.solve)로 부위 월드 회전 · 자리 → 프레임 사이 각속도 벡터 · 선속도 → "튐"(한 프레임에 속도가 급변) 수를 센다.
--   의도된 타격 창(접촉 − 0.03 ~ 접촉 + 히트스톱 + 0.25)은 뺀다. 접촉 시각 − 판정 시각(hit)도 출력(0 = 보이는 타격 = 판정).
-- 실행: python build_run.py boss_motion_test.luau (PRELUDE=motion_prelude.luau) · 결과 = %TEMP%/harness_result.txt
local BossMotion = MODS.BossMotion
local BossRig = MODS.BossRig
local BossRigSpec = MODS.BossRigSpec
local BossData = MODS.BossData
local BossMotionData = MODS.BossMotionData
local contactTime = BossMotion.contactTime or function(clip, hit) return hit + ((clip.post and clip.post[1] and clip.post[1].s) or 0) end

local FPS = 60
local DT = 1 / FPS
local ANG_JUMP = tonumber(ANG_JUMP_OVERRIDE) or 450 -- 도/초: 프레임 사이 각속도 벡터 변화가 이보다 크면 튐(60fps에서 프레임당 7.5°)
local LIN_JUMP = 4.0 -- 단위/초(× sizeScale = stud/초): 부위 자리 속도 변화

local function relAxis(a, b)
	-- 월드 각속도 벡터(도): b · a⁻¹ 의 축 × 각
	local ra, rb = a.r, b.r
	-- R = rb · raᵀ
	local function el(i, j)
		return rb[(i - 1) * 3 + 1] * ra[(j - 1) * 3 + 1] + rb[(i - 1) * 3 + 2] * ra[(j - 1) * 3 + 2] + rb[(i - 1) * 3 + 3] * ra[(j - 1) * 3 + 3]
	end
	local tr = el(1, 1) + el(2, 2) + el(3, 3)
	local th = math.acos(math.clamp((tr - 1) / 2, -1, 1))
	if th < 1e-7 then
		return 0, 0, 0
	end
	local s = 2 * math.sin(th)
	local k = math.deg(th) / math.max(s, 1e-9)
	return (el(3, 2) - el(2, 3)) * k, (el(1, 3) - el(3, 1)) * k, (el(2, 1) - el(1, 2)) * k
end

-- 한 동작 재생: stFn(t) → st · 창 [0, T] · 제외 창 목록 → 튐 사건 수 · 최악 값 · 최악 부위
local DETAIL = nil
local function run(rigId, stFn, T, excl)
	local rig = BossRigSpec.rigs[rigId]
	local data = BossData.bosses[rigId]
	local ctx = BossMotion.context(rigId, rig, data.skills, data.moveSpeedStuds)
	local rest = BossMotion.prepare(rig)
	local prevF, prevW, prevV = nil, {}, {}
	local events, worst, worstPart, worstT = 0, 0, nil, 0
	local flagged = false
	local n = math.floor(T * FPS)
	for i = 0, n do
		local t = i * DT
		local st = stFn(t)
		local pose = BossMotion.evaluate(ctx, st, t)
		local frames = BossRig.solve(rig, CFrame.identity, 1, BossMotion.toTransforms(rest, 1, pose))
		local bad = false
		local excluded = false
		for _, w in ipairs(excl) do
			if t >= w[1] and t <= w[2] then
				excluded = true
			end
		end
		if prevF then
			for part, cf in pairs(frames) do
				local p = prevF[part]
				if p then
					local wx, wy, wz = relAxis(p, cf)
					wx, wy, wz = wx * FPS, wy * FPS, wz * FPS
					local vx, vy, vz = (cf.x - p.x) * FPS, (cf.y - p.y) * FPS, (cf.z - p.z) * FPS
					local pw, pv = prevW[part], prevV[part]
					if pw and not excluded then
						local dw = math.sqrt((wx - pw[1]) ^ 2 + (wy - pw[2]) ^ 2 + (wz - pw[3]) ^ 2)
						local dv = math.sqrt((vx - pv[1]) ^ 2 + (vy - pv[2]) ^ 2 + (vz - pv[3]) ^ 2)
						-- 선속도 튐은 몸 전체 이동(Hips = 루트 관절 자리)만 본다 - 다른 부위의 선속도는 회전에서 생겨 각속도로 이미 잰다
						local score = math.max(dw / ANG_JUMP, part == "Hips" and dv / LIN_JUMP or 0)
						if DETAIL and not excluded and score > 1 then
							print(("  DETAIL %s t=%.3f part=%s dw=%.0f dv=%.2f"):format(DETAIL, t, part, dw, dv))
						end
						if score > 1 then
							bad = true
						end
						if score > worst then
							worst, worstPart, worstT = score, part, t
						end
					end
					prevW[part], prevV[part] = { wx, wy, wz }, { vx, vy, vz }
				end
			end
		end
		if bad and not flagged then
			events += 1
		end
		flagged = bad
		prevF = frames
	end
	return events, worst, worstPart, worstT
end

local rows = {}
local totalEvents = 0
local ids = {}
for id, rig in pairs(BossRigSpec.rigs) do
	if not rig.variant then -- BOSS-FRAMEWORK: 새 몸(리그 v2)은 boss_framework_test가 돈다
		table.insert(ids, id)
	end
end
table.sort(ids)
local function add(rigId, action, ev, worst, part, t, contactOff)
	totalEvents += ev
	table.insert(rows, ("%s,%s,%d,%.2f,%s,%.2f,%s"):format(rigId, action, ev, worst, tostring(part), t, contactOff and ("%.3f"):format(contactOff) or ""))
end

for _, rigId in ipairs(ids) do
	local rig = BossRigSpec.rigs[rigId]
	local data = BossData.bosses[rigId]
	local plan = BossMotion.planOf(rigId, rig)
	local weight = rig.weight or 1
	-- 대기(4초)
	local ev, w, p, t = run(rigId, function() return { inCombat = true, speed = 0, gait = 0 } end, 4, {})
	add(rigId, "idle", ev, w, p, t)
	-- 걷기(가속 → 일정 → 감속)
	local gait = 0
	local move = data.moveSpeedStuds or 8
	local stride = (BossMotion.context(rigId, rig, data.skills, move).walk.stride or 0.7) * (data.sizeScale or 3)
	ev, w, p, t = run(rigId, function(tt)
		local sp = move * math.clamp(tt / 0.8, 0, 1) * math.clamp((5 - tt) / 0.8, 0, 1)
		gait = (gait + sp * DT / (2 * stride * (BossMotion.strideScale and BossMotion.strideScale(BossMotion.context(rigId, rig, data.skills, move), sp) or 1))) % 1
		return { inCombat = true, speed = sp, gait = gait }
	end, 5, {})
	add(rigId, "walk", ev, w, p, t)
	-- 달리기(이동 × 2.5 - 대공 잡기 쫓기 · 돌진) · 걷기 ↔ 달리기 전환
	gait = 0
	DETAIL = (DETAIL_FOR == rigId .. ":run") and "run" or nil
	ev, w, p, t = run(rigId, function(tt)
		local sp = move * (1 + 1.5 * math.clamp((tt - 0.5) / 0.6, 0, 1)) * math.clamp(tt / 0.6, 0, 1) * math.clamp((5 - tt) / 0.8, 0, 1)
		gait = (gait + sp * DT / (2 * stride * (BossMotion.strideScale and BossMotion.strideScale(BossMotion.context(rigId, rig, data.skills, move), sp) or 1))) % 1
		return { inCombat = true, speed = sp, gait = gait }
	end, 5, {})
	add(rigId, "run", ev, w, p, t)
	DETAIL = nil
	-- 대공 잡기 흐름: 전조(5초) → 쫓기(달리기 1초) → 낚아챔 → 들기 → 던지기 전조 → 던짐
	do
		gait = 0
		local tele, pickAt, throwPlan = 5, 6.2, 9.0
		local plan = BossMotion.planOf(rigId, rig)
		local smooth = 0
		DETAIL = (DETAIL_FOR == rigId .. ":grab") and "grab" or nil
		ev, w, p, t = run(rigId, function(tt)
			local raw = (tt > tele + 0.05 and tt < pickAt) and move * 2.5 or 0
			smooth += (raw - smooth) * (1 - math.exp(-DT * 8)) -- 클라 BossAnimator의 속도 매끈하게와 같은 식
			local sp = smooth
			gait = (gait + sp * DT / (2 * stride * (BossMotion.strideScale and BossMotion.strideScale(BossMotion.context(rigId, rig, data.skills, move), sp) or 1))) % 1
			local st = { inCombat = true, speed = sp, gait = gait, act = "grab", actAt = 0, actHit = tele, noOverlap = true }
			if tt >= pickAt then
				st.pickAt = pickAt
			end
			st.throwPlan = throwPlan
			if tt >= throwPlan then
				st.throwAt, st.act = throwPlan, nil
			end
			return st
		end, throwPlan + 1.8, { { tele - 0.03, tele + 0.12 }, { pickAt - 0.03, pickAt + 0.35 }, { throwPlan - 0.12, throwPlan + 0.35 } })
		add(rigId, "grab", ev, w, p, t)
		DETAIL = nil
	end
	-- 평타 2번(좌 · 우)
	ev, w, p, t = run(rigId, function(tt)
		local n = tt < 1.2 and 1 or 2
		return { inCombat = true, speed = 0, swingAt = n == 1 and 0.2 or 1.4, swingN = n }
	end, 3, { { 0.2 - 0.03, 0.2 + 0.07 + 0.04 * weight + 0.25 }, { 1.4 - 0.03, 1.4 + 0.07 + 0.04 * weight + 0.25 } })
	add(rigId, "basic", ev, w, p, t)
	-- 스킬 동작(대공 잡기 제외 - 서버 흐름이 따로)
	local skillIds = {}
	for sid in pairs(data.skills) do
		table.insert(skillIds, sid)
	end
	table.sort(skillIds)
	for _, sid in ipairs(skillIds) do
		local skill = data.skills[sid]
		if skill.primitive ~= "grab" then
			local clipName = BossMotion.clipNameForSkill(rigId, rig, sid, skill)
			local clip = clipName and BossMotion.clip(rigId, rig, clipName)
			if clip then
				local hit = (skill.primitive ~= "gimmick" and skill.telegraphSeconds) or 1.5
				local at = 0.3
				local contact = at + contactTime(clip, hit)
				local swingFrom = at + ((BossMotion.clipKeys and BossMotion.clipKeys(clip, hit).preEnd) or hit) -- 내려치는 구간(전조 끝 → 접촉)도 타격 동작
				local endAt = at + hit + (clip.loop and 2.0 or 1.6)
				local hs = (clip.hitstop or 0) * weight
				DETAIL = (DETAIL_FOR == rigId .. ":" .. sid) and sid or nil
				if DETAIL then print(("DETAIL %s hit=%.2f contact=%.2f preEnd=%.2f endAt=%.2f"):format(sid, at + hit, contact, at + BossMotion.clipKeys(clip, hit).preEnd, endAt)) end
				ev, w, p, t = run(rigId, function(tt)
					return { inCombat = true, speed = 0, act = sid, actAt = at, actHit = hit, actEndAt = tt >= endAt and endAt or nil }
				end, endAt + 0.8, { { math.min(swingFrom, contact) - 0.03, contact + hs + 0.25 } })
				DETAIL = nil
				add(rigId, "skill:" .. sid .. "(" .. clipName .. ")", ev, w, p, t, contact - (at + hit))
			end
		end
	end
	-- A2-M1 등장(첫 조우 3초 · 짧은 판 1.2초): 내려찍듯 착지하는 방식(번개 강하)은 착지 순간이 타격, 포효 접촉도 타격 순간
	do
		local I = BossData.mechanics.intro
		local bi = (MODS.BossMotionData.bosses[rigId] or {}).intro or {}
		local riseT = I.firstSeconds * (bi.riseFrac or 0.42)
		local roarContact = 0.3 + riseT + 0.05 + 0.35
		ev, w, p, t = run(rigId, function() return { inCombat = true, speed = 0, introAt = 0.3, introSeconds = I.firstSeconds, introFull = true } end, I.firstSeconds + 1.2,
			{ { 0.3 - 0.03, 0.3 + 0.06 }, { 0.3 + riseT - 0.06, 0.3 + riseT + 0.12 }, { roarContact - 0.47, roarContact + 0.35 } })
		add(rigId, "intro", ev, w, p, t)
		ev, w, p, t = run(rigId, function() return { inCombat = true, speed = 0, introAt = 0.3, introSeconds = I.shortSeconds, introFull = false } end, I.shortSeconds + 1.0,
			{ { 0.3 + 0.5 - 0.15, 0.3 + 0.5 + 0.35 } })
		add(rigId, "introShort", ev, w, p, t)
	end
	-- 피격(약 · 강) · 기절 · 사망
	ev, w, p, t = run(rigId, function() return { inCombat = true, speed = 0, flinchAt = 0.2, flinchAmp = 0.7 } end, 1, { { 0.2 - 0.03, 0.2 + 0.1 } })
	add(rigId, "flinch", ev, w, p, t)
	ev, w, p, t = run(rigId, function() return { inCombat = true, speed = 0, flinchAt = 0.2, flinchAmp = 2 } end, 1.2, { { 0.2 - 0.03, 0.2 + 0.12 } })
	add(rigId, "flinchBig", ev, w, p, t)
	ev, w, p, t = run(rigId, function() return { inCombat = true, speed = 0, stunAt = 0.2, stunUntil = 3.2 } end, 4, { { 0.2 - 0.03, 0.2 + 0.12 } }) -- 기절 시작 = 부딪힌 순간(의도된 타격 반응)
	add(rigId, "stun", ev, w, p, t)
	local Dd = plan.death
	local slowEnd = Dd.slowSeconds and (Dd.slowSeconds + (Dd.hitstopAt - Dd.slowSeconds * Dd.slowRate)) or Dd.hitstopAt
	ev, w, p, t = run(rigId, function() return { speed = 0, deadAt = 0.2 } end, 4, { { 0.2 + slowEnd - 0.05, 0.2 + slowEnd + 0.3 } })
	add(rigId, "death", ev, w, p, t)
end

print("===MOTION CSV===")
print("boss,action,jumps,worstScore,worstPart,worstT,contactMinusHit")
for _, r in ipairs(rows) do
	print(r)
end
print("===MOTION END=== total jumps " .. totalEvents)
