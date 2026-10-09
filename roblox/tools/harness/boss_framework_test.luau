-- BOSS-FRAMEWORK 하네스(오프라인): 리그 v2 검사(관절 · 판정 사본 · 부피 · 이름) + 기준 자세 접지 높이(접지 부위 밑점 최저 y ≈ −1.5).
-- 실행: PRELUDE=motion_prelude.luau ECON_RES=res_frame.txt python build_run.py boss_framework_test.luau
local BossRigSpec = MODS.BossRigSpec
local BossRig = MODS.BossRig
local BossFramework = MODS.BossFramework

local pass, total = 0, 0
local function check(name, good, detail)
	total += 1
	if good then
		pass += 1
	end
	print(("[FRAME] %s %s%s"):format(good and "O" or "X", name, detail and (" - " .. detail) or ""))
end

-- 1. 리그 v2 검사
local keys = {}
for key, rig in pairs(BossRigSpec.rigs) do
	if rig.variant then
		table.insert(keys, key)
	end
end
table.sort(keys)
for _, key in ipairs(keys) do
	local ok, lines, st = BossFramework.checkRig(key)
	check("리그 " .. key .. "(" .. BossRigSpec.rigs[key].status .. ")", ok, table.concat(lines, " · "))
	-- 접지: 기준 자세 FK(S = 1) → 접지 부위 밑점 최저 y
	local rig = BossRigSpec.rigs[key]
	local frames = BossRig.solve(rig, CFrame.identity, 1, {})
	local minY, maxY, who = math.huge, -math.huge, nil
	for _, f in ipairs(rig.feet) do
		local cf = frames[f.part]
		local y = (cf * CFrame.new(f.at.X, f.at.Y, f.at.Z)).Position.Y
		if y < minY then
			minY, who = y, f.part
		end
		maxY = math.max(maxY, y)
	end
	check("접지 " .. key, #rig.feet > 0 and math.abs(minY + 1.5) < 0.35, ("접지 부위 %d · 최저 %.2f(%s) · 최고 %.2f · 기준 −1.50"):format(#rig.feet, minY, tostring(who), maxY))
end

-- 2. 옛 리그 6종 그대로(관절 수 고정값 - 덤프 대조는 rig_dump_all)
local oldJoints = { section_guardian = 28, frost_giant = 28, abyssal_lord = 37, crystal_queen = 35, scorpion_queen = 51, storm_lord = 31 }
for id, n in pairs(oldJoints) do
	check("옛 리그 " .. id, #BossRigSpec.rigs[id].joints == n and not BossRigSpec.rigs[id].variant, ("관절 %d"):format(#BossRigSpec.rigs[id].joints))
end

-- 3. 스위치: 실전 live 비어 있음(검수 전) · 시험 스위치는 Studio + 속성일 때만
check("실전 스위치 비어 있음", next(MODS.BossFrameworkData.live) == nil)

-- ─────────────────────────── 2. 동작 세트(v2 - 시험 리그만) ───────────────────────────
local BossMotion = MODS.BossMotion
local BossClipSet = MODS.BossClipSet
local BossData = MODS.BossData
local Frame = MODS.BossFrameworkData

local function sortedKeys(t)
	local out = {}
	for k in pairs(t) do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

for _, key in ipairs(keys) do
	local rig = BossRigSpec.rigs[key]
	if rig.status ~= "trial" then
		continue
	end
	local data = BossData.bosses[rig.bossId]
	-- 2-1 빠짐 검사(빠지면 실패)
	local ok, rows = BossClipSet.coverage(key, data.skills, MODS.BossSoundData, BossMotion.contactTime)
	local bad, borrowed, own = {}, 0, 0
	for _, r in ipairs(rows) do
		if not r.ok then
			table.insert(bad, r.form .. "/" .. r.key .. ":" .. r.what)
		end
		if r.what:find("^빌림") then
			borrowed += 1
		elseif r.what:find("^전용") then
			own += 1
		end
	end
	check("빠짐 검사 " .. key, ok, ("줄 %d · 전용 %d · 빌림 %d%s"):format(#rows, own, borrowed, #bad > 0 and (" · X " .. table.concat(bad, " | ")) or ""))
	if PRINT_COVERAGE then
		for _, r in ipairs(rows) do
			print(("  COVER %s %s %s %s"):format(r.ok and "O" or "X", r.form, r.key, r.what))
		end
	end

	-- 2-2 세트 자세 접지(서 있기 · 전투 준비): 접지 부위 밑점 높이 차(너클 = 손 · 발 같이 바닥)
	local ctx = BossMotion.context(key, rig, data.skills, data.moveSpeedStuds)
	local rest = BossMotion.prepare(rig)
	for _, formName in ipairs({ "before", "after" }) do
		local pose, info = BossMotion.evaluate(ctx, { form = formName, inCombat = true, speed = 0, gait = 0 }, 1.0)
		local frames = BossRig.solve(rig, CFrame.identity, 1, BossMotion.toTransforms(rest, 1, pose))
		local ys, lo = {}, math.huge
		for _, name in ipairs(info.contacts or { "Foot_L", "Foot_R" }) do
			local at = rig.contactAt[name]
			local y = (frames[name] * CFrame.new(at.X, at.Y, at.Z)).Position.Y
			ys[name] = y
			lo = math.min(lo, y)
		end
		local spread = 0
		for _, y in pairs(ys) do
			spread = math.max(spread, y - lo)
		end
		local parts = {}
		for _, n in ipairs(sortedKeys(ys)) do
			table.insert(parts, ("%s %.2f"):format(n, ys[n]))
		end
		check(("접지 자세 %s %s"):format(key, formName), spread < 0.2, ("%s · 높이 차 %.2f(< 0.20) · 보행 %s"):format(table.concat(parts, " · "), spread, tostring(ctx.set.forms[formName].gait)))
	end

	-- 2-3 튐 · 접촉 = 판정 시각: 대기 · 걷기(전/후) · 스킬 전부(전/후) · 변신 - 60fps FK 각속도 변화(boss_motion_test와 같은 잣대 450°/s²·프레임)
	local FPS, ANG = 60, 450
	local function rel(a, b)
		local ra, rb = a.r, b.r
		local function el(i, j)
			return rb[(i - 1) * 3 + 1] * ra[(j - 1) * 3 + 1] + rb[(i - 1) * 3 + 2] * ra[(j - 1) * 3 + 2] + rb[(i - 1) * 3 + 3] * ra[(j - 1) * 3 + 3]
		end
		local tr = el(1, 1) + el(2, 2) + el(3, 3)
		local th = math.acos(math.clamp((tr - 1) / 2, -1, 1))
		if th < 1e-7 then
			return 0, 0, 0
		end
		local k = math.deg(th) / math.max(2 * math.sin(th), 1e-9)
		return (el(3, 2) - el(2, 3)) * k, (el(1, 3) - el(3, 1)) * k, (el(2, 1) - el(1, 2)) * k
	end
	local function run(stFn, T, excl)
		local prevF, prevW = nil, {}
		local events, worst, worstPart, worstT, flagged = 0, 0, nil, 0, false
		for i = 0, math.floor(T * FPS) do
			local t = i / FPS
			local pose = BossMotion.evaluate(ctx, stFn(t), t)
			local frames = BossRig.solve(rig, CFrame.identity, 1, BossMotion.toTransforms(rest, 1, pose))
			local ex = false
			for _, w in ipairs(excl or {}) do
				if t >= w[1] and t <= w[2] then
					ex = true
				end
			end
			local bad = false
			if prevF then
				for part, cf in pairs(frames) do
					local p = prevF[part]
					if p then
						local wx, wy, wz = rel(p, cf)
						wx, wy, wz = wx * FPS, wy * FPS, wz * FPS
						local pw = prevW[part]
						if pw and not ex then
							local dw = math.sqrt((wx - pw[1]) ^ 2 + (wy - pw[2]) ^ 2 + (wz - pw[3]) ^ 2) / ANG
							if dw > 1 then
								bad = true
							end
							if dw > worst then
								worst, worstPart, worstT = dw, part, t
							end
						end
						prevW[part] = { wx, wy, wz }
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
	local jumpsTotal = 0
	local function report(label, ev, worst, part, t, extra)
		jumpsTotal += ev
		print(("  MOTION %s %s jumps=%d worst=%.2f(%s @ %.2f)%s"):format(key, label, ev, worst, tostring(part), t, extra or ""))
	end
	local walkSpeed = data.moveSpeedStuds or 8
	for _, formName in ipairs({ "before", "after" }) do
		report(formName .. ":idle", run(function()
			return { form = formName, inCombat = true, speed = 0, gait = 0 }
		end, 4))
		local Wf = BossMotion.walkFor(ctx, formName)
		report(formName .. ":walk", run(function(t)
			local d = math.min(t, 1) * walkSpeed * t * 0.5 + math.max(t - 1, 0) * walkSpeed -- 1초에 걸쳐 속도를 올림
			local sp = math.min(t, 1) * walkSpeed
			return { form = formName, inCombat = true, speed = sp / 3.9, gait = (d / 3.9) / (2 * Wf.stride) % 1 }
		end, 5))
		for _, sid in ipairs(sortedKeys(data.skills)) do
			local sk = data.skills[sid]
			if sk.primitive ~= "grab" then
				local hit = sk.telegraphSeconds or 1.5
				local name = BossMotion.clipNameForSkill(key, rig, sid, sk, formName)
				local clip = BossMotion.clip(key, rig, name)
				local contact = clip and BossMotion.contactTime(clip, hit) or hit
				local preEnd = clip and BossMotion.clipKeys(clip, hit).preEnd or hit
				local hs = clip and (clip.hitstop or 0) * (rig.weight or 1) or 0
				local excl = { { 0.3 + preEnd - 0.03, 0.3 + contact + hs + 0.25 } } -- 의도된 타격 창 = boss_motion_test와 같음(휘두르기 시작 ~ 접촉 + 정지 + 0.25)
				-- GUARDIAN-V2: 동작 데이터의 extraStrikes(가슴 치기 · 둘째 볼리 · 연타) = 같은 잣대의 창(앞 키 ~ 그 키 + 정지 + 0.25)
				if clip and clip.extraStrikes then
					local K = BossMotion.clipKeys(clip, hit)
					local times = {}
					for _, f in ipairs(clip.extraStrikes.pre or {}) do
						table.insert(times, f * K.preEnd)
					end
					for _, s in ipairs(clip.extraStrikes.post or {}) do
						table.insert(times, hit + s - K.strike + hs)
					end
					for _, tk in ipairs(times) do
						local prev = 0
						for _, k in ipairs(K.keys) do
							if k.t < tk - 1e-6 then
								prev = math.max(prev, k.t)
							end
						end
						table.insert(excl, { 0.3 + prev - 0.03, 0.3 + tk + hs + 0.25 })
					end
				end
				local ev, worst, part, t = run(function(tt)
					return { form = formName, inCombat = true, speed = 0, gait = 0, act = sid, actAt = 0.3, actHit = hit, actEndAt = (tt > 0.3 + hit + 2.2) and (0.3 + hit + 2.2) or nil }
				end, hit + 3.2, excl)
				report(("%s:%s(%s)"):format(formName, sid, tostring(name)), ev, worst, part, t, (" contact-hit=%.3f"):format(contact - hit))
			end
		end
	end
	local T = ctx.set.transform
	report("transform", run(function()
		return { inCombat = true, speed = 0, gait = 0, transformAt = 0.3 }
	end, T.seconds + 1.2, { { 0.3 + T.hit - 0.03, 0.3 + T.hit + 1.1 } })) -- 가슴 치기 2번 · 수정 폭발 = 의도된 빠른 구간
	check("튐 " .. key, jumpsTotal == 0, ("튐 합 %d(대기 · 걷기 · 스킬 · 변신 - 의도된 타격 창 제외)"):format(jumpsTotal))

	-- 2-4 번쩍: 판정 시각 직전 0.15초에만 · 판정 순간에 꺼짐
	local sid = data.skills.heavy and "heavy" or ctx.set.signature[1] -- BOSS-NIGHT-1: 강공격이 없는 보스 = 세트 대표 스킬 첫째
	local sk = data.skills[sid]
	local hitAt = 0.3 + sk.telegraphSeconds
	local _, iBefore = BossMotion.evaluate(ctx, { form = "before", inCombat = true, act = sid, actAt = 0.3, actHit = sk.telegraphSeconds }, hitAt - 0.2)
	local _, iIn = BossMotion.evaluate(ctx, { form = "before", inCombat = true, act = sid, actAt = 0.3, actHit = sk.telegraphSeconds }, hitAt - 0.05)
	local _, iAfter = BossMotion.evaluate(ctx, { form = "before", inCombat = true, act = sid, actAt = 0.3, actHit = sk.telegraphSeconds }, hitAt + 0.01)
	check("번쩍 창 " .. key, iBefore.rim == nil and iIn.rim ~= nil and iAfter.rim == nil, ("판정 −0.20 %s · −0.05 %s(%s) · +0.01 %s"):format(tostring(iBefore.rim ~= nil), tostring(iIn.rim ~= nil), iIn.rim and table.concat(iIn.rim, "/") or "-", tostring(iAfter.rim ~= nil)))

	-- 2-5 변신: switchAt 전 = before · 뒤 = after
	local _, a = BossMotion.evaluate(ctx, { transformAt = 0, inCombat = true }, T.switchAt - 0.05)
	local _, b = BossMotion.evaluate(ctx, { transformAt = 0, inCombat = true }, T.switchAt + 0.05)
	check("변신 세트 교체 " .. key, a.form == "before" and b.form == "after" and a.transforming and b.transforming, ("%.2f초 전 %s · 뒤 %s"):format(T.switchAt, tostring(a.form), tostring(b.form)))

	-- 2-6 비용(오프라인 - luau CLI · 상대 비교만): 프레임당 evaluate + FK(접지용) 평균 μs - 옛 몸 같은 보스와 비교
	local function cost(c, r, st, n, full)
		local rr = BossMotion.prepare(r)
		-- BOSS-NIGHT-1: 지금 클라 = 발 접지 사슬만 FK(BossRig.solveParts) · 기준(옛 몸 · 변경 전 클라) = 전체 FK(full) - 바이블 §1-4 "지금 × 1.5"
		local feet = {}
		for _, f in ipairs(r.feet or {}) do
			table.insert(feet, f.part)
		end
		local t0 = os.clock()
		for i = 1, n do
			local pose = BossMotion.evaluate(c, st, i / 60)
			if full then
				BossRig.solve(r, CFrame.identity, 1, BossMotion.toTransforms(rr, 1, pose))
			else
				BossRig.solveParts(r, CFrame.identity, 1, BossMotion.toTransforms(rr, 1, pose), feet)
			end
		end
		return (os.clock() - t0) / n * 1e6
	end
	local oldRig = BossRigSpec.rigs[rig.bossId]
	local oldCtx = BossMotion.context(rig.bossId, oldRig, data.skills, data.moveSpeedStuds)
	local stWalk = { inCombat = true, speed = 6, gait = 0.3, act = "heavy", actAt = 0, actHit = 2 }
	-- BOSS-NIGHT-1: 옛 · 새를 교대로 3번 재 최솟값(먼저 잰 쪽의 쓰레기를 뒤에 잰 쪽이 치르는 잡음 - 같은 보스가 × 1.0 ~ 2.5로 흔들렸다)
	local cOld, cNew = math.huge, math.huge
	for _ = 1, 3 do
		cOld = math.min(cOld, cost(oldCtx, oldRig, stWalk, 1500, true))
		cNew = math.min(cNew, cost(ctx, rig, stWalk, 1500))
	end
	check("모션 비용(오프라인) " .. key, cNew <= cOld * 1.5, ("옛 몸 · 변경 전 클라(전체 FK) %.1fμs → 새 몸 · 지금 클라(발 사슬 FK) %.1fμs(× %.2f · 합격 ≤ × 1.5)"):format(cOld, cNew, cNew / cOld))
end

-- ─────────────────────────── GUARDIAN-V2 4: 크기 × 1.5 · 몸 가장자리 기준 반경(인스턴스 데이터 - 스테이지 15 · 솔로) ───────────────────────────
do
	local BossRules = MODS.BossRules
	local walk = MODS.WorldConfig.playerWalkSpeedStuds
	local ids = sortedKeys(BossData.bosses)
	local same = 0
	for _, id in ipairs(ids) do
		local d = BossRules.buildInstanceData(15, id, 1)
		local out, edge = BossFramework.applyBodyEdge(d, id .. "_v2", walk)
		if not Frame.bodyEdge[id] then -- BOSS-NIGHT-1: 설정이 있는 보스(수호자 · 매머드 …)는 아래 보스별 줄이 본다
			if out == d and edge == 0 then
				same += 1
			end
		end
	end
	local nOther = 0
	for _, id in ipairs(ids) do
		nOther += Frame.bodyEdge[id] and 0 or 1
	end
	check("몸 가장자리 장치 - 설정 없는 보스 값 변화 0", same == nOther, ("%d / %d(표에 없음 = 사본도 안 만듦)"):format(same, nOther))
	local d = BossRules.buildInstanceData(15, "section_guardian", 1)
	local g, edge, fitted = BossFramework.applyBodyEdge(d, "section_guardian_v2", walk)
	local rig = BossRigSpec.rigs.section_guardian_v2
	local rows = {}
	local function cmp(label, a, b)
		table.insert(rows, ("%s %.1f → %.1f"):format(label, a or 0, b or 0))
	end
	cmp("강공격 r", d.skills.heavy.radiusStuds, g.skills.heavy.radiusStuds)
	cmp("원 안 내려찍기 r", d.skills.innerSmash.radiusStuds, g.skills.innerSmash.radiusStuds)
	cmp("강화 평타 부채 r", d.skills.swipe.radiusStuds, g.skills.swipe.radiusStuds)
	cmp("강화 평타 대상 거리", d.skills.swipe.conditions[1].studs, g.skills.swipe.conditions[1].studs)
	cmp("반사 결계 r", d.skills.mirror.barrierRadiusStuds, g.skills.mirror.barrierRadiusStuds)
	cmp("근접 원형 구역 r", d.innerSafeRadiusStuds, g.innerSafeRadiusStuds)
	cmp("추격 정지", d.chaseStopDistanceStuds, g.chaseStopDistanceStuds)
	local nfit = 0
	for _ in pairs(fitted) do
		nfit += 1
	end
	local okEdge = math.abs(edge - BossFramework.edgeGrowth(rig, d.sizeScale)) < 1e-6 and edge > 0
	check("몸 가장자리 수호자 +" .. ("%.2f"):format(edge) .. " stud", okEdge and nfit == 0 and d.skills.heavy.radiusStuds == MODS.BossRules.buildInstanceData(15, "section_guardian", 1).skills.heavy.radiusStuds,
		table.concat(rows, " · ") .. (" · 전조 맞춤 다시 %d개(서 있는 거리도 같이 늘어 0이어야)"):format(nfit))
	-- 크기(V2 × 1.5 → V3 키 30 = × 1.92): 보이는 몸 · 판정 사본 · 피격 반경
	local S = d.sizeScale
	local old = BossRigSpec.rigs.section_guardian
	local function bodyOf(r)
		for _, j in ipairs(r.joints) do
			if j.part == "Body" then
				return j.size
			end
		end
	end
	local oldBody, newBody = bodyOf(old), bodyOf(rig)
	local volOld = MODS.BossSkeleton.queryVolume(old) * S ^ 3
	local volNew = MODS.BossSkeleton.queryVolume(rig) * (S * rig.scale) ^ 3
	-- GUARDIAN-V3 6: 판정 사본 부피 = scale³ × 옛 몸(±20%) · 카메라 = 1.3 × scale ÷ 1.5(§5 비례) · 서 있는 키(FK 실측)는 아래 V3 블록
	local camOk = math.abs(rig.cameraZoomScale - 1.3 * rig.scale / 1.5) <= 0.01
	check("크기 × " .. rig.scale, camOk and math.abs(volNew / volOld / rig.scale ^ 3 - 1) <= Frame.budget.queryVolumeTolerance + 1e-6,
		("판정 사본 부피 %.0f → %.0f stud³(× %.2f = %.2f³ × %.2f) · 몸통 판정 %.1f×%.1f×%.1f → %.1f×%.1f×%.1f · 가장자리 반폭 %.1f → %.1f stud · 카메라 34 → %.1f(× %.2f)"):format(
			volOld, volNew, volNew / volOld, rig.scale, volNew / volOld / rig.scale ^ 3, oldBody.X * S, oldBody.Y * S, oldBody.Z * S, newBody.X * S * rig.scale, newBody.Y * S * rig.scale, newBody.Z * S * rig.scale,
			rig.baseEdgeHalfWidth * S, rig.edgeHalfWidth * S * rig.scale, BossData.bosses.section_guardian.cameraZoomStuds * rig.cameraZoomScale, rig.cameraZoomScale))
	-- 때리는 부위 = 전조 안(보스 중심 원 · 부채): 접촉 순간 번쩍 부위 수평 거리 ≤ 반경(+ 가장자리) · 땅 치기는 높이 바닥 ±0.25 단위
	local ctx2 = BossMotion.context("section_guardian_v2", rig, g.skills, g.moveSpeedStuds)
	local rest2 = BossMotion.prepare(rig)
	local sizes = {}
	for _, j in ipairs(rig.joints) do
		sizes[j.part] = j.size
	end
	local reach = {}
	local reachOk = true
	for _, sid in ipairs({ "heavy", "innerSmash", "swipe" }) do
		local sk = g.skills[sid]
		for _, form in ipairs({ "before", "after" }) do
			local name = BossMotion.clipNameForSkill("section_guardian_v2", rig, sid, sk, form)
			local clip = BossMotion.clip("section_guardian_v2", rig, name)
			local tc = BossMotion.contactTime(clip, sk.telegraphSeconds)
			local pose = BossMotion.evaluate(ctx2, { form = form, inCombat = true, speed = 0, gait = 0, act = sid, actAt = 0, actHit = sk.telegraphSeconds }, tc + 0.001)
			local frames = BossRig.solve(rig, CFrame.identity, 1, BossMotion.toTransforms(rest2, 1, pose))
			local far, lowY = 0, math.huge
			for _, part in ipairs(ctx2.set.flash[sid]) do
				local p = (frames[part] * CFrame.new(0, -sizes[part].Y / 2, 0)).Position
				far = math.max(far, math.sqrt(p.X ^ 2 + p.Z ^ 2) * S * rig.scale)
				lowY = math.min(lowY, p.Y)
			end
			local ground = sk.primitive ~= "sector"
			local good = far <= sk.radiusStuds + 0.05 and (not ground or math.abs(lowY + 1.5) <= 0.25)
			reachOk = reachOk and good
			table.insert(reach, ("%s/%s %.1f ≤ %.1f%s"):format(sid, form, far, sk.radiusStuds, ground and (" · 높이 %.2f"):format(lowY) or ""))
		end
	end
	check("때리는 부위 = 전조 안", reachOk, table.concat(reach, " · "))
end

-- ─────────────────────────── GUARDIAN-V3: 새 몸 설정(BossFramework.applyV3 - 스테이지 15 · 솔로) ───────────────────────────
do
	local BossRules = MODS.BossRules
	local BossSkillMath = MODS.BossSkillMath
	local BossScheduler = MODS.BossScheduler
	local walk = MODS.WorldConfig.playerWalkSpeedStuds
	local V3 = Frame.v3.section_guardian
	local rig = BossRigSpec.rigs.section_guardian_v2
	-- 다른 5보스 · 옛 몸 = 그대로(같은 표)
	local same, ids = 0, sortedKeys(BossData.bosses)
	for _, id in ipairs(ids) do
		local d = BossRules.buildInstanceData(15, id, 1)
		-- 설정 있는 보스 = 옛 몸(리그 nil)으로 · 없는 보스 = 새 몸 리그 키로도 그대로여야
		if BossFramework.applyV3(d, not Frame.v3[id] and (id .. "_v2") or nil) == d then
			same += 1
		end
	end
	check("V3 - 설정 없는 보스 · 옛 몸 값 변화 0", same == #ids, ("%d / %d"):format(same, #ids))
	local d = BossRules.buildInstanceData(15, "section_guardian", 1)
	local e = BossFramework.applyBodyEdge(d, "section_guardian_v2", walk)
	local g = BossFramework.applyV3(e, "section_guardian_v2")
	local half = rig.edgeHalfWidth * d.sizeScale * rig.scale
	local hideOk = g.skills.heavy.noFloor and g.skills.innerSmash.noFloor and g.skills.swipe.noFloor and not g.skills.earthSplit.noFloor and g.basicNoFloor and g.innerRingHidden
	check("V3 근접 바닥 표시 끔(평타 · 내려찍기 · 안쪽 원 · 휘두르기 - 대지 가르기는 남김)", hideOk == true,
		("강공격 %s · 원 안 %s · 강화 평타 %s · 대지 가르기 %s · 평타 %s · 근접 원 %s"):format(tostring(g.skills.heavy.noFloor), tostring(g.skills.innerSmash.noFloor), tostring(g.skills.swipe.noFloor),
			tostring(g.skills.earthSplit.noFloor), tostring(g.basicNoFloor), tostring(g.innerRingHidden)))
	local w = V3.windup.seconds
	local windOk = w >= 0.1 and w <= 0.15 and math.abs(g.skills.heavy.telegraphSeconds - e.skills.heavy.telegraphSeconds - w) < 1e-9
		and math.abs(g.skills.innerSmash.telegraphSeconds - e.skills.innerSmash.telegraphSeconds - w) < 1e-9 and math.abs(g.skills.swipe.telegraphSeconds - e.skills.swipe.telegraphSeconds - w) < 1e-9
		and g.skills.charge.telegraphSeconds == e.skills.charge.telegraphSeconds and g.basicWindupExtraSeconds == w
	check("V3 예비 동작 +" .. w .. "초(0.1 ~ 0.15)", windOk, ("강공격 %.2f → %.2f · 원 안 %.2f → %.2f · 강화 평타 %.2f → %.2f · 평타 예비 + %.2f"):format(e.skills.heavy.telegraphSeconds, g.skills.heavy.telegraphSeconds,
		e.skills.innerSmash.telegraphSeconds, g.skills.innerSmash.telegraphSeconds, e.skills.swipe.telegraphSeconds, g.skills.swipe.telegraphSeconds, g.basicWindupExtraSeconds or 0))
	check("V3 돌진 경로 반폭 = 몸 반폭", math.abs(g.skills.charge.pathHalfWidthStuds - half) < 1e-6 and g.skills.charge.markStyle == "crack",
		("%.2f → %.2f stud(몸 가장자리 반폭)"):format(e.skills.charge.pathHalfWidthStuds, g.skills.charge.pathHalfWidthStuds))
	check("V3 이속 × 1.3 · 질주 25 stud 밖 × 1.5", math.abs(g.moveSpeedStuds - e.moveSpeedStuds * 1.3) < 1e-6 and g.sprintBeyondStuds == 25 and g.sprintMultiplier == 1.5,
		("%.1f → %.1f · 질주 %.1f stud/s(걷기 %d)"):format(e.moveSpeedStuds, g.moveSpeedStuds, g.moveSpeedStuds * g.sprintMultiplier, walk))
	local b, l = g.skills.banana, g.skills.leap
	local bOk = b and b.reactive and b.telegraphSeconds == 0.45 and b.speedStuds == 110 and b.leadFraction == 0.5 and b.damage.kind == "maxHp" and b.damage.fraction == 0.07
		and b.cooldownSeconds == 3 and b.conditions[1].type == "targetBeyondFor" and b.conditions[1].studs == 30 and b.conditions[1].seconds == 1.5 and b.overrides[1].set.count == 3
	check("V3 바나나(조건 30 stud · 1.5초 · 쿨 3 · 예비 0.45 · 110 stud/s · 리드 50% · 7% · 광폭 3갈래)", bOk == true, b and ("쿨 %d · 예비 %.2f · 속도 %d · 리드 %.0f%% · 최대 체력 %.0f%% · 광폭 %d갈래"):format(
		b.cooldownSeconds, b.telegraphSeconds, b.speedStuds, b.leadFraction * 100, b.damage.fraction * 100, b.overrides[1].set.count) or "없음")
	local lOk = l and l.reactive and l.telegraphSeconds == 1.1 and l.lockSeconds == 0.4 and l.flightSeconds == 0.8 and l.maxLeapStuds == 60 and math.abs(l.radiusStuds - (half + 12)) < 1e-6
		and l.conditions[1].count == 2 and l.conditions[1].seconds == 12 and l.onHit[1].type == "launch"
	-- 도약 회피: 착지 원은 준비 시작부터 보이고 대상을 따라온다 → 인지(perception)는 고정 전 표시 시간(준비 − 고정 0.6초) 안에 끝난다.
	--   고정(끝 0.3초) + 비행 0.8 = 1.1초 안에 대상 자리(몸 끝)에서 원 밖으로 = (반경 − 몸 반폭 + 캐릭터 반폭) ÷ 걷기 × 여유 계수
	local dodge = BossData.mechanics.dodge
	local seen = l.telegraphSeconds - l.lockSeconds
	local need = (l.radiusStuds - l.landShortStuds + dodge.characterHalfWidthStuds) / walk * dodge.marginFactor
	local have = l.lockSeconds + l.flightSeconds
	-- V3.1: 순수 걷기(여유 계수 없이) 여유 ≥ 0.3초(사용자 목표)
	local raw = (l.radiusStuds - l.landShortStuds + dodge.characterHalfWidthStuds) / walk
	check("V3.1 도약(빗나감 2회/12초 · 준비 1.1 · 고정 0.4 · 비행 0.8 · 60 stud · 반경 몸 + 12 · 넉백) + 걸어서 회피 여유 ≥ 0.3", lOk == true and have >= need and have - raw >= 0.3 and seen >= dodge.perceptionSeconds,
		l and ("반경 %.2f(= %.2f + 12) · 고정 전 표시 %.2f초 ≥ 인지 %.2f · 고정 뒤 걷기 %.2f초(× 1.25 = %.2f) ≤ %.2f초(순수 여유 %.2f · 계수 여유 %.2f)"):format(l.radiusStuds, half, seen, dodge.perceptionSeconds, raw, need, have, have - raw, have - need) or "없음")
	-- 남은 스킬 회피 부등식(돌진 폭이 넓어짐 · 예비 연장) - 서 있는 거리 = 추격 정지
	local bad = {}
	for id, s in pairs(g.skills) do
		if not s.reactive then
			for _, c in ipairs(BossSkillMath.dodgeChecks(s, g.chaseStopDistanceStuds, walk)) do
				if not c.ok then
					table.insert(bad, ("%s %s %.2f > %.2f"):format(id, c.label, c.requiredSeconds, c.availableSeconds))
				end
			end
		end
	end
	check("V3 회피 부등식(전 스킬)", #bad == 0, #bad == 0 and "실패 0" or table.concat(bad, " · "))
	-- 스케줄러 ⑧: 반응 스킬은 일반 후보가 아니고 전역 쿨을 건드리지 않는다
	local st = BossScheduler.newState(g.skills, g.skillOrder, 0, false, g.scheduler)
	local beyond, misses = false, 0
	local ctx = { now = 5, graceUntil = 0, conditionMet = function(c)
		if c.type == "targetBeyondFor" then
			return beyond
		elseif c.type == "missesWithin" then
			return misses >= c.count
		end
		return true
	end, boundSeconds = function() return 1 end }
	local r0 = BossScheduler.pickReactive(st, g.skills, g.reactiveOrder, ctx)
	beyond = true
	local r1 = BossScheduler.pickReactive(st, g.skills, g.reactiveOrder, ctx)
	local lastEnd = st.lastEndAt
	BossScheduler.onReactiveEnd(st, g.skills, "banana", 5)
	ctx.now = 6
	local r2 = BossScheduler.pickReactive(st, g.skills, g.reactiveOrder, ctx)
	ctx.now = 8.01
	local r3 = BossScheduler.pickReactive(st, g.skills, g.reactiveOrder, ctx)
	misses = 2
	local r4 = BossScheduler.pickReactive(st, g.skills, g.reactiveOrder, ctx)
	local inOrder = table.find(g.skillOrder, "banana") or table.find(g.skillOrder, "leap")
	check("V3 스케줄러 ⑧ 반응 스킬", r0 == nil and r1 == "banana" and r2 == nil and r3 == "banana" and r4 == "leap" and st.lastEndAt == lastEnd and not inOrder,
		("멀지 않음 %s · 멂 %s · 쿨 중 %s · 쿨 뒤 %s · 빗나감 2 %s · 전역 쿨 그대로 %s · 일반 후보 아님 %s"):format(tostring(r0), tostring(r1), tostring(r2), tostring(r3), tostring(r4), tostring(st.lastEndAt == lastEnd), tostring(not inOrder)))
	-- 첫 보스 도움: 실패 0 · 1 · 3 · 5 → 1 · 0.9 · 0.7 · 0.7 · 클리어 뒤 1
	local A = g.firstAssist
	local m = { BossFramework.assistMultiplier(A, 0, false), BossFramework.assistMultiplier(A, 1, false), BossFramework.assistMultiplier(A, 3, false), BossFramework.assistMultiplier(A, 5, false), BossFramework.assistMultiplier(A, 5, true) }
	check("V3 첫 보스 도움(−10%/실패 · 최대 −30% · 클리어 뒤 끝)", math.abs(m[1] - 1) < 1e-9 and math.abs(m[2] - 0.9) < 1e-9 and math.abs(m[3] - 0.7) < 1e-9 and math.abs(m[4] - 0.7) < 1e-9 and m[5] == 1,
		("%.2f · %.2f · %.2f · %.2f · 클리어 %.2f"):format(m[1], m[2], m[3], m[4], m[5]))
	check("V3 실전 스위치 live 비어 있음", next(Frame.live) == nil, "live = {}")
	-- 서 있는 키(FK · 기본 자세 · 전투 대기): 발 −1.5 기준 머리 꼭대기 · 전체 꼭대기 × S × scale - 목표 약 30 stud(직립 = 변신 뒤)
	local ctx3 = BossMotion.context("section_guardian_v2", rig, g.skills, g.moveSpeedStuds)
	local rest3 = BossMotion.prepare(rig)
	local size3 = {}
	for _, j in ipairs(rig.joints) do
		size3[j.part] = j.size
	end
	local tops = {}
	for _, form in ipairs({ "before", "after" }) do
		local pose = BossMotion.evaluate(ctx3, { form = form, inCombat = true, speed = 0, gait = 0 }, 10)
		local frames = BossRig.solve(rig, CFrame.identity, 1, BossMotion.toTransforms(rest3, 1, pose))
		local head = (frames.Head * CFrame.new(0, size3.Head.Y / 2, 0)).Position.Y
		local all = -math.huge
		for part, cf in pairs(frames) do
			if size3[part] then
				all = math.max(all, (cf * CFrame.new(0, size3[part].Y / 2, 0)).Position.Y)
			end
		end
		tops[form] = { head = (head + 1.5) * d.sizeScale * rig.scale, all = (all + 1.5) * d.sizeScale * rig.scale }
	end
	check("V3 서 있는 키 약 30 stud(직립 머리 꼭대기 ±1)", math.abs(tops.after.head - 30) <= 1,
		("직립(변신 뒤) 머리 %.1f · 전체 %.1f stud · 너클(변신 전) 머리 %.1f · 전체 %.1f stud"):format(tops.after.head, tops.after.all, tops.before.head, tops.before.all))
end

-- ─────────────────────────── BOSS-NIGHT-1 1: 빙하 매머드 새 몸(applyBodyEdge → applyV3 · 스테이지 15 · 솔로) ───────────────────────────
do
	local BossRules = MODS.BossRules
	local BossSkillMath = MODS.BossSkillMath
	local walk = MODS.WorldConfig.playerWalkSpeedStuds
	local d = BossRules.buildInstanceData(15, "frost_giant", 1)
	local e, edge = BossFramework.applyBodyEdge(d, "frost_giant_v2", walk)
	local g = BossFramework.applyV3(e, "frost_giant_v2")
	local rig = BossRigSpec.rigs.frost_giant_v2
	local k = d.sizeScale * rig.scale
	local front, rear, half = rig.frontHalfLength * k, rig.rearHalfLength * k, rig.edgeHalfWidth * k
	local inOrder = function(id)
		return table.find(g.skillOrder, id) ~= nil
	end
	check("매머드 신규 패턴(얼음 창 → 얼음 상아 · 코 채찍 · 상아 돌진 · 뒷발차기 반응)", g.skills.spear == nil and not inOrder("spear") and inOrder("tuskShot") and inOrder("trunkWhip") and inOrder("gore")
		and not inOrder("backKick") and g.reactiveOrder[1] == "backKick" and g.skills.backKick.reactive == true,
		("일반 후보 %d개 · 반응 %s"):format(#g.skillOrder, table.concat(g.reactiveOrder, ",")))
	local tw, bk, go, ts = g.skills.trunkWhip, g.skills.backKick, g.skills.gore, g.skills.tuskShot
	check("매머드 앞 · 뒤 구역(반경 = 머리 앞 끝 / 엉덩이 끝 기준)", math.abs(tw.radiusStuds - (12 + front)) < 1e-6 and math.abs(tw.conditions[1].studs - (12 + front)) < 1e-6
		and math.abs(bk.radiusStuds - (14 + rear)) < 1e-6 and math.abs(bk.conditions[1].studs - (20 + rear)) < 1e-6 and math.abs(go.arenaMarginStuds - (4 + front)) < 1e-6,
		("앞 끝 %.1f · 엉덩이 끝 %.1f · 옆 %.1f stud · 코 채찍 r %.1f · 뒷발차기 r %.1f(조건 %.1f) · 돌진 벽 여유 %.1f"):format(front, rear, half, tw.radiusStuds, bk.radiusStuds, bk.conditions[1].studs, go.arenaMarginStuds))
	check("매머드 상아 돌진 경로 반폭 = 몸 반폭 · 균열선", math.abs(go.pathHalfWidthStuds - half) < 1e-6 and go.markStyle == "crack", ("%.2f stud"):format(go.pathHalfWidthStuds))
	check("매머드 바닥 표시 끔(근접) · 예비 +0.12", g.skills.slam.noFloor and g.skills.innerSmash.noFloor and g.skills.swipe.noFloor and tw.noFloor and bk.noFloor and not g.skills.stomp.noFloor
		and math.abs(g.skills.slam.telegraphSeconds - (d.skills.slam.telegraphSeconds + 0.12)) < 1e-6 and g.basicNoFloor and g.innerRingHidden,
		("빙결 강타 %.2f → %.2f · 코 채찍 %.2f · 발 구르기 바닥 표시 유지(점프로 넘기 - 큰 범위)"):format(d.skills.slam.telegraphSeconds, g.skills.slam.telegraphSeconds, tw.telegraphSeconds))
	check("매머드 피해 계수 × 0.60(신규 · 반응 포함)", math.abs(g.skills.slam.damage.multiplier - d.skills.slam.damage.multiplier * 0.6) < 1e-6 and math.abs(ts.damage.multiplier - 1.8 * 0.6) < 1e-6
		and math.abs(bk.damage.multiplier - 2.0 * 0.6) < 1e-6, ("빙결 강타 %.2f · 얼음 상아 %.2f · 뒷발차기 %.2f"):format(g.skills.slam.damage.multiplier, ts.damage.multiplier, bk.damage.multiplier))
	local bad = {}
	for id, s in pairs(g.skills) do
		if not s.reactive then
			for _, c in ipairs(BossSkillMath.dodgeChecks(s, g.chaseStopDistanceStuds, walk)) do
				if not c.ok then
					table.insert(bad, ("%s %s %.2f > %.2f"):format(id, c.label, c.requiredSeconds, c.availableSeconds))
				end
			end
		end
	end
	-- 뒷발차기(반응): 엉덩이 끝 + 14 부채 밖으로 = 서 있던 자리(조건 반경 안 · 끝에서 6 안쪽 가정) → 옆으로 비키기(부채 120° - 옆 반폭) ≤ 예비 0.9
	local side = (14 + rear) * math.sin(math.rad(60)) -- 부채 가장자리까지 옆 거리(최악 = 뒤 한가운데)
	local needKick = (MODS.BossData.mechanics.dodge.perceptionSeconds + 8 / walk) -- 뒤 한가운데에서 비스듬히 8 stud(부채 가장자리 각) = 인지 + 걷기
	check("매머드 회피 부등식(신규 포함 전 스킬)", #bad == 0, #bad == 0 and "실패 0" or table.concat(bad, " · "))
	check("매머드 뒷발차기 회피(걷기 - 대시 · 점프 없이)", needKick <= bk.telegraphSeconds, ("인지 0.5 + 옆 8 stud 걷기 = %.2f초 ≤ 예비 %.2f"):format(needKick, bk.telegraphSeconds))
	check("매머드 크기(등 높이 약 30 · 길이 약 39 stud)", math.abs(0.85 * 2.4 * k - 30) < 1.5, ("등 %.1f · 몸 길이(엉덩이 끝 ~ 머리 앞) %.1f · 상아 끝 ~ 꼬리 %.1f stud · 몸 가장자리 +%.2f · BodyRadius 증가"):format(0.85 * 2.4 * k, front + rear, 1.73 * 2.4 * k, edge))
end

-- ─────────────────────────── BOSS-NIGHT-1 2: 폭풍 군주 새 몸(변신 무적 · 폼 부품 · 2폼 주먹) ───────────────────────────
do
	local BossRules = MODS.BossRules
	local walk = MODS.WorldConfig.playerWalkSpeedStuds
	local d = BossRules.buildInstanceData(15, "storm_lord", 1)
	local e, edge = BossFramework.applyBodyEdge(d, "storm_lord_v2", walk)
	local g = BossFramework.applyV3(e, "storm_lord_v2")
	local rig = BossRigSpec.rigs.storm_lord_v2
	local set = MODS.BossClipSet.get("storm_lord_v2")
	local parts = {}
	for _, j in ipairs(rig.joints) do
		parts[j.part] = true
	end
	local missing = {}
	for _, list in pairs(set.formParts) do
		for _, n in ipairs(list) do
			if not parts[n] then
				table.insert(missing, n)
			end
		end
	end
	for id, list in pairs(set.forms.after.flash) do
		for _, n in ipairs(list) do
			if not parts[n] then
				table.insert(missing, "flash:" .. id .. ":" .. n)
			end
		end
	end
	check("폭풍 폼 부품 · 2폼 번쩍 부위 = 리그에 있음", #missing == 0, ("1폼 숨김 %d · 2폼 숨김 %d · 빠짐 %s"):format(#set.formParts.before, #set.formParts.after, #missing == 0 and "0" or table.concat(missing, ",")))
	local tg = g.v3 and g.v3.transformGuard
	-- BOSS-NIGHT-2 2-2(사용자: 아이언맨식 · 무적 3.5초): 변신 동작 ≤ 무적 · 조립(마지막 부품 · 번개 폭발)은 돌풍(50% + 3초) 전에 끝 · 부품 순서 건틀릿 L → R → 어깨 → 코어 → 왕관 → 날개
	local A = set.transform.assemble
	local order = {}
	for _, step in ipairs(A and A.steps or {}) do
		table.insert(order, step.wings and "wings" or table.concat(step.parts, "+"))
	end
	local lastAt = A and A.steps[#A.steps].at or math.huge
	check("폭풍 50% 변신 무적 3.5초 · 조립(폭발) < 돌풍 시작 · 부품 순서", tg ~= nil and tg.seconds == 3.5 and tg.hpBelow == 0.5 and set.transform.seconds <= tg.seconds + 1e-6
		and A and A.burst < d.environment.firstDelaySeconds and lastAt <= A.burst and table.concat(order, ">") == "Gauntlet_L>Gauntlet_R>Pauldron2_L+Pauldron2_R>ChestCore>Crown>wings",
		tg and ("무적 %.1f초 · 변신 동작 %.1f초 · 폭발 %.2f초 · 돌풍 첫 지연 %.1f초 · %s"):format(tg.seconds, set.transform.seconds, A and A.burst or -1, d.environment.firstDelaySeconds, table.concat(order, " > ")) or "없음")
	check("폭풍 근접 바닥 표시 끔 · 예비 +0.12 · 원거리 스킬 그대로", g.skills.swipe.noFloor == true and g.skills.innerSmash.noFloor == true and g.basicNoFloor and g.innerRingHidden
		and math.abs(g.skills.swipe.telegraphSeconds - (d.skills.swipe.telegraphSeconds + 0.12)) < 1e-6 and g.skills.strike.telegraphSeconds == d.skills.strike.telegraphSeconds,
		("강화 평타 %.2f → %.2f · 몸 가장자리 +%.2f"):format(d.skills.swipe.telegraphSeconds, g.skills.swipe.telegraphSeconds, edge))
	check("폭풍 크기(키 약 31 stud)", math.abs(7.2 * 3.75 * rig.scale - 31) < 1.5, ("키 %.1f stud(K 7.2 × S 3.75 × %.2f)"):format(7.2 * 3.75 * rig.scale, rig.scale))
end

-- ─────────────────────────── BOSS-NIGHT-1 4: 수정 나비 여왕 새 몸(떠 있기 · 닫힌 종 치마 §8 · 근접 표시) ───────────────────────────
do
	local BossRules = MODS.BossRules
	local walk = MODS.WorldConfig.playerWalkSpeedStuds
	local d = BossRules.buildInstanceData(15, "crystal_queen", 1)
	local e, edge = BossFramework.applyBodyEdge(d, "crystal_queen_v2", walk)
	local g = BossFramework.applyV3(e, "crystal_queen_v2")
	local rig = BossRigSpec.rigs.crystal_queen_v2
	local set = MODS.BossClipSet.get("crystal_queen_v2")
	-- BOSS-NIGHT-2 3(사용자: 근접은 느리고 피할 만하게): 예비 +0.12 → +0.4 · 폭발도 · 마법 미사일(5발 · 첫 명중 고정 추적 · 18 stud 밖 가장 먼 한 명)
	local mm = g.skills.magicMissiles
	check("수정 근접 = 바닥 예고 보임 · 예비 +0.4(강화 평타 · 폭발) · 근접 평타 없음 · 마법 미사일(5발 · 대상 규칙 · 대시 통과 · 마지막 발 경직)", not g.skills.swipe.noFloor and not g.basicNoFloor and g.innerRingHidden and not g.skills.burst.noFloor
		and math.abs(g.skills.swipe.telegraphSeconds - (d.skills.swipe.telegraphSeconds + 0.4)) < 1e-6 and math.abs(g.skills.burst.telegraphSeconds - (d.skills.burst.telegraphSeconds + 0.4)) < 1e-6
		and g.skills.energyBeam.telegraphSeconds == d.skills.energyBeam.telegraphSeconds and g.basicDisabled == true
		and mm and mm.count == 5 and mm.targetRule == "missileTarget" and mm.preferBeyondStuds == 12 and mm.lockOnFirstHit and mm.passThrough == "dash" and mm.lastOnHit and mm.telegraphSeconds == 0.6
		and table.find(g.reactiveOrder or {}, "magicMissiles") ~= nil and BossMotion.clipNameForSkill("crystal_queen_v2", rig, "magicMissiles", mm, "after") == "q_missile",
		("강화 평타 %.2f → %.2f · 폭발 %.2f → %.2f · 미사일 %s발 × %.2f · 간격 %.2f · 속도 %s · 몸 가장자리 +%.2f"):format(d.skills.swipe.telegraphSeconds, g.skills.swipe.telegraphSeconds,
			d.skills.burst.telegraphSeconds, g.skills.burst.telegraphSeconds, tostring(mm and mm.count), mm and mm.damage.multiplier or 0, mm and mm.launchIntervalSeconds or 0, tostring(mm and mm.speedStuds), edge))
	local S = d.sizeScale
	local h = 7.0 * S * rig.scale
	check("수정 크기(키 약 29 stud) · 두 폼 떠 있기", math.abs(h - 29) < 1.5 and set.forms.before.gait == "hover" and set.forms.after.gait == "hover", ("키 %.1f stud(K 7.0 × S %.2f × %.2f)"):format(h, S, rig.scale))
	-- §8: 닫힌 종 치마(허리 → 발목 위) - 판정 사본 아님 · 발목(0.05 H) 근처까지 덮음 · 다리(허벅지 · 정강이)가 치마 상자 안
	local skirt, legsIn = nil, true
	for _, j in ipairs(rig.joints) do
		if j.part == "Skirt" then
			skirt = j
		end
	end
	check("수정 §8 닫힌 종 치마(허리 → 발목 위 · 판정 아님)", skirt ~= nil and not skirt.query and skirt.size.Y >= 7.0 * 0.45, skirt and ("치마 높이 %.2f(키 7.0의 %.0f%%)"):format(skirt.size.Y, skirt.size.Y / 7.0 * 100) or "없음")
end

-- ─────────────────────────── BOSS-NIGHT-2 1: 전갈 여왕 새 몸(다리 4쌍 1·3 / 2·4 교대 · 크기 24 · 근접 표시 · 색조 노브) ───────────────────────────
do
	local BossRules = MODS.BossRules
	local BossMotion = MODS.BossMotion
	local walk = MODS.WorldConfig.playerWalkSpeedStuds
	local d = BossRules.buildInstanceData(20, "scorpion_queen", 1)
	local e, edge = BossFramework.applyBodyEdge(d, "scorpion_queen_v2", walk)
	local g = BossFramework.applyV3(e, "scorpion_queen_v2")
	local rig = BossRigSpec.rigs.scorpion_queen_v2
	local set = MODS.BossClipSet.get("scorpion_queen_v2")
	local S = d.sizeScale
	local h = 4.4 * S * rig.scale
	local nLegs = 0
	for _, j in ipairs(rig.joints) do
		if j.name:match("^Hip%d_[LR]$") then
			nLegs += 1
		end
	end
	check("전갈 크기(높이 약 24 stud) · 다리 8개(4쌍) · hexapod", math.abs(h - 24) < 1 and nLegs == 8 and set.forms.before.gait == "hexapod", ("높이 %.1f stud(K 4.4 × S %.2f × %.2f) · 다리 %d"):format(h, S, rig.scale, nLegs))
	check("전갈 근접 바닥 표시 끔 · 예비 +0.12 · 집게 강타 · 독침(멀리 닿음) 바닥 표시 유지", g.skills.clawSweep.noFloor == true and g.skills.swipe.noFloor == true and g.basicNoFloor and not g.skills.claw.noFloor and not g.skills.sting.noFloor
		and math.abs(g.skills.clawSweep.telegraphSeconds - (d.skills.clawSweep.telegraphSeconds + 0.12)) < 1e-6, ("두 집게 휩쓸기 %.2f → %.2f · 몸 가장자리 +%.2f"):format(d.skills.clawSweep.telegraphSeconds, g.skills.clawSweep.telegraphSeconds, edge))
	-- 걸음: 같은 순간 들린 발 = 왼 1 · 3 + 오른 2 · 4(또는 반대) · 들린 발은 바닥 위(발이 땅으로 파고들지 않음)
	local ctx = BossMotion.context("scorpion_queen_v2", rig, g.skills, g.moveSpeedStuds)
	local rest = BossMotion.prepare(rig)
	local half = {}
	for _, j in ipairs(rig.joints) do
		half[j.part] = j.size.Y / 2
	end
	local okGroup, lowest, liftMax = true, math.huge, 0
	for _, gait in ipairs({ 0.1, 0.6 }) do -- 들림 최고점(gaitLeg 종 모양 - 0.25 · 0.75 = 딛는 순간)
		local pose = BossMotion.evaluate(ctx, { form = "before", inCombat = false, speed = 3, gait = gait }, 1.0)
		local frames = BossRig.solve(rig, CFrame.identity, 1, BossMotion.toTransforms(rest, 1, pose))
		local up = {}
		for k = 1, 4 do
			for _, side in ipairs({ "L", "R" }) do
				local key = ("Shin%d_%s"):format(k, side)
				local y = (frames[key] * CFrame.new(0, -half[key], 0)).Position.Y
				up[k .. side] = y > -1.5 + 0.05
				lowest = math.min(lowest, y)
				liftMax = math.max(liftMax, y + 1.5)
			end
		end
		local a = up["1L"] and up["3L"] and up["2R"] and up["4R"] and not (up["1R"] or up["3R"] or up["2L"] or up["4L"])
		local b = up["1R"] and up["3R"] and up["2L"] and up["4L"] and not (up["1L"] or up["3L"] or up["2R"] or up["4R"])
		okGroup = okGroup and (a or b)
	end
	check("전갈 걸음 1·3 / 2·4 교대 · 들린 발 바닥 위", okGroup and lowest > -1.5 - 0.15 and liftMax > 0.1, ("가장 낮은 발 %.2f · 최대 들림 %.2f 단위"):format(lowest, liftMax))
	local tint = Frame.atlasTint["bosses/scorpion_queen_v2m"]
	check("전갈 색조 노브(기본 0 = 원본 · 1 = sand 변형 아틀라스 등록)", tint and tint.value == 0 and tint.variants[1] == "sand" and MODS.ArtAssetIds and MODS.ArtAssetIds["bosses/scorpion_queen_v2m_atlas1_sand"] ~= nil or (tint and tint.value == 0 and not MODS.ArtAssetIds),
		("value %s · variants %s"):format(tostring(tint and tint.value), tint and table.concat(tint.variants, ",") or "-"))
end

-- ─────────────────────────── BOSS-NIGHT-2 3 발생 지점(shared/BossOrigin · data/BossOriginData): 표에 있는 스킬 = 부위 자리 · 예외 = nil(몸 중심) · 크기 배율 비례 ───────────────────────────
do
	local BossOrigin = MODS.BossOrigin
	local origin = Vector3.new(0, 0, 0)
	local target = Vector3.new(0, 0, -50) -- 대상 = -Z(앞)
	local rows, ok = {}, true
	for _, e in ipairs({ { "section_guardian_v2", "heavy" }, { "section_guardian_v2", "shockwave" }, { "frost_giant_v2", "slam" }, { "storm_lord_v2", "thunderRing" }, { "abyssal_lord_v2", "tide" },
		{ "crystal_queen_v2", "magicMissiles" }, { "scorpion_queen_v2", "claw" } }) do
		local p1 = BossOrigin.point(e[1], 1, 1, e[2], origin, target, 0)
		local p2 = BossOrigin.point(e[1], 2, 1, e[2], origin, target, 0)
		local good = p1 ~= nil and p2 ~= nil and math.abs((p2 - Vector3.new(0, p2.Y, 0)).Magnitude - 2 * (p1 - Vector3.new(0, p1.Y, 0)).Magnitude) < 1e-3
		ok = ok and good
		table.insert(rows, ("%s/%s %.1f"):format(e[1]:gsub("_v2", ""), e[2], p1 and Vector3.new(p1.X, 0, p1.Z).Magnitude or -1))
	end
	local exc = BossOrigin.point("section_guardian_v2", 1, 1, "innerSmash", origin, target, 0) == nil and BossOrigin.point("crystal_queen_v2", 1, 1, "burst", origin, target, 0) == nil
		and BossOrigin.point("abyssal_lord_v2", 1, 1, "sweep", origin, target, 0) == nil
	local front = BossOrigin.point("section_guardian_v2", 1, 1, "heavy", origin, target, 0)
	check("발생 지점 표(접촉 부위 · 크기 배율 비례 · 예외 = 몸 중심 · 앞 = 대상 쪽)", ok and exc and front and front.Z < 0, table.concat(rows, " · "))
end

print(("[FRAME] 끝 %d/%d"):format(pass, total))
