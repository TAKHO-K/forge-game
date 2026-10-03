-- 상점 [치장] 탭(QUEUE-B1 B2 UI). 치장은 반짝 조각 또는 로벅스로만 산다 - **골드 가격은 표시하지 않는다**(서버 CosmeticService도 골드를 받지 않는다).
--   ① 조각 잔액 · 받을 선물 ② 테마 세트 3(4칸 해금) ③ 글라이더 스킨 2 - 각각 보유 표시 · [조각 n] · [로벅스 n](준비 중 = 회색) ④ 칸 5개 장착 고르기(산 것 중 · 기본으로 되돌리기)
--   ⑤ 이름표 색(편의 패스가 있을 때만). 요청 = ShopRequest(buyShards · buyRobux · equip · giftClaim) · 화면 = ShopSync 표(MonetizationService.view) 그대로.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)

local CosmeticTab = {}

local function nameOf(kind, id)
	local list = kind == "cosmeticTheme" and CosmeticSlotData.sets or kind == "cosmeticItem" and CosmeticSlotData.items or CosmeticSlotData.gliderSkins
	for _, entry in ipairs(list) do
		if entry.id == id then
			return Text.name(entry.name)
		end
	end
	return tostring(id)
end
CosmeticTab.nameOf = nameOf

-- 판매 행 하나(테마 세트 · 글라이더 공통). kind = "cosmeticTheme" | "gliderSkin" · productKey = MonetizationData.products 키
local TRY_ITEM_SLOTS = { weaponSkin = true, petAccessory = true } -- QUEUE-ALL6 H 입혀 보기 = 내 화면 Attribute만 바꿔 바로 보이는 칸(처치 · 강화 · 귀환 · 이모트는 서버 사건이 있어야 보임)
local function saleRow(ctx, env, view, kind, entry, owned, shardPrice, productKey, subtitleKey)
	local buttons
	if owned then
		buttons = { { name = "Owned_" .. entry.id, text = Text.get("shop.owned"), enabled = false } }
	elseif not Monetization.onSale(CosmeticSlotData, kind, entry.id) then -- QUEUE-ALL6 H 시즌 한정(할로윈 = 10월) 판매 기간 밖
		buttons = { { name = "OffSeason_" .. entry.id, text = Text.get("shop.cos.offSeason", { month = tostring(entry.seasonMonth) }), width = 140, enabled = false } }
	else
		buttons = {}
		if shardPrice then -- QUEUE-ALL9B 3-7: 상품마다 토큰가(서버 view.productTokens - 토큰 불가 = 버튼 없음)
			table.insert(buttons, { name = "Shards_" .. entry.id, text = Text.get("shop.shardPrice", { n = tostring(shardPrice) }), kind = "primary",
				enabled = (view.shards or 0) >= shardPrice and not env.busy(), onActivated = function()
					env.send("buyShards", kind, entry.id)
				end })
		end
		table.insert(buttons, env.robuxButton(productKey, "Robux_" .. entry.id))
		if kind ~= "cosmeticItem" or TRY_ITEM_SLOTS[entry.slot] then
			table.insert(buttons, { name = "Try_" .. entry.id, text = Text.get("shop.cos.try"), width = 84, enabled = true, onActivated = function() -- QUEUE-ALL2 P2 B-4 ①: 내 캐릭터에 입혀 보기(로컬 · 잠깐)
				env.preview(kind, entry)
			end })
		end
	end
	ctx.row({
		name = "Sale_" .. entry.id,
		title = Text.name(entry.name),
		titleColor = owned and "success" or nil,
		subtitle = Text.get(owned and "shop.cos.ownedSub" or subtitleKey),
		buttons = buttons,
	})
end

CosmeticTab.saleRow = saleRow

-- 장착 칩 줄: 기본 + 산 것. current = 지금 장착 id(nil = 기본)
local function equipChips(ctx, env, slotId, current, options)
	local chips = { { name = ("Equip_%s_default"):format(slotId), text = Text.get("shop.cos.default"), selected = current == nil, enabled = not env.busy(), onActivated = function()
		if current ~= nil then
			env.send("equip", slotId, nil)
		end
	end } }
	for _, option in ipairs(options) do
		table.insert(chips, { name = ("Equip_%s_%s"):format(slotId, option.id), text = option.text, swatch = option.swatch, selected = current == option.id,
			enabled = not env.busy(), onActivated = function()
				if current ~= option.id then
					env.send("equip", slotId, option.id)
				end
			end })
	end
	ctx.chips("Chips_" .. slotId, chips)
end

function CosmeticTab.render(ctx, env)
	local view = env.state.view
	if not view then
		ctx.line(Text.get("shop.loading"), "textSecondary", 1, "Loading")
		return
	end
	ctx.line(Text.get("shop.cos.balance", { n = tostring(view.shards or 0) }), "gold", 1, "Balance")
	ctx.line(Text.get("shop.cos.noGold"), "textSecondary", 1, "NoGold")
	if (view.gifts or 0) > 0 then
		ctx.row({
			name = "Gifts",
			title = Text.get("gift.pending", { n = tostring(view.gifts) }),
			highlight = true,
			buttons = { { name = "GiftsClaim", text = Text.get("gift.claimAll"), kind = "primary", width = 110, enabled = not env.busy(), onActivated = function()
				env.send("giftClaim", "all")
			end } },
		})
	end

	ctx.section(Text.get("shop.cos.themeSection"), "ThemeSection")
	for _, set in ipairs(CosmeticSlotData.sets) do
		if set.seasonOnly or set.passOnly or set.boardOnly then
			continue -- QUEUE-ALL9B 패스 · 출석판 전용 테마 = 판매 줄 없음
		end
		saleRow(ctx, env, view, "cosmeticTheme", set, view.themes and view.themes[set.id] == true, (view.productTokens or {})["theme_" .. set.id], "theme_" .. set.id, "shop.cos.themeSub")
	end
	ctx.section(Text.get("shop.cos.gliderSection"), "GliderSection")
	for _, skin in ipairs(CosmeticSlotData.gliderSkins) do
		if skin.seasonOnly or skin.passOnly or skin.boardOnly then
			continue -- QUEUE-ALL1 R1: 시즌 한정(구름 고래) · QUEUE-ALL9B 패스 · 출석판 전용 = 판매 줄 없음(시즌 탭 · 장착 칩에만)
		end
		saleRow(ctx, env, view, "gliderSkin", skin, view.gliderSkins and view.gliderSkins[skin.id] == true, (view.productTokens or {})["glider_" .. skin.id], "glider_" .. skin.id, "shop.cos.gliderSub")
	end
	-- QUEUE-ALL6 H 소품(칸 하나짜리) - 칸별 묶음
	ctx.section(Text.get("shop.cos.itemSection"), "ItemSection")
	for _, slotId in ipairs(CosmeticSlotData.itemSlots) do
		ctx.line(Text.get("shop.slot." .. slotId), "textSecondary", 1, "ItemSlot_" .. slotId)
		for _, item in ipairs(CosmeticSlotData.items) do
			if item.slot == slotId and not (item.seasonOnly or item.passOnly or item.boardOnly) then -- QUEUE-ALL9B 패스 · 출석판 전용 = 판매 줄 없음
				saleRow(ctx, env, view, "cosmeticItem", item, view.items and view.items[item.id] == true, (view.productTokens or {})["item_" .. item.id], "item_" .. item.id, "shop.cos.itemSub." .. slotId)
			end
		end
	end

	ctx.section(Text.get("shop.cos.equipSection"), "EquipSection")
	local equipped = view.equipped or {}
	for _, slot in ipairs(CosmeticSlotData.slots) do
		local isGlider = slot.id == "gliderSkin"
		local isItem = table.find(CosmeticSlotData.itemSlots, slot.id) ~= nil -- QUEUE-ALL6 H 소품 칸
		local options = {}
		for _, entry in ipairs(isGlider and CosmeticSlotData.gliderSkins or isItem and CosmeticSlotData.items or CosmeticSlotData.sets) do
			local owned
			if isItem then
				owned = entry.slot == slot.id and view.items and view.items[entry.id]
			else
				owned = isGlider and view.gliderSkins[entry.id] or (not isGlider and view.themes[entry.id])
			end
			if owned then
				table.insert(options, { id = entry.id, text = Text.name(entry.name) })
			end
		end
		local current = equipped[slot.id]
		ctx.line(Text.get("shop.cos.slotLine", { slot = Text.get("shop.slot." .. slot.id),
			current = current and nameOf(isGlider and "gliderSkin" or isItem and "cosmeticItem" or "cosmeticTheme", current) or Text.get("shop.cos.default") }), "textPrimary", 1, "Slot_" .. slot.id)
		if #options == 0 then
			ctx.line(Text.get(isGlider and "shop.cos.noGlider" or isItem and "shop.cos.noItem" or "shop.cos.noTheme"), "textSecondary", 1, "SlotEmpty_" .. slot.id)
		else
			equipChips(ctx, env, slot.id, current, options)
		end
	end

	ctx.section(Text.get("shop.cos.nameplateSection"), "NameplateSection")
	local pass = view.passes and view.passes.nameplateColor
	if pass and pass.owned then
		local options = {}
		for _, colorName in ipairs(view.nameplateColors or {}) do
			table.insert(options, { id = colorName, text = Text.get("shop.color." .. colorName), swatch = UIColors[colorName] })
		end
		ctx.line(Text.get("shop.cos.slotLine", { slot = Text.get("shop.slot.nameplateColor"),
			current = equipped.nameplateColor and Text.get("shop.color." .. equipped.nameplateColor) or Text.get("shop.cos.default") }), "textPrimary", 1, "Slot_nameplateColor")
		equipChips(ctx, env, "nameplateColor", equipped.nameplateColor, options)
	else
		ctx.line(Text.get("shop.cos.nameplateLocked"), "textSecondary", 1, "NameplateLocked")
	end
	-- QUEUE-ALL1 P6 이름표 배지(패스 있을 때 4개 중 고르기 · 없음 = 기본)
	ctx.section(Text.get("shop.cos.badgeSection"), "BadgeSection")
	local badgePass = view.passes and view.passes.nameplateBadge
	if badgePass and badgePass.owned then
		local options = {}
		for _, badgeId in ipairs(view.nameplateBadges or {}) do
			table.insert(options, { id = badgeId, text = Text.get("shop.badge." .. badgeId) })
		end
		ctx.line(Text.get("shop.cos.slotLine", { slot = Text.get("shop.slot.nameplateBadge"),
			current = equipped.nameplateBadge and Text.get("shop.badge." .. equipped.nameplateBadge) or Text.get("shop.cos.default") }), "textPrimary", 1, "Slot_nameplateBadge")
		equipChips(ctx, env, "nameplateBadge", equipped.nameplateBadge, options)
	else
		ctx.line(Text.get("shop.cos.badgeLocked"), "textSecondary", 1, "BadgeLocked")
	end
end

return CosmeticTab
