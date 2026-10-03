-- QUEUE-B1 B2 P4c 수익화 골격 - **가격 · 상품 ID 자리값은 전부 이 파일 하나**(Creator Hub에서 만든 뒤 id만 채운다 · 0 = 아직 없음 → 구매 버튼이 "준비 중").
--   설계 = docs/design/monetization-p4c.md · 검사 = shared/Monetization.lua(checkCatalog - 판매 금지 목록 · 유료 랜덤 · 무료 줄 규칙) · 서버 = server/MonetizationService.lua(영수증 · 게임패스 · 정책).
--   치장 목록(테마 세트 · 글라이더 스킨)은 shared/data/CosmeticSlotData.lua(MV1 치장 슬롯 자리 - §7-6 기존 입구) · 시즌 패스 줄 = shared/data/SeasonPassData.lua.
--   치장 재화 = 반짝 조각(profile.quests.currencies.sparkleShard - G3 퀘스트 보상이 이미 쓰는 칸 · 지급 입구 QuestService.grant). 골드로는 치장을 못 산다.
local D = {
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
	allowedKinds = { cosmeticTheme = true, gliderSkin = true, seasonPremium = true, gamePass = true, cosmeticItem = true, passTierSkip = true, bagSlots = true }, -- QUEUE-ALL9C 1-6 bagSlots = 가방 칸 출처(bagSources - 출처별 한 번 · 전투력 · 성장 재화 아님) -- QUEUE-ALL9B 4-8 passTierSkip = 시즌 패스 칸 건너뛰기(수량형 - 저장 실패 때 되돌림) -- QUEUE-ALL6 H cosmeticItem = 꾸미기 소품(칸 하나 · 겉모습만)

	-- 개발자 상품(Developer Product - ProcessReceipt). key = 코드 이름 · productId = Creator Hub 번호(자리 0) · robux = 표시 가격(자리 - 실제 가격은 Creator Hub 값이 우선).
	--   grants = 산 사람이 받는 것(종류 · id). paidRandom = 유료 랜덤(지금 0개 - 넣으면 odds 필수 · 정책 제한 국가에서 구매 막힘).
	products = {
		-- QUEUE-ALL9C 1-6(monetization 확정안): 모험가 스타터 팩 199 · 계정당 1회(starterPack - 스타터 전용 치장 starterOnly는 이 상품만 줄 수 있다) · 가방 +20 = bagSources.starter
		starter_pack = { productId = 0, robux = 199, starterPack = true, release = 1,
			grants = { { kind = "bagSlots", id = "starter" }, { kind = "cosmeticItem", id = "starterEdge" }, { kind = "cosmeticTheme", id = "starterStar" } } },
		theme_starlight = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "starlight" } } },
		theme_ember = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "ember" } } },
		theme_frost = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "frost" } } },
		glider_petal = { productId = 0, robux = 149, grants = { { kind = "gliderSkin", id = "petal" } } },
		glider_kite = { productId = 0, robux = 149, grants = { { kind = "gliderSkin", id = "kite" } } },
		theme_jelly = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "jelly" } } }, -- QUEUE-ALL1 P6 말랑 젤리
		glider_dragonWing = { productId = 0, robux = 149, grants = { { kind = "gliderSkin", id = "dragonWing" } } }, -- QUEUE-ALL1 P6 푸른 드래곤 날개
		season_premium = { productId = 0, robux = 399, grants = { { kind = "seasonPremium" } } }, -- 이번 시즌 유료 줄(시즌마다 다시 산다)
		-- QUEUE-ALL9B 4-4 할인 시즌용(SeasonPassData.saleActive가 켜질 때만 프롬프트 - 같은 지급) · 4-8 칸 건너뛰기(시즌당 구매로 오른 칸 상한 · 건너뛴 칸 알 = 토큰 · 성장 재화 = 토큰 1)
		season_premium_sale = { productId = 0, robux = 299, grants = { { kind = "seasonPremium" } } },
		pass_skip1 = { productId = 0, robux = 25, grants = { { kind = "passTierSkip", amount = 1 } } },
		pass_skip5 = { productId = 0, robux = 99, grants = { { kind = "passTierSkip", amount = 5 } } },
		-- QUEUE-ALL6 H 꾸미기 TOP 10(사용자 확정 · 유료 랜덤 없음 · 자리값 0). 키 규칙 = theme_<id> · glider_<id> · item_<id>
		theme_anvil = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "anvil" } } },
		theme_halloween = { productId = 0, robux = 199, grants = { { kind = "cosmeticTheme", id = "halloween" } } }, -- 10월만 판매(CosmeticSlotData seasonMonth)
		glider_slimeParachute = { productId = 0, robux = 149, grants = { { kind = "gliderSkin", id = "slimeParachute" } } },
		item_rocketPop = { productId = 0, robux = 99, grants = { { kind = "cosmeticItem", id = "rocketPop" } } },
		item_balloonPop = { productId = 0, robux = 99, grants = { { kind = "cosmeticItem", id = "balloonPop" } } },
		item_crystalBlade = { productId = 0, robux = 149, grants = { { kind = "cosmeticItem", id = "crystalBlade" } } },
		item_goldenHammer = { productId = 0, robux = 99, grants = { { kind = "cosmeticItem", id = "goldenHammer" } } },
		item_forgeBrazier = { productId = 0, robux = 99, grants = { { kind = "cosmeticItem", id = "forgeBrazier" } } },
		item_highFive = { productId = 0, robux = 49, grants = { { kind = "cosmeticItem", id = "highFive" } } },
		item_petCrown = { productId = 0, robux = 49, grants = { { kind = "cosmeticItem", id = "petCrown" } } },
		-- QUEUE-ALL9B 3-4 499R$급(tier = premium) 자리 - **인식용 임시 제안**(실제 상품 · 이름 · 구성은 사용자가 정한다 · productId 0 = 로벅스 준비 중 · 토큰으로는 살 수 있다).
		--   묶음 = 이미 있는 에셋만(새 메시 없음): 망치와 모루 테마 + 슬라임 낙하산 + 황금 망치.
		bundle_blacksmith = { productId = 0, robux = 499, tier = "premium", name = "대장장이 세트", proposal = true,
			grants = { { kind = "cosmeticTheme", id = "anvil" }, { kind = "gliderSkin", id = "slimeParachute" }, { kind = "cosmeticItem", id = "goldenHammer" } } },
	},
	-- QUEUE-ALL9C 1-6 출시 상품 순차 공개: 상품 · 게임패스마다 공개 단계(1 = 출시). releaseStageNow보다 큰 단계 = 상점에 안 보임 + 서버가 구매 프롬프트 · 토큰 구매 거부(Monetization.isReleased 한 곳).
	--   표에 없는 키 = releaseDefault. ★패스 보상 치장(별빛 · 서리꽃 · 불씨 테마 · 꽃잎 · 연 글라이더)은 시즌 1 동안 상점 비공개(패스 전용 - 결정 4) · 이후 판매 여부 = 결정 필요.
	releaseStageNow = 1,
	releaseDefault = 2,
	release = {
		starter_pack = 1, season_premium = 1, season_premium_sale = 1, pass_skip1 = 1, pass_skip5 = 1,
		theme_anvil = 1, theme_jelly = 1, theme_halloween = 1, glider_dragonWing = 1, glider_slimeParachute = 1,
		item_rocketPop = 1, item_balloonPop = 1, item_crystalBlade = 1, item_highFive = 1, item_petCrown = 1,
		bagExpand = 1, pickupRadius = 1, recallCooldown = 1, nameplateColor = 1, nameplateBadge = 1,
		-- 나중(2): 황금 망치 · 화로 · 이름표 세트 · (새벽 깃 날개 · 별의 수호룡 = 상품 자리 없음 - ALL9E 이후) · 대장장이 묶음(제안) · 패스 보상 치장 5종
		item_goldenHammer = 2, item_forgeBrazier = 2, nameplateSet = 2, bundle_blacksmith = 2,
		theme_starlight = 2, theme_ember = 2, theme_frost = 2, glider_petal = 2, glider_kite = 2,
	},
	-- QUEUE-ALL9C 1-6R(사용자 10-03) 상점 카드: NEW 띠 = 공개 단계가 열린 날(UTC)부터 newDays일 · 단계 1 날짜 = 자리값(실제 출시일로 바꾼다 - 보고서 결정 필요)
	newDays = 14,
	releaseStageStartUtc = { [1] = 1790985600 }, -- 2026-10-03 00:00 UTC(자리)
	-- 가격급 띠(등급 색 아님 - UI 중립색 3종 UIColors shopBand*): 49 · 79 · 99 = 기본 / 149 · 199 = 특별 / 그 위(399 · 499) = 대표
	priceBands = { { maxRobux = 99, id = "basic" }, { maxRobux = 199, id = "special" }, { maxRobux = math.huge, id = "flagship" } },
	-- 추천 탭 "이번 주 추천" 카드 4개: 주 1회 UTC 월요일 00:00 교체(epochUtc = 월요일 기준점) · 후보 표에서 차례로(공개 · 판매 중 · 산 것 제외는 화면이 거른다) · 카운트다운만(깜빡임 · 압박 문구 없음)
	weeklyFeatured = {
		count = 4,
		epochUtc = 1767571200, -- 2026-01-05 00:00 UTC(월요일)
		pool = { "theme_anvil", "glider_dragonWing", "item_rocketPop", "item_petCrown", "theme_jelly", "glider_slimeParachute", "item_balloonPop", "item_highFive",
			"item_crystalBlade", "theme_halloween", "item_goldenHammer", "item_forgeBrazier", "theme_starlight", "glider_petal", "theme_ember", "glider_kite", "theme_frost" },
	},
	-- QUEUE-ALL9C 1-6 가방 칸 출처(출처별 한 번): 기본 SaveConfig.bagBaseSlots(35) + 가방 확장 패스 20 + 스타터 20 = 최대 75(bagMaxSlots - 검사)
	bagSources = { starter = { slots = 20 } },
	bagMaxSlots = 75,
	-- QUEUE-ALL9B 3-4 가격 등급(표시 · 검사용): premium = 499R$급 대표 치장. 상품의 tier가 여기 이름이면 robux가 이 값이어야 한다(checkCatalog).
	tiers = { premium = { robux = 499 } },
	-- QUEUE-ALL9B 3-3 꾸미기 토큰 가격 = 로벅스 가격에 비례(499R$급 = premiumTokens · roundTo 단위 반올림) - 계산 = shared/Monetization.tokenPriceForRobux 한 곳.
	--   근거 = 토큰 유입 모형(docs/phase/QUEUE-ALL9B-report.md 4절): 캐주얼(하루 1시간)이 도감 60% · 67% · 75%에 닿는 날 누적 토큰 498 · 696 · 948 → 가운데 67% ≈ 700
	--   (보완 지시로 패스 무료 줄 토큰이 성장 재화로 바뀐 뒤 다시 잰 값 - 처음 계산 800).
	--   49 → 70 · 99 → 140 · 149 → 210 · 199 → 280 · 399 → 560 · 499 → 700. 토큰으로 못 사는 것 = 시즌 패스 보상(passOnly) · 시즌 한정(seasonOnly) · 출석판 전용(boardOnly) · 시즌 유료 줄.
	tokenPricing = { premiumRobux = 499, premiumTokens = 700, roundTo = 10 },
	-- 게임패스(편의만 - 전투력 · 획득량 없음). passId = Creator Hub 번호(자리 0). 효과 수치도 여기(편의 값).
	gamePasses = {
		bagExpand = { passId = 0, robux = 149, bonusSlots = 20 }, -- 가방 칸 +20(InventorySync.capacity)
		pickupRadius = { passId = 0, robux = 79, radiusMultiplier = 1.5 }, -- QUEUE-ALL9C 1-6 표시 가격 99 → 79(실제 가격 = Creator Hub) -- 펫 자동 줍기 반경 ×1.5(PetService.pickupRange - 해금 기준은 그대로)
		recallCooldown = { passId = 0, robux = 49, cooldownMultiplier = 0.5 }, -- QUEUE-ALL9C 1-6 표시 가격 99 → 49 -- 마을 귀환 도착 뒤 쿨 ×0.5(Travel - hubReturnCooldownSeconds)
		nameplateColor = { passId = 0, robux = 49, colors = { "gold", "success", "stealShield", "ember" } }, -- 이름표 색(UIColors 기존 이름 - 새 색 금지 · 전투력 없음)
		nameplateBadge = { passId = 0, robux = 49, badges = { "hammer", "slime", "star", "heart" } },
		-- QUEUE-ALL9C 1-6 이름표 세트 79(색 + 배지) - 색 · 배지 둘 다 없는 사람에게만 보인다(onlyWithout) · 공개 단계 2(나중)
		nameplateSet = { passId = 0, robux = 79, includes = { "nameplateColor", "nameplateBadge" }, onlyWithout = { "nameplateColor", "nameplateBadge" } }, -- QUEUE-ALL1 P6 이름표 배지: 이름 앞 작은 정지 아이콘 1개(고르기) · 칭호 흐름 띠와 안 겹침 · 전투력 없음
	},
	-- 꾸미기 토큰(id sparkleShard) 가격 · 환산 = 아래 tokenPricing에서 계산(파일 끝 - shardPrices · ownedRefundShards = 종류별 대표값 · 표시 · 옛 호출 호환).
	--   토큰을 **상품으로 직접** 팔지 않는다(유료 재화 상품 없음 - 시즌 유료 줄 보상에는 토큰이 있다 · 토큰은 치장만 산다 - 설계 문서 §3 · §10-2).
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
		allowedKinds = { cosmeticTheme = true, gliderSkin = true, sparkleShard = true, cosmeticItem = true }, -- 선물로 줄 수 있는 것(치장 · 치장 재화)
		maxPending = 50, -- 한 사람 받을 선물 상한(넘으면 관리자 명령이 거부)
		claimedIdsKeep = 200, -- QUEUE-ALL5 A1(v62): 받은 선물 id 기록 개수(mailbox.claimedIds - 최근 것만 · 넘치면 가장 오래된 것부터 버림). 대기열에 남은 같은 id는 옮길 때마다 지우기를 다시 시도하므로 200개(= 상한 50의 4배) 밖으로 밀려날 때까지 남아 있을 수 없다
		storeName = "Gifts_v1", -- 오프라인 대상에게 쌓는 DataStore(검증 무장 중 = _verify 접미사)
		userToUser = { enabled = false, productKey = nil }, -- 유저 간 로벅스 선물 자리(P4c 뒤 - 대상 UserId를 프롬프트 전에 서버에 맡기는 방식)
	},
}

-- QUEUE-ALL9B 3-3: 로벅스 → 토큰 가격(식 한 곳 - Monetization.tokenPriceForRobux가 이 함수를 부른다). 종류별 대표값 = 표시 · 옛 호출 호환(실제 가격 · 영수증 환산은 상품의 robux로 상품마다).
local function tokens(robux)
	local p = D.tokenPricing
	return math.max(p.roundTo, math.floor(p.premiumTokens * robux / p.premiumRobux / p.roundTo + 0.5) * p.roundTo)
end
D.tokenPrice = tokens
D.shardPrices = { theme = tokens(199), gliderSkin = tokens(149), item = tokens(99) }
D.ownedRefundShards = { cosmeticTheme = tokens(199), gliderSkin = tokens(149), seasonPremium = tokens(399), cosmeticItem = tokens(99) }
return D
