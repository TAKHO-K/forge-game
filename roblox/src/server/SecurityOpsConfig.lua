-- QUEUE-ALL6 F 보안 운영 기준값(한 곳): 탐지(의심 기록) · 감사 기록 · 되돌리기 · 차단. 자동 처벌 없음 - 기록만(docs/phase/security-runbook.md).
--   의심 기록 = AcquisitionAudit.flag(검토 대기 저장소 AuditReview_v1 - 기존 입구 재사용) · 오탐을 줄이게 기준을 넉넉히(합법 최대의 약 2배 이상).
return {
	-- 탐지: 플레이어마다 windowSeconds 동안 센 값이 기준을 넘으면 kind별 cooldownSeconds에 한 번 기록
	detect = {
		windowSeconds = 60,
		cooldownSeconds = 600,
		-- 이동 되돌림(HeightGuard 수평 · 높이) 분당 - 정상 = 대시 · 활강 · 지연으로 가끔 0 ~ 2
		moveRevertsPerMin = 8,
		-- 골드 = "잡몹 몇 마리 몫"(계정 최고 스테이지의 tier1 1마리 골드)으로 나눈 분당 합. 정상 최대 = 광역 처치 + 보상 받기 몰아서(약 1,500)
		goldKillEqPerMin = 4000,
		-- 명중(서버가 피해를 계산한 횟수) 분당 - 평타 간격 하한 + 광역(최대 5마리) + 스킬 틱 = 약 1,200
		hitsPerMin = 2500,
		-- 공통 요청 제한(RequestGate)에 버려진 요청 분당 - 정상 연타는 몇 개
		gateDropsPerMin = 60,
		-- 보스 처치 시간 하한(초): 진입 연출(무적) 뒤 이보다 빨리 죽으면 기록(낮은 스테이지 한 방은 정상 - 이 값은 "무적 시간 안 처치" 수준)
		bossMinFightSeconds = 1.0,
	},
	-- 감사 기록(복구의 근거): 중요한 변화만 짧게. 저장 = AuditTrail_v1 키 u<userId>(Studio = 시험 접두사 · 검증 무장 = _verify)
	trail = {
		storeName = "AuditTrail_v1",
		keep = 200, -- 사람당 최근 몇 개
		maxAgeDays = 90, -- 이보다 오래된 줄은 쓸 때 버린다
		flushSeconds = 60, -- 모아서 쓰기(DataStore 예산)
		bigGoldKillEq = 20000, -- 한 번에 이만큼(잡몹 몇 마리 몫) 넘게 늘면 기록
		enhanceFromLevel = 20, -- 강화 성공 +20 이상 기록
	},
	-- 되돌리기(/ops rollback): 미리보기 → 확인 번호 → 실행. 확인 번호 유효 시간 · 백업 저장소
	rollback = {
		confirmSeconds = 300,
		backupStore = "OpsRollbackBackup_v1",
		listVersions = 30, -- 시각으로 고를 때 훑는 버전 수
		-- QUEUE-ALL6R 결정 8: 대상 저장을 다른 서버가 쥐고 있으면(SaveSystem.heldElsewhere) MessagingService로 그 서버에 내보내기를 부탁 → 잠금이 풀릴 때까지(최대 releaseWaitSeconds) 기다린 뒤 덮는다 · 안 풀리면 중단
		kickTopic = "OpsKick_v1", -- 검증 무장 = _verify
		releaseWaitSeconds = 30,
		releasePollSeconds = 3,
	},
	-- 확인 번호가 필요한 명령(되돌리기와 같은 미리보기 → /ops <명령> confirm <번호>): 영구 차단 · 초월 회수(QUEUE-ALL6R 결정 8)
	confirm = { banDurations = { perm = true }, revokeTranscendent = true },
	-- 차단(/ops ban): 로블록스 Players:BanAsync - 경험 전체 · 부계정 포함(ExcludeAltAccounts = false)
	ban = {
		durations = { ["1d"] = 86400, ["3d"] = 259200, ["7d"] = 604800, ["30d"] = 2592000, perm = -1 },
		maxReasonChars = 120,
	},
	-- 회수 가능한 재화(/ops revoke <userId> <재화> <수량>)
	revokeCurrencies = { gold = true, sparkleShard = true, enhanceStone = true, highEnhanceStone = true, gemDust = true },
}
