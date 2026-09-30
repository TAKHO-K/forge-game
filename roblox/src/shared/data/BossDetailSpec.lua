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

return BossDetailSpec
