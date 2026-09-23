-- 환생 후 레벨 마일스톤(P2.5b D · R6A). 규칙 = shared/Milestone.lua. 값은 P2.5b 제안(docs/phase/P25b-log.md 결정 필요).
--   능력치 마일스톤: 환생 1회 이상인 직업이 그 회차에서 레벨 statInterval(50)의 배수에 처음 닿을 때마다 1회 - 회차마다 다시 센다(환생을 반복하면 누적).
--     1회 = 공격력 × k^statStagesPerMilestone(k = InfiniteStageConfig.growthRate - "스테이지 환산 1.5스테이지분", P25a 환산 표 단위 - 그 표에서 마일스톤은 공격 쪽 칸이다). 곱연산으로 쌓인다.
--     survival = true면 최대 체력에도 같은 배율을 곱한다. 기본 false: 생존에 주면 진행 속도를 정하는 방어구 생존 사다리(P25a 로그 10)를 건너뛰게 돼
--     곡선이 무너진다 - 하네스 실측(docs/phase/P25b-log.md D3) 일반 프로필 설계 최대 4,537시간 → 77.5시간. 생존 몫을 줄지는 결정 필요.
--   해금 마일스톤: 환생 뒤 레벨 unlockInterval(100)의 배수에 처음 닿을 때 unlocks의 다음 항목 1개(계정 공유 · 한 번만). 레벨 100 · 200 · 300 · 400 · 500 = 1 · 2 · 3 · 4 · 5번째.
--     reserved = true는 시스템이 아직 없어 자리만 예약한다(해금 기록만 남고 효과는 그 시스템이 생길 때 이 기록을 읽는다).
--   순서 근거: 환생 1 ~ 4회차는 레벨 155 · 202 · 248 · 279에서 끝난다(CharacterLevelConfig.rebirth) → 100 · 200은 중간 회차에서, 300 이상은 5회차(마지막 회차)에서만 닿는다 -
--   지금 효과가 있는 해금을 먼저 준다.

return {
	statInterval = 50,
	statStagesPerMilestone = 1.5,
	survival = false,
	unlockInterval = 100,
	unlocks = {
		{ id = "bagSlots", name = "가방 칸 +5", bagSlots = 5 },
		{ id = "inheritDiscount", name = "계승 비용 -10%", inheritDiscount = 0.10 },
		{ id = "gemSocket", name = "보석 칸 +1(예약)", reserved = true },
		{ id = "presetSlot", name = "장비 프리셋 칸 +1(예약)", reserved = true },
		{ id = "petSlot", name = "펫 칸 +1(예약)", reserved = true },
	},
}
