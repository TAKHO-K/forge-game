-- BR1-4b 보스 모션 계산(순수 함수 - 클라 client/BossAnimator가 매 프레임 · 서버가 잡힌 사람을 부착점에 둘 때 FK로 같은 식). 데이터 = shared/data/BossMotionData.
-- 입력 st(서버 시각 기준 초): speed(stud/s) · gait(걸음 위상 - 이동 거리 ÷ 보폭으로 진행 = 발 미끄러짐 없음) · turn(rad/s) · lookYaw(도 - 없으면 두리번) ·
--   act · actAt · actHit · actEndAt(스킬 - 서버 BossAct*) · env · envAt · envHit · swingAt · swingN · pickAt · throwPlan · throwAt · stunAt · stunUntil · flinchAt · deadAt.
-- 출력: pose[관절] = { rx, ry, rz, px, py, pz }(부모 축 · 도 · 단위) + info { flash(번쩍일 부위 이름) · eyes(눈 회전) }. toTransforms가 Motor6D.Transform으로 바꾼다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local D = require(ReplicatedStorage.Shared.data.BossMotionData)

local BossMotion = {}

local TAU = math.pi * 2

local function clamp01(x)
	return x < 0 and 0 or (x > 1 and 1 or x)
end

-- 이징(직선 보간 없음)
local function ease(kind, t)
	t = clamp01(t)
	if kind == "in" then
		return t * t * t
	elseif kind == "out" then
		return 1 - (1 - t) ^ 3
	elseif kind == "back" then
		local c = 1.6
		return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
	end
	return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 -- inout
end
BossMotion.ease = ease

local function val(v, i)
	return v and v[i] or 0
end

-- out = out + (layer − out) × w(덮기) · 관절별 가중치 mask(선택)
local function blend(out, layer, w, filter)
	if w <= 0 then
		return
	end
	for joint, v in pairs(layer) do
		if not filter or filter(joint) then
			local o = out[joint]
			if not o then
				o = { 0, 0, 0, 0, 0, 0 }
				out[joint] = o
			end
			for i = 1, 6 do
				o[i] += (val(v, i) - o[i]) * w
			end
		end
	end
end

local function add(out, layer, w)
	if w == 0 then
		return
	end
	for joint, v in pairs(layer) do
		local o = out[joint]
		if not o then
			o = { 0, 0, 0, 0, 0, 0 }
			out[joint] = o
		end
		for i = 1, 6 do
			o[i] += val(v, i) * w
		end
	end
end

local function addTo(out, joint, i, amount)
	local o = out[joint]
	if not o then
		o = { 0, 0, 0, 0, 0, 0 }
		out[joint] = o
	end
	o[i] += amount
end

local function lerpPose(a, b, t)
	local out = {}
	for joint, v in pairs(a) do
		local w = b[joint]
		out[joint] = { val(v, 1) + (val(w, 1) - val(v, 1)) * t, val(v, 2) + (val(w, 2) - val(v, 2)) * t, val(v, 3) + (val(w, 3) - val(v, 3)) * t,
			val(v, 4) + (val(w, 4) - val(v, 4)) * t, val(v, 5) + (val(w, 5) - val(v, 5)) * t, val(v, 6) + (val(w, 6) - val(v, 6)) * t }
	end
	for joint, w in pairs(b) do
		if not a[joint] then
			out[joint] = { val(w, 1) * t, val(w, 2) * t, val(w, 3) * t, val(w, 4) * t, val(w, 5) * t, val(w, 6) * t }
		end
	end
	return out
end

local function isLeg(joint)
	return joint == "RootJoint" or joint:find("^Hip") ~= nil or joint:find("^Knee") ~= nil or joint:find("^Ankle") ~= nil
end
local function isUpper(joint)
	return not isLeg(joint)
end

-- 보스의 plan 표 · 동작 찾기
function BossMotion.planOf(rigId, rig)
	return D[rig.plan] or D.biped
end
function BossMotion.clip(rigId, rig, name)
	local own = D.bossClips[rigId]
	return (own and own[name]) or BossMotion.planOf(rigId, rig).clips[name]
end
-- 스킬 id → 동작 이름(보스 표 → primitive 기본표 → 없음)
function BossMotion.clipNameForSkill(rigId, rig, skillId, skill)
	local boss = D.bosses[rigId]
	local name = boss and boss.skills[skillId]
	if name then
		return name
	end
	local defaults = D.defaults[rig.plan] or D.defaults.biped
	return skill and defaults[skill.primitive] or nil
end

-- 동작 표본: clip을 시작 뒤 tRel초(때리는 순간 = hit초)에서. 반환 = pose, 끝 시각(tRel 기준 - 되풀이면 nil), info
function BossMotion.sampleClip(clip, tRel, hit, weight)
	weight = weight or 1
	local hitstop = (clip.hitstop or 0) * weight
	local t = tRel
	if hitstop > 0 and t > hit then
		t = t < hit + hitstop and hit or t - hitstop
	end
	local keys = {}
	for _, k in ipairs(clip.pre or {}) do
		table.insert(keys, { t = k.f * hit, pose = k.pose, ease = k.ease })
	end
	for _, k in ipairs(clip.post or {}) do
		table.insert(keys, { t = hit + k.s, pose = k.pose, ease = k.ease })
	end
	local pose
	local lastT = #keys > 0 and keys[#keys].t or hit
	if #keys == 0 then
		pose = {}
	elseif t <= keys[1].t then
		pose = keys[1].pose
		if keys[1].t > 0 then -- 첫 키까지는 시작 자세(빈 자세 = 바탕)에서 이징으로
			pose = lerpPose({}, keys[1].pose, ease(keys[1].ease, t / keys[1].t))
		end
	elseif t >= lastT then
		pose = keys[#keys].pose
		if clip.loop then
			local L = clip.loop
			local u = (t - lastT) / L.period
			local n = #L.poses
			local i = math.floor(u) % n
			local loopPose = lerpPose(L.poses[i + 1], L.poses[(i + 1) % n + 1], ease("inout", u - math.floor(u)))
			pose = lerpPose(pose, loopPose, ease("inout", (t - lastT) / 0.2))
		end
	else
		for i = 1, #keys - 1 do
			local a, b = keys[i], keys[i + 1]
			if t >= a.t and t < b.t then
				pose = lerpPose(a.pose, b.pose, ease(b.ease, (t - a.t) / math.max(b.t - a.t, 1e-3)))
				break
			end
		end
		pose = pose or keys[#keys].pose
	end
	local info = {}
	-- 떨림(강화 평타 전조 끝 - 팔을 휘두를 듯) + 번쩍
	if clip.tremble and hit > 0 and tRel >= clip.tremble.from * hit and tRel < hit then
		local ramp = clamp01((tRel - clip.tremble.from * hit) / math.max(hit * (1 - clip.tremble.from), 1e-3))
		local copy = lerpPose(pose, {}, 0)
		for _, joint in ipairs(clip.tremble.joints) do
			addTo(copy, joint, 1, math.sin(tRel * TAU * 17) * clip.tremble.amp * ramp)
			addTo(copy, joint, 3, math.cos(tRel * TAU * 13) * clip.tremble.amp * 0.6 * ramp)
		end
		pose = copy
		info.flash = clip.flash
		info.flashAmount = ramp * (0.5 + 0.5 * math.sin(tRel * TAU * 6))
	end
	-- 몸 눌림(무게감) · 제자리 돌기
	if (clip.squash or clip.spin or clip.spinPre) then
		local copy = lerpPose(pose, {}, 0)
		if clip.squash and tRel >= hit and tRel < hit + hitstop + 0.3 then
			addTo(copy, "RootJoint", 5, -clip.squash * weight * math.sin(math.pi * clamp01((tRel - hit) / (hitstop + 0.3))))
		end
		if clip.spin and tRel > hit then
			addTo(copy, "RootJoint", 2, (clip.spin * (tRel - hit)) % 360)
		end
		if clip.spinPre and hit > 0 and tRel < hit then
			addTo(copy, "RootJoint", 2, clip.spinPre * ease("inout", tRel / hit))
		end
		pose = copy
	end
	return pose, (not clip.loop) and (lastT + hitstop) or nil, info
end

-- 결정적 두리번(서버 · 클라 같은 값): 창 k마다 무작위 목표 각
local function lookTarget(k, yawDeg)
	local x = math.sin(k * 12.9898 + 78.233) * 43758.5453
	return ((x - math.floor(x)) * 2 - 1) * yawDeg
end
local function idleLook(L, now)
	local k = math.floor(now / L.everySeconds)
	local since = now - k * L.everySeconds
	local from, to = lookTarget(k - 1, L.yawDeg), lookTarget(k, L.yawDeg)
	local neck = from + (to - from) * ease("inout", since * L.neckSpeed / 3)
	local body = from + (to - from) * ease("inout", since * L.bodySpeed / 3)
	return neck, body * L.bodyFollow
end

-- ─────────────────────────── 바탕(대기 · 걷기) ───────────────────────────
-- 한 다리의 걸음(위상 u · 0 ~ 1): 딛는 구간(u 0.25 ~ 0.75) = 발이 **일정 속도로** 뒤로(땅에서 안 미끄러짐 - 발 앞뒤 자리 = reach × sin θ가 선형) ·
-- 흔드는 구간 = 이징으로 앞으로 + 들기(bell 0 → 1 → 0). 반환: 각(도), bell.
local function gaitLeg(u, halfStride, reach)
	u = u % 1
	local d, bell
	if u >= 0.25 and u < 0.75 then
		d, bell = halfStride * (1 - 2 * (u - 0.25) / 0.5), 0
	else
		local f = ((u + 0.25) % 1) / 0.5
		d, bell = -halfStride + 2 * halfStride * ease("inout", f), math.sin(math.pi * f)
	end
	return math.deg(math.asin(math.clamp(d / reach, -0.95, 0.95))), bell
end
local function baseBiped(ctx, st, now, pose)
	local P = ctx.plan
	local I = P.idle
	local b = math.sin(TAU * now / I.breath.period)
	local w = math.sin(TAU * now / I.sway.period)
	blend(pose, {
		Waist = { I.breath.waist * b, 0, 0 },
		Shoulder_R = { 0, 0, I.breath.shoulder * (b + 1) * 0.5 }, Shoulder_L = { 0, 0, -I.breath.shoulder * (b + 1) * 0.5 },
		RootJoint = { 0, 0, I.sway.roll * w, I.sway.shift * w, I.breath.lift * b, 0 },
		Hip_L = { 0, 0, -I.sway.roll * w }, Hip_R = { 0, 0, -I.sway.roll * w },
		Elbow_R = { 6, 0, 0 }, Elbow_L = { 6, 0, 0 },
	}, 1)
	-- 걷기 · 달리기
	local W = ctx.walk
	local walkW = clamp01((st.speed or 0) / 2)
	if walkW > 0 then
		local legLen = ctx.legLen or 1.6
		local run = clamp01(((st.speed or 0) / math.max(ctx.moveSpeed or 8, 1) - 1) / math.max(W.runAt - 1, 0.1))
		local s = math.sin(TAU * (st.gait or 0))
		local knee = W.knee * (1 + 0.6 * run)
		local aL, bL = gaitLeg(st.gait or 0, W.stride / 2, legLen)
		local aR, bR = gaitLeg((st.gait or 0) + 0.5, W.stride / 2, legLen)
		blend(pose, {
			-- 흔드는 다리는 엉덩이도 더 굽혀 발을 든다(bell) - 딛는 다리는 곧게 뒤로 민다
			Hip_L = { aL + 0.45 * knee * bL, 0, 0 }, Hip_R = { aR + 0.45 * knee * bR, 0, 0 },
			Knee_L = { -knee * bL, 0, 0 }, Knee_R = { -knee * bR, 0, 0 },
			Ankle_L = { 0.25 * knee * bL - 0.3 * aL, 0, 0 }, Ankle_R = { 0.25 * knee * bR - 0.3 * aR, 0, 0 },
			RootJoint = { 0, 0, 0, 0, -W.bob * s * s - 0.12 * run, 0 },
			Waist = { -W.lean * run - 2, W.twist * s, 0 },
			Shoulder_L = { -W.arm * (1 + run) * s, 0, -4 }, Shoulder_R = { W.arm * (1 + run) * s, 0, 4 },
			Elbow_L = { 12 + 30 * run, 0, 0 }, Elbow_R = { 12 + 30 * run, 0, 0 },
		}, walkW)
	end
	return W
end

local function baseScorpion(ctx, st, now, pose)
	local P = ctx.plan
	local I = P.idle
	local b = math.sin(TAU * now / I.breath.period)
	blend(pose, {
		RootJoint = { 0, 0, 0, 0, I.breath.lift * b, 0 },
		Pincer_R = { 0, 0, 12 + I.breath.claw * b }, Pincer_L = { 0, 0, -12 - I.breath.claw * b },
		Shoulder_R = { 3 * b, 0, 0 }, Shoulder_L = { 3 * b, 0, 0 },
	}, 1)
	local W = ctx.walk
	local walkW = clamp01((st.speed or 0) / 2)
	if walkW > 0 then
		local legs = {}
		for k = 1, 3 do
			for _, side in ipairs({ "L", "R" }) do
				local x = side == "R" and 1 or -1
				local key = ("%d_%s"):format(k, side)
				local phase = (st.gait or 0) + (table.find(W.groupA, key) and 0 or 0.5)
				local a, bell = gaitLeg(phase, W.stride / 2, ctx.legReach or 1.3)
				legs["Hip" .. key] = { 0, x * a, x * W.lift * bell }
				legs["Knee" .. key] = { 0, 0, -x * W.lift * 0.5 * bell }
			end
		end
		legs.RootJoint = { 0, 0, 0, 0, -W.bob * math.abs(math.sin(TAU * 2 * (st.gait or 0))), 0 }
		blend(pose, legs, walkW)
	end
	return W
end

-- 사슬 흔들림(꼬리 · 망토 · 수염 · 치마 - 결정적 sine · 사슬마다 위상이 다르다). 클라가 여기에 스프링 여운을 더한다.
local function chainSway(ctx, now, pose)
	for ci, chain in ipairs(ctx.rig.chains or {}) do
		local phase = chain.phase or ci * 1.3
		local period = (ctx.plan.idle.tail and ctx.plan.idle.tail.period) or 3
		local travel = (ctx.plan.idle.tail and ctx.plan.idle.tail.travel) or 0.6
		for i, joint in ipairs(chain) do
			local a = TAU * now / period + phase - i * travel
			addTo(pose, joint, 2, (chain.sway or 4) * math.sin(a) * (0.5 + 0.5 * i / #chain))
			if ctx.plan.idle.tail then
				addTo(pose, joint, 1, ctx.plan.idle.tail.curl * math.sin(a * 0.7 + 1))
			end
		end
	end
end

-- ─────────────────────────── 한 프레임 ───────────────────────────
-- ctx = { rig, rigId, plan(D.biped | D.scorpion), boss(D.bosses[rigId]), legLen, moveSpeed, weight, skills(BossData 인스턴스 스킬표 - 없으면 표만) }
function BossMotion.evaluate(ctx, st, now)
	local pose, info = {}, {}
	local P = ctx.plan
	local weight = ctx.weight or 1
	local W = (ctx.rig.plan == "scorpion" and baseScorpion or baseBiped)(ctx, st, now, pose)

	-- 두리번(머리가 먼저 → 몸이 따라감) · 방향 전환 때 몸을 먼저 기울임
	local neckYaw, bodyYaw
	if st.lookYaw then
		neckYaw, bodyYaw = st.lookYaw, st.lookYaw * P.idle.look.bodyFollow
	else
		neckYaw, bodyYaw = idleLook(P.idle.look, now)
	end
	addTo(pose, "Neck", 2, math.clamp(neckYaw - bodyYaw, -55, 55))
	addTo(pose, ctx.rig.plan == "scorpion" and "RootJoint" or "Waist", 2, bodyYaw)
	addTo(pose, "RootJoint", 3, math.clamp(-(st.turn or 0) * (W.turnLean or 6), -12, 12))

	-- 전투 준비 자세(평타 뒤 4초 · 스킬 중)
	local combat = st.swingAt and clamp01(1 - (now - st.swingAt - 3) / 1) or 0
	if combat > 0 and P.guard then
		blend(pose, P.guard, combat * 0.85, (st.speed or 0) > 1 and isUpper or nil)
	end
	-- 평타(좌우 번갈아)
	if st.swingAt and now - st.swingAt < 1.0 then
		local clip = P.clips[(st.swingN or 0) % 2 == 0 and "basic_R" or "basic_L"]
		local p, endT = BossMotion.sampleClip(clip, now - st.swingAt, 0, weight)
		local w = ease("out", (now - st.swingAt) / 0.05) * (1 - ease("inout", (now - st.swingAt - (endT or 0.6)) / 0.3))
		blend(pose, p, w, (st.speed or 0) > 1 and isUpper or nil)
	end

	-- 환경 변화(두 번째 시계)와 스킬: 동작 층
	local function actLayer(name, at, hit, endAt, upperOnly)
		local clip = name and BossMotion.clip(ctx.rigId, ctx.rig, name)
		if not clip or not at then
			return 0
		end
		local tRel = now - at
		local p, endT, cinfo = BossMotion.sampleClip(clip, tRel, hit or 0, weight)
		local w = ease("out", tRel / (clip.blendIn or 0.18))
		if endT then
			w *= 1 - ease("inout", (tRel - endT) / 0.3)
		end
		if endAt then
			w *= 1 - ease("inout", (now - endAt) / 0.3)
		end
		if w > 0 then
			local filter = ((clip.upper and tRel > (hit or 0)) or upperOnly) and isUpper or nil
			blend(pose, p, w, filter)
			if cinfo.flash then
				info.flash, info.flashAmount = cinfo.flash, cinfo.flashAmount * w
			end
		end
		return w
	end
	if st.env then
		actLayer(ctx.boss and ctx.boss.env or "cast", st.envAt, st.envHit, st.envEndAt)
	end
	if st.act then
		local skill = ctx.skills and ctx.skills[st.act]
		if skill and skill.primitive == "grab" then
			-- 대공 잡기: 전조 → (쫓기 = 달리며 팔 앞으로 | 들기) → 던지기
			local hit = st.actHit or 5
			local tRel = now - st.actAt
			if tRel < hit + 0.05 then
				actLayer("grab_tele", st.actAt, hit, st.actEndAt)
			elseif st.throwAt and now >= st.throwAt then
				-- 던진 뒤는 아래 층이 이어서 그린다(스킬이 던지는 순간 끝난다)
			elseif st.throwPlan and now >= st.throwPlan - P.throwWindup then
				actLayer(ctx.boss and ctx.boss.throw or "throw_overhead", st.throwPlan - P.throwWindup, P.throwWindup)
			elseif (st.speed or 0) > 2 then
				actLayer("grab_reach", st.actAt + hit, 0, st.actEndAt, true)
			else
				actLayer("grab_hold", st.actAt + hit, 0, st.actEndAt)
			end
		else
			actLayer(BossMotion.clipNameForSkill(ctx.rigId, ctx.rig, st.act, skill), st.actAt, st.actHit, st.actEndAt)
		end
	end
	-- 던진 순간부터 회복까지(스킬이 이미 끝났어도 - 전조와 같은 시간축)
	if st.throwAt and now >= st.throwAt and now - st.throwAt < 1.4 then
		actLayer(ctx.boss and ctx.boss.throw or "throw_overhead", st.throwAt - P.throwWindup, P.throwWindup)
	end
	-- 낚아챔(더하는 층 - 히트스톱 + 표정)
	if st.pickAt and now - st.pickAt < 0.7 then
		local p = BossMotion.sampleClip(P.clips.grab_snatch, now - st.pickAt, 0, weight)
		add(pose, p, 1)
	end

	-- 피격 움찔(작게)
	if st.flinchAt and now - st.flinchAt < P.flinch.seconds then
		add(pose, P.flinch.pose, math.sin(math.pi * (now - st.flinchAt) / P.flinch.seconds))
	end

	-- 사슬 흔들림(여운의 결정적 부분)
	chainSway(ctx, now, pose)

	-- 기절(비틀 → 주저앉음 → 일어남)
	if st.stunAt and st.stunUntil and now < st.stunUntil + 0.05 then
		local S = P.stun
		local t, dur = now - st.stunAt, math.max(st.stunUntil - st.stunAt, S.staggerSeconds + S.riseSeconds)
		local wob = S.wobble
		local target
		if t < S.staggerSeconds then
			target = lerpPose(S.stagger, S.stagger, 0)
		elseif t < dur - S.riseSeconds then
			target = lerpPose(S.stagger, S.sit, ease("inout", (t - S.staggerSeconds) / 0.45))
		else
			target = S.sit
		end
		target = lerpPose(target, target, 0)
		addTo(target, "Neck", 3, wob.neck * math.sin(TAU * wob.hz * t))
		addTo(target, "Neck", 1, wob.neck * 0.5 * math.cos(TAU * wob.hz * t))
		if wob.waist > 0 then
			addTo(target, "Waist", 3, wob.waist * math.sin(TAU * wob.hz * 0.5 * t))
		end
		local w = ease("out", t / 0.15)
		if t > dur - S.riseSeconds then
			w *= 1 - ease("inout", (t - (dur - S.riseSeconds)) / S.riseSeconds)
		end
		blend(pose, target, w)
		if w > 0.5 then
			info.eyes = S.eyes
		end
	end

	-- 사망(쓰러짐 - 모든 층 위)
	if st.deadAt then
		local Dd = P.death
		local t = now - st.deadAt
		local hitstop = t > Dd.hitstopAt and t < Dd.hitstopAt + 0.08 * weight
		local p = BossMotion.sampleClip({ post = Dd.keys }, hitstop and Dd.hitstopAt or (t > Dd.hitstopAt and t - 0.08 * weight or t), 0)
		blend(pose, p, ease("out", t / 0.12))
		info.eyes = Dd.eyes
		info.fade = clamp01((t - Dd.fadeFrom) / Dd.fadeSeconds)
	end
	return pose, info
end

-- 자세 → Motor6D.Transform(관절 이름 → CFrame). 각은 부모 축 기준 → 기준 자세 rot로 켤레 변환(T = R0⁻¹ · 자리 · 회전 · R0).
function BossMotion.prepare(rig)
	local rest = {}
	for _, j in ipairs(rig.joints) do
		local r = j.rot or Vector3.zero
		local R0 = CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
		rest[j.name] = { R0 = R0, R0inv = R0:Inverse() }
	end
	return rest
end

function BossMotion.transformOf(rest, S, joint, v)
	local r = rest[joint]
	if not r then
		return nil
	end
	local local_ = CFrame.new(val(v, 4) * S, val(v, 5) * S, val(v, 6) * S) * CFrame.Angles(math.rad(val(v, 1)), math.rad(val(v, 2)), math.rad(val(v, 3)))
	return r.R0inv * local_ * r.R0
end

function BossMotion.toTransforms(rest, S, pose)
	local out = {}
	for joint, v in pairs(pose) do
		local cf = BossMotion.transformOf(rest, S, joint, v)
		if cf then
			out[joint] = cf
		end
	end
	return out
end

-- 다리 길이(단위 - 걸음 보폭 → 엉덩이 흔들 각)
-- 전갈 다리: 엉덩이 관절에서 발끝까지 수평 반경(단위) - 걸음 각 = asin(발 앞뒤 자리 ÷ 반경)(gaitLeg - 발 미끄러짐 없음)
local function scorpionLegReach(rig)
	local ok, frames = pcall(function()
		local BossRig = require(ReplicatedStorage.Shared.BossRig)
		return BossRig.solve(rig, CFrame.identity, 1, {})
	end)
	if not ok or not frames.Thigh1_R or not frames.Shin1_R then
		return nil
	end
	local hip
	for _, j in ipairs(rig.joints) do
		if j.name == "Hip1_R" then
			hip = j.at
		end
	end
	local tip = (frames.Shin1_R * CFrame.new(0, -0.975, 0)).Position
	return hip and Vector3.new(tip.X - hip.X, 0, tip.Z - hip.Z).Magnitude or nil
end

function BossMotion.legLength(rig)
	local thigh, shin
	for _, j in ipairs(rig.joints) do
		if j.part == "Thigh_L" then
			thigh = j.size.Y
		elseif j.part == "Shin_L" then
			shin = j.size.Y
		end
	end
	return (thigh or 0.8) + (shin or 0.8)
end

-- 컨텍스트(보스 한 종 - 한 번 만들어 둔다)
function BossMotion.context(rigId, rig, skills, moveSpeed)
	local plan, boss = BossMotion.planOf(rigId, rig), D.bosses[rigId]
	local walk = {}
	for k, v in pairs(plan.walk) do
		walk[k] = v
	end
	for k, v in pairs(boss and boss.walk or {}) do
		walk[k] = v
	end
	local legReach = rig.plan == "scorpion" and scorpionLegReach(rig) or nil
	return {
		rig = rig, rigId = rigId, plan = plan, boss = boss, walk = walk, legLen = BossMotion.legLength(rig), legReach = legReach,
		moveSpeed = moveSpeed, weight = rig.weight or 1, skills = skills,
	}
end

return BossMotion
