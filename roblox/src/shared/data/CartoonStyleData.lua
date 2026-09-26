-- A1 카툰 스타일 프로필(shared/CartoonStyle이 적용 · 클라 OutlinePool · CartoonZoneTint가 읽는다). 모든 색 · 수치는 여기만.
-- 프로필 = lighting(Lighting 속성) · effects(Lighting 자식 효과 - 이름 고정) · terrain(Terrain 물 속성 + MaterialColors) · materialOverrides(텍스처 없는 MaterialVariant로 덮을 재질) ·
--   props(소품 그림자) · palette(구역별 기본 · 강조색 - art-spec 2장) · zoneTint(구역별 색조 - 클라) · outline(외곽선 풀) · vfx(수량 · 거리 예산) · rarity(등급 표현).
-- base = 지금 place 값(A1 시작 때 Studio에서 읽음 - 되돌리기 기준). cartoon = A1 후보.
-- 관리 속성 목록(managed) 밖의 속성은 Apply가 절대 건드리지 않는다(docs/art/cartoon-pipeline.md).

local TerrainGenData = require(script.Parent.TerrainGenData)
local WorldMapData = require(script.Parent.WorldMapData)

local function rgb(hex)
	return { tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16) }
end

-- 지형 재질 전체(덮어쓰기 · 색 관리 대상) - TerrainGenData.materialColors의 키 + 길 재질
local TERRAIN_MATERIALS = { "Grass", "LeafyGrass", "Rock", "Mud", "Limestone", "Slate", "Pavement", "Basalt", "Sand", "Sandstone", "Ground", "Cobblestone", "Snow", "Ice", "Glacier", "Salt", "Asphalt" }

local managed = {
	lighting = { "Ambient", "OutdoorAmbient", "Brightness", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness", "ColorShift_Top", "ColorShift_Bottom" },
	effects = {
		Atmosphere = { class = "Atmosphere", props = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" } },
		Bloom = { class = "BloomEffect", props = { "Enabled", "Intensity", "Size", "Threshold" } },
		SunRays = { class = "SunRaysEffect", props = { "Enabled", "Intensity", "Spread" } },
		CartoonColorCorrection = { class = "ColorCorrectionEffect", props = { "Enabled", "Brightness", "Contrast", "Saturation", "TintColor" } }, -- 없으면 만든다(이름 고정)
	},
	terrain = { "WaterColor", "WaterTransparency", "WaterReflectance", "WaterWaveSize" },
	terrainMaterials = TERRAIN_MATERIALS,
	-- 맵 파트 색(이름으로 찾는다 - Workspace.Ground.<model> 아래 BasePart.Color): 허브 바닥 원판 · 포탈 광장 · 거리 바닥(A1 - 흰 원판이 허브 화면을 덮었다)
	mapParts = { model = "Hub", names = { "HubFloor", "PortalPlaza", "DistrictFloor" } },
	-- MaterialService: 위 재질의 BaseMaterialOverride(카툰 = "CartoonFlat_<재질>" · base = "") + 폴더 MaterialService.CartoonStyle 안 변형
	-- 소품(Workspace 안 Attribute Prop이 있는 모델의 BasePart): CastShadow (원래 값 = Attribute CSBaseCastShadow에 한 번 적어 둔다)
	-- Workspace Attribute CartoonStyle(지금 프로필 이름 - 클라가 읽는다)
}

local base = {
	lighting = {
		Ambient = { 70, 70, 70 }, OutdoorAmbient = { 70, 70, 70 }, Brightness = 3, ExposureCompensation = 0,
		EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, ShadowSoftness = 0.2,
		ColorShift_Top = { 0, 0, 0 }, ColorShift_Bottom = { 0, 0, 0 },
	},
	effects = {
		-- 밀도 · 오프셋 = 부팅 때 HuntingGround가 넣는 WorldMapData.atmosphere(place 값 0.3 · 0.25가 아니라 실행 중 값이 기준)
		Atmosphere = { Density = WorldMapData.atmosphere.density, Offset = WorldMapData.atmosphere.offset, Color = { 199, 199, 199 }, Decay = { 106, 112, 125 }, Glare = 0, Haze = 0 },
		Bloom = { Enabled = true, Intensity = 1, Size = 24, Threshold = 2 },
		SunRays = { Enabled = true, Intensity = 0.01, Spread = 0.1 },
		CartoonColorCorrection = { Enabled = false, Brightness = 0, Contrast = 0, Saturation = 0, TintColor = { 255, 255, 255 } },
	},
	terrain = { WaterColor = { 70, 130, 170 }, WaterTransparency = 0.35, WaterReflectance = 0.6, WaterWaveSize = 0.13 },
	materialColors = TerrainGenData.materialColors, -- base = 굽기 데이터 그대로(단일 출처)
	materialOverrides = false, -- 덮어쓰기 없음(엔진 기본 텍스처)
	props = { smallShadowOff = false },
	mapParts = { HubFloor = WorldMapData.colors.safe, PortalPlaza = WorldMapData.colors.blockLight, DistrictFloor = WorldMapData.colors.road }, -- 맵 코드가 쓰는 원래 색(단일 출처)
	outline = { enabled = false }, -- 조준 외곽선만(아래 공통 aim)
	zoneTint = false,
}

local cartoon = {
	-- 평면 카툰: 반사광(스펙큘러) 0 · 환경광을 올려 그늘을 가볍게 · 그림자 경계 선명 · 채도 조금 올림. 블룸 약하게.
	lighting = {
		Ambient = { 96, 98, 112 }, OutdoorAmbient = { 150, 152, 165 }, Brightness = 2.4, ExposureCompensation = 0,
		EnvironmentDiffuseScale = 0.45, EnvironmentSpecularScale = 0, ShadowSoftness = 0.08,
		ColorShift_Top = { 255, 244, 228 }, ColorShift_Bottom = { 0, 0, 0 },
	},
	effects = {
		Atmosphere = { Density = 0.1, Offset = 0.05, Color = { 190, 216, 245 }, Decay = { 150, 180, 220 }, Glare = 0, Haze = 0.4 }, -- 밀도는 base처럼 낮게(먼 나무 · 빛기둥 유지) · 푸른 원경
		Bloom = { Enabled = true, Intensity = 0.35, Size = 18, Threshold = 1.6 },
		SunRays = { Enabled = true, Intensity = 0.015, Spread = 0.15 },
		CartoonColorCorrection = { Enabled = true, Brightness = 0.02, Contrast = 0.06, Saturation = 0.08, TintColor = { 255, 255, 255 } },
	},
	terrain = { WaterColor = rgb("#2EC4D6"), WaterTransparency = 0.15, WaterReflectance = 0.05, WaterWaveSize = 0.08 },
	-- art-spec 2장 HEX 출발 → 공유 재질은 한 색(구역별로 가르려면 재질을 바꿔 다시 굽기 - A1 보고서 결정)
	materialColors = {
		Grass = rgb("#6DBA46"), -- (A1 화면 조정 - 시트 #7BC950은 실사 잔디 장식과 겹쳐 너무 밝았다) 허브 #6CC24A · T1 #7BC950 (T3 바닥2 공유)
		LeafyGrass = rgb("#5DAE45"), -- T1 이끼 띠 #4E9A3A 쪽 · T3 바닥 · 선인장 · 잎(공유)
		Rock = rgb("#A8A29A"), -- T1 돌(모든 구역 급경사 공유)
		Mud = rgb("#7A6448"),
		Limestone = rgb("#D9C9A3"), -- 허브 돌길 · T1 폐허 · T5 길(공유)
		Slate = rgb("#55468F"), Pavement = rgb("#63529E"), -- T2 바닥(시트 #4B3A8C보다 조금 밝게 - 멀리서 과포화)
		Basalt = rgb("#3B3070"), -- T2 비탈 · T5 바닥2(공유)
		Sand = rgb("#F2C46B"), Sandstone = rgb("#D9924A"), Salt = rgb("#EAD7A6"), -- T4
		Ground = rgb("#B38A5E"), -- T1 · T6 흙길 · T5 바닥(공유 - 충돌: T5 바닥 #3A3F5C)
		Cobblestone = rgb("#4A4F6E"), -- T5 비탈
		Snow = rgb("#F4F8FC"), Ice = rgb("#A9D8F5"), Glacier = rgb("#8CC3EA"), -- T6
		Asphalt = rgb("#3C3552"), -- T2 길
	},
	materialOverrides = true, -- 위 재질 전부 "텍스처 없는 변형" = 평면 면 음영(텍스처 0장)
	props = { smallShadowOff = true, smallMaxSize = 6 }, -- 가장 긴 변 ≤ 6인 소품 파트는 그림자 끔
	mapParts = { HubFloor = rgb("#6CC24A"), PortalPlaza = rgb("#D9C9A3"), DistrictFloor = rgb("#D9C9A3") }, -- 허브 잔디 · 돌길(art-spec 허브)
	outline = { enabled = true },
	zoneTint = true,
}

return {
	active = "base", -- 부팅 때 적용할 프로필(A1 승인 뒤 "cartoon"으로). /gg style base|cartoon 으로 즉시 전환
	managed = managed,
	profiles = { base = base, cartoon = cartoon },
	variantPrefix = "CartoonFlat_",

	-- 구역 팔레트(art-spec 2장 - A1 확정표 · 관문 테두리 = 상호작용 신호). 코어(포탈 · 관문 안쪽)는 전 구역 공통.
	portalCore = rgb("#4FD1FF"),
	palette = {
		hub = { ground = rgb("#6CC24A"), main1 = rgb("#D9C9A3"), main2 = rgb("#3A5BA0"), shade = rgb("#8B5A2B"), rim = nil },
		tier1 = { ground = rgb("#7BC950"), main1 = rgb("#A8A29A"), main2 = rgb("#9BA7B0"), shade = rgb("#6E6A66"), rim = rgb("#5CE08A") },
		tier2 = { ground = rgb("#4B3A8C"), main1 = rgb("#D26CF0"), main2 = rgb("#F59AE6"), shade = rgb("#2A1F55"), rim = rgb("#D26CF0") },
		tier3 = { ground = rgb("#2EC4D6"), main1 = rgb("#C9E4EA"), main2 = rgb("#3BA8A0"), shade = rgb("#1B7FA8"), rim = rgb("#7FF0FF") },
		tier4 = { ground = rgb("#F2C46B"), main1 = rgb("#D9924A"), main2 = rgb("#4E9A3A"), shade = rgb("#A8612E"), rim = rgb("#FFD34D") },
		tier5 = { ground = rgb("#3A3F5C"), main1 = rgb("#5A3F9E"), main2 = rgb("#7FE3FF"), shade = rgb("#2B2F6B"), rim = rgb("#B45CFF") },
		tier6 = { ground = rgb("#F4F8FC"), main1 = rgb("#A9D8F5"), main2 = rgb("#4F9BD6"), shade = rgb("#7F93A8"), rim = rgb("#6FE7FF") },
	},

	-- 구역 색조(클라 CartoonZoneTint - 카툰 프로필에서만 · 공통 규칙 위에 아주 옅게). 없으면 흰색(변화 없음). 전환 = tweenSeconds.
	zoneTint = {
		tweenSeconds = 1.5,
		hub = { 255, 252, 244 }, tier1 = { 250, 255, 246 }, tier2 = { 246, 238, 255 }, tier3 = { 240, 252, 255 },
		tier4 = { 255, 248, 236 }, tier5 = { 238, 240, 255 }, tier6 = { 244, 250, 255 },
	},

	-- 외곽선 풀(클라 OutlinePool). 슬롯 = Highlight 인스턴스 수(Enabled = false도 차지 - 255 하드 한도). 대상당 1개 · 거리 밖은 다른 대상에게 재사용 · 남으면 제거.
	outline = {
		color = rgb("#1E1B2E"), fillTransparency = 1, outlineTransparency = 0,
		maxActive = 80, -- 운영 상한(풀 크기). 255 - (강화 외곽선 ≤ 20명 + 보스 아레나 2 + 예비) 안
		tickSeconds = 0.2,
		spare = 4, -- 재사용 여유(이만큼은 지우지 않고 남겨 둔다 - 생성 순간 부하 줄이기)
		-- 우선순위(작을수록 먼저) · 거리(카메라 기준 stud - 밖은 후보 아님)
		categories = {
			aim = { priority = 0, distance = math.huge },
			boss = { priority = 1, distance = 400 },
			self = { priority = 2, distance = math.huge },
			party = { priority = 3, distance = 200 },
			interact = { priority = 4, distance = 120 }, -- 관문 · NPC · 둥지(CollectionService 태그 OutlineTarget)
			monster = { priority = 5, distance = 90 },
			player = { priority = 6, distance = 90 },
		},
		aimColor = { 255, 230, 90 }, -- 조준 대상(기존 AimHighlight와 같은 값 - 두 프로필 공통)
		aimHeavyColor = nil, -- AimTarget의 강공격 준비 색을 그대로 쓴다(AimTarget.HEAVY_OUTLINE)
		tag = "OutlineTarget",
	},

	-- VFX 예산(art-spec 7장 · style-bible 8장 - A2-6에서 소비). 거리 = 이 밖이면 남의 효과를 안 그린다.
	vfx = {
		hitParticles = 6, critParticles = 6, bossHitParticles = 6, skillParticles = 20, levelUpParticles = 16, enhanceParticles = 24,
		otherPlayerScale = 0.5, maxConcurrentPieces = 90, poolSize = 120,
		otherPlayerDistance = 120, weaponAuraDistance = 60,
	},

	-- 등급 표현(art-spec 5장 - 누적). 색 = 기존 ItemVisualData 우선(여기 없음). 태초 = 기존 자홍 대표색 + 흰 본체(통합안 - 결정).
	rarity = {
		order = { "normal", "rare", "epic", "legendary", "relic", "ancient", "primordial" },
		layers = {
			normal = {},
			rare = { "rim" },
			epic = { "rim", "gem" },
			legendary = { "rim", "gem", "wings", "glow" },
			relic = { "rim", "gem", "wings", "glow", "shards" },
			ancient = { "rim", "gem", "wings", "glow", "shards", "ring" },
			primordial = { "rim", "gem", "wings", "glow", "shards", "ring", "whiteAura", "whiteBody" },
		},
		shardCount = 6, auraDistance = 60,
	},

	-- 거리별 성능 정책(A1 ⑦ - 수치 한곳)
	perf = { smallPropShadowOff = 6, outlineMonsterDistance = 90, particleDistance = 120, renderFidelity = "Automatic", streamingModel = "Atomic" },
}
