-- BR1-4b 보스 모션 계산(순수 함수 - 클라 client/BossAnimator가 매 프레임 · 서버가 잡힌 사람을 부착점에 둘 때 FK로 같은 식). 데이터 = shared/data/BossMotionData.
-- 입력 st(서버 시각 기준 초): speed(stud/s) · gait(걸음 위상 - 이동 거리 ÷ 보폭으로 진행 = 발 미끄러짐 없음) · turn(rad/s) · lookYaw(도 - 없으면 두리번) ·
--   act · actAt · actHit · actEndAt(스킬 - 서버 BossAct*) · env · envAt · envHit · swingAt · swingN · pickAt · throwPlan · throwAt · stunAt · stunUntil · flinchAt · deadAt.
-- 출력: pose[관절] = { rx, ry, rz, px, py, pz }(부모 축 · 도 · 단위) + info { flash(번쩍일 부위 이름) · eyes(눈 회전) }. toTransforms가 Motor6D.Transform으로 바꾼다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local D = require(ReplicatedStorage.Shared.data.BossMotionData)
local Easing = require(ReplicatedStorage.Shared.Easing)

local BossMotion = {}

local TAU = math.pi * 2

local clamp01 = Easing.clamp01

-- 이징(직선 보간 없음) - A2-M1: 공용 shared/Easing(옛 in · out · inout · back 식 그대로 + strike · settle · sine …)
local ease = Easing.get
BossMotion.ease = ease

local function val(v, i)
	return v and v[i] or 0
end

-- 자세 값 = { rx, ry, rz, px, py, pz, [7] = 관절 가중치(없으면 1) }. A2-M1: 키 사이에 관절이 빠지거나 새로 들어올 때 값을 0(기준 자세)으로 끌고 가지 않고
--   **가중치**를 1 → 0(0 → 1)으로 줄인다 - 빠지는 순간 밑 층(두리번 · 호흡 · 준비 자세)이 한 프레임에 튀어나오던 문제(목 −13° 튐)를 없앤다.
local function jw(v)
	return v[7] or 1
end

-- out = out + (layer − out) × w × 관절 가중치(덮기) · 관절 필터(선택)
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
			local k = w * jw(v)
			for i = 1, 6 do
				o[i] += (val(v, i) - o[i]) * k
			end
		end
	end
end

-- 더하기 층: 없는 관절 = 0 기여 · 관절 가중치를 곱한다(옛 "0으로 보간"과 같은 값)
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
		local k = w * jw(v)
		for i = 1, 6 do
			o[i] += val(v, i) * k
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

-- only = 관절 이름 목록(선택 - 겹침 지연 표본처럼 몇 관절만 필요할 때: 그 관절만 계산한다)
local function lerpPose(a, b, t, only)
	local out = {}
	if only then
		for _, joint in ipairs(only) do
			local v, w = a[joint], b[joint]
			if v and w then
				out[joint] = { val(v, 1) + (val(w, 1) - val(v, 1)) * t, val(v, 2) + (val(w, 2) - val(v, 2)) * t, val(v, 3) + (val(w, 3) - val(v, 3)) * t,
					val(v, 4) + (val(w, 4) - val(v, 4)) * t, val(v, 5) + (val(w, 5) - val(v, 5)) * t, val(v, 6) + (val(w, 6) - val(v, 6)) * t, jw(v) + (jw(w) - jw(v)) * t }
			elseif v then
				out[joint] = { val(v, 1), val(v, 2), val(v, 3), val(v, 4), val(v, 5), val(v, 6), jw(v) * (1 - t) }
			elseif w then
				out[joint] = { val(w, 1), val(w, 2), val(w, 3), val(w, 4), val(w, 5), val(w, 6), jw(w) * t }
			end
		end
		return out
	end
	for joint, v in pairs(a) do
		local w = b[joint]
		if w then
			out[joint] = { val(v, 1) + (val(w, 1) - val(v, 1)) * t, val(v, 2) + (val(w, 2) - val(v, 2)) * t, val(v, 3) + (val(w, 3) - val(v, 3)) * t,
				val(v, 4) + (val(w, 4) - val(v, 4)) * t, val(v, 5) + (val(w, 5) - val(v, 5)) * t, val(v, 6) + (val(w, 6) - val(v, 6)) * t, jw(v) + (jw(w) - jw(v)) * t }
		else -- b에 없는 관절 = 값은 그대로 · 가중치만 줄어든다
			out[joint] = { val(v, 1), val(v, 2), val(v, 3), val(v, 4), val(v, 5), val(v, 6), jw(v) * (1 - t) }
		end
	end
	for joint, w in pairs(b) do
		if not a[joint] then -- a에 없던 관절 = b 값 · 가중치만 늘어난다
			out[joint] = { val(w, 1), val(w, 2), val(w, 3), val(w, 4), val(w, 5), val(w, 6), jw(w) * t }
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

-- A2-M1 타격 정렬: 전조(pre)가 있는 동작은 post 첫 키(접촉 · 쏘는 순간 자세)가 **판정 순간(hit)에** 오게 한다.
--   옛 방식 = 전조 키가 hit에 끝나고(치켜든 자세) 히트스톱이 치켜든 자세를 멈춘 뒤 post 첫 키(s ≈ 0.07 ~ 0.12)에 내려쳤다 → 보이는 타격이 판정보다 0.1 ~ 0.2초 늦었다
--   (공정성 규칙 "보이기 전에 맞는 일 금지" 위반). 지금 = 전조 키를 [0, hit − strike]로 당기고(strike = post 첫 키 s · 전조의 40%까지) 접촉 키 = hit ·
--   히트스톱 = **접촉 자세**에서 멈춤 · 나머지 post 키 = hit + (s − strike). 판정 시각(hit)은 그대로 - 겉모습만 앞당긴다.
--   clip.align = false면 옛 방식(전조 없는 층 · 더하는 층은 원래 정렬할 것이 없다).
--   접촉 키의 ease가 "out"이면 "strike"로 읽는다(치켜든 자세에서 속도 0으로 출발 - 한 프레임 속도 튐 없음 · 빠르기는 거의 같다).
BossMotion.alignMaxFraction = 0.4

local keyCache = setmetatable({}, { __mode = "k" }) -- [clip] = { hit, keys, preEnd, lastT }

local function buildKeys(clip, hit)
	local c = keyCache[clip]
	if c and c.hit == hit then
		return c
	end
	local post1 = clip.post and clip.post[1]
	local strike = 0
	if clip.align ~= false and clip.pre and #clip.pre > 0 and post1 and (post1.s or 0) > 0 and hit > 0 then
		strike = math.min(post1.s, hit * BossMotion.alignMaxFraction)
	end
	local preEnd = hit - strike
	local keys = {}
	for _, k in ipairs(clip.pre or {}) do
		table.insert(keys, { t = k.f * preEnd, pose = k.pose, ease = k.ease })
	end
	for i, k in ipairs(clip.post or {}) do
		local e = k.ease
		if i == 1 and strike > 0 and e == "out" then
			e = "strike"
		end
		table.insert(keys, { t = hit + k.s - strike, pose = k.pose, ease = e })
	end
	c = { hit = hit, keys = keys, preEnd = preEnd, strike = strike, lastT = #keys > 0 and keys[#keys].t or hit }
	keyCache[clip] = c
	return c
end
BossMotion.clipKeys = buildKeys

-- 접촉 시각(tRel 기준 - 검사 · 하네스용): 정렬된 동작 = hit · 옛 방식 = hit + post 첫 키 s
function BossMotion.contactTime(clip, hit)
	local c = buildKeys(clip, hit)
	local post1 = clip.post and clip.post[1]
	return post1 and (hit + post1.s - c.strike) or hit
end

-- 동작 표본: clip을 시작 뒤 tRel초(때리는 순간 = hit초)에서. 반환 = pose, 끝 시각(tRel 기준 - 되풀이면 nil), info
function BossMotion.sampleClip(clip, tRel, hit, weight, only)
	weight = weight or 1
	local hitstop = (clip.hitstop or 0) * weight
	local K = buildKeys(clip, hit)
	local keys, lastT, preEnd = K.keys, K.lastT, K.preEnd
	local contact = hit + ((clip.post and clip.post[1] and (clip.post[1].s - K.strike)) or 0)
	local t = tRel
	if hitstop > 0 and t > contact then
		t = t < contact + hitstop and contact or t - hitstop
	end
	local pose
	if #keys == 0 then
		pose = {}
	elseif t <= keys[1].t then
		pose = keys[1].pose
		if keys[1].t > 0 then -- 첫 키까지는 시작 자세(빈 자세 = 바탕)에서 이징으로
			pose = lerpPose({}, keys[1].pose, ease(keys[1].ease, t / keys[1].t), only)
		end
	elseif t >= lastT then
		pose = keys[#keys].pose
		if clip.loop then
			local L = clip.loop
			local u = (t - lastT) / L.period
			local n = #L.poses
			local i = math.floor(u) % n
			local loopPose = lerpPose(L.poses[i + 1], L.poses[(i + 1) % n + 1], ease("inout", u - math.floor(u)), only)
			pose = lerpPose(pose, loopPose, ease("inout", (t - lastT) / 0.2), only)
		end
	else
		for i = 1, #keys - 1 do
			local a, b = keys[i], keys[i + 1]
			if t >= a.t and t < b.t then
				pose = lerpPose(a.pose, b.pose, ease(b.ease, (t - a.t) / math.max(b.t - a.t, 1e-3)), only)
				break
			end
		end
		pose = pose or keys[#keys].pose
	end
	local info = {}
	-- 떨림(강화 평타 전조 끝 - 팔을 휘두를 듯) + 번쩍. A2-M1: 떨림은 휘두르기 시작(preEnd)까지 · 주파수 9 / 7Hz(옛 17 / 13Hz는 60fps에서 프레임마다 방향이 바뀌는 잡음이었다)
	local trembleEnd = K.strike > 0 and preEnd or hit
	if clip.tremble and hit > 0 and tRel >= clip.tremble.from * trembleEnd and tRel < trembleEnd then
		local ramp = clamp01((tRel - clip.tremble.from * trembleEnd) / math.max(trembleEnd * (1 - clip.tremble.from), 1e-3))
		local fade = clamp01((trembleEnd - tRel) / 0.06) -- 휘두르기 직전 부드럽게 멎는다
		local copy = lerpPose(pose, {}, 0)
		for _, joint in ipairs(clip.tremble.joints) do
			addTo(copy, joint, 1, math.sin(tRel * TAU * 9) * clip.tremble.amp * ramp * fade)
			addTo(copy, joint, 3, math.cos(tRel * TAU * 7) * clip.tremble.amp * 0.6 * ramp * fade)
		end
		pose = copy
		info.flash = clip.flash
		info.flashAmount = ramp * (0.5 + 0.5 * math.sin(tRel * TAU * 6))
	end
	if clip.airborne and hit > 0 and tRel >= clip.airborne.from * hit and tRel <= clip.airborne.to * hit then
		info.airborne = true
	end
	-- BR1-4c c-7: 노려봄(전조 동안 눈 빛남 세기 0 → 1)
	if clip.glare and hit > 0 and tRel < hit + 0.1 then
		info.glare = clamp01(tRel / hit)
	end
	-- 몸 눌림(무게감 - 접촉 순간부터) · 제자리 돌기
	if (clip.squash or clip.spin or clip.spinPre) then
		local copy = lerpPose(pose, {}, 0)
		if clip.squash and tRel >= contact and tRel < contact + hitstop + 0.3 then
			addTo(copy, "RootJoint", 5, -clip.squash * weight * math.sin(math.pi * clamp01((tRel - contact) / (hitstop + 0.3))))
		end
		if clip.spin and tRel > hit then
			addTo(copy, "RootJoint", 2, (clip.spin * (tRel - hit)) % 360)
		end
		if clip.spinPre and hit > 0 and tRel < hit then
			addTo(copy, "RootJoint", 2, clip.spinPre * ease("inout", tRel / math.max(trembleEnd, 1e-3)))
		end
		pose = copy
	end
	info.contact = contact
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
		-- A2-M1: 흔드는 발 = 3차 에르미트(양 끝 기울기 = 딛는 발 속도 -2h) - 옛 inout은 발을 떼는 순간 속도가 0으로 꺾였다(빠른 걸음 · 달리기에서 튐).
		--   들기 = sin²(시작 · 끝 속도 0). 발은 떼며 살짝 더 뒤로 갔다가 앞으로 - 실제 걸음과 같다.
		local f = ((u + 0.25) % 1) / 0.5
		local h = halfStride
		local f2, f3 = f * f, f * f * f
		d = (2 * f3 - 3 * f2 + 1) * -h + (f3 - 2 * f2 + f) * (-2 * h) + (-2 * f3 + 3 * f2) * h + (f3 - f2) * (-2 * h)
		bell = math.sin(math.pi * f) ^ 2
	end
	return math.deg(math.asin(math.clamp(d / reach, -0.95, 0.95))), bell
end
-- A2-M1 보폭 배율: 빨리 갈수록 보폭도 는다(보폭 ∝ 속도^0.75 · 걷기 속도 이하 = 1) - 옛 = 보폭 고정이라 달리기(× 2.5)에서 초당 3 ~ 4걸음 종종걸음(다리 튐).
--   걸음 위상(클라 BossAnimator · 검사)도 같은 배율의 보폭으로 진행해야 발이 안 미끄러진다.
function BossMotion.strideScale(ctx, speed)
	return math.clamp((speed or 0) / math.max(ctx.moveSpeed or 8, 1), 1, 3) ^ 0.75
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
	local walkW = ease("sine", (st.speed or 0) / 2.5) -- A2-M1: 속도 → 걷기 가중치를 사인으로(옛 직선은 걷기 시작 · 멈춤에서 다리 각속도가 꺾였다)
	if walkW > 0 then
		local legLen = ctx.legLen or 1.6
		local run = clamp01(((st.speed or 0) / math.max(ctx.moveSpeed or 8, 1) - 1) / math.max(W.runAt - 1, 0.1))
		local s = math.sin(TAU * (st.gait or 0))
		local knee = W.knee * (1 + 0.3 * run) -- A2-M1: 0.6 → 0.3(큰 보폭 달리기 - 무릎을 덜 접어도 발이 뜬다)
		local k = BossMotion.strideScale(ctx, st.speed)
		local aL, bL = gaitLeg(st.gait or 0, W.stride * k / 2, legLen)
		local aR, bR = gaitLeg((st.gait or 0) + 0.5, W.stride * k / 2, legLen)
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
	local walkW = ease("sine", (st.speed or 0) / 2.5) -- A2-M1: 속도 → 걷기 가중치를 사인으로(옛 직선은 걷기 시작 · 멈춤에서 다리 각속도가 꺾였다)
	if walkW > 0 then
		local legs = {}
		local run = clamp01(((st.speed or 0) / math.max(ctx.moveSpeed or 8, 1) - 1) / math.max(W.runAt - 1, 0.1))
		local liftK = 1 - 0.3 * run -- A2-M1: 빠르게 달릴수록 다리를 낮게(잰걸음 - 다리 튐 없음)
		for k = 1, 3 do
			for _, side in ipairs({ "L", "R" }) do
				local x = side == "R" and 1 or -1
				local key = ("%d_%s"):format(k, side)
				local phase = (st.gait or 0) + (table.find(W.groupA, key) and 0 or 0.5)
				local a, bell = gaitLeg(phase, W.stride * BossMotion.strideScale(ctx, st.speed) / 2, ctx.legReach or 1.3)
				local lift = W.lift * liftK
				legs["Hip" .. key] = { 0, x * a, x * lift * bell }
				legs["Knee" .. key] = { 0, 0, -x * lift * 0.5 * bell }
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

	-- 전투 준비 자세(평타 뒤 4초 · BR1-4c c-10: 보스전 중(st.inCombat)이면 늘 - 패턴 사이에 대기 자세로 돌아갔다 다시 드는 순간이 없게)
	local combat = st.inCombat and 1 or (st.swingAt and clamp01(1 - (now - st.swingAt - 3) / 1) or 0)
	-- A2-M1: 걷는 동안 다리는 걸음이 그린다 - 옛 "속도 > 1이면 다리 끔" 필터가 속도 1을 넘나들 때 다리 자세를 한 프레임에 바꿨다 → 다리 가중치를 속도로 부드럽게
	local legK = 1 - ease("sine", ((st.speed or 0) - 0.3) / 1.6)
	if combat > 0 and P.guard then
		blend(pose, P.guard, combat * 0.85, isUpper)
		blend(pose, P.guard, combat * 0.85 * legK, isLeg)
	end
	-- 평타(좌우 번갈아)
	if st.swingAt and now - st.swingAt < 1.0 then
		local clip = P.clips[(st.swingN or 0) % 2 == 0 and "basic_R" or "basic_L"]
		local p, endT = BossMotion.sampleClip(clip, now - st.swingAt, 0, weight)
		local w = ease("out", (now - st.swingAt) / 0.05) * (1 - ease("inout", (now - st.swingAt - (endT or 0.6)) / 0.3))
		blend(pose, p, w, isUpper)
		blend(pose, p, w * legK, isLeg)
	end

	-- 환경 변화(두 번째 시계)와 스킬: 동작 층
	local function actLayer(name, at, hit, endAt, upperOnly, fade)
		local clip = name and BossMotion.clip(ctx.rigId, ctx.rig, name)
		if not clip or not at then
			return 0
		end
		local tRel = now - at
		local p, endT, cinfo = BossMotion.sampleClip(clip, tRel, hit or 0, weight)
		-- A2-M1 여운 · 겹침(follow-through · overlap): 팔 끝 · 목 · 꼬리 밑동은 몸보다 조금 늦게 같은 궤적을 따른다(관절 묶음별 지연 표본)
		--   휘두르는 구간(전조 끝 0.15초 전 ~ 접촉 + 히트스톱)에서는 지연을 0으로 줄인다 - 때리는 부위(손 · 꼬리 끝)가 판정보다 늦게 닿지 않게(공정성). 경계는 sine으로 이어 튐 없음.
		local lagK = 1
		if P.overlap and not st.noOverlap and (hit or 0) > 0 then
			local K = BossMotion.clipKeys(clip, hit)
			local c0, c1 = K.preEnd - 0.15, cinfo.contact + (clip.hitstop or 0) * weight
			if tRel > c0 and tRel < c1 + 0.12 then
				lagK = tRel < K.preEnd and 1 - ease("sine", (tRel - c0) / 0.15) or (tRel < c1 and 0 or ease("sine", (tRel - c1) / 0.12))
			end
		end
		if P.overlap and not st.noOverlap and lagK > 0 then
			local copy = nil
			for _, g in ipairs(P.overlap) do
				local lagged = BossMotion.sampleClip(clip, tRel - g.delay * weight * lagK, hit or 0, weight, g.joints)
				for _, joint in ipairs(g.joints) do
					if lagged[joint] or p[joint] then
						copy = copy or lerpPose(p, {}, 0)
						copy[joint] = lagged[joint] or { 0, 0, 0, 0, 0, 0, 0 } -- 늦은 표본에 아직 없는 관절 = 가중치 0
					end
				end
			end
			p = copy or p
		end
		-- A2-M1: 섞어 들어가기 = sine(시작 속도 0 - 옛 "out"은 동작마다 첫 프레임에 속도가 튀었다)
		local w = ease("sine", tRel / (clip.blendIn or 0.18))
		if endT then
			w *= 1 - ease("inout", (tRel - endT) / 0.3)
		end
		if endAt then
			w *= 1 - ease("inout", (now - endAt) / 0.3)
		end
		w *= fade or 1
		if w > 0 then
			-- upper(돌진 · 쫓기) = 때리는 순간부터 다리는 걸음이 그린다 - A2-M1: 다리 넘김을 0.15초 사인으로(옛 = 한 프레임 전환)
			local legW = upperOnly and 0 or (clip.upper and 1 - ease("sine", (tRel - (hit or 0)) / 0.15) or 1)
			blend(pose, p, w, isUpper)
			if legW > 0 then
				blend(pose, p, w * legW, isLeg)
			end
			if cinfo.flash then
				info.flash, info.flashAmount = cinfo.flash, cinfo.flashAmount * w
			end
			if cinfo.glare then
				info.glare = cinfo.glare * w
			end
			if cinfo.airborne and w > 0.3 then
				info.airborne = true
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
			-- A2-M1: 단계 사이는 시간 · 속도로 교차 페이드(상태 없음 - 서버 잡기 FK와 같은 값) - 옛 = 한 프레임에 층이 바뀌어 팔이 튀었다
			local hit = st.actHit or 5
			local tRel = now - st.actAt
			local thrown = st.throwAt and now >= st.throwAt
			local throwK = (st.throwPlan and not thrown) and ease("sine", (now - (st.throwPlan - P.throwWindup)) / 0.2) or 0
			local holdKeep = (st.throwPlan and not thrown) and 1 - ease("sine", (now - (st.throwPlan - P.throwWindup)) / P.throwWindup) or 1 -- 들기는 던지기 전조 내내 천천히 넘긴다(전조 첫 키가 들기 자세 위로 차오름)
			if tRel < hit + 0.4 then
				actLayer("grab_tele", st.actAt, hit, st.actEndAt, nil, 1 - ease("sine", (tRel - hit) / 0.4))
			end
			if tRel >= hit and not thrown then
				local runK = ease("sine", ((st.speed or 0) - 1) / math.max(ctx.moveSpeed or 8, 4)) -- 쫓기 ↔ 들기: 속도 폭을 넓게(멈출 때 팔이 천천히 올라감)
				local keep = holdKeep
				if runK > 0 and keep > 0 then
					actLayer("grab_reach", st.actAt + hit, 0, st.actEndAt, true, runK * keep)
				end
				if runK < 1 and keep > 0 then
					actLayer("grab_hold", st.actAt + hit, 0, st.actEndAt, nil, (1 - runK) * keep)
				end
			end
			if throwK > 0 then
				actLayer(ctx.boss and ctx.boss.throw or "throw_overhead", st.throwPlan - P.throwWindup, P.throwWindup)
			end
		else
			actLayer(BossMotion.clipNameForSkill(ctx.rigId, ctx.rig, st.act, skill), st.actAt, st.actHit, st.actEndAt)
			-- BR1-4c: 지진파 뛰어오름마다 웅크림 → 공중 → 내려찍기(서버 BossHopAt · 뛰는 시간 = 착지 = 파동)
			if st.hopAt and st.hopSeconds and st.hopAt >= st.actAt and P.clips.hopSlam and now - st.hopAt < st.hopSeconds + 0.8 then
				actLayer("hopSlam", st.hopAt, st.hopSeconds, st.actEndAt)
			end
			-- BR1-4c c-9: 스킬 뒤 단계(마무리 강타 → 숨 고르기)
			local phaseClip = st.actPhase and P.phaseClips and P.phaseClips[st.actPhase]
			if phaseClip and st.actPhaseAt then
				local clip = BossMotion.clip(ctx.rigId, ctx.rig, phaseClip)
				actLayer(phaseClip, st.actPhaseAt, clip and clip.finishHit or 0, st.actEndAt)
			end
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

	-- 피격 움찔(더하는 층 · 판정 없음) - A2-M1: 세기 = st.flinchAmp(클라가 체력 감소 크기로 정한다 - 작은 타격 0.7 · 강공격 · 치명 최대 2) · 모양 = 빨리 밀렸다가 천천히 돌아옴
	if st.flinchAt and now - st.flinchAt < P.flinch.seconds * (st.flinchAmp and st.flinchAmp > 1.2 and 1.4 or 1) then
		local dur = P.flinch.seconds * (st.flinchAmp and st.flinchAmp > 1.2 and 1.4 or 1)
		local u = (now - st.flinchAt) / dur
		local shape = u < 0.25 and ease("quadOut", u / 0.25) or 1 - ease("settle", (u - 0.25) / 0.75)
		add(pose, P.flinch.pose, shape * (st.flinchAmp or 1))
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
		if Dd.slowSeconds then -- BR1-4c c-5: 막타 뒤 잠깐 슬로모션(화면만)
			t = t < Dd.slowSeconds and t * Dd.slowRate or Dd.slowSeconds * Dd.slowRate + (t - Dd.slowSeconds)
		end
		info.slow = (now - st.deadAt) < (Dd.slowSeconds or 0)
		info.stars = Dd.stars and t > (Dd.hitstopAt or 1) - 0.3 or nil
		local hitstop = t > Dd.hitstopAt and t < Dd.hitstopAt + 0.08 * weight
		Dd.clip = Dd.clip or { post = Dd.keys, align = false }
		local p = BossMotion.sampleClip(Dd.clip, hitstop and Dd.hitstopAt or (t > Dd.hitstopAt and t - 0.08 * weight or t), 0)
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
