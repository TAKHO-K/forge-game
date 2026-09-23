-- 환생 후 레벨 마일스톤(P2.5b D · P2.5c B2 재설계). 규칙 = shared/Milestone.lua.
-- P2.5c B2(사용자 확정): 회차마다 반복되던 50 · 100레벨 보상(곱연산 공격력 ×1.03 · 해금)은 없앴다 - 환생 자체가 회차 보상이다. 새 사다리는 **환생 5회를 마친 직업**만:
--   레벨 firstLevel(200) = 큰 보상(버킷 +bigBonus) + 첫 해금 · 그 뒤 statInterval(50)레벨마다 작은 보상(버킷 +smallBonus) · unlockInterval(100)레벨마다 다음 해금.
--   능력치는 합연산 전용 "마일스톤 버킷" 하나에 더한다: 배율 = 1 + 버킷. 모든 마일스톤의 합 ≤ capRatio − 1(= 스테이지 환산 10칸분 - 힘 비율 1.02^10,
--   COMMON §1 "k 의존 값 = 힘 비율" - k가 바뀌어도 같은 힘). 상한에 닿은 뒤의 작은 보상은 0이다(기록은 계속 오른다).
--   stat = 버킷이 붙는 곳("attack" = 공격력 · "survival" = 최대 체력) - 하네스 곡선 비교로 정했다(docs/phase/P25c-log.md).
--   해금은 계정 공유 · 한 번만(profile.milestoneUnlocks = 받은 개수). reserved = true는 시스템이 아직 없어 자리만 예약한다(기록만 남고 효과는 그 시스템이 생길 때).
--   해금 순서 근거: 지금 효과가 있는 것(가방 · 계승 할인)을 먼저, 예약 셋은 만들 가능성이 높은 순(보석 칸 = 무기 홈 6번째 · 프리셋 · 펫).

return {
	requiredRebirths = 5, -- 환생 이 횟수를 마친 직업부터(GemData.maxRebirthCount와 같은 값 - 마지막 환생)
	firstLevel = 200,
	statInterval = 50,
	unlockInterval = 100,
	bigBonus = 0.05,
	smallBonus = 0.001,
	capRatio = 1.02 ^ 10,
	stat = "attack",
	unlocks = {
		{ id = "bagSlots", name = "가방 칸 +5", bagSlots = 5 },
		{ id = "inheritDiscount", name = "계승 비용 -10%", inheritDiscount = 0.10 },
		{ id = "gemSocket", name = "보석 칸 +1(예약)", reserved = true },
		{ id = "presetSlot", name = "장비 프리셋 칸 +1(예약)", reserved = true },
		{ id = "petSlot", name = "펫 칸 +1(예약)", reserved = true },
	},
}
