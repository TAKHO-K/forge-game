-- BR1-4c c-12 보스맵 구조물 겉모양 1차(전체 카툰 전 "볼만하게"). 충돌 · 판정은 그대로(BossArenaMap의 투명 충돌 기둥) - 여기는 보이는 조각만(충돌 · 조준 없음).
-- 소품 = 조각 목록(레시피). 서버가 보스전마다 이 레시피로 짓고, 시작할 때 기준 크기 모델을 ReplicatedStorage.Assets.Props/<kind>에 한 벌 만들어 둔다(A2 카툰 모델 교체 자리 -
-- 그 폴더에 Authored 속성을 단 모델을 넣으면 레시피 대신 그 모델을 복제해 크기만 맞춘다: server/BossArenaLooks).
--
-- ★ 가독성 규칙 하나(형태 = 윗면 · 색 = 톤):
--   올라갈 수 있는 큰 블록(group big) = **평평하고 밝은 윗면 판**(top 톤 · 테두리 띠) + 어두운 옆면 - "밝은 평면 = 설 수 있다".
--     올라갈 수 있으면서 부서지면(지금 큰 블록 전부 - hitsToBreak) 처음부터 윗면 테두리에 어두운 금 무늬(W2 파트 0 - "설 수 있지만 부서진다").
--   부서지는 구조물(group small · feature) = **둥글거나 뾰족한 윗면**(평평한 밝은 판 없음) · 옆면 톤 + 밑동 어둡게 + 맵 장식(이끼 · 눈 · 수정 · 모래 · 금속).
--   그냥 장식(벽 바깥 테라스) = 채도 · 명도를 테라스 색 쪽으로 decorMuteFraction만큼 눌러 배경으로 물러난다(외곽선 모델은 그대로).
--
-- 조각 = { n = 이름, s = "block" | "ball" | "cyl"(세운 원기둥) | "wedge", t = 톤, size = { x, y, z }, at = { x, y, z }, rot = { x, y, z }(도), u = true(크기를 전부 r배) }
--   크기 · 자리: x · z = r배(반경), y = h배(높이) - big/small은 r = 배치 반경 · h = 윗면 높이, perCollider 레시피는 충돌 원마다 그 원의 r · h.
--   특수: mound = true(눈더미 - 공 윗부분이 충돌 원 안) · span = true(첫 두 기둥 사이 들보 - y = lintelStuds + at.y 절대값 · size.y 절대 두께).
-- 톤 = top(밝게) · side(구조물 색) · base(어둡게) · crack(아주 어둡게 - 테두리 금) · detail(맵 장식색) · glow(보스 머리색 빛) · crystal(맵 장식색 빛).

local OBSTACLE = require(script.Parent.BossArenaMapData).obstacle

local tones = {
	topLighten = 0.24, -- 윗면 = 구조물 색 → 흰색 쪽
	baseDarken = 0.3, -- 밑동 = 구조물 색 → 검정 쪽
	decorMuteFraction = 0.35, -- 벽 밖 장식 → 테라스 색 쪽(배경으로)
	-- 바닥과 대비: 구조물 색의 밝기가 바닥과 minFloorContrast보다 가까우면(빙하 · 모래처럼 밝은 바닥) 구조물 색을 contrastDarken만큼 어둡게 한 뒤 톤을 나눈다
	minFloorContrast = 0.2,
	contrastDarken = 0.32,
	crackDarken = 0.6, -- W2 파트 0: 테두리 금 무늬(crack 톤) = 구조물 색 → 검정 쪽
}

-- 맵 장식색(맵 테마) - A1 카툰 팔레트 쪽 채도 있는 한 톤.
local detail = {
	section_guardian = { color = Color3.fromRGB(150, 118, 214), material = Enum.Material.Neon, transparency = 0.2 }, -- 공허 룬 이끼(빛)
	frost_giant = { color = Color3.fromRGB(246, 251, 255), material = Enum.Material.SmoothPlastic, transparency = 0 }, -- 눈
	abyssal_lord = { color = Color3.fromRGB(86, 148, 96), material = Enum.Material.SmoothPlastic, transparency = 0 }, -- 이끼
	crystal_queen = { color = Color3.fromRGB(140, 232, 246), material = Enum.Material.Neon, transparency = 0.15 }, -- 수정
	scorpion_queen = { color = Color3.fromRGB(236, 212, 156), material = Enum.Material.SmoothPlastic, transparency = 0 }, -- 쌓인 모래
	storm_lord = { color = Color3.fromRGB(150, 158, 178), material = Enum.Material.Metal, transparency = 0 }, -- 금속 띠
	default = { color = Color3.fromRGB(120, 160, 110), material = Enum.Material.SmoothPlastic, transparency = 0 },
}

-- 구조물당 조각 상한(충돌 원 여럿이면 합) - 동시 상한 14개 × 이 값이 클라 파트 증가의 상한이다.
local maxPartsPerStructure = 20

local P = {}

-- W2 파트 0 가독성 보완: 올라갈 수 있으면서 부서지는 것(큰 블록 - 단상 · 큰 바위판) = 평평한 윗면 + **처음부터 테두리에 금 무늬**.
--   윗면 가장자리에서 안쪽으로 뻗는 어두운 가는 금(바깥 끝 → 안쪽) + 곁가지 - 판정 · 충돌 무관(보이는 조각만).
local function rimCracks(topY, rimRadius, anglesDeg)
	local pieces = {}
	for i, deg in ipairs(anglesDeg) do
		-- 바깥 마디(테두리에서 안쪽으로) → 안쪽 마디(28° 꺾임 - 번개 모양) + 홀수 번째는 곁가지
		local a = math.rad(deg)
		local outer = (i % 2 == 0) and 0.32 or 0.26
		local mid = rimRadius - outer / 2
		table.insert(pieces, { n = "RimCrack", s = "block", t = "crack", size = { outer, 0.02, 0.07 }, at = { math.cos(a) * mid, topY, math.sin(a) * mid }, rot = { 0, -deg, 0 } })
		local bend = deg + ((i % 2 == 0) and 28 or -28)
		local b = math.rad(bend)
		local inner = 0.2
		local joint = rimRadius - outer
		local c = Vector3.new(math.cos(a) * joint - math.cos(b) * inner / 2, 0, math.sin(a) * joint - math.sin(b) * inner / 2)
		table.insert(pieces, { n = "RimCrack", s = "block", t = "crack", size = { inner, 0.02, 0.055 }, at = { c.X, topY, c.Z }, rot = { 0, -bend, 0 } })
		if i % 2 == 1 then -- 곁가지(바깥 끝 가까이서 비스듬히)
			local s = a + math.rad(9)
			table.insert(pieces, { n = "RimCrack", s = "block", t = "crack", size = { 0.13, 0.02, 0.045 }, at = { math.cos(s) * (rimRadius - 0.1), topY, math.sin(s) * (rimRadius - 0.1) }, rot = { 0, -(deg + 50), 0 } })
		end
	end
	return pieces
end

local function withCracks(recipe, cracks)
	for _, piece in ipairs(cracks) do
		table.insert(recipe, piece)
	end
	return recipe
end

-- ═══ 올라갈 수 있는 큰 블록(윗면 = climbHeightStuds · 밝은 판 + 테두리 금) ═══
P.rockpile = withCracks({
	{ n = "Core", s = "cyl", t = "side", size = { 1.84, 0.9, 1.84 }, at = { 0, 0.45, 0 } },
	{ n = "Bevel", s = "cyl", t = "side", size = { 1.9, 0.08, 1.9 }, at = { 0, 0.92, 0 } },
	{ n = "Top", s = "cyl", t = "top", size = { 1.78, 0.03, 1.78 }, at = { 0, 0.985, 0 } }, -- 윗면 = 1.0h(서는 면)
	{ n = "Skirt", s = "cyl", t = "base", size = { 2.0, 0.12, 2.0 }, at = { 0, 0.06, 0 } },
	{ n = "Stone", s = "ball", t = "base", size = { 0.36, 0.36, 0.36 }, at = { 0.8, 0.28, 0.3 }, u = true },
	{ n = "Stone", s = "ball", t = "side", size = { 0.3, 0.3, 0.3 }, at = { -0.55, 0.25, 0.7 }, u = true },
	{ n = "Stone", s = "ball", t = "base", size = { 0.32, 0.32, 0.32 }, at = { -0.7, 0.26, -0.55 }, u = true },
	{ n = "Stone", s = "ball", t = "side", size = { 0.28, 0.28, 0.28 }, at = { 0.35, 0.22, -0.85 }, u = true },
	{ n = "Patch", s = "cyl", t = "detail", size = { 0.5, 0.02, 0.36 }, at = { 0.45, 1.0, 0.35 } },
	{ n = "Patch", s = "cyl", t = "detail", size = { 0.36, 0.02, 0.5 }, at = { -0.5, 1.0, -0.3 } },
}, rimCracks(1.0, 0.89, { 20, 150, 265 }))
P.dolmen = withCracks({
	{ n = "Leg", s = "block", t = "base", size = { 0.24, 0.78, 0.3 }, at = { 0.55, 0.39, 0 }, rot = { 0, 0, 4 } },
	{ n = "Leg", s = "block", t = "base", size = { 0.24, 0.78, 0.3 }, at = { -0.28, 0.39, 0.48 }, rot = { 0, 120, 4 } },
	{ n = "Leg", s = "block", t = "base", size = { 0.24, 0.78, 0.3 }, at = { -0.28, 0.39, -0.48 }, rot = { 0, 240, 4 } },
	{ n = "Slab", s = "cyl", t = "side", size = { 2.0, 0.2, 2.0 }, at = { 0, 0.87, 0 } },
	{ n = "Top", s = "cyl", t = "top", size = { 1.9, 0.03, 1.9 }, at = { 0, 0.985, 0 } },
	{ n = "Patch", s = "cyl", t = "detail", size = { 0.45, 0.02, 0.3 }, at = { -0.4, 1.0, 0.45 } },
	{ n = "Patch", s = "cyl", t = "detail", size = { 0.3, 0.02, 0.42 }, at = { 0.5, 1.0, -0.35 } },
}, rimCracks(1.0, 0.95, { 75, 200, 320 }))

-- ═══ 작은 구조물(윗면 = heightStuds · 못 올라간다 = 뾰족 · 둥근 윗면) ═══
P.block = { -- 모서리 깎은 바위(지붕 모양 능선)
	{ n = "Skirt", s = "block", t = "base", size = { 1.3, 0.12, 1.15 }, at = { 0, 0.06, 0 } },
	{ n = "Body", s = "block", t = "side", size = { 1.2, 0.62, 1.05 }, at = { 0, 0.4, 0 }, rot = { 0, 0, 3 } },
	{ n = "Ridge", s = "wedge", t = "side", size = { 1.2, 0.38, 0.53 }, at = { 0, 0.9, 0.26 }, rot = { 0, 180, 0 } },
	{ n = "Ridge", s = "wedge", t = "top", size = { 1.2, 0.38, 0.53 }, at = { 0, 0.9, -0.26 } },
	{ n = "Chip", s = "block", t = "base", size = { 0.45, 0.4, 0.45 }, at = { 0.55, 0.2, 0.45 }, rot = { 8, 35, 0 } },
	{ n = "Moss", s = "wedge", t = "detail", size = { 1.0, 0.1, 0.3 }, at = { 0.05, 1.0, -0.36 } },
}
P.boulder = { -- 둥근 바위 + 윗빛 공(밝은 톤) + 밑동
	{ n = "Skirt", s = "cyl", t = "base", size = { 1.7, 0.1, 1.7 }, at = { 0, 0.05, 0 } },
	{ n = "Body", s = "ball", t = "side", size = { 1.75, 1.75, 1.75 }, at = { 0, 0.62, 0 }, u = true },
	{ n = "Light", s = "ball", t = "top", size = { 1.05, 1.05, 1.05 }, at = { -0.2, 0.93, -0.18 }, u = true },
	{ n = "Side", s = "ball", t = "base", size = { 0.9, 0.9, 0.9 }, at = { 0.55, 0.3, 0.35 }, u = true },
	{ n = "Cap", s = "cyl", t = "detail", size = { 0.8, 0.05, 0.8 }, at = { -0.15, 1.0, -0.15 } },
}
P.stump = { -- 부러진 기둥(기운 단면 - 평평한 밝은 판 아님)
	{ n = "Base", s = "cyl", t = "base", size = { 1.7, 0.14, 1.7 }, at = { 0, 0.07, 0 } },
	{ n = "Shaft", s = "cyl", t = "side", size = { 1.4, 0.82, 1.4 }, at = { 0, 0.51, 0 } },
	{ n = "Break", s = "cyl", t = "side", size = { 1.3, 0.12, 1.3 }, at = { 0, 0.92, 0 }, rot = { 0, 0, 16 } },
	{ n = "Flute", s = "block", t = "base", size = { 0.12, 0.7, 0.12 }, at = { 0.7, 0.5, 0 } },
	{ n = "Flute", s = "block", t = "base", size = { 0.12, 0.7, 0.12 }, at = { -0.7, 0.5, 0 } },
	{ n = "Moss", s = "cyl", t = "detail", size = { 1.45, 0.08, 1.45 }, at = { 0, 0.3, 0 } },
}
P.cluster = { -- 수정 다발(뾰족 끝)
	{ n = "Rock", s = "ball", t = "base", size = { 1.3, 1.3, 1.3 }, at = { 0, 0.1, 0 }, u = true },
	{ n = "Prism", s = "block", t = "side", size = { 0.5, 0.75, 0.5 }, at = { 0, 0.42, 0 }, rot = { 0, 20, 6 } },
	{ n = "Tip", s = "wedge", t = "crystal", size = { 0.5, 0.25, 0.5 }, at = { 0.02, 0.92, 0 }, rot = { 0, 20, 6 } },
	{ n = "Prism", s = "block", t = "side", size = { 0.36, 0.55, 0.36 }, at = { 0.5, 0.3, 0.3 }, rot = { 18, 60, -14 } },
	{ n = "Tip", s = "wedge", t = "crystal", size = { 0.36, 0.2, 0.36 }, at = { 0.58, 0.66, 0.35 }, rot = { 18, 60, -14 } },
	{ n = "Prism", s = "block", t = "side", size = { 0.34, 0.5, 0.34 }, at = { -0.45, 0.28, -0.35 }, rot = { -16, 140, 12 } },
	{ n = "Tip", s = "wedge", t = "crystal", size = { 0.34, 0.2, 0.34 }, at = { -0.52, 0.62, -0.4 }, rot = { -16, 140, 12 } },
}

-- ═══ 작은 지형지물(충돌 원마다 - perCollider) ═══
P.icePillars = { perCollider = true,
	{ n = "Base", s = "cyl", t = "base", size = { 2.1, 0.08, 2.1 }, at = { 0, 0.04, 0 } },
	{ n = "Pillar", s = "cyl", t = "side", size = { 1.8, 0.86, 1.8 }, at = { 0, 0.45, 0 } },
	{ n = "Tip", s = "ball", t = "top", size = { 1.6, 1.6, 1.6 }, at = { 0, 0.88, 0 }, u = true },
	{ n = "Snow", s = "cyl", t = "detail", size = { 1.9, 0.04, 1.9 }, at = { 0, 0.62, 0 } },
}
P.snowMound = { perCollider = true,
	{ n = "Mound", s = "ball", t = "side", mound = true },
	{ n = "Shade", s = "cyl", t = "base", size = { 1.85, 0.06, 1.85 }, at = { 0, 0.03, 0 } },
}
P.statue = { perCollider = true,
	{ n = "Plinth", s = "block", t = "base", size = { 1.3, 0.19, 1.3 }, at = { 0, 0.095, 0 } },
	{ n = "Step", s = "block", t = "side", size = { 1.05, 0.08, 1.05 }, at = { 0, 0.23, 0 } },
	{ n = "Body", s = "block", t = "side", size = { 0.8, 0.5, 0.55 }, at = { 0, 0.52, 0 } },
	{ n = "Shoulder", s = "wedge", t = "top", size = { 0.8, 0.07, 0.55 }, at = { 0, 0.8, 0 } },
	{ n = "Head", s = "ball", t = "top", size = { 0.7, 0.7, 0.7 }, at = { 0, 0.9, 0 }, u = true },
	{ n = "Moss", s = "block", t = "detail", size = { 0.82, 0.1, 0.57 }, at = { 0, 0.3, 0 } },
}
P.brokenArch = { perCollider = true, lintel = { broken = true },
	{ n = "Base", s = "cyl", t = "base", size = { 2.3, 0.07, 2.3 }, at = { 0, 0.035, 0 } },
	{ n = "Leg", s = "cyl", t = "side", size = { 2.0, 0.9, 2.0 }, at = { 0, 0.5, 0 } },
	{ n = "Ring", s = "cyl", t = "top", size = { 2.15, 0.04, 2.15 }, at = { 0, 0.94, 0 } },
	{ n = "Moss", s = "cyl", t = "detail", size = { 2.08, 0.05, 2.08 }, at = { 0, 0.25, 0 } },
	{ n = "Lintel", s = "block", t = "top", span = true, size = { 1, 1.2, 2 }, at = { 0, 0.6, 0 } },
}
P.ruinGate = { perCollider = true, lintel = { broken = false },
	{ n = "Base", s = "block", t = "base", size = { 1.6, 0.07, 1.6 }, at = { 0, 0.035, 0 } },
	{ n = "Leg", s = "block", t = "side", size = { 1.35, 0.9, 1.35 }, at = { 0, 0.5, 0 } },
	{ n = "Cap", s = "block", t = "top", size = { 1.55, 0.06, 1.55 }, at = { 0, 0.96, 0 } },
	{ n = "Sand", s = "wedge", t = "detail", size = { 1.35, 0.12, 0.6 }, at = { 0, 0.1, 0.95 }, rot = { 0, 180, 0 } },
	{ n = "Lintel", s = "block", t = "top", span = true, size = { 1, 1.2, 2 }, at = { 0, 0.6, 0 } },
	{ n = "LintelShade", s = "block", t = "base", span = true, size = { 1, 0.3, 2.1 }, at = { 0, -0.1, 0 } },
}
P.crystalCluster = { perCollider = true,
	{ n = "Rock", s = "ball", t = "base", size = { 1.8, 1.8, 1.8 }, at = { 0, 0.02, 0 }, u = true },
	{ n = "Crystal", s = "block", t = "side", size = { 1.2, 0.8, 1.2 }, at = { 0, 0.42, 0 }, rot = { 5, 30, -4 } },
	{ n = "Tip", s = "wedge", t = "crystal", size = { 1.2, 0.2, 1.2 }, at = { 0.03, 0.92, 0 }, rot = { 5, 30, -4 } },
}
P.ruinFragment = { perCollider = true,
	{ n = "Skirt", s = "block", t = "base", size = { 1.45, 0.1, 1.15 }, at = { 0, 0.05, 0 } },
	{ n = "Body", s = "block", t = "side", size = { 1.35, 0.7, 1.05 }, at = { 0, 0.42, 0 }, rot = { 0, 0, 4 } },
	{ n = "Break", s = "wedge", t = "top", size = { 1.35, 0.25, 1.05 }, at = { 0, 0.9, 0 } },
	{ n = "Carve", s = "block", t = "base", size = { 1.37, 0.06, 0.2 }, at = { 0, 0.55, 0 } },
	{ n = "Sand", s = "wedge", t = "detail", size = { 1.3, 0.22, 0.5 }, at = { 0, 0.11, 0.75 }, rot = { 0, 180, 0 } },
}
P.cactus = { perCollider = true,
	{ n = "Sand", s = "cyl", t = "detail", size = { 1.8, 0.06, 1.8 }, at = { 0, 0.03, 0 } },
	{ n = "Trunk", s = "cyl", t = "side", size = { 1.15, 0.94, 1.15 }, at = { 0, 0.47, 0 } },
	{ n = "Crown", s = "ball", t = "top", size = { 0.58, 0.58, 0.58 }, at = { 0, 0.94, 0 }, u = true },
	{ n = "Arm", s = "cyl", t = "side", size = { 0.5, 0.33, 0.5 }, at = { 0.75, 0.55, 0 } },
	{ n = "ArmTip", s = "ball", t = "top", size = { 0.25, 0.25, 0.25 }, at = { 0.75, 0.72, 0 }, u = true },
	{ n = "Arm", s = "cyl", t = "side", size = { 0.5, 0.27, 0.5 }, at = { -0.75, 0.64, 0 } },
	{ n = "ArmTip", s = "ball", t = "top", size = { 0.25, 0.25, 0.25 }, at = { -0.75, 0.78, 0 }, u = true },
	{ n = "Flower", s = "ball", t = "glow", size = { 0.25, 0.25, 0.25 }, at = { 0, 1.05, 0 }, u = true },
}
P.rodWreck = { perCollider = true, variants = { -- 1번 원 = 쓰러진 피뢰침 · 2번 = 잔해
	{
		{ n = "Base", s = "cyl", t = "base", size = { 1.6, 0.07, 1.6 }, at = { 0, 0.035, 0 } },
		{ n = "Rod", s = "block", t = "detail", size = { 0.62, 1.0, 0.62 }, at = { 0, 0.5, 0 }, rot = { 6, 0, -5 } },
		{ n = "Band", s = "block", t = "base", size = { 0.7, 0.05, 0.7 }, at = { 0, 0.4, 0 }, rot = { 6, 0, -5 } },
		{ n = "Tip", s = "ball", t = "glow", size = { 0.8, 0.8, 0.8 }, at = { -0.3, 1.0, 0 }, u = true },
	},
	{
		{ n = "Skirt", s = "block", t = "base", size = { 1.4, 0.2, 1.25 }, at = { 0, 0.1, 0 } },
		{ n = "Debris", s = "wedge", t = "side", size = { 1.3, 0.8, 1.2 }, at = { 0, 0.55, 0 }, rot = { 0, 30, 0 } },
		{ n = "Metal", s = "block", t = "detail", size = { 1.1, 0.12, 0.2 }, at = { 0, 0.3, 0.2 }, rot = { 0, 30, 10 } },
	},
} }
P.rubble = { perCollider = true,
	{ n = "Chunk", s = "block", t = "side", size = { 1.3, 0.7, 1.15 }, at = { 0, 0.35, 0 }, rot = { 6, 47, 0 } },
	{ n = "Chamfer", s = "wedge", t = "top", size = { 1.3, 0.35, 1.15 }, at = { 0, 0.87, 0 }, rot = { 6, 47, 0 } },
	{ n = "Skirt", s = "block", t = "base", size = { 1.45, 0.12, 1.3 }, at = { 0, 0.06, 0 }, rot = { 0, 47, 0 } },
}
P.runeStones = { perCollider = true,
	{ n = "Base", s = "block", t = "base", size = { 1.7, 0.08, 1.3 }, at = { 0, 0.04, 0 } },
	{ n = "Stone", s = "block", t = "side", size = { 1.3, 0.84, 0.9 }, at = { 0, 0.46, 0 } },
	{ n = "Point", s = "wedge", t = "top", size = { 1.3, 0.16, 0.45 }, at = { 0, 0.96, 0.225 }, rot = { 0, 180, 0 } },
	{ n = "Point", s = "wedge", t = "side", size = { 1.3, 0.16, 0.45 }, at = { 0, 0.96, -0.225 } },
	{ n = "Rune", s = "block", t = "glow", size = { 0.6, 0.14, 0.95 }, at = { 0, 0.6, 0 } },
}

-- 균열 단계(맞은 횟수 → 남은 타격). 1단계 = 가는 금(색 그대로) · 2단계 = 굵은 금 + 빨간 빛 금 + 위험색 틴트(옛 crackAtHitsLeft = 1과 같은 순간). 판정 그대로(겉모습만).
local crackStages = {
	{ hitsLeft = 3, lines = 3, widthStuds = 0.35, tintFraction = 0, glow = false },
	{ hitsLeft = OBSTACLE.crackAtHitsLeft, lines = 6, widthStuds = 0.7, tintFraction = 0.35, glow = true }, -- 리뷰: 마지막 단계 = crackAtHitsLeft(obstacle.cracked와 같은 순간)
}

-- 파괴 파편(클라 BossArenaMapView): 조각 수 · 크기 배율 · 먼지 고리(옛 10조각 · 먼지 없음).
local debris = { pieces = 16, sizeScale = 1.15, dustPuffs = 10, flash = true }

return {
	tones = tones,
	detail = detail,
	recipes = P,
	maxPartsPerStructure = maxPartsPerStructure,
	crackStages = crackStages,
	debris = debris,
	library = { folder = "Props", refRadius = 4, authoredAttribute = "Authored" },
}
