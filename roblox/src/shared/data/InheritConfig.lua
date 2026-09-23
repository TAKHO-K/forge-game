-- 장비 계승(P2.5b A). 착용 중인 장비 A → 가방의 같은 부위 장비 B로 옵션 세트(종류 + 굴림 위치)를 옮기고, A는 분해 재료로 돌려준다(규칙 = shared/Inherit.lua).
-- 비용 = GoldCost.cost(tier1 잡몹 골드 × goldKillEquivalent[B 등급], 계정 최고 스테이지, "inherit") - 변환권(GemData.rerollTicketGoldMultiplier = 40마리)과 같은 "잡몹 처치 몇 마리 몫" 단위.
-- 값은 P2.5b 제안(docs/phase/P25b-log.md 결정 필요 2): 등급 1단계마다 ×2. 마일스톤 해금 "계승 비용 할인"(MilestoneData)이 이 비용에 곱해진다.

return {
	goldKillEquivalent = {
		normal = 20,
		rare = 40,
		epic = 80,
		legendary = 160,
		relic = 320,
		ancient = 640,
		primordial = 1280,
	},
}
