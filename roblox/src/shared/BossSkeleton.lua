-- BOSS-FRAMEWORK 1 뼈대 생성기(순수 함수 - 데이터 표 BossRigSpec · BossRigV2Data가 부른다). 출력 = BossRigSpec 관절 표 규격 그대로
--   { name(Motor6D) · parent(부모 파트) · part(자식 파트) · size · shape · color · material · at(부모 공간 관절 자리) · pivot(자식 공간 관절 자리) · rot(기준 자세 도) · query }.
--   단위 = sizeScale 1 · 루트 = (0, 0, 0) · 발바닥 y −1.5 · 앞 = −Z. 모션 부호(A1 실측): 아래로 늘어진 부위 X +θ = 앞으로 든다 · 무릎 굽힘 X −θ.
--   biped · chain = 옛 BossRigSpec 안의 함수를 옮긴 것(식 · 순서 그대로 - 옛 리그 결과 불변). 나머지 = 새 몸 구조(바이블 §2): 네 발 · 뱀 하체 · 날개 · 코 · 여섯 다리.
--   관절 이름 규칙: 앞다리 = 이족 팔 이름(Shoulder · Elbow · Wrist → UpperArm · Forearm · Hand) · 뒷다리 = 이족 다리 이름(Hip · Knee · Ankle) → 잡기 부착점 · 발 접지 · 효과가 그대로 쓴다.
local BossSkeleton = {}

local V = Vector3.new

local function add(J, j)
	table.insert(J, j)
	return j
end
BossSkeleton.add = add

-- ─────────────────────────── 두 발 몸(옛 BossRigSpec biped 그대로) ───────────────────────────
-- o = { hips, torso, head(크기), headShape, thigh = { w, len }, shin = { w, len }, foot(크기), upperArm = { w, len }, forearm = { w, len }, hand(크기), shoulderX, stance(엉덩이 반폭) }
function BossSkeleton.biped(o)
	local J = {}
	local legLen = o.thigh.len + o.shin.len
	local hipJointY = -1.5 + o.foot.Y + legLen
	add(J, { name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", size = o.hips, color = "dark", at = V(0, hipJointY + o.hips.Y / 2, 0), pivot = V(0, 0, 0) })
	add(J, { name = "Waist", parent = "Hips", part = "Body", size = o.torso, color = "body", at = V(0, o.hips.Y / 2, 0), pivot = V(0, -o.torso.Y / 2, 0), query = true })
	add(J, { name = "Neck", parent = "Body", part = "Head", size = o.head, shape = o.headShape or "block", color = "head", at = V(0, o.torso.Y / 2, 0), pivot = V(0, -o.head.Y * 0.45, 0), query = true })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		add(J, { name = "Hip_" .. side, parent = "Hips", part = "Thigh_" .. side, size = V(o.thigh.w, o.thigh.len, o.thigh.w), color = "body", at = V(x * o.stance, -o.hips.Y / 2, 0), pivot = V(0, o.thigh.len / 2, 0) })
		add(J, { name = "Knee_" .. side, parent = "Thigh_" .. side, part = "Shin_" .. side, size = V(o.shin.w, o.shin.len, o.shin.w), color = "dark", at = V(0, -o.thigh.len / 2, 0), pivot = V(0, o.shin.len / 2, 0) })
		add(J, { name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, size = o.foot, color = "dark", at = V(0, -o.shin.len / 2, 0), pivot = V(0, o.foot.Y / 2, o.foot.Z * 0.25) })
		add(J, { name = "Shoulder_" .. side, parent = "Body", part = "UpperArm_" .. side, size = V(o.upperArm.w, o.upperArm.len, o.upperArm.w), color = "body",
			at = V(x * o.shoulderX, o.torso.Y / 2 - o.upperArm.w * 0.45, 0), pivot = V(0, o.upperArm.len / 2 - o.upperArm.w * 0.3, 0), rot = V(0, 0, x * 6) })
		add(J, { name = "Elbow_" .. side, parent = "UpperArm_" .. side, part = "Forearm_" .. side, size = V(o.forearm.w, o.forearm.len, o.forearm.w), color = "head", at = V(0, -o.upperArm.len / 2, 0), pivot = V(0, o.forearm.len / 2, 0), rot = V(8, 0, 0) })
		add(J, { name = "Wrist_" .. side, parent = "Forearm_" .. side, part = "Hand_" .. side, size = o.hand, color = "head", at = V(0, -o.forearm.len / 2, 0), pivot = V(0, o.hand.Y / 2, 0) })
	end
	-- 얼굴(표정 - 4b-4 낚아채는 순간): 눈 · 입
	add(J, { name = "Eyes", parent = "Head", part = "Eyes", size = V(o.head.X * 0.62, o.head.Y * 0.14, 0.08), color = "eye", material = "Neon", at = V(0, o.head.Y * 0.12, -o.head.Z / 2), pivot = V(0, 0, 0.02) })
	add(J, { name = "Jaw", parent = "Head", part = "Mouth", size = V(o.head.X * 0.42, o.head.Y * 0.1, 0.08), color = "mouth", at = V(0, -o.head.Y * 0.22, -o.head.Z / 2), pivot = V(0, o.head.Y * 0.04, 0.02) })
	return J
end

-- 사슬(꼬리 · 망토 · 수염 · 치마 · 코 · 날개 마디): n마디, 마디마다 length · 굵기 w0 → w1(끝으로 가늘어짐) · 첫 마디 기준 자세 rot0 · 다음 마디부터 rotStep(옛 BossRigSpec chain 그대로).
--   o.thick(선택 - 납작한 천 · 날개막: 두께를 따로) · o.query(선택 - 이 마디 번호만 판정 사본) · o.lengths · o.rots(선택 - 마디마다 길이 · 기준 자세 표)
function BossSkeleton.chain(J, o)
	local parent = o.parent
	for i = 1, o.count do
		local f = (i - 1) / math.max(o.count - 1, 1)
		local w = o.w0 + (o.w1 - o.w0) * f
		local name = ("%s%d"):format(o.prefix, i)
		local len = (o.lengths and o.lengths[i]) or o.length
		local prevLen = i > 1 and ((o.lengths and o.lengths[i - 1]) or o.length) or nil
		table.insert(J, {
			name = name, parent = parent, part = name, size = V(w * (o.flat or 1), len, o.thick or w), color = (i == o.count and o.tipColor) or o.color or "body",
			material = (i == o.count and o.tipMaterial) or o.material, shape = (i == o.count and o.tipShape) or "block",
			at = i == 1 and o.at or V(0, -prevLen / 2, 0), pivot = V(0, len / 2, 0), rot = (o.rots and o.rots[i]) or (i == 1 and o.rot0 or o.rotStep),
			query = (o.query == i) or nil,
		})
		parent = name
	end
	return J
end

-- ─────────────────────────── 네 발(매머드 · 너클 보행 시안의 기준) ───────────────────────────
-- 몸통이 수평: Hips(엉덩이) → Body(앞몸 · 척추 1) → Chest(척추 2 · 선택) → Neck → Head. 앞다리 = Body(또는 Chest) 앞 아래 · 뒷다리 = Hips 아래.
-- o = { hips, body, chest(선택), head, neckLen, legFront = { upper, lower, foot(크기), w }, legRear = { upper, lower, foot, w }, stanceX, frontZ, rearZ, height(엉덩이 관절 높이 - 없으면 다리 길이) }
function BossSkeleton.quadruped(o)
	local J = {}
	local rear, front = o.legRear, o.legFront
	local hipY = -1.5 + rear.foot.Y + rear.upper + rear.lower
	add(J, { name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", size = o.hips, color = "dark", at = V(0, hipY + o.hips.Y * 0.3, o.rearZ or 0.9), pivot = V(0, 0, 0) })
	-- 척추: Body가 Hips 앞으로 수평(관절 = Hips 앞면)
	add(J, { name = "Waist", parent = "Hips", part = "Body", size = o.body, color = "body", at = V(0, 0.1, -o.hips.Z / 2), pivot = V(0, 0, o.body.Z / 2), query = true })
	local front0, frontLen = "Body", o.body.Z
	if o.chest then
		add(J, { name = "Spine", parent = "Body", part = "Chest", size = o.chest, color = "body", at = V(0, 0.05, -o.body.Z / 2), pivot = V(0, 0, o.chest.Z / 2) })
		front0, frontLen = "Chest", o.chest.Z
	end
	add(J, { name = "Neck", parent = front0, part = "Head", size = o.head, color = "head", at = V(0, (o.neckY or 0.25), -frontLen / 2), pivot = V(0, 0, o.head.Z * 0.4), query = true })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		-- 앞다리(팔 이름)
		add(J, { name = "Shoulder_" .. side, parent = front0, part = "UpperArm_" .. side, size = V(front.w, front.upper, front.w), color = "body", at = V(x * o.stanceX, -0.2, -frontLen * 0.25), pivot = V(0, front.upper / 2, 0) })
		add(J, { name = "Elbow_" .. side, parent = "UpperArm_" .. side, part = "Forearm_" .. side, size = V(front.w * 0.9, front.lower, front.w * 0.9), color = "head", at = V(0, -front.upper / 2, 0), pivot = V(0, front.lower / 2, 0) })
		add(J, { name = "Wrist_" .. side, parent = "Forearm_" .. side, part = "Hand_" .. side, size = front.foot, color = "dark", at = V(0, -front.lower / 2, 0), pivot = V(0, front.foot.Y / 2, 0) })
		-- 뒷다리(다리 이름)
		add(J, { name = "Hip_" .. side, parent = "Hips", part = "Thigh_" .. side, size = V(rear.w, rear.upper, rear.w), color = "body", at = V(x * o.stanceX, -o.hips.Y * 0.3, 0), pivot = V(0, rear.upper / 2, 0) })
		add(J, { name = "Knee_" .. side, parent = "Thigh_" .. side, part = "Shin_" .. side, size = V(rear.w * 0.9, rear.lower, rear.w * 0.9), color = "dark", at = V(0, -rear.upper / 2, 0), pivot = V(0, rear.lower / 2, 0) })
		add(J, { name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, size = rear.foot, color = "dark", at = V(0, -rear.lower / 2, 0), pivot = V(0, rear.foot.Y / 2, 0) })
	end
	add(J, { name = "Eyes", parent = "Head", part = "Eyes", size = V(o.head.X * 0.7, o.head.Y * 0.12, 0.08), color = "eye", material = "Neon", at = V(0, o.head.Y * 0.18, -o.head.Z / 2), pivot = V(0, 0, 0.02) })
	add(J, { name = "Jaw", parent = "Head", part = "Mouth", size = V(o.head.X * 0.4, o.head.Y * 0.1, 0.08), color = "mouth", at = V(0, -o.head.Y * 0.3, -o.head.Z / 2), pivot = V(0, o.head.Y * 0.04, 0.02) })
	return J
end

-- ─────────────────────────── 뱀 하체(나가) ───────────────────────────
-- 이족 상체(다리 없음) + Hips 밑에서 뒤로 눕는 꼬리 n마디 + 끝 지느러미. o = { upper(biped 옵션 - 다리 값은 길이 계산용) · tail = { count, length, w0, w1, rot0, rotStep, query } · fin(크기) }
function BossSkeleton.serpent(o)
	local J = {}
	for _, j in ipairs(BossSkeleton.biped(o.upper)) do
		if not (j.name:find("^Hip_") or j.name:find("^Knee_") or j.name:find("^Ankle_")) then
			table.insert(J, j)
		end
	end
	local T = o.tail
	BossSkeleton.chain(J, { prefix = "Tail", parent = "Hips", count = T.count, length = T.length, w0 = T.w0, w1 = T.w1, flat = T.flat or 1.25, at = T.at or V(0, -0.2, 0.2),
		rot0 = T.rot0 or V(-80, 0, 0), rotStep = T.rotStep or V(-8, 0, 0), rots = T.rots, color = "body", query = T.query })
	if o.fin then
		add(J, { name = "TailFin", parent = "Tail" .. T.count, part = "TailFin", size = o.fin, shape = "wedge", color = "accent", at = V(0, -T.length / 2, 0), pivot = V(0, o.fin.Y / 2, 0) })
	end
	return J
end

-- ─────────────────────────── 날개(나비 4장 · 망토 날개) ───────────────────────────
-- pairs = { { tag = "F", at, rot0, count, length, w0, w1, rotStep, thick } … } → Wing<tag>_L1 … · Wing<tag>_R1 …(좌우 거울)
function BossSkeleton.wings(J, parent, pairsList, color, material)
	for _, p in ipairs(pairsList) do
		for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
			local x = s[2]
			BossSkeleton.chain(J, { prefix = ("Wing%s_%s"):format(p.tag, s[1]), parent = parent, count = p.count or 2, length = p.length, w0 = p.w0, w1 = p.w1, thick = p.thick or 0.06,
				at = V(p.at.X * x, p.at.Y, p.at.Z), rot0 = V(p.rot0.X, p.rot0.Y * x, p.rot0.Z * x), rotStep = V(p.rotStep.X, p.rotStep.Y * x, p.rotStep.Z * x), color = color or "accent", material = material })
		end
	end
	return J
end

-- ─────────────────────────── 여섯 다리(전갈 - 엉덩이 · 무릎) ───────────────────────────
-- legs = { z1, z2, z3 } · o = { parent, x, thigh, shin, w } → Hip<k>_<L|R> · Knee<k>_<L|R>(옛 전갈과 같은 이름 · 자세)
function BossSkeleton.hexapod(J, o)
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		for k, z in ipairs(o.legs) do
			local leg = ("%d_%s"):format(k, side)
			add(J, { name = "Hip" .. leg, parent = o.parent, part = "Thigh" .. leg, size = V(o.w, o.thigh, o.w), color = "head", at = V(x * o.x, o.y or -0.15, z), pivot = V(0, o.thigh / 2, 0), rot = V(0, 0, x * 125) })
			add(J, { name = "Knee" .. leg, parent = "Thigh" .. leg, part = "Shin" .. leg, size = V(o.w * 0.86, o.shin, o.w * 0.86), color = "dark", at = V(0, -o.thigh / 2, 0), pivot = V(0, o.shin / 2, 0), rot = V(0, 0, -x * 95) })
		end
	end
	return J
end

-- ─────────────────────────── 검사(관절 수 · 판정 사본 부피) ───────────────────────────
function BossSkeleton.jointCount(rig)
	return #rig.joints
end

-- 판정 사본(query = true 부위) 부피 합(sizeScale 1 · 상자 부피 · 공 = 상자 × π/6)
function BossSkeleton.queryVolume(rig)
	local v, names = 0, {}
	for _, j in ipairs(rig.joints) do
		if j.query then
			local box = j.size.X * j.size.Y * j.size.Z
			v += j.shape == "ball" and box * math.pi / 6 or box
			table.insert(names, j.part)
		end
	end
	return v, names
end

-- 관절 하나 찾기(이름)
function BossSkeleton.find(J, name)
	for _, j in ipairs(J) do
		if j.name == name then
			return j
		end
	end
	return nil
end

return BossSkeleton
