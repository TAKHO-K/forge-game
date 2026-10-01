-- QUEUE-B1 B2 P4c 수익화 골격 - **가격 · 상품 ID 자리값은 전부 이 파일 하나**(Creator Hub에서 만든 뒤 id만 채운다 · 0 = 아직 없음 → 구매 버튼이 "준비 중").
--   설계 = docs/design/monetization-p4c.md · 검사 = shared/Monetization.lua(checkCatalog - 판매 금지 목록 · 유료 랜덤 · 무료 줄 규칙) · 서버 = server/MonetizationService.lua(영수증 · 게임패스 · 정책).
--   치장 목록(테마 세트 · 글라이더 스킨)은 shared/data/CosmeticSlotData.lua(MV1 치장 슬롯 자리 - §7-6 기존 입구) · 시즌 패스 줄 = shared/data/SeasonPassData.lua.
--   치장 재화 = 반짝 조각(profile.quests.currencies.sparkleShard - G3 퀘스트 보상이 이미 쓰는 칸 · 지급 입구 QuestService.grant). 골드로는 치장을 못 산다.
return {
	-- 판매 금지(사용자 규칙): 상품 · 시즌 패스 유료 줄 · 선물의 grants에 이 종류가 하나라도 있으면 등록 검사가 거부한다.
	--   이름 = grant.kind. 보상 표의 옛 키(gold · enhanceStone 등)도 같은 뜻으로 막는다(aliases).
	forbiddenKinds = {
		gold = "골드", equipment = "장비", gem = "보석", randomOption = "랜덤 옵션", combatPower = "전투력",
		enhanceProtection = "강화 보호", luckBoost = "행운 부스트", expMultiplier = "경험치 배수", goldMultiplier = "골드 배수", title = "칭호",
	},
	forbiddenAliases = { -- 게임 안 보상 키 → 금지 종류(같은 것을 다른 이름으로 팔지 못하게)
		enhanceStone = "equipment", protectionTicket = "enhanceProtection", rerollTicket = "randomOption", gemDust = "gem", item = "equipment",
		rebirthTicket = "expMultiplier", titleId = "title", expBoost = "expMultiplier", goldBoost = "goldMultiplier",
	},
	-- 팔 수 있는 종류(이 밖의 종류는 모르는 종류로 거부 - 새 종류는 여기와 검사에 같이 넣는다)
	allowedKinds = { cosmeticTheme = true, gliderSkin = true, seasonPremium = true, gamePass = true },

	-- 개발자 상품(Developer Product - ProcessReceipt). key = 코드 이름 · productId = Creator Hub 번호(자리 0) · robux = 표시 가격(자리 - 실제 가격은 Creator Hub 값이 우선).
	--   grants = 산 사람이 받는 것(종류 · id). paidRandom = 유료 랜덤(지금 0개 - 넣으면 odds 필수 · 정책 제한 국가에서 구매 막힘).
	products = {
		theme_starlight = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "starlight" } } },
		theme_ember = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "ember" } } },
		theme_frost = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "frost" } } },
		glider_petal = { productId = 0, robux = 149, grants = { { kind = "gliderSkin", id = "petal" } } },
		glider_kite = { productId = 0, robux = 149, grants = { { kind = "gliderSkin", id = "kite" } } },
		theme_jelly = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "jelly" } } }, -- QUEUE-ALL1 P6 말랑 젤리
		glider_dragonWing = { productId = 0, robux = 149, grants = { { kind = "gliderSkin", id = "dragonWing" } } }, -- QUEUE-ALL1 P6 푸른 드래곤 날개
		season_premium = { productId = 0, robux = 399, grants = { { kind = "seasonPremium" } } }, -- 이번 시즌 유료 줄(시즌마다 다시 산다)
	},
	-- 게임패스(편의만 - 전투력 · 획득량 없음). passId = Creator Hub 번호(자리 0). 효과 수치도 여기(편의 값).
	gamePasses = {
		bagExpand = { passId = 0, robux = 149, bonusSlots = 20 }, -- 가방 칸 +20(InventorySync.capacity)
		pickupRadius = { passId = 0, robux = 99, radiusMultiplier = 1.5 }, -- 펫 자동 줍기 반경 ×1.5(PetService.pickupRange - 해금 기준은 그대로)
		recallCooldown = { passId = 0, robux = 99, cooldownMultiplier = 0.5 }, -- 마을 귀환 도착 뒤 쿨 ×0.5(Travel - hubReturnCooldownSeconds)
		nameplateColor = { passId = 0, robux = 49, colors = { "gold", "success", "stealShield", "ember" } }, -- 이름표 색(UIColors 기존 이름 - 새 색 금지 · 전투력 없음)
		nameplateBadge = { passId = 0, robux = 49, badges = { "hammer", "slime", "star", "heart" } }, -- QUEUE-ALL1 P6 이름표 배지: 이름 앞 작은 정지 아이콘 1개(고르기) · 칭호 흐름 띠와 안 겹침 · 전투력 없음
	},
	-- 반짝 조각 가격(로벅스 대신 조각으로 살 때 - 골드 불가). 조각을 **상품으로 직접** 팔지 않는다(유료 재화 상품 없음 - 시즌 유료 줄 보상에는 조각이 있다 · 조각은 치장만 산다 - 설계 문서 §3 · §10-2).
	shardPrices = { theme = 120, gliderSkin = 80 },
	-- QUEUE-B1 결정 8: 이미 가진 것을 (클라가 직접 연 구매 창으로) 산 영수증 · 지난 시즌에 연 유료 줄 영수증 = 반짝 조각으로 환산(자리값 - 조각 가격 기준).
	ownedRefundShards = { cosmeticTheme = 120, gliderSkin = 80, seasonPremium = 120 },
	-- 반짝 조각 출처(퀘스트 · 출석 · 메인 퀘스트 보상은 QuestData에 이미 있다 - 여기는 새 출처만)
	shardSources = {
		treeStation = 2, -- 나무 정거장 처음 오르기(정거장마다 1회 · 리프트 · 순간이동 도착은 제외)
		nestDex = 1, -- 비밀 둥지 도감 새 칸
		title = 3, -- 업적(칭호) 새로 받음
	},
	-- 유료 랜덤 정책(PolicyService ArePaidRandomItemsRestricted): 제한 대상에게는 paidRandom 상품의 구매 버튼을 막고 서버도 영수증을 거절 대신 환불 불가라 **프롬프트 자체를 막는다**.
	policy = { checkOnJoin = true, failClosed = true }, -- 정책 조회 실패 = 제한으로 본다(보수적)
	-- 영수증 기록(중복 처리 방지): 최근 receiptKeep개의 PurchaseId를 저장 · 구매 기록 logKeep줄
	receiptKeep = 200,
	logKeep = 100,
	-- 선물함(우편함): 치장만 · 관리자 = server/OpsConfig.userIds(운영 명령과 같은 목록) · 유저 간 로벅스 선물 = 자리(enabled false)
	gifts = {
		allowedKinds = { cosmeticTheme = true, gliderSkin = true, sparkleShard = true }, -- 선물로 줄 수 있는 것(치장 · 치장 재화)
		maxPending = 50, -- 한 사람 받을 선물 상한(넘으면 관리자 명령이 거부)
		claimedIdsKeep = 200, -- QUEUE-ALL5 A1(v62): 받은 선물 id 기록 개수(mailbox.claimedIds - 최근 것만 · 넘치면 가장 오래된 것부터 버림). 대기열에 남은 같은 id는 옮길 때마다 지우기를 다시 시도하므로 200개(= 상한 50의 4배) 밖으로 밀려날 때까지 남아 있을 수 없다
		storeName = "Gifts_v1", -- 오프라인 대상에게 쌓는 DataStore(검증 무장 중 = _verify 접미사)
		userToUser = { enabled = false, productKey = nil }, -- 유저 간 로벅스 선물 자리(P4c 뒤 - 대상 UserId를 프롬프트 전에 서버에 맡기는 방식)
	},
}
