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
local baseGetService = game.GetService
game.GetService = function(self, name)
	if name == "Players" then
		return setmetatable({ GetPlayerByUserId = function(_, id) return PLAYERS[id] end, GetPlayers = function() return {} end },
			{ __index = function() return { Connect = function() end } end })
	elseif name == "MarketplaceService" then
		return setmetatable({ PromptProductPurchase = function(_, p, id) table.insert(prompts, { "product", id }) end, PromptGamePassPurchase = function(_, p, id) table.insert(prompts, { "pass", id }) end,
			UserOwnsGamePassAsync = function() return false end }, { __index = function() return { Connect = function() end } end })
	elseif name == "PolicyService" then
		return { GetPolicyInfoForPlayerAsync = function() if policyAnswer == "error" then error("policy down") end return { ArePaidRandomItemsRestricted = policyAnswer } end }
	elseif name == "DataStoreService" then
		return { GetDataStore = function(_, storeName) DS[storeName] = DS[storeName] or {}; local t = DS[storeName]
			return { UpdateAsync = function(_, key, fn) local v = fn(t[key]); if v ~= nil then t[key] = v end; return v end, GetAsync = function(_, key) return t[key] end } end }
	elseif name == "HttpService" then
		return { GenerateGUID = function() guid += 1; return "G" .. guid end }
	end
	return baseGetService(self, name)
end

local ok, err = pcall(function()
	local SaveSystem, PlayerProfile = MODS.SaveSystem, MODS.PlayerProfile
	local Data, Mon = MODS.MonetizationData, MODS.Monetization
	local Cos, Season = MODS.CosmeticSlotData, MODS.SeasonPassData

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
	check("조각 모자람 거부 · 구매 120 차감 · 두 번째 owned · 골드 그대로", not b1 and w1 == "shards" and b2 and not b3 and w3 == "owned" and qs.currencies.sparkleShard == 380 and p.gold == gold0,
		("조각 %d"):format(qs.currencies.sparkleShard))
	local e1 = MODS.CosmeticService.equip(player, "dashTrail", "frost")
	local e2 = MODS.CosmeticService.equip(player, "jumpFx", "ember")
	local e3, w4 = MODS.CosmeticService.equip(player, "glideTrail", "starlight")
	local e4, w5 = MODS.CosmeticService.equip(player, "nameplateColor", "gold")
	-- (가짜 Player는 Instance가 아니라 Attribute 적용은 건너뛴다 - 장착 표로 확인 · Attribute는 다음 Play 목록)
	check("칸별 섞어 장착(frost + ember) · 안 산 세트 거부 · 패스 없는 이름표 색 거부", e1 and e2 and not e3 and w4 == "not_owned" and not e4 and w5 == "no_pass"
		and s.cosmetics.equipped.dashTrail == "frost" and s.cosmetics.equipped.jumpFx == "ember" and s.cosmetics.equipped.glideTrail == nil)

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

	-- ⑦-2 QUEUE-B1 결정 8 · 9: 이미 가진 것 영수증 = 조각 환산 · 저장 실패 = 조각 되돌림 · 지난 시즌 유료 줄 영수증 = 환산 · 같은 실패 줄 한 번 · 손상 표 복구
	Data.products.theme_ember.productId = 9001
	local shard0 = qs.currencies.sparkleShard
	saveResult = false
	local r1 = MS.processReceipt({ PlayerId = 77, ProductId = 9001, PurchaseId = "P-OWN", CurrencySpent = 199 }, deps)
	local afterFail = qs.currencies.sparkleShard
	saveResult = true
	local r2 = MS.processReceipt({ PlayerId = 77, ProductId = 9001, PurchaseId = "P-OWN", CurrencySpent = 199 }, deps)
	check("이미 가진 테마 영수증 = 조각 +120 환산 · 저장 실패 때 되돌림 · 재시도 Granted", tostring(r1):find("NotProcessedYet") ~= nil and afterFail == shard0
		and tostring(r2):find("PurchaseGranted") ~= nil and qs.currencies.sparkleShard == shard0 + Data.ownedRefundShards.cosmeticTheme, ("%d → %d → %d"):format(shard0, afterFail, qs.currencies.sparkleShard))
	s.seasonPass.premium = false
	s.seasonPass.promptSeason = s.seasonPass.season - 1 -- 지난 시즌에 연 구매 창
	local shard1 = qs.currencies.sparkleShard
	MS.processReceipt({ PlayerId = 77, ProductId = 9002, PurchaseId = "P-OLDSEASON", CurrencySpent = 399 }, deps)
	check("지난 시즌에 연 유료 줄 영수증 = 이번 시즌 유료 안 켜고 조각 환산", not s.seasonPass.premium and qs.currencies.sparkleShard == shard1 + Data.ownedRefundShards.seasonPremium and s.seasonPass.promptSeason == nil)
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
	local fresh = SaveSystem.migrate({})
	check("migrate({}) → v56 · 새 칸 모양", fresh.version == 56 and type(fresh.cosmetics.themes) == "table" and type(fresh.mailbox.gifts) == "table" and fresh.seasonPass.premium == false
		and type(fresh.purchases.receipts) == "table" and type(fresh.purchases.log) == "table")
	local old = SaveSystem.migrate({})
	old.version = 55
	old.cosmetics, old.mailbox, old.seasonPass = nil, nil, nil
	old.purchases.receipts, old.purchases.log = nil, nil
	old.gamepasses = nil
	local m = SaveSystem.migrate(old)
	check("v55 옛 표본 → v56 빈 칸 채움", m.version == 56 and m.cosmetics and m.mailbox and m.seasonPass and m.purchases.receipts and m.purchases.log and type(m.gamepasses) == "table")
	local snap = PlayerProfile.snapshotForDevTools(player)
	check("백업 대상(snapshotForDevTools)에 새 칸", snap.cosmetics and snap.mailbox and snap.seasonPass and snap.receipts and snap.purchaseLog and snap.gamepasses)
	-- 게임패스 효과: 가방 +20 · 귀환 쿨 × 0.5
	local cap0 = MODS.InventorySync.capacity(p)
	s.gamepasses.bagExpand = true
	local cap1 = MODS.InventorySync.capacity(p)
	s.gamepasses.bagExpand = nil
	check(("가방 확장 패스 +%d칸"):format(Data.gamePasses.bagExpand.bonusSlots), cap1 - cap0 == Data.gamePasses.bagExpand.bonusSlots, ("%d → %d"):format(cap0, cap1))
end)
if not ok then print("[MON] 에러 " .. tostring(err)) end
print(("[MON] 끝 %d/%d"):format(pass, total))
