-- QUEUE-B1 B2 시즌 패스(8주 - 사용자 지시). 시즌 번호 = 리더보드 시즌과 같은 시계(LeaderboardRules.seasonAt · LeaderboardConfig.seasonLengthDays = 56).
--   경험치 = profile.quests.currencies.passExp(G3 퀘스트 보상 칸 - 일일 · 주간 미션 · 접속 · 일일 상자가 이미 준다 = 공통 입구 재사용) · 시즌이 바뀌면 0부터.
--   무료 줄(free) = 누구나 · 유료 줄(paid) = 이번 시즌 유료(MonetizationData.products.season_premium). 보상 지급 = QuestService.grant(한 곳).
--   규칙(shared/Monetization.checkSeasonPass가 검사): 알(랜덤)은 무료 줄만 · 유료 줄은 판매 금지 목록 밖(치장 · 치장 재화)만.
--   치장 id = CosmeticSlotData.sets / gliderSkins. 외형 에셋은 자리(A가 채움).
local rows = { free = {}, paid = {} }
local TIERS = 40
for tier = 1, TIERS do
	-- 무료 줄: 조각 2 · 5칸마다 알 1 · 20 · 40칸 = 치장
	local free = { sparkleShard = 2 }
	if tier % 5 == 0 then
		free = { sparkleShard = 2, egg = 1 }
	end
	if tier == 20 then
		free = { cosmeticTheme = "starlight" }
	elseif tier == 40 then
		free = { gliderSkin = "petal" }
	end
	rows.free[tier] = free
	-- 유료 줄: 조각 4 · 10 · 30칸 = 치장 · 40칸 = 시즌 한정 테마
	local paid = { sparkleShard = 4 }
	if tier == 10 then
		paid = { gliderSkin = "kite" }
	elseif tier == 30 then
		paid = { cosmeticTheme = "ember" }
	elseif tier == 40 then
		paid = { cosmeticTheme = "frost" }
	end
	rows.paid[tier] = paid
end

return {
	enabled = true,
	tiers = TIERS,
	expPerTier = 250, -- 하루 약 120(일간 3 × 20 + 접속 10 + 상자 50) + 주 500(주간) → 8주 약 10,700 ≈ 40칸 × 250(모두 매일 하면 끝까지)
	rows = rows,
}
