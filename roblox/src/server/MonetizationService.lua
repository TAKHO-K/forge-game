-- QUEUE-B1 B2 수익화 서버(P4c 골격). 가격 · 상품 ID = shared/data/MonetizationData(자리값 0 = 준비 중) · 규칙 = shared/Monetization · 설계 = docs/design/monetization-p4c.md.
--   ① 구매 처리: MarketplaceService.ProcessReceipt(이 게임의 유일한 콜백) - 구매 ID 기록(profile.purchases.receipts)으로 중복 지급 방지 → 지급 → **저장 성공을 확인한 뒤에만**
--      PurchaseGranted(실패 = 기록 · 지급 되돌림 없이 NotProcessedYet → Roblox가 다음 접속 · 재시도 때 다시 부른다 - 지급은 멱등이라 두 번 불러도 같다). 구매 기록 = purchases.log.
--      **상품 grant는 멱등 종류만**(allowedKinds - 치장 소유 · 유료 줄 켜기). 수량형(조각 · 알)을 상품에 넣으려면 저장 실패 때 되돌림이 먼저 필요하다(리뷰).
--   ② 판매 금지 목록: 서버 시작 때 Monetization.checkCatalog - 걸린 상품은 판매 목록에서 빠지고(구매 프롬프트 거부) 로그에 남는다.
--   ③ 유료 랜덤: PolicyService ArePaidRandomItemsRestricted를 접속 때 캐시(조회 실패 = 제한) - paidRandom 상품은 제한 대상에게 프롬프트 자체를 막는다(지금 paidRandom 0개).
--   ④ 게임패스(편의): 접속 때 UserOwnsGamePassAsync로 profile.gamepasses 캐시 갱신(조회 실패면 캐시 유지) · 구매 완료 이벤트로 즉시 반영 · 효과 = 각 시스템이 hasPass로 읽는다.
--   ⑤ 창구 Remote ShopRequest(클라 → 서버) / ShopSync(서버 → 클라 화면 표) - 요청 제한 = RequestGate(공통 입구).
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
local SeasonPassData = require(ReplicatedStorage.Shared.data.SeasonPassData)
local NestData = require(ReplicatedStorage.Shared.data.NestData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local PlayerProfile = require(script.Parent.PlayerProfile)
local CosmeticService = require(script.Parent.CosmeticService)
local SeasonPassService = require(script.Parent.SeasonPassService)
local GiftService = require(script.Parent.GiftService)

local MonetizationService = {}

local catalogOk, catalogReasons, validProducts = Monetization.checkCatalog(MonetizationData, CosmeticSlotData, SeasonPassData)
MonetizationService.catalogOk = catalogOk
MonetizationService.catalogReasons = catalogReasons
MonetizationService.validProducts = validProducts
if not catalogOk then
	for _, line in ipairs(catalogReasons) do
		warn("[B2] 상품 등록 거부: " .. line)
	end
end

local inFlight = {} -- 리뷰 의심: 처리 중(저장 대기) PurchaseId - 겹친 두 번째 호출은 NotProcessedYet
local restricted = {} -- [Player] = bool(유료 랜덤 제한 - nil = 아직 모름 → failClosed면 제한)
local syncRemote = nil
local resultRemote = nil -- 결정 10: ShopResult(action, ok, why) - 창이 결과 한 줄을 정확히 쓴다

-- 보상 적용(상품 grants · 시즌 줄 · 선물 공통). reward = { cosmeticTheme = id, gliderSkin = id, sparkleShard = n, egg = n, seasonPremium = true }.
--   판매 금지 종류는 source == "product"일 때 거부(시즌 무료 줄 알 · 조각은 무료 보상). 반환: ok, 요약 | 이유
function MonetizationService.applyReward(player, reward, source)
	if type(reward) ~= "table" then
		return false, "no_reward"
	end
	local parts = {}
	if reward.egg and #PlayerProfile.getEggs(player) + reward.egg > NestData.eggCap then
		return false, "egg_full" -- 받은 표시를 하기 전에 막는다(QuestService.claim과 같은 규칙)
	end
	for _, grant in ipairs(Monetization.rewardToGrants(reward)) do
		if source == "product" then
			local ok, why = Monetization.checkGrant(MonetizationData, grant)
			if not ok then
				return false, why
			end
		elseif source == "refund" and grant.kind ~= "sparkleShard" then -- 결정 8: 환산은 조각만
			return false, "refund_kind"
		elseif source == "seasonPaid" then -- 리뷰 중요 2: 유료 줄 = 로벅스로 산 보상 - 판매 금지 · 알(랜덤) 거부(데이터가 잘못돼도 지급 안 함)
			local ok, why = Monetization.checkGrant(MonetizationData, grant, Monetization.PAID_ROW_KINDS)
			if not ok then
				return false, why
			end
		end
		if grant.kind == "cosmeticTheme" or grant.kind == "gliderSkin" then
			local got, why = CosmeticService.grant(player, grant.kind, grant.id)
			if not got and why ~= "owned" then
				return false, why
			end
			table.insert(parts, ("%s %s%s"):format(grant.kind, grant.id, got and "" or "(이미 있음)"))
		elseif grant.kind == "seasonPremium" then
			local got, why = SeasonPassService.setPremium(player)
			if not got and why ~= "owned" then
				return false, why
			end
			table.insert(parts, "시즌 유료 줄")
		elseif grant.kind == "sparkleShard" or grant.kind == "egg" then
			table.insert(parts, require(script.Parent.QuestService).grant(player, { [grant.kind] = grant.amount }))
		else
			return false, "unknown_kind " .. tostring(grant.kind)
		end
	end
	return true, table.concat(parts, " · ")
end

-- ── ① 구매 처리 ──
-- 반환 = Enum.ProductPurchaseDecision. deps(검증 · 하네스) = { save = function(player) → 저장 성공 bool }
function MonetizationService.processReceipt(receiptInfo, deps)
	local Decision = Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local s = player and PlayerProfile.getMonetizationState(player)
	if not s then
		return Decision.NotProcessedYet -- 접속 전 · 로드 전: 다음 접속 때 Roblox가 다시 부른다
	end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if inFlight[purchaseId] then
		return Decision.NotProcessedYet
	end
	if Monetization.hasReceipt(s.purchases, purchaseId) then
		return Decision.PurchaseGranted -- 이미 지급(중복 호출)
	end
	local key = Monetization.productKeyById(MonetizationData, receiptInfo.ProductId)
	local product = key and MonetizationData.products[key]
	local function log(result)
		print(("[B2] 구매 처리: %s - %s(%s) → %s"):format(player.Name, tostring(key), purchaseId, result))
		for _, line in ipairs(s.purchases.log) do -- 결정 9: 재시도마다 같은 줄이 쌓이지 않게(알 수 없는 상품 · 정책 제한은 접속마다 다시 온다 - 운영 = 구매 기록으로 환불 판단)
			if line.purchaseId == purchaseId and line.result == result then
				return
			end
		end
		Monetization.appendLog(s.purchases, { at = os.time(), key = key or ("?" .. tostring(receiptInfo.ProductId)), purchaseId = purchaseId,
			robux = receiptInfo.CurrencySpent, result = result }, MonetizationData.logKeep)
	end
	if not product or not validProducts[key] then
		log("unknown_or_rejected")
		return Decision.NotProcessedYet
	end
	if not Monetization.paidRandomAllowed(product, MonetizationService.isRestricted(player)) then
		log("paid_random_restricted")
		return Decision.NotProcessedYet
	end
	Monetization.recordReceipt(s.purchases, purchaseId, os.time(), MonetizationData.receiptKeep)
	local reward = {}
	local refund = 0
	-- 결정 8: 이미 전부 가진 것(클라가 직접 연 구매 창) · 결정 9: 지난 시즌에 연 유료 줄 영수증이 다음 시즌에 온 것 → 조각 환산(유료 줄은 켜지 않는다)
	local staleSeason = s.seasonPass.promptSeason ~= nil and s.seasonPass.promptSeason ~= SeasonPassService.currentSeason()
	local hasPremium = false
	for _, grant in ipairs(product.grants) do
		hasPremium = hasPremium or grant.kind == "seasonPremium"
	end
	if MonetizationService.ownsAll(player, product) or (hasPremium and staleSeason) then
		for _, grant in ipairs(product.grants) do
			refund += MonetizationData.ownedRefundShards[grant.kind] or 0
		end
		reward = { sparkleShard = refund }
	else
		for _, grant in ipairs(product.grants) do
			reward[grant.kind] = grant.id or grant.amount or true
		end
	end
	if hasPremium then
		s.seasonPass.promptSeason = nil
	end
	local ok, summary = MonetizationService.applyReward(player, reward, refund > 0 and "refund" or "product")
	if not ok then
		Monetization.forgetReceipt(s.purchases, purchaseId)
		log("grant_failed " .. tostring(summary))
		return Decision.NotProcessedYet
	end
	log("granted " .. tostring(summary))
	inFlight[purchaseId] = true
	local okSave, saved = pcall(deps and deps.save or function(p)
		return require(script.Parent.ImmediateSave).flush(p)
	end, player)
	inFlight[purchaseId] = nil
	saved = okSave and saved
	if not saved then
		-- 저장 실패: 기록을 빼고 NotProcessedYet → 다음 재시도가 다시 지급(멱등 - 치장 소유 · 유료 줄은 켜진 채라 같은 결과) · 그때 저장되면 Granted
		Monetization.forgetReceipt(s.purchases, purchaseId)
		if refund > 0 then -- 조각 환산은 더하기라 멱등이 아니다 - 되돌린다(재시도 때 다시 준다)
			local quests = PlayerProfile.getQuestState(player)
			if quests then
				quests.currencies.sparkleShard = math.max(0, (quests.currencies.sparkleShard or 0) - refund)
			end
		end
		log("save_failed_retry")
		return Decision.NotProcessedYet
	end
	require(script.Parent.Telemetry).custom(player, "Purchase_" .. key, 1)
	MonetizationService.push(player)
	return Decision.PurchaseGranted
end

-- ── ③ 유료 랜덤 정책 ──
function MonetizationService.isRestricted(player)
	local value = restricted[player]
	if value == nil then
		return MonetizationData.policy.failClosed
	end
	return value
end
local function cachePolicy(player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and type(info) == "table" and type(info.ArePaidRandomItemsRestricted) == "boolean" and player.Parent then -- QUEUE-ALL5 D②: 조회 중 나갔으면 쓰지 않는다(PlayerRemoving이 지운 뒤 다시 남던 것)
		restricted[player] = info.ArePaidRandomItemsRestricted
	end
end

-- ── ④ 게임패스 ──
function MonetizationService.hasPass(player, passKey)
	local s = PlayerProfile.getMonetizationState(player)
	return s ~= nil and s.gamepasses[passKey] == true
end
local function applyPassAttributes(player)
	local s = PlayerProfile.getMonetizationState(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	for key in pairs(MonetizationData.gamePasses) do
		player:SetAttribute("Pass_" .. key, s.gamepasses[key] == true)
	end
	CosmeticService.applyAttributes(player) -- 이름표 색은 패스가 있어야 보인다
end
local function refreshPasses(player)
	local s = PlayerProfile.getMonetizationState(player)
	if not s then
		return
	end
	for key, pass in pairs(MonetizationData.gamePasses) do
		if pass.passId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.passId)
			end)
			if ok and PlayerProfile.getMonetizationState(player) == s then -- QUEUE-ALL5 D②: 조회(yield) 중 퇴장 · 프로필 교체면 낡은 표에 쓰지 않는다
				s.gamepasses[key] = owns == true or nil
			end -- 조회 실패 = 캐시 유지
		end
	end
	applyPassAttributes(player)
end

-- ── ⑤ 화면 표 · 창구 ──
function MonetizationService.view(player)
	local s = PlayerProfile.getMonetizationState(player)
	if not s then
		return nil
	end
	local products = {}
	for key, product in pairs(MonetizationData.products) do
		products[key] = { robux = product.robux, ready = validProducts[key] == true and product.productId ~= 0,
			blocked = not Monetization.paidRandomAllowed(product, MonetizationService.isRestricted(player)), paidRandom = product.paidRandom == true, odds = product.odds }
	end
	local passes = {}
	for key, pass in pairs(MonetizationData.gamePasses) do
		passes[key] = { robux = pass.robux, ready = pass.passId ~= 0, owned = s.gamepasses[key] == true }
	end
	return {
		shards = CosmeticService.shards(player),
		shardPrices = MonetizationData.shardPrices,
		themes = table.clone(s.cosmetics.themes),
		gliderSkins = table.clone(s.cosmetics.gliderSkins),
		equipped = table.clone(s.cosmetics.equipped),
		products = products,
		passes = passes,
		nameplateColors = MonetizationData.gamePasses.nameplateColor.colors,
		nameplateBadges = MonetizationData.gamePasses.nameplateBadge.badges, -- QUEUE-ALL1 P6
		season = SeasonPassService.view(player),
		gifts = #s.mailbox.gifts,
		paidRandomRestricted = MonetizationService.isRestricted(player),
	}
end
function MonetizationService.push(player)
	if syncRemote and typeof(player) == "Instance" and player.Parent then
		syncRemote:FireClient(player, MonetizationService.view(player))
	end
end

-- 상품의 grant를 전부 이미 가졌나(치장 소유 · 이번 시즌 유료 줄)
function MonetizationService.ownsAll(player, product)
	local s = PlayerProfile.getMonetizationState(player)
	if not s then
		return false
	end
	for _, grant in ipairs(product.grants) do
		local owned = (grant.kind == "cosmeticTheme" and s.cosmetics.themes[grant.id]) or (grant.kind == "gliderSkin" and s.cosmetics.gliderSkins[grant.id])
			or (grant.kind == "seasonPremium" and SeasonPassService.ensure(player) and s.seasonPass.premium)
		if not owned then
			return false
		end
	end
	return true
end

-- 로벅스 구매 프롬프트(서버가 연다 - 판매 목록 · 정책 확인 뒤). 반환: ok, 이유
function MonetizationService.promptProduct(player, key)
	local product = MonetizationData.products[key]
	if not product or not validProducts[key] then
		return false, "not_for_sale"
	end
	if product.productId == 0 then
		return false, "not_ready"
	end
	if not Monetization.paidRandomAllowed(product, MonetizationService.isRestricted(player)) then
		return false, "restricted"
	end
	if not PlayerProfile.getMonetizationState(player) then
		return false, "no_profile" -- QUEUE-ALL5 D②: 로드 전 - 아래 seasonPremium 줄이 nil을 인덱싱했다
	end
	if MonetizationService.ownsAll(player, product) then -- 리뷰 중요 3: 이미 가진 치장 · 이번 시즌 유료 줄을 다시 사지 않게(결제만 되고 받는 것 없음)
		return false, "owned"
	end
	for _, grant in ipairs(product.grants) do
		if grant.kind == "seasonPremium" then
			local s = PlayerProfile.getMonetizationState(player)
			s.seasonPass.promptSeason = SeasonPassService.currentSeason() -- 결정 9: 영수증이 다음 시즌에 오면 조각 환산
		end
	end
	MarketplaceService:PromptProductPurchase(player, product.productId)
	return true
end
function MonetizationService.promptPass(player, key)
	local pass = MonetizationData.gamePasses[key]
	if not pass then
		return false, "unknown"
	end
	if pass.passId == 0 then
		return false, "not_ready"
	end
	if MonetizationService.hasPass(player, key) then
		return false, "owned"
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.passId)
	return true
end

local ACTIONS = { view = true, buyShards = true, buyRobux = true, buyPass = true, equip = true, seasonClaim = true, giftClaim = true }
function MonetizationService.handle(player, action, a, b)
	if type(action) ~= "string" or not ACTIONS[action] then
		return false, "bad_action"
	end
	local ok, why = true, nil
	if action == "buyShards" and type(a) == "string" and type(b) == "string" then
		ok, why = CosmeticService.buyWithShards(player, a, b)
	elseif action == "buyRobux" and type(a) == "string" then
		ok, why = MonetizationService.promptProduct(player, a)
	elseif action == "buyPass" and type(a) == "string" then
		ok, why = MonetizationService.promptPass(player, a)
	elseif action == "equip" and type(a) == "string" and (b == nil or type(b) == "string") then
		ok, why = CosmeticService.equip(player, a, b)
	elseif action == "seasonClaim" and type(a) == "string" and type(b) == "number" then
		ok, why = SeasonPassService.claim(player, a, b)
	elseif action == "giftClaim" and type(a) == "string" then
		local got = GiftService.claim(player, a)
		ok, why = got > 0, if got > 0 then nil else "none"
	elseif action ~= "view" then
		ok, why = false, "bad_args"
	end
	if resultRemote and action ~= "view" and typeof(player) == "Instance" and player.Parent then
		resultRemote:FireClient(player, action, ok == true, why ~= nil and tostring(why) or nil)
	end
	MonetizationService.push(player)
	return ok, why
end

-- 결정 9: DevTools 백업 복원(restoreForDevTools) 뒤 치장 · 패스 Attribute 다시 걸기
function MonetizationService.reapplyAttributes(player)
	applyPassAttributes(player)
end

function MonetizationService.onLoaded(player)
	SeasonPassService.ensure(player)
	CosmeticService.onLoaded(player)
	applyPassAttributes(player) -- 캐시값으로 먼저(조회는 느리다)
	task.spawn(function()
		cachePolicy(player)
		refreshPasses(player)
		MonetizationService.push(player)
	end)
	GiftService.onLoaded(player)
end

function MonetizationService.start()
	GiftService.start()
	-- QUEUE-B1 결정 7: 시즌 1 시작일이 없으면 시즌 패스가 한 시즌에 멈춘다 - 서버 시작 경고(출시 체크리스트 P6)
	local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)
	if SeasonPassData.enabled and not LeaderboardConfig.firstSeasonDateKst and (LeaderboardConfig.seasonStartUnix or 0) <= 0 then
		warn("[B2] 시즌 1 시작일 미정(LeaderboardConfig.firstSeasonDateKst) - 시즌 번호 고정 · 시즌 패스가 넘어가지 않는다(출시 전 확정)")
	end
	local request = ReplicatedStorage:FindFirstChild("ShopRequest") or Instance.new("RemoteEvent")
	request.Name = "ShopRequest"
	request.Parent = ReplicatedStorage
	syncRemote = ReplicatedStorage:FindFirstChild("ShopSync") or Instance.new("RemoteEvent")
	syncRemote.Name = "ShopSync"
	syncRemote.Parent = ReplicatedStorage
	resultRemote = ReplicatedStorage:FindFirstChild("ShopResult") or Instance.new("RemoteEvent")
	resultRemote.Name = "ShopResult"
	resultRemote.Parent = ReplicatedStorage
	local RequestGate = require(script.Parent.RequestGate)
	request.OnServerEvent:Connect(function(player, action, a, b)
		if not RequestGate.allow(player, "ShopRequest") then
			return
		end
		MonetizationService.handle(player, action, a, b)
	end)
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return MonetizationService.processReceipt(receiptInfo)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = Monetization.passKeyById(MonetizationData, passId)
		local s = key and purchased and PlayerProfile.getMonetizationState(player)
		if s then -- 리뷰 의심: 완료 신호만 믿지 않고 소유 조회로 확인(조회 실패 = 다음 접속 refresh에 맡김)
			local okOwn, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if not (okOwn and owns) or PlayerProfile.getMonetizationState(player) ~= s then
				return -- QUEUE-ALL5 D②: 조회(yield) 중 퇴장 · 프로필 교체면 낡은 표에 쓰지 않는다(다음 접속 refresh가 반영)
			end
			s.gamepasses[key] = true
			applyPassAttributes(player)
			if key == "bagExpand" then
				PlayerProfile.pushInventory(player) -- 리뷰 사소: 칸 수 표시 즉시
			end
			require(script.Parent.ImmediateSave).request(player)
			Monetization.appendLog(s.purchases, { at = os.time(), key = "pass_" .. key, purchaseId = "pass", robux = MonetizationData.gamePasses[key].robux, result = "pass_owned" }, MonetizationData.logKeep)
			MonetizationService.push(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		restricted[player] = nil
	end)
end

return MonetizationService
