-- M1 맵 확장 그레이박스(사용자 지시 - 큰 그림 먼저, 세부 · 카툰은 나중). 수치의 단일 출처 = 이 파일.
-- 좌표: 원점 = 허브(큰 나무) 중심 · 지면 윗면 y = floorTopY. 방위 a(도) = 방향 (cos a, 0, sin a) - -90 = -Z(스폰 때 카메라가 보는 쪽).
-- 구역 안의 자리는 "구역 좌표"(r = 원점에서 바깥쪽 거리, lat = 그 방위에 수직인 옆 거리 - 오른쪽 +)로 적는다(shared/WorldMapLayout이 월드로 바꾼다).
-- 이동 기준 = docs/design/movement-metrics.md v2(공중 점프 2 · 발 최고 19.44 · 옵션 21.38 · 못 오르는 벽 ≥ 23 · 못 건너는 간격 ≥ 46).
-- 걷기 16 기준 거리: 허브 끝 → 구역 입구 480 ~ 640(30 ~ 40초) · 입구 → 보스 관문 1,440 ~ 2,400(90 ~ 150초) - 검증 M1(가)가 경로 길이로 잰다.

local FLOOR_TOP_Y = 1

-- 그레이박스 색(회색 단계 + 구역 구분용 옅은 바닥 색만 - 카툰 · 장식 금지, 스타일 잠금 전).
local GREY = {
	ground = { 150, 150, 150 },
	road = { 175, 170, 160 },
	block = { 128, 128, 132 },
	blockDark = { 96, 96, 100 },
	blockLight = { 190, 190, 194 },
	safe = { 205, 215, 210 },
	marker = { 240, 200, 70 }, -- 둥지 · 이스터에그 자리 표시(기능 없음 - 자리만)
	barrier = { 120, 190, 255 },
}

-- 구역 공통 배치(구역 좌표). 구역 영역 = 원(중심 r = regionCenterR · 반경 regionRadius) - ZoneBounds · 결계 · 몬스터 리쉬 상한이 같은 원을 쓴다.
-- 60° 꽃잎 여섯 장: 이웃 구역 원은 경계선에서 맞닿는다(1700 × sin 30° = 850).
local LAYOUT = {
	regionCenterR = 1700,
	regionRadius = 850,
	camp = { r = 900, lat = 0, radius = 40 }, -- 입구 캠프(안전 · 포탈) - 구역 원 안 끝(원 안쪽 경계 r 850)
	-- 사냥 지대 3곳(평평 - 전투 가독성). 슬롯 = 3 × 3 격자(WorldConfig.zoneMonsterGrid - 64 간격 · 9마리) · 반경 = 격자 모서리 90 + 여유.
	grounds = {
		{ r = 1250, lat = -250, radius = 120 },
		{ r = 1650, lat = 300, radius = 120 },
		{ r = 2050, lat = -200, radius = 120 },
	},
	gate = { r = 2400, lat = 0, radius = 18 }, -- 보스 관문(밟으면 입장) · 토벌 관문 자리(BR2 - 표시만)는 옆 raidLat
	raidLat = 90,
	roadWidth = 16,
	-- 길 = 허브 끝 → 입구(결계 문) → 캠프 → 사냥 지대 1 · 2 · 3 → 관문. 길 안내(Wayfinder)가 같은 점을 따라간다.
	barrierGateR = 850, -- 결계 문(길이 구역 원을 지나는 자리)
}

return {
	floorTopY = FLOOR_TOP_Y,
	floorThickness = 2,
	worldRadiusStuds = 3000,
	-- 바닥 = 정사각 타일(스트리밍 단위 - 큰 판 하나는 멀리서 통째로 빠질 수 있다). 세계 원 밖 타일은 만들지 않는다.
	floorTileStuds = 500,
	-- 세계 끝: 보이지 않는 벽(충돌 · 높이 edgeWallHeight - 나무 꼭대기에서 뛰어도 못 넘는다) + 보이는 낮은 능선.
	edge = { radius = 2960, wallHeight = 700, segments = 72, ridgeHeight = 30, ridgeWidth = 40 },
	colors = GREY,
	layout = LAYOUT,

	-- ═══ 허브 "큰 나무 마을" ═══ 나무 아래(잎 덮개 반경) = 안전 지대(전투 없음 - 몬스터가 없고 들어오지 않는다).
	hub = {
		key = "spawn", -- WorldConfig.zones 키(옛 리스폰 마을 자리 - 복귀 · 리스폰이 읽는다)
		displayName = "큰 나무 마을",
		safeRadius = 300, -- = 잎 덮개 반경 = 경계(뿌리 끝 · 등불 줄)
		spawn = { r = 90, angleDeg = -90 }, -- 리스폰 자리(나무 앞 광장 · T1 쪽)
		-- 시설(뿌리 아래). 강화대 · 제단 · 상인은 WorldConfig가 이 자리를 읽는다(옛 강화소 · 커뮤니티 칸 대체).
		facilities = {
			forge = { angleDeg = -30, r = 170, displayName = "대장간", size = { 60, 18, 44 } }, -- 강화대 중심
			market = { angleDeg = 90, r = 170, displayName = "시장", size = { 70, 14, 40 } }, -- 상점 · 보석상인 · 판매
			community = { angleDeg = 210, r = 170, displayName = "커뮤니티 센터", size = { 60, 20, 50 } }, -- 환생 제단 · 부화장 자리 · 파티 게시판 · 순위판
			portal = { angleDeg = -90, r = 200, displayName = "포탈 광장", radius = 46 },
		},
		-- 커뮤니티 센터 안 자리 표시(기능은 해당 단계에서): 부화장 · 파티 게시판 · 순위판
		communitySpots = {
			{ id = "hatchery", label = "부화장(펫 단계)", offset = { -20, 0, 18 } },
			{ id = "partyBoard", label = "파티 게시판", offset = { 20, 0, 18 } },
			{ id = "rankBoard", label = "순위판", offset = { 0, 0, 30 } },
		},
		marketSpots = {
			{ id = "shop", label = "상점(준비)", offset = { -24, 0, -26 } },
			{ id = "sell", label = "판매", offset = { 24, 0, -26 } },
		},
		portalRingRadius = 38, -- 포탈 광장 안 구역별 포탈 6개(이름표가 안 겹치게 - 이웃 간격 38)
		lanterns = { count = 24 }, -- 경계선 등불(safeRadius 둘레)
		roots = { count = 8, length = 250, height = 10, width = 14 },
		-- 나무(점프맵 · 랜드마크). 높이 약 470. 잎(leaves)은 별도 모델 - 재질 · 색은 seasons에서(봄 벚꽃 교체 = 데이터만).
		tree = {
			-- M1 추가(사용자 - 매일 오르는 콘텐츠): 높이는 시간으로 역산했다 - 바닥 → 정상 6 ~ 8분(보통 실력) · 최고 정거장 → 정상 1.5 ~ 2분(검증 M1(가)가 아래 secondsPerStep으로 잰다).
			trunkRadius = 40, trunkHeight = 800,
			leaves = {
				season = "summer",
				seasons = {
					summer = { material = "Grass", color = { 110, 140, 105 } },
					spring = { material = "Grass", color = { 235, 180, 195 } }, -- 벚꽃(시즌 단계에서 season만 바꾼다)
				},
				-- 잎 뭉치(공 - 충돌 없음) - 고리마다 반경 · 높이 · 지름 · 개수. 잎 덮개 반경 ≈ 300 = 안전 지대 경계. 줄기 둘레 반경 70 안은 비운다(점프맵 나선).
				rings = {
					{ radius = 140, y = 560, diameter = 130, count = 10 },
					{ radius = 240, y = 520, diameter = 150, count = 14 },
					{ radius = 190, y = 640, diameter = 130, count = 10 },
					{ radius = 110, y = 720, diameter = 110, count = 7 },
				},
			},
			-- 구름층(연출 자리 - 그레이박스는 옅은 원판 하나 · 충돌 없음): 오르다 이 높이를 지나간다.
			cloudLayer = { y = 400, radius = 420, thickness = 6, transparency = 0.85 },
			metersPerStud = 0.28, -- 화면 높이 표시(m) = (발 − 지면) × 이 값(로블록스 관례 1 stud ≈ 0.28 m)
			-- 점프맵: 줄기 둘레 나선(발판 중심 반경 = 줄기 + ringOffset). 구간 = movement-metrics v2 §3 표 - 간격 · 오름은 발판 끝에서 끝. 발판마다 pattern을 차례로 되풀이한다.
			-- 구간 1 ~ 5의 끝 = 가지 정거장(체크포인트 · 휴식처 - 넓은 발판). 역대 최고 레벨(환생해도 유지 - peakLevel)이 unlockLevel 이상이면 그 정거장이 열리고,
			-- 허브의 덩굴 리프트가 가장 높은 열린 정거장으로 보낸다. 마지막 구간(정거장 5 → 정상)은 누구나 직접 오른다. 대시 칸 사이는 보통 세 칸(대시 쿨 8초).
			-- 떨어지면 마지막으로 밟은 정거장으로 돌아간다(fallDropStuds 아래로 내려가면 - 정거장의 "내려가기" 판을 쓰면 기록이 지워진다).
			course = {
				startAngleDeg = -90, ringOffset = 9, checkpointSize = 16,
				-- 보통 실력 가정(실패 · 재시도 포함) 한 칸 평균 시간 - 높이 역산의 근거(체감으로 다시 맞춘다)
				secondsPerStep = { easy = 2.0, normal = 3.5, hard = 5.0 },
				sections = {
					{ name = "뿌리 계단", difficulty = "easy", untilY = 100, width = 5, pattern = { { rise = 4, gap = 5 } } },
					{ name = "첫 가지", difficulty = "normal", untilY = 230, width = 3.5, pattern = { { rise = 6, gap = 10 }, { rise = 12, gap = 8 }, { rise = 4, gap = 15 } } },
					{ name = "구름 아래", difficulty = "normal", untilY = 360, width = 3.5, pattern = { { rise = 6, gap = 10 }, { rise = 12, gap = 8 }, { rise = 4, gap = 15 } } },
					{ name = "구름층", difficulty = "hard", untilY = 470, width = 2.5, pattern = { { rise = 5, gap = 24, dash = true }, { rise = 13, gap = 8 }, { rise = 8, gap = 14 }, { rise = 6, gap = 10 } } },
					{ name = "높은 가지", difficulty = "hard", untilY = 580, width = 2.5, pattern = { { rise = 5, gap = 24, dash = true }, { rise = 13, gap = 8 }, { rise = 8, gap = 14 }, { rise = 6, gap = 10 } } },
					{ name = "정상 오르기", difficulty = "hard", untilY = 750, width = 2.5, pattern = { { rise = 5, gap = 24, dash = true }, { rise = 13, gap = 8 }, { rise = 8, gap = 14 }, { rise = 6, gap = 10 } } },
				},
				-- 정거장 = 구간 1 ~ 5의 끝(순서대로). unlockLevel = 역대 최고 레벨 기준(제안 - 환생 요구 25 · 50 · 75 · 100 · 125와 겹치지 않게 간격을 벌렸다).
				stations = {
					{ name = "뿌리 정거장", unlockLevel = 10 },
					{ name = "첫 가지 정거장", unlockLevel = 30 },
					{ name = "구름 아래 정거장", unlockLevel = 60 },
					{ name = "구름층 정거장", unlockLevel = 120 },
					{ name = "높은 가지 정거장", unlockLevel = 250 },
				},
				fallDropStuds = 30,
				deck = { y = 760, radius = 26 }, -- 정상 전망대(6구역이 내려다보인다)
				dailyEgg = { label = "하루 1회 보상(펫 단계 - 무료 알)" }, -- 자리 표시만
				lift = { angleDeg = 0, r = 70, label = "덩굴 리프트" }, -- 허브 바닥 · 줄기 옆(밟으면 가장 높은 열린 정거장)
			},
		},
	},

	-- ═══ 구역 6개 ═══ tierIndex = 기존 tier(몬스터 · 드랍 그대로) · bossId = 이 구역의 진행 보스(BossData.placement.laps[1]과 같은 순서 - 검증이 대조).
	-- 배정: T1 = 견습 보스(구간 수호자 - 스테이지 5) · T2 ~ T6 = BR 모형 난이도 순(처음 만남 · 스테이지 30 · 솔로 전멸률 - M1 보고서 표).
	-- features(구역 좌표): 높이는 탐험 지역에(사냥 지대는 평평). kind = plateau(경사로로 걸어 오름) · tower(1단 점프 계단 나선) · cliff(못 오르는 벽 ≥ 23 - 경치 · 막음) ·
	--   cave(굴 - 벽 둘 + 지붕) · falls(폭포 벽 + 뒤 공간) · spire(랜드마크 기둥 - 오르지 않음). explore = 둘러볼 지점 이름(발견 목록 · 탐험 표시).
	-- eggs = 이스터에그 자리(발견 목록 데이터 틀만 - 보상은 칭호 · 꾸미기, 전투력 없음). at = 그 feature의 top | behind | inside | base.
	-- nests = 둥지 자리(기능은 펫 단계) · difficulty = walk(경사로) | chain(1단 점프 계단) | puzzle(공중 점프 2 + 대시 한 번의 도약) - 구역마다 walk 포함.
	zones = {
		{
			key = "tier1", tierIndex = 1, bossId = "section_guardian", angleDeg = -90, theme = "수호자의 석조 평원", floorTint = { 150, 156, 146 },
			landmark = { kind = "monoliths", r = 2400, count = 8, radius = 60, height = 34 },
			features = {
				{ kind = "plateau", r = 1100, lat = 300, w = 120, d = 90, h = 40, explore = "절벽 위 전망" },
				{ kind = "tower", r = 1500, lat = -330, size = 22, h = 60, explore = "폐허 망루 꼭대기" },
				{ kind = "cave", r = 1850, lat = 380, w = 50, d = 60, h = 26, explore = "바위 굴" },
				{ kind = "falls", r = 2250, lat = -420, w = 70, h = 60, explore = "폭포 뒤" },
				{ kind = "cliff", r = 1450, lat = 520, w = 200, d = 60, h = 90 },
			},
			eggs = { { id = "t1_watch", feature = 2, at = "top" }, { id = "t1_cave", feature = 3, at = "inside" }, { id = "t1_falls", feature = 4, at = "behind" } },
			nests = {
				{ difficulty = "walk", r = 1000, lat = -120 }, { difficulty = "walk", r = 1900, lat = 120 },
				{ difficulty = "chain", r = 1350, lat = 120 }, { difficulty = "chain", r = 2250, lat = 250 },
				{ difficulty = "puzzle", r = 1550, lat = -120 }, { difficulty = "puzzle", r = 2150, lat = -520 },
			},
		},
		{
			key = "tier2", tierIndex = 2, bossId = "crystal_queen", angleDeg = -30, theme = "수정 동굴", floorTint = { 150, 150, 162 },
			landmark = { kind = "spires", r = 2400, count = 5, radius = 70, height = 130 },
			features = {
				{ kind = "cave", r = 1100, lat = 320, w = 70, d = 90, h = 30, explore = "수정 굴" },
				{ kind = "spire", r = 1450, lat = -380, size = 30, h = 150, explore = "큰 수정 기둥" },
				{ kind = "plateau", r = 1900, lat = 520, w = 110, d = 110, h = 50, explore = "수정 언덕 위" },
				{ kind = "tower", r = 2250, lat = -400, size = 24, h = 70, explore = "수정 탑 꼭대기" },
				{ kind = "falls", r = 1500, lat = 560, w = 60, h = 70, explore = "빛 폭포 뒤" },
			},
			eggs = { { id = "t2_cave", feature = 1, at = "inside" }, { id = "t2_hill", feature = 3, at = "top" }, { id = "t2_falls", feature = 5, at = "behind" } },
			nests = {
				{ difficulty = "walk", r = 1000, lat = -150 }, { difficulty = "walk", r = 2200, lat = 150 },
				{ difficulty = "chain", r = 1400, lat = 100 }, { difficulty = "chain", r = 1950, lat = -500 },
				{ difficulty = "puzzle", r = 1700, lat = -100 }, { difficulty = "puzzle", r = 2300, lat = 380 },
				{ difficulty = "chain", r = 1150, lat = -450 },
			},
		},
		{
			key = "tier3", tierIndex = 3, bossId = "abyssal_lord", angleDeg = 30, theme = "수몰 사원", floorTint = { 144, 154, 160 },
			landmark = { kind = "temple", r = 2400, count = 4, radius = 50, height = 70 },
			features = {
				{ kind = "falls", r = 1050, lat = -420, w = 80, h = 80, explore = "사원 폭포 뒤" },
				{ kind = "tower", r = 1450, lat = 360, size = 26, h = 80, explore = "잠긴 종탑 꼭대기" },
				{ kind = "plateau", r = 1850, lat = -420, w = 100, d = 120, h = 36, explore = "제단 언덕" },
				{ kind = "cave", r = 2250, lat = 380, w = 60, d = 70, h = 28, explore = "물길 굴" },
				{ kind = "cliff", r = 1600, lat = -560, w = 180, d = 50, h = 80 },
			},
			eggs = { { id = "t3_falls", feature = 1, at = "behind" }, { id = "t3_bell", feature = 2, at = "top" }, { id = "t3_cave", feature = 4, at = "inside" } },
			nests = {
				{ difficulty = "walk", r = 1000, lat = 150 }, { difficulty = "walk", r = 2000, lat = 140 },
				{ difficulty = "chain", r = 1100, lat = 200 }, { difficulty = "chain", r = 2250, lat = -300 },
				{ difficulty = "puzzle", r = 1700, lat = 120 }, { difficulty = "puzzle", r = 2100, lat = 520 },
			},
		},
		{
			key = "tier4", tierIndex = 4, bossId = "scorpion_queen", angleDeg = 90, theme = "모래 유적", floorTint = { 162, 156, 140 },
			landmark = { kind = "pyramid", r = 2400, count = 1, radius = 70, height = 90 },
			features = {
				{ kind = "plateau", r = 1100, lat = 300, w = 140, d = 90, h = 30, explore = "모래 언덕 위" },
				{ kind = "cave", r = 1450, lat = 380, w = 60, d = 80, h = 26, explore = "무너진 지하 통로" },
				{ kind = "tower", r = 1850, lat = -420, size = 22, h = 64, explore = "오벨리스크 꼭대기" },
				{ kind = "falls", r = 2250, lat = 420, w = 60, h = 50, explore = "모래 폭포 뒤" },
				{ kind = "spire", r = 1600, lat = 560, size = 26, h = 110 },
			},
			eggs = { { id = "t4_tunnel", feature = 2, at = "inside" }, { id = "t4_obelisk", feature = 3, at = "top" }, { id = "t4_sandfall", feature = 4, at = "behind" } },
			nests = {
				{ difficulty = "walk", r = 1000, lat = 150 }, { difficulty = "walk", r = 2150, lat = 250 },
				{ difficulty = "chain", r = 1150, lat = 150 }, { difficulty = "chain", r = 2000, lat = 200 },
				{ difficulty = "puzzle", r = 1600, lat = -50 }, { difficulty = "puzzle", r = 2300, lat = -480 },
			},
		},
		{
			-- 폭풍 첨탑 = 특히 높게(사용자 지시): 첨탑 320 · 절벽 150.
			key = "tier5", tierIndex = 5, bossId = "storm_lord", angleDeg = 150, theme = "폭풍 첨탑", floorTint = { 146, 150, 158 },
			landmark = { kind = "stormSpire", r = 2400, count = 1, radius = 40, height = 320 },
			features = {
				{ kind = "tower", r = 1100, lat = 320, size = 28, h = 120, explore = "바람 탑 꼭대기" },
				{ kind = "cliff", r = 1450, lat = -380, w = 160, d = 80, h = 150, explore = "낙뢰 절벽(아래에서 올려다보기)" },
				{ kind = "plateau", r = 2000, lat = 520, w = 120, d = 100, h = 60, explore = "구름 고원" },
				{ kind = "cave", r = 2250, lat = -380, w = 60, d = 70, h = 30, explore = "번개 굴" },
				{ kind = "spire", r = 1650, lat = -600, size = 34, h = 200 },
			},
			eggs = { { id = "t5_windtop", feature = 1, at = "top" }, { id = "t5_plateau", feature = 3, at = "top" }, { id = "t5_cave", feature = 4, at = "inside" } },
			nests = {
				{ difficulty = "walk", r = 1000, lat = -150 }, { difficulty = "walk", r = 2100, lat = 120 },
				{ difficulty = "chain", r = 1350, lat = 100 }, { difficulty = "chain", r = 2250, lat = 300 },
				{ difficulty = "puzzle", r = 1700, lat = -150 }, { difficulty = "puzzle", r = 2000, lat = -520 },
				{ difficulty = "puzzle", r = 1250, lat = -520 },
			},
		},
		{
			key = "tier6", tierIndex = 6, bossId = "frost_giant", angleDeg = 210, theme = "빙하 동굴", floorTint = { 158, 162, 168 },
			landmark = { kind = "iceWall", r = 2400, count = 3, radius = 80, height = 120 },
			features = {
				{ kind = "cliff", r = 1100, lat = -450, w = 160, d = 70, h = 120, explore = "빙벽" },
				{ kind = "cave", r = 1450, lat = 380, w = 70, d = 90, h = 32, explore = "얼음 굴" },
				{ kind = "plateau", r = 1850, lat = -420, w = 120, d = 110, h = 55, explore = "빙하 고원" },
				{ kind = "falls", r = 2250, lat = 420, w = 70, h = 90, explore = "언 폭포 뒤" },
				{ kind = "tower", r = 1650, lat = 560, size = 24, h = 72, explore = "얼음 탑 꼭대기" },
			},
			eggs = { { id = "t6_cave", feature = 2, at = "inside" }, { id = "t6_glacier", feature = 3, at = "top" }, { id = "t6_falls", feature = 4, at = "behind" } },
			nests = {
				{ difficulty = "walk", r = 1000, lat = 150 }, { difficulty = "walk", r = 2150, lat = 120 },
				{ difficulty = "chain", r = 1150, lat = 150 }, { difficulty = "chain", r = 2000, lat = 180 },
				{ difficulty = "puzzle", r = 1700, lat = 120 }, { difficulty = "puzzle", r = 2350, lat = -250 },
			},
		},
	},

	-- 둥지 구조(movement-metrics v2 §4 - 자리만, 기능은 펫 단계). 높이 · 간격 = 발판 끝에서 끝.
	--   walk: 경사로(각 slopeDeg ≤ 45 · 폭 ≥ 4)로 선반 높이 ledgeH.
	--   chain: 1단 점프 계단 steps개(단마다 오름 rise ≤ 5 · 간격 gap ≤ 6 · 폭 width) - 맨 위 둥지(바닥에서 steps × rise).
	--   puzzle: 계단으로 기둥 위(pillarH) → 한 번의 도약(오름 rise 11 ~ 15 · 간격 gap 20 ~ 30 = 공중 2 + 대시 칸 80%) → 선반. 선반 높이 = pillarH + rise ≥ 23(바닥에서 바로는 못 오른다).
	--   실패하면 기둥 옆 바닥(계단 첫 단 바로 앞)에 떨어진다 - 높이 11에서 한 단 아래(처음부터 긴 길이 아니게). 선반 밑에 발판을 두면 그 발판에서 공중 2만으로 닿아 퍼즐이 깨진다.
	nest = {
		walk = { ledgeH = 12, slopeDeg = 35, width = 6, ledge = 12 },
		chain = { steps = 8, rise = 4, gap = 5, width = 4, ledge = 8 },
		puzzle = { pillarH = 11, pillarSize = 6, rise = 15, gap = 24, ledge = 8, stairRise = 4, stairGap = 4 }, -- 오름 15 > 공중 1 최대 13.32 → 공중 2 필요 · 간격 24 > 공중 2 최대(16 · H15) → 대시 필요
		marker = { size = 3 },
	},

	-- 토벌 · 보스 관문 표지(M1 추가 - 사용자): 관문마다 보스 고유 색(BossData 머리색) 빛기둥 - 하늘까지 · 멀리서 보이게. 파트 1개 · 충돌 · 쿼리 없음 · Persistent 모델(스트리밍으로 안 사라진다).
	gatePillar = { width = 8, height = 1800, transparency = 0.35 },

	-- 확장 자리(M1 추가 - 구현 없음 · 자리 · 좌표만, docs/design/world-map-m1.md §확장). 신규 보스 = "작은 보스 섬".
	--   outerRing: 바깥 고리 - 꽃잎 사이 틈(두 구역 원 밖 · 세계 끝 안) 6칸. 섬 반경 ≤ islandRadius.
	--   sky: 하늘층 - 나무 정상 전망대에서 다리로 잇는다(높이 y · 전망대에서 방위 bridgeAngleDeg로 bridgeLength).
	--   underground: 지하층 - 허브 뿌리 아래(입구 = 줄기 밑 entry). 주의: 심연 복귀선(TerrainConfig.voidReturnY = −24)보다 깊다 - 구현 때 이 공간을 복귀 판정에서 빼야 한다.
	reserved = {
		outerRing = { r = 2700, islandRadius = 180, angles = { -60, 0, 60, 120, 180, 240 } },
		sky = { y = 900, bridgeAngleDeg = 90, bridgeLength = 160, islandRadius = 120 },
		underground = { y = -80, entry = { angleDeg = 180, r = 60 }, radius = 260 },
	},

	-- ═══ 진행 · 이동 ═══
	progress = {
		-- 구역 k+1 = 구역 k 보스를 처음 잡으면 열린다(개인 · 계정 - 직업 중 가장 높은 보스 기록). 처음 = T1만.
		startUnlocked = 1,
		-- 잠긴 구역 밀어내기(서버 보조 - 주 수단은 클라 결계 벽): 들어온 자리 → 구역 원 밖 pushOutStuds.
		pushOutStuds = 6,
		pushCheckSeconds = 0.5,
	},
	-- 결계(잠긴 구역 경계 - 클라만 만든다: 캐릭터 물리는 클라 소유라 로컬 벽이 그 사람만 막는다). 투명 충돌 벽 + 발밑 빛 선 + 결계 문 표시.
	barrier = { wallHeight = 700, segmentLength = 60, lineHeight = 1.5, lineWidth = 1.2, gateWidth = 30, gateHeight = 26 },

	travel = {
		portalRadius = 6, -- 포탈 판 반경(밟으면)
		campDiscoverRadius = 60, -- 캠프 중심에서 이 안에 들어오면 그 구역 포탈 개방(저장)
		hubReturnCooldownSeconds = 60,
		partyTeleportCooldownSeconds = 90,
		-- 파티원 곁으로 이동 제한(제안): 내가 · 대상이 보스전 중이면 불가 · 내가 최근 combatLockSeconds 안에 피해를 주거나 받았으면 불가 ·
		-- 대상 자리가 나에게 잠긴 구역이면 불가. 도착 = 대상 옆 arriveOffsetStuds.
		combatLockSeconds = 8,
		arriveOffsetStuds = 5,
		streamTimeoutSeconds = 3, -- RequestStreamAroundAsync 기다림 상한(넘으면 그냥 옮긴다)
	},

	-- 길 안내(바닥 빛줄기 · 화살표 - 튜토리얼과 공유하는 client/Wayfinder). 표시만.
	guide = { beamWidth = 2.5, arrowEvery = 24, arrowsShown = 6, arriveStuds = 20, refreshSeconds = 0.5 },

	-- ═══ 최적화 ═══
	-- 몬스터 지대 활성화: 사냥 지대 중심 activateRadius 안에 사람이 있으면 그 지대 9마리를 세우고, keepRadius 밖으로 모두 나간 뒤 idleSeconds가 지나면 치운다.
	-- 서버 몬스터 수 = 사람이 있는 지대 × 9(맵 크기와 무관).
	spawnSites = { activateRadius = 250, keepRadius = 320, idleSeconds = 20, checkSeconds = 1.0 },
	-- 스트리밍(Workspace 속성 = default.project.json · 여기 값은 기록 · 검증 대조용). 나무 실루엣은 Persistent 모델.
	streaming = { targetRadius = 1024, minRadius = 128, streamOutBehavior = "Opportunistic" },

	-- 검증 · 이동 시간 표용 지점 이름(보고서)
	boss = { entry = "gate" }, -- 보스 입장 = 관문(보스 스테이지를 고르면 관문까지 길 안내 → 관문을 밟으면 입장). "direct" = 옛 즉시 입장
}
