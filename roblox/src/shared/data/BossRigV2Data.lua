-- BOSS-FRAMEWORK 1 새 몸(리그 v2) 데이터 - 바이블 §2 보스별 몸 구조. 리그 키 = "<보스 id>_v2"(BossRigSpec.rigs에 같이 등록 · 모델 Attribute BossRigKey).
--   status: "trial" = 시험(Studio 스위치 BossFrameworkTrial로만 뜬다) · "draft" = 뼈대 초안(메시 · 클립 전 - 생성기 · 예산 검사용, 어디서도 안 쓴다).
--   실전 교체 = shared/data/BossFrameworkData.live(설계 담당 검수 뒤에만 채운다).
--   chains(2차 움직임 사슬) = { 관절 이름…, kind = tail | wing | cape | trunk | fur | crystal | cloth(스프링 값 = BossFrameworkData.springs), lag, sway(옛 결정적 흔들림 - BossMotion.chainSway) }.
--   contacts(선택) = 발 접지에 쓰는 부위(없으면 BossRigSpec가 Foot · Shin 끝으로 채운다). 판정 사본 = query = true 부위(Body · Head + 큰 몸이면 1개).
local BossSkeleton = require(script.Parent.Parent.BossSkeleton)

local V = Vector3.new
local add, chain = BossSkeleton.add, BossSkeleton.chain

local D = {}
D.rigs = {}

-- 막대 부위(수정 · 뿔 · 왕관): 중심 center · 회전 rot(도)로 놓되 관절 = 밑동(흔들림 · 터짐이 밑동에서 돈다)
-- 회전(도 - CFrame.Angles(rx, ry, rz)와 같은 순서 Rx · Ry · Rz)을 벡터에 적용(데이터 로드에 CFrame을 안 쓴다 - 하네스 · 도구 스텁에서도 돈다)
local function rotate(v, rot)
	local x, y, z = v.X, v.Y, v.Z
	local cz, sz = math.cos(math.rad(rot.Z)), math.sin(math.rad(rot.Z))
	x, y = x * cz - y * sz, x * sz + y * cz
	local cy, sy = math.cos(math.rad(rot.Y)), math.sin(math.rad(rot.Y))
	x, z = x * cy + z * sy, -x * sy + z * cy
	local cx, sx = math.cos(math.rad(rot.X)), math.sin(math.rad(rot.X))
	y, z = y * cx - z * sx, y * sx + z * cx
	return V(x, y, z)
end

local function stick(J, name, parent, size, center, rot, color, material, shape)
	local base = center - rotate(V(0, size.Y / 2, 0), rot)
	return add(J, { name = name, parent = parent, part = name, size = size, shape = shape, color = color, material = material, at = base, pivot = V(0, -size.Y / 2, 0), rot = rot })
end

-- ─────────────────────────── 구간 수호자 → 너클 보행 수정 골렘(GUARDIAN-V2 · Meshy 원본) ───────────────────────────
-- 상자 · 관절 = Meshy GLB(guardian_v1_meshy71 · A-포즈) 정면 · 옆 실측(모델 높이 10 = "m" 단위 · 발바닥 0 · fwd + = 앞)에 맞춤.
--   K = m → 리그 단위: 판정 사본(Body + Head) 부피 = 옛 몸 × 1.17(허용 ±20%) · 어깨 폭 = 바이블 §4 목표(15 stud @ S 3.9)에 맞춘 값(키는 그림 비율상 §4 추정보다 낮다 - 보고서).
--   팔 = Meshy A-포즈 그대로가 기준 자세(위팔 바깥 43° · 아래팔 · 손 앞으로) - 아래로 펴면 거대한 아래팔이 몸통을 뚫는다(고릴라 비율).
--   scale 1.5 = 바이블 §5 크기 × 1.5(보이는 몸 · 판정 사본 · 모션 이동 모두 - MonsterSpawner가 S × scale로 짓는다).
--   Jaw = 자리만(움직이지 않음 · 메시 없음) · 눈 · 룬 = KIT가 Neon으로 새로 만든다(rigs/section_guardian_v2.kit.json).
do
	local K = 0.40
	local function P(x, z, fwd) -- m 단위 점 → 리그 공간(x = 오른쪽 +)
		return V(K * x, K * z - 1.5, -K * fwd)
	end
	local function Z(w, h, d)
		return V(K * w, K * h, K * d)
	end
	-- 3 × 3 회전(CFrame.Angles(rx, ry, rz) = Rx · Ry · Rz 순서 - 데이터 로드에 CFrame을 안 쓴다)
	local function E(r)
		local cx, sx, cy, sy, cz, sz = math.cos(math.rad(r.X)), math.sin(math.rad(r.X)), math.cos(math.rad(r.Y)), math.sin(math.rad(r.Y)), math.cos(math.rad(r.Z)), math.sin(math.rad(r.Z))
		return {
			{ cy * cz, -cy * sz, sy },
			{ cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy },
			{ sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy },
		}
	end
	local function mulT(A, B) -- Aᵀ · B
		local M = {}
		for i = 1, 3 do
			M[i] = {}
			for j = 1, 3 do
				M[i][j] = A[1][i] * B[1][j] + A[2][i] * B[2][j] + A[3][i] * B[3][j]
			end
		end
		return M
	end
	local function applyT(A, v) -- Aᵀ · v
		return V(A[1][1] * v.X + A[2][1] * v.Y + A[3][1] * v.Z, A[1][2] * v.X + A[2][2] * v.Y + A[3][2] * v.Z, A[1][3] * v.X + A[2][3] * v.Y + A[3][3] * v.Z)
	end
	local function apply(A, v)
		return V(A[1][1] * v.X + A[1][2] * v.Y + A[1][3] * v.Z, A[2][1] * v.X + A[2][2] * v.Y + A[2][3] * v.Z, A[3][1] * v.X + A[3][2] * v.Y + A[3][3] * v.Z)
	end
	local function euler(M) -- Rx · Ry · Rz 분해(도)
		local ry = math.asin(math.clamp(M[1][3], -1, 1))
		return V(math.deg(math.atan2(-M[2][3], M[3][3])), math.deg(ry), math.deg(math.atan2(-M[1][2], M[1][1])))
	end
	local J, world = {}, { HumanoidRootPart = { R = E(Vector3.zero), c = Vector3.zero } }
	-- 세계 자리로 부위 하나: o = { name, parent, part, center, size, joint, rot(세계 도) · color · material · query }
	local function place(o)
		local par = world[o.parent]
		local Rw = E(o.rot or Vector3.zero)
		world[o.part] = { R = Rw, c = o.center }
		return add(J, { name = o.name, parent = o.parent, part = o.part, size = o.size, color = o.color or "body", material = o.material, query = o.query,
			at = applyT(par.R, o.joint - par.c), pivot = applyT(Rw, o.joint - o.center), rot = euler(mulT(par.R, Rw)) })
	end
	-- 팔 마디: 관절 a → 끝 b(m 단위) · 상자 길이 = 거리 + ext · 세계 회전 = (0, −1, 0)을 a→b로(rz = 바깥 · rx = 앞)
	local function seg(name, parent, part, a, b, w, d, ext, color)
		local pa, pb = P(a[1], a[2], a[3]), P(b[1], b[2], b[3])
		local dir = (pb - pa).Unit
		local rz = math.deg(math.asin(dir.X))
		local rx = math.deg(math.atan2(-dir.Z, -dir.Y))
		local len = (pb - pa).Magnitude + K * ext
		return place({ name = name, parent = parent, part = part, joint = pa, center = pa + dir * (len / 2 - K * ext * 0.25), size = V(K * w, len, K * d), rot = V(rx, 0, rz), color = color })
	end
	place({ name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", center = P(0, 2.55, -0.1), size = Z(4.0, 1.3, 3.0), joint = P(0, 2.55, 0), color = "dark" })
	place({ name = "Waist", parent = "Hips", part = "Body", center = P(0, 5.3, -0.35), size = Z(5.0, 4.6, 4.0), joint = P(0, 3.2, -0.2), query = true })
	place({ name = "Neck", parent = "Body", part = "Head", center = P(0, 7.95, 1.6), size = Z(2.8, 3.0, 2.9), joint = P(0, 6.9, 0.7), color = "head", query = true })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		place({ name = "Hip_" .. side, parent = "Hips", part = "Thigh_" .. side, center = P(x * 1.55, 2.15, -0.05), size = Z(1.8, 1.1, 1.9), joint = P(x * 1.5, 2.6, -0.05) })
		place({ name = "Knee_" .. side, parent = "Thigh_" .. side, part = "Shin_" .. side, center = P(x * 1.65, 1.25, -0.05), size = Z(1.75, 0.9, 1.8), joint = P(x * 1.6, 1.65, 0), color = "dark" })
		place({ name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, center = P(x * 1.8, 0.42, 0.15), size = Z(2.1, 0.85, 2.5), joint = P(x * 1.7, 0.8, -0.1), color = "dark" })
		seg("Shoulder_" .. side, "Body", "UpperArm_" .. side, { x * 2.9, 6.3, 0 }, { x * 4.6, 4.5, 0.3 }, 2.3, 2.4, 0.5)
		seg("Elbow_" .. side, "UpperArm_" .. side, "Forearm_" .. side, { x * 4.6, 4.5, 0.3 }, { x * 5.25, 2.35, 1.35 }, 3.2, 2.9, 0.5, "head")
		seg("Wrist_" .. side, "Forearm_" .. side, "Hand_" .. side, { x * 5.25, 2.35, 1.35 }, { x * 5.0, 0.3, 2.1 }, 3.1, 3.0, 0.2, "head")
		place({ name = "Pauldron_" .. side, parent = "UpperArm_" .. side, part = side == "L" and "LeftPauldron" or "RightPauldron", center = P(x * 3.35, 6.65, -0.1), size = Z(2.2, 2.0, 2.8), joint = P(x * 3.0, 6.6, 0), color = "head" })
	end
	-- 얼굴: 눈(Neon · KIT 생성 - 평소 모양 · 화남 · 헤롱 조각은 장식으로 같은 부위에) · 턱(자리만) · 눈썹 바위(Meshy 눈썹 - 표정)
	place({ name = "Eyes", parent = "Head", part = "Eyes", center = P(0, 7.92, 2.56), size = Z(1.7, 0.6, 0.12), joint = P(0, 7.92, 2.56), color = Color3.fromRGB(205, 90, 255), material = "Neon" }) -- Neon 색 = 가장 낮은 채널 ≤ 90(흰 날림 방지)
	place({ name = "Jaw", parent = "Head", part = "Mouth", center = P(0, 7.0, 2.6), size = Z(0.6, 0.2, 0.1), joint = P(0, 7.0, 2.6), color = "mouth" })
	place({ name = "Brow", parent = "Head", part = "Brow", center = P(0, 8.45, 2.45), size = Z(2.5, 0.55, 0.7), joint = P(0, 8.5, 2.1), color = "slab" })
	place({ name = "Rune", parent = "Body", part = "Rune", center = P(0, 4.15, 1.86), size = Z(1.0, 1.8, 0.14), joint = P(0, 4.15, 1.86), color = Color3.fromRGB(185, 70, 255), material = "Neon" })
	place({ name = "TassetF", parent = "Hips", part = "TassetF", center = P(0, 2.2, 1.35), size = Z(2.6, 1.2, 0.5), joint = P(0, 2.75, 1.3), color = "slab" })
	place({ name = "TassetB", parent = "Hips", part = "TassetB", center = P(0, 2.3, -1.55), size = Z(2.8, 1.3, 0.5), joint = P(0, 2.9, -1.5), color = "slab" })
	-- 등 수정 5(Meshy 등 수정 무리 실측 - 가운데 큰 것 · 왼쪽 큰 것 · 오른쪽 큰 것(더 눕힘) · 둥근 작은 것 둘) · 관절 = 밑동(흔들림 · 50% 터짐)
	--   가운데 · 큰 쌍 = Neon(Meshy 수정 면 그대로 빛 - 색 = 텍스처 평균에서 가장 낮은 채널 ≤ 90) · 둥근 둘 = 텍스처
	local GLOW = Color3.fromRGB(225, 90, 255)
	local function crystal(name, center, size, rot, glow)
		local c = P(center[1], center[2], center[3])
		local base = c - apply(E(rot), V(0, K * size[2] / 2, 0))
		return place({ name = name, parent = "Body", part = name, center = c, size = Z(size[1], size[2], size[3]), joint = base, rot = rot, color = glow and GLOW or "accent", material = glow and "Neon" or nil })
	end
	crystal("Crystal1", { 0, 7.35, -2.65 }, { 1.2, 3.2, 1.2 }, V(20, 0, 0), true)
	crystal("Crystal2", { -2.0, 8.0, -1.75 }, { 1.5, 4.0, 1.5 }, V(12, 0, 20), true)
	crystal("Crystal3", { 2.65, 7.9, -1.7 }, { 1.5, 4.0, 1.5 }, V(12, 0, -35), true)
	crystal("Crystal4", { -1.6, 5.9, -2.45 }, { 1.1, 1.1, 1.1 }, V(30, 0, 0))
	crystal("Crystal5", { 1.6, 6.0, -2.4 }, { 1.1, 1.1, 1.1 }, V(30, 0, 0))
	D.rigs.section_guardian_v2 = {
		bossId = "section_guardian", variant = "v2", status = "trial", plan = "biped", joints = J, accent = Color3.fromRGB(190, 110, 255),
		-- 바이블 §5 크기 × 1.5(MonsterSpawner · 전시 리그가 S × scale) → GUARDIAN-V3 6(사용자): 서 있는 키 약 30 stud = 직립(변신 뒤) 머리 꼭대기 FK 실측
		--   × 1.92에서 28.6(Studio 28.7 ~ 29.0) → 2.0에서 29.8. K(0.40)를 바꾸면 메시를 다시 굽고 올려야 한다 - K와 scale은 둘 다 균일 배율이라 결과가 같아 scale로 맞춘다
		--   (판정 사본 · 몸 가장자리 · 모션 이동이 같이 커진다).
		scale = 2.0,
		edgeHalfWidth = K * 4.45, -- 몸 가장자리 반폭(어깨 갑옷 바깥 - 리그 단위 · BossFramework.edgeGrowth)
		baseEdgeHalfWidth = 2.1, -- 옛 몸(BossRigSpec section_guardian) 가장자리 반폭 = 어깨 1.5 + 갑옷 0.1 + 0.5
		cameraZoomScale = 1.73, -- 바이블 §5-4 카메라 줌 × 약 1.3(크기 × 1.5일 때) → GUARDIAN-V3: 크기 비례 1.3 × 2.0 ÷ 1.5 = 1.73(CameraRig)
		attach = { HandR = { part = "Hand_R", at = V(0, -0.35, 0) }, HandL = { part = "Hand_L", at = V(0, -0.35, 0) }, Mouth = { part = "Head", at = V(0, -0.3, -0.5) }, Chest = { part = "Body", at = V(0, -0.45, -0.85) },
			ShoulderR = { part = "RightPauldron", at = V(0, 0.4, 0) }, ShoulderL = { part = "LeftPauldron", at = V(0, 0.4, 0) }, Back = { part = "Crystal1", at = V(0, 0.6, 0) } },
		chains = {
			{ "TassetF", kind = "crystal", lag = 0.5, sway = 1.2 }, { "TassetB", kind = "crystal", lag = 0.5, sway = 1.2 },
			{ "Crystal1", kind = "crystal", lag = 0.3, sway = 1.5 }, { "Crystal2", kind = "crystal", lag = 0.3, sway = 1.5 }, { "Crystal3", kind = "crystal", lag = 0.3, sway = 1.5 },
			{ "Crystal4", kind = "crystal", lag = 0.3, sway = 2 }, { "Crystal5", kind = "crystal", lag = 0.3, sway = 2 },
		},
		weight = 1.15,
		meshKey = "bosses/section_guardian_v2m", -- KIT 결과(Meshy 원본 · 옛 가짜 원본 시험 = bosses/section_guardian_v2 그대로 남김)
		themeColors = { body = Color3.fromRGB(60, 20, 70), head = Color3.fromRGB(90, 30, 100), accent = Color3.fromRGB(190, 110, 255) },
		recolor = { Hips = "shadow", Shin_L = "shadow", Shin_R = "shadow", Foot_L = "stone", Foot_R = "stone", UpperArm_L = "stone", UpperArm_R = "stone" },
	}
end

-- ─────────────────────────── BOSS-NIGHT-1 공용: Meshy 실측 좌표로 부위 놓기(수호자 v2와 같은 규칙 - 그 블록은 그대로 둔다) ───────────────────────────
--   K = 실측 단위(Meshy 모델 높이 1 = "H") → 리그 단위 · P(x, z, fwd) = 오른쪽 x · 높이 z(발바닥 0) · 앞 fwd(+ = 앞 = 리그 −Z).
--   place{ name, parent, part, center, size, joint, rot(세계 도) } · seg(관절 a → 끝 b 막대) · chainPts(점 목록 → 사슬 마디).
local function placer(K)
	local L = {}
	function L.P(x, z, fwd)
		return V(K * x, K * z - 1.5, -K * fwd)
	end
	function L.Z(w, h, d)
		return V(K * w, K * h, K * d)
	end
	local function E(r)
		local cx, sx, cy, sy, cz, sz = math.cos(math.rad(r.X)), math.sin(math.rad(r.X)), math.cos(math.rad(r.Y)), math.sin(math.rad(r.Y)), math.cos(math.rad(r.Z)), math.sin(math.rad(r.Z))
		return {
			{ cy * cz, -cy * sz, sy },
			{ cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy },
			{ sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy },
		}
	end
	local function mulT(A, B)
		local M = {}
		for i = 1, 3 do
			M[i] = {}
			for j = 1, 3 do
				M[i][j] = A[1][i] * B[1][j] + A[2][i] * B[2][j] + A[3][i] * B[3][j]
			end
		end
		return M
	end
	local function applyT(A, v)
		return V(A[1][1] * v.X + A[2][1] * v.Y + A[3][1] * v.Z, A[1][2] * v.X + A[2][2] * v.Y + A[3][2] * v.Z, A[1][3] * v.X + A[2][3] * v.Y + A[3][3] * v.Z)
	end
	local function euler(M)
		local ry = math.asin(math.clamp(M[1][3], -1, 1))
		return V(math.deg(math.atan2(-M[2][3], M[3][3])), math.deg(ry), math.deg(math.atan2(-M[1][2], M[1][1])))
	end
	L.J = {}
	local world = { HumanoidRootPart = { R = E(Vector3.zero), c = Vector3.zero } }
	function L.place(o)
		local par = world[o.parent]
		local Rw = E(o.rot or Vector3.zero)
		world[o.part] = { R = Rw, c = o.center }
		return add(L.J, { name = o.name, parent = o.parent, part = o.part, size = o.size, color = o.color or "body", material = o.material, query = o.query, shape = o.shape,
			at = applyT(par.R, o.joint - par.c), pivot = applyT(Rw, o.joint - o.center), rot = euler(mulT(par.R, Rw)) })
	end
	-- 막대 마디: 관절 a → 끝 b(실측 좌표) · 단면 w × d · 세계 회전 = (0, −1, 0)을 a → b로
	function L.seg(name, parent, part, a, b, w, d, ext, color, extra)
		local pa, pb = L.P(a[1], a[2], a[3]), L.P(b[1], b[2], b[3])
		local dir = (pb - pa).Unit
		local rz = math.deg(math.asin(math.clamp(dir.X, -1, 1)))
		local rx = math.deg(math.atan2(-dir.Z, -dir.Y))
		local len = (pb - pa).Magnitude + K * (ext or 0)
		local o = { name = name, parent = parent, part = part, joint = pa, center = pa + dir * (len / 2 - K * (ext or 0) * 0.25), size = V(K * w, len, K * d), rot = V(rx, 0, rz), color = color }
		for k, v in pairs(extra or {}) do
			o[k] = v
		end
		return L.place(o)
	end
	-- 점 목록 → 사슬(prefix1 .. n): 마디 i = 점 i → 점 i + 1 · 굵기 w0 → w1
	function L.chainPts(prefix, parent, pts, w0, w1, d0, d1, color, extra)
		local prev = parent
		for i = 1, #pts - 1 do
			local u = (i - 1) / math.max(#pts - 2, 1)
			local w, d = w0 + (w1 - w0) * u, (d0 or w0) + ((d1 or w1) - (d0 or w0)) * u
			L.seg(prefix .. i, prev, prefix .. i, pts[i], pts[i + 1], w, d, 0.02, color, extra)
			prev = prefix .. i
		end
	end
	return L
end
D.placer = placer

-- ─────────────────────────── 서리 거인 → 빙하 매머드 "빙하 엄니"(BOSS-NIGHT-1 1 · Meshy 원본 실측 · 네 발) ───────────────────────────
-- 상자 · 관절 = Meshy mammoth_v1_body(remesh30k · 원본과 같은 모양) 옆 · 앞 · 위 실측(모델 높이 1 = H · 발바닥 0 · fwd + = 머리 쪽).
--   K 2.4 = 판정 사본(Body · Hips · Head) 부피 = 옛 몸 × 1.14(허용 ±20%) · scale 3.3 = 등 높이(0.85 H) 30 stud(바이블 §5 × 1.5 목표 - 수호자 V3처럼 K 대신 scale로 크기).
--   다리 = 짧고 굵은 인형 비율(보이는 다리 0.15 H) · 앞다리 Shoulder · Elbow · Wrist(Hand = 앞발) · 뒷다리 Hip · Knee · Ankle(quad 보행 이름) ·
--   코 6마디(평면 자르기 = 리그 상자) · 상아 L/R 밑동 분리 · 귀 L/R · 꼬리 3(말린 꼬리) · 등 털 3(사슬) · 등 얼음 1(낙빙 흔들림) · 이마 털 얼음 1 · 턱(자리만).
--   앞 구역(상아 · 코 · 앞발) / 뒤 구역(뒷발차기) = 판정 구역은 스킬 데이터(BossFrameworkData.v3.frost_giant).
do
	local L = placer(2.4)
	local P, Z, place, seg, chainPts = L.P, L.Z, L.place, L.seg, L.chainPts
	place({ name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", center = P(0, 0.48, -0.3), size = Z(0.6, 0.66, 0.5), joint = P(0, 0.48, -0.08), query = true })
	place({ name = "Waist", parent = "Hips", part = "Body", center = P(0, 0.5, 0.15), size = Z(0.62, 0.7, 0.42), joint = P(0, 0.5, -0.06), query = true })
	place({ name = "Neck", parent = "Body", part = "Head", center = P(0, 0.68, 0.45), size = Z(0.36, 0.4, 0.3), joint = P(0, 0.7, 0.3), color = "head", query = true })
	place({ name = "Jaw", parent = "Head", part = "Mouth", center = P(0, 0.47, 0.52), size = Z(0.08, 0.03, 0.05), joint = P(0, 0.49, 0.5), color = "mouth" })
	place({ name = "HeadIce", parent = "Head", part = "HeadIce", center = P(0, 0.91, 0.47), size = Z(0.16, 0.1, 0.14), joint = P(0, 0.86, 0.47), color = "accent" })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		place({ name = "Ear_" .. side, parent = "Head", part = "Ear_" .. side, center = P(x * 0.275, 0.58, 0.23), size = Z(0.12, 0.4, 0.3), joint = P(x * 0.2, 0.66, 0.3), color = "head" })
		seg("Tusk_" .. side, "Head", "Tusk_" .. side, { x * 0.09, 0.46, 0.55 }, { x * 0.22, 0.5, 0.88 }, 0.08, 0.16, 0.02, "light")
		-- 앞다리(앞발 = Hand) · 뒷다리(뒷발 = Foot) - 발바닥 0
		seg("Shoulder_" .. side, "Body", "UpperArm_" .. side, { x * 0.19, 0.34, 0.15 }, { x * 0.19, 0.17, 0.15 }, 0.17, 0.18, 0.02)
		seg("Elbow_" .. side, "UpperArm_" .. side, "Forearm_" .. side, { x * 0.19, 0.17, 0.15 }, { x * 0.19, 0.08, 0.15 }, 0.16, 0.17, 0.02)
		place({ name = "Wrist_" .. side, parent = "Forearm_" .. side, part = "Hand_" .. side, center = P(x * 0.19, 0.04, 0.16), size = Z(0.18, 0.08, 0.2), joint = P(x * 0.19, 0.08, 0.15), color = "dark" })
		seg("Hip_" .. side, "Hips", "Thigh_" .. side, { x * 0.19, 0.34, -0.38 }, { x * 0.19, 0.17, -0.38 }, 0.17, 0.18, 0.02)
		seg("Knee_" .. side, "Thigh_" .. side, "Shin_" .. side, { x * 0.19, 0.17, -0.38 }, { x * 0.19, 0.08, -0.38 }, 0.16, 0.17, 0.02)
		place({ name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, center = P(x * 0.19, 0.04, -0.37), size = Z(0.18, 0.08, 0.2), joint = P(x * 0.19, 0.08, -0.38), color = "dark" })
	end
	-- 코 6마디(코끝 말림까지) · 꼬리 3(말린 꼬리) · 등 털 3(등 위 판 - 사슬) · 등 얼음 덩어리
	chainPts("Trunk", "Head", { { 0, 0.56, 0.58 }, { 0, 0.46, 0.62 }, { 0, 0.36, 0.61 }, { 0, 0.27, 0.59 }, { 0, 0.19, 0.56 }, { 0, 0.12, 0.52 }, { 0, 0.05, 0.47 } }, 0.13, 0.08, 0.13, 0.08, "head")
	chainPts("Tail", "Hips", { { 0, 0.56, -0.54 }, { 0, 0.56, -0.66 }, { 0, 0.5, -0.77 }, { 0, 0.4, -0.8 } }, 0.12, 0.1, 0.2, 0.2, "body")
	place({ name = "Fur1", parent = "Body", part = "Fur1", center = P(0, 0.83, 0.14), size = Z(0.5, 0.1, 0.22), joint = P(0, 0.83, 0.25), color = "light" })
	place({ name = "Fur2", parent = "Fur1", part = "Fur2", center = P(0, 0.85, -0.1), size = Z(0.52, 0.1, 0.26), joint = P(0, 0.85, 0.03), color = "light" })
	place({ name = "Fur3", parent = "Fur2", part = "Fur3", center = P(0, 0.8, -0.36), size = Z(0.5, 0.1, 0.26), joint = P(0, 0.83, -0.23), color = "light" })
	place({ name = "BackIce", parent = "Fur2", part = "BackIce", center = P(0, 0.93, -0.17), size = Z(0.24, 0.16, 0.28), joint = P(0, 0.87, -0.17), color = "accent" })
	D.rigs.frost_giant_v2 = {
		bossId = "frost_giant", variant = "v2", status = "trial", plan = "quad", joints = L.J, accent = Color3.fromRGB(200, 240, 255),
		scale = 3.3, -- 등 높이 0.85 H × K 2.4 × S 4.455 × 3.3 = 30 stud(바이블 §5)
		edgeHalfWidth = 2.4 * 0.31, -- 몸 가장자리 반폭(옆구리 털 바깥 - 리그 단위)
		frontHalfLength = 2.4 * 0.62, rearHalfLength = 2.4 * 0.56, -- 몸 중심(루트) → 머리 · 코 앞 끝 / 엉덩이 끝(앞 구역 · 뒤 구역 반경 - BossFramework.applyV3 radiusFrom)
		baseEdgeHalfWidth = 1.6, -- 옛 몸(서리 거인 직립) 가장자리 반폭 = 몸 0.95 + 팔 0.65
		cameraZoomScale = 1.3, -- 38 → 49.4(설계 메모: 50 상한)
		attach = { HandR = { part = "Trunk6", at = V(0, -0.1, 0) }, HandL = { part = "Tusk_L", at = V(0, -0.35, 0) }, ShoulderR = { part = "Tusk_R", at = V(0, -0.35, 0) }, ShoulderL = { part = "BackIce", at = V(0, 0.2, 0) },
			Mouth = { part = "Head", at = V(0, -0.25, -0.35) }, TuskTipL = { part = "Tusk_L", at = V(0, -0.4, 0) }, TuskTipR = { part = "Tusk_R", at = V(0, -0.4, 0) }, Back = { part = "BackIce", at = V(0, 0.2, 0) } },
		chains = { { "Trunk1", "Trunk2", "Trunk3", "Trunk4", "Trunk5", "Trunk6", kind = "trunk", lag = 0.5, sway = 6 }, { "Tail1", "Tail2", "Tail3", kind = "tail", lag = 0.5, sway = 5 },
			{ "Fur1", "Fur2", "Fur3", kind = "fur", lag = 0.55, sway = 2 }, { "Ear_L", kind = "cloth", lag = 0.5, sway = 4 }, { "Ear_R", kind = "cloth", lag = 0.5, sway = 4 } },
		weight = 1.5,
		contacts = { "Foot_L", "Foot_R", "Hand_L", "Hand_R" },
		meshKey = "bosses/frost_giant_v2m",
		themeColors = { body = Color3.fromRGB(235, 240, 248), head = Color3.fromRGB(225, 232, 242), accent = Color3.fromRGB(150, 215, 255) },
	}
end

-- ─────────────────────────── 심해 군주 → 나가(초안 · 뱀 하체 12마디) ───────────────────────────
do
	local J = BossSkeleton.serpent({
		upper = { hips = V(1.5, 0.5, 1.1), torso = V(2.3, 1.6, 1.4), head = V(1.1, 0.9, 1.1), thigh = { w = 0.66, len = 0.72 }, shin = { w = 0.6, len = 0.72 }, foot = V(0.8, 0.25, 1.15),
			upperArm = { w = 0.62, len = 0.95 }, forearm = { w = 0.6, len = 0.9 }, hand = V(0.72, 0.72, 0.72), shoulderX = 1.42, stance = 0.46 },
		tail = { count = 12, length = 0.6, w0 = 1.0, w1 = 0.3, at = V(0, -0.2, 0.1), rots = { V(-15, 0, 0), V(-20, 0, 0), V(-25, 0, 0), V(-30, 0, 0), V(0, 0, 0), V(0, 0, 0), V(0, 0, 0), V(0, 0, 0), V(0, 0, 0), V(0, 0, 0), V(5, 0, 0), V(5, 0, 0) }, query = 3 },
		fin = V(0.9, 0.7, 0.12),
	})
	add(J, { name = "Fin_L", parent = "Head", part = "LeftFin", size = V(0.25, 0.8, 0.9), shape = "wedge", color = "accent", at = V(-0.6, 0.1, 0.1), pivot = V(0, -0.2, 0), rot = V(0, 0, 35) })
	add(J, { name = "Fin_R", parent = "Head", part = "RightFin", size = V(0.25, 0.8, 0.9), shape = "wedge", color = "accent", at = V(0.6, 0.1, 0.1), pivot = V(0, -0.2, 0), rot = V(0, 0, -35) })
	add(J, { name = "Crest", parent = "Body", part = "BackFin", size = V(0.25, 1.1, 1.2), shape = "wedge", color = "accent", at = V(0, 0.4, 0.7), pivot = V(0, -0.3, 0), rot = V(0, 180, 0) })
	for i, x in ipairs({ -0.3, 0, 0.3 }) do
		chain(J, { prefix = "Hair" .. i .. "_", parent = "Head", count = 1, length = 0.7, w0 = 0.25, w1 = 0.25, thick = 0.06, at = V(x, 0.3, 0.45), rot0 = V(-40, 0, x * 30), rotStep = V(0, 0, 0), color = "accent" })
	end
	add(J, { name = "Trident", parent = "Hand_R", part = "Trident", size = V(0.22, 4.2, 0.22), shape = "cyl", color = "accent", at = V(0, -0.3, 0), pivot = V(0, -0.6, 0) })
	add(J, { name = "TridentHead", parent = "Trident", part = "TridentHead", size = V(0.9, 0.7, 0.15), shape = "wedge", color = "accent", material = "Neon", at = V(0, 2.1, 0), pivot = V(0, -0.35, 0) })
	local tail = { kind = "tail", lag = 0.45, sway = 6 }
	for i = 1, 12 do
		tail[i] = "Tail" .. i
	end
	D.rigs.abyssal_lord_v2 = {
		bossId = "abyssal_lord", variant = "v2", status = "draft", plan = "serpent", joints = J, accent = Color3.fromRGB(60, 200, 255),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.4, 0) }, HandL = { part = "Hand_L", at = V(0, -0.4, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.55) }, TailTip = { part = "Tail12", at = V(0, -0.3, 0) } },
		chains = { tail, { "Hair1_1", kind = "fur", lag = 0.4, sway = 4 }, { "Hair2_1", kind = "fur", lag = 0.4, sway = 4 }, { "Hair3_1", kind = "fur", lag = 0.4, sway = 4 } },
		weight = 1.1,
		contacts = { { part = "Tail5", at = V(0, 0, -0.37) }, { part = "Tail8", at = V(0, 0, -0.29) }, { part = "Tail11", at = V(0, 0, -0.2) } }, -- 누운 꼬리 = 배 쪽(마디 국소 −Z)
	}
end

-- ─────────────────────────── 수정 여왕 → 수정 나비 여왕(초안 · 날개 4장 × 2마디 · 떠 있음) ───────────────────────────
do
	local J = BossSkeleton.biped({
		hips = V(1.2, 0.5, 0.9), torso = V(1.5, 1.7, 0.9), head = V(0.9, 0.95, 0.9), headShape = "ball",
		thigh = { w = 0.5, len = 0.9 }, shin = { w = 0.45, len = 0.9 }, foot = V(0.55, 0.25, 0.9),
		upperArm = { w = 0.45, len = 0.95 }, forearm = { w = 0.42, len = 0.9 }, hand = V(0.5, 0.6, 0.5), shoulderX = 0.95, stance = 0.35,
	})
	for i, s in ipairs({ { "F", V(0, 0, -0.45), V(12, 0, 0) }, { "B", V(0, 0, 0.45), V(-12, 0, 0) }, { "L", V(-0.6, 0, 0), V(0, 0, -12) }, { "R", V(0.6, 0, 0), V(0, 0, 12) } }) do
		chain(J, { prefix = "Skirt" .. s[1], parent = "Hips", count = 2, length = 0.75, w0 = i <= 2 and 1.25 or 0.95, w1 = i <= 2 and 1.35 or 1.05, at = s[2] + V(0, -0.1, 0), rot0 = s[3], rotStep = s[3] * 0.5, color = "head", tipColor = "accent", tipMaterial = "Glass" })
	end
	add(J, { name = "Crown", parent = "Head", part = "Crown", size = V(0.8, 0.5, 0.8), shape = "cyl", color = "accent", material = "Neon", at = V(0, 0.5, 0), pivot = V(0, -0.2, 0), rot = V(0, 0, 90) })
	BossSkeleton.wings(J, "Body", {
		{ tag = "F", at = V(0.35, 0.55, 0.45), rot0 = V(-10, -30, 55), rotStep = V(0, 0, 10), count = 2, length = 1.1, w0 = 1.1, w1 = 0.9 },
		{ tag = "B", at = V(0.3, 0.1, 0.45), rot0 = V(-15, -35, 105), rotStep = V(0, 0, 8), count = 2, length = 0.9, w0 = 0.9, w1 = 0.7 },
	}, "accent", "Glass")
	add(J, { name = "Antenna_L", parent = "Head", part = "Antenna_L", size = V(0.06, 0.7, 0.06), color = "accent", at = V(-0.2, 0.4, -0.2), pivot = V(0, -0.35, 0), rot = V(25, 0, -20) })
	add(J, { name = "Antenna_R", parent = "Head", part = "Antenna_R", size = V(0.06, 0.7, 0.06), color = "accent", at = V(0.2, 0.4, -0.2), pivot = V(0, -0.35, 0), rot = V(25, 0, 20) })
	add(J, { name = "ChestGem", parent = "Body", part = "ChestGem", size = V(0.4, 0.4, 0.2), shape = "ball", color = "accent", material = "Neon", at = V(0, 0.3, -0.45), pivot = V(0, 0, 0) })
	add(J, { name = "Scepter", parent = "Hand_R", part = "Scepter", size = V(0.18, 2.4, 0.18), shape = "cyl", color = "head", at = V(0, -0.25, 0), pivot = V(0, -0.5, 0) })
	add(J, { name = "ScepterGem", parent = "Scepter", part = "ScepterGem", size = V(0.5, 0.5, 0.5), shape = "ball", color = "accent", material = "Neon", at = V(0, 1.25, 0), pivot = V(0, 0, 0) })
	local chains = {}
	for _, w in ipairs({ "WingF_L", "WingF_R", "WingB_L", "WingB_R" }) do
		table.insert(chains, { w .. "1", w .. "2", kind = "wing", lag = 0.4, sway = 3 })
	end
	for _, s in ipairs({ "F", "B", "L", "R" }) do
		table.insert(chains, { "Skirt" .. s .. "1", "Skirt" .. s .. "2", kind = "cloth", lag = 0.4, sway = 3 })
	end
	table.insert(chains, { "Antenna_L", kind = "fur", lag = 0.3, sway = 5 })
	table.insert(chains, { "Antenna_R", kind = "fur", lag = 0.3, sway = 5 })
	D.rigs.crystal_queen_v2 = {
		bossId = "crystal_queen", variant = "v2", status = "draft", plan = "biped", joints = J, accent = Color3.fromRGB(150, 240, 255),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.3, 0) }, HandL = { part = "Hand_L", at = V(0, -0.3, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.45) }, Gem = { part = "ScepterGem", at = V(0, 0, 0) } },
		chains = chains, weight = 0.8,
	}
end

-- ─────────────────────────── 폭풍 군주 → 폭풍 기사 · 50% 비행 변신(BOSS-NIGHT-1 2 · Meshy 몸 + 부품 9 · 바이블 §2-5 · §10 · STORM-PARTS) ───────────────────────────
-- 상자 · 관절 = Meshy storm_v1_body(A-포즈 · 망토 없음) 정면 · 옆 실측(높이 1 = H · 발바닥 0 · fwd + = 앞). K 7.2 = 판정 사본(Body · Head) 부피 = 옛 몸 × 1.07 · scale 1.15 = 키 31 stud(§5).
--   1폼 = 몸 + 어깨 갑옷 · 번개 칼날(Pauldron_L/R) + 구름 깃(Plume) + 망토 4갈래 × 4마디(CapeA ~ D) + 지팡이 · 지팡이 보주(고리째 - 떨어져 떠다님).
--   2폼 = 망토 · 지팡이 · 1폼 어깨 · 아래팔 · 손 · 구름 깃 숨김 → 날개(Wing_L1 · L2 · R1 · R2) · 번개 왕관(Crown) · 가슴 코어(ChestCore) · 2폼 어깨(Pauldron2_L/R) · 건틀릿(Gauntlet_L/R - 아래팔 + 주먹)이 날아와 붙음.
--   부품 GLB → 상자 맞춤 = rigs/storm_lord_v2.kit.json(addons) · 보이기 전환 = BossClipSetData.storm_lord_v2.formParts(클라).
do
	local L = placer(7.2)
	local P, Z, place, seg, chainPts = L.P, L.Z, L.place, L.seg, L.chainPts
	place({ name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", center = P(0, 0.47, 0), size = Z(0.22, 0.1, 0.12), joint = P(0, 0.49, 0), color = "dark" })
	place({ name = "Waist", parent = "Hips", part = "Body", center = P(0, 0.62, 0), size = Z(0.24, 0.3, 0.13), joint = P(0, 0.52, 0), query = true })
	place({ name = "Neck", parent = "Body", part = "Head", center = P(0, 0.85, 0.005), size = Z(0.13, 0.14, 0.13), joint = P(0, 0.79, 0), color = "head", query = true })
	place({ name = "Plume", parent = "Head", part = "Plume", center = P(0, 0.95, 0), size = Z(0.18, 0.11, 0.14), joint = P(0, 0.91, 0), color = "accent" })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		seg("Hip_" .. side, "Hips", "Thigh_" .. side, { x * 0.055, 0.47, 0 }, { x * 0.055, 0.3, 0.005 }, 0.09, 0.09, 0.02)
		seg("Knee_" .. side, "Thigh_" .. side, "Shin_" .. side, { x * 0.055, 0.3, 0.005 }, { x * 0.06, 0.07, 0 }, 0.08, 0.08, 0.02, "dark")
		place({ name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, center = P(x * 0.06, 0.035, 0.065), size = Z(0.08, 0.07, 0.17), joint = P(x * 0.06, 0.07, 0), color = "dark" })
		seg("Shoulder_" .. side, "Body", "UpperArm_" .. side, { x * 0.15, 0.71, 0 }, { x * 0.225, 0.6, 0 }, 0.07, 0.07, 0.02)
		seg("Elbow_" .. side, "UpperArm_" .. side, "Forearm_" .. side, { x * 0.225, 0.6, 0 }, { x * 0.28, 0.52, 0 }, 0.065, 0.065, 0.02)
		seg("Wrist_" .. side, "Forearm_" .. side, "Hand_" .. side, { x * 0.28, 0.52, 0 }, { x * 0.305, 0.45, 0 }, 0.06, 0.05, 0.01)
		place({ name = "Pauldron_" .. side, parent = "UpperArm_" .. side, part = side == "L" and "LeftPauldron" or "RightPauldron", center = P(x * 0.17, 0.775, 0), size = Z(0.11, 0.23, 0.12), joint = P(x * 0.15, 0.71, 0), color = "head" })
		-- 2폼(숨김으로 시작): 어깨 · 건틀릿(아래팔 + 주먹 - 팔꿈치 관 자름)
		place({ name = "Pauldron2_" .. side, parent = "UpperArm_" .. side, part = "Pauldron2_" .. side, center = P(x * 0.185, 0.765, 0), size = Z(0.14, 0.17, 0.14), joint = P(x * 0.15, 0.71, 0), color = "head" })
		seg("Gauntlet_" .. side, "Forearm_" .. side, "Gauntlet_" .. side, { x * 0.225, 0.6, 0 }, { x * 0.31, 0.43, 0 }, 0.09, 0.09, 0.02, "head")
	end
	-- 로브(허리 갑옷 앞 · 뒤)
	place({ name = "RobeF", parent = "Hips", part = "RobeF", center = P(0, 0.445, 0.05), size = Z(0.22, 0.15, 0.04), joint = P(0, 0.52, 0.045), color = "body" })
	place({ name = "RobeB", parent = "Hips", part = "RobeB", center = P(0, 0.445, -0.05), size = Z(0.22, 0.15, 0.04), joint = P(0, 0.52, -0.045), color = "body" })
	-- 망토 4갈래 × 4마디(등 어깨 뒤 → 발목 위) - 1폼
	for i, x in ipairs({ -0.16, -0.055, 0.055, 0.16 }) do
		local tag = ({ "A", "B", "C", "D" })[i]
		chainPts("Cape" .. tag, "Body", { { x, 0.77, -0.085 }, { x * 1.05, 0.6, -0.1 }, { x * 1.1, 0.43, -0.11 }, { x * 1.15, 0.27, -0.12 }, { x * 1.2, 0.1, -0.13 } }, 0.105, 0.11, 0.06, 0.06, "dark")
	end
	-- 지팡이(오른손 · 땅 짚는 높이) + 보주(고리째)
	place({ name = "Staff", parent = "Hand_R", part = "Staff", center = P(0.31, 0.4, 0.03), size = Z(0.06, 0.66, 0.06), joint = P(0.305, 0.47, 0.02), color = "dark" })
	place({ name = "StaffOrb", parent = "Staff", part = "StaffOrb", center = P(0.31, 0.8, 0.03), size = Z(0.2, 0.14, 0.12), joint = P(0.31, 0.74, 0.03), color = "accent" })
	-- 2폼: 왕관 · 가슴 코어 · 날개 2 × 2
	place({ name = "Crown", parent = "Head", part = "Crown", center = P(0, 0.935, 0), size = Z(0.19, 0.15, 0.16), joint = P(0, 0.9, 0), color = "accent" })
	place({ name = "ChestCore", parent = "Body", part = "ChestCore", center = P(0, 0.66, 0.08), size = Z(0.16, 0.18, 0.03), joint = P(0, 0.66, 0.07), color = "accent" })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		place({ name = "Wing_" .. side .. "1", parent = "Body", part = "Wing_" .. side .. "1", center = P(x * 0.15, 0.82, -0.12), size = Z(0.22, 0.5, 0.06), joint = P(x * 0.05, 0.72, -0.1), color = "accent" })
		place({ name = "Wing_" .. side .. "2", parent = "Wing_" .. side .. "1", part = "Wing_" .. side .. "2", center = P(x * 0.4, 0.82, -0.13), size = Z(0.28, 0.5, 0.06), joint = P(x * 0.26, 0.82, -0.12), color = "accent" })
	end
	local cape = {}
	for _, tag in ipairs({ "A", "B", "C", "D" }) do
		table.insert(cape, { "Cape" .. tag .. "1", "Cape" .. tag .. "2", "Cape" .. tag .. "3", "Cape" .. tag .. "4", kind = "cape", lag = 0.5, sway = 5 })
	end
	table.insert(cape, { "Wing_L1", "Wing_L2", kind = "wing", lag = 0.4, sway = 3 })
	table.insert(cape, { "Wing_R1", "Wing_R2", kind = "wing", lag = 0.4, sway = 3 })
	table.insert(cape, { "RobeF", kind = "cloth", lag = 0.4, sway = 2 })
	table.insert(cape, { "RobeB", kind = "cloth", lag = 0.4, sway = 2 })
	D.rigs.storm_lord_v2 = {
		bossId = "storm_lord", variant = "v2", status = "trial", plan = "biped", joints = L.J, accent = Color3.fromRGB(255, 240, 90),
		scale = 1.15, -- 키 1 H × K 7.2 × S 3.75 × 1.15 = 31 stud(바이블 §5)
		edgeHalfWidth = 7.2 * 0.2, -- 몸 가장자리 반폭(어깨 갑옷 바깥)
		baseEdgeHalfWidth = 1.35, -- 옛 몸(폭풍 군주 직립) = 어깨 1.05 + 팔 0.3
		cameraZoomScale = 1.3,
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0, 0.2, 0) }, ShoulderL = { part = "UpperArm_L", at = V(0, 0.2, 0) }, HandR = { part = "Hand_R", at = V(0, -0.2, 0) }, HandL = { part = "Hand_L", at = V(0, -0.2, 0) },
			Mouth = { part = "Head", at = V(0, -0.2, -0.45) }, Orb = { part = "StaffOrb", at = V(0, 0, 0) }, FistR = { part = "Gauntlet_R", at = V(0, -0.5, 0) }, FistL = { part = "Gauntlet_L", at = V(0, -0.5, 0) } },
		chains = cape, weight = 1.0,
		meshKey = "bosses/storm_lord_v2m",
		themeColors = { body = Color3.fromRGB(40, 50, 90), head = Color3.fromRGB(190, 200, 215), accent = Color3.fromRGB(255, 225, 90) },
	}
end

return D
