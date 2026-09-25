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
		spawn = { r = 120, angleDeg = -60 }, -- 리스폰 자리(나무 앞 · 판자뿌리 사이 - 뿌리 각 −78.5° · −42.5°)
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
		roots = { count = 8, length = 250, height = 4, width = 14 }, -- 낮은 경사(나무 점프맵 첫 가지 높이 5보다 낮게)
		-- 나무(점프맵 · 랜드마크). 높이 약 470. 잎(leaves)은 별도 모델 - 재질 · 색은 seasons에서(봄 벚꽃 교체 = 데이터만).
		tree = {
			-- M1 추가(사용자 - 매일 오르는 콘텐츠): 높이는 시간으로 역산했다 - 바닥 → 정상 6 ~ 8분(보통 실력) · 최고 정거장 → 정상 1.5 ~ 2분(검증 M1(가)가 course.secondsPer로 잰다).
			-- 나무 모양(사용자 - 세계수 · 메타세쿼이아처럼): 곧은 적갈색 줄기(결 · 판자뿌리) + 층층이 뻗은 수평 가지(tiers) + 아래가 넓고 위로 좁아지는 원뿔 수관 + 뾰족한 꼭대기(spire).
			--   가지 끝의 잎 뭉치(spray - 납작한 잎 판)는 점프맵 길 바깥(clearRadius 이상)에만 - 오르는 사람이 잎 속에 파묻히지 않게. 어깨(shoulderY) 위는 길이 끝난 뒤라 줄기까지 잎이 찬다.
			--   장식은 전부 충돌 · 쿼리 없음. 색 = bark(껍질) · 잎은 계절 역할(SeasonRole) - WorldMap.setSeason.
			trunkRadius = 48, trunkHeight = 800,
			bark = { 142, 84, 58 }, barkDark = { 108, 62, 44 }, barkMaterial = "SmoothPlastic", -- 카툰풍(평면 음영) -- 메타세쿼이아 적갈색 껍질(점프맵 가지 · 혹 · 정거장도 이 톤 - 길이 나무에서 튀지 않게)
			buttress = { count = 10, height = 90, reach = 95, width = 12 }, -- 판자뿌리(밑동이 넓게 퍼진다)
			ridges = { count = 14, depth = 3, width = 5 }, -- 줄기 결(세로 골)
			crownShape = {
				baseY = 150, baseRadius = 300, -- 가장 아래 가지층(가장 넓다 - 잎 덮개 ≈ 허브 안전 지대)
				shoulderY = 770, shoulderRadius = 150, -- 점프맵 끝 높이 - 여기까지 원뿔이 좁아진다
				tipY = 960, -- 꼭대기(뾰족 - 줄기가 가늘어지며 끝난다)
				-- 잎(사용자 확정 - 층층 로우폴리 원뿔): 층(tier)마다 각진 원뿔대 "치마" 한 장 - 위 가장자리 = 안쪽(점프맵 길 밖 clearRadius · 어깨 위는 줄기) · 아래 가장자리 = 수관 반경.
				--   면 = 쐐기 파트 2개로 만든 삼각형(로우폴리 · 메시 에셋 없음 - git에 남는다). 층마다 면 수 · 꼭짓점 반경 · 높이 · 비틀림 · 색을 고정 시드로 흔든다(매번 같은 모양).
				--   층이 위아래로 겹쳐(skirt > spacing) 틈이 없다 · 안쪽은 비어 있어 오르는 사람은 치마 밑에서 바깥을 본다. 꼭대기 = 끝이 뾰족한 원뿔(tip).
				clearRadius = 145,
				coneTiers = { spacing = 70, skirt = 104, facets = { 6, 8 }, thickness = 1.6 }, -- 면 수가 적을수록 로우폴리(파트 = 면 × 4)
				jitter = { seed = 20260926, radius = 0.09, y = 6, twistDeg = 16, tint = 0.07 },
			},
			leaves = {
				season = "summer", -- 계절 = 이 값 하나(또는 Workspace Attribute Season - WorldMap.setSeason이 SeasonRole 붙은 도형을 다시 칠한다)
				-- 계절 색표(역할별): 잎 판 = leaves(바깥 층) · leavesDeep(안쪽 · 아래 층) · 점프맵 잎 발판 = leafPad · 솔방울 = blossom. 메타세쿼이아: 봄 연둣빛 · 여름 초록 · 가을 적갈색 · 겨울 잎 진 회갈색 + 눈.
				seasons = {
					spring = { material = "SmoothPlastic", leaves = { 170, 210, 120 }, leavesDeep = { 140, 190, 100 }, leafPad = { 180, 215, 130 }, blossom = { 150, 110, 70 } },
					summer = { material = "SmoothPlastic", leaves = { 96, 150, 82 }, leavesDeep = { 72, 122, 66 }, leafPad = { 118, 165, 94 }, blossom = { 120, 90, 60 } },
					autumn = { material = "SmoothPlastic", leaves = { 196, 104, 52 }, leavesDeep = { 160, 78, 44 }, leafPad = { 210, 130, 64 }, blossom = { 110, 70, 45 } },
					winter = { material = "SmoothPlastic", leaves = { 214, 222, 228 }, leavesDeep = { 150, 128, 116 }, leafPad = { 228, 234, 238 }, blossom = { 240, 244, 248 } },
				},
			},
			fruitColors = { bounce = { 255, 150, 60 }, soft = { 200, 120, 220 }, hang = { 250, 220, 80 }, pad = { 230, 90, 90 } },
			-- 구름층(연출 자리 - 그레이박스는 옅은 원판 하나 · 충돌 없음): 오르다 이 높이를 지나간다.
			cloudLayer = { y = 400, radius = 420, thickness = 6, transparency = 0.85 },
			metersPerStud = 0.28, -- 화면 높이 표시(m) = (발 − 지면) × 이 값(로블록스 관례 1 stud ≈ 0.28 m)
			-- 점프맵(M1 재설계 - 사용자: "진짜 거대한 나무를 기어오른다"). 줄기 둘레 발판이 아니라 가지 · 열매 · 덩굴 · 잎 · 줄기 속 통로를 지나간다.
			--   두 갈래 길: inner = 줄기 가까이(반경 inner.radius) · 기존 방향(+) · 짧고 어렵다(좁은 발판 · 정밀 점프 · 줄기 속 통로) /
			--   outer = 반대 방향(−) · 줄기에서 멀리 뻗은 가지(반경 outer.radius) · 길고 점프대가 많다(경치). 두 길은 정거장(줄기 둘레 고리 발판 - 반경 ringInner ~ ringOuter)에서 만난다 -
			--   안쪽 길은 고리 안쪽 가장자리로 · 바깥 길은 바깥 가장자리로 올라선다(고리가 두 길 머리 위를 막지 않는다).
			--   구간 = 정거장 사이 6개(바닥 → 1 … 5 → 정상). 구간마다 주인공 요소 1개(theme). 요소(k): branch(원통 가지 - dia = 굵기 · 가늘수록 조심) · bounce(통통 열매 - 트램펄린) ·
			--   soft(말랑 열매 - 밟으면 가라앉다가 softDropSeconds 뒤 떨어지고 softRespawnSeconds 뒤 다시 - 로컬 · 풀링) · hang(매달린 열매 - 진자 · 움직이는 발판) ·
			--   pad(점프대 - 버섯 · 꽃봉오리 · 다음 요소까지 정해진 포물선으로 날린다 · 착지 표시) · vine(덩굴 사다리 - TrussPart 기본 오르기 · h) · leaf(잎 발판 - sway면 흔들림) ·
			--   tunnel(줄기 속 구멍 통로 - 줄기 안으로 들어가 반대편 구멍으로 나온다) · step(평범한 가지 혹).
			--   rise = 앞 요소 윗면 → 이 요소 윗면 · gap = 앞 요소 끝 → 이 요소 끝(수평 · 길을 따라). 필요한 기술은 검증 M1(가)가 movement-metrics v2 표(80% 여유)로 계산한다.
			--   pattern은 차례로 되풀이하고, 정거장 높이 finalRiseMax 안쪽에 들어오면 정거장으로 올라선다. secondsPer = 보통 실력 가정 시간(실패 · 재시도 포함 - 체감으로 다시 맞춘다).
			-- 구간 1 ~ 5의 끝 = 가지 정거장. 역대 최고 레벨(peakLevel)이 unlockLevel 이상이면 열리고 허브 덩굴 리프트가 가장 높은 열린 정거장으로 보낸다. 마지막 구간은 누구나 직접.
			-- 떨어지면 마지막으로 밟은 정거장으로(fallDropStuds 아래로 내려가 서면 - 정거장의 "내려가기" 판을 쓰면 기록이 지워진다).
			course = {
				trunkSegments = true, -- 줄기를 통로 높이에서 끊어 짓는다(속이 빈 고리)
				station = { ringInner = 68, ringOuter = 110, thickness = 2, segments = 16, startAngleDeg = -90 },
				inner = { radius = 60, dir = 1 },
				outer = { radius = 120, dir = -1 },
				finalRiseMax = 6,
				elementScale = 0.75, -- 밟는 칸 크기 배율(사용자 - 길이 나무보다 튀지 않게): 가지 · 잎 길이 · 열매 · 혹 · 점프대 갓. 가지 굵기(dia)는 균형 판정이라 그대로 · 열매 지름 최소 4 · 혹 최소 2.5
				bounce = { reachStuds = 22, horizontalMax = 14 }, -- 통통 열매: 밟으면 발 +reach(클라 속도) - 공중 점프는 그 뒤에도 쓴다(서버 높이 검증 예외 - TreeLaunch)
				pad = { maxGap = 44, maxRise = 18, flightSeconds = 1.1 }, -- 점프대: 다음 요소 가운데로 날린다(비행 시간 고정 포물선)
				soft = { sinkStuds = 0.8, dropSeconds = 1.5, respawnSeconds = 4 },
				hang = { rope = 10, swingDeg = 22, periodSeconds = 4.0 },
				leafSway = { deg = 6, periodSeconds = 3.2 },
				movingMax = 14, -- 움직이는 발판(매달린 열매 + 흔들리는 잎) 상한 - 검증이 센다
				climbStudsPerSecond = 9, -- 덩굴 오르기 속도(가정 - 시간 표)
				secondsPer = { easy = 2.0, normal = 3.2, hard = 4.8, bounce = 2.6, launch = 3.0, climbExtra = 1.0, soft = 0.6, hang = 1.5, tunnel = 8 },
				legs = {
					{ -- 바닥 → 정거장 1(100): 굵은 가지 + 통통 열매 입문(보통)
						name = "뿌리 가지", theme = "굵은 가지 · 통통 열매", untilY = 100,
						inner = { { k = "branch", rise = 5, gap = 8, len = 14, dia = 6 }, { k = "bounce", rise = 3, gap = 7, dia = 6 }, { k = "branch", rise = 12, gap = 6, len = 10, dia = 5 }, { k = "step", rise = 6, gap = 10, w = 5 }, { k = "branch", rise = 3, gap = 11, len = 12, dia = 5 } },
						outer = { { k = "branch", rise = 4, gap = 6, len = 22, dia = 8 }, { k = "bounce", rise = 3, gap = 6, dia = 7 }, { k = "branch", rise = 14, gap = 8, len = 20, dia = 7 }, { k = "branch", rise = 4, gap = 5, len = 18, dia = 7 } },
					},
					{ -- 정거장 1 → 2(230): 덩굴 + 잎(보통)
						name = "덩굴 숲", theme = "덩굴 사다리 · 잎 발판", untilY = 230,
						inner = { { k = "vine", rise = 16, gap = 4 }, { k = "leaf", rise = 2, gap = 5, len = 9 }, { k = "leaf", rise = 8, gap = 10, len = 9 }, { k = "leaf", rise = 12, gap = 8, len = 8, sway = true }, { k = "leaf", rise = 5, gap = 13, len = 8 } },
						outer = { { k = "vine", rise = 14, gap = 4 }, { k = "leaf", rise = 2, gap = 5, len = 14 }, { k = "leaf", rise = 6, gap = 8, len = 14 }, { k = "branch", rise = 5, gap = 7, len = 20, dia = 7 }, { k = "leaf", rise = 8, gap = 9, len = 12 } },
					},
					{ -- 정거장 2 → 3(360): 말랑 열매 + 줄기 속 통로(보통 → 어려움)
						name = "말랑 열매 골", theme = "말랑 열매 · 줄기 속 통로", untilY = 360,
						inner = { { k = "soft", rise = 6, gap = 10, dia = 5 }, { k = "soft", rise = 10, gap = 8, dia = 5 }, { k = "tunnel", rise = 4, gap = 6 }, { k = "branch", rise = 8, gap = 12, len = 8, dia = 4 }, { k = "soft", rise = 12, gap = 8, dia = 5 } },
						outer = { { k = "branch", rise = 5, gap = 7, len = 18, dia = 6 }, { k = "soft", rise = 6, gap = 8, dia = 6 }, { k = "soft", rise = 8, gap = 9, dia = 6 }, { k = "branch", rise = 4, gap = 6, len = 16, dia = 6 }, { k = "leaf", rise = 10, gap = 8, len = 12 } },
					},
					{ -- 정거장 3 → 4(470): 점프대 연속 + 가는 가지(어려움)
						name = "점프대 가지", theme = "점프대 · 가는 가지", untilY = 470,
						inner = { { k = "pad", rise = 3, gap = 8 }, { k = "branch", rise = 12, gap = 34, len = 12, dia = 2.5 }, { k = "branch", rise = 4, gap = 12, len = 12, dia = 2.5 }, { k = "branch", rise = 3, gap = 20, len = 10, dia = 2.5 }, { k = "step", rise = 11, gap = 8, w = 3 } },
						outer = { { k = "pad", rise = 2, gap = 6 }, { k = "branch", rise = 12, gap = 38, len = 16, dia = 3.5 }, { k = "pad", rise = 2, gap = 6 }, { k = "branch", rise = 10, gap = 36, len = 16, dia = 3 }, { k = "branch", rise = 4, gap = 9, len = 14, dia = 3 } },
						shortcut = { path = "inner", fromIndex = 2, skip = 3 }, -- 숨은 지름길: 잎 뒤에 숨은 덩굴(줄기 뒤쪽) - 요소 fromIndex에서 skip칸 건너뛴다
					},
					{ -- 정거장 4 → 5(580): 혼합 복습 - 통통 · 말랑 · 가는 가지 + 대시(어려움). 정거장이 5곳이라 구간이 6개(사용자 표 5개 + 이 구간).
						name = "높은 가지", theme = "혼합(통통 · 말랑 · 가는 가지)", untilY = 580,
						inner = { { k = "bounce", rise = 4, gap = 10, dia = 5 }, { k = "soft", rise = 18, gap = 8, dia = 5 }, { k = "branch", rise = 5, gap = 24, len = 10, dia = 2.5 }, { k = "step", rise = 13, gap = 8, w = 2.5 } },
						outer = { { k = "pad", rise = 2, gap = 8 }, { k = "branch", rise = 10, gap = 36, len = 14, dia = 3 }, { k = "soft", rise = 6, gap = 10, dia = 5 }, { k = "branch", rise = 5, gap = 20, len = 12, dia = 3 }, { k = "vine", rise = 16, gap = 5 } },
						egg = { path = "outer", index = 7, id = "tree_leafnest" }, -- 이스터에그 자리(바깥 길 잎 뒤)
					},
					{ -- 정거장 5 → 정상(750): 매달린 열매 + 공중 점프 · 대시 조합(마지막 - 누구나 직접)
						name = "정상 오르기", theme = "매달린 열매 · 점프 대시 조합", untilY = 750,
						inner = { { k = "hang", rise = 6, gap = 12, dia = 5 }, { k = "branch", rise = 5, gap = 24, len = 8, dia = 2.5 }, { k = "step", rise = 8, gap = 12, w = 2.5 }, { k = "leaf", rise = 6, gap = 26, len = 8 }, { k = "step", rise = 10, gap = 10, w = 2.5 }, { k = "branch", rise = 3, gap = 22, len = 8, dia = 2.5 } },
						outer = { { k = "hang", rise = 5, gap = 10, dia = 6 }, { k = "leaf", rise = 6, gap = 14, len = 10 }, { k = "pad", rise = 2, gap = 8 }, { k = "branch", rise = 10, gap = 34, len = 12, dia = 2.5 }, { k = "branch", rise = 4, gap = 24, len = 10, dia = 2.5 }, { k = "step", rise = 9, gap = 10, w = 2.5 }, { k = "branch", rise = 3, gap = 20, len = 8, dia = 2.5 } },
					},
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

	-- 봉인 입구(M1 추가 - 사용자: 신규 업데이트 티저). 아직 개발하지 않은 확장 자리(reserved)의 입구 = "봉인된 문".
	--   보스 잠금 결계(파란 빛 선 · 자물쇠 · "처음 잡으면 열린다")와 시각 언어가 다르다: 사슬 · 덩굴에 휘감긴 문 + 잠든 문장(빛이 숨쉬듯 희미하게) · 조건 문구 없음 · 날짜 · "곧 열림" 약속 문구 금지.
	--   이름은 작게(낡은 명판) + "???". 소품(props)은 그 던전 느낌만 - 테마 = 데이터 · 모델 묶음(Sealed_<id>)으로 분리(나중에 교체 쉽게).
	--   "뚫을 수 있을 것 같은" 틈(ledge): 문 옆 무너진 담 위 선반(높이 ledgeH - 공중 점프 1회로 닿는다) + 그 위 구멍. 실제로는 봉인 상자(box - 투명 충돌 벽 5면) + 서버 구역 검사(안이면 입구 앞으로 부드럽게 되돌림 · 피해 없음).
	--   선반까지 올라간 사람 = 짧은 문구 + 칭호 "호기심 대장"(계정 1회 · v39 titles). 봉인 상자 안은 비워 둔다(인스턴스 0).
	--   at: angleDeg · r = 문 위치(허브 원점 기준) · y = 문 바닥 높이 · 문 앞 = 허브 쪽(facing = "hub") 또는 바깥(facing = "out").
	sealed = {
		door = { width = 16, height = 22, frame = 3, ledgeH = 12, ledgeSize = 6, holeH = 8, wallW = 14, emblemSize = 5, breatheSeconds = 3.2 },
		title = { id = "curiousCaptain", name = "호기심 대장", line = "…아직 잠들어 있다." },
		entrances = {
			{ id = "clockTower", name = "태엽 시계탑", region = "outerRing", at = { angleDeg = 0, r = 2590, y = 0 }, facing = "hub", box = { w = 320, d = 340, h = 700 }, props = "clockTower" },
			{ id = "giantKitchen", name = "거인의 부엌", region = "outerRing", at = { angleDeg = 120, r = 2590, y = 0 }, facing = "hub", box = { w = 320, d = 340, h = 700 }, props = "giantKitchen" },
			{ id = "puppetTheater", name = "인형 극장", region = "outerRing", at = { angleDeg = 240, r = 2590, y = 0 }, facing = "hub", box = { w = 320, d = 340, h = 700 }, props = "puppetTheater" },
			-- 하늘섬: 나무 정상 전망대(760) 바깥 구름 발판 위 구름 문 - 정상에서만 보인다(구름 발판은 전망대에서 공중 점프 + 대시로 닿는다)
			{ id = "cloudWhale", name = "구름 고래 하늘섬", region = "sky", at = { angleDeg = 90, r = 152, y = 770 }, facing = "hub", box = { w = 80, d = 120, h = 200 }, props = "cloudWhale",
				platform = { r = 140, size = 24 } },
			-- 지하: 허브 뿌리 아래 - 줄기 밑동 옆 광산 입구(문 앞 = 바깥 · 상자 = 줄기 쪽)
			{ id = "moleMine", name = "두더지 광산", region = "underground", at = { angleDeg = 191, r = 76, y = 0 }, facing = "out", box = { w = 22, d = 20, h = 24 }, props = "moleMine" },
		},
	},

	-- ═══ 진행 · 이동 ═══
	progress = {
		-- 구역 k+1 = 구역 k 보스를 처음 잡으면 열린다(개인 · 계정 - 직업 중 가장 높은 보스 기록). 처음 = T1만.
		startUnlocked = 1,
		-- 잠긴 구역 밀어내기(서버 보조 - 주 수단은 클라 결계 벽): 들어온 자리 → 구역 원 밖 pushOutStuds.
		pushOutStuds = 6,
		-- 높은 곳 착지 복귀(서버): 나무 둘레(treeRadius) 밖에서 발이 standMaxY 위에 서 있으면 허브로 - 걸어서 오를 수 있는 가장 높은 곳 = 탑 지형 120(폭풍 첨탑 구역).
		treeRadius = 320, standMaxY = 160,
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

	-- 대기(Atmosphere - place 기본 밀도 0.3은 1,000 stud 밖을 거의 지운다 → 나무 · 빛기둥이 어디서나 보이게 낮춘다. 서버 부팅 때 Lighting에 적용 - git 기록)
	atmosphere = { density = 0.08, offset = 0 },

	-- 검증 · 이동 시간 표용 지점 이름(보고서)
	boss = { entry = "gate" }, -- 보스 입장 = 관문(보스 스테이지를 고르면 관문까지 길 안내 → 관문을 밟으면 입장). "direct" = 옛 즉시 입장
}
