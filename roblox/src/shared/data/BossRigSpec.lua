-- BR1-4b 보스 리그 규격(4b-1). 보스마다 부위(파트) · 관절(Motor6D 이름 · 계층) · 기준 자세 · 부착점 · 2차 움직임 사슬.
--   모션(shared/data/BossMotionData)은 **관절 이름으로만** 부위를 가리킨다 → A2에서 카툰 모델(메시)로 바꿔도 관절 이름 · 계층만 지키면 모션을 그대로 쓴다.
--   방식 = A1 리그 게이트(파트 + Motor6D · 클라가 Motor6D.Transform으로 절차 모션 - 업로드 없음). 루트(HumanoidRootPart)는 지금처럼 서버가 Anchored로 옮긴다(판정 위치 = 계산값 그대로) ·
--   나머지 부위는 Anchored 끔 + Motor6D로 루트에 묶인다(루트가 고정이라 물리 시뮬레이션 없음) · 부위는 전부 CanCollide · CanTouch 끔(판정 = 거리 기반 - 옛 몸통과 같다) ·
--   Body(몸통) · Head(머리) 이름은 그대로 둔다(조준 · 피해 숫자 · 이름표 · 색 바꾸기가 이 이름을 찾는다). 새 부위는 CanQuery도 끔(광선 판정에 새로 끼지 않게).
-- 단위: 좌표 · 크기는 sizeScale 1 기준(모델을 지을 때 BossData sizeScale을 곱한다). 루트 = (0, 0, 0) · 발바닥 = y −1.5(옛 몸통 바닥과 같은 자리) · 앞 = −Z.
-- 관절 표 = { name(Motor6D 이름), parent(부모 파트 이름), part(자식 파트 이름), size, shape("block" | "ball" | "wedge" | "cyl"), color("body" | "head" | "dark" | "accent" | "eye" | "mouth"),
--   material(선택 - "Neon" 등), at(부모 파트 공간의 관절 자리), pivot(자식 파트 공간의 관절 자리), rot(기준 자세 - 관절에서 자식이 돌아간 각 · 도), query(true = CanQuery 유지) }.
-- 모션 각 부호(A1 실측): 아래로 늘어진 부위를 X축 +θ 돌리면 앞으로 든다 · 무릎을 굽히면 X −θ · 허리 앞 숙임 X −θ · 고개 숙임 X −θ.
local BossRigSpec = {}

local V = Vector3.new

-- 두 발 몸 · 사슬 = shared/BossSkeleton(BOSS-FRAMEWORK 1 - 식 그대로 옮김 · 새 몸 구조 생성기와 같이 쓴다)
local BossSkeleton = require(script.Parent.Parent.BossSkeleton)
local biped, chain = BossSkeleton.biped, BossSkeleton.chain

local function add(J, j)
	table.insert(J, j)
	return J
end

-- ─────────────────────────── 보스 6종 ───────────────────────────
BossRigSpec.rigs = {}

-- 구간 수호자: 돌 골렘 - 굵은 팔 · 큰 주먹 · 어깨 갑주 · 가슴 룬(보스색 빛).
do
	local J = biped({
		hips = V(1.6, 0.5, 1.0), torso = V(2.4, 1.7, 1.3), head = V(1.1, 0.95, 1.0),
		thigh = { w = 0.75, len = 0.8 }, shin = { w = 0.7, len = 0.8 }, foot = V(0.8, 0.3, 1.1),
		upperArm = { w = 0.75, len = 1.0 }, forearm = { w = 0.8, len = 0.95 }, hand = V(1.05, 1.0, 1.05), shoulderX = 1.5, stance = 0.5,
	})
	add(J, { name = "Pauldron_L", parent = "UpperArm_L", part = "LeftPauldron", size = V(1.0, 0.5, 1.15), color = "head", at = V(-0.1, 0.45, 0), pivot = V(0, 0, 0) })
	add(J, { name = "Pauldron_R", parent = "UpperArm_R", part = "RightPauldron", size = V(1.0, 0.5, 1.15), color = "head", at = V(0.1, 0.45, 0), pivot = V(0, 0, 0) })
	add(J, { name = "Rune", parent = "Body", part = "Rune", size = V(0.7, 0.7, 0.08), color = "accent", material = "Neon", at = V(0, 0.2, -0.66), pivot = V(0, 0, 0) })
	BossRigSpec.rigs.section_guardian = {
		plan = "biped", joints = J, accent = Color3.fromRGB(190, 110, 255),
		attach = { HandR = { part = "Hand_R", at = V(0, -0.5, 0) }, HandL = { part = "Hand_L", at = V(0, -0.5, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.5) }, Chest = { part = "Body", at = V(0, 0.2, -0.7) },
			ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.9, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.9, 0) } },
		chains = {},
		weight = 1.0, -- 무게감(모션 전조 · 히트스톱 배율)
	}
end

-- 서리 거인: 크고 느린 거인 - 뿔 · 얼음 수염(2차 움직임) · 오른손 얼음 곤봉.
do
	local J = biped({
		hips = V(1.4, 0.5, 0.9), torso = V(1.9, 1.9, 1.15), head = V(1.0, 1.0, 1.0),
		thigh = { w = 0.62, len = 1.0 }, shin = { w = 0.56, len = 1.0 }, foot = V(0.72, 0.3, 1.0),
		upperArm = { w = 0.58, len = 1.05 }, forearm = { w = 0.58, len = 1.0 }, hand = V(0.72, 0.8, 0.72), shoulderX = 1.22, stance = 0.42,
	})
	add(J, { name = "Horn_L", parent = "Head", part = "LeftHorn", size = V(0.3, 1.0, 0.3), shape = "wedge", color = "accent", at = V(-0.45, 0.45, 0), pivot = V(0, -0.45, 0), rot = V(0, 0, 25) })
	add(J, { name = "Horn_R", parent = "Head", part = "RightHorn", size = V(0.3, 1.0, 0.3), shape = "wedge", color = "accent", at = V(0.45, 0.45, 0), pivot = V(0, -0.45, 0), rot = V(0, 180, 25) })
	chain(J, { prefix = "Beard", parent = "Head", count = 3, length = 0.38, w0 = 0.62, w1 = 0.3, flat = 1.1, at = V(0, -0.45, -0.3), rot0 = V(-8, 0, 0), rotStep = V(-6, 0, 0), color = "accent" })
	add(J, { name = "Club", parent = "Hand_R", part = "IceClub", size = V(0.55, 2.6, 0.55), shape = "cyl", color = "accent", material = "Ice", at = V(0, -0.35, 0), pivot = V(0, 0.9, 0) })
	BossRigSpec.rigs.frost_giant = {
		plan = "biped", joints = J, accent = Color3.fromRGB(200, 240, 255),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.4, 0) }, HandL = { part = "Hand_L", at = V(0, -0.4, 0) }, Mouth = { part = "Head", at = V(0, -0.25, -0.5) }, ClubTip = { part = "IceClub", at = V(0, 1.3, 0) } },
		chains = { { "Beard1", "Beard2", "Beard3", lag = 0.55, sway = 4 } },
		weight = 1.4,
	}
end

-- 심해 군주: 인어 군주 - 머리 지느러미 · 뒤로 끌리는 긴 꼬리 6마디(2차 움직임 · 꼬리 휩쓸기) · 삼지창.
do
	local J = biped({
		hips = V(1.5, 0.5, 1.1), torso = V(2.3, 1.6, 1.4), head = V(1.1, 0.9, 1.1),
		thigh = { w = 0.66, len = 0.72 }, shin = { w = 0.6, len = 0.72 }, foot = V(0.8, 0.25, 1.15),
		upperArm = { w = 0.62, len = 0.95 }, forearm = { w = 0.6, len = 0.9 }, hand = V(0.72, 0.72, 0.72), shoulderX = 1.42, stance = 0.46,
	})
	add(J, { name = "Fin_L", parent = "Head", part = "LeftFin", size = V(0.25, 0.8, 0.9), shape = "wedge", color = "accent", at = V(-0.6, 0.1, 0.1), pivot = V(0, -0.2, 0), rot = V(0, 0, 35) })
	add(J, { name = "Fin_R", parent = "Head", part = "RightFin", size = V(0.25, 0.8, 0.9), shape = "wedge", color = "accent", at = V(0.6, 0.1, 0.1), pivot = V(0, -0.2, 0), rot = V(0, 0, -35) })
	add(J, { name = "Crest", parent = "Body", part = "BackFin", size = V(0.25, 1.1, 1.2), shape = "wedge", color = "accent", at = V(0, 0.4, 0.7), pivot = V(0, -0.3, 0), rot = V(0, 180, 0) })
	chain(J, { prefix = "Tail", parent = "Hips", count = 6, length = 0.75, w0 = 0.75, w1 = 0.32, flat = 1.2, at = V(0, -0.15, 0.5), rot0 = V(-75, 0, 0), rotStep = V(-9, 0, 0), color = "head", tipColor = "accent", tipShape = "wedge" })
	add(J, { name = "Trident", parent = "Hand_R", part = "Trident", size = V(0.22, 4.2, 0.22), shape = "cyl", color = "accent", at = V(0, -0.3, 0), pivot = V(0, -0.6, 0) })
	add(J, { name = "TridentHead", parent = "Trident", part = "TridentHead", size = V(0.9, 0.7, 0.15), shape = "wedge", color = "accent", material = "Neon", at = V(0, 2.1, 0), pivot = V(0, -0.35, 0) })
	BossRigSpec.rigs.abyssal_lord = {
		plan = "biped", joints = J, accent = Color3.fromRGB(60, 200, 255),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.4, 0) }, HandL = { part = "Hand_L", at = V(0, -0.4, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.55) }, TailTip = { part = "Tail6", at = V(0, -0.3, 0) } },
		chains = { { "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", lag = 0.45, sway = 7 } },
		weight = 1.1,
	}
end

-- 수정 여왕: 가는 몸 · 수정 치마 4장 × 2마디(2차 움직임) · 왕관 · 등 수정 날개 · 홀.
do
	local J = biped({
		hips = V(1.2, 0.5, 0.9), torso = V(1.5, 1.7, 0.9), head = V(0.9, 0.95, 0.9), headShape = "ball",
		thigh = { w = 0.5, len = 0.9 }, shin = { w = 0.45, len = 0.9 }, foot = V(0.55, 0.25, 0.9),
		upperArm = { w = 0.45, len = 0.95 }, forearm = { w = 0.42, len = 0.9 }, hand = V(0.5, 0.6, 0.5), shoulderX = 0.95, stance = 0.35,
	})
	for i, s in ipairs({ { "F", V(0, 0, -0.45), V(12, 0, 0) }, { "B", V(0, 0, 0.45), V(-12, 0, 0) }, { "L", V(-0.6, 0, 0), V(0, 0, -12) }, { "R", V(0.6, 0, 0), V(0, 0, 12) } }) do
		chain(J, { prefix = "Skirt" .. s[1], parent = "Hips", count = 2, length = 0.75, w0 = i <= 2 and 1.25 or 0.95, w1 = i <= 2 and 1.35 or 1.05, flat = 1, at = s[2] + V(0, -0.1, 0), rot0 = s[3], rotStep = s[3] * 0.5, color = "head", tipColor = "accent", tipMaterial = "Glass" })
	end
	add(J, { name = "Crown", parent = "Head", part = "Crown", size = V(0.8, 0.5, 0.8), shape = "cyl", color = "accent", material = "Neon", at = V(0, 0.5, 0), pivot = V(0, -0.2, 0), rot = V(0, 0, 90) })
	add(J, { name = "Wing_L", parent = "Body", part = "LeftShard", size = V(0.35, 1.6, 0.35), shape = "wedge", color = "accent", material = "Glass", at = V(-0.4, 0.5, 0.45), pivot = V(0, -0.7, 0), rot = V(-15, 0, 30) })
	add(J, { name = "Wing_R", parent = "Body", part = "RightShard", size = V(0.35, 1.6, 0.35), shape = "wedge", color = "accent", material = "Glass", at = V(0.4, 0.5, 0.45), pivot = V(0, -0.7, 0), rot = V(-15, 180, 30) })
	add(J, { name = "Scepter", parent = "Hand_R", part = "Scepter", size = V(0.18, 2.4, 0.18), shape = "cyl", color = "head", at = V(0, -0.25, 0), pivot = V(0, -0.5, 0) })
	add(J, { name = "ScepterGem", parent = "Scepter", part = "ScepterGem", size = V(0.5, 0.5, 0.5), shape = "ball", color = "accent", material = "Neon", at = V(0, 1.25, 0), pivot = V(0, 0, 0) })
	BossRigSpec.rigs.crystal_queen = {
		plan = "biped", joints = J, accent = Color3.fromRGB(150, 240, 255),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.3, 0) }, HandL = { part = "Hand_L", at = V(0, -0.3, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.45) }, Gem = { part = "ScepterGem", at = V(0, 0, 0) } },
		chains = { { "SkirtF1", "SkirtF2", lag = 0.4, sway = 3 }, { "SkirtB1", "SkirtB2", lag = 0.4, sway = 3 }, { "SkirtL1", "SkirtL2", lag = 0.4, sway = 3 }, { "SkirtR1", "SkirtR2", lag = 0.4, sway = 3 } },
		weight = 0.8,
	}
end

-- 폭풍 군주: 마법사 - 오른손 지팡이 · 망토 2줄 × 3마디(2차 움직임) · 어깨 칼날.
do
	local J = biped({
		hips = V(1.3, 0.5, 0.9), torso = V(1.7, 1.8, 1.0), head = V(0.95, 1.0, 0.95),
		thigh = { w = 0.55, len = 0.95 }, shin = { w = 0.5, len = 0.95 }, foot = V(0.6, 0.25, 0.95),
		upperArm = { w = 0.5, len = 1.0 }, forearm = { w = 0.48, len = 0.95 }, hand = V(0.55, 0.6, 0.55), shoulderX = 1.05, stance = 0.38,
	})
	add(J, { name = "Blade_L", parent = "Body", part = "LeftBlade", size = V(0.3, 1.5, 0.3), shape = "wedge", color = "accent", at = V(-0.95, 0.9, 0), pivot = V(0, -0.6, 0), rot = V(0, 0, 15) })
	add(J, { name = "Blade_R", parent = "Body", part = "RightBlade", size = V(0.3, 1.5, 0.3), shape = "wedge", color = "accent", at = V(0.95, 0.9, 0), pivot = V(0, -0.6, 0), rot = V(0, 180, 15) })
	chain(J, { prefix = "CapeL", parent = "Body", count = 3, length = 0.8, w0 = 0.8, w1 = 0.95, flat = 1, at = V(-0.42, 0.8, 0.55), rot0 = V(-6, 0, 0), rotStep = V(-3, 0, 0), color = "dark" })
	chain(J, { prefix = "CapeR", parent = "Body", count = 3, length = 0.8, w0 = 0.8, w1 = 0.95, flat = 1, at = V(0.42, 0.8, 0.55), rot0 = V(-6, 0, 0), rotStep = V(-3, 0, 0), color = "dark" })
	add(J, { name = "Staff", parent = "Hand_R", part = "Staff", size = V(0.25, 4.6, 0.25), shape = "cyl", color = "dark", at = V(0, -0.3, 0), pivot = V(0, -0.4, 0) })
	add(J, { name = "StaffOrb", parent = "Staff", part = "StaffOrb", size = V(0.7, 0.7, 0.7), shape = "ball", color = "accent", material = "Neon", at = V(0, 2.35, 0), pivot = V(0, 0, 0) })
	BossRigSpec.rigs.storm_lord = {
		plan = "biped", joints = J, accent = Color3.fromRGB(255, 240, 90),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.3, 0) }, HandL = { part = "Hand_L", at = V(0, -0.3, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.5) }, Orb = { part = "StaffOrb", at = V(0, 0, 0) } },
		chains = { { "CapeL1", "CapeL2", "CapeL3", lag = 0.5, sway = 5 }, { "CapeR1", "CapeR2", "CapeR3", lag = 0.5, sway = 5 } },
		weight = 0.9,
	}
end

-- 전갈 여왕: 낮고 넓은 몸 · 다리 6(엉덩이 · 무릎) · 집게 2(어깨 · 팔꿈치 · 집게 턱) · 꼬리 3 × 8마디(꼬리마다 따로 흔들림 · 4b-5 한 명씩 매단다).
do
	local J = {}
	add(J, { name = "RootJoint", parent = "HumanoidRootPart", part = "Body", size = V(2.4, 0.9, 2.2), color = "body", at = V(0, -0.1, 0), pivot = V(0, 0, 0), query = true })
	add(J, { name = "Neck", parent = "Body", part = "Head", size = V(1.3, 0.7, 0.9), color = "head", at = V(0, 0.05, -1.1), pivot = V(0, 0, 0.42), query = true })
	add(J, { name = "Eyes", parent = "Head", part = "Eyes", size = V(0.8, 0.14, 0.08), color = "eye", material = "Neon", at = V(0, 0.15, -0.45), pivot = V(0, 0, 0.02) })
	add(J, { name = "Jaw", parent = "Head", part = "Mouth", size = V(0.6, 0.12, 0.08), color = "mouth", at = V(0, -0.18, -0.45), pivot = V(0, 0.04, 0.02) })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		for k, z in ipairs({ -0.6, 0.15, 0.85 }) do
			local leg = ("%d_%s"):format(k, side)
			add(J, { name = "Hip" .. leg, parent = "Body", part = "Thigh" .. leg, size = V(0.28, 1.0, 0.28), color = "head", at = V(x * 1.2, -0.15, z), pivot = V(0, 0.5, 0), rot = V(0, 0, x * 125) })
			add(J, { name = "Knee" .. leg, parent = "Thigh" .. leg, part = "Shin" .. leg, size = V(0.24, 1.95, 0.24), color = "dark", at = V(0, -0.5, 0), pivot = V(0, 0.975, 0), rot = V(0, 0, -x * 95) })
		end
		add(J, { name = "Shoulder_" .. side, parent = "Body", part = "UpperArm_" .. side, size = V(0.4, 1.0, 0.4), color = "head", at = V(x * 0.95, 0.05, -1.05), pivot = V(0, 0.5, 0), rot = V(95, x * -25, 0) })
		add(J, { name = "Elbow_" .. side, parent = "UpperArm_" .. side, part = "Forearm_" .. side, size = V(0.42, 1.0, 0.42), color = "body", at = V(0, -0.5, 0), pivot = V(0, 0.5, 0), rot = V(40, 0, 0) })
		add(J, { name = "Wrist_" .. side, parent = "Forearm_" .. side, part = "Hand_" .. side, size = V(0.8, 0.9, 0.5), color = "head", at = V(0, -0.5, 0), pivot = V(0, 0.4, 0), rot = V(-45, 0, 0) })
		add(J, { name = "Pincer_" .. side, parent = "Hand_" .. side, part = "Pincer_" .. side, size = V(0.3, 0.9, 0.3), shape = "wedge", color = "accent", at = V(-x * 0.25, -0.4, 0), pivot = V(0, 0.45, 0), rot = V(0, 0, x * 10) })
	end
	local tailRot = { -30, 0, 30 }
	for t = 1, 3 do
		chain(J, { prefix = ("Tail%d_"):format(t), parent = "Body", count = 8, length = 0.55, w0 = 0.45, w1 = 0.24, at = V((t - 2) * 0.45, 0.3, 1.0), rot0 = V(-127, tailRot[t], 0), rotStep = V(-20, 0, 0),
			color = "body", tipColor = "accent", tipShape = "wedge", tipMaterial = "Neon" })
	end
	local chains = {}
	for t = 1, 3 do
		local c = { lag = 0.5, sway = 9, phase = t * 1.9 }
		for i = 1, 8 do
			c[i] = ("Tail%d_%d"):format(t, i)
		end
		chains[t] = c
	end
	BossRigSpec.rigs.scorpion_queen = {
		plan = "scorpion", joints = J, accent = Color3.fromRGB(255, 190, 60),
		-- 4b-5 매달기: 꼬리 1 = 끝(8마디) · 꼬리 2 = 가운데(5) · 꼬리 3 = 밑(4 - 2마디는 잡힌 사람 발이 땅에 묻혔다) · 넷째부터 = 집게(HandR · HandL)
		attach = {
			Tail1 = { part = "Tail1_8", at = V(0, -0.3, 0) }, Tail2 = { part = "Tail2_5", at = V(0, 0, 0) }, Tail3 = { part = "Tail3_4", at = V(0, 0, 0) },
			HandR = { part = "Hand_R", at = V(0, -0.5, 0) }, HandL = { part = "Hand_L", at = V(0, -0.5, 0) }, Mouth = { part = "Head", at = V(0, -0.1, -0.5) },
		},
		chains = chains,
		weight = 0.8,
	}
end

-- BOSS-FRAMEWORK 1: 새 몸(리그 v2 - shared/data/BossRigV2Data)을 "<보스 id>_v2" 키로 같이 등록한다(모델 Attribute BossRigKey가 고른다 · BossRig = 보스 id 그대로).
--   어느 몸이 뜨는지 = shared/data/BossFrameworkData(실전 live · Studio 시험 스위치) - 등록만으로는 아무 보스도 바뀌지 않는다.
local BossRigV2Data = require(script.Parent.BossRigV2Data)
for key, rig in pairs(BossRigV2Data.rigs) do
	rig.key = key
	BossRigSpec.rigs[key] = rig
end

-- BR1-4c c-10 발 접지: 발바닥 점(클라 BossAnimator가 매 프레임 가장 낮은 발을 땅에 맞춘다 - 뜬 발 · 바닥 관통 없음). 두 발 = 발 파트 밑면 · 전갈 = 다리 끝.
--   v2 = rig.contacts(접지 부위 이름 - 네 발 · 너클 · 뱀 꼬리)가 있으면 그것 · contactAt = 모든 부위의 밑점(동작 세트가 바꿔 고른다 - BossClipSetData contacts).
for _, rig in pairs(BossRigSpec.rigs) do
	rig.feet = {}
	if rig.variant then
		rig.contactAt = {}
		for _, j in ipairs(rig.joints) do
			rig.contactAt[j.part] = V(0, -j.size.Y / 2, 0)
		end
	end
	for _, j in ipairs(rig.joints) do
		if rig.contacts then
			for _, c in ipairs(rig.contacts) do -- 이름(밑점 = 아래 끝) 또는 { part, at }(누운 꼬리 - 배 쪽 점)
				if c == j.part then
					table.insert(rig.feet, { part = j.part, at = V(0, -j.size.Y / 2, 0) })
				elseif type(c) == "table" and c.part == j.part then
					table.insert(rig.feet, { part = j.part, at = c.at })
					rig.contactAt[j.part] = c.at
				end
			end
		elseif j.part == "Foot_L" or j.part == "Foot_R" then
			table.insert(rig.feet, { part = j.part, at = V(0, -j.size.Y / 2, 0) })
		elseif j.part:match("^Shin%d_[LR]$") then
			table.insert(rig.feet, { part = j.part, at = V(0, -j.size.Y / 2, 0) })
		end
	end
end

-- 모델 → 리그 키(BossRigKey가 있으면 v2 · 없으면 보스 id = 옛 리그)
function BossRigSpec.keyOf(model)
	return model:GetAttribute("BossRigKey") or model:GetAttribute("BossRig")
end
function BossRigSpec.rigOf(model)
	local key = BossRigSpec.keyOf(model)
	return key and BossRigSpec.rigs[key] or nil, key
end

-- 색 역할 → 실제 색(bodyColor · headColor = BossData · accent = 위 표 · 나머지 = 파생).
function BossRigSpec.colorOf(role, look, rig)
	if typeof(role) == "Color3" then -- A2-S 아트 샘플: 관절 표에 색을 직접 적은 부위
		return role
	end
	if role == "head" then
		return look.headColor
	elseif role == "dark" then
		return look.bodyColor:Lerp(Color3.new(0, 0, 0), 0.3)
	elseif role == "accent" then
		return rig.accent or look.headColor
	elseif role == "eye" then
		return Color3.new(1, 1, 1):Lerp(rig.accent or Color3.new(1, 1, 1), 0.35)
	elseif role == "mouth" then
		return Color3.fromRGB(25, 18, 22)
	elseif role == "light" then -- A2-M1 디테일 색 역할(새 색 없이 보스 색에서 파생)
		return look.headColor:Lerp(Color3.new(1, 1, 1), 0.35)
	elseif role == "shadow" then
		return look.bodyColor:Lerp(Color3.new(0, 0, 0), 0.5)
	elseif role == "stone" then
		return look.bodyColor:Lerp(Color3.fromRGB(140, 136, 150), 0.42)
	elseif role == "slab" then -- 밝은 판석(명도 대비 - 머리색을 회백으로)
		return look.headColor:Lerp(Color3.fromRGB(205, 200, 215), 0.4)
	elseif role == "metal" then
		return look.headColor:Lerp(Color3.fromRGB(150, 150, 160), 0.6)
	end
	return look.bodyColor
end

-- A2-M1 접지: 보스 리그 전부 발바닥을 바닥에 맞춘다(shared/BossRig.rootLift - 루트 판정 자리는 그대로)
-- A2-M1 디테일(shared/data/BossDetailSpec - ArtStyleV1 스위치 뒤): 새 관절(detail = true · 스위치 끔이면 안 짓는다) · 2차 움직임 사슬 · 장식 · 테마 색을 얹는다.
local BossDetailSpec = require(script.Parent.BossDetailSpec)
for id, rig in pairs(BossRigSpec.rigs) do
	rig.groundLift = true
	local detail = BossDetailSpec.bosses[id]
	if detail then
		for _, j in ipairs(detail.joints or {}) do
			table.insert(rig.joints, j)
		end
		for _, c in ipairs(detail.chains or {}) do
			c.detail = true
			table.insert(rig.chains, c)
		end
		rig.deco = detail.deco
		rig.themeColors = detail.themeColors
		rig.recolor = detail.recolor
	end
end

-- 대공 잡기 들기 자리(4b-3 · 4b-5): 잡힌 순서대로 이 부착점에 매단다(서버 server/BossAirGrab · 클라 BossAnimator 같은 FK) · 두 발 몸 = 오른손 · 왼손 · 어깨 · 전갈 = 꼬리 끝 · 가운데 · 밑 → 넷째부터 집게.
BossRigSpec.holdSlots = { biped = { "HandR", "HandL", "ShoulderR", "ShoulderL" }, scorpion = { "Tail1", "Tail2", "Tail3", "HandR", "HandL" } }
BossRigSpec.holdHangStuds = 1.3 -- 부착점 아래 잡힌 사람 루트까지(stud)
BossRigSpec.holdMarkColors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(120, 230, 120), Color3.fromRGB(255, 220, 90), Color3.fromRGB(230, 130, 255) } -- 4b-5 잡힌 사람 머리 위 표식(자리 순서)

-- 모션 LOD(4b 검증 - 클라 비용): 카메라에서 이 거리(stud) 밖이면 모션 갱신을 줄인다.
BossRigSpec.lod = { fullStuds = 160, reducedHz = 15, farStuds = 400 }

return BossRigSpec
