-- QUEUE-B1 B2 시즌 패스(8주 - 사용자 지시). 시즌 번호 = 리더보드 시즌과 같은 시계(LeaderboardRules.seasonAt · LeaderboardConfig.seasonLengthDays = 56).
--   경험치 = profile.quests.currencies.passExp(G3 퀘스트 보상 칸 - 일일 · 주간 미션 · 접속 · 일일 상자가 이미 준다 = 공통 입구 재사용) · 시즌이 바뀌면 0부터.
--   무료 줄(free) = 누구나 · 유료 줄(paid) = 이번 시즌 유료(MonetizationData.products.season_premium). 보상 지급 = MonetizationService.applyReward(한 곳).
--   규칙(shared/Monetization.checkSeasonPass가 검사): 알(랜덤)은 무료 줄만 · 유료 줄은 판매 금지 목록 밖(치장 · 치장 재화)만 · 골드 · 강화석 · 성장 소모품 = 무료 줄만.
--   치장 id = CosmeticSlotData.sets / gliderSkins(패스 전용 = passOnly · 시즌 한정 = seasonOnly - 상점 · 토큰 · 선물 X).
--
-- QUEUE-ALL9B 보완 지시(사용자 - 패스만 사고 치장을 안 사는 일이 없게): 무료 줄 = 성장 재화(골드 · 강화석 · 소모품 - 모두가 받음) · 유료 줄 = 패스 전용 치장 + 고래 세트 + 소량 토큰
--   (가치 ×5 ~ 8 · 토큰 ≤ 20% - 계산 = Monetization.passValue). 근거 표 = docs/phase/QUEUE-ALL9B-report.md "보완 지시" 절.
--   무료 줄 숫자 = **시즌 1(출시일 = 모두 1일차) 고정값**: 그 칸에 닿는 날(매일 접속 = 평일 120 · 주말 240 · 주간 500 · 칸당 170)의
--   기준선 유저(EconSim 유형별 값 × 1.2 - 높게 잡기)로 골드 = max(캐주얼 12.5분 사냥, 일반 3분 사냥) 00 단위 · 강화석 = 일반 유형 그날 강화 단계 2회 시도분(최소 10).
--   **2시즌부터는 같은 방법(유형별 성장표 다시 계산)으로 다시 정한다.**
local TIERS = 40

-- 무료 줄 골드(칸 1 ~ 40 · 20 · 40칸 = 패스 전용 치장이라 0)
local FREE_GOLD = {
	3500, 3500, 4200, 4200, 4200, 4200, 4200, 4200, 4200, 4400,
	4900, 4900, 4900, 4900, 5900, 5900, 5900, 5900, 5900, 0,
	6700, 6700, 6700, 7600, 7600, 7600, 7600, 7600, 7600, 8000,
	8000, 8000, 9800, 9800, 9800, 9800, 9800, 9800, 11200, 0,
}
-- 짝수 칸(+ 1칸) = 강화석 · 33칸부터 상급 강화석(+22 이상 재료)
local function stoneFor(tier)
	if tier == 1 or (tier % 2 == 0 and tier ~= 20 and tier ~= 40) then
		if tier >= 33 then
			return "highEnhanceStone", tier >= 39 and 26 or 20
		end
		return "enhanceStone", tier >= 24 and 24 or tier >= 21 and 20 or tier >= 4 and 16 or 10
	end
	return nil
end
local GEM_DUST = { [12] = 10, [24] = 10, [36] = 10 } -- 보석 재련 한두 번분
-- QUEUE-ALL9B G(사용자 10-03 - 방지권 폐지): 옛 하락 방지권 1장 → 골드. 그 칸 고정 골드에 더한다.
-- QUEUE-ALL9C 0-6(결정 4): 기준 = 그 칸에 닿는 날(매일 접속) 캐주얼 예상 스테이지의 옛 하락 방지권 상점가(Enhance.getProtectionPrice - 보스 표 0-5와 같은 환산) · niceReward.
--   25칸 = 21일째 스테이지 725 → 3,000 · 35칸 = 28일째 스테이지 1,045 → 4,200 → 4,000. 옛 140,000 · 490,000(일반 유형 방지 1회 추가 비용)은 무료 줄 가치를 43.8 → 58.2시간으로 키웠다.
local PROTECT_GOLD = { [25] = 3000, [35] = 4000 }

-- 유료 줄: 5칸마다 패스 전용 치장 · 그 밖 = 토큰 15 · 20 · 40칸 = seasonLimited(시즌 대표)
local PAID_COSMETIC = {
	[5] = { gliderSkin = "berryParachute" },
	[10] = { cosmeticTheme = "violetStar" },
	[15] = { gliderSkin = "jadeWing" },
	[25] = { cosmeticTheme = "sodaJelly" },
	[30] = { cosmeticTheme = "moonEmber" },
	[35] = { gliderSkin = "amethystWing" },
}
local PAID_TOKENS = 15

local rows = { free = {}, paid = {} }
for tier = 1, TIERS do
	local free = {}
	if FREE_GOLD[tier] > 0 then
		free.gold = FREE_GOLD[tier] -- 고정 골드(GoldCost 스테이지 배율 아님 - MonetizationService.applyReward)
	end
	local stoneId, stoneN = stoneFor(tier)
	if stoneId then
		free[stoneId] = stoneN
	end
	if tier % 5 == 0 and tier ~= 20 and tier ~= 40 then
		free.egg = 1
	end
	free.gemDust = GEM_DUST[tier]
	if PROTECT_GOLD[tier] then
		free.gold = (free.gold or 0) + PROTECT_GOLD[tier]
	end
	rows.free[tier] = free
	rows.paid[tier] = PAID_COSMETIC[tier] and table.clone(PAID_COSMETIC[tier]) or { sparkleShard = PAID_TOKENS }
end

-- QUEUE-ALL9B 4-5 시즌 대표 보상 틀: 시즌 번호마다 { paid40 = 유료 40칸 대표 · mid = 유료 20칸 중간 대표 · free40 = 무료 40칸 }.
--   비면 fallback(토큰) - 1시즌이 비면 검사 실패 · 2시즌은 경고("2시즌 대표 보상 결정 필요")(Monetization.checkSeasonPass).
local SLOTS = { paid40 = { row = "paid", tier = 40 }, mid = { row = "paid", tier = 20 }, free40 = { row = "free", tier = 40 } }
local seasonLimited = {
	[1] = {
		paid40 = { gliderSkin = "cloudWhale", cosmeticTheme = "cloudWhaleTrail" }, -- 구름 고래 세트(글라이더 + 물결 트레일) · 시즌 1 한정 · 최종 유효 보상
		mid = { cosmeticTheme = "auroraFrost" },
		free40 = { gliderSkin = "mintParachute" },
	},
}
local FALLBACK = { paid40 = { sparkleShard = 40 }, mid = { sparkleShard = PAID_TOKENS }, free40 = { sparkleShard = 5 } }
rows.free[20] = { cosmeticTheme = "meadowStar" } -- 무료 20칸 = 패스 전용 테마(모든 시즌 같음 - 이미 받았으면 지급 없음)

-- 시즌 번호의 표(대표 칸 반영 · 새 표 - 서버 받기 · 화면 · 검사가 같은 함수)
local function rowsFor(season)
	local out = { free = table.clone(rows.free), paid = table.clone(rows.paid) }
	local limited = seasonLimited[season] or {}
	for slot, at in pairs(SLOTS) do
		out[at.row][at.tier] = limited[slot] or FALLBACK[slot]
	end
	return out
end

-- QUEUE-ALL9A 1-3 · ALL9B 보완 5: 40칸 뒤 반복 보너스(170 경험치마다 · 시즌당 bonusCap회). 무료 = 토큰 1 + 골드(40칸 무렵 기준선 캐주얼 약 4분 사냥) · 유료 = 토큰 2
local BONUS = { free = { sparkleShard = 1, gold = 3600 }, paid = { sparkleShard = 2 } }
local BONUS_CAP = 20
local function rewardAt(season, rowName, tier)
	if tier > TIERS then
		return BONUS[rowName]
	end
	return rowsFor(season)[rowName][tier]
end

return {
	seasonLimited = seasonLimited,
	seasonSlots = SLOTS,
	rowsFor = rowsFor,
	rewardAt = rewardAt,
	enabled = true,
	tiers = TIERS,
	-- QUEUE-ALL9A 1-1: 40칸 = 6,800. 매일 접속(평일 120 · 주말 240 · 주간 500) = 32일째 · 주 4일 = 42일째(하네스 season_pass_test · economy_all9b)
	expPerTier = 170,
	bonus = BONUS,
	bonusCap = BONUS_CAP, -- QUEUE-ALL9B 보완 5-2: 반복 보너스 시즌당 상한(매일 접속 = 48일째에 참)
	-- QUEUE-ALL9A 1-2: 주말 2배 = 서버 UTC 금 15:00 ~ 월 07:00(한국 토 00:00 ~ 월 16:00 · 64시간). startSec = 일요일 00:00 UTC부터 초.
	weekend = { startSec = 5 * 86400 + 15 * 3600, lengthSec = 64 * 3600, mult = 2, sources = { login = true, daily = true, chest = true } },
	-- QUEUE-ALL9B 4-4 할인: true면 상점이 399 취소선 + season_premium_sale(299) · 서버는 지금 활성인 상품만 받는다(둘 다 같은 지급). 이번 시즌 = 할인 없음.
	saleActive = false,
	-- QUEUE-ALL9B 4-8 칸 건너뛰기(pass_skip1 · pass_skip5): 시즌당 구매로 오른 칸 상한 · 40칸까지만 · 넘는 영수증 = 토큰 환산(상품 robux 비례).
	--   건너뛴 칸의 무료 줄: 알 → 토큰 2(유료 랜덤 회피) · 골드 · 강화석 · 성장 소모품 → 토큰 1(로벅스로 성장 재화를 얻는 길 차단 - 보완 6-2) · 치장 = 그대로.
	-- SEC-FIX-1 8(사용자 결정 10-11): 칸 건너뛰기 = "못 한 출석 따라잡기"로만 - 출석판 센 칸 < 시즌 시작부터 지난 날 수일 때만 · 하루 perDay번(1) · 한 번에 1칸 ·
	--   매일 출석한 무료 유저가 오늘까지 닿는 칸(SeasonPassService.paceExp - 접속 + 일간 전부 + 상자 + 시작한 주의 주간 전부 · 주말 2배)을 넘지 못함. 날짜 = 서버 UTC(출석판과 같은 기준).
	skip = { capPerSeason = 20, maxTier = TIERS, eggTokens = 2, growthTokens = 1, perDay = 1 },
	-- 성장 재화 종류(무료 줄만 · 건너뛴 칸 = 토큰 1)
	growthKinds = { gold = true, enhanceStone = true, highEnhanceStone = true, gemDust = true, protectDrop = true },
	-- QUEUE-ALL9B 4-1 패스 치장 상당가(R$ - 같은 종류의 상점가 · 대표 = 499급) · 가치 목표(보완 지시: ×5 ~ 8 · 토큰 ≤ 20%)
	value = { theme = 199, gliderSkin = 149, item = 99, representative = 499, targetMin = 5, targetMax = 8, tokenShareMax = 0.2 },
	rows = rows,
}
