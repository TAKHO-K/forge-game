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
local function stick(J, name, parent, size, center, rot, color, material, shape)
	local R = CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	local base = center - R:VectorToWorldSpace(V(0, size.Y / 2, 0))
	return add(J, { name = name, parent = parent, part = name, size = size, shape = shape, color = color, material = material, at = base, pivot = V(0, -size.Y / 2, 0), rot = rot })
end

-- ─────────────────────────── 구간 수호자 → 너클 보행 수정 골렘(시험) ───────────────────────────
-- 뼈대 = 옛 이족 17 그대로(치수 같음 - 판정 사본 부피 1.00) + 어깨 갑옷 L/R · 가슴 룬 · 허리 갑옷 앞/뒤 · 등 수정 5 · 머리 수정 왕관 · 눈썹 바위 · 턱 바위 = 30관절.
--   깃발 3마디 × 2 → 등 수정으로 대체(네 발 자세에서 깃발이 땅에 끌림 - 바이블 §2-1).
do
	local J = BossSkeleton.biped({
		hips = V(1.6, 0.5, 1.0), torso = V(2.4, 1.7, 1.3), head = V(1.1, 0.95, 1.0),
		thigh = { w = 0.75, len = 0.8 }, shin = { w = 0.7, len = 0.8 }, foot = V(0.8, 0.3, 1.1),
		upperArm = { w = 0.75, len = 1.0 }, forearm = { w = 0.8, len = 0.95 }, hand = V(1.05, 1.0, 1.05), shoulderX = 1.5, stance = 0.5,
	})
	add(J, { name = "Pauldron_L", parent = "UpperArm_L", part = "LeftPauldron", size = V(1.0, 0.5, 1.15), color = "head", at = V(-0.1, 0.45, 0), pivot = V(0, 0, 0) })
	add(J, { name = "Pauldron_R", parent = "UpperArm_R", part = "RightPauldron", size = V(1.0, 0.5, 1.15), color = "head", at = V(0.1, 0.45, 0), pivot = V(0, 0, 0) })
	add(J, { name = "Rune", parent = "Body", part = "Rune", size = V(0.7, 0.7, 0.08), color = "accent", material = "Neon", at = V(0, 0.2, -0.66), pivot = V(0, 0, 0) })
	add(J, { name = "TassetF", parent = "Hips", part = "TassetF", size = V(1.05, 0.7, 0.16), color = "slab", at = V(0, -0.16, -0.56), pivot = V(0, 0.34, 0), rot = V(-6, 0, 0) })
	add(J, { name = "TassetB", parent = "Hips", part = "TassetB", size = V(1.05, 0.7, 0.16), color = "slab", at = V(0, -0.16, 0.56), pivot = V(0, 0.34, 0), rot = V(6, 0, 0) })
	-- 등 수정 5(가운데 큰 것 · 양옆 · 작은 끝 - 옛 장식 자리 그대로 · 50% 변신에 터짐)
	stick(J, "Crystal1", "Body", V(0.46, 1.7, 0.46), V(0, 0.7, 0.86), V(-22, 45, 0), "accent", "Glass")
	stick(J, "Crystal2", "Body", V(0.36, 1.2, 0.36), V(-0.6, 0.45, 0.8), V(-16, 45, 24), "accent", "Glass")
	stick(J, "Crystal3", "Body", V(0.36, 1.2, 0.36), V(0.6, 0.45, 0.8), V(-16, -45, -24), "accent", "Glass")
	stick(J, "Crystal4", "Body", V(0.26, 0.7, 0.26), V(-0.95, 0.1, 0.72), V(-10, 45, 40), "accent", "Glass")
	stick(J, "Crystal5", "Body", V(0.26, 0.7, 0.26), V(0.95, 0.1, 0.72), V(-10, -45, -40), "accent", "Glass")
	stick(J, "Crown", "Head", V(0.3, 0.85, 0.3), V(0, 0.78, 0.05), V(0, 45, 0), "accent", "Glass")
	add(J, { name = "Brow", parent = "Head", part = "Brow", size = V(1.2, 0.26, 0.34), color = "slab", at = V(0, 0.36, -0.3), pivot = V(0, 0.1, 0.14), rot = V(-12, 0, 0) })
	add(J, { name = "Chin", parent = "Head", part = "Chin", size = V(0.96, 0.26, 0.38), color = "stone", at = V(0, -0.27, -0.13), pivot = V(0, 0.13, 0.19), rot = V(8, 0, 0) })
	D.rigs.section_guardian_v2 = {
		bossId = "section_guardian", variant = "v2", status = "trial", plan = "biped", joints = J, accent = Color3.fromRGB(190, 110, 255),
		attach = { HandR = { part = "Hand_R", at = V(0, -0.5, 0) }, HandL = { part = "Hand_L", at = V(0, -0.5, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.5) }, Chest = { part = "Body", at = V(0, 0.2, -0.7) },
			ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.9, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.9, 0) }, Back = { part = "Crystal1", at = V(0, 0.85, 0) } },
		chains = {
			{ "TassetF", kind = "cloth", lag = 0.55, sway = 2.5 }, { "TassetB", kind = "cloth", lag = 0.55, sway = 2.5 },
			{ "Crystal1", kind = "crystal", lag = 0.3, sway = 1.5 }, { "Crystal2", kind = "crystal", lag = 0.3, sway = 1.5 }, { "Crystal3", kind = "crystal", lag = 0.3, sway = 1.5 },
			{ "Crystal4", kind = "crystal", lag = 0.3, sway = 2 }, { "Crystal5", kind = "crystal", lag = 0.3, sway = 2 },
		},
		weight = 1.0,
		meshKey = "bosses/section_guardian_v2", -- KIT 결과(없으면 상자 리그 그대로)
		themeColors = { body = Color3.fromRGB(60, 20, 70), head = Color3.fromRGB(90, 30, 100), accent = Color3.fromRGB(190, 110, 255) },
		recolor = { Hips = "shadow", Shin_L = "shadow", Shin_R = "shadow", Foot_L = "stone", Foot_R = "stone", UpperArm_L = "stone", UpperArm_R = "stone" },
	}
end

-- ─────────────────────────── 서리 거인 → 빙하 매머드(초안 · 네 발) ───────────────────────────
do
	local J = BossSkeleton.quadruped({
		hips = V(1.7, 1.3, 1.3), body = V(1.9, 1.6, 1.6), chest = V(1.8, 1.7, 1.1), head = V(1.0, 1.0, 0.9), neckY = 0.35,
		legFront = { upper = 0.95, lower = 0.85, foot = V(0.7, 0.3, 0.7), w = 0.62 }, legRear = { upper = 0.9, lower = 0.8, foot = V(0.7, 0.3, 0.7), w = 0.62 },
		stanceX = 0.62, rearZ = 1.1,
	})
	add(J, { name = "Ear_L", parent = "Head", part = "Ear_L", size = V(0.1, 0.8, 0.7), color = "head", at = V(-0.5, 0.15, 0.15), pivot = V(0, 0.3, 0), rot = V(0, 0, -20) })
	add(J, { name = "Ear_R", parent = "Head", part = "Ear_R", size = V(0.1, 0.8, 0.7), color = "head", at = V(0.5, 0.15, 0.15), pivot = V(0, 0.3, 0), rot = V(0, 0, 20) })
	chain(J, { prefix = "Trunk", parent = "Head", count = 6, length = 0.32, w0 = 0.42, w1 = 0.18, at = V(0, -0.2, -0.45), rot0 = V(10, 0, 0), rotStep = V(-6, 0, 0), color = "head" })
	add(J, { name = "Tusk_L", parent = "Head", part = "Tusk_L", size = V(0.16, 1.2, 0.16), color = "light", at = V(-0.3, -0.3, -0.35), pivot = V(0, 0.6, 0), rot = V(60, 0, -10) })
	add(J, { name = "Tusk_R", parent = "Head", part = "Tusk_R", size = V(0.16, 1.2, 0.16), color = "light", at = V(0.3, -0.3, -0.35), pivot = V(0, 0.6, 0), rot = V(60, 0, 10) })
	chain(J, { prefix = "Tail", parent = "Hips", count = 3, length = 0.3, w0 = 0.2, w1 = 0.1, at = V(0, 0.3, 0.65), rot0 = V(-20, 0, 0), rotStep = V(-5, 0, 0), color = "body" })
	chain(J, { prefix = "Fur", parent = "Body", count = 3, length = 0.5, w0 = 1.8, w1 = 1.9, thick = 0.15, at = V(0, 0.8, 0.2), rot0 = V(-90, 0, 0), rotStep = V(8, 0, 0), color = "light", material = "Fabric" })
	for i, x in ipairs({ -0.35, 0, 0.35 }) do
		stick(J, "Ice" .. i, "Chest", V(0.22, 0.7, 0.22), V(x, 1.05, 0.1), V(-10, 45, x * 40), "accent", "Ice")
	end
	D.rigs.frost_giant_v2 = {
		bossId = "frost_giant", variant = "v2", status = "draft", plan = "quad", joints = J, accent = Color3.fromRGB(200, 240, 255),
		attach = { HandR = { part = "Trunk6", at = V(0, -0.2, 0) }, HandL = { part = "Tusk_L", at = V(0, -0.6, 0) }, ShoulderR = { part = "Tusk_R", at = V(0, -0.6, 0) }, ShoulderL = { part = "Chest", at = V(0, 0.9, 0) }, Mouth = { part = "Head", at = V(0, -0.3, -0.45) } },
		chains = { { "Trunk1", "Trunk2", "Trunk3", "Trunk4", "Trunk5", "Trunk6", kind = "trunk", lag = 0.5, sway = 6 }, { "Tail1", "Tail2", "Tail3", kind = "tail", lag = 0.5, sway = 5 },
			{ "Fur1", "Fur2", "Fur3", kind = "fur", lag = 0.55, sway = 2 }, { "Ear_L", kind = "cloth", lag = 0.5, sway = 4 }, { "Ear_R", kind = "cloth", lag = 0.5, sway = 4 } },
		weight = 1.4,
		contacts = { "Foot_L", "Foot_R", "Hand_L", "Hand_R" },
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

-- ─────────────────────────── 폭풍 군주 → 폭풍 기사(초안 · 망토 4 × 2 = 변신 때 날개) ───────────────────────────
do
	local J = BossSkeleton.biped({
		hips = V(1.3, 0.5, 0.9), torso = V(1.7, 1.8, 1.0), head = V(0.95, 1.0, 0.95),
		thigh = { w = 0.55, len = 0.95 }, shin = { w = 0.5, len = 0.95 }, foot = V(0.6, 0.25, 0.95),
		upperArm = { w = 0.5, len = 1.0 }, forearm = { w = 0.48, len = 0.95 }, hand = V(0.55, 0.6, 0.55), shoulderX = 1.05, stance = 0.38,
	})
	add(J, { name = "Blade_L", parent = "Body", part = "LeftBlade", size = V(0.3, 1.5, 0.3), shape = "wedge", color = "accent", at = V(-0.95, 0.9, 0), pivot = V(0, -0.6, 0), rot = V(0, 0, 15) })
	add(J, { name = "Blade_R", parent = "Body", part = "RightBlade", size = V(0.3, 1.5, 0.3), shape = "wedge", color = "accent", at = V(0.95, 0.9, 0), pivot = V(0, -0.6, 0), rot = V(0, 180, 15) })
	add(J, { name = "Plume", parent = "Head", part = "Plume", size = V(0.15, 0.9, 0.5), shape = "wedge", color = "accent", at = V(0, 0.5, 0.1), pivot = V(0, -0.4, 0), rot = V(-20, 0, 0) })
	chain(J, { prefix = "CapeL", parent = "Body", count = 4, length = 0.7, w0 = 0.8, w1 = 1.0, thick = 0.08, at = V(-0.42, 0.8, 0.55), rot0 = V(-6, 0, 0), rotStep = V(-3, 0, 0), color = "dark" })
	chain(J, { prefix = "CapeR", parent = "Body", count = 4, length = 0.7, w0 = 0.8, w1 = 1.0, thick = 0.08, at = V(0.42, 0.8, 0.55), rot0 = V(-6, 0, 0), rotStep = V(-3, 0, 0), color = "dark" })
	chain(J, { prefix = "RobeF", parent = "Hips", count = 2, length = 0.55, w0 = 0.9, w1 = 0.95, thick = 0.08, at = V(0, -0.15, -0.48), rot0 = V(-4, 0, 0), rotStep = V(-2, 0, 0), color = "body" })
	chain(J, { prefix = "RobeB", parent = "Hips", count = 2, length = 0.55, w0 = 0.9, w1 = 0.95, thick = 0.08, at = V(0, -0.15, 0.48), rot0 = V(4, 0, 0), rotStep = V(2, 0, 0), color = "body" })
	add(J, { name = "Staff", parent = "Hand_R", part = "Staff", size = V(0.25, 4.6, 0.25), shape = "cyl", color = "dark", at = V(0, -0.3, 0), pivot = V(0, -0.4, 0) })
	add(J, { name = "StaffOrb", parent = "Staff", part = "StaffOrb", size = V(0.7, 0.7, 0.7), shape = "ball", color = "accent", material = "Neon", at = V(0, 2.35, 0), pivot = V(0, 0, 0) })
	D.rigs.storm_lord_v2 = {
		bossId = "storm_lord", variant = "v2", status = "draft", plan = "biped", joints = J, accent = Color3.fromRGB(255, 240, 90),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.3, 0) }, HandL = { part = "Hand_L", at = V(0, -0.3, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.5) }, Orb = { part = "StaffOrb", at = V(0, 0, 0) } },
		chains = { { "CapeL1", "CapeL2", "CapeL3", "CapeL4", kind = "cape", lag = 0.5, sway = 5 }, { "CapeR1", "CapeR2", "CapeR3", "CapeR4", kind = "cape", lag = 0.5, sway = 5 },
			{ "RobeF1", "RobeF2", kind = "cloth", lag = 0.45, sway = 3 }, { "RobeB1", "RobeB2", kind = "cloth", lag = 0.45, sway = 3 }, { "Plume", kind = "fur", lag = 0.4, sway = 4 } },
		weight = 0.9,
	}
end

-- 전갈 여왕 = 몸 구조 유지(바이블 §2-4 - 옛 51관절 그대로 · 외곽선 껍데기만 KIT로 추가) → v2 리그 없음.

return D
