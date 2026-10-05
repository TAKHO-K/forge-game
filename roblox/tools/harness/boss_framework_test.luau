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
				local ev, worst, part, t = run(function(tt)
					return { form = formName, inCombat = true, speed = 0, gait = 0, act = sid, actAt = 0.3, actHit = hit, actEndAt = (tt > 0.3 + hit + 2.2) and (0.3 + hit + 2.2) or nil }
				end, hit + 3.2, { { 0.3 + preEnd - 0.03, 0.3 + contact + hs + 0.25 } }) -- 의도된 타격 창 = boss_motion_test와 같음(휘두르기 시작 ~ 접촉 + 정지 + 0.25)
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

print(("[FRAME] 끝 %d/%d"):format(pass, total))
