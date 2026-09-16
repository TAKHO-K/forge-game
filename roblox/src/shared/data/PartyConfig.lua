-- 파티 구조 상수(24-1, PRD 20.47 [5]). 밸런스 수치가 아니라 구조값이다 - 보스 HP 배수의
-- 지수 p는 여기 박지 않고 BossRules.partyHpExponent가 이 maxMembers·BossData.stageInterval·
-- InfiniteStageConfig.growthRate에서 매번 유도한다(새 밸런스 상수를 만들지 않는다는 지시).
return {
	-- 서버 정원 12 = 4인 × 3파티(PRD 20.47 [5](가) - 20.38 [6]이 12를 잡은 산식 그대로).
	-- 5인 이상은 보스 패턴 구속 시간(돌진 ⌈N/2⌉회)이 패턴 최소 간격 규칙을 깨는 상한이다.
	maxMembers = 4,

	-- 초대 팝업 유지 시간(PRD 20.47 [5](라) "받는 쪽 팝업 15초"). 지나면 자동 거절.
	inviteTimeoutSeconds = 15,
}
