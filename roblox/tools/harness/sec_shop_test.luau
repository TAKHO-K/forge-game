-- SEC-FIX-1 3 · 8 결제 재현 하네스(실제 MonetizationService · SeasonPassService · SaveSystem + 가짜 Marketplace · Policy · DataStore - 스캐폴드 = monetize_test 앞부분 그대로).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py MonetizationService,SaveSystem,OpsServer.server,InventorySync) ECON_RES=res_secshop.txt python build_run.py sec_shop_test.luau
-- 옛 코드 실패 확인 = ECON_SRC=<옛 src 스냅샷>(옛 = X). 묶음: 3 지급 에러 → 잠금 해제 · 되돌림 · 다음에 다시 처리 - 끝 줄 "[SECSHOP] 끝 n/m".
Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[SECSHOP] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
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
	local s = PlayerProfile.getMonetizationState(player)

	-- ═══ 3. 결제 applyReward 런타임 에러 → 잠금 해제 · 영수증 · 부분 지급 되돌림 · NotProcessedYet → 다음에 다시 처리 ═══
	Data.products.theme_ember.productId = 9001
	MS.validProducts.theme_ember = true
	local deps = { save = function() return true end }
	local realApply = MS.applyReward
	MS.applyReward = function(pl, reward, source, granted)
		realApply(pl, reward, source, granted) -- 앞 지급은 들어감(부분 지급)
		error("지급 함수 런타임 에러(시험)")
	end
	s.cosmetics.themes.ember = nil
	local okCall, d1 = pcall(MS.processReceipt, { PlayerId = 77, ProductId = 9001, PurchaseId = "P-ERR", CurrencySpent = 199 }, deps)
	MS.applyReward = realApply
	check("3 지급 에러 = 처리가 에러를 던지지 않고 NotProcessedYet(옛 = 에러가 ProcessReceipt 밖으로)", okCall and tostring(d1):find("NotProcessedYet") ~= nil, tostring(d1))
	check("3 지급 에러 뒤 처리 중 잠금 풀림(옛 = 그 서버에서 토큰 구매 · 시즌 받기 · 선물 받기 계속 막힘)", not MS.receiptBusy(player))
	check("3 지급 에러 = 영수증 기록 · 부분 지급(테마) 되돌림(자동저장에 안 남음)", not Mon.hasReceipt(s.purchases, "P-ERR") and not s.cosmetics.themes.ember,
		("영수증 %s · 테마 %s"):format(tostring(Mon.hasReceipt(s.purchases, "P-ERR")), tostring(s.cosmetics.themes.ember)))
	local okCall2, d2 = pcall(MS.processReceipt, { PlayerId = 77, ProductId = 9001, PurchaseId = "P-ERR", CurrencySpent = 199 }, deps)
	check("3 다음 호출(Roblox 재시도) = 지급 · PurchaseGranted(옛 = inFlight가 남아 영영 NotProcessedYet)", okCall2 and tostring(d2):find("PurchaseGranted") ~= nil and s.cosmetics.themes.ember == true, tostring(d2))
	local okTok = pcall(MS.buyWithTokens, player, "theme_ember")
	check("3 그 뒤 토큰 구매 입구 동작(잠금 없음)", okTok and not MS.receiptBusy(player))
	Data.products.theme_ember.productId = 0
end)
if not ok then print("[SECSHOP] 에러 " .. tostring(err)) end
print(("[SECSHOP] 끝 %d/%d"):format(pass, total))
