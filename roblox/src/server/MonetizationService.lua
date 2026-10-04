-- QUEUE-B1 B2 수익화 서버(P4c 골격). 가격 · 상품 ID = shared/data/MonetizationData(자리값 0 = 준비 중) · 규칙 = shared/Monetization · 설계 = docs/design/monetization-p4c.md.
--   ① 구매 처리: MarketplaceService.ProcessReceipt(이 게임의 유일한 콜백) - 구매 ID 기록(profile.purchases.receipts)으로 중복 지급 방지 → 지급 → **저장 성공을 확인한 뒤에만**
--      PurchaseGranted(실패 = 기록과 이번 지급을 둘 다 되돌리고 NotProcessedYet → Roblox가 다음 접속 · 재시도 때 다시 부른다 - QUEUE-ALL10 0-1 captureUndo). 구매 기록 = purchases.log.
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
--   granted(선택 · QUEUE-ALL10 0-1 리뷰) = 이번 호출이 **실제로 새로 넣은 것** 목록을 채운다(영수증 되돌림이 그것만 지운다 - 처리 전에 없던 것 전부가 아니라).
function MonetizationService.applyReward(player, reward, source, granted)
	if type(reward) ~= "table" then
		return false, "no_reward"
	end
	local parts = {}
	if reward.egg and #PlayerProfile.getEggs(player) + reward.egg > NestData.eggCap then
		return false, "egg_full" -- 받은 표시를 하기 전에 막는다(QuestService.claim과 같은 규칙)
	end
	for _, grant in ipairs(Monetization.rewardToGrants(reward)) do
		if source == "product" or source == "token" then -- QUEUE-ALL9B 3-5 토큰 구매도 상품과 같은 판매 금지 검사
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
		if grant.kind == "cosmeticTheme" or grant.kind == "gliderSkin" or grant.kind == "cosmeticItem" then -- QUEUE-ALL6 H 꾸미기 소품
			local got, why = CosmeticService.grant(player, grant.kind, grant.id)
			if not got and why ~= "owned" then
				return false, why
			end
			if got and granted then
				table.insert(granted, { kind = grant.kind, id = grant.id })
			end
			table.insert(parts, ("%s %s%s"):format(grant.kind, grant.id, got and "" or "(이미 있음)"))
		elseif grant.kind == "seasonPremium" then
			local got, why = SeasonPassService.setPremium(player)
			if not got and why ~= "owned" then
				return false, why
			end
			if got and granted then
				table.insert(granted, { kind = "seasonPremium" })
			end
			table.insert(parts, "시즌 유료 줄")
		elseif grant.kind == "sparkleShard" or grant.kind == "egg" then
			table.insert(parts, (require(script.Parent.QuestService).grant(player, { [grant.kind] = grant.amount }))) -- 괄호 = 요약 문자열 하나(grant는 지급 표도 돌려준다)
			if granted and grant.kind == "sparkleShard" then
				table.insert(granted, { kind = "sparkleShard", amount = grant.amount })
			end
		elseif grant.kind == "gold" and type(grant.amount) == "number" and grant.amount > 0 then -- QUEUE-ALL9B 보완 2-2 시즌 무료 줄 고정 골드(스테이지 배율 아님 · 상품 · 유료 줄은 위 검사가 막는다)
			PlayerProfile.addGold(player, grant.amount)
			table.insert(parts, require(ReplicatedStorage.Shared.Text).getFor(player, "srv.reward.gold", { n = ("%d"):format(grant.amount) }))
		elseif grant.kind == "enhanceStone" or grant.kind == "highEnhanceStone" or grant.kind == "gemDust" then -- 보완 2-3 · 2-4 무료 줄 성장 소모품(기존 재화)
			table.insert(parts, (require(script.Parent.QuestService).grant(player, { [grant.kind] = grant.amount }))) -- 괄호 = 요약 문자열 하나(grant는 지급 표도 돌려준다)
		elseif grant.kind == "bagSlots" and MonetizationData.bagSources[grant.id] then -- QUEUE-ALL9C 1-6 가방 칸 출처(출처별 한 번 - 이미 있으면 그대로 · 멱등)
			local s = PlayerProfile.getMonetizationState(player)
			if granted and not s.purchases.bagSources[grant.id] then
				table.insert(granted, { kind = "bagSlots", id = grant.id })
			end
			s.purchases.bagSources[grant.id] = true
			require(script.Parent.InventorySync).push(player, PlayerProfile.getProfile(player))
			table.insert(parts, ("가방 출처 %s"):format(grant.id))
		elseif grant.kind == "passTierSkip" then -- QUEUE-ALL9B 4-8 칸 건너뛰기(방 = 영수증 처리 전에 확인)
			local got, marked = SeasonPassService.applySkip(player, grant.amount)
			if not got then
				return false, marked
			end
			if granted then
				table.insert(granted, { kind = "passTierSkip", amount = grant.amount, marked = marked }) -- 리뷰 L1: 이 영수증이 표시한 칸만 되돌린다
			end
			table.insert(parts, ("시즌 패스 %d칸"):format(grant.amount))
		else
			return false, "unknown_kind " .. tostring(grant.kind)
		end
	end
	return true, table.concat(parts, " · ")
end

-- QUEUE-ALL10 0-1: 영수증 처리 하나가 "실제로 새로 넣은 것"(granted - applyReward가 채운다)만 되돌리는 함수(저장 대기 중 들어온 다른 변경 · 다른 영수증은 건드리지 않는다).
--   되돌림 = 영수증 기록 · 새 치장(장착 중이면 장착도) · 유료 줄 · 가방 출처 · 시즌 영수증 표시(promptSeason) · 이 영수증의 칸 건너뛰기 · 토큰 환산. yield 없음(저장과 섞이지 않는다).
--   처리 중(busy)에는 같은 사람의 토큰 사용 · 시즌 줄 받기 · 선물 받기를 막는다(리뷰 H1 · M1: 되돌릴 수 없는 소비가 끼면 재시도와 합쳐 이중 지급).
local busyPlayers = {} -- [Player] = 처리 중 영수증 수
function MonetizationService.receiptBusy(player)
	return (busyPlayers[player] or 0) > 0
end
function MonetizationService.captureUndo(player)
	local s = PlayerProfile.getMonetizationState(player)
	local promptSeason = s.seasonPass.promptSeason
	local granted = {}
	return granted, function(purchaseId)
		Monetization.forgetReceipt(s.purchases, purchaseId)
		for _, g in ipairs(granted) do
			local bag = (g.kind == "cosmeticTheme" and s.cosmetics.themes) or (g.kind == "gliderSkin" and s.cosmetics.gliderSkins)
				or (g.kind == "cosmeticItem" and type(s.cosmetics.items) == "table" and s.cosmetics.items)
			if bag then
				bag[g.id] = nil
				for slot, id in pairs(s.cosmetics.equipped) do
					if id == g.id then
						s.cosmetics.equipped[slot] = nil
					end
				end
			elseif g.kind == "seasonPremium" then
				s.seasonPass.premium = false
			elseif g.kind == "bagSlots" then
				s.purchases.bagSources[g.id] = nil
				local profile = PlayerProfile.getProfile(player)
				if profile then -- 리뷰 M3: 저장 대기 중 퇴장 = 프로필 없음(push가 nil을 인덱싱해 나머지 되돌림 · inFlight 해제가 끊겼다)
					require(script.Parent.InventorySync).push(player, profile)
				end
			elseif g.kind == "passTierSkip" then
				SeasonPassService.revertSkip(player, g.amount, g.marked)
			elseif g.kind == "sparkleShard" then -- 조각 환산은 더하기라 멱등이 아니다(재시도 때 다시 준다 · 처리 중 소비는 busy가 막는다)
				local quests = PlayerProfile.getQuestState(player)
				if quests then
					quests.currencies.sparkleShard = math.max(0, (quests.currencies.sparkleShard or 0) - g.amount)
					if typeof(player) == "Instance" then
						player:SetAttribute("SparkleShard", quests.currencies.sparkleShard) -- QUEUE-ALL6 C: 지갑 Attribute
					end
				end
			end
		end
		s.seasonPass.promptSeason = promptSeason
		if typeof(player) == "Instance" and player.Parent then
			CosmeticService.applyAttributes(player)
			MonetizationService.push(player)
		end
	end
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
	inFlight[purchaseId] = true -- QUEUE-ALL10 0-1: 기록 · 지급 · 저장 · 되돌림 전체가 한 처리(겹친 호출은 NotProcessedYet)
	busyPlayers[player] = (busyPlayers[player] or 0) + 1
	local function done()
		inFlight[purchaseId] = nil
		busyPlayers[player] = (busyPlayers[player] or 1) - 1
		if busyPlayers[player] <= 0 then
			busyPlayers[player] = nil
		end
	end
	local granted, undo = MonetizationService.captureUndo(player)
	Monetization.recordReceipt(s.purchases, purchaseId, os.time(), MonetizationData.receiptKeep)
	local reward = {}
	local refund = 0
	-- 결정 8: 이미 전부 가진 것(클라가 직접 연 구매 창) · 결정 9: 지난 시즌에 연 유료 줄 영수증이 다음 시즌에 온 것 → 조각 환산(유료 줄은 켜지 않는다)
	local staleSeason = s.seasonPass.promptSeason ~= nil and s.seasonPass.promptSeason ~= SeasonPassService.currentSeason()
	local hasPremium = false
	for _, grant in ipairs(product.grants) do
		hasPremium = hasPremium or grant.kind == "seasonPremium"
	end
	local skipN = 0
	for _, grant in ipairs(product.grants) do
		skipN += grant.kind == "passTierSkip" and (grant.amount or 0) or 0
	end
	local skipOver = skipN > 0 and SeasonPassService.skipRoom(player) < skipN -- QUEUE-ALL9B 4-8: 상한 넘는 영수증(창을 연 뒤 칸이 오름 등) = 토큰 환산
	if MonetizationService.ownsAll(player, product) or (hasPremium and staleSeason) or skipOver then
		refund = Monetization.tokenPriceForRobux(MonetizationData, product.robux) or 0 -- QUEUE-ALL9B 3-3: 상품 robux 비례(토큰 가격과 같은 식)
		reward = { sparkleShard = refund }
	else
		for _, grant in ipairs(product.grants) do
			reward[grant.kind] = grant.id or grant.amount or true
		end
	end
	if hasPremium then
		s.seasonPass.promptSeason = nil
	end
	local ok, summary = MonetizationService.applyReward(player, reward, refund > 0 and "refund" or "product", granted)
	if not ok then
		undo(purchaseId) -- 부분 지급 금지: 앞 grant가 들어갔어도 전부 되돌린다
		done()
		log("grant_failed " .. tostring(summary))
		return Decision.NotProcessedYet
	end
	log("granted " .. tostring(summary))
	local okSave, saved = pcall(deps and deps.save or function(p)
		return require(script.Parent.ImmediateSave).flush(p)
	end, player)
	saved = okSave and saved
	if not saved then
		-- QUEUE-ALL10 0-1(AUDIT1 즉시-1): 저장 실패 = 영수증 기록과 이번 지급을 **둘 다** 지급 전으로 되돌리고 NotProcessedYet(옛 = 기록만 빼서
		--   다음 자동저장이 "영수증 없는 지급"을 남기고, 재시도가 ownsAll → 토큰 환산을 또 줬다). 지급과 기록은 같은 프로필 표라 어느 저장에든 함께 들어간다.
		undo(purchaseId)
		done()
		log("save_failed_retry")
		return Decision.NotProcessedYet
	end
	done()
	require(script.Parent.Telemetry).custom(player, "Purchase_" .. key, 1)
	require(script.Parent.AuditTrail).note(player, "purchase", ("%s · %s"):format(key, tostring(purchaseId))) -- QUEUE-ALL6 F3 감사
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
	return s ~= nil and Monetization.passOwned(MonetizationData, s.gamepasses, passKey) -- QUEUE-ALL10 0-3 세트 패스 includes
end
local function applyPassAttributes(player)
	local s = PlayerProfile.getMonetizationState(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	for key in pairs(MonetizationData.gamePasses) do
		player:SetAttribute("Pass_" .. key, Monetization.passOwned(MonetizationData, s.gamepasses, key))
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
		products[key] = { robux = product.robux, ready = validProducts[key] == true and product.productId ~= 0, released = Monetization.isReleased(MonetizationData, key), productId = product.productId,
			blocked = not Monetization.paidRandomAllowed(product, MonetizationService.isRestricted(player)), paidRandom = product.paidRandom == true, odds = product.odds }
	end
	local passes = {}
	for key, pass in pairs(MonetizationData.gamePasses) do
		passes[key] = { robux = pass.robux, ready = pass.passId ~= 0, owned = Monetization.passOwned(MonetizationData, s.gamepasses, key), released = Monetization.isReleased(MonetizationData, key), passId = pass.passId }
	end
	return {
		shards = CosmeticService.shards(player),
		shardPrices = MonetizationData.shardPrices,
		productTokens = (function() -- QUEUE-ALL9B 3-7: 상품마다 토큰가(토큰 불가 = 없음) · 499급 진행
			local out = {}
			for key in pairs(MonetizationData.products) do
				out[key] = validProducts[key] and Monetization.productTokenPrice(MonetizationData, CosmeticSlotData, key) or nil
			end
			return out
		end)(),
		premiumTokens = Monetization.premiumTokenProgress(MonetizationData, CosmeticService.shards(player)),
		themes = table.clone(s.cosmetics.themes),
		gliderSkins = table.clone(s.cosmetics.gliderSkins),
		items = table.clone(type(s.cosmetics.items) == "table" and s.cosmetics.items or {}), -- QUEUE-ALL6 H 꾸미기 소품
		equipped = table.clone(s.cosmetics.equipped),
		products = products,
		passes = passes,
		nameplateColors = MonetizationData.gamePasses.nameplateColor.colors,
		nameplateBadges = MonetizationData.gamePasses.nameplateBadge.badges, -- QUEUE-ALL1 P6
		season = SeasonPassService.view(player),
		gifts = #s.mailbox.gifts,
		paidRandomRestricted = MonetizationService.isRestricted(player),
		-- QUEUE-ALL9C 1-6 스타터 팩: 노출 = 아직 안 샀고 (첫 보스 처치 또는 상점 두 번째 방문) · 가방 칸 = 서버 capacity와 같은 함수(지금 칸 · 출처)
		starter = {
			owned = s.purchases.bagSources.starter == true,
			visible = s.purchases.bagSources.starter ~= true and ((PlayerProfile.getAccountBestBossCleared(player) or 0) > 0 or (s.purchases.shopViews or 0) >= 2),
		},
		bag = { slots = require(script.Parent.InventorySync).capacity(PlayerProfile.getProfile(player)), max = require(script.Parent.InventorySync).maxCapacity(PlayerProfile.getProfile(player)), -- QUEUE-ALL10 0-4 마일스톤 칸은 상한 밖
			pass = s.gamepasses.bagExpand == true, starter = s.purchases.bagSources.starter == true,
			passSlots = MonetizationData.gamePasses.bagExpand.bonusSlots, starterSlots = MonetizationData.bagSources.starter.slots },
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
			or (grant.kind == "cosmeticItem" and type(s.cosmetics.items) == "table" and s.cosmetics.items[grant.id]) -- QUEUE-ALL6 H
			or (grant.kind == "seasonPremium" and SeasonPassService.ensure(player) and s.seasonPass.premium)
			or (grant.kind == "bagSlots" and s.purchases.bagSources[grant.id]) -- QUEUE-ALL9C 1-6
		if not owned then
			return false
		end
	end
	return true
end

-- QUEUE-ALL9B 3-5 토큰(sparkleShard)으로 상품 사기 - 모든 상점 치장(묶음 포함). 가격 = Monetization.productTokenPrice(로벅스 비례 · 화면과 같은 함수).
--   거부: 모르는 · 등록 거부 상품 · 토큰 불가(시즌 한정 · 패스 · 출석판 전용 · 시즌 유료 줄) · 판매 기간 밖 · 이미 전부 가짐 · 토큰 부족.
--   차감 → 지급(applyReward - 상품 · 시즌 줄 · 선물과 같은 입구) · 중간 yield 없음(같은 요청이 겹쳐도 두 번째는 owned) · 감사 기록 · 즉시 저장 요청.
function MonetizationService.buyWithTokens(player, key)
	local product = type(key) == "string" and MonetizationData.products[key]
	if not product or not validProducts[key] then
		return false, "unknown"
	end
	if not Monetization.isReleased(MonetizationData, key) then
		return false, "not_released" -- QUEUE-ALL9C 1-6
	end
	local price, blocked = Monetization.productTokenPrice(MonetizationData, CosmeticSlotData, key)
	if not price then
		return false, blocked or "not_token"
	end
	for _, grant in ipairs(product.grants) do
		if not Monetization.onSale(CosmeticSlotData, grant.kind, grant.id) then
			return false, "off_season"
		end
	end
	if not PlayerProfile.getMonetizationState(player) then
		return false, "no_profile"
	end
	if MonetizationService.ownsAll(player, product) then
		return false, "owned"
	end
	if not CosmeticService.spendShards(player, price) then
		return false, "shards"
	end
	for _, grant in ipairs(product.grants) do
		local ok, why = MonetizationService.applyReward(player, { [grant.kind] = grant.id }, "token")
		if not ok then -- 데이터 오류(위에서 걸러져 일어나지 않아야 한다) - 토큰을 돌려준다(이미 지급된 치장은 소유 그대로 · 멱등)
			local quests = PlayerProfile.getQuestState(player)
			if quests then
				quests.currencies.sparkleShard = (quests.currencies.sparkleShard or 0) + price
				require(script.Parent.QuestService).syncWallet(player) -- 리뷰: 되돌린 토큰을 재화 칸에도
			end
			warn(("[ALL9B] 토큰 구매 지급 실패: %s - %s %s → 토큰 %d 되돌림"):format(tostring(player), key, tostring(why), price))
			return false, why
		end
	end
	require(script.Parent.AuditTrail).note(player, "tokenBuy", ("%s · %d토큰"):format(key, price)) -- QUEUE-ALL9B 6-2 감사
	require(script.Parent.ImmediateSave).request(player)
	print(("[ALL9B] 토큰 구매: %s - %s · %d토큰"):format(tostring(player), key, price))
	return true
end

-- 로벅스 구매 프롬프트(서버가 연다 - 판매 목록 · 정책 확인 뒤). 반환: ok, 이유
function MonetizationService.promptProduct(player, key)
	local product = MonetizationData.products[key]
	if not product or not validProducts[key] then
		return false, "not_for_sale"
	end
	if not Monetization.isReleased(MonetizationData, key) then
		return false, "not_released" -- QUEUE-ALL9C 1-6 순차 공개(비공개 = 프롬프트 거부)
	end
	if product.productId == 0 then
		return false, "not_ready"
	end
	local ckind, cid = Monetization.productCosmetic(product)
	if ckind and not Monetization.onSale(CosmeticSlotData, ckind, cid) then
		return false, "off_season" -- QUEUE-ALL6 H: 할로윈 = 10월만 판매(산 사람은 계속 가짐)
	end
	if not Monetization.paidRandomAllowed(product, MonetizationService.isRestricted(player)) then
		return false, "restricted"
	end
	if not PlayerProfile.getMonetizationState(player) then
		return false, "no_profile" -- QUEUE-ALL5 D②: 로드 전 - 아래 seasonPremium 줄이 nil을 인덱싱했다
	end
	if (key == "season_premium" or key == "season_premium_sale") and key ~= Monetization.activePremiumKey(SeasonPassData) then
		return false, "not_active" -- QUEUE-ALL9B 4-4: 지금 활성인 유료 줄 상품만(할인 켜짐 = sale만 · 꺼짐 = 정가만)
	end
	for _, grant in ipairs(product.grants) do
		if grant.kind == "passTierSkip" and SeasonPassService.skipRoom(player) < (grant.amount or 0) then
			return false, "skip_cap" -- 4-8: 버튼 비활성과 같은 판정(서버도)
		end
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
	if not Monetization.isReleased(MonetizationData, key) then
		return false, "not_released" -- QUEUE-ALL9C 1-6
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

local ACTIONS = { view = true, buyShards = true, buyTokens = true, buyRobux = true, buyPass = true, equip = true, equipAll = true, seasonClaim = true, seasonClaimAll = true, giftClaim = true }
function MonetizationService.handle(player, action, a, b)
	if type(action) ~= "string" or not ACTIONS[action] then
		return false, "bad_action"
	end
	local ok, why = true, nil
	if MonetizationService.receiptBusy(player) and (action == "buyShards" or action == "buyTokens" or action == "seasonClaim" or action == "seasonClaimAll" or action == "giftClaim") then
		ok, why = false, "busy" -- QUEUE-ALL10 0-1 리뷰 H1 · M1: 영수증 저장 대기 중(수 초)에는 되돌릴 수 없는 소비 · 받기를 막는다
	elseif action == "buyShards" and type(a) == "string" and type(b) == "string" then
		ok, why = CosmeticService.buyWithShards(player, a, b)
	elseif action == "buyTokens" and type(a) == "string" then -- QUEUE-ALL9B 3-5 상품 키(묶음 포함)
		ok, why = MonetizationService.buyWithTokens(player, a)
	elseif action == "buyRobux" and type(a) == "string" then
		ok, why = MonetizationService.promptProduct(player, a)
	elseif action == "buyPass" and type(a) == "string" then
		ok, why = MonetizationService.promptPass(player, a)
	elseif action == "equip" and type(a) == "string" and (b == nil or type(b) == "string") then
		ok, why = CosmeticService.equip(player, a, b)
	elseif action == "equipAll" and type(a) == "string" and type(b) == "string" then -- QUEUE-ALL9C 1-6 X6 구매 완료 창 [바로 장착] = 그 치장이 들어가는 칸 전부
		ok, why = CosmeticService.equipAll(player, a, b)
	elseif action == "seasonClaim" and type(a) == "string" and type(b) == "number" then
		ok, why = SeasonPassService.claim(player, a, b)
	elseif action == "seasonClaimAll" and type(a) == "string" then -- QUEUE-ALL9B 4-6 일괄 받기(소급)
		local got, last = SeasonPassService.claimAll(player, a)
		ok, why = got > 0, if got > 0 then nil else (last or "none")
	elseif action == "giftClaim" and type(a) == "string" then
		local got = GiftService.claim(player, a)
		ok, why = got > 0, if got > 0 then nil else "none"
	elseif action == "view" then
		local s = PlayerProfile.getMonetizationState(player) -- QUEUE-ALL9C 1-6: 상점을 연 횟수(스타터 노출 조건 - 두 번째 방문)
		if s then
			s.purchases.shopViews = math.min((s.purchases.shopViews or 0) + 1, 1000)
		end
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
	SeasonPassService.weekendBanner(player) -- QUEUE-ALL9A 1-2 주말 창 첫 접속 배너 1회
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
