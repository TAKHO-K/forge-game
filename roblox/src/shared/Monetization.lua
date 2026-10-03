-- QUEUE-B1 B2 P4c 수익화 순수 규칙(서버 · 검증 · 하네스 공용 - Roblox 서비스 없음).
--   ① 판매 금지 목록 강제(checkGrant · checkProduct · checkCatalog) ② 유료 랜덤 정책(paidRandomAllowed) ③ 시즌 패스 줄 규칙(checkSeasonPass)
--   ④ 영수증 중복 처리 방지(recordReceipt - PurchaseId 기록) ⑤ 시즌 칸 계산(seasonTier · canClaim).
--   데이터 = shared/data/MonetizationData · CosmeticSlotData · SeasonPassData.
local Monetization = {}

-- 보상 표(QuestService.grant 모양 - { sparkleShard = 2, egg = 1, cosmeticTheme = "id" })를 grants 목록으로. 키 순서를 정렬해 결과가 늘 같다.
function Monetization.rewardToGrants(reward)
	local grants, keys = {}, {}
	for key in pairs(reward or {}) do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local value = reward[key]
		if type(value) == "string" then
			table.insert(grants, { kind = key, id = value })
		else
			table.insert(grants, { kind = key, amount = value })
		end
	end
	return grants
end

-- 한 grant의 판정. 반환: ok, 이유(거부일 때). allowed = 이 자리에서 허용하는 종류 집합(기본 = data.allowedKinds).
function Monetization.checkGrant(data, grant, allowed)
	local kind = type(grant) == "table" and grant.kind
	if type(kind) ~= "string" then
		return false, "종류 없음"
	end
	local forbidden = data.forbiddenKinds[kind] and kind or data.forbiddenAliases[kind]
	if forbidden then
		return false, ("판매 금지: %s(%s)"):format(data.forbiddenKinds[forbidden] or forbidden, kind)
	end
	if not (allowed or data.allowedKinds)[kind] then
		return false, ("모르는 종류: %s"):format(kind)
	end
	return true
end

-- 상품 하나(개발자 상품). 반환: ok, 이유 목록
function Monetization.checkProduct(data, key, product, cosmetics)
	local reasons = {}
	if type(product) ~= "table" or type(product.grants) ~= "table" or #product.grants == 0 then
		return false, { key .. ": grants 없음" }
	end
	for _, grant in ipairs(product.grants) do
		local ok, why = Monetization.checkGrant(data, grant)
		if not ok then
			table.insert(reasons, ("%s: %s"):format(key, why))
		elseif cosmetics and (grant.kind == "cosmeticTheme" or grant.kind == "gliderSkin" or grant.kind == "cosmeticItem") and not Monetization.findCosmetic(cosmetics, grant.kind, grant.id) then
			table.insert(reasons, ("%s: 없는 치장 %s"):format(key, tostring(grant.id)))
		elseif cosmetics and Monetization.seasonOnly(cosmetics, grant.kind, grant.id) then
			table.insert(reasons, ("%s: 시즌 한정 치장 %s는 상품으로 못 판다(재판매 없음)"):format(key, tostring(grant.id))) -- QUEUE-ALL1 R1
		elseif cosmetics and Monetization.tokenBlocked(cosmetics, grant.kind, grant.id) then
			table.insert(reasons, ("%s: 패스 · 출석판 전용 치장 %s는 상품으로 못 판다"):format(key, tostring(grant.id))) -- QUEUE-ALL9B 4-3 · 5-1
		end
	end
	if product.tier ~= nil and not (data.tiers and data.tiers[product.tier] and data.tiers[product.tier].robux == product.robux) then
		table.insert(reasons, ("%s: 가격 등급 %s와 robux %s가 안 맞음"):format(key, tostring(product.tier), tostring(product.robux))) -- QUEUE-ALL9B 3-4
	end
	if product.paidRandom and type(product.odds) ~= "table" then
		table.insert(reasons, key .. ": 유료 랜덤인데 확률표(odds) 없음 - 구매 전 확률 표시 필수")
	end
	if type(product.productId) ~= "number" or type(product.robux) ~= "number" then
		table.insert(reasons, key .. ": productId · robux 숫자 아님")
	end
	return #reasons == 0, reasons
end

-- QUEUE-ALL6 H: 지금 팔리는가(seasonMonth = 그 달(KST)에만 판매 - 할로윈 10월). 산 사람은 계속 가진다 · 장착도 된다(판매만 막음).
function Monetization.onSale(cosmetics, kind, id, unixNow)
	local entry = Monetization.findCosmetic(cosmetics, kind, id)
	if type(entry) ~= "table" or not entry.seasonMonth then
		return true
	end
	return tonumber(os.date("!%m", (unixNow or os.time()) + 9 * 3600)) == entry.seasonMonth
end

-- 상품 키 → 그 상품이 주는 치장(첫 grant) - 판매 기간 검사용
function Monetization.productCosmetic(product)
	local g = type(product) == "table" and type(product.grants) == "table" and product.grants[1]
	if g and (g.kind == "cosmeticTheme" or g.kind == "gliderSkin" or g.kind == "cosmeticItem") then
		return g.kind, g.id
	end
	return nil
end

-- QUEUE-ALL1 R1: 시즌 한정 치장(seasonOnly = 시즌 번호)이면 그 번호 · 아니면 nil - 상품 · 반짝 조각 · 선물로 못 준다(시즌 줄만)
function Monetization.seasonOnly(cosmetics, kind, id)
	local entry = Monetization.findCosmetic(cosmetics, kind, id)
	return type(entry) == "table" and entry.seasonOnly or nil
end

-- ── QUEUE-ALL9B 3 꾸미기 토큰(id sparkleShard) ──
-- 로벅스 가격 → 토큰 가격(식 = MonetizationData.tokenPrice 한 곳 · 499R$급 = tokenPricing.premiumTokens)
function Monetization.tokenPriceForRobux(data, robux)
	if type(robux) ~= "number" or robux <= 0 then
		return nil
	end
	return data.tokenPrice(robux)
end
-- 토큰으로 못 사는 치장인가: 시즌 한정(seasonOnly) · 시즌 패스 보상 전용(passOnly) · 출석판 전용(boardOnly). 반환 = 이유 | nil
function Monetization.tokenBlocked(cosmetics, kind, id)
	local entry = Monetization.findCosmetic(cosmetics, kind, id)
	if type(entry) ~= "table" then
		return nil
	end
	if entry.seasonOnly then
		return "season_only"
	elseif entry.passOnly then
		return "pass_only"
	elseif entry.boardOnly then
		return "board_only"
	end
	return nil
end
-- 상품 하나의 토큰 가격(치장만 · 토큰 불가 치장이 하나라도 있으면 nil + 이유). 상점 "가격 옆 토큰가"(3-7)와 서버 구매가 같은 함수.
function Monetization.productTokenPrice(data, cosmetics, key)
	local product = data.products[key]
	if type(product) ~= "table" or type(product.grants) ~= "table" or #product.grants == 0 then
		return nil, "unknown"
	end
	for _, g in ipairs(product.grants) do
		if g.kind ~= "cosmeticTheme" and g.kind ~= "gliderSkin" and g.kind ~= "cosmeticItem" then
			return nil, "not_cosmetic" -- 시즌 유료 줄 = 로벅스만
		end
		if not Monetization.findCosmetic(cosmetics, g.kind, g.id) then
			return nil, "unknown"
		end
		local blocked = Monetization.tokenBlocked(cosmetics, g.kind, g.id)
		if blocked then
			return nil, blocked
		end
	end
	return Monetization.tokenPriceForRobux(data, product.robux), nil
end
-- 도감 · 상점 "다음 499급까지 n토큰"(3-7): 가진 토큰 → { price = 499급 토큰가, need = 모자란 토큰, ratio = 0 ~ 1 }
function Monetization.premiumTokenProgress(data, balance)
	balance = type(balance) == "number" and balance == balance and math.max(0, balance) or 0
	local price = Monetization.tokenPriceForRobux(data, data.tokenPricing.premiumRobux)
	return { price = price, need = math.max(0, price - balance), ratio = math.min(1, balance / price) }
end

-- 치장 찾기(CosmeticSlotData). kind = cosmeticTheme | gliderSkin | cosmeticItem(QUEUE-ALL6 H 꾸미기 소품)
function Monetization.findCosmetic(cosmetics, kind, id)
	local list = kind == "cosmeticTheme" and cosmetics.sets or kind == "gliderSkin" and cosmetics.gliderSkins or kind == "cosmeticItem" and cosmetics.items or nil
	for _, entry in ipairs(list or {}) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- 시즌 패스 줄 규칙: 유료 줄 = 판매 금지 밖 + 치장 · 치장 재화만 · 알(랜덤) 없음 / 무료 줄 = 알 허용(무료 랜덤) · 판매 금지 종류도 무료 보상이라 막지 않는다(골드 등은 지금 없음).
local PAID_ROW_KINDS = { sparkleShard = true, cosmeticTheme = true, gliderSkin = true, cosmeticItem = true }
Monetization.PAID_ROW_KINDS = PAID_ROW_KINDS -- 리뷰 중요 2: 서버가 유료 줄을 지급할 때도 같은 표로 막는다
local FREE_ROW_KINDS = { sparkleShard = true, cosmeticTheme = true, gliderSkin = true, cosmeticItem = true, egg = true }
-- 한 칸 보상의 줄 규칙(QUEUE-ALL9A 1-3: 40칸 표 · 보너스 칸이 같은 검사)
local function checkRowReward(reasons, data, cosmetics, rowName, reward, label)
	for _, grant in ipairs(Monetization.rewardToGrants(reward)) do
		if rowName == "paid" then
			if grant.kind == "egg" then
				table.insert(reasons, label .. ": 유료 줄에 알(랜덤)")
			else
				local ok, why = Monetization.checkGrant(data, grant, PAID_ROW_KINDS)
				if not ok then
					table.insert(reasons, label .. ": " .. why)
				end
			end
		elseif not FREE_ROW_KINDS[grant.kind] then
			table.insert(reasons, ("%s: 무료 줄 모르는 종류 %s"):format(label, grant.kind))
		end
		if (grant.kind == "cosmeticTheme" or grant.kind == "gliderSkin") and not Monetization.findCosmetic(cosmetics, grant.kind, grant.id) then
			table.insert(reasons, ("%s: 없는 치장 %s"):format(label, tostring(grant.id)))
		end
	end
end
function Monetization.checkSeasonPass(data, season, cosmetics)
	local reasons = {}
	for tier = 1, season.tiers do
		for _, rowName in ipairs({ "free", "paid" }) do
			local reward = season.rows[rowName][tier]
			for _, e in ipairs(season.seasonLimited or {}) do -- QUEUE-ALL1 R1: 한정 칸의 그 시즌 보상도 같은 규칙으로 본다
				if e.row == rowName and e.tier == tier then
					for _, grant in ipairs(Monetization.rewardToGrants(e.reward)) do
						if (grant.kind == "cosmeticTheme" or grant.kind == "gliderSkin") and not Monetization.findCosmetic(cosmetics, grant.kind, grant.id) then
							table.insert(reasons, ("%s %d칸(시즌 %d 한정): 없는 치장 %s"):format(rowName, tier, e.season, tostring(grant.id)))
						end
					end
				end
			end
			if type(reward) ~= "table" then
				table.insert(reasons, ("%s %d칸: 보상 없음"):format(rowName, tier))
				continue
			end
			checkRowReward(reasons, data, cosmetics, rowName, reward, ("%s %d칸"):format(rowName, tier))
		end
	end
	for _, rowName in ipairs({ "free", "paid" }) do -- QUEUE-ALL9A 1-3: 40칸 뒤 반복 보너스 칸도 같은 줄 규칙
		if season.bonus then
			if type(season.bonus[rowName]) ~= "table" then
				table.insert(reasons, rowName .. " 보너스 칸: 보상 없음")
			else
				checkRowReward(reasons, data, cosmetics, rowName, season.bonus[rowName], rowName .. " 보너스 칸")
			end
		end
	end
	return #reasons == 0, reasons
end

-- 전체 카탈로그(서버 시작 때 1회 - 거부된 상품은 판매 목록에서 뺀다). 반환: ok, 이유 목록, 통과한 상품 key 집합
function Monetization.checkCatalog(data, cosmetics, season)
	local reasons, valid = {}, {}
	local keys = {}
	for key in pairs(data.products) do
		table.insert(keys, key)
	end
	table.sort(keys)
	local seenIds = {}
	for _, key in ipairs(keys) do
		local product = data.products[key]
		local ok, why = Monetization.checkProduct(data, key, product, cosmetics)
		if ok and product.productId ~= 0 then
			if seenIds[product.productId] then
				ok, why = false, { ("%s: productId %d 중복(%s)"):format(key, product.productId, seenIds[product.productId]) }
			end
			seenIds[product.productId] = key
		end
		if ok then
			valid[key] = true
		else
			for _, line in ipairs(why) do
				table.insert(reasons, line)
			end
		end
	end
	if season then
		local ok, why = Monetization.checkSeasonPass(data, season, cosmetics)
		if not ok then
			for _, line in ipairs(why) do
				table.insert(reasons, line)
			end
		end
	end
	return #reasons == 0, reasons, valid
end

function Monetization.productKeyById(data, productId)
	if type(productId) ~= "number" or productId == 0 then
		return nil
	end
	for key, product in pairs(data.products) do
		if product.productId == productId then
			return key
		end
	end
	return nil
end

function Monetization.passKeyById(data, passId)
	if type(passId) ~= "number" or passId == 0 then
		return nil
	end
	for key, pass in pairs(data.gamePasses) do
		if pass.passId == passId then
			return key
		end
	end
	return nil
end

-- 유료 랜덤 정책: 제한 대상(restricted = true · 조회 실패 = failClosed면 true)에게 paidRandom 상품은 안 판다.
function Monetization.paidRandomAllowed(product, restricted)
	if not product or not product.paidRandom then
		return true
	end
	return restricted == false
end

-- 영수증 기록(profile.purchases). 반환: "new"(처음 - 지급해도 된다) | "duplicate"(이미 지급 - 다시 주지 않고 PurchaseGranted만).
--   receipts = { { id = PurchaseId(문자열), at } } 최근 keep개 · 옛것부터 버린다. 기록은 지급과 **같은 저장**에 들어가야 한다(서버가 지급 뒤 저장 성공을 확인하고 Granted).
function Monetization.hasReceipt(purchases, purchaseId)
	for _, r in ipairs(purchases.receipts) do
		if r.id == purchaseId then
			return true
		end
	end
	return false
end
function Monetization.recordReceipt(purchases, purchaseId, now, keep)
	purchaseId = tostring(purchaseId)
	if Monetization.hasReceipt(purchases, purchaseId) then
		return "duplicate"
	end
	table.insert(purchases.receipts, { id = purchaseId, at = now })
	while #purchases.receipts > keep do
		table.remove(purchases.receipts, 1)
	end
	return "new"
end
-- 되돌리기(지급 뒤 저장이 실패하면 기록도 빼서 다음 재시도 때 다시 지급 - 지급 자체도 되돌린다)
function Monetization.forgetReceipt(purchases, purchaseId)
	purchaseId = tostring(purchaseId)
	for i = #purchases.receipts, 1, -1 do
		if purchases.receipts[i].id == purchaseId then
			table.remove(purchases.receipts, i)
		end
	end
end
function Monetization.appendLog(purchases, entry, keep)
	table.insert(purchases.log, entry)
	while #purchases.log > keep do
		table.remove(purchases.log, 1)
	end
end

-- 시즌 칸: 경험치 → 도달한 칸(0 ~ tiers)
function Monetization.seasonTier(exp, expPerTier, tiers)
	exp = type(exp) == "number" and exp == exp and exp or 0
	return math.clamp(math.floor(math.max(exp, 0) / expPerTier), 0, tiers)
end
-- QUEUE-ALL9A 1-3: 상한 없는 도달 칸(41 이상 = 반복 보너스 칸) · 보너스 횟수 = max(0, 도달 - tiers)
function Monetization.seasonReach(exp, expPerTier)
	exp = type(exp) == "number" and exp == exp and exp or 0
	return math.floor(math.max(exp, 0) / expPerTier)
end
-- 받을 수 있나: 도달 · 안 받음 · 유료 줄은 이번 시즌 유료. bonus = true면 tiers 뒤 칸(보너스)도 받는다(reachedTier = seasonReach - 상한 없음)
function Monetization.canClaim(pass, rowName, tier, reachedTier, tiers, bonus)
	if type(tier) ~= "number" or tier ~= math.floor(tier) or tier < 1 or (tier > tiers and not bonus) then
		return false, "bad_tier"
	end
	if rowName ~= "free" and rowName ~= "paid" then
		return false, "bad_row"
	end
	if tier > reachedTier then
		return false, "not_reached"
	end
	if rowName == "paid" and not pass.premium then
		return false, "not_premium"
	end
	local claimed = rowName == "free" and pass.claimedFree or pass.claimedPaid
	if claimed[tostring(tier)] then
		return false, "claimed"
	end
	return true
end

-- QUEUE-ALL9A 1-2 주말 2배 창(서버 UTC 시각만 - 클라 시계 · 시간대 안 씀). w = SeasonPassData.weekend.
--   반환: 지금 창 안인가, 그 창(또는 다음 창)의 시작 · 끝(유닉스 초). 1970-01-04 = 일요일 → (now - 3일) % 주 = 일요일 00:00 UTC부터 초.
local WEEK = 7 * 86400
function Monetization.weekendWindow(now, w)
	local sunday = now - (now - 3 * 86400) % WEEK
	local startAt = sunday + w.startSec
	if now >= startAt then
		return true, startAt, startAt + w.lengthSec
	end
	local prev = startAt - WEEK -- 지난주 창이 월요일까지 이어진다
	if now < prev + w.lengthSec then
		return true, prev, prev + w.lengthSec
	end
	return false, startAt, startAt + w.lengthSec
end
-- 패스 경험치 배율(source = 퀘스트 받기 종류 login | daily | chest | weekly …): 창 안 + 2배 출처만 w.mult
function Monetization.passExpMultiplier(source, active, w)
	return (active and w.sources[source]) and w.mult or 1
end

return Monetization
