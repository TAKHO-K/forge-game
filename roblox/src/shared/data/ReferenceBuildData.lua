-- PROG-2B-1 몹 기준 함수(shared/ReferenceBuild) 데이터 - CRIT-TRAIN-1 C7 · PROG-2A ④(D4) · GOLD-CURVE-1 G6(사용자 확정).
--   몹 HP · 권장 전투력 = 지금 곡선 × (새 규칙 기준 빌드의 한 대 기대 피해 ÷ 옛 규칙 기준 빌드의 한 대 기대 피해). 지금 곡선(대표 표 · 벽 · 구간 배율)은 옛 규칙의
--   중앙값(일반 프로필) 전투력 기대값으로 맞춘 고정점이라, 새로 생긴 힘(수련 1% · 치명 수련 …)만큼만 비율로 곱하면 "중앙값 = 같은 처치 속도"가 유지된다.
--   기준 빌드 = 중앙값이 그 스테이지에서 상한까지 산다고 본다("수련 먼저" 정책 - 모든 프로필이 열리는 대로 상한까지 삼 · CRIT-TRAIN-1 3-3).
return {
	refClass = "bow", -- 기준 직업(EconSim 대표 · 공격 버킷 직업 능력 값은 네 직업 같음)
	-- 영구 공격 버킷의 수련 · 직업 능력 밖 몫(마일스톤 등 - PROG-2A 설계 시뮬 comp.base = 1.05 · GOLD-CURVE-1 §6-3 ★ "상한까지 산다" 보정과 같은 값)
	bucketBase = 1.05,
	-- 옛 공용 수련(PROG-2B-1 전 - QUEUE-ALL9B 2): 공격 +0.1%/단계 · 최대 50 · 상한 = 최고 ÷ 20. 분모(옛 규칙 기준 빌드)에만 쓴다.
	legacyTraining = { attackPerLevel = 0.001, maxLevel = 50, stagesPerLevel = 20 },
}
