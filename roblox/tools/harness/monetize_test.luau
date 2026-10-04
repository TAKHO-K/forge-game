-- QUEUE-B1 B2 수익화 골격 하네스(실제 shared/Monetization · 서버 MonetizationService · CosmeticService · SeasonPassService · GiftService · SaveSystem + 가짜 Marketplace · Policy · DataStore).
-- 실행: python deps.py MonetizationService,SaveSystem,OpsServer.server > deps.txt → LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(cat deps.txt) ECON_RES=res_mon.txt python build_run.py monetize_test.luau
Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[MON] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

-- 가짜 서비스: Players(UserId → 가짜 Player) · Marketplace(프롬프트 기록) · Policy · DataStore(선물 대기열) · HttpService(GUID)
local PLAYERS, prompts, policyAnswer, DS, guid = {}, {}, nil, {}, 0
local dsFailUpdate = false -- QUEUE-ALL5 A1: 대기열 지우기(UpdateAsync) 실패 주입
local releaseMode = false -- QUEUE-ALL9A 1-2: 출시 서버 흉내(RunService:IsStudio() = false)
local baseGetService = game.GetService
game.GetService = function(self, name)
	if name == "RunService" and releaseMode then
		return { IsStudio = function() return false end, IsServer = function() return true end, IsRunning = function() return true end }
	elseif name == "Players" then
		return setmetatable({ GetPlayerByUserId = function(_, id) return PLAYERS[id] end, GetPlayers = function() return {} end },
			{ __index = function() return { Connect = function() end } end })
	elseif name == "MarketplaceService" then
		return setmetatable({ PromptProductPurchase = function(_, p, id) table.insert(prompts, { "product", id }) end, PromptGamePassPurchase = function(_, p, id) table.insert(prompts, { "pass", id }) end,
			UserOwnsGamePassAsync = function() return false end }, { __index = function() return { Connect = function() end } end })
	elseif name == "PolicyService" then
		return { GetPolicyInfoForPlayerAsync = function() if policyAnswer == "error" then error("policy down") end return { ArePaidRandomItemsRestricted = policyAnswer } end }
	elseif name == "DataStoreService" then
		return { GetDataStore = function(_, storeName) DS[storeName] = DS[storeName] or {}; local t = DS[storeName]
			return { UpdateAsync = function(_, key, fn) if dsFailUpdate then error("ds down") end local v = fn(t[key]); if v ~= nil then t[key] = v end; return v end, GetAsync = function(_, key) return t[key] end } end }
	elseif name == "HttpService" then
		return { GenerateGUID = function() guid += 1; return "G" .. guid end }
	end
	return baseGetService(self, name)
end

local ok, err = pcall(function()
	local SaveSystem, PlayerProfile = MODS.SaveSystem, MODS.PlayerProfile
	local Data, Mon = MODS.MonetizationData, MODS.Monetization
	local Cos, Season = MODS.CosmeticSlotData, MODS.SeasonPassData
	local RELEASE_NOW = Data.releaseStageNow
	Data.releaseStageNow = 99 -- QUEUE-ALL9C 1-6: 옛 검사(구매 · 토큰 · 장착 원리)는 공개 단계와 무관 - 시험 상품(별빛 · 서리꽃 · 묶음)이 2단계라 전부 열어 둔다 · 순차 공개 검사 직전에 되돌림

	-- ① 판매 금지 목록 강제
	local okCat, reasons = Mon.checkCatalog(Data, Cos, Season)
	check("실제 카탈로그(상품 6 · 시즌 40칸 × 2줄) 통과", okCat, table.concat(reasons, " / "))
	local banned = { "gold", "equipment", "gem", "randomOption", "combatPower", "enhanceProtection", "luckBoost", "expMultiplier", "goldMultiplier", "title",
		"enhanceStone", "protectionTicket", "rerollTicket", "gemDust", "rebirthTicket", "expBoost", "goldBoost", "sparkleShard", "egg", "whatever" }
	local allRejected, rows = true, {}
	for _, kind in ipairs(banned) do
		local okP, why = Mon.checkProduct(Data, "t_" .. kind, { productId = 1, robux = 1, grants = { { kind = kind, id = "x", amount = 1 } } }, Cos)
		allRejected = allRejected and not okP
		if okP then table.insert(rows, kind) end
	end
	check("금지 10종 + 별칭 7 + 로벅스 조각 · 알(랜덤) · 모르는 종류 → 전부 등록 거부", allRejected, "통과한 것: [" .. table.concat(rows, ",") .. "]")
	local okMixed = Mon.checkProduct(Data, "mix", { productId = 1, robux = 1, grants = { { kind = "cosmeticTheme", id = "starlight" }, { kind = "gold", amount = 5 } } }, Cos)
	check("치장 + 골드 섞은 상품 거부", not okMixed)
	local okRandom = Mon.checkProduct(Data, "rnd", { productId = 1, robux = 1, paidRandom = true, grants = { { kind = "cosmeticTheme", id = "starlight" } } }, Cos)
	check("유료 랜덤 확률표 없음 거부", not okRandom)
	local okBadCos = Mon.checkProduct(Data, "nocos", { productId = 1, robux = 1, grants = { { kind = "cosmeticTheme", id = "없는세트" } } }, Cos)
	check("없는 치장 id 거부", not okBadCos)
	local badSeason = { tiers = 1, rows = { free = { { sparkleShard = 1 } }, paid = { { egg = 1 } } } }
	local okS1 = Mon.checkSeasonPass(Data, badSeason, Cos)
	local badSeason2 = { tiers = 1, rows = { free = { { sparkleShard = 1 } }, paid = { { gold = 100 } } } }
	local okS2 = Mon.checkSeasonPass(Data, badSeason2, Cos)
	check("시즌 유료 줄 알(랜덤) · 골드 거부", not okS1 and not okS2)
	local dupData = table.clone(Data)
	dupData.products = { a = { productId = 7, robux = 1, grants = { { kind = "gliderSkin", id = "petal" } } }, b = { productId = 7, robux = 1, grants = { { kind = "gliderSkin", id = "kite" } } } }
	local okDup = Mon.checkCatalog(dupData, Cos, nil)
	check("같은 productId 두 상품 거부", not okDup)
	check("유료 랜덤 정책: 제한 true · 조회 실패(nil → failClosed) = 막힘 · false = 허용", not Mon.paidRandomAllowed({ paidRandom = true }, true)
		and Mon.paidRandomAllowed({ paidRandom = true }, false) and Mon.paidRandomAllowed({ paidRandom = false }, true) and Data.policy.failClosed)

	-- 가짜 플레이어(로드된 프로필)
	local attrs = {}
	local player = setmetatable({ Name = "Buyer", UserId = 77, Parent = true }, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
		if k == "IsA" then return function() return false end end
		if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
		return nil
	end })
	PLAYERS[77] = player
	local profile = SaveSystem.migrate({})
	PlayerProfile.init(player, profile)
	PlayerProfile.setClassId(player, "bow")
	local p = PlayerProfile.getProfile(player)
	p.tutorial = p.tutorial or {}
	p.tutorial.completed = true
	local MS = MODS.MonetizationService
	local QuestService = MODS.QuestService
	QuestService.onLoaded(player)

	-- ② 구매 처리(ProcessReceipt): 상품 id 자리값 대신 시험 id를 넣는다
	Data.products.theme_ember.productId = 9001
	MS.validProducts.theme_ember = true
	local saves = 0
	local saveResult = true
	local deps = { save = function() saves += 1; return saveResult end }
	local receipt = { PlayerId = 77, ProductId = 9001, PurchaseId = "P-1", CurrencySpent = 199 }
	local d1 = MS.processReceipt(receipt, deps)
	local d2 = MS.processReceipt(receipt, deps)
	local s = PlayerProfile.getMonetizationState(player)
	check("영수증 첫 호출 = 지급 + Granted · 같은 구매 ID 두 번째 = 다시 안 줌 + Granted", tostring(d1):find("PurchaseGranted") ~= nil and tostring(d2):find("PurchaseGranted") ~= nil
		and s.cosmetics.themes.ember == true and #s.purchases.receipts == 1 and saves == 1, ("%s · %s · 기록 %d · 저장 %d"):format(tostring(d1), tostring(d2), #s.purchases.receipts, saves))
	saveResult = false
	local d3 = MS.processReceipt({ PlayerId = 77, ProductId = 9001, PurchaseId = "P-2", CurrencySpent = 199 }, deps)
	local recorded = Mon.hasReceipt(s.purchases, "P-2")
	saveResult = true
	local d4 = MS.processReceipt({ PlayerId = 77, ProductId = 9001, PurchaseId = "P-2", CurrencySpent = 199 }, deps)
	check("저장 실패 → NotProcessedYet · 기록 빼기 → 재시도 때 Granted(멱등)", tostring(d3):find("NotProcessedYet") ~= nil and not recorded and tostring(d4):find("PurchaseGranted") ~= nil
		and Mon.hasReceipt(s.purchases, "P-2"), ("%s → %s"):format(tostring(d3), tostring(d4)))
	local d5 = MS.processReceipt({ PlayerId = 999, ProductId = 9001, PurchaseId = "P-3" }, deps)
	local d6 = MS.processReceipt({ PlayerId = 77, ProductId = 123456, PurchaseId = "P-4" }, deps)
	check("접속 안 한 사람 · 모르는 상품 = NotProcessedYet(지급 없음)", tostring(d5):find("NotProcessedYet") ~= nil and tostring(d6):find("NotProcessedYet") ~= nil)
	local logOk = #s.purchases.log >= 4
	check("구매 기록(log) 남음", logOk, ("%d줄 · 마지막 %s"):format(#s.purchases.log, tostring(s.purchases.log[#s.purchases.log] and s.purchases.log[#s.purchases.log].result)))
	for i = 1, Data.receiptKeep + 5 do
		Mon.recordReceipt(s.purchases, "R" .. i, 0, Data.receiptKeep)
	end
	check(("영수증 기록 상한 %d"):format(Data.receiptKeep), #s.purchases.receipts == Data.receiptKeep and not Mon.hasReceipt(s.purchases, "R1") and Mon.hasReceipt(s.purchases, "R" .. (Data.receiptKeep + 5)))

	-- ③ 프롬프트: 자리값 0 = 준비 중 · 판매 목록 밖 거부 · 정책
	local okP1, whyP1 = MS.promptProduct(player, "theme_starlight")
	local okP2o, whyP2o = MS.promptProduct(player, "theme_ember") -- 리뷰 중요 3: 이미 가진 테마 = 창 안 엶
	Data.products.glider_kite.productId = 9003
	MS.validProducts.glider_kite = true
	local okP2 = MS.promptProduct(player, "glider_kite")
	local okP3, whyP3 = MS.promptProduct(player, "nope")
	check("프롬프트: id 0 → not_ready · 이미 가진 것 → owned · 시험 id → 열림 · 없는 상품 → 거부", not okP1 and whyP1 == "not_ready" and not okP2o and whyP2o == "owned" and okP2 and not okP3 and #prompts == 1,
		("%s · %s · %s · %s"):format(tostring(whyP1), tostring(whyP2o), tostring(okP2), tostring(whyP3)))
	Data.products.glider_kite.productId = 0
	Data.products.glider_petal.productId, Data.products.glider_petal.paidRandom, Data.products.glider_petal.odds = 9004, true, { petal = 1 }
	MS.validProducts.glider_petal = true
	local okR1 = MS.promptProduct(player, "glider_petal") -- 정책 모름 = failClosed → 막힘
	Data.products.glider_petal.productId, Data.products.glider_petal.paidRandom, Data.products.glider_petal.odds = 0, nil, nil
	check("유료 랜덤 상품 + 정책 모름 → 프롬프트 막힘", not okR1)

	-- ④ 치장: 조각 구매(골드 불가) · 장착 섞기 · 소유 안 한 것 거부
	local qs = PlayerProfile.getQuestState(player)
	qs.currencies.sparkleShard = 50
	local gold0 = p.gold
	local b1, w1 = MODS.CosmeticService.buyWithShards(player, "cosmeticTheme", "frost")
	qs.currencies.sparkleShard = 500
	local b2 = MODS.CosmeticService.buyWithShards(player, "cosmeticTheme", "frost")
	local b3, w3 = MODS.CosmeticService.buyWithShards(player, "cosmeticTheme", "frost")
	check(("조각 모자람 거부 · 구매 %d 차감(199R$ 테마 = 토큰가) · 두 번째 owned · 골드 그대로"):format(Data.shardPrices.theme), not b1 and w1 == "shards" and b2 and not b3 and w3 == "owned" and qs.currencies.sparkleShard == 500 - Data.shardPrices.theme and p.gold == gold0,
		("조각 %d"):format(qs.currencies.sparkleShard))
	local e1 = MODS.CosmeticService.equip(player, "dashTrail", "frost")
	local e2 = MODS.CosmeticService.equip(player, "jumpFx", "ember")
	local e3, w4 = MODS.CosmeticService.equip(player, "glideTrail", "starlight")
	local e4, w5 = MODS.CosmeticService.equip(player, "nameplateColor", "gold")
	-- (가짜 Player는 Instance가 아니라 Attribute 적용은 건너뛴다 - 장착 표로 확인 · Attribute는 다음 Play 목록)
	check("칸별 섞어 장착(frost + ember) · 안 산 세트 거부 · 패스 없는 이름표 색 거부", e1 and e2 and not e3 and w4 == "not_owned" and not e4 and w5 == "no_pass"
		and s.cosmetics.equipped.dashTrail == "frost" and s.cosmetics.equipped.jumpFx == "ember" and s.cosmetics.equipped.glideTrail == nil)
	-- QUEUE-ALL6 H 꾸미기 소품(cosmeticItem): 조각 60 · 칸 맞춤 장착 · 다른 칸 거부 · 소품 상품 지급 멱등 · 할로윈 10월만
	qs.currencies.sparkleShard = Data.tokenPrice(Data.products.item_rocketPop.robux) + 40
	local i1 = MODS.CosmeticService.buyWithShards(player, "cosmeticItem", "rocketPop")
	local i2, wi2 = MODS.CosmeticService.buyWithShards(player, "cosmeticItem", "rocketPop")
	local q1 = MODS.CosmeticService.equip(player, "killFx", "rocketPop")
	local q2, wq2 = MODS.CosmeticService.equip(player, "weaponSkin", "rocketPop")
	local q3, wq3 = MODS.CosmeticService.equip(player, "killFx", "balloonPop")
	check("소품: 조각 토큰가(99R$) 차감 · 두 번째 owned · 처치 칸 장착 · 다른 칸 거부 · 안 산 소품 거부", i1 and not i2 and wi2 == "owned" and qs.currencies.sparkleShard == 40 and q1 and not q2 and wq2 == "unknown" and not q3 and wq3 == "not_owned"
		and s.cosmetics.equipped.killFx == "rocketPop", ("조각 %d"):format(qs.currencies.sparkleShard))
	local g1 = MODS.CosmeticService.grant(player, "cosmeticItem", "petCrown")
	local g2, wg2 = MODS.CosmeticService.grant(player, "cosmeticItem", "petCrown")
	check("소품 지급(상품 · 선물 공통 입구) 멱등 · 테마/글라이더 표에 안 섞임", g1 and not g2 and wg2 == "owned" and s.cosmetics.items.petCrown == true and s.cosmetics.gliderSkins.petCrown == nil and s.cosmetics.themes.petCrown == nil)
	local oct = os.time({ year = 2026, month = 10, day = 15, hour = 3 })
	local sep = os.time({ year = 2026, month = 9, day = 15, hour = 3 })
	check("할로윈 테마 = 10월(KST)만 판매 · 다른 테마는 늘", Mon.onSale(Cos, "cosmeticTheme", "halloween", oct) and not Mon.onSale(Cos, "cosmeticTheme", "halloween", sep) and Mon.onSale(Cos, "cosmeticTheme", "anvil", sep))

	-- ④-2 QUEUE-ALL9B 3-5 토큰 구매(상품 키 - 묶음 포함): 499급 묶음 = 800 · 시즌 유료 줄 · 시즌 한정 = 토큰 불가 · 연타 = 두 번째 owned · 부족 거부 · 감사
	MS.validProducts.bundle_blacksmith = true
	local bundlePrice = Mon.productTokenPrice(Data, Cos, "bundle_blacksmith")
	qs.currencies.sparkleShard = bundlePrice - 1
	local tb0, wtb0 = MS.buyWithTokens(player, "bundle_blacksmith")
	qs.currencies.sparkleShard = bundlePrice + 5
	local tb1 = MS.buyWithTokens(player, "bundle_blacksmith")
	local tb2, wtb2 = MS.buyWithTokens(player, "bundle_blacksmith")
	check(("토큰 묶음(499R$급 %d): 부족 거부 · 구매 = 3종 지급 · 연타 = owned · 남은 5"):format(bundlePrice), bundlePrice == Data.tokenPricing.premiumTokens and not tb0 and wtb0 == "shards" and tb1 and not tb2 and wtb2 == "owned"
		and s.cosmetics.themes.anvil and s.cosmetics.gliderSkins.slimeParachute and s.cosmetics.items.goldenHammer and qs.currencies.sparkleShard == 5, ("토큰 %d"):format(qs.currencies.sparkleShard))
	qs.currencies.sparkleShard = 5000
	local tp, wtp = MS.buyWithTokens(player, "season_premium")
	local tw, wtw = MODS.CosmeticService.buyWithShards(player, "gliderSkin", "cloudWhale")
	local tu, wtu = MS.buyWithTokens(player, "nope")
	check("토큰 불가: 시즌 유료 줄 · 시즌 한정(구름 고래) · 모르는 상품 - 토큰 그대로", not tp and wtp == "not_cosmetic" and not tw and not tu and wtu == "unknown" and qs.currencies.sparkleShard == 5000,
		("%s · %s · %s"):format(tostring(wtp), tostring(wtw), tostring(wtu)))
	local prices = {}
	for _, r in ipairs({ 49, 99, 149, 199, 399, 499 }) do
		table.insert(prices, ("%d→%d"):format(r, Mon.tokenPriceForRobux(Data, r)))
	end
	check("토큰가 = 로벅스 비례(10 단위 · 499급 700)", Mon.tokenPriceForRobux(Data, 49) == 70 and Mon.tokenPriceForRobux(Data, 99) == 140 and Mon.tokenPriceForRobux(Data, 149) == 210
		and Mon.tokenPriceForRobux(Data, 199) == 280 and Mon.tokenPriceForRobux(Data, 499) == 700, table.concat(prices, " "))

	-- ⑤ 조각 출처: 나무 정거장 1회 · 순간이동 도착 제외
	local before = qs.currencies.sparkleShard
	local t1 = MODS.CosmeticService.onTreeStation(player, 2, false)
	local t2 = MODS.CosmeticService.onTreeStation(player, 2, false)
	local t3 = MODS.CosmeticService.onTreeStation(player, 3, true)
	check("나무 정거장 처음 = +2 · 두 번째 없음 · 순간이동 도착 없음 · 키 문자열", t1 and not t2 and not t3 and qs.currencies.sparkleShard == before + Data.shardSources.treeStation and s.cosmetics.treeStations["2"] == true)

	-- ⑥ 시즌 패스: 경험치 → 칸 · 무료 받기 · 유료 없이 거부 · 알 무료 줄 · 시즌 넘김 초기화
	local SP = MODS.SeasonPassService
	SP.ensure(player) -- 접속 때(MonetizationService.onLoaded)처럼 먼저 이번 시즌으로 넘긴다(시즌 0 → 지금 = 경험치 0부터)
	qs.currencies.passExp = Season.expPerTier * 5 + 10
	local c1 = SP.claim(player, "free", 1)
	local c2, why2 = SP.claim(player, "free", 1)
	local c3, why3 = SP.claim(player, "paid", 1)
	local c4, why4 = SP.claim(player, "free", 6)
	local eggs0 = #PlayerProfile.getEggs(player)
	local c5 = SP.claim(player, "free", 5)
	check("시즌 받기: 1칸 O · 두 번 X · 유료 줄 not_premium · 6칸 not_reached · 5칸 알 +1", c1 and not c2 and why2 == "claimed" and not c3 and why3 == "not_premium" and not c4 and why4 == "not_reached"
		and c5 and #PlayerProfile.getEggs(player) == eggs0 + 1, ("%s · %s · %s · 알 %d → %d"):format(tostring(why2), tostring(why3), tostring(why4), eggs0, #PlayerProfile.getEggs(player)))
	Data.products.season_premium.productId = 9002
	MS.validProducts.season_premium = true
	MS.processReceipt({ PlayerId = 77, ProductId = 9002, PurchaseId = "P-9", CurrencySpent = 399 }, deps)
	local c6 = SP.claim(player, "paid", 1)
	check("유료 줄 구매 뒤 받기", s.seasonPass.premium and c6)
	local okPrem, whyPrem = MS.promptProduct(player, "season_premium")
	check("이번 시즌 유료 줄 가진 채 다시 구매 창 = owned", not okPrem and whyPrem == "owned", tostring(whyPrem))
	local saved2 = Season.rows.paid[2]
	Season.rows.paid[2] = { gold = 100 }
	local cBad, whyBad = SP.claim(player, "paid", 2)
	Season.rows.paid[2] = { egg = 1 }
	local cBad2 = SP.claim(player, "paid", 2)
	Season.rows.paid[2] = saved2
	check("유료 줄 데이터에 골드 · 알이 들어가도 받기에서 막힘(리뷰 중요 2)", not cBad and not cBad2 and not s.seasonPass.claimedPaid["2"], tostring(whyBad))
	local season0 = s.seasonPass.season
	s.seasonPass.season = season0 - 1 -- 지난 시즌 기록
	SP.ensure(player)
	check("시즌 넘김: 경험치 0 · 받음 · 유료 초기화", s.seasonPass.season == season0 and qs.currencies.passExp == 0 and not s.seasonPass.premium and next(s.seasonPass.claimedFree) == nil)

	-- ⑥-2 QUEUE-ALL9A: 주말 2배(지급 입구 QuestService.grant 한 곳 · 주간 = 1배) · 개발 덮어쓰기 = Studio만 · 보너스 칸(41칸부터 · 같은 받음 표)
	check("weekend on(Studio) 받아들임", SP.setWeekendOverride("on") and SP.weekend() == true)
	local e0 = qs.currencies.passExp
	QuestService.grant(player, { passExp = 20 }, "daily")
	QuestService.grant(player, { passExp = 10 }, "login")
	QuestService.grant(player, { passExp = 50 }, "chest")
	QuestService.grant(player, { passExp = 100 }, "weekly")
	check("주말: 일간 20 → 40 · 접속 10 → 20 · 상자 50 → 100 · 주간 100 → 100", qs.currencies.passExp - e0 == 40 + 20 + 100 + 100, tostring(qs.currencies.passExp - e0))
	SP.setWeekendOverride("off")
	local e1 = qs.currencies.passExp
	QuestService.grant(player, { passExp = 20 }, "daily")
	QuestService.grant(player, { passExp = 20 })
	check("weekend off: 일간 20 그대로 · 출처 없는 지급 = 1배", qs.currencies.passExp - e1 == 40)
	SP.setWeekendOverride("on")
	releaseMode = true
	local rejected = not SP.setWeekendOverride("on")
	local wedNoon = 1790000000 - (1790000000 - 4 * 86400) % (7 * 86400) + 2 * 86400 + 12 * 3600 -- 수요일 12:00 UTC
	check("출시 설정(IsStudio false): /gg weekend 거절 · 남은 덮어쓰기도 안 읽음(수요일 = 1배)", rejected and SP.weekend(wedNoon) == false and SP.passExpMultiplier("daily", wedNoon) == 1)
	releaseMode = false
	SP.setWeekendOverride("auto")
	qs.currencies.passExp = Season.tiers * Season.expPerTier + Season.expPerTier * 2 + 5
	local shard0 = qs.currencies.sparkleShard
	local b1 = SP.claim(player, "free", 41)
	local b2 = SP.claim(player, "free", 42)
	local b3, why3b = SP.claim(player, "free", 43)
	local b4, why4b = SP.claim(player, "free", 41)
	check("보너스 칸: 41 · 42 O(무료 = 토큰 1씩 - QUEUE-ALL9B 보완 5-1) · 43 not_reached · 41 다시 claimed · 받음 키 문자열", b1 and b2 and not b3 and why3b == "not_reached" and not b4 and why4b == "claimed"
		and qs.currencies.sparkleShard == shard0 + 2 * Season.bonus.free.sparkleShard and s.seasonPass.claimedFree["41"] == true, ("%s · %s"):format(tostring(why3b), tostring(why4b)))
	local v = SP.view(player)
	check("view: reach 42 · bonus 표 · weekend 표", v.reach == 42 and v.bonus.paid.sparkleShard == Season.bonus.paid.sparkleShard and v.bonusCap == Season.bonusCap and type(v.weekend.active) == "boolean" and v.tier == Season.tiers)

	-- QUEUE-ALL9B 4-6 중간 구매 소급: 유료 줄 일괄 받기(도달 40 + 보너스 2) · 다시 누르면 0
	s.seasonPass.premium = true
	s.seasonPass.claimedPaid = {}
	local got1 = SP.claimAll(player, "paid")
	local got2, why2 = SP.claimAll(player, "paid")
	check("4-6 유료 줄 일괄 받기 = 도달 칸 전부(40 + 보너스 2) · 다시 = 0", got1 == Season.tiers + 2 and got2 == 0 and s.seasonPass.claimedPaid["40"] == true and s.seasonPass.claimedPaid["42"] == true,
		("%d · %d(%s)"):format(got1, got2, tostring(why2)))
	-- QUEUE-ALL9B 4-8 칸 건너뛰기: 영수증 → 칸 + 건너뛴 칸 표시 · 무료 줄 성장 재화 → 토큰 · 상한 넘는 영수증 = 토큰 환산 · 저장 실패 = 되돌림
	qs.currencies.passExp = 3 * Season.expPerTier + 10
	s.seasonPass.claimedFree, s.seasonPass.skipBought, s.seasonPass.skipTiers = {}, 0, {}
	Data.products.pass_skip5.productId, Data.products.pass_skip1.productId = 9105, 9101
	MS.validProducts.pass_skip5, MS.validProducts.pass_skip1 = true, true
	local rs = MS.processReceipt({ PlayerId = 77, ProductId = 9105, PurchaseId = "P-SKIP5", CurrencySpent = 99 }, deps)
	local gold0 = p.gold
	local shardS = qs.currencies.sparkleShard
	local c4 = SP.claim(player, "free", 4) -- 건너뛴 칸(4 ~ 8)
	check("4-8 건너뛰기 5칸: 도달 3 → 8 · 4 ~ 8칸 표시 · 4칸 무료(골드 + 강화석) = 토큰 1 · 골드 그대로", tostring(rs):find("PurchaseGranted") ~= nil and s.seasonPass.skipBought == 5
		and s.seasonPass.skipTiers["4"] and s.seasonPass.skipTiers["8"] and not s.seasonPass.skipTiers["3"] and c4 and p.gold == gold0 and qs.currencies.sparkleShard == shardS + 1, ("산 칸 %d"):format(s.seasonPass.skipBought))
	local eggs0 = #PlayerProfile.getEggs(player)
	local c5, w5 = SP.claim(player, "free", 5) -- 알 + 골드 → 토큰 3
	check("4-8 건너뛴 5칸(알 + 골드) = 토큰 3 · 알 안 늚(유료 랜덤 0)", c5 and qs.currencies.sparkleShard == shardS + 4 and #PlayerProfile.getEggs(player) == eggs0,
		("%s · 토큰 +%d · 알 %d → %d"):format(tostring(w5), qs.currencies.sparkleShard - shardS, eggs0, #PlayerProfile.getEggs(player)))
	s.seasonPass.skipBought = Season.skip.capPerSeason - 2
	local shardO = qs.currencies.sparkleShard
	local okPrompt, whyPrompt = MS.promptProduct(player, "pass_skip5")
	local ro = MS.processReceipt({ PlayerId = 77, ProductId = 9105, PurchaseId = "P-SKIPOVER", CurrencySpent = 99 }, deps)
	check("4-8 상한(남은 2칸)에 5칸: 프롬프트 거부 skip_cap · 영수증 = 토큰 환산(칸 안 오름)", not okPrompt and whyPrompt == "skip_cap" and tostring(ro):find("PurchaseGranted") ~= nil
		and qs.currencies.sparkleShard == shardO + Data.tokenPrice(99) and s.seasonPass.skipBought == Season.skip.capPerSeason - 2)
	local exp1 = qs.currencies.passExp
	saveResult = false
	MS.processReceipt({ PlayerId = 77, ProductId = 9101, PurchaseId = "P-SKIPFAIL", CurrencySpent = 25 }, deps)
	saveResult = true
	check("4-8 저장 실패 = 칸 · 산 칸 되돌림(재시도가 다시 준다)", qs.currencies.passExp == exp1 and s.seasonPass.skipBought == Season.skip.capPerSeason - 2)
	-- QUEUE-ALL9C 0-1(ALL9B 리뷰): 되돌리기 전에 경험치가 늘어도(저장 대기 중 사냥) 되돌림 = applySkip이 표시한 칸만 지운다
	s.seasonPass.skipBought, s.seasonPass.skipTiers = 0, {}
	qs.currencies.passExp = 3 * Season.expPerTier
	SP.applySkip(player, 2) -- 4 · 5칸 표시 · 도달 5
	qs.currencies.passExp += 4 * Season.expPerTier -- 되돌리기 전 사냥으로 4칸 더
	SP.revertSkip(player, 2)
	check("ALL9B 리뷰: 칸 건너뛰기 되돌림 = 표시한 칸(4 · 5)만 지움 · 경험치 2칸분만 뺌", next(s.seasonPass.skipTiers) == nil and qs.currencies.passExp == 7 * Season.expPerTier and s.seasonPass.skipBought == 0, -- 3 + 2(건너뛰기) + 4(사냥) − 2(되돌림)
		("남은 표시 %s · 경험치 %d"):format(tostring(next(s.seasonPass.skipTiers)), qs.currencies.passExp))
	-- QUEUE-ALL9C 0-1(ALL9B 리뷰): 토큰 구매 지급 실패 → 토큰 되돌림 + 재화 칸 동기(syncWallet)
	local QS = MODS.QuestService
	local realSync, realApply, synced = QS.syncWallet, MS.applyReward, 0
	QS.syncWallet = function(...) synced += 1; return realSync(...) end
	MS.applyReward = function() return false, "test_fail" end
	MS.validProducts.theme_jelly = true
	s.cosmetics.themes.jelly = nil
	qs.currencies.sparkleShard = 9999
	local rf, wrf = MS.buyWithTokens(player, "theme_jelly")
	MS.applyReward, QS.syncWallet = realApply, realSync
	check("ALL9B 리뷰: 토큰 구매 지급 실패 = 토큰 전액 되돌림 + syncWallet 호출", not rf and wrf == "test_fail" and qs.currencies.sparkleShard == 9999 and synced >= 1, ("토큰 %d · sync %d"):format(qs.currencies.sparkleShard, synced))
	-- QUEUE-ALL9B 4-4 할인: 꺼짐 = 정가만 · 켜짐 = 299만 프롬프트
	Data.products.season_premium_sale.productId = 9106
	MS.validProducts.season_premium_sale = true
	s.seasonPass.premium = false
	local okSale, whySale = MS.promptProduct(player, "season_premium_sale")
	Season.saleActive = true
	local okFull, whyFull = MS.promptProduct(player, "season_premium")
	local okSale2 = MS.promptProduct(player, "season_premium_sale")
	Season.saleActive = false
	check("4-4 할인 꺼짐 = 299 거부 · 켜짐 = 399 거부 · 299 열림", not okSale and whySale == "not_active" and not okFull and whyFull == "not_active" and okSale2)
	Data.products.pass_skip5.productId, Data.products.pass_skip1.productId, Data.products.season_premium_sale.productId = 0, 0, 0
	-- 시즌 경계: 건너뛰기 기록 초기화
	s.seasonPass.season = s.seasonPass.season - 1
	SP.ensure(player)
	check("시즌 경계: 산 칸 · 건너뛴 칸 표시 · 받음 초기화", s.seasonPass.skipBought == 0 and next(s.seasonPass.skipTiers) == nil and next(s.seasonPass.claimedFree) == nil)
	-- ⑦ 선물함: 온라인 바로 · 오프라인 대기열 → 접속 때 옮김 · 치장만 · 받기
	local GS = MODS.GiftService
	local r1 = GS.send(77, "gliderSkin", "kite", "알파 감사", "ops")
	local r2 = GS.send(77, "gold", "100", "", "ops")
	local r3 = GS.send(77, "sparkleShard", "-5", "", "ops")
	local r4 = GS.send(55, "sparkleShard", "30", "", "ops")
	check("선물 보내기: 온라인 = 선물함 · 골드 거부 · 음수 거부 · 오프라인 = 대기열", r1:find("delivered_online") ~= nil and r2:find("rejected") ~= nil and r3:find("rejected") ~= nil and r4:find("queued") ~= nil,
		("%s | %s | %s | %s"):format(r1, r2, r3, r4))
	local got = GS.claim(player, "all")
	check("선물 받기 전부: 글라이더 소유 · 선물함 비움", got == 1 and s.cosmetics.gliderSkins.kite == true and #s.mailbox.gifts == 0)
	-- 리뷰 중요 1: 대기열 옮김 = 저장 성공 뒤에만 비운다(저장 실패 = 대기열 그대로 · 두 번 옮겨도 선물함 id 중복 없음)
	local queueStore = DS[Data.gifts.storeName]
	queueStore.u77 = { { id = "Q1", kind = "sparkleShard", amount = 5, from = "ops", note = "", at = 0 } }
	local ImmediateSave = MODS.ImmediateSave
	local realFlush = ImmediateSave.flush
	ImmediateSave.flush = function() return false end
	local realSpawn = task.spawn
	task.spawn = function(fn, ...) fn(...) end
	GS.onLoaded(player)
	local keptOnFail = queueStore.u77 and #queueStore.u77 == 1 and #s.mailbox.gifts == 1
	ImmediateSave.flush = function() return true end
	GS.onLoaded(player)
	ImmediateSave.flush = realFlush
	task.spawn = realSpawn
	check("선물 대기열: 저장 실패 → 대기열 남김 · 성공 → 비움 · 선물함 1건(중복 없음)", keptOnFail and #queueStore.u77 == 0 and #s.mailbox.gifts == 1,
		("대기열 %d · 선물함 %d"):format(queueStore.u77 and #queueStore.u77 or -1, #s.mailbox.gifts))

	-- ⑦-1 QUEUE-ALL5 A1(v62): 받은 선물 id 기록 - 대기열 지우기 실패 뒤 재접속 · 서버 이동 · 동시 받기에서 재지급 없음
	do
		local function deep(v)
			if type(v) ~= "table" then return v end
			local c = {}
			for k, x in pairs(v) do c[k] = deep(x) end
			return c
		end
		task.spawn = function(fn, ...) fn(...) end
		GS.claim(player, "all") -- 앞 검사의 Q1 정리
		local shardStart = qs.currencies.sparkleShard
		queueStore.u77 = { { id = "Q2", kind = "sparkleShard", amount = 7, from = "ops", note = "", at = 0 } }
		ImmediateSave.flush = function() return true end
		dsFailUpdate = true -- 옮김 저장은 성공 · 대기열 지우기 실패
		GS.onLoaded(player)
		dsFailUpdate = false
		local movedButQueued = #s.mailbox.gifts == 1 and #queueStore.u77 == 1
		local got1 = GS.claim(player, "Q2")
		local afterClaim = qs.currencies.sparkleShard
		-- 재접속(같은 서버): 대기열에 남은 Q2를 다시 읽음
		GS.onLoaded(player)
		local reAdded = #s.mailbox.gifts
		local got2 = GS.claim(player, "all")
		check("재접속: 대기열 지우기 실패 뒤 다시 옮겨도 받은 선물 재지급 없음 · 대기열 비움", movedButQueued and got1 == 1 and reAdded == 0 and got2 == 0
			and qs.currencies.sparkleShard == afterClaim and afterClaim == shardStart + 7 and #queueStore.u77 == 0,
			("옮김 %s · 받음 %d · 다시 옮김 %d · 다시 받음 %d · 조각 %d → %d"):format(tostring(movedButQueued), got1, reAdded, got2, shardStart, qs.currencies.sparkleShard))
		-- 서버 이동: 저장된 프로필(왕복 사본)을 다른 서버의 새 Player가 읽음 · 대기열에 같은 id가 다시 있음(지우기 실패가 남긴 상태)
		queueStore.u77 = { { id = "Q2", kind = "sparkleShard", amount = 7, from = "ops", note = "", at = 0 } }
		local saved = SaveSystem.migrate(deep(PlayerProfile.getProfile(player)))
		local attrs2 = {}
		local player2 = setmetatable({ Name = "Buyer@B", UserId = 77, Parent = true }, { __index = function(_, k)
			if k == "SetAttribute" then return function(_, n, v) attrs2[n] = v end end
			if k == "GetAttribute" then return function(_, n) return attrs2[n] end end
			if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
			if k == "IsA" then return function() return false end end
			if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
			return nil
		end })
		PlayerProfile.init(player2, saved)
		local s2 = PlayerProfile.getMonetizationState(player2)
		local qs2 = PlayerProfile.getQuestState(player2)
		local shardB = qs2.currencies.sparkleShard
		GS.onLoaded(player2)
		local gotB = GS.claim(player2, "all")
		check("서버 이동: 왕복 저장의 claimedIds로 다른 서버에서도 재지급 없음", table.find(s2.mailbox.claimedIds, "Q2") ~= nil and #s2.mailbox.gifts == 0 and gotB == 0
			and qs2.currencies.sparkleShard == shardB and #queueStore.u77 == 0, ("기록 %d · 선물함 %d · 받음 %d"):format(#s2.mailbox.claimedIds, #s2.mailbox.gifts, gotB))
		-- 동시 받기: 같은 id가 선물함에 두 줄(옛 중복) + 같은 id를 두 번 연달아 요청 + "all"
		local shardC = qs.currencies.sparkleShard
		table.insert(s.mailbox.gifts, { id = "Q3", kind = "sparkleShard", amount = 4, from = "ops", note = "", at = 0 })
		table.insert(s.mailbox.gifts, { id = "Q3", kind = "sparkleShard", amount = 4, from = "ops", note = "", at = 0 })
		local c1 = GS.claim(player, "Q3")
		local c2 = GS.claim(player, "Q3")
		table.insert(s.mailbox.gifts, { id = "Q3", kind = "sparkleShard", amount = 4, from = "ops", note = "", at = 0 })
		local c3 = GS.claim(player, "all")
		check("동시 받기: 같은 id 두 줄 · 연타 · all = 한 번만 지급", c1 == 1 and c2 == 0 and c3 == 0 and qs.currencies.sparkleShard == shardC + 4 and #s.mailbox.gifts == 0,
			("%d · %d · %d · 조각 +%d"):format(c1, c2, c3, qs.currencies.sparkleShard - shardC))
		-- 정리 규칙: 최근 claimedIdsKeep개만
		local keep = Data.gifts.claimedIdsKeep
		for i = 1, keep + 5 do
			table.insert(s.mailbox.gifts, { id = "K" .. i, kind = "sparkleShard", amount = 1, from = "ops", note = "", at = 0 })
		end
		GS.claim(player, "all")
		check(("받은 id 기록 = 최근 %d개(오래된 것부터 버림)"):format(keep), #s.mailbox.claimedIds == keep and s.mailbox.claimedIds[keep] == "K" .. (keep + 5)
			and table.find(s.mailbox.claimedIds, "Q2") == nil, ("%d개 · 끝 %s"):format(#s.mailbox.claimedIds, tostring(s.mailbox.claimedIds[#s.mailbox.claimedIds])))
		local v61 = SaveSystem.migrate({})
		v61.version = 61
		v61.mailbox = { gifts = { { id = "OLD", kind = "sparkleShard", amount = 1 } }, seq = 3 }
		local m62 = SaveSystem.migrate(v61)
		check("v61 표본 → v62: claimedIds 빈 목록 · 선물 보존", m62.version >= 62 and type(m62.mailbox.claimedIds) == "table" and #m62.mailbox.claimedIds == 0 and m62.mailbox.gifts[1].id == "OLD")
		ImmediateSave.flush = realFlush
		task.spawn = realSpawn
	end

	-- ⑦-2 QUEUE-B1 결정 8 · 9: 이미 가진 것 영수증 = 조각 환산 · 저장 실패 = 조각 되돌림 · 지난 시즌 유료 줄 영수증 = 환산 · 같은 실패 줄 한 번 · 손상 표 복구
	Data.products.theme_ember.productId = 9001
	local shard0 = qs.currencies.sparkleShard
	saveResult = false
	local r1 = MS.processReceipt({ PlayerId = 77, ProductId = 9001, PurchaseId = "P-OWN", CurrencySpent = 199 }, deps)
	local afterFail = qs.currencies.sparkleShard
	saveResult = true
	local r2 = MS.processReceipt({ PlayerId = 77, ProductId = 9001, PurchaseId = "P-OWN", CurrencySpent = 199 }, deps)
	check("이미 가진 테마 영수증 = 토큰가 환산 · 저장 실패 때 되돌림 · 재시도 Granted", tostring(r1):find("NotProcessedYet") ~= nil and afterFail == shard0
		and tostring(r2):find("PurchaseGranted") ~= nil and qs.currencies.sparkleShard == shard0 + Data.tokenPrice(Data.products.theme_ember.robux), ("%d → %d → %d"):format(shard0, afterFail, qs.currencies.sparkleShard))
	s.seasonPass.premium = false
	s.seasonPass.promptSeason = s.seasonPass.season - 1 -- 지난 시즌에 연 구매 창
	local shard1 = qs.currencies.sparkleShard
	MS.processReceipt({ PlayerId = 77, ProductId = 9002, PurchaseId = "P-OLDSEASON", CurrencySpent = 399 }, deps)
	check("지난 시즌에 연 유료 줄 영수증 = 이번 시즌 유료 안 켜고 조각 환산", not s.seasonPass.premium and qs.currencies.sparkleShard == shard1 + Data.tokenPrice(Data.products.season_premium.robux) and s.seasonPass.promptSeason == nil)
	local logN = #s.purchases.log
	MS.processReceipt({ PlayerId = 77, ProductId = 55555, PurchaseId = "P-UNK" }, deps)
	MS.processReceipt({ PlayerId = 77, ProductId = 55555, PurchaseId = "P-UNK" }, deps)
	check("알 수 없는 상품 재시도 = 기록 한 줄만", #s.purchases.log == logN + 1)
	local pr = PlayerProfile.getProfile(player)
	local keepCos = pr.cosmetics
	pr.cosmetics = { themes = "깨짐" }
	local fixed = PlayerProfile.getMonetizationState(player)
	check("손상된 치장 칸 = 안쪽 표까지 복구(로드 막지 않음)", type(fixed.cosmetics.themes) == "table" and type(fixed.cosmetics.equipped) == "table")
	pr.cosmetics = keepCos

	-- ⑧ 저장 이관 v56: 빈 표 · v55 옛 표본(필드 없음) · 문자열 키 왕복
	-- QUEUE-ALL4 G: 기대 버전 = 지금 SaveConfig.saveVersion(옛 리터럴 56 - 이후 v57 ~ v61 이관이 더 붙어 끝 버전이 올라갔다. 이 검사의 뜻은 v56 칸이 끝까지 살아남는가)
	local LATEST = MODS.SaveConfig.saveVersion
	local fresh = SaveSystem.migrate({})
	check("migrate({}) → 최신(v" .. tostring(LATEST) .. ") · v56 새 칸 모양", fresh.version == LATEST and type(fresh.cosmetics.themes) == "table" and type(fresh.mailbox.gifts) == "table" and fresh.seasonPass.premium == false
		and type(fresh.purchases.receipts) == "table" and type(fresh.purchases.log) == "table")
	local old = SaveSystem.migrate({})
	old.version = 55
	old.cosmetics, old.mailbox, old.seasonPass = nil, nil, nil
	old.purchases.receipts, old.purchases.log = nil, nil
	old.gamepasses = nil
	local m = SaveSystem.migrate(old)
	check("v55 옛 표본 → 최신 · v56 빈 칸 채움", m.version == LATEST and m.cosmetics and m.mailbox and m.seasonPass and m.purchases.receipts and m.purchases.log and type(m.gamepasses) == "table")
	local snap = PlayerProfile.snapshotForDevTools(player)
	check("백업 대상(snapshotForDevTools)에 새 칸", snap.cosmetics and snap.mailbox and snap.seasonPass and snap.receipts and snap.purchaseLog and snap.gamepasses)
	-- 게임패스 효과: 가방 +20 · 귀환 쿨 × 0.5
	local cap0 = MODS.InventorySync.capacity(p)
	s.gamepasses.bagExpand = true
	local cap1 = MODS.InventorySync.capacity(p)
	s.gamepasses.bagExpand = nil
	check(("가방 확장 패스 +%d칸"):format(Data.gamePasses.bagExpand.bonusSlots), cap1 - cap0 == Data.gamePasses.bagExpand.bonusSlots, ("%d → %d"):format(cap0, cap1))
	-- ══ QUEUE-ALL9C 1-6 스타터 팩 · 가방 출처 · 순차 공개 ══
	Data.releaseStageNow = RELEASE_NOW
	local fresh69 = SaveSystem.migrate({})
	check("v69 새 계정 = purchases.bagSources {} · shopViews 0", type(fresh69.purchases.bagSources) == "table" and next(fresh69.purchases.bagSources) == nil and fresh69.purchases.shopViews == 0)
	local old68 = SaveSystem.migrate({})
	old68.version = 68
	old68.purchases.bagSources, old68.purchases.shopViews = nil, nil
	local m69 = SaveSystem.migrate(old68)
	check("v68 → v69 빈 칸 채움 · 멱등", m69.version == LATEST and type(m69.purchases.bagSources) == "table" and m69.purchases.shopViews == 0 and SaveSystem.migrate(m69).purchases.shopViews == 0)
	local okStarter, whyStarter = Mon.checkProduct(Data, "starter_pack", Data.products.starter_pack, Cos)
	check("스타터 팩 등록 통과(가방 출처 · 스타터 전용 치장 2)", okStarter, table.concat(whyStarter or {}, " / "))
	local leak = Mon.checkProduct(Data, "leak", { productId = 1, robux = 49, grants = { { kind = "cosmeticItem", id = "starterEdge" } } }, Cos)
	local badBag = Mon.checkProduct(Data, "badBag", { productId = 1, robux = 49, grants = { { kind = "bagSlots", id = "nope" } } }, Cos)
	check("스타터 전용 치장을 다른 상품에 넣으면 거부 · 모르는 가방 출처 거부", not leak and not badBag)
	check("스타터 전용 치장 토큰 · 선물 불가(tokenBlocked = starter_only)", Mon.tokenBlocked(Cos, "cosmeticItem", "starterEdge") == "starter_only" and Mon.tokenBlocked(Cos, "cosmeticTheme", "starterStar") == "starter_only")
	-- 가방 칸: 기본 35 · 패스 + 20 · 스타터 + 20 = 75(출처별 한 번)
	s.gamepasses.bagExpand = nil
	p.purchases.bagSources = {}
	local base = MODS.InventorySync.capacity(p)
	s.gamepasses.bagExpand = true
	local withPass = MODS.InventorySync.capacity(p)
	p.purchases.bagSources.starter = true
	local both = MODS.InventorySync.capacity(p)
	s.gamepasses.bagExpand = nil
	local starterOnly = MODS.InventorySync.capacity(p)
	check("가방 칸 기본 35 · 패스 55 · 스타터만 55 · 둘 다 75(최대)", base == 35 and withPass == 55 and starterOnly == 55 and both == 75 and Data.bagMaxSlots == 75, ("%d · %d · %d · %d"):format(base, withPass, starterOnly, both))
	p.purchases.bagSources = {}
	-- 스타터 구매(영수증) → 3종 지급 · 다시 = 프롬프트 거부(계정당 1회)
	Data.products.starter_pack.productId = 9201
	MS.validProducts.starter_pack = true
	s.cosmetics.items.starterEdge, s.cosmetics.themes.starterStar = nil, nil
	local rStarter = MS.processReceipt({ PlayerId = 77, ProductId = 9201, PurchaseId = "P-STARTER", CurrencySpent = 199 }, deps)
	local okAgain, whyAgain = MS.promptProduct(player, "starter_pack")
	check("스타터 영수증 = 가방 출처 + 은빛 날 + 별빛 궤적 · 두 번째 프롬프트 owned", tostring(rStarter):find("PurchaseGranted") ~= nil and p.purchases.bagSources.starter == true
		and s.cosmetics.items.starterEdge == true and s.cosmetics.themes.starterStar == true and not okAgain and whyAgain == "owned" and MODS.InventorySync.capacity(p) == 55, ("%s · %s"):format(tostring(rStarter), tostring(whyAgain)))
	Data.products.starter_pack.productId = 0
	p.purchases.bagSources = {}
	-- 순차 공개: 비공개 상품 = 프롬프트 · 토큰 구매 거부(게임패스도)
	Data.products.item_goldenHammer.productId = 9202
	MS.validProducts.item_goldenHammer = true
	local okHidden, whyHidden = MS.promptProduct(player, "item_goldenHammer")
	qs.currencies.sparkleShard = 9999
	local okHiddenTok, whyHiddenTok = MS.buyWithTokens(player, "item_goldenHammer")
	local okSet, whySet = MS.promptPass(player, "nameplateSet")
	Data.products.item_goldenHammer.productId = 0
	check("비공개(2단계) 상품 · 게임패스 = 프롬프트 · 토큰 거부 not_released", not okHidden and whyHidden == "not_released" and not okHiddenTok and whyHiddenTok == "not_released" and not okSet and whySet == "not_released",
		("%s · %s · %s"):format(tostring(whyHidden), tostring(whyHiddenTok), tostring(whySet)))
	check("공개 단계 표: 출시 = 스타터 · 패스 · 모루 · 젤리 · 할로윈 · 드래곤 날개 · 슬라임 · 로켓 · 풍선 · 수정 · 하이파이브 · 펫 왕관 · 편의 5 / 나중 = 황금 망치 · 화로 · 이름표 세트 · 패스 보상 5",
		Mon.isReleased(Data, "starter_pack") and Mon.isReleased(Data, "theme_halloween") and Mon.isReleased(Data, "item_petCrown") and Mon.isReleased(Data, "recallCooldown")
		and not Mon.isReleased(Data, "item_forgeBrazier") and not Mon.isReleased(Data, "nameplateSet") and not Mon.isReleased(Data, "theme_starlight") and not Mon.isReleased(Data, "glider_kite"))
	check("표시 가격: 줍기 79 · 귀환 49 · 이름표 세트 79", Data.gamePasses.pickupRadius.robux == 79 and Data.gamePasses.recallCooldown.robux == 49 and Data.gamePasses.nameplateSet.robux == 79)

end)
if not ok then print("[MON] 에러 " .. tostring(err)) end
-- QUEUE-ALL9C 1-6R 카드 규격 · 묶음 · 이번 주 추천(위 pcall 함수는 지역 변수 상한 200에 닿아 따로)
local ok2, err2 = pcall(function()
	local Data, Mon = MODS.MonetizationData, MODS.Monetization
	local Cos, Season = MODS.CosmeticSlotData, MODS.SeasonPassData
	local RELEASE_NOW = Data.releaseStageNow
	local sumBS = Mon.bundleComponentSum(Data, "bundle_blacksmith")
	check("묶음 구성품 합계: 대장장이 = 모루 199 + 슬라임 149 + 황금 망치 99 = 447 · 단품 · 스타터 = 묶음 아님", sumBS == 447 and Mon.bundleComponentSum(Data, "theme_anvil") == nil
		and Mon.bundleComponentSum(Data, "starter_pack") == nil, tostring(sumBS))
	local _, _, _, warnCat = Mon.checkCatalog(Data, Cos, Season)
	local bsWarn = false
	for _, line in ipairs(warnCat) do
		bsWarn = bsWarn or line:find("bundle_blacksmith") ~= nil
	end
	local fake = table.clone(Data.products)
	fake.bundle_test = { productId = 0, robux = 300, grants = { { kind = "cosmeticTheme", id = "anvil" }, { kind = "cosmeticItem", id = "goldenHammer" } } } -- 199 + 99 = 298 ≤ 300
	local okBad, whyBad = Mon.checkCatalog(setmetatable({ products = fake }, { __index = Data }), Cos, nil)
	fake.bundle_test.robux = 249
	local okGood = Mon.checkCatalog(setmetatable({ products = fake }, { __index = Data }), Cos, nil)
	check("등록 검사: 묶음 가격 ≥ 구성품 합계 = 거부 · 미만 = 통과 · 제안 자리(대장장이 499 ≥ 447) = 경고", not okBad and okGood and bsWarn, table.concat(whyBad, " / "))
	check("가격급 띠: 49 · 79 · 99 기본 / 149 · 199 특별 / 399 · 499 대표", Mon.priceBand(Data, 49) == "basic" and Mon.priceBand(Data, 79) == "basic" and Mon.priceBand(Data, 99) == "basic"
		and Mon.priceBand(Data, 149) == "special" and Mon.priceBand(Data, 199) == "special" and Mon.priceBand(Data, 399) == "flagship" and Mon.priceBand(Data, 499) == "flagship")
	Data.releaseStageNow = RELEASE_NOW
	local d1 = Data.releaseStageStartUtc[1]
	check("NEW = 공개 날부터 14일(13.9일 O · 14일 X · 공개 전 X · 비공개 단계 X)", Mon.isNew(Data, "theme_anvil", d1 + 13.9 * 86400) and not Mon.isNew(Data, "theme_anvil", d1 + 14 * 86400)
		and not Mon.isNew(Data, "theme_anvil", d1 - 1) and not Mon.isNew(Data, "theme_starlight", d1 + 86400))
	local monday = Data.weeklyFeatured.epochUtc + 40 * 604800
	local wkA, nextA = Mon.weeklyFeatured(Data, monday - 1)
	local wkB, nextB = Mon.weeklyFeatured(Data, monday)
	local wkC = Mon.weeklyFeatured(Data, monday + 6 * 86400)
	local okDistinct = #wkB == 4 and table.concat(wkA, ",") ~= table.concat(wkB, ",") and table.concat(wkB, ",") == table.concat(wkC, ",")
	local onlyReleased = Mon.weeklyFeatured(Data, monday, function(key) return Mon.isReleased(Data, key) end)
	local allReleased = #onlyReleased == 4
	for _, key in ipairs(onlyReleased) do
		allReleased = allReleased and Mon.isReleased(Data, key)
	end
	check("이번 주 추천 4개: UTC 월요일 00:00에 바뀜 · 한 주 안은 같음 · 다음 교체 = 다음 월요일 · 비공개 거르기", okDistinct and nextA == monday and nextB == monday + 604800 and allReleased,
		table.concat(wkB, ",") .. " | " .. table.concat(onlyReleased, ","))
	for _, key in ipairs(Data.weeklyFeatured.pool) do
		assert(Data.products[key], "weeklyFeatured 후보에 없는 상품 " .. key)
	end
end)
if not ok2 then print("[MON] 에러 " .. tostring(err2)) end
-- QUEUE-ALL10 0-1(AUDIT1 즉시-1): 영수증 저장 실패 주입 × 상품 종류 → 최종 지급 정확히 1회(같은 서버 재시도 · 자동저장 끼어듦 · 다른 서버 재접속)
--   "DataStore" = stored(성공한 저장의 깊은 사본) · 다른 서버 = stored를 새 가짜 Player에 로드(같은 UserId) · 자동저장 = 실패 사이에 성공하는 저장(옛 결함: 영수증 없는 지급이 남음)
local ok3, err3 = pcall(function()
	local SaveSystem, PlayerProfile, QuestService = MODS.SaveSystem, MODS.PlayerProfile, MODS.QuestService
	local Data, Mon, MS = MODS.MonetizationData, MODS.Monetization, MODS.MonetizationService
	local SeasonData = MODS.SeasonPassData
	local function deep(t)
		if type(t) ~= "table" then return t end
		local o = {}
		for k, v in pairs(t) do o[k] = deep(v) end
		return o
	end
	local function makePlayer(uid)
		local at = {}
		return setmetatable({ Name = "Buyer" .. uid, UserId = uid, Parent = true }, { __index = function(_, k)
			if k == "SetAttribute" then return function(_, n, v) at[n] = v end end
			if k == "GetAttribute" then return function(_, n) return at[n] end end
			if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
			if k == "IsA" then return function() return false end end
			if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
			return nil
		end })
	end
	local function load(uid, prof)
		local pl = makePlayer(uid)
		PLAYERS[uid] = pl
		PlayerProfile.init(pl, prof)
		QuestService.onLoaded(pl)
		return pl
	end
	local KEYS = { "theme_frost", "bundle_blacksmith", "bundle_owned", "season_premium", "pass_skip5", "starter_pack" }
	local ids = { theme_frost = 9501, bundle_blacksmith = 9502, bundle_owned = 9502, season_premium = 9503, pass_skip5 = 9504, starter_pack = 9505 }
	for key, id in pairs(ids) do
		if Data.products[key] then
			Data.products[key].productId = id
			MS.validProducts[key] = true
		end
	end
	-- 지급 결과 요약(비교용): 치장 소유 · 유료 줄 · 가방 출처 · 토큰 · 건너뛴 칸 · 영수증
	local function snap(pl)
		local s, q = PlayerProfile.getMonetizationState(pl), PlayerProfile.getQuestState(pl)
		return { frost = s.cosmetics.themes.frost == true, anvil = s.cosmetics.themes.anvil == true, slime = s.cosmetics.gliderSkins.slimeParachute == true,
			hammer = s.cosmetics.items.goldenHammer == true, premium = s.seasonPass.premium == true, starter = s.purchases.bagSources.starter == true,
			edge = s.cosmetics.items.starterEdge == true, star = s.cosmetics.themes.starterStar == true, shard = q.currencies.sparkleShard or 0,
			skip = s.seasonPass.skipBought or 0, exp = q.currencies.passExp or 0, receipts = #s.purchases.receipts }
	end
	local per = SeasonData.expPerTier
	local function expected(key, b)
		local e = table.clone(b)
		if key == "theme_frost" then e.frost = true
		elseif key == "bundle_blacksmith" then e.anvil, e.slime, e.hammer = true, true, true
		elseif key == "bundle_owned" then e.shard = b.shard + (Mon.tokenPriceForRobux(Data, Data.products.bundle_blacksmith.robux) or 0)
		elseif key == "season_premium" then e.premium = true
		elseif key == "pass_skip5" then e.skip, e.exp = b.skip + 5, b.exp + 5 * per
		elseif key == "starter_pack" then e.starter, e.edge, e.star = true, true, true end
		e.receipts = b.receipts + 1
		return e
	end
	local function same(a, b)
		for k, v in pairs(a) do if b[k] ~= v then return false, k end end
		return true
	end
	local PATTERNS = { "ok", "fail1", "fail2", "fail1_autosave", "fail1_rejoin", "fail1_autosave_rejoin", "fail1_crash_rejoin", "granted_recall_rejoin", "fail1_yieldsave_crash_rejoin", "fail1_yieldsave_rejoin" }
	local rows, allOk, n = {}, true, 0
	for ki, key in ipairs(KEYS) do
		for pi, pat in ipairs(PATTERNS) do
			n += 1
			local uid = 1000 + ki * 100 + pi
			local prof = SaveSystem.migrate({})
			prof.tutorial = prof.tutorial or {}
			prof.tutorial.completed = true
			local pl = load(uid, prof)
			PlayerProfile.setClassId(pl, "bow")
			local s = PlayerProfile.getMonetizationState(pl)
			if key == "bundle_blacksmith" then s.cosmetics.themes.anvil = true end -- 1개만 가진 묶음 = 나머지 2개 지급(환산 아님)
			if key == "bundle_owned" then s.cosmetics.themes.anvil, s.cosmetics.gliderSkins.slimeParachute, s.cosmetics.items.goldenHammer = true, true, true end
			local stored = deep(PlayerProfile.getProfile(pl)) -- 구매 전 저장본
			local fails = (pat == "ok" or pat == "granted_recall_rejoin") and 0 or (pat == "fail2" and 2 or 1)
			local deps = { save = function(p2)
				if fails > 0 and pat:find("yieldsave") then stored = deep(PlayerProfile.getProfile(p2)) end -- 리뷰 빈틈 ①: 저장 대기 중 자동저장이 지급 + 영수증을 실제로 쓰고 flush만 실패
				if fails > 0 then fails -= 1; return false end
				stored = deep(PlayerProfile.getProfile(p2)); return true
			end }
			local before = snap(pl)
			local receipt = { PlayerId = uid, ProductId = ids[key], PurchaseId = "Q-" .. uid, CurrencySpent = Data.products[key == "bundle_owned" and "bundle_blacksmith" or key].robux }
			local results = {}
			for attempt = 1, 6 do
				local d = tostring(MS.processReceipt(receipt, deps))
				table.insert(results, d:match("%.(%w+)$") or d)
				local granted = d:find("PurchaseGranted") ~= nil
				if pat:find("autosave") and not granted then stored = deep(PlayerProfile.getProfile(PLAYERS[uid])) end -- 실패 사이 자동저장(성공)
				if pat:find("rejoin") and attempt == 1 then
					if pat:find("crash") then -- 서버가 저장 없이 죽음 → 마지막 성공 저장본으로 다른 서버
						load(uid, deep(stored))
					else -- 퇴장 저장(성공) 뒤 다른 서버
						stored = deep(PlayerProfile.getProfile(PLAYERS[uid]))
						load(uid, deep(stored))
					end
				elseif granted and attempt >= 2 then
					break
				end
			end
			local final = snap(PLAYERS[uid])
			local exp = expected(key, before)
			local okS, badKey = same(exp, final)
			local storedOk = same(exp, snap(load(uid, deep(stored)))) -- 마지막 저장본도 정확히 1회(재접속 뒤 상태)
			allOk = allOk and okS and storedOk
			if not (okS and storedOk) then table.insert(rows, ("%s/%s 틀림(%s) %s"):format(key, pat, tostring(badKey), table.concat(results, ","))) end
		end
	end
	check(("ALL10 0-1 저장 실패 주입 %d경우(상품 6 × 실패 패턴 10: 정상 · 1회 · 2회 · 자동저장 끼어듦 · 재접속 · 자동저장+재접속 · 서버 죽음 재접속 · 지급 뒤 재호출 · 대기 중 자동저장 후 죽음/퇴장) → 메모리 · 저장본 모두 지급 정확히 1회"):format(n),
		allOk, table.concat(rows, " / "))
	-- 부분 지급 금지: 묶음 두 번째 grant가 실패하면 첫 grant도 되돌림
	local pl = load(2001, SaveSystem.migrate({}))
	local origGrant = MODS.CosmeticService.grant
	MODS.CosmeticService.grant = function(p2, kind, id) if kind == "gliderSkin" then return false, "boom" end return origGrant(p2, kind, id) end
	local d = MS.processReceipt({ PlayerId = 2001, ProductId = 9502, PurchaseId = "Q-PART", CurrencySpent = 499 }, { save = function() return true end })
	MODS.CosmeticService.grant = origGrant
	local s = PlayerProfile.getMonetizationState(pl)
	check("묶음 중간 grant 실패 → 앞 grant(모루)도 되돌림 · 영수증 없음 · NotProcessedYet", tostring(d):find("NotProcessedYet") ~= nil and not s.cosmetics.themes.anvil and not Mon.hasReceipt(s.purchases, "Q-PART"))
	-- 저장 대기 중 장착한 새 치장 → 되돌림 때 장착도 풀림
	local pl2 = load(2002, SaveSystem.migrate({}))
	local s2 = PlayerProfile.getMonetizationState(pl2)
	MS.processReceipt({ PlayerId = 2002, ProductId = 9501, PurchaseId = "Q-EQ", CurrencySpent = 199 }, { save = function() s2.cosmetics.equipped.trail = "frost"; return false end })
	check("저장 대기 중 장착 → 실패 되돌림이 장착도 해제(소유 없는 장착 0)", not s2.cosmetics.themes.frost and s2.cosmetics.equipped.trail == nil)
	-- 리뷰 H1: 환산 토큰 저장 대기 중 토큰 구매 = busy 거절 → 최종 토큰 = 환산 1회분
	local pH = load(2003, SaveSystem.migrate({}))
	local sH, qH = PlayerProfile.getMonetizationState(pH), PlayerProfile.getQuestState(pH)
	sH.cosmetics.themes.anvil, sH.cosmetics.gliderSkins.slimeParachute, sH.cosmetics.items.goldenHammer = true, true, true
	qH.currencies.sparkleShard = 0
	local refundN = Mon.tokenPriceForRobux(Data, 499) or 0
	local busyWhy
	local failH = 1
	local depsH = { save = function() if failH > 0 then failH -= 1; local _, w = MS.handle(pH, "buyTokens", "theme_jelly"); busyWhy = w; return false end return true end }
	local rH = { PlayerId = 2003, ProductId = 9502, PurchaseId = "Q-H1", CurrencySpent = 499 }
	MS.processReceipt(rH, depsH)
	local dH = MS.processReceipt(rH, depsH)
	check("리뷰 H1: 저장 대기 중 토큰 구매 = busy 거절 · 실패 → 재시도 뒤 토큰 = 환산 1회분 · 젤리 미지급", busyWhy == "busy" and tostring(dH):find("PurchaseGranted") ~= nil
		and qH.currencies.sparkleShard == refundN and not sH.cosmetics.themes.jelly and not MS.receiptBusy(pH), ("%s · 토큰 %d/%d"):format(tostring(busyWhy), qH.currencies.sparkleShard, refundN))
	-- 리뷰 M2: A(지난 시즌 유료 줄 = 환산) 저장 대기 중 B(할인 유료 줄) 지급 · 성공 → A 실패 되돌림이 B의 유료 줄을 끄지 않음
	local pM = load(2004, SaveSystem.migrate({}))
	local sM = PlayerProfile.getMonetizationState(pM)
	Data.products.season_premium_sale.productId = 9506
	MS.validProducts.season_premium_sale = true
	sM.seasonPass.promptSeason = -5
	local failM = 1
	local depsM = { save = function()
		if failM > 0 then failM -= 1
			sM.seasonPass.promptSeason = nil
			MS.processReceipt({ PlayerId = 2004, ProductId = 9506, PurchaseId = "Q-M2B", CurrencySpent = 299 }, { save = function() return true end })
			return false
		end
		return true end }
	MS.processReceipt({ PlayerId = 2004, ProductId = 9503, PurchaseId = "Q-M2A", CurrencySpent = 399 }, depsM)
	check("리뷰 M2: 겹친 두 유료 줄 영수증 - A 되돌림 뒤에도 B 유료 줄 유지 · B 영수증 기록", sM.seasonPass.premium == true and Mon.hasReceipt(sM.purchases, "Q-M2B") and not Mon.hasReceipt(sM.purchases, "Q-M2A"))
	Data.products.season_premium_sale.productId = 0
	-- 리뷰 M3: 스타터 저장 대기 중 퇴장(프로필 없음) → 되돌림 오류 없음 · inFlight 풀림(같은 id 다시 = 처리됨)
	local pS = load(2005, SaveSystem.migrate({}))
	local origGP = PlayerProfile.getProfile
	local leaving = false
	PlayerProfile.getProfile = function(p2) if leaving and p2 == pS then return nil end return origGP(p2) end
	local okM3 = pcall(MS.processReceipt, { PlayerId = 2005, ProductId = 9505, PurchaseId = "Q-M3", CurrencySpent = 199 }, { save = function() leaving = true; return false end })
	leaving = false
	PlayerProfile.getProfile = origGP
	local dM3 = MS.processReceipt({ PlayerId = 2005, ProductId = 9505, PurchaseId = "Q-M3", CurrencySpent = 199 }, { save = function() return true end })
	check("리뷰 M3: 저장 대기 중 퇴장 되돌림 = 오류 없음 · 재시도 Granted(inFlight 풀림)", okM3 and tostring(dM3):find("PurchaseGranted") ~= nil and not MS.receiptBusy(pS))
	-- 리뷰 L1: 칸 건너뛰기 두 영수증 겹침 - A 실패 되돌림이 B의 칸 표시를 지우지 않음
	local pK = load(2006, SaveSystem.migrate({}))
	local sK = PlayerProfile.getMonetizationState(pK)
	Data.products.pass_skip1.productId = 9507
	MS.validProducts.pass_skip1 = true
	local failK = 1
	MS.processReceipt({ PlayerId = 2006, ProductId = 9504, PurchaseId = "Q-L1A", CurrencySpent = 99 }, { save = function()
		if failK > 0 then failK -= 1
			MS.processReceipt({ PlayerId = 2006, ProductId = 9507, PurchaseId = "Q-L1B", CurrencySpent = 25 }, { save = function() return true end })
			return false
		end
		return true end })
	local tiers = {}
	for k in pairs(sK.seasonPass.skipTiers) do table.insert(tiers, k) end
	check("리뷰 L1: 겹친 칸 건너뛰기 - A(5칸) 되돌림 뒤 B(1칸) 표시 1개 · skipBought 1", #tiers == 1 and tiers[1] == "6" and sK.seasonPass.skipBought == 1, table.concat(tiers, ","))
	Data.products.pass_skip1.productId = 0
	-- 게임패스: 소유 = Roblox 조회 값(bool) · 두 번 반영해도 가방 칸 한 번
	local p3 = PlayerProfile.getProfile(pl2)
	local s3 = PlayerProfile.getMonetizationState(pl2)
	s3.gamepasses.bagExpand = true
	local c1 = MODS.InventorySync.capacity(p3)
	s3.gamepasses.bagExpand = true
	check("게임패스(가방 확장) 두 번 반영 = 칸 +20 한 번(소유 표시 bool · 영수증 없음)", c1 == MODS.InventorySync.capacity(p3) and c1 == 55, tostring(c1))
	for key in pairs(ids) do
		if Data.products[key] then Data.products[key].productId = 0 end
	end
end)
if not ok3 then print("[MON] 에러 " .. tostring(err3)) end
print(("[MON] 끝 %d/%d"):format(pass, total))
