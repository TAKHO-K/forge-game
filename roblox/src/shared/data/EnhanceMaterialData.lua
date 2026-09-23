-- 강화 재료 2종(28-1 S04, PRD 20.72 [1-5](나) · 20.81 [B-4]) - 19 ~ 24강 시도가 골드와 함께 소모한다. 골드는 스테이지에 지수로 자라 고정가가
-- 공짜가 되므로, 스테이지에 지수로 자라지 않는 재료로 시간 축을 고정한다. 계정 공유(profile.materials)이고 처치 보상으로 즉시 지급된다(땅에 안 떨어진다).
-- 처치당 기대 개수 = dropChancePerKill × 마릿수분(tier · 접두사 보상 배율 / 보스 20 / 반짝이 · 상자 보너스) × 받는 사람의 경험치 배수
-- (PlayerProfile.getExpGainMultiplier - 성장 옵션 × 파티 보너스. 골드 · 장비에는 곱하지 않는다). 계산은 Loot.expectedMaterialCount 하나다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)

return {
	order = { "enhanceStone", "highEnhanceStone" },
	materials = {
		-- minStage: 받는 사람의 스테이지가 이 값 이상일 때만 나온다(보스도 "받는 사람의 스테이지"). 상급 해금 뒤에는 두 재료가 각각 독립으로 굴려진다.
		-- P2.5c 결정 10: 옛 스테이지 50 · 75(k 1.155)와 같은 힘의 지금 스테이지(힘 비율 - InfiniteStage.fromLegacyStage) = 358 · 539(k 1.02).
		enhanceStone = { displayName = "강화석", minStage = InfiniteStage.fromLegacyStage(50), dropChancePerKill = 0.25 },
		highEnhanceStone = { displayName = "상급 강화석", minStage = InfiniteStage.fromLegacyStage(75), dropChancePerKill = 0.25 },
	},
	-- 시도 1회의 소모(시도하는 순간의 단계 → { 재료 id, 개수 }). 0 ~ 18강은 없음(골드만)
	costByLevel = {
		[19] = { id = "enhanceStone", count = 8 },
		[20] = { id = "enhanceStone", count = 10 },
		[21] = { id = "enhanceStone", count = 12 },
		[22] = { id = "highEnhanceStone", count = 10 },
		[23] = { id = "highEnhanceStone", count = 13 },
		[24] = { id = "highEnhanceStone", count = 16 },
		-- P2.5a C5: 25 ~ 29강(→ +26 ~ +30) - 22 ~ 24강 증가폭(+3개)을 그대로 이었다.
		[25] = { id = "highEnhanceStone", count = 19 },
		[26] = { id = "highEnhanceStone", count = 22 },
		[27] = { id = "highEnhanceStone", count = 25 },
		[28] = { id = "highEnhanceStone", count = 28 },
		[29] = { id = "highEnhanceStone", count = 31 },
	},
}
