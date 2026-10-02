-- QUEUE-ALL1 P3 §4 전 서버 합동 목표(docs/design/v2/04 §4): 주기 1주(월요일 UTC - Quest.weekOf와 같다) · 지표 = 보스 처치 수 + 초월 보너스(큰 칸).
--   보상 3칸(목표의 60% · 85% · 100% - 못 채워도 닿은 칸까지): 강화석 → 알 → 한정 칭호. 받을 자격 = 그 주에 1 이상 기여한 사람(profile.communityGoal - SAVE v57).
--   목표치 = "지난주 플레이 기준이면 이번 주도 간당간당": 기준선 = 지난 2 ~ 3주 합계 가중 평균(weights) · 주간 변화 ±weeklyChangeCap · 목표 = 기준선 × targetFactor(평균 페이스면 일요일쯤 달성).
--   1주차(기록 없음) = 첫 기여부터 24시간 실측 × 7 × week1Factor · 정해진 목표는 주 중간에 안 바뀐다.
--   집계 = 서버마다 flushSeconds 모아 DataStore UpdateAsync 한 번(서버 수 × 분당 1 ~ 2회 - 호출 한도 60 + 인원 × 10 / 분 안) · 1인 하루 상한 = MemoryStore HashMap(키 = 유저 · UTC 날짜 · TTL 2일).
--   MemoryStore 한도(서버당 분당 1000 + 인원 × 100 요청)는 처치당 1회라 넉넉하다. 실패하면 이 서버 세션 안에서만 센다(안전 쪽).
return {
	storeName = "CommunityGoal_v1",
	-- QUEUE-ALL8 E3: 명예의 전당 위 게이지(떠 있는 판) = 가까이(nearStuds 안)만 · 칸 달성 순간 = 거리 무관 showSeconds 동안(멀리서 HUD처럼 화면 위를 덮던 것)
	board = { nearStuds = 45, showSeconds = 5 },
	studioKeyPrefix = "studio_", -- Studio(수동 · 검증)는 라이브 합계를 안 건드린다
	dailyMapName = "CommunityGoalDaily",
	weights = { bossKill = 1, transcendent = 300 }, -- 초월 = 큰 칸
	dailyCapPerPlayer = 60, -- 1인 하루 기여 상한(보스 처치 60회분)
	-- QUEUE-ALL4 C: 하루 상한 키(MemoryStore) 수명 = 그날 UTC 끝 + 이 여유(초). 옛 TTL 2일은 키가 이틀치 쌓였다 - MemoryStore 메모리 한도(64KB + 1.2KB × 동시 접속)는
	-- 동시 접속 기준이라 "하루 접속자 수 ÷ 동시 접속"이 크면 이 키가 한도를 먼저 채워 파티 레코드 쓰기까지 막을 수 있다(docs/design/save-audit-launch.md §4).
	dailyTtlMarginSeconds = 600,
	flushSeconds = 45,
	baselineWeights = { 0.5, 0.3, 0.2 }, -- 지난주 · 2주 전 · 3주 전
	weeklyChangeCap = 0.25,
	targetFactor = 0.95,
	week1Factor = 0.7,
	-- QUEUE-ALL7 B: 목표 · 칸 문턱 = 끝 두 자리 00(roundTo 단위 · 가장 가까운 값) · 순서 = 가중 평균 × targetFactor → ±weeklyChangeCap → 반올림(제한보다 반올림을 먼저 하지 않는다) · 최솟값 minTarget(접속자가 아주 적어도 0 · 100이 안 나오게)
	roundTo = 100,
	minTarget = 300,
	tiers = {
		{ fraction = 0.6, reward = { enhanceStone = 40 }, label = "강화석 40" },
		{ fraction = 0.85, reward = { egg = 1 }, label = "알 1" },
		{ fraction = 1.0, reward = { title = "communityHero" }, label = "한정 칭호 「모두의 영웅」" },
	},
	text = {
		hud = "주간 합동 목표 %d%%", measuring = "주간 합동 목표 · 목표 계산 중", tierBanner = "[전 서버] 주간 합동 목표 %d%% 달성! 보상: %s",
		panelTitle = "주간 합동 목표", metric = "모든 서버의 보스 처치 수 + 초월 획득(큰 칸)", claim = "받기", claimed = "받음", locked = "미달성", needContribute = "이번 주 기여가 있어야 받습니다",
	},
}
