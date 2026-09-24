-- 보스 아레나 맵(P3a C - 원형 · 4인 · 보스 6종 전용 테마). 그리기는 server/BossArenaMap.lua(서버 파트) · client/BossArenaMapView.client.lua(파편 연출).
--
-- 모양: 반경 radiusStuds의 원(모서리 없음 - S15 측정 "모서리 1stud 37/48 실패"의 기하 원인을 없앤다). 옛 정사각형 반폭 96(면적 36,864) →
-- 반경 120(면적 45,239 · +23%, 지름 240)으로 키웠다 - 최대 4인이 흩어져 서도 산개 원 · 돌진 경로가 서로 덜 겹친다(사용자 지시 "크고 웅장하게").
-- 한 슬롯(12개)의 기반(바닥 · 벽 고리 · 바깥 단)은 한 번 짓고 계속 쓰고, 보스전마다 그 보스의 테마로 색 · 재질을 바꾸고 장식 · 구조물을 짓는다(끝나면 치운다).
--
-- 카툰 방향(사용자 지시): 재질은 매끈한 SmoothPlastic 위주(빛 · 물은 Neon · 반투명만), 채도 있는 평면색, 장식 · 구조물 · 벽에 외곽선(Highlight - 아레나당
-- 모델 2개 = 기반 1 + 장식 1, 로블록스 동시 Highlight 한도 31 안: 12슬롯 × 2 = 24). 최종 에셋으로 갈아 끼울 때는 kind별 빌더(BossArenaMap) 한 곳만 바꾼다.
--
-- 색 규칙: 바닥은 보스와 **대비**되는 테마 색(보스가 바닥 위에서 잘 보이게 - 보스 색은 tier 색이라 테마 색과 다르다), 발광 무늬 · 장식의 빛은 **보스 머리색**
-- (boss = "head" / "body")으로 이어 준다. 색 값은 테마(맵 컨셉 PRD 20.50 [6])의 분위기 값이다 - 사용자 지시(분위기 · 색감)로 새 색을 쓴다(로그 결정).
--
-- 구조물(obstacle - 사용자 지시): 자연스러운 바위 · 얼음 · 기둥 잔해. 걸어서 못 지나가고(충돌) 보스 걸음도 비켜 간다(지면 폴더 - 계단 한 단보다 높다),
-- 보스 돌진이 부딪히면 그 자리에서 멈추고 구조물이 부서지며 헤롱이 길어진다(chargeStunBonusSeconds), 플레이어가 hitsToBreak번 때리면 부서진다(파편 연출).
-- 보스전을 전멸로 다시 시작하면 구조물도 처음대로 돌아온다. 자리 규칙: 중심(보스 스폰 · centerClearStuds) · 입장 방위(± 25°) · 킷과 떨어지고, 벽과의 틈 ≥ minWallGapStuds ·
-- 서로의 틈 ≥ minGapStuds - 틈이 캐릭터 폭(2)보다 훨씬 넓어 끼일 자리가 없다(P3a(가)가 6종 전부 잰다). 기믹 지형(얼음 기둥 · 모래 구덩이)은 구조물과 겹치는 자리에 서지 않는다(BossPatterns).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local RADIUS = 120

local geometry = {
	radiusStuds = RADIUS,
	wallSegments = 24, -- 24각형 고리(안쪽 반경 = radiusStuds). 변의 가운데가 원에서 최대 0.21stud 안쪽 - 캐릭터 반폭(1)보다 작다
	wallHeightStuds = 14,
	wallThicknessStuds = 4,
	floorThicknessStuds = 2, -- 바닥 윗면 = 1(옛 아레나 · 사냥터와 같은 관례)
	rimWidthStuds = 40, -- 벽 바깥의 테라스(장식이 서는 곳 - 걸어서는 못 간다: 벽이 막는다)
	rimDropStuds = 1.5, -- 테라스 윗면이 아레나 바닥보다 이만큼 낮다(층이 보이게)
	entryDistanceStuds = 90, -- 입장 자리 = 중심에서 +Z로 이만큼(옛 86 - 벽에서 10). 보스는 중심에 선다
	entryAngleDeg = 90, -- 입장 자리의 방위(각 = +X에서 +Z 쪽으로) - 구조물 · 킷은 이 방위 ± 25°에 두지 않는다
	centerClearStuds = 26, -- 보스 스폰 자리 둘레 - 구조물 금지
	slotSpacingExtraStuds = 100, -- 슬롯 사이 여유(기반 + 테라스 지름 밖으로)
	-- 진동파의 최대 반경(여기까지 퍼지면 사라진다) = 옛 정사각형 아레나 반폭 96 × (√2 + 0.05) ≈ 140.6 그대로 - 반경 120의 중심 파동이 벽까지 닿고,
	-- 파동 스킬의 구속 시간(BossSkillMath.boundSeconds)과 모형(BossSim)이 옛 값과 같다(아레나를 키우며 파동이 길어지지 않게).
	waveMaxRadiusStuds = 96 * (math.sqrt(2) + 0.05),
	-- 대상 원(낙석 · 낙빙 · 독침)의 중심을 벽 안쪽으로 누르는 여백. 옛 값 2는 벽에 붙어 선 대상의 첫 원을 1stud 안쪽(= 도망갈 쪽)으로 밀어 가장자리 회피를
	-- 깎았다(P3a C2 하네스 - 원 반경 120 · 벽 1stud: 여백 2 = 48칸 중 3칸 실패 · 1 = 1칸 · 0 = 0칸). 0이어도 원은 대상 발밑에 뜬다(캐릭터는 몸 반폭 1 때문에
	-- 벽에서 1stud보다 가까이 설 수 없다). 벽 너머로 흩어졌을 원은 벽 선 위로 눌린다(바깥 절반은 벽 · 테라스 위라 아무도 못 선다).
	circleTargetMarginStuds = 0,
}

-- 구조물 공통.
local obstacle = {
	hitsToBreak = 3,
	hitIntervalSeconds = 0.25, -- 한 사람의 연타 · 다중 타격 스킬이 한 틱에 3번을 다 채우지 않게(보물상자와 같은 결)
	chargeStunBonusSeconds = 2.0, -- 돌진이 구조물에 부딪히면 헤롱이 이만큼 길어진다(기회)
	chargeBodyHalfStuds = 3, -- 돌진 경로와 구조물의 충돌 여유(보스 몸통 반폭)
	-- 충돌 기둥의 높이 - 계단 한 단(2)보다 높고(보스 걸음이 비켜 간다) 보스 지면 탐지 창(발 + TerrainConfig.probeUpStuds 4)보다 낮아야 한다: 광선은 시작점이 든
	-- 파트를 못 맞혀서, 윗면이 발 + 4를 넘는 기둥은 탐지가 기둥 속에서 시작해 "지면 = 바닥"으로 보고 보스가 뚫고 지나간다(P3a 리뷰 2 - 옛 5).
	heightStuds = 3.8,
	minWallGapStuds = 20, -- 구조물 가장자리와 벽 사이 최소 틈(검증 (가))
	minGapStuds = 16, -- 구조물끼리 · 킷과의 최소 틈
	-- 뺑뺑이 방지(사용자 지시): 보스가 추격 중 한 구조물 곁(반경 + 몸통 + nearSlackStuds)에 머문 시간이 "그 구조물을 보스 걸음으로 smashAfterLaps바퀴 도는 시간"
	-- (2π × (반경 + 몸통 + nearSlackStuds) ÷ 보스 이동 속도 × 바퀴)을 넘으면 보스가 그 구조물을 부수고 다가간다 - 구조물 뒤에 숨어 무적이 되는 길이 없다.
	-- 곁을 떠나 있으면 같은 속도로 줄어든다(잠깐 스친 것은 쌓이지 않는다).
	smashAfterLaps = 5,
	nearSlackStuds = 3,
	-- 부서질 때 위에 서 있던 사람(사용자 지시): 파편과 함께 튕겨 난다(기존 넉백 연출 launch - 높이 · 거리) + 최대 체력 비율 피해(방어 무관 · 신규 보호 · 쉴드는 그대로 탄다).
	-- 피해 비율은 결정 필요(로그) - 잠정 10%(보스 기믹 실패 55%의 약 1/5 - "올라서 있으면 조금 아프다").
	topBreak = { maxHpFraction = 0.10, heightStuds = 5, distanceStuds = 10, label = "구조물 파편" },
}

-- 장식 kind(빌더가 아는 모양):
--   spike       테라스 위의 뾰족한 기둥(쐐기 두 장 - 얼음 가시 · 수정 · 첨탑)
--   column      원기둥 + 머리돌(신전 기둥 · 폐허 기둥)
--   obelisk     기울어진 사각 기둥 + 빛나는 조각(공허)
--   floorRing   바닥의 얇은 빛 고리(무늬 - 충돌 · 조준 없음)
--   floorDisc   바닥의 얇은 원판(물웅덩이 · 모래 무늬)
-- 구조물 kind: boulder(둥근 바위 둘) · block(기울어진 돌덩이 둘) · stump(부러진 기둥) · cluster(결정 세 개) · mesa(큰 바위판 - 낮고 넓다)
-- 자리: angles = 방위 목록(도) · ring = 반경 배율(radiusStuds 기준 - 1보다 크면 테라스). obstacles = 그룹 목록(그룹마다 kind · 크기 · 자리).
-- heightStuds(선택, 기본 obstacle.heightStuds): 큰 바위판은 3.5 - 계단 한 단(2)보다 높아 보스 걸음은 비켜 가지만 플레이어는 뛰어올라(점프 7.2) 위로 건너간다
-- (사용자 지시 "보스는 못 지나가도 플레이어는 지나갈 수 있는 경우"). 부서질 때 위에 서 있던 사람은 파편과 함께 튕겨 나고 피해를 받는다(obstacle.topBreak).

local maps = {
	-- 공허의 제단(구간 수호자 - 보라). 어두운 청회색 바닥 · 보라 빛 룬 고리 · 떠 있는 오벨리스크.
	section_guardian = {
		name = "공허의 제단",
		floor = { color = Color3.fromRGB(40, 38, 56), material = Enum.Material.SmoothPlastic },
		wall = { color = Color3.fromRGB(62, 54, 84), material = Enum.Material.SmoothPlastic },
		rim = { color = Color3.fromRGB(24, 22, 32), material = Enum.Material.SmoothPlastic },
		decor = {
			{ kind = "obelisk", ring = 1.14, angles = { 0, 45, 135, 180, 225, 270, 315 }, size = Vector3.new(6, 30, 6), tiltDeg = 8, color = Color3.fromRGB(48, 40, 70), glow = "head" },
			{ kind = "floorRing", radius = 34, width = 1.2, glow = "head", transparency = 0.35 },
			{ kind = "floorRing", radius = 72, width = 0.8, glow = "head", transparency = 0.55 },
		},
		obstacles = {
			{ kind = "block", color = Color3.fromRGB(74, 64, 100), ring = 0.52, angles = { 20, 160, 215, 325 }, radius = 4.5 },
			{ kind = "mesa", color = Color3.fromRGB(58, 50, 80), ring = 0.32, angles = { 270 }, radius = 9, heightStuds = 3.5 }, -- 큰 바위판: 플레이어는 뛰어올라 건너가고 보스는 돌아간다
		},
	},
	-- 빙하 동굴(서리 거인). 밝은 얼음 바닥 · 얼음 가시 테라스 · 얼음 바위.
	frost_giant = {
		name = "빙하 동굴",
		floor = { color = Color3.fromRGB(186, 218, 234), material = Enum.Material.SmoothPlastic },
		wall = { color = Color3.fromRGB(132, 184, 212), material = Enum.Material.SmoothPlastic },
		rim = { color = Color3.fromRGB(92, 138, 168), material = Enum.Material.SmoothPlastic },
		decor = {
			{ kind = "spike", ring = 1.1, angles = { 0, 30, 60, 120, 150, 180, 210, 240, 270, 300, 330 }, size = Vector3.new(7, 26, 7), color = Color3.fromRGB(214, 238, 250), transparency = 0.1 },
			{ kind = "spike", ring = 1.24, angles = { 15, 75, 165, 255, 345 }, size = Vector3.new(9, 38, 9), color = Color3.fromRGB(170, 214, 238), transparency = 0.1 },
			{ kind = "floorRing", radius = 58, width = 0.8, glow = "head", transparency = 0.6 },
		},
		obstacles = {
			{ kind = "boulder", color = Color3.fromRGB(168, 210, 232), ring = 0.5, angles = { 25, 150, 210, 330 }, radius = 4.5, transparency = 0.1 },
			{ kind = "mesa", color = Color3.fromRGB(200, 230, 244), ring = 0.32, angles = { 270 }, radius = 9, heightStuds = 3.5, transparency = 0.05 }, -- 큰 바위판: 플레이어는 뛰어올라 건너가고 보스는 돌아간다
		},
	},
	-- 수몰 사원(심해 군주). 짙은 청록 돌바닥 · 물웅덩이 · 신전 기둥 고리. 돌단(킷)은 BossData가 짓는다.
	abyssal_lord = {
		name = "수몰 사원",
		floor = { color = Color3.fromRGB(46, 78, 86), material = Enum.Material.SmoothPlastic },
		wall = { color = Color3.fromRGB(74, 98, 94), material = Enum.Material.SmoothPlastic },
		rim = { color = Color3.fromRGB(30, 52, 62), material = Enum.Material.SmoothPlastic },
		decor = {
			{ kind = "column", ring = 1.12, angles = { 0, 30, 60, 120, 150, 180, 210, 240, 270, 300, 330 }, size = Vector3.new(7, 28, 7), color = Color3.fromRGB(156, 166, 154) },
			-- 돌단(킷)은 반경 65의 방위 0 · 45 · … · 315 여덟 곳 - 물웅덩이 · 구조물은 단 사이(방위 22.5 + 45k)에 둔다. 가운데 큰 웅덩이 = 가라앉은 제단.
			{ kind = "floorDisc", spots = { { 0, 0 } }, radius = 16, color = Color3.fromRGB(48, 132, 168), transparency = 0.45 },
			{ kind = "floorDisc", spots = { { 22.5, 0.3 }, { 112.5, 0.3 }, { 202.5, 0.3 }, { 292.5, 0.3 } }, radius = 8, color = Color3.fromRGB(48, 132, 168), transparency = 0.5 },
		},
		obstacles = {
			{ kind = "stump", color = Color3.fromRGB(138, 146, 134), ring = 0.78, angles = { 22.5, 157.5, 202.5, 337.5 }, radius = 4 },
		}, -- 큰 바위판 없음 - 돌단(킷)이 그 역할(올라서는 지형)을 한다
	},
	-- 수정 동굴(수정 여왕 - 붉은 분홍). 어두운 남색 바닥 · 청록 · 백색 결정(PRD 20.50 [6] "골렘 구역과 겹치지 않게 청록 · 백색").
	crystal_queen = {
		name = "수정 동굴",
		floor = { color = Color3.fromRGB(34, 32, 50), material = Enum.Material.SmoothPlastic },
		wall = { color = Color3.fromRGB(54, 48, 74), material = Enum.Material.SmoothPlastic },
		rim = { color = Color3.fromRGB(22, 20, 34), material = Enum.Material.SmoothPlastic },
		decor = {
			{ kind = "spike", ring = 1.1, angles = { 10, 50, 100, 140, 190, 230, 280, 320 }, size = Vector3.new(6, 24, 6), color = Color3.fromRGB(140, 228, 240), transparency = 0.15, neon = true },
			{ kind = "spike", ring = 1.22, angles = { 30, 120, 210, 300 }, size = Vector3.new(8, 34, 8), color = Color3.fromRGB(226, 246, 250), transparency = 0.15 },
			{ kind = "floorRing", radius = 46, width = 1, glow = "head", transparency = 0.5 },
		},
		obstacles = {
			{ kind = "cluster", color = Color3.fromRGB(122, 214, 228), ring = 0.55, angles = { 20, 145, 215, 320 }, radius = 4.5, transparency = 0.15 },
			{ kind = "mesa", color = Color3.fromRGB(64, 58, 92), ring = 0.32, angles = { 270 }, radius = 9, heightStuds = 3.5 }, -- 큰 바위판: 플레이어는 뛰어올라 건너가고 보스는 돌아간다
		},
	},
	-- 모래 유적(전갈 여왕). 모래 바닥 · 사암 벽 · 폐허 기둥. 유사 웅덩이 · 안쪽 폐허 기둥(킷)은 BossData가 짓는다.
	scorpion_queen = {
		name = "모래 유적",
		floor = { color = Color3.fromRGB(222, 198, 142), material = Enum.Material.SmoothPlastic },
		wall = { color = Color3.fromRGB(196, 162, 108), material = Enum.Material.SmoothPlastic },
		rim = { color = Color3.fromRGB(170, 136, 88), material = Enum.Material.SmoothPlastic },
		decor = {
			{ kind = "column", ring = 1.14, angles = { 20, 70, 110, 160, 200, 250, 290, 340 }, size = Vector3.new(8, 22, 8), color = Color3.fromRGB(206, 172, 118), broken = true },
			{ kind = "floorDisc", spots = { { 45, 0.35 }, { 135, 0.62 }, { 250, 0.4 }, { 300, 0.66 } }, radius = 12, color = Color3.fromRGB(208, 180, 124), transparency = 0 },
		},
		obstacles = {
			{ kind = "block", color = Color3.fromRGB(204, 170, 116), ring = 0.55, angles = { 40, 140, 225, 315 }, radius = 4.5 },
			{ kind = "mesa", color = Color3.fromRGB(214, 182, 128), ring = 0.32, angles = { 270 }, radius = 9, heightStuds = 3.5 }, -- 큰 바위판: 플레이어는 뛰어올라 건너가고 보스는 돌아간다
		},
	},
	-- 폭풍 첨탑(폭풍 군주). 청회색 판석 · 번개빛 첨탑 끝 · 현무암 바위. 피뢰침(킷)은 BossData가 짓는다.
	storm_lord = {
		name = "폭풍 첨탑",
		floor = { color = Color3.fromRGB(62, 68, 84), material = Enum.Material.SmoothPlastic },
		wall = { color = Color3.fromRGB(86, 92, 112), material = Enum.Material.SmoothPlastic },
		rim = { color = Color3.fromRGB(40, 44, 56), material = Enum.Material.SmoothPlastic },
		decor = {
			{ kind = "spike", ring = 1.12, angles = { 0, 45, 90, 135, 180, 225, 270, 315 }, size = Vector3.new(6, 36, 6), color = Color3.fromRGB(98, 104, 126), tipColor = UIColors.xp },
			{ kind = "floorRing", radius = 30, width = 1, color = UIColors.xp, transparency = 0.55 },
		},
		obstacles = {
			{ kind = "boulder", color = Color3.fromRGB(78, 82, 98), ring = 0.52, angles = { 35, 145, 215, 325 }, radius = 4.5 },
			{ kind = "mesa", color = Color3.fromRGB(70, 74, 90), ring = 0.32, angles = { 270 }, radius = 9, heightStuds = 3.5 }, -- 큰 바위판: 플레이어는 뛰어올라 건너가고 보스는 돌아간다
		},
	},
}

-- 테마가 없는 보스(앞으로 추가될 보스 · 견습 보스)의 기본 맵 - 보스 색에서 만든다(계획서 docs/phase/P3a-bossmap-plan.md의 "재사용 규칙").
local default = {
	name = "시련의 원형장",
	floor = { color = Color3.fromRGB(44, 40, 44), material = Enum.Material.SmoothPlastic },
	wall = { color = Color3.fromRGB(70, 62, 66), material = Enum.Material.SmoothPlastic },
	rim = { color = Color3.fromRGB(28, 24, 28), material = Enum.Material.SmoothPlastic },
	decor = {
		{ kind = "column", ring = 1.12, angles = { 0, 45, 135, 180, 225, 315 }, size = Vector3.new(7, 24, 7), color = Color3.fromRGB(96, 88, 92) },
		{ kind = "floorRing", radius = 40, width = 1, glow = "head", transparency = 0.5 },
	},
	obstacles = {
		{ kind = "block", color = Color3.fromRGB(96, 88, 92), ring = 0.52, angles = { 30, 150, 210, 330 }, radius = 4.5 },
		{ kind = "mesa", color = Color3.fromRGB(86, 78, 82), ring = 0.32, angles = { 270 }, radius = 9, heightStuds = 3.5 }, -- 큰 바위판: 플레이어는 뛰어올라 건너가고 보스는 돌아간다
	},
}

return {
	geometry = geometry,
	obstacle = obstacle,
	maps = maps,
	default = default,
	outlineColor = UIColors.metalOuter, -- 카툰 외곽선(기존 색)
}
