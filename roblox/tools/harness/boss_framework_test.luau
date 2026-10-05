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
	local sk = data.skills.heavy
	local hitAt = 0.3 + sk.telegraphSeconds
	local _, iBefore = BossMotion.evaluate(ctx, { form = "before", inCombat = true, act = "heavy", actAt = 0.3, actHit = sk.telegraphSeconds }, hitAt - 0.2)
	local _, iIn = BossMotion.evaluate(ctx, { form = "before", inCombat = true, act = "heavy", actAt = 0.3, actHit = sk.telegraphSeconds }, hitAt - 0.05)
	local _, iAfter = BossMotion.evaluate(ctx, { form = "before", inCombat = true, act = "heavy", actAt = 0.3, actHit = sk.telegraphSeconds }, hitAt + 0.01)
	check("번쩍 창 " .. key, iBefore.rim == nil and iIn.rim ~= nil and iAfter.rim == nil, ("판정 −0.20 %s · −0.05 %s(%s) · +0.01 %s"):format(tostring(iBefore.rim ~= nil), tostring(iIn.rim ~= nil), iIn.rim and table.concat(iIn.rim, "/") or "-", tostring(iAfter.rim ~= nil)))

	-- 2-5 변신: switchAt 전 = before · 뒤 = after
	local _, a = BossMotion.evaluate(ctx, { transformAt = 0, inCombat = true }, T.switchAt - 0.05)
	local _, b = BossMotion.evaluate(ctx, { transformAt = 0, inCombat = true }, T.switchAt + 0.05)
	check("변신 세트 교체 " .. key, a.form == "before" and b.form == "after" and a.transforming and b.transforming, ("%.2f초 전 %s · 뒤 %s"):format(T.switchAt, tostring(a.form), tostring(b.form)))

	-- 2-6 비용(오프라인 - luau CLI · 상대 비교만): 프레임당 evaluate + FK(접지용) 평균 μs - 옛 몸 같은 보스와 비교
	local function cost(c, r, st, n)
		local rr = BossMotion.prepare(r)
		local t0 = os.clock()
		for i = 1, n do
			local pose = BossMotion.evaluate(c, st, i / 60)
			BossRig.solve(r, CFrame.identity, 1, BossMotion.toTransforms(rr, 1, pose))
		end
		return (os.clock() - t0) / n * 1e6
	end
	local oldRig = BossRigSpec.rigs[rig.bossId]
	local oldCtx = BossMotion.context(rig.bossId, oldRig, data.skills, data.moveSpeedStuds)
	local stWalk = { inCombat = true, speed = 6, gait = 0.3, act = "heavy", actAt = 0, actHit = 2 }
	local cOld = cost(oldCtx, oldRig, stWalk, 3000)
	local cNew = cost(ctx, rig, stWalk, 3000)
	check("모션 비용(오프라인) " .. key, cNew <= cOld * 1.5, ("옛 %.1fμs → 새 %.1fμs(× %.2f · 합격 ≤ × 1.5)"):format(cOld, cNew, cNew / cOld))
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
		if id ~= "section_guardian" then
			if out == d and edge == 0 then
				same += 1
			end
		end
	end
	check("몸 가장자리 장치 - 다른 5보스 값 변화 0", same == #ids - 1, ("%d / %d(표에 없음 = 사본도 안 만듦)"):format(same, #ids - 1))
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
		if BossFramework.applyV3(d, id ~= "section_guardian" and (id .. "_v2") or nil) == d then
			same += 1
		end
	end
	check("V3 - 다른 5보스 · 옛 몸 수호자 값 변화 0", same == #ids, ("%d / %d"):format(same, #ids))
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
	local lOk = l and l.reactive and l.telegraphSeconds == 0.9 and l.lockSeconds == 0.3 and l.flightSeconds == 0.8 and l.maxLeapStuds == 60 and math.abs(l.radiusStuds - (half + 12)) < 1e-6
		and l.conditions[1].count == 2 and l.conditions[1].seconds == 12 and l.onHit[1].type == "launch"
	-- 도약 회피: 착지 원은 준비 시작부터 보이고 대상을 따라온다 → 인지(perception)는 고정 전 표시 시간(준비 − 고정 0.6초) 안에 끝난다.
	--   고정(끝 0.3초) + 비행 0.8 = 1.1초 안에 대상 자리(몸 끝)에서 원 밖으로 = (반경 − 몸 반폭 + 캐릭터 반폭) ÷ 걷기 × 여유 계수
	local dodge = BossData.mechanics.dodge
	local seen = l.telegraphSeconds - l.lockSeconds
	local need = (l.radiusStuds - l.landShortStuds + dodge.characterHalfWidthStuds) / walk * dodge.marginFactor
	local have = l.lockSeconds + l.flightSeconds
	check("V3 도약(빗나감 2회/12초 · 준비 0.9 · 고정 0.3 · 비행 0.8 · 60 stud · 반경 몸 + 12 · 넉백) + 걸어서 회피", lOk == true and have >= need and seen >= dodge.perceptionSeconds,
		l and ("반경 %.2f(= %.2f + 12) · 고정 전 표시 %.2f초 ≥ 인지 %.2f · 고정 뒤 걷기 %.2f초 ≤ %.2f초(여유 %.2f)"):format(l.radiusStuds, half, seen, dodge.perceptionSeconds, need, have, have - need) or "없음")
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

print(("[FRAME] 끝 %d/%d"):format(pass, total))
