-- 상점 카드 내용(QUEUE-ALL9C 1-6R · 사용자 10-03): 상품 · 게임패스 → Card spec(이름 · 칸 · 가격급 · NEW · 보유/착용 · 가격 버튼 · 정지 그림). 모든 탭이 이 함수들로 카드를 만든다.
--   치장 하위 칩(테마 세트 · 글라이더 · 처치 이펙트 · 무기 스킨 · 이모트 · 펫 꾸미기 · 이름표 · 연출) = CHIPS 표 · 공개 상품 0개 칩은 숨긴다(chipEntries가 빈 목록).
--   그림 = 정지 ViewportFrame(테마 = 칸 4개 모양 · 글라이더 = 실제 모양) 또는 아이콘 · 글자 칸 - 회전 없음(스크롤 성능).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local ArtImage = require(script.Parent.Parent.Parent.ui.ArtImage)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local PriceCache = require(script.Parent.Parent.Parent.ui.PriceCache)

local Catalog = {}

local LIST = { cosmeticTheme = "sets", gliderSkin = "gliderSkins", cosmeticItem = "items" }
local OWNED = { cosmeticTheme = "themes", gliderSkin = "gliderSkins", cosmeticItem = "items" }

-- 치장 탭 하위 칩: 상품 고르기(match) · 장착 칸(slots - 칸별 장착 칩) · 이름표 = 게임패스 카드
Catalog.CHIPS = {
	{ id = "theme", kinds = { cosmeticTheme = true }, bundles = true, slots = CosmeticSlotData.setSlots },
	{ id = "glider", kinds = { gliderSkin = true }, slots = { "gliderSkin" } },
	{ id = "killFx", itemSlots = { killFx = true }, slots = { "killFx" } },
	{ id = "weaponSkin", itemSlots = { weaponSkin = true }, slots = { "weaponSkin" } },
	{ id = "emote", itemSlots = { emote = true }, slots = { "emote" } },
	{ id = "petAccessory", itemSlots = { petAccessory = true }, slots = { "petAccessory" } },
	{ id = "nameplate", passes = { "nameplateColor", "nameplateBadge", "nameplateSet" }, nameplate = true },
	{ id = "fx", itemSlots = { enhanceFx = true, recallFx = true }, slots = { "enhanceFx", "recallFx" } },
}

local function forSale(entry)
	return not (entry.seasonOnly or entry.passOnly or entry.boardOnly or entry.starterOnly)
end

local function now()
	return workspace:GetServerTimeNow()
end

-- 상품 키 → 첫 구성품(kind · entry)
function Catalog.firstGrant(key)
	local product = MonetizationData.products[key]
	local g = product and product.grants and product.grants[1]
	if g and LIST[g.kind] then
		return g.kind, Monetization.findCosmetic(CosmeticSlotData, g.kind, g.id)
	end
	return nil, nil
end

-- 상품 하나가 화면에 보이나(공개 · 판매용 치장)
function Catalog.productVisible(view, key)
	local p = view.products and view.products[key]
	if not p or p.released == false then
		return false
	end
	local product = MonetizationData.products[key]
	for _, g in ipairs(product.grants or {}) do
		local entry = LIST[g.kind] and Monetization.findCosmetic(CosmeticSlotData, g.kind, g.id)
		if not entry or not forSale(entry) then
			return false
		end
	end
	return true
end

-- 칩 하나의 카드 목록: { { key = 상품 키 } | { pass = 게임패스 키 } }
function Catalog.chipEntries(view, chip)
	local out = {}
	if chip.passes then
		for _, key in ipairs(chip.passes) do
			if Catalog.passVisible(view, key) then
				table.insert(out, { pass = key })
			end
		end
		return out
	end
	local keys = {}
	for key in pairs(MonetizationData.products) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b) -- 묶음(대표) 먼저 · 그다음 가격 높은 순 · 이름
		local pa, pb = MonetizationData.products[a], MonetizationData.products[b]
		local ba, bb = #(pa.grants or {}) > 1, #(pb.grants or {}) > 1
		if ba ~= bb then
			return ba
		end
		if pa.robux ~= pb.robux then
			return pa.robux > pb.robux
		end
		return a < b
	end)
	for _, key in ipairs(keys) do
		local product = MonetizationData.products[key]
		local grants = product.grants or {}
		local g = grants[1]
		local bundle = #grants > 1 and not product.starterPack
		local match = g and ((bundle and chip.bundles) or (not bundle and #grants == 1 and (
			(chip.kinds and chip.kinds[g.kind]) or (chip.itemSlots and g.kind == "cosmeticItem" and chip.itemSlots[(Monetization.findCosmetic(CosmeticSlotData, g.kind, g.id) or {}).slot]))))
		if match and Catalog.productVisible(view, key) then
			table.insert(out, { key = key })
		end
	end
	return out
end

function Catalog.passVisible(view, key)
	local pass = view.passes and view.passes[key]
	if not pass or pass.released == false then
		return false
	end
	for _, other in ipairs(MonetizationData.gamePasses[key].onlyWithout or {}) do -- 이름표 세트 = 색 · 배지 둘 다 없는 사람에게만
		if view.passes[other] and view.passes[other].owned == true then
			return false
		end
	end
	return true
end

-- 상품 보유(구성품 전부) · 착용(테마 = 모양 있는 칸 전부 · 글라이더 · 소품 = 그 칸)
function Catalog.ownership(view, key)
	local product = MonetizationData.products[key]
	local owned, equipped = true, true
	for _, g in ipairs(product.grants or {}) do
		if not (view[OWNED[g.kind] or ""] or {})[g.id] then
			owned = false
		end
		local entry = LIST[g.kind] and Monetization.findCosmetic(CosmeticSlotData, g.kind, g.id)
		local eq = view.equipped or {}
		if g.kind == "cosmeticTheme" then
			for _, slot in ipairs(CosmeticSlotData.setSlots) do
				if entry and entry.looks and entry.looks[slot] ~= "" and eq[slot] ~= g.id then
					equipped = false
				end
			end
		elseif g.kind == "gliderSkin" then
			equipped = equipped and eq.gliderSkin == g.id
		elseif g.kind == "cosmeticItem" then
			equipped = equipped and entry ~= nil and eq[entry.slot] == g.id
		else
			equipped = false
		end
	end
	return owned, owned and equipped
end

-- ── 정지 그림 ──
local function viewport(holder, build, distance, height)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Viewport"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(170, 170, 180)
	vp.LightColor = Color3.fromRGB(255, 255, 250)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	vp.Parent = holder
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = vp
	vp.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local center = build(world) or Vector3.zero
	camera.CFrame = CFrame.lookAt(center + Vector3.new(distance * 0.7, height, distance * 0.7), center)
	return vp
end

local function themePicture(entry)
	return function(holder)
		viewport(holder, function(world)
			local Preview3D = require(script.Parent.Preview3D)
			for _, slot in ipairs(CosmeticSlotData.setSlots) do
				local piece = Preview3D.themePiece(slot, entry.looks and entry.looks[slot], CFrame.new(0, 3, 0))
				if piece then
					piece.Parent = world
				end
			end
			return Vector3.new(0, 3.2, 2.5) -- 발자국(바닥) ~ 활강 궤적(머리 위)까지 한 화면
		end, 19, 3)
	end
end

local function gliderPicture(entry)
	return function(holder)
		viewport(holder, function(world)
			local root = Instance.new("Part")
			root.Name = "Root"
			root.Anchored = true
			root.Transparency = 1
			root.Size = Vector3.new(2, 2, 1)
			root.CFrame = CFrame.new()
			root.Parent = world
			local model = Instance.new("Model")
			model.Parent = world
			require(script.Parent.Parent.Parent.GlideView).buildOnto(model, root, entry.id)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			local cf, size = model:GetBoundingBox()
			return cf.Position, size
		end, 13, 3)
	end
end

-- 아이콘 칸(그림 자리 - 감사 뒤 전용 아이콘으로 바뀐다) · text = 큰 글자(편의 패스 효과 값)
function Catalog.iconPicture(path, fallback, text)
	return function(holder)
		if text then
			local l = Theme.label(holder, text, "title", "textPrimary")
			l.Name = "BigText"
			l.Size = UDim2.fromScale(1, 1)
			l.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		local icon = ArtImage.label(holder, path, UDim2.fromScale(0.5, 0.5), fallback) -- 그림 칸의 절반(정사각 - 비율 제약)
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = icon
	end
end

function Catalog.pictureFor(kind, entry)
	if kind == "cosmeticTheme" and entry then
		return themePicture(entry)
	elseif kind == "gliderSkin" and entry then
		return gliderPicture(entry)
	end
	return Catalog.iconPicture("icons/reward/cosmeticTheme", "✦")
end

-- ── 카드 spec ──
local function displayRobux(view, key)
	local p = view.products and view.products[key]
	return PriceCache.get("product", p and p.productId or 0, p and p.robux or MonetizationData.products[key].robux)
end

-- 치장 상품 카드. env = init 환경(send · confirmRobux · openDetail · busy)
function Catalog.productCard(env, key)
	local view = env.state.view
	local product = MonetizationData.products[key]
	local kind, entry = Catalog.firstGrant(key)
	local bundleCount = #(product.grants or {})
	local isBundle = bundleCount > 1
	local owned, equipped = Catalog.ownership(view, key)
	local title = product.name and Text.name(product.name) or (entry and Text.name(entry.name)) or key
	local slotText
	if isBundle then
		slotText = Text.get("shop.card.bundleSlot", { n = tostring(bundleCount) })
	elseif kind == "cosmeticTheme" then
		slotText = Text.get("shop.card.themeSlot")
	elseif kind == "gliderSkin" then
		slotText = Text.get("shop.slot.gliderSkin")
	else
		slotText = Text.get("shop.slot." .. tostring(entry and entry.slot))
	end
	local sum = isBundle and Monetization.bundleComponentSum(MonetizationData, key) or nil
	local robux = displayRobux(view, key)
	local button
	if owned then
		if isBundle then
			button = { state = "owned", enabled = false }
		else
			button = { state = equipped and "equipped" or "equip", kind = "secondary", enabled = not equipped and not env.busy(), onActivated = function()
				env.send("equipAll", kind, entry.id)
			end }
		end
	elseif not isBundle and entry and not Monetization.onSale(CosmeticSlotData, kind, entry.id) then
		button = { text = Text.get("shop.cos.offSeason", { month = tostring(entry.seasonMonth) }), enabled = false }
	else
		button = { currency = "robux", amount = robux, enabled = not env.busy(), onActivated = function()
			env.openDetail(key)
		end }
	end
	return {
		name = "Card_" .. key,
		title = title,
		slotText = slotText,
		strikeText = sum and tostring(sum) or nil,
		picture = Catalog.pictureFor(kind, entry),
		isNew = Monetization.isNew(MonetizationData, key, now()),
		band = Monetization.priceBand(MonetizationData, product.robux),
		owned = owned,
		button = button,
		onOpen = function()
			env.openDetail(key)
		end,
	}
end

-- 편의 패스 카드(그림 = 효과 값 큰 글자) · 누름 = 결제 확인 창(구성 + 환불 문구 ①)
local PASS_TEXT = {
	bagExpand = function(def)
		return "+" .. tostring(def.bonusSlots)
	end,
	pickupRadius = function(def)
		return ("×%g"):format(def.radiusMultiplier)
	end,
	recallCooldown = function(def)
		return ("×%g"):format(def.cooldownMultiplier)
	end,
}
function Catalog.passCard(env, key, title, subtitle)
	local view = env.state.view
	local pass = view.passes[key]
	local def = MonetizationData.gamePasses[key]
	local price = env.passPrice(key) or pass.robux
	local buy = function()
		env.confirmRobux({ title = title, body = subtitle }, price, function()
			env.send("buyPass", key)
		end)
	end
	local button
	if pass.owned then
		button = { state = "owned", enabled = false }
	elseif not pass.ready then
		button = { currency = "robux", amount = price, enabled = false } -- 준비 중(passId 0) = 가격은 보이고 버튼만 꺼짐
	else
		button = { currency = "robux", amount = price, enabled = not env.busy(), onActivated = buy }
	end
	local textFn = PASS_TEXT[key]
	local picture
	if textFn then
		picture = Catalog.iconPicture(nil, nil, textFn(def))
	elseif key == "nameplateColor" or key == "nameplateSet" then
		picture = function(holder) -- 이름표 색 4개 견본
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.AnchorPoint = Vector2.new(0.5, 0.5)
			row.Position = UDim2.fromScale(0.5, 0.5)
			row.Size = UDim2.fromOffset(4 * 22 + 3 * 6, 22)
			row.Parent = holder
			for i, colorName in ipairs(MonetizationData.gamePasses.nameplateColor.colors) do
				local sw = Instance.new("Frame")
				sw.BackgroundColor3 = UIColors[colorName] or Color3.new(1, 1, 1)
				sw.BorderSizePixel = 0
				sw.Position = UDim2.fromOffset((i - 1) * 28, 0)
				sw.Size = UDim2.fromOffset(22, 22)
				sw.Parent = row
				Theme.corner(sw, 11)
			end
		end
	else
		picture = Catalog.iconPicture("icons/reward/title", "★")
	end
	return {
		name = "Pass_" .. key,
		title = title,
		slotText = subtitle,
		picture = picture,
		isNew = Monetization.isNew(MonetizationData, key, now()),
		band = Monetization.priceBand(MonetizationData, def.robux),
		owned = pass.owned == true,
		button = button,
		onOpen = (not pass.owned and pass.ready) and buy or nil,
	}
end

-- 시즌 패스 카드(추천 탭) · 누름 = 시즌 패스 탭
function Catalog.seasonCard(env, robuxButtonSpec)
	local view = env.state.view
	local premium = view.season and view.season.premium
	local product = view.products and view.products.season_premium
	return {
		name = "Card_season",
		title = Text.get("season.premiumTitle"),
		slotText = Text.get("shop.card.seasonSlot"),
		picture = Catalog.iconPicture("icons/reward/passExp", "★"),
		band = Monetization.priceBand(MonetizationData, product and product.robux or 0),
		owned = premium == true,
		button = premium and { state = "owned", enabled = false } or robuxButtonSpec,
		onOpen = function()
			env.selectTab("season")
		end,
	}
end

return Catalog
