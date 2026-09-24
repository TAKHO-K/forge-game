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

-- P3c B4: 반경 120 → 140(면적 +36%). 확인한 것: ① 진동파 최대 반경 140.6 ≥ 140 - 중심 파동이 여전히 벽까지 닿는다 ② 가장자리 48지점 회피 0/48(P3c(가) - 원이 커질수록
-- 벽이 곧아져 유리하다) ③ 심해 군주 범람 - 발판 8곳(반경 65) 한 고리로는 원 안 최악 63.6stud > 회피 57이라 안쪽 3 + 바깥 8 = 11곳(최악 49.8 - BossData abyssalKitParts ·
-- 결정 필요 4) ④ 전갈 여왕 웅덩이 · 폭풍 군주 피뢰침 · 서리 거인 기둥 · 수정 여왕 분열은 반경에서 계산하거나 반경과 무관 ⑤ 성능 = 보고서 ④(파트 수 · P2.5a 기준선 대비).
local RADIUS = 140

local geometry = {
	radiusStuds = RADIUS,
	wallSegments = 24, -- 24각형 고리(안쪽 반경 = radiusStuds). 변의 가운데가 원에서 최대 0.21stud 안쪽 - 캐릭터 반폭(1)보다 작다
	wallHeightStuds = 14,
	wallThicknessStuds = 4,
	floorThicknessStuds = 2, -- 바닥 윗면 = 1(옛 아레나 · 사냥터와 같은 관례)
	rimWidthStuds = 40, -- 벽 바깥의 테라스(장식이 서는 곳 - 걸어서는 못 간다: 벽이 막는다)
	rimDropStuds = 1.5, -- 테라스 윗면이 아레나 바닥보다 이만큼 낮다(층이 보이게)
	entryDistanceStuds = 90, -- 입장 자리 = 중심에서 +Z로 이만큼(옛 86). 반경 140에서는 벽에서 50 - 보스 쪽으로 걸어 들어가는 거리는 그대로 둔다. 보스는 중심에 선다
	entryAngleDeg = 90, -- 입장 자리의 방위(각 = +X에서 +Z 쪽으로) - 구조물 · 킷은 이 방위 ± 25°에 두지 않는다
	centerClearStuds = 26, -- 보스 스폰 자리 둘레 - 구조물 금지
	slotSpacingExtraStuds = 100, -- 슬롯 사이 여유(기반 + 테라스 지름 밖으로)
	-- 진동파의 최대 반경(여기까지 퍼지면 사라진다) = 옛 정사각형 아레나 반폭 96 × (√2 + 0.05) ≈ 140.6 그대로 - 반경 140(P3c)의 중심 파동도 벽까지 닿고,
	-- 파동 스킬의 구속 시간(BossSkillMath.boundSeconds)과 모형(BossSim)이 옛 값과 같다(아레나를 키우며 파동이 길어지지 않게).
	waveMaxRadiusStuds = 96 * (math.sqrt(2) + 0.05),
	-- 대상 원(낙석 · 낙빙 · 독침)의 중심을 벽 안쪽으로 누르는 여백. 옛 값 2는 벽에 붙어 선 대상의 첫 원을 1stud 안쪽(= 도망갈 쪽)으로 밀어 가장자리 회피를
	-- 깎았다(P3a C2 하네스 - 원 반경 120 · 벽 1stud: 여백 2 = 48칸 중 3칸 실패 · 1 = 1칸 · 0 = 0칸). 0이어도 원은 대상 발밑에 뜬다(캐릭터는 몸 반폭 1 때문에
	-- 벽에서 1stud보다 가까이 설 수 없다). 벽 너머로 흩어졌을 원은 벽 선 위로 눌린다(바깥 절반은 벽 · 테라스 위라 아무도 못 선다).
	circleTargetMarginStuds = 0,
}

-- 구조물 공통.
-- P3c B2 · C8(사용자 확정): 모든 구조물(큰 블록 · 작은 구조물 · 작은 지형지물)의 파괴 규칙을 하나로 - 플레이어 공격 hitsToBreak(5)번, 보스 돌진은 한 번에 부서진다.
-- 부서지기 직전(남은 타격 crackAtHitsLeft = 1)에는 금이 간 표시가 붙는다. 옛 "뺑뺑이 5바퀴면 보스가 부순다"는 없앴다(C8 - 돌진 대상이 가장 가까운 사람이라
-- 구조물 뒤에 숨은 사람에게 돌진이 오고, 구조물이 부서지며 보스가 기절한다 - 숨는 것이 곧 유도다).
local obstacle = {
	hitsToBreak = 5,
	crackAtHitsLeft = 1,
	hitIntervalSeconds = 0.25, -- 한 사람의 연타 · 다중 타격 스킬이 한 틱에 여러 번을 다 채우지 않게(보물상자와 같은 결)
	-- 돌진이 구조물에 부딪히면 헤롱이 이만큼 길어진다(기회) - 돌진 헤롱 4 + 2 = 기절 6초(C8 승인).
	chargeStunBonusSeconds = 2.0,
	chargeBodyHalfStuds = 3, -- 돌진 경로와 구조물의 충돌 여유(보스 몸통 반폭)
	-- 충돌 기둥의 높이 - 계단 한 단(2)보다 높고(보스 걸음이 비켜 간다) 보스 지면 탐지 창(발 + TerrainConfig.probeUpStuds 4)보다 낮아야 한다: 광선은 시작점이 든
	-- 파트를 못 맞혀서, 윗면이 발 + 4를 넘는 기둥은 탐지가 기둥 속에서 시작해 "지면 = 바닥"으로 보고 보스가 뚫고 지나간다(P3a 리뷰 2 - 옛 5).
	heightStuds = 3.8,
	-- B2 올라갈 수 있는 큰 블록의 윗면 높이 - 점프(7.2)로 오르고, 계단 한 단(2)보다 높아 보스는 돌아간다. 윗면 + 넉백 상한 7.5 = 11 < 벽 14(맵 이탈 방지).
	climbHeightStuds = 3.5,
	-- 부서질 때 위에 서 있던 사람(사용자 지시): 파편과 함께 튕겨 난다(기존 넉백 연출 launch - 높이 · 거리) + 최대 체력 비율 피해(방어 무관 · 신규 보호 · 쉴드는 그대로 탄다).
	-- 10%(P3a 결정 필요 2 → P3c B2 사용자 지시 "위에 있다가 부서지면 피해 10%").
	topBreak = { maxHpFraction = 0.10, heightStuds = 5, distanceStuds = 10, label = "구조물 파편" },
}

-- P3c B1 무작위 배치(보스 등장마다 새 시드 - 로그 "[forge-game] 보스맵 배치 시드"). 생성 · 검사 = shared/ArenaLayout(순수 함수 - 서버와 검증이 같은 함수).
--   자리: 중심에서 centerClearStuds + 크기 ~ 반경 − wallGapStuds − 크기 사이, 입장 방위 ± entryClearDeg 밖, 킷(발판 · 웅덩이 · 피뢰침)과 kitGapStuds, 서로 minGapStuds.
--     wallGapStuds 20 = 벽에서 구조물 가장자리까지 - 큰 블록(윗면 3.5)에 올라 뛰어도 벽(14)을 못 넘고, 벽과 구조물 사이에 갇힐 틈이 없다.
--     minGapStuds 10 = 보스 몸통(반폭 3.6)도 사이로 지나간다(2 × 3.6 < 10) - 캐릭터 폭 2는 물론이다.
--   연결: 칸 connectCellStuds 격자로 입장 자리에서 퍼져 나가 원 안의 빈 칸이 전부 이어지는가(몸 반폭 1 여유) - 아니면 다시 뽑는다.
--   돌진 보장: 중심에서 무작위 방향으로 돌진할 때 구조물을 지나는 방위의 몫(보스 몸통 반폭 포함) ≥ chargeCoverageMin - 아니면 다시 뽑는다.
--   재시도: 한 배치에 retries번까지 - 다 실패하면 마지막 후보 중 조건을 가장 많이 지킨 것(검증은 100시드에서 실패 0을 본다).
--   둔덕(B4 바닥 높낮이): 층 높이 stepStuds의 원판을 겹쳐 쌓은 완만한 언덕 - 층당 0.5는 걸어서 오른다. 높이 상한 maxHeightStuds 1.5(= 3층).
--     판정의 높이차 상한 8 · 계단 한 단 2 · 공중 판정(진동파)에 모두 여유가 크다 - 높이별 재검사 = P3c(나B4). 둔덕 위의 예고는 클라가 그 자리 가장 높은 지면 위로 띄운다.
local layout = {
	centerClearStuds = 26,
	entryClearDeg = 25,
	wallGapStuds = 20,
	minGapStuds = 10,
	kitGapStuds = 10,
	connectCellStuds = 2,
	chargeCoverageMin = 0.30,
	retries = 60,
	tries = 200, -- 한 구조물의 자리를 찾는 시도
	mounds = { count = { 2, 3 }, radiusStuds = { 12, 20 }, stepStuds = 0.5, maxHeightStuds = 1.5, gapStuds = 4 },
}

-- P3c B3 작은 지형지물의 모양(kind마다) - 충돌 원(colliders: 한가운데 기준 x · z · 반경 · 높이 · tall)과 자리 잡기용 발자국 반경(footprint).
--   tall = 충돌 기둥이 보이는 모양만큼 높다(석상 · 얼음 기둥 - 위에 올라설 수 없게). 이런 기둥은 지면 폴더 밖에 둔다(지면 탐지 · 드랍 스냅 · 낙하점 높이가 기둥 꼭대기를
--   바닥으로 보지 않게). 보스는 추격 중에 가는 기둥을 비켜 가지 않는다(보스 몸은 충돌이 없다 - 돌진은 부딪혀 부순다).
--   "사이로 지나다니는" 모양: 기둥 사이 틈 ≥ 3stud(캐릭터 폭 2 + 여유) - 얼음 기둥 셋 · 수정 무리 · 룬석 고리 · 무너진 아치 · 유적 문.
local featureShapes = {
	icePillars = { footprint = 5, colliders = { { 3.5, 0, 1.2, 7, true }, { -1.75, 3.03, 1.2, 5, true }, { -1.75, -3.03, 1.2, 6, true } } },
	snowMound = { footprint = 3, colliders = { { 0, 0, 3, 1.5 } } },
	statue = { footprint = 2.2, colliders = { { 0, 0, 2, 8, true } } },
	brokenArch = { footprint = 5, colliders = { { 3.5, 0, 1.2, 8, true }, { -3.5, 0, 1.2, 8, true } }, lintelStuds = 7 },
	crystalCluster = { footprint = 4.5, colliders = { { 3, 0, 1, 6, true }, { -1.5, 2.6, 1, 4.5, true }, { -1.5, -2.6, 1, 5, true } } },
	ruinGate = { footprint = 5, colliders = { { 3.5, 0, 1.3, 8, true }, { -3.5, 0, 1.3, 8, true } }, lintelStuds = 7 },
	ruinFragment = { footprint = 2.5, colliders = { { 0, 0, 2.5, 3 } } },
	cactus = { footprint = 2, colliders = { { 0, 0, 1.2, 6, true } } },
	rodWreck = { footprint = 4, colliders = { { 0, 0, 0.8, 7, true }, { 2.5, 0, 1.5, 1.5 } } },
	rubble = { footprint = 3.5, colliders = { { 1.5, 0, 1.2, 1.2 }, { -1.2, 1.4, 1, 1 }, { -1, -1.5, 1.1, 1.1 } } },
	runeStones = { footprint = 5, colliders = { { 4, 0, 1, 4.5, true }, { 0, 4, 1, 4.5, true }, { -4, 0, 1, 4.5, true }, { 0, -4, 1, 4.5, true } } },
}

-- P3c A5 맵 이탈 방지(모든 패턴 공통 불변식): 넉백 · 돌진 · 밀어내기가 겹쳐도 플레이어는 맵 밖으로 나가거나 떨어지지 않는다. 세 겹이다(shared/ArenaContainment).
--   ① 넉백 상한: 높이 ≤ maxLaunchHeightStuds · 수평 거리 ≤ maxLaunchDistanceStuds. 높이 7.5 = 판정 높이차 상한(8)보다 낮고(보스가 뜬 대상을 놓치지 않는다),
--      가장 높은 발판(큰 블록 윗면 obstacle.climbHeightStuds)에서 떠도 벽 윗면(wallHeightStuds 14)에 못 닿는다(3.5 + 7.5 = 11 < 14).
--   ② 경계 안쪽 고정: 넉백 착지점이 벽에서 innerMarginStuds 안쪽을 넘지 않게 수평 거리를 줄인다(클라 BossStormView가 이 함수로 자른다 - 서버는 구역을 실어 보낸다).
--   ③ 복귀: 서버가 checkIntervalSeconds마다 멤버 위치를 보고, 원 밖(outsideToleranceStuds 넘게) · 바닥 아래(fallDepthStuds)면 옮긴다(server/BossArenaContainment).
--      P3d B(사용자 결정 - 옛 "피해 없이 벽에서 rescueInsetStuds 안쪽"을 대체): **본인의 보스방 스폰 자리**(입장 자리 - BossArenaMap.entryPosition, 멤버 순번)로 옮긴다.
--      날려 보낸 기술의 피해는 그 판정에서 이미 받았다(복귀가 되돌리지 않는다) · 체력 비율 · 기믹 누적(%피해 발동 누적 · 반사 횟수 · 단 기록 · 잡힘)은 그대로다(순간이동만 한다).
--      복귀 직후 returnProtectSeconds 동안 보호: 받는 피해 0배 + 넉백(launch)을 안 받는다 - 스폰 자리에 떨어지는 다음 판정이 곧바로 다시 날려 보내는 연쇄 이탈을 막는다.
--      0.75 = 지시 범위 0.5 ~ 1초의 가운데(결정 필요 - 로그). 스폰 자리가 구조물에 덮였으면(재생성은 입장 자리를 비운다 - 안전망) 옛 안전 지점(rescueInsetStuds)으로 간다.
--      ①②가 지키면 ③은 한 번도 안 돈다 - 로그가 0이어야 정상이다.
local containment = {
	maxLaunchHeightStuds = 7.5,
	maxLaunchDistanceStuds = 12,
	innerMarginStuds = 3,
	outsideToleranceStuds = 2,
	fallDepthStuds = 6,
	rescueInsetStuds = 8,
	returnProtectSeconds = 0.75,
	checkIntervalSeconds = 0.25,
	-- 이탈 시뮬레이션(검증 P3c(가)): 무작위 패턴 조합 trials회 - 한 조합 = 사건 1 ~ maxEvents개(넉백 · 회오리 · 구조물 파편 · 모래 무덤 밀기 · 대시 · 걷기).
	sim = { trials = 1000, maxEvents = 6, seed = 20260924 },
}

-- 장식 kind(빌더가 아는 모양):
--   spike       테라스 위의 뾰족한 기둥(쐐기 두 장 - 얼음 가시 · 수정 · 첨탑)
--   column      원기둥 + 머리돌(신전 기둥 · 폐허 기둥)
--   obelisk     기울어진 사각 기둥 + 빛나는 조각(공허)
--   floorRing   바닥의 얇은 빛 고리(무늬 - 충돌 · 조준 없음)
--   floorDisc   바닥의 얇은 원판(물웅덩이 · 모래 무늬)
-- 구조물(P3c B - 보스 등장마다 무작위 자리 · 크기, shared/ArenaLayout): layout = 그룹 목록 { kind, group, count = { 최소, 최대 }, radius = { 최소, 최대 }(big · small), color, transparency }.
--   group "big"     올라갈 수 있는 큰 블록(B2) - 윗면 obstacle.climbHeightStuds. kind: rockpile(돌무더기 - 둥근 돌이 뭉친 모양) · dolmen(고인돌 - 받침돌 위의 넓은 판)
--   group "small"   작은 구조물(P3a) - 높이 obstacle.heightStuds. kind: boulder · block · stump · cluster
--   group "feature" 작은 지형지물(B3) - 모양은 featureShapes[kind](충돌 원 · 높이). 맵 분위기에 맞는 것만 쓴다.
-- 부서지는 규칙은 셋 다 같다(obstacle.hitsToBreak · 돌진 한 번). 보이는 모양 ⊂ 충돌 원(맞았을 때 크기가 줄지 않는다 - P3a).

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
		layout = {
			{ kind = "rockpile", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(58, 50, 80) },
			{ kind = "dolmen", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(74, 64, 100) },
			{ kind = "block", group = "small", count = { 3, 4 }, radius = { 3.5, 4.5 }, color = Color3.fromRGB(74, 64, 100) },
			{ kind = "runeStones", group = "feature", count = { 2, 3 }, color = Color3.fromRGB(62, 54, 84) }, -- 룬석 고리(사이로 지나간다)
			{ kind = "rubble", group = "feature", count = { 1, 2 }, color = Color3.fromRGB(58, 50, 80) },
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
		layout = {
			{ kind = "rockpile", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(168, 210, 232), transparency = 0.05 }, -- 얼음 바위 더미
			{ kind = "dolmen", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(200, 230, 244), transparency = 0.05 }, -- 얼음판
			{ kind = "boulder", group = "small", count = { 3, 4 }, radius = { 3.5, 4.5 }, color = Color3.fromRGB(168, 210, 232), transparency = 0.1 },
			{ kind = "icePillars", group = "feature", count = { 2, 3 }, color = Color3.fromRGB(214, 238, 250), transparency = 0.1 }, -- 얼음 기둥 셋(사이로 지나간다)
			{ kind = "snowMound", group = "feature", count = { 2, 3 }, color = Color3.fromRGB(236, 246, 252) }, -- 눈더미
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
			-- 돌단(킷, P3c)은 안쪽 반경 40의 방위 45 · 165 · 285 세 곳 + 바깥 반경 105의 방위 22.5 + 45k 여덟 곳 - 물웅덩이는 안쪽 단 사이(방위 105 · 225 · 345)에 둔다. 가운데 큰 웅덩이 = 가라앉은 제단.
			{ kind = "floorDisc", spots = { { 0, 0 } }, radius = 16, color = Color3.fromRGB(48, 132, 168), transparency = 0.45 },
			{ kind = "floorDisc", spots = { { 105, 0.3 }, { 225, 0.3 }, { 345, 0.3 } }, radius = 8, color = Color3.fromRGB(48, 132, 168), transparency = 0.5 },
		},
		-- 돌단(킷) 11곳이 올라서는 지형이라 큰 블록은 하나(무너진 제단석)만 둔다.
		layout = {
			{ kind = "dolmen", group = "big", count = { 1, 1 }, radius = { 8, 9 }, color = Color3.fromRGB(122, 132, 120) },
			{ kind = "stump", group = "small", count = { 2, 3 }, radius = { 3.5, 4 }, color = Color3.fromRGB(138, 146, 134) },
			{ kind = "brokenArch", group = "feature", count = { 1, 2 }, color = Color3.fromRGB(156, 166, 154) }, -- 무너진 아치(사이로 지나간다)
			{ kind = "statue", group = "feature", count = { 1, 2 }, color = Color3.fromRGB(122, 140, 128) }, -- 석상
		},
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
		layout = {
			{ kind = "rockpile", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(64, 58, 92) },
			{ kind = "dolmen", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(54, 48, 74) },
			{ kind = "cluster", group = "small", count = { 3, 4 }, radius = { 3.5, 4.5 }, color = Color3.fromRGB(122, 214, 228), transparency = 0.15 },
			{ kind = "crystalCluster", group = "feature", count = { 2, 3 }, color = Color3.fromRGB(140, 228, 240), transparency = 0.15 }, -- 수정 군집(사이로 지나간다)
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
		layout = {
			{ kind = "rockpile", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(214, 182, 128) },
			{ kind = "dolmen", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(196, 162, 108) },
			{ kind = "block", group = "small", count = { 2, 3 }, radius = { 3.5, 4.5 }, color = Color3.fromRGB(204, 170, 116) },
			{ kind = "ruinGate", group = "feature", count = { 1, 2 }, color = Color3.fromRGB(206, 172, 118) }, -- 유적 문(사이로 지나간다)
			{ kind = "ruinFragment", group = "feature", count = { 1, 2 }, color = Color3.fromRGB(196, 162, 108) }, -- 유적 조각
			{ kind = "cactus", group = "feature", count = { 2, 3 }, color = Color3.fromRGB(96, 140, 72) }, -- 선인장
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
		layout = {
			{ kind = "rockpile", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(70, 74, 90) },
			{ kind = "dolmen", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(86, 92, 112) },
			{ kind = "boulder", group = "small", count = { 3, 4 }, radius = { 3.5, 4.5 }, color = Color3.fromRGB(78, 82, 98) },
			{ kind = "rodWreck", group = "feature", count = { 2, 3 }, color = Color3.fromRGB(98, 104, 126) }, -- 쓰러진 피뢰침 · 잔해
			{ kind = "rubble", group = "feature", count = { 1, 2 }, color = Color3.fromRGB(78, 82, 98) },
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
	layout = {
		{ kind = "rockpile", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(86, 78, 82) },
		{ kind = "dolmen", group = "big", count = { 1, 1 }, radius = { 8, 10 }, color = Color3.fromRGB(96, 88, 92) },
		{ kind = "block", group = "small", count = { 3, 4 }, radius = { 3.5, 4.5 }, color = Color3.fromRGB(96, 88, 92) },
		{ kind = "rubble", group = "feature", count = { 2, 3 }, color = Color3.fromRGB(86, 78, 82) },
	},
}

return {
	geometry = geometry,
	obstacle = obstacle,
	containment = containment,
	layout = layout,
	featureShapes = featureShapes,
	maps = maps,
	default = default,
	outlineColor = UIColors.metalOuter, -- 카툰 외곽선(기존 색)
}
