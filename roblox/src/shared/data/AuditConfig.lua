-- S1 획득 보안(태초) · 속도 봉투 · 확률 검사 · 처치 속도 수치(server/AcquisitionAudit). 자동 제재는 없다 - 격리 · 보류 · 검토 대기 · 로그만.
return {
	-- 저장소(Studio = 시험 키 접두사 - PrimordialData와 같은 방식)
	ledgerStore = "PrimordialLedger_v1", -- 태초 발급 원장: 키 "roll_<rollId>" = { rollId, userId, source, p, stage, at, jobId, no, part }
	reviewStore = "AuditReview_v1", -- 검토 대기: 키 "u<userId>" = 최근 flags 목록(reviewKeep개)
	opsLogStore = "OpsLog_v1", -- 운영 명령 기록: 키 "log" = 최근 opsLogKeep개
	excludedStore = "PrimordialExcluded_v1", -- 명예의 전당 · 번호 집계에서 뺀 세계 번호(회수 · 격리): 키 "numbers" = { [번호 문자열] = 이유 }
	boardStore = "PrimordialCount_v1", -- 태초 리더보드(OrderedDataStore): 값 = 개수 × 1e10 + (9999999999 − 달성 unix) - 동점 = 먼저 달성
	alphaStatsStore = "AlphaStats_v1", -- S1 후속 0-5: 서버 종료 때 알파 통계 요약(AlphaStats): 키 "summaries" = 최근 alphaStatsKeep개 { at, jobId, uptime, 카운터 } · 검증 모드 = "_verify" 저장소
	alphaStatsKeep = 100,
	testKeyPrefix = "studio_",
	reviewKeep = 30,
	opsLogKeep = 200,

	-- 2-4 집계: 태초 리더보드 · 세계 번호 · 칭호 "태초의 선택" = 드랍 출처만(item.source.kind). 분해 보석 · 환생 무기 · 펫 합성 · 운영 지급/복구(kind "ops") · 선물은 출처 태그가 없거나 여기 없다.
	countableSources = { boss = true, raid = true, sparkle = true, field = true },

	-- 2-6 확률 검사: λ = 이 계정이 실제로 굴린 태초 확률의 합(profile.audit.lambda - 드랍마다 그 굴림의 태초 확률). P(X ≥ 보유 수 | λ) < 이 값 = 검토 대기(자동 제재 없음).
	poissonThreshold = 1e-6,

	-- 2-5 속도 봉투: EconSim 프로필 envelope(전 부위 태초 · 스테이지 1부터 · 최적 파티 · 조작 효율 1)의 합법 최대 곡선(플레이 시간 → 최고 스테이지) × margin을
	-- 넘으면 리더보드 등재 보류(Leaderboard.eligibility "velocity_hold") + 검토 대기. curve = { { 누적 플레이 시간(시), 최고 스테이지 } } - S1 보고서 2-5(로컬 EconSim).
	envelope = {
		margin = 1.1,
		-- 로컬 EconSim(W3b 파트 0 · 2026-09-28 - 후반 벽 · 천장 몫 0.9941 · 장비 옵션 = 위력 최대 굴림): 25,300 = 1,158시간(하루 24시간 48.3일) · 비교 상위 1% 2,501시간.
		--   새 곡선(원값) = 1h 540 · 2h 565 · 3h 610 · 5h 2,210 · 12h 3,395 · 50h 5,595 · 200h 9,440 · 500h 16,355 · 1,000h 23,850 · 1,500h 27,775 · 2,100h 30,900.
		--   옛(S1 · 2026-09-27): 25,300 = 1,169시간 · 상위 1% 1,968시간. 아래 = 옛 · 새 곡선의 시각별 큰 값(보류는 넓은 쪽이 안전 - 옛 경로로 합법 진행한 계정을 새로 보류하지 않는다).
		--   곡선 사이는 선형 보간 · 끝 뒤는 마지막 기울기.
		curve = { { 0, 1 }, { 1, 540 }, { 2, 1600 }, { 3, 2115 }, { 5, 2450 }, { 8, 2840 }, { 12, 3395 }, { 20, 4155 }, { 30, 4785 }, { 50, 5595 }, { 80, 6575 }, { 120, 8060 },
			{ 200, 9970 }, { 300, 11825 }, { 500, 16355 }, { 800, 21575 }, { 1000, 23850 }, { 1200, 25655 }, { 1500, 28845 }, { 1800, 31595 }, { 2100, 34015 } },
	},

	-- 2-7 처치 · 보스 클리어 속도 상한(넘으면 로그 + 검토 대기): 창 안 처치 수 · 보스 클리어 수. 합법 최대(광역 스킬 · 무리 5마리)보다 넉넉히.
	killRate = { windowSeconds = 60, maxKills = 240, bossWindowSeconds = 3600, maxBossClears = 120 },

	-- 플레이 시간 누적(profile.audit.playSeconds - 속도 봉투의 x축) 간격
	playTickSeconds = 60,
}
