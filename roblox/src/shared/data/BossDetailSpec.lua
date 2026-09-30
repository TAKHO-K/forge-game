-- A2-M1 보스 디테일(사용자 지시 2026-09-30: "보스별 파트를 더 추가하고 최대 파트 제한을 풀어 보스전만큼은 정성 들여 만들었구나 알 수 있게 - 이번 아트 작업의 핵심"
--   · "모바일 평균 유저 기준 4인 도전 때 렉이 걸리면 안 된다 - 적당히"). BossRigSpec의 리그 위에 얹는다(ArtStyleV1 스위치 뒤 - 끄면 옛 모습 그대로).
--   joints = 움직이는 새 부위(관절 표와 같은 규격 - 망토 · 꼬리 · 깃발 조각 등 2차 움직임 사슬) · chains = 그 부위의 2차 움직임 사슬(BossRigSpec chains 규격)
--   deco = 부모 부위에 용접되는 장식 파트(관절 없음 = 모션 계산 비용 0 · 충돌 · 조준 · 터치 없음): { parent, name, size, at(부모 부위 공간 · 단위 = sizeScale 1),
--     rot(도 - X · Y · Z), shape("block" | "ball" | "wedge" | "cyl" | "corner"), color(역할 - body · head · dark · accent · eye · mouth · light · shadow · stone · metal 또는 Color3),
--     material(선택 - "Neon" · "Glass" · "Ice" · "Slate" …), lod(1 = 늘 · 2 = 세밀 - 폰 · 먼 거리에서 클라가 숨김 · client/BossDetailLod) }
--   themeColors = 몸 · 머리 · 강조 색(A2-N2 확정 `roblox/art/bosses/<보스>.meta.json` themeColors - 스위치 켬일 때 BossData 색 대신).
-- 파트 예산(art-direction §6 A2-M1 개정): 두 발 보스 ≤ 80 · 전갈 여왕 ≤ 110(세밀 lod 2 포함) · 폰에서 보이는 수(lod 1) ≤ 60 · 80.
-- 이름 규칙: 장식 = Deco_<부위>_<무엇>(좌우 _L · _R) · 새 관절 = 파트 이름과 같게(TassetF · BannerL1 …) - Blender 스크립트(make_boss.py)도 같은 이름 · 피벗.
local BossDetailSpec = {}

local V = Vector3.new

local function mirrorX(list)
	-- _L 항목을 _R로(부모 · 이름 · x · ry · rz 부호) 복사한다
	local out = {}
	for _, d in ipairs(list) do
		table.insert(out, d)
		if d.name:find("_L$") then
			local r = d.rot or V(0, 0, 0)
			table.insert(out, {
				parent = d.parent:gsub("_L$", "_R"):gsub("^Left", "Right"), name = d.name:gsub("_L$", "_R"), size = d.size, shape = d.shape, color = d.color,
				material = d.material, lod = d.lod, at = V(-d.at.X, d.at.Y, d.at.Z), rot = V(r.X, -r.Y, -r.Z),
			})
		end
	end
	return out
end
BossDetailSpec.mirrorX = mirrorX

local function deco(parent, name, size, at, rot, color, opts)
	opts = opts or {}
	return { parent = parent, name = name, size = size, at = at, rot = rot or V(0, 0, 0), color = color, shape = opts.shape, material = opts.material, lod = opts.lod or 1 }
end

-- 사슬(깃발 · 천 · 꼬리 조각) - BossRigSpec chain과 같은 모양의 관절 표
local function chain(J, o)
	local parent = o.parent
	for i = 1, o.count do
		local f = (i - 1) / math.max(o.count - 1, 1)
		local w = o.w0 + (o.w1 - o.w0) * f
		local name = ("%s%d"):format(o.prefix, i)
		table.insert(J, {
			name = name, parent = parent, part = name, size = V(w, o.length, o.thick or w), color = (i == o.count and o.tipColor) or o.color or "body",
			material = (i == o.count and o.tipMaterial) or o.material, shape = "block",
			at = i == 1 and o.at or V(0, -o.length / 2, 0), pivot = V(0, o.length / 2, 0), rot = i == 1 and o.rot0 or o.rotStep, detail = true,
		})
		parent = name
	end
end

BossDetailSpec.bosses = {}

-- ─────────────────────────── 구간 수호자: 고대 돌 골렘 · 보라 룬 수정 ───────────────────────────
-- 콘셉트: 구간을 지키는 오래된 석상. 몸은 겹겹이 쌓인 판석(가슴 · 어깨 · 허리띠 · 무릎) · 등과 머리에 보라 수정이 돋고 룬이 빛난다.
-- 실루엣 = 넓은 어깨 + 머리 수정 관 + 등 수정 3 + 허리 깃발 2(걸을 때 펄럭임). 무게감 = 두꺼운 팔뚝 테 · 주먹 돌기 · 발 발톱.
do
	local J = {}
	-- 허리 앞 · 뒤 판석(걸음 · 타격에 흔들리는 2차 움직임)
	table.insert(J, { name = "TassetF", parent = "Hips", part = "TassetF", size = V(1.05, 0.7, 0.16), color = "slab", at = V(0, -0.16, -0.56), pivot = V(0, 0.34, 0), rot = V(-6, 0, 0), detail = true })
	table.insert(J, { name = "TassetB", parent = "Hips", part = "TassetB", size = V(1.05, 0.7, 0.16), color = "slab", at = V(0, -0.16, 0.56), pivot = V(0, 0.34, 0), rot = V(6, 0, 0), detail = true })
	-- 허리 옆 룬 깃발 2줄 × 3조각(천 - 강조색 끝)
	chain(J, { prefix = "BannerL", parent = "Hips", count = 3, length = 0.46, w0 = 0.5, w1 = 0.42, thick = 0.07, at = V(-0.78, -0.1, 0.34), rot0 = V(4, 0, 6), rotStep = V(3, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	chain(J, { prefix = "BannerR", parent = "Hips", count = 3, length = 0.46, w0 = 0.5, w1 = 0.42, thick = 0.07, at = V(0.78, -0.1, 0.34), rot0 = V(4, 0, -6), rotStep = V(3, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	local D = {
		-- 머리: 얼굴 판석(이마 · 턱) + 수정 관(가운데 큰 결정 + 양옆 2쌍)
		deco("Head", "Deco_Head_Brow", V(1.2, 0.26, 0.34), V(0, 0.26, -0.44), V(-12, 0, 0), "slab"),
		deco("Head", "Deco_Head_Jaw", V(0.96, 0.26, 0.38), V(0, -0.4, -0.32), V(8, 0, 0), "stone"),
		deco("Head", "Deco_Head_Cheek_L", V(0.2, 0.5, 0.5), V(-0.58, -0.05, -0.2), V(0, 0, 0), "stone"),
		deco("Head", "Deco_Head_Crown", V(0.3, 0.85, 0.3), V(0, 0.78, 0.05), V(0, 45, 0), "accent", { material = "Glass" }),
		deco("Head", "Deco_Head_CrownSide_L", V(0.24, 0.6, 0.24), V(-0.3, 0.66, 0.1), V(0, 45, 20), "accent", { material = "Glass" }),
		deco("Head", "Deco_Head_CrownOuter_L", V(0.18, 0.4, 0.18), V(-0.5, 0.55, 0.12), V(0, 45, 34), "accent", { material = "Glass", lod = 2 }),
		-- 가슴 판석(룬 둘레) · 룬 빛줄기(세밀)
		deco("Body", "Deco_Chest_Top", V(2.05, 0.38, 0.24), V(0, 0.64, -0.74), V(-4, 0, 0), "slab"),
		deco("Body", "Deco_Chest_Side_L", V(0.62, 1.02, 0.22), V(-0.92, 0.02, -0.72), V(0, -8, 0), "stone"),
		deco("Body", "Deco_Chest_Belly", V(1.36, 0.4, 0.22), V(0, -0.6, -0.72), V(0, 0, 0), "slab"),
		deco("Body", "Deco_Chest_Ray_L", V(0.34, 0.06, 0.04), V(-0.5, 0.2, -0.72), V(0, 0, 0), "accent", { material = "Neon", lod = 2 }),
		deco("Body", "Deco_Chest_RayLow_L", V(0.3, 0.06, 0.04), V(-0.3, -0.12, -0.72), V(0, 0, -40), "accent", { material = "Neon", lod = 2 }),
		-- 등 수정 무리 5(뒤 실루엣 - 큰 가운데 + 양옆 + 작은 끝)
		deco("Body", "Deco_Back_Crystal", V(0.46, 1.7, 0.46), V(0, 0.7, 0.86), V(-22, 45, 0), "accent", { material = "Glass" }),
		deco("Body", "Deco_Back_CrystalSide_L", V(0.36, 1.2, 0.36), V(-0.6, 0.45, 0.8), V(-16, 45, 24), "accent", { material = "Glass" }),
		deco("Body", "Deco_Back_CrystalSmall_L", V(0.26, 0.7, 0.26), V(-0.95, 0.1, 0.72), V(-10, 45, 40), "accent", { material = "Glass", lod = 2 }),
		deco("Body", "Deco_Back_Slab", V(1.6, 1.1, 0.2), V(0, 0.05, 0.72), V(0, 0, 0), "stone"),
		-- 어깨 판석 덮개 · 돌 가시 2 · 룬 띠(세밀)
		deco("LeftPauldron", "Deco_Pauldron_Cap_L", V(1.2, 0.3, 1.3), V(-0.05, 0.3, 0), V(0, 0, 12), "slab"),
		deco("LeftPauldron", "Deco_Pauldron_Spike_L", V(0.28, 0.62, 0.28), V(-0.28, 0.55, 0.24), V(0, 45, 20), "stone"),
		deco("LeftPauldron", "Deco_Pauldron_Spike2_L", V(0.22, 0.46, 0.22), V(-0.22, 0.48, -0.28), V(0, 45, 14), "stone"),
		deco("LeftPauldron", "Deco_Pauldron_Rune_L", V(0.5, 0.08, 0.04), V(0, 0.02, -0.66), V(0, 0, 0), "accent", { material = "Neon", lod = 2 }),
		-- 팔: 위팔 룬(세밀) · 팔꿈치 돌 · 팔뚝 판석 테 · 주먹 돌기(세밀)
		deco("UpperArm_L", "Deco_UpperArm_Rune_L", V(0.05, 0.56, 0.05), V(-0.4, -0.1, 0), V(0, 0, 0), "accent", { material = "Neon", lod = 2 }),
		deco("Forearm_L", "Deco_Forearm_Elbow_L", V(0.5, 0.36, 0.42), V(0, 0.42, 0.3), V(20, 0, 0), "stone"),
		deco("Forearm_L", "Deco_Forearm_Band_L", V(0.96, 0.38, 0.96), V(0, 0.08, 0), V(0, 0, 0), "slab"),
		deco("Hand_L", "Deco_Hand_Knuckle_L", V(0.95, 0.26, 0.26), V(0, -0.28, -0.56), V(0, 0, 0), "stone", { lod = 2 }),
		-- 허리띠(앞 버클 = 수정 · 양옆 돌)
		deco("Hips", "Deco_Belt", V(1.72, 0.2, 1.1), V(0, 0.2, 0), V(0, 0, 0), "shadow"),
		deco("Hips", "Deco_Belt_Buckle", V(0.52, 0.52, 0.24), V(0, 0.05, -0.56), V(0, 0, 45), "accent", { material = "Glass" }),
		deco("Hips", "Deco_Belt_Side_L", V(0.38, 0.44, 1.0), V(-0.86, 0.02, 0), V(0, 0, 0), "stone"),
		-- 다리: 허벅지 판석 · 무릎 판 · 정강이 판 · 발 앞 돌(세밀)
		deco("Thigh_L", "Deco_Thigh_Plate_L", V(0.86, 0.52, 0.86), V(0, 0.14, 0), V(0, 0, 0), "stone"),
		deco("Thigh_L", "Deco_Knee_L", V(0.6, 0.44, 0.26), V(0, -0.38, -0.4), V(-10, 0, 0), "slab"),
		deco("Shin_L", "Deco_Shin_L", V(0.72, 0.6, 0.2), V(0, 0.02, -0.38), V(0, 0, 0), "stone"),
		deco("Foot_L", "Deco_Toe_L", V(0.86, 0.24, 0.3), V(0, -0.02, -0.64), V(0, 0, 0), "stone", { lod = 2 }),
	}
	BossDetailSpec.bosses.section_guardian = {
		joints = J,
		chains = { { "TassetF", lag = 0.55, sway = 2.5 }, { "TassetB", lag = 0.55, sway = 2.5 }, { "BannerL1", "BannerL2", "BannerL3", lag = 0.4, sway = 6 }, { "BannerR1", "BannerR2", "BannerR3", lag = 0.4, sway = 6 } },
		deco = mirrorX(D),
		recolor = { Hips = "shadow", Shin_L = "shadow", Shin_R = "shadow", Foot_L = "stone", Foot_R = "stone", UpperArm_L = "stone", UpperArm_R = "stone" }, -- 디테일 모드 부위 색(명도 위계: 어두운 속 ↔ 밝은 판석 ↔ 빛나는 수정)
		themeColors = { body = Color3.fromRGB(60, 20, 70), head = Color3.fromRGB(90, 30, 100), accent = Color3.fromRGB(190, 110, 255) },
	}
end

-- ─────────────────────────── 서리 거인: 얼음 갑옷 · 털 망토의 거인 ───────────────────────────
-- 콘셉트: 설산의 거인 족장. 흰 털 망토(등 · 2차 움직임) · 털 허리띠와 다리 감개 · 얼음 갑주(가슴 · 어깨 · 무릎) · 머리 얼음 관 · 등 고드름 · 곤봉에 박힌 얼음 가시.
-- 실루엣 = 높고 넓은 어깨(얼음 어깨 갑주 + 가시) + 등 망토 + 곤봉 끝 가시. 무게감 = 두꺼운 털 장화 · 무릎 얼음.
do
	local J = {}
	chain(J, { prefix = "Mantle", parent = "Body", count = 3, length = 0.6, w0 = 1.7, w1 = 1.95, thick = 0.14, at = V(0, 0.78, 0.64), rot0 = V(6, 0, 0), rotStep = V(4, 0, 0), color = "light", material = "Fabric" })
	chain(J, { prefix = "Loin", parent = "Hips", count = 2, length = 0.45, w0 = 0.85, w1 = 0.75, thick = 0.08, at = V(0, -0.16, -0.5), rot0 = V(-4, 0, 0), rotStep = V(-3, 0, 0), color = "light", material = "Fabric" })
	local D = {
		deco("Head", "Deco_Head_Brow", V(1.08, 0.22, 0.32), V(0, 0.26, -0.46), V(-10, 0, 0), "light", { material = "Fabric" }),
		deco("Head", "Deco_Head_IceCrown", V(0.26, 0.66, 0.26), V(0, 0.7, 0), V(0, 45, 0), "accent", { material = "Ice" }),
		deco("Head", "Deco_Head_IceCrownSide_L", V(0.2, 0.46, 0.2), V(-0.28, 0.62, 0.06), V(0, 45, 16), "accent", { material = "Ice" }),
		deco("Body", "Deco_Collar_Fur", V(2.15, 0.48, 1.42), V(0, 0.9, 0.05), V(0, 0, 0), "light", { material = "Fabric" }),
		deco("Body", "Deco_Chest_Ice", V(1.35, 0.95, 0.22), V(0, 0.2, -0.66), V(0, 0, 0), "accent", { material = "Ice" }),
		deco("Body", "Deco_Chest_Rune", V(0.95, 0.06, 0.04), V(0, 0.2, -0.78), V(0, 0, 0), "accent", { material = "Neon", lod = 2 }),
		deco("Body", "Deco_Back_Icicle", V(0.3, 1.0, 0.3), V(0, 0.45, 0.78), V(-28, 45, 0), "accent", { material = "Ice" }),
		deco("Body", "Deco_Back_IcicleSide_L", V(0.24, 0.75, 0.24), V(-0.52, 0.3, 0.74), V(-22, 45, 20), "accent", { material = "Ice", lod = 2 }),
		deco("UpperArm_L", "Deco_Pauldron_Ice_L", V(0.98, 0.52, 0.98), V(-0.08, 0.46, 0), V(0, 0, 10), "accent", { material = "Ice" }),
		deco("UpperArm_L", "Deco_Pauldron_Spike_L", V(0.24, 0.62, 0.24), V(-0.32, 0.82, 0), V(0, 45, 26), "accent", { material = "Ice" }),
		deco("UpperArm_L", "Deco_Shoulder_Fur_L", V(0.72, 0.3, 0.72), V(0, 0.12, 0), V(0, 0, 0), "light", { material = "Fabric", lod = 2 }),
		deco("Forearm_L", "Deco_Forearm_Fur_L", V(0.74, 0.36, 0.74), V(0, 0.12, 0), V(0, 0, 0), "light", { material = "Fabric" }),
		deco("Hand_L", "Deco_Hand_Ice_L", V(0.62, 0.22, 0.22), V(0, -0.22, -0.4), V(0, 0, 0), "accent", { material = "Ice", lod = 2 }),
		deco("Hips", "Deco_Belt_Fur", V(1.58, 0.32, 1.08), V(0, 0.1, 0), V(0, 0, 0), "light", { material = "Fabric" }),
		deco("Hips", "Deco_Belt_Buckle", V(0.42, 0.42, 0.2), V(0, 0.1, -0.56), V(0, 0, 45), "accent", { material = "Ice" }),
		deco("Thigh_L", "Deco_Knee_Ice_L", V(0.52, 0.42, 0.22), V(0, -0.48, -0.36), V(-10, 0, 0), "accent", { material = "Ice" }),
		deco("Shin_L", "Deco_Shin_Fur_L", V(0.72, 0.58, 0.72), V(0, -0.16, 0), V(0, 0, 0), "light", { material = "Fabric" }),
		deco("Foot_L", "Deco_Boot_L", V(0.84, 0.38, 1.1), V(0, 0.04, -0.02), V(0, 0, 0), "shadow"),
		deco("IceClub", "Deco_Club_SpikeA", V(0.22, 0.6, 0.22), V(0, 1.05, -0.32), V(-40, 45, 0), "accent", { material = "Ice" }),
		deco("IceClub", "Deco_Club_SpikeB", V(0.22, 0.6, 0.22), V(0.3, 0.85, 0.15), V(30, 45, -40), "accent", { material = "Ice" }),
		deco("IceClub", "Deco_Club_SpikeC", V(0.2, 0.5, 0.2), V(-0.3, 0.7, 0.12), V(25, 45, 40), "accent", { material = "Ice", lod = 2 }),
		deco("Beard3", "Deco_Beard_Icicle", V(0.14, 0.4, 0.14), V(0, -0.3, 0), V(0, 45, 0), "accent", { material = "Ice", lod = 2 }),
	}
	BossDetailSpec.bosses.frost_giant = {
		joints = J,
		chains = { { "Mantle1", "Mantle2", "Mantle3", lag = 0.55, sway = 4 }, { "Loin1", "Loin2", lag = 0.5, sway = 3 } },
		deco = mirrorX(D),
		recolor = { Hips = "shadow" },
		themeColors = { body = Color3.fromRGB(96, 150, 204), head = Color3.fromRGB(226, 240, 250), accent = Color3.fromRGB(170, 232, 255) },
	}
end

-- ─────────────────────────── 심해 군주: 산호 왕관 · 조개 갑주의 인어 왕 ───────────────────────────
-- 콘셉트: 가라앉은 신전의 왕. 산호 왕관 · 조개 어깨 · 비늘 가슴판 · 진주 목걸이 · 수염 촉수 3(2차 움직임) · 꼬리 지느러미 · 삼지창 곁날.
do
	local J = {}
	chain(J, { prefix = "TentL", parent = "Head", count = 3, length = 0.34, w0 = 0.2, w1 = 0.1, thick = 0.2, at = V(-0.26, -0.44, -0.36), rot0 = V(8, 0, 4), rotStep = V(6, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	chain(J, { prefix = "TentM", parent = "Head", count = 3, length = 0.38, w0 = 0.22, w1 = 0.1, thick = 0.22, at = V(0, -0.46, -0.42), rot0 = V(10, 0, 0), rotStep = V(6, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	chain(J, { prefix = "TentR", parent = "Head", count = 3, length = 0.34, w0 = 0.2, w1 = 0.1, thick = 0.2, at = V(0.26, -0.44, -0.36), rot0 = V(8, 0, -4), rotStep = V(6, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	local D = {
		deco("Head", "Deco_Head_Coral", V(0.18, 0.72, 0.18), V(0, 0.66, 0.02), V(0, 0, 0), "accent", { material = "Glass" }),
		deco("Head", "Deco_Head_CoralSide_L", V(0.15, 0.52, 0.15), V(-0.26, 0.58, 0.02), V(0, 0, 22), "accent", { material = "Glass" }),
		deco("Head", "Deco_Head_CoralTwig_L", V(0.1, 0.32, 0.1), V(-0.42, 0.74, 0.02), V(0, 0, 48), "accent", { material = "Glass", lod = 2 }),
		deco("Head", "Deco_Head_Visor", V(1.16, 0.2, 0.32), V(0, 0.22, -0.5), V(-8, 0, 0), "shadow"),
		deco("UpperArm_L", "Deco_Pauldron_Shell_L", V(1.02, 0.46, 1.02), V(-0.08, 0.42, 0), V(0, 0, 15), "light"),
		deco("UpperArm_L", "Deco_Pauldron_Ridge_L", V(0.12, 0.5, 0.92), V(-0.2, 0.6, 0), V(0, 0, 15), "accent", { lod = 2 }),
		deco("Body", "Deco_Chest_ScaleTop", V(1.65, 0.3, 0.14), V(0, 0.45, -0.73), V(0, 0, 0), "head"),
		deco("Body", "Deco_Chest_ScaleMid", V(1.4, 0.3, 0.14), V(0, 0.1, -0.73), V(0, 0, 0), "light"),
		deco("Body", "Deco_Chest_ScaleLow", V(1.1, 0.3, 0.14), V(0, -0.25, -0.73), V(0, 0, 0), "head"),
		deco("Body", "Deco_Pearl_L", V(0.24, 0.24, 0.24), V(-0.36, 0.7, -0.72), V(0, 0, 0), "light", { shape = "ball" }),
		deco("Body", "Deco_Pearl_Center", V(0.3, 0.3, 0.3), V(0, 0.6, -0.8), V(0, 0, 0), "accent", { shape = "ball", material = "Neon" }),
		deco("Forearm_L", "Deco_Forearm_Fin_L", V(0.1, 0.62, 0.52), V(-0.34, 0, 0.1), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass" }),
		deco("Hips", "Deco_Belt", V(1.6, 0.22, 1.2), V(0, 0.15, 0), V(0, 0, 0), "shadow"),
		deco("Hips", "Deco_Belt_Shell", V(0.52, 0.42, 0.18), V(0, 0.1, -0.6), V(0, 0, 0), "light"),
		deco("Tail2", "Deco_Tail_Fin2", V(0.1, 0.5, 0.5), V(0, 0, 0.42), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass" }),
		deco("Tail3", "Deco_Tail_Fin3", V(0.1, 0.45, 0.45), V(0, 0, 0.38), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass" }),
		deco("Tail4", "Deco_Tail_Fin4", V(0.1, 0.4, 0.4), V(0, 0, 0.32), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass", lod = 2 }),
		deco("Tail5", "Deco_Tail_Fin5", V(0.1, 0.35, 0.35), V(0, 0, 0.28), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass", lod = 2 }),
		deco("Shin_L", "Deco_Shin_Scale_L", V(0.68, 0.5, 0.2), V(0, 0.05, -0.33), V(0, 0, 0), "head"),
		deco("Trident", "Deco_Trident_ProngL", V(0.1, 0.62, 0.1), V(-0.32, 2.25, 0), V(0, 0, 12), "accent", { material = "Neon" }),
		deco("Trident", "Deco_Trident_ProngR", V(0.1, 0.62, 0.1), V(0.32, 2.25, 0), V(0, 0, -12), "accent", { material = "Neon" }),
		deco("Trident", "Deco_Trident_Ring", V(0.5, 0.14, 0.5), V(0, 1.8, 0), V(0, 0, 0), "light"),
	}
	BossDetailSpec.bosses.abyssal_lord = {
		joints = J,
		chains = { { "TentL1", "TentL2", "TentL3", lag = 0.35, sway = 7 }, { "TentM1", "TentM2", "TentM3", lag = 0.35, sway = 7, phase = 1.1 }, { "TentR1", "TentR2", "TentR3", lag = 0.35, sway = 7, phase = 2.3 } },
		deco = mirrorX(D),
		recolor = {},
		themeColors = { body = Color3.fromRGB(24, 66, 112), head = Color3.fromRGB(36, 140, 146), accent = Color3.fromRGB(70, 226, 214) },
	}
end

-- ─────────────────────────── 수정 여왕: 수정궁의 여왕(분홍 몸 · 청록 결정) ───────────────────────────
-- 콘셉트: 우아한 결정 여왕. 머리 뒤 후광 · 왕관 가시 · 이마 보석 · 옷깃 · 어깨 결정 · 팔찌 · 허리 보석 · 치마 끝 결정(세밀) · 날개 2단(2차 움직임) · 뒤 옷자락.
do
	local J = {}
	table.insert(J, { name = "Wing2_L", parent = "LeftShard", part = "LeftShard2", size = V(0.28, 1.25, 0.28), shape = "wedge", color = "accent", material = "Glass", at = V(0, 0.2, 0.08), pivot = V(0, -0.55, 0), rot = V(-8, 0, 22), detail = true })
	table.insert(J, { name = "Wing2_R", parent = "RightShard", part = "RightShard2", size = V(0.28, 1.25, 0.28), shape = "wedge", color = "accent", material = "Glass", at = V(0, 0.2, 0.08), pivot = V(0, -0.55, 0), rot = V(-8, 0, 22), detail = true })
	chain(J, { prefix = "Train", parent = "Body", count = 3, length = 0.62, w0 = 1.05, w1 = 1.3, thick = 0.06, at = V(0, 0.55, 0.48), rot0 = V(6, 0, 0), rotStep = V(5, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Glass" })
	local D = {
		deco("Head", "Deco_Halo_Top", V(1.3, 0.1, 0.1), V(0, 0.95, 0.5), V(0, 0, 0), "accent", { material = "Neon" }),
		deco("Head", "Deco_Halo_Side_L", V(0.1, 1.0, 0.1), V(-0.65, 0.45, 0.5), V(0, 0, 0), "accent", { material = "Neon" }),
		deco("Head", "Deco_Halo_Corner_L", V(0.1, 0.5, 0.1), V(-0.5, 0.88, 0.5), V(0, 0, -45), "accent", { material = "Neon", lod = 2 }),
		deco("Head", "Deco_Head_Jewel", V(0.16, 0.16, 0.08), V(0, 0.2, -0.46), V(0, 0, 45), "accent", { material = "Neon" }),
		deco("Crown", "Deco_Crown_Spike", V(0.14, 0.6, 0.14), V(0, 0.5, -0.3), V(0, 45, 0), "accent", { material = "Glass" }),
		deco("Crown", "Deco_Crown_SpikeSide_L", V(0.12, 0.46, 0.12), V(-0.3, 0.42, -0.1), V(0, 45, 10), "accent", { material = "Glass" }),
		deco("Crown", "Deco_Crown_SpikeBack_L", V(0.1, 0.36, 0.1), V(-0.24, 0.36, 0.26), V(0, 45, 14), "accent", { material = "Glass", lod = 2 }),
		deco("Body", "Deco_Collar", V(1.34, 0.2, 0.84), V(0, 0.88, 0), V(0, 0, 0), "light"),
		deco("Body", "Deco_Chest_Gem", V(0.36, 0.36, 0.12), V(0, 0.35, -0.5), V(0, 0, 45), "accent", { material = "Neon" }),
		deco("UpperArm_L", "Deco_Shoulder_Crystal_L", V(0.18, 0.6, 0.18), V(-0.16, 0.6, 0), V(0, 45, 22), "accent", { material = "Glass" }),
		deco("UpperArm_L", "Deco_Shoulder_Crystal2_L", V(0.14, 0.42, 0.14), V(-0.1, 0.52, 0.16), V(0, 45, 12), "accent", { material = "Glass", lod = 2 }),
		deco("UpperArm_L", "Deco_Epaulet_L", V(0.62, 0.18, 0.56), V(0, 0.42, 0), V(0, 0, 8), "light"),
		deco("Forearm_L", "Deco_Bracelet_L", V(0.52, 0.14, 0.52), V(0, -0.3, 0), V(0, 0, 0), "accent", { material = "Glass" }),
		deco("Hips", "Deco_Belt", V(1.3, 0.14, 1.0), V(0, 0.2, 0), V(0, 0, 0), "light"),
		deco("Hips", "Deco_Belt_Gem", V(0.26, 0.26, 0.1), V(0, 0.15, -0.5), V(0, 0, 45), "accent", { material = "Neon" }),
		deco("SkirtF2", "Deco_Hem_F_L", V(0.14, 0.42, 0.14), V(-0.42, -0.45, 0), V(0, 45, 0), "accent", { material = "Glass", lod = 2 }),
		deco("SkirtB2", "Deco_Hem_B_L", V(0.14, 0.42, 0.14), V(-0.42, -0.45, 0), V(0, 45, 0), "accent", { material = "Glass", lod = 2 }),
		deco("SkirtL2", "Deco_Hem_Side_L", V(0.14, 0.4, 0.14), V(0, -0.45, -0.3), V(0, 45, 0), "accent", { material = "Glass", lod = 2 }),
		deco("ScepterGem", "Deco_Scepter_Prong_L", V(0.08, 0.42, 0.08), V(-0.28, 0.16, 0), V(0, 0, 25), "accent", { material = "Glass" }),
		deco("ScepterGem", "Deco_Scepter_ProngTop", V(0.08, 0.45, 0.08), V(0, 0.38, 0), V(0, 0, 0), "accent", { material = "Glass" }),
	}
	BossDetailSpec.bosses.crystal_queen = {
		joints = J,
		chains = { { "Wing2_L", lag = 0.5, sway = 4 }, { "Wing2_R", lag = 0.5, sway = 4, phase = 1.3 }, { "Train1", "Train2", "Train3", lag = 0.45, sway = 4 } },
		deco = mirrorX(D),
		recolor = {},
		themeColors = { body = Color3.fromRGB(222, 120, 172), head = Color3.fromRGB(246, 204, 224), accent = Color3.fromRGB(84, 226, 214) },
	}
end

-- ─────────────────────────── 폭풍 군주: 두건 쓴 폭풍 마법사 ───────────────────────────
-- 콘셉트: 천둥 첨탑의 군주. 두건(얼굴 그늘) · 높은 옷깃 · 가슴 번개 무늬(노란 빛) · 어깨 판 · 팔 보호대 · 허리 구슬 · 앞 · 뒤 옷자락(2차 움직임) · 지팡이 초승달 날.
do
	local J = {}
	chain(J, { prefix = "RobeF", parent = "Hips", count = 2, length = 0.55, w0 = 1.0, w1 = 1.12, thick = 0.08, at = V(0, -0.2, -0.48), rot0 = V(-4, 0, 0), rotStep = V(-3, 0, 0), color = "head" })
	chain(J, { prefix = "RobeB", parent = "Hips", count = 2, length = 0.62, w0 = 1.1, w1 = 1.2, thick = 0.08, at = V(0, -0.2, 0.48), rot0 = V(4, 0, 0), rotStep = V(3, 0, 0), color = "head" })
	local D = {
		deco("Head", "Deco_Hood_Shell", V(1.15, 0.62, 0.92), V(0, 0.34, 0.18), V(0, 0, 0), "shadow"),
		deco("Head", "Deco_Hood_Side_L", V(0.14, 0.84, 0.92), V(-0.56, 0, 0.12), V(0, 0, 0), "shadow"),
		deco("Head", "Deco_Hood_Peak", V(0.42, 0.32, 0.42), V(0, 0.64, -0.18), V(30, 45, 0), "shadow"),
		deco("Head", "Deco_Face_Mask", V(0.82, 0.36, 0.06), V(0, -0.24, -0.49), V(0, 0, 0), "shadow"),
		deco("Body", "Deco_Collar", V(1.5, 0.52, 0.26), V(0, 0.95, -0.32), V(-15, 0, 0), "head"),
		deco("Body", "Deco_Collar_Spike_L", V(0.12, 0.52, 0.12), V(-0.62, 1.12, -0.22), V(0, 0, 20), "accent", { material = "Neon", lod = 2 }),
		deco("Body", "Deco_Bolt_A", V(0.09, 0.52, 0.04), V(0, 0.42, -0.52), V(0, 0, 25), "accent", { material = "Neon" }),
		deco("Body", "Deco_Bolt_B", V(0.09, 0.42, 0.04), V(0.08, 0.06, -0.52), V(0, 0, -25), "accent", { material = "Neon" }),
		deco("Body", "Deco_Bolt_C", V(0.09, 0.42, 0.04), V(0, -0.28, -0.52), V(0, 0, 25), "accent", { material = "Neon" }),
		deco("UpperArm_L", "Deco_Shoulder_Plate_L", V(0.78, 0.3, 0.72), V(-0.05, 0.46, 0), V(0, 0, 15), "head"),
		deco("UpperArm_L", "Deco_Shoulder_Edge_L", V(0.72, 0.06, 0.06), V(-0.05, 0.62, -0.37), V(0, 0, 15), "accent", { material = "Neon", lod = 2 }),
		deco("Forearm_L", "Deco_Bracer_L", V(0.6, 0.42, 0.6), V(0, 0.05, 0), V(0, 0, 0), "shadow"),
		deco("Forearm_L", "Deco_Bracer_Rune_L", V(0.06, 0.34, 0.04), V(0, 0.05, -0.31), V(0, 0, 20), "accent", { material = "Neon", lod = 2 }),
		deco("Hips", "Deco_Belt", V(1.42, 0.26, 1.0), V(0, 0.15, 0), V(0, 0, 0), "shadow"),
		deco("Hips", "Deco_Belt_Orb", V(0.32, 0.32, 0.32), V(0, 0.12, -0.52), V(0, 0, 0), "accent", { shape = "ball", material = "Neon" }),
		deco("StaffOrb", "Deco_Staff_CrescentL", V(0.12, 0.72, 0.12), V(-0.46, 0.1, 0), V(0, 0, 25), "accent", { material = "Neon" }),
		deco("StaffOrb", "Deco_Staff_CrescentR", V(0.12, 0.72, 0.12), V(0.46, 0.1, 0), V(0, 0, -25), "accent", { material = "Neon" }),
		deco("StaffOrb", "Deco_Staff_Spike", V(0.1, 0.5, 0.1), V(0, 0.56, 0), V(0, 45, 0), "accent", { material = "Neon" }),
		deco("Shin_L", "Deco_Shin_Guard_L", V(0.56, 0.5, 0.16), V(0, 0.1, -0.3), V(0, 0, 0), "shadow"),
		deco("Thigh_L", "Deco_Knee_L", V(0.46, 0.32, 0.18), V(0, -0.46, -0.3), V(-10, 0, 0), "head"),
		deco("Foot_L", "Deco_Boot_L", V(0.66, 0.3, 1.0), V(0, 0.03, 0), V(0, 0, 0), "shadow"),
	}
	BossDetailSpec.bosses.storm_lord = {
		joints = J,
		chains = { { "RobeF1", "RobeF2", lag = 0.5, sway = 4 }, { "RobeB1", "RobeB2", lag = 0.5, sway = 5, phase = 1.4 } },
		deco = mirrorX(D),
		recolor = {},
		themeColors = { body = Color3.fromRGB(92, 97, 128), head = Color3.fromRGB(118, 124, 156), accent = Color3.fromRGB(255, 224, 64) },
	}
end

-- ─────────────────────────── 전갈 여왕: 모래 무덤의 여제(금 장신구) ───────────────────────────
-- 콘셉트: 사막 여제. 겹겹 등딱지 · 금 테두리 · 금 왕관 가시 · 큰 턱 · 옆 눈(세밀) · 집게 톱니(세밀) · 팔 금 띠 · 다리 가시(세밀) · 꼬리 금 고리 · 목걸이 보석 · 등 비단 베일(2차 움직임).
do
	local J = {}
	chain(J, { prefix = "Veil", parent = "Body", count = 3, length = 0.4, w0 = 1.0, w1 = 0.8, thick = 0.05, at = V(0, 0.55, 0.2), rot0 = V(70, 0, 0), rotStep = V(8, 0, 0), color = "accent", material = "Fabric" })
	local D = {
		deco("Body", "Deco_Carapace_Front", V(2.0, 0.22, 0.8), V(0, 0.52, -0.6), V(-6, 0, 0), "head"),
		deco("Body", "Deco_Carapace_Mid", V(2.1, 0.22, 0.8), V(0, 0.56, 0.05), V(-6, 0, 0), "head"),
		deco("Body", "Deco_Carapace_Back", V(1.9, 0.22, 0.75), V(0, 0.52, 0.7), V(-6, 0, 0), "head"),
		deco("Body", "Deco_Carapace_TrimF", V(2.04, 0.07, 0.09), V(0, 0.62, -0.98), V(0, 0, 0), "accent", { material = "Metal", lod = 2 }),
		deco("Body", "Deco_Carapace_TrimM", V(2.14, 0.07, 0.09), V(0, 0.66, -0.32), V(0, 0, 0), "accent", { material = "Metal", lod = 2 }),
		deco("Body", "Deco_Carapace_TrimB", V(1.94, 0.07, 0.09), V(0, 0.62, 0.34), V(0, 0, 0), "accent", { material = "Metal", lod = 2 }),
		deco("Body", "Deco_Side_Ridge_L", V(0.16, 0.32, 1.8), V(-1.26, 0.2, 0), V(0, 0, 0), "head"),
		deco("Body", "Deco_Necklace", V(1.2, 0.09, 0.09), V(0, 0.2, -1.13), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Body", "Deco_Necklace_Gem", V(0.22, 0.32, 0.1), V(0, 0.04, -1.15), V(0, 0, 0), "accent", { material = "Neon" }),
		deco("Head", "Deco_Crown_Band", V(1.1, 0.12, 0.6), V(0, 0.38, 0.15), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Head", "Deco_Crown_Spike", V(0.13, 0.5, 0.13), V(0, 0.62, 0.1), V(0, 45, 0), "accent", { material = "Metal" }),
		deco("Head", "Deco_Crown_SpikeSide_L", V(0.11, 0.4, 0.11), V(-0.36, 0.54, 0.16), V(0, 45, 14), "accent", { material = "Metal" }),
		deco("Head", "Deco_Mandible_L", V(0.14, 0.18, 0.48), V(-0.35, -0.25, -0.62), V(0, -20, 0), "light", { shape = "wedge" }),
		deco("Head", "Deco_Eye_Side_L", V(0.12, 0.12, 0.05), V(-0.46, 0.22, -0.46), V(0, 0, 0), "eye", { material = "Neon", lod = 2 }),
		deco("Hand_L", "Deco_Claw_Tooth_L", V(0.12, 0.32, 0.12), V(0.22, -0.3, -0.2), V(0, 45, 0), "light", { lod = 2 }),
		deco("Hand_L", "Deco_Claw_Tooth2_L", V(0.12, 0.28, 0.12), V(0.22, -0.02, -0.22), V(0, 45, 0), "light", { lod = 2 }),
		deco("Forearm_L", "Deco_Arm_Band_L", V(0.5, 0.14, 0.5), V(0, 0.2, 0), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Thigh1_L", "Deco_Leg_Spike1_L", V(0.1, 0.36, 0.1), V(0, 0.2, 0.15), V(0, 45, 0), "light", { lod = 2 }),
		deco("Thigh2_L", "Deco_Leg_Spike2_L", V(0.1, 0.36, 0.1), V(0, 0.2, 0.15), V(0, 45, 0), "light", { lod = 2 }),
		deco("Thigh3_L", "Deco_Leg_Spike3_L", V(0.1, 0.36, 0.1), V(0, 0.2, 0.15), V(0, 45, 0), "light", { lod = 2 }),
		deco("Tail1_7", "Deco_Tail1_Ring", V(0.36, 0.1, 0.36), V(0, 0, 0), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Tail2_7", "Deco_Tail2_Ring", V(0.36, 0.1, 0.36), V(0, 0, 0), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Tail3_7", "Deco_Tail3_Ring", V(0.36, 0.1, 0.36), V(0, 0, 0), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Tail1_3", "Deco_Tail1_Plate", V(0.52, 0.12, 0.44), V(0, 0, 0.22), V(0, 0, 0), "head", { lod = 2 }),
		deco("Tail2_3", "Deco_Tail2_Plate", V(0.52, 0.12, 0.44), V(0, 0, 0.22), V(0, 0, 0), "head", { lod = 2 }),
		deco("Tail3_3", "Deco_Tail3_Plate", V(0.52, 0.12, 0.44), V(0, 0, 0.22), V(0, 0, 0), "head", { lod = 2 }),
	}
	BossDetailSpec.bosses.scorpion_queen = {
		joints = J,
		chains = { { "Veil1", "Veil2", "Veil3", lag = 0.5, sway = 6 } },
		deco = mirrorX(D),
		recolor = {},
		themeColors = { body = Color3.fromRGB(168, 95, 38), head = Color3.fromRGB(206, 150, 104), accent = Color3.fromRGB(255, 196, 60) },
	}
end

return BossDetailSpec
