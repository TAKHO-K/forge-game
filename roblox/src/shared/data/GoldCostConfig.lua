-- 골드 비용 곡선(P2 C1, 결정 4B "골드 비용을 수입 증가율에 연동"). 공식은 shared/GoldCost.lua 한 곳이고 여기엔 비용 종류별 기준 스테이지만 둔다.
--
-- 비용(종류, 기본 비용, 스테이지 s) = floor(기본 비용 × g_gold^max(0, s − 기준 스테이지)) - g_gold = InfiniteStageConfig.goldGrowthRate(P2.5a - 옛 k 1.155).
-- 골드 수입(잡몹 골드 = tier 골드 × k^(s−1))과 같은 k로 커지므로, 기준 스테이지 뒤로는 "골드/분 ÷ 1회 비용"(구매력)이 스테이지와 무관하게 일정하다.
-- 스테이지 s = 계정 최고 스테이지(PlayerProfile.getAccountBestStage) - 지금 서 있는 곳이 아니다(스테이지 1로 내려가 싸게 사는 구멍, 28-2 [8] 3번과 같은 규칙).
--
--   enhance       무기 강화 1회 골드(기본 비용 = EnhanceConfig.goldCost 표). 기준 100 = P0 E4에서 구매력을 잰 구간 끝(스테이지 100) -
--                 그때까지는 P2 전 고정표 그대로이고, 그 뒤로는 스테이지 100 시점의 구매력을 유지한다(P2 전: 스테이지 100 이후 골드 비용이 사실상 0).
--   rerollTicket  옵션 변환권(기본 비용 = tier1 잡몹 골드 × GemData.rerollTicketGoldMultiplier). 기준 1 = P2 전과 같은 값(잡몹 1마리당 골드 × 배수).
--   protection    강화 방지권(기본 비용 = tier1 잡몹 골드 × EnhanceConfig.protection[종류].priceKillEquivalent). 기준 1 = P2 전과 같은 값.
-- 새 골드 소비처(예: 펫)는 여기에 종류 한 줄을 더하고 GoldCost.cost(기본 비용, 스테이지, 종류)를 부르면 된다.
-- P2.5a C8: enhance 기준 100 → 1. 비용이 스테이지 1부터 골드 수입과 같은 율(InfiniteStageConfig.goldGrowthRate)로 커져 구매력이 1 ~ 100 구간에서도 일정하다
-- (기준 100이면 1 ~ 100에서는 비용이 고정이라 수입만 커져 구매력이 스테이지 따라 올랐다). 강화 1회 비용 = EnhanceConfig.goldCost × 1.001^(s − 1).
return {
	anchorStage = {
		enhance = 1,
		rerollTicket = 1,
		protection = 1,
		inherit = 1, -- P2.5b A: 장비 계승(기본 비용 = tier1 잡몹 골드 × InheritConfig.goldKillEquivalent[B 등급]) - 변환권과 같은 기준 1
	},
}
