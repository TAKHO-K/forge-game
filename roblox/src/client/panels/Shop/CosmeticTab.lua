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
-- QUEUE-ALL9B 테마 미리보기 순서(칸 · 이름 · 확인 키) - 한 번 누를 때 하나씩
CosmeticTab.themeParts = {
	{ slot = "dashTrail", key = "shop.slot.dashTrail", input = "Shift" },
	{ slot = "jumpFx", key = "shop.slot.jumpFx", input = "Space" },
	{ slot = "glideTrail", key = "shop.slot.glideTrail", input = "Space × 2" },
	{ slot = "footstep", key = "shop.slot.footstep", input = "W" },
}
local TRY_ITEM_SLOTS = { weaponSkin = true, petAccessory = true } -- QUEUE-ALL6 H 입혀 보기 = 내 화면 Attribute만 바꿔 바로 보이는 칸(처치 · 강화 · 귀환 · 이모트는 서버 사건이 있어야 보임)
local function saleRow(ctx, env, view, kind, entry, owned, shardPrice, productKey, subtitleKey)
	local buttons
	local info = { title = Text.name(entry.name), body = Text.get(subtitleKey, { name = Text.name(entry.name) }) } -- QUEUE-ALL9C 1-6 결제 확인 창 = 구성
	if owned then
		-- QUEUE-ALL9B(사용자 10-03): 산 것은 구매칸 전체를 덮는다 · QUEUE-ALL9C 1-6 X6: 이번 창에서 산 것 = "구매 완료" · 원래 가진 것 = "보유 중 ✓"
		buttons = { { name = "Owned_" .. entry.id, text = Text.get(env.state.justBought[entry.id] and "shop.cos.soldOut" or "shop.ownedCheck"), width = 296, enabled = false } }
	elseif not Monetization.onSale(CosmeticSlotData, kind, entry.id) then -- QUEUE-ALL6 H 시즌 한정(할로윈 = 10월) 판매 기간 밖
		buttons = { { name = "OffSeason_" .. entry.id, text = Text.get("shop.cos.offSeason", { month = tostring(entry.seasonMonth) }), width = 140, enabled = false } }
	else
		buttons = {}
		if shardPrice then -- QUEUE-ALL9B 3-7: 상품마다 토큰가(서버 view.productTokens - 토큰 불가 = 버튼 없음)
			table.insert(buttons, { name = "Shards_" .. entry.id, text = Text.get("shop.priceNumber", { n = tostring(shardPrice) }), icon = "token", kind = "primary",
				enabled = (view.shards or 0) >= shardPrice and not env.busy(), onActivated = function()
					env.send("buyShards", kind, entry.id)
				end })
		end
		table.insert(buttons, env.robuxButton(productKey, "Robux_" .. entry.id, info))
		if kind ~= "cosmeticItem" then -- QUEUE-ALL9C 1-6 X6: [미리보기] = 3D 창(내 아바타 복제 · 돌려 보기 · 구성품 켜고 끄기 · 안에 [직접 보기] = 옛 내 캐릭터 입혀 보기)
			table.insert(buttons, { name = "Preview3D_" .. entry.id, text = Text.get("shop.preview3d"), width = 96, enabled = true, onActivated = function()
				env.openPreview(kind, entry)
			end })
		elseif TRY_ITEM_SLOTS[entry.slot] then -- 소품(무기 · 펫 칸) = 내 캐릭터에 잠깐 입혀 보기(QUEUE-ALL2 P2 B-4 ①)
			table.insert(buttons, { name = "Try_" .. entry.id, text = Text.get("shop.cos.try"), width = 84, enabled = true, onActivated = function()
				env.preview(kind, entry)
			end })
		end
	end
	ctx.row({
		name = "Sale_" .. entry.id,
		title = Text.name(entry.name),
		titleColor = owned and "success" or nil,
		subtitle = Text.get(owned and "shop.cos.ownedSub" or subtitleKey, { name = Text.name(entry.name) }),
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

-- QUEUE-ALL9C 1-6: 한 페이지 구역 = renderHeader(잔액 · 선물) + renderThemes · renderGliders · renderItems · renderEquip(장착 · 이름표). 스타터 전용(starterOnly) = 판매 줄 없음.
local function forSale(entry)
	return not (entry.seasonOnly or entry.passOnly or entry.boardOnly or entry.starterOnly)
end
local function released(view, productKey)
	local p = view.products and view.products[productKey]
	return p ~= nil and p.released ~= false -- 순차 공개(서버 view.products[].released) - 비공개 = 줄 없음
end
function CosmeticTab.renderHeader(ctx, env)
	local view = env.state.view
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

end
function CosmeticTab.renderThemes(ctx, env)
	local view = env.state.view
	for _, set in ipairs(CosmeticSlotData.sets) do
		if forSale(set) and released(view, "theme_" .. set.id) then -- QUEUE-ALL9B 패스 · 출석판 전용 · QUEUE-ALL9C 스타터 전용 · 비공개 = 판매 줄 없음
			saleRow(ctx, env, view, "cosmeticTheme", set, view.themes and view.themes[set.id] == true, (view.productTokens or {})["theme_" .. set.id], "theme_" .. set.id, "shop.cos.themeSub")
		end
	end
end
function CosmeticTab.renderGliders(ctx, env)
	local view = env.state.view
	for _, skin in ipairs(CosmeticSlotData.gliderSkins) do
		if forSale(skin) and released(view, "glider_" .. skin.id) then -- QUEUE-ALL1 R1: 시즌 한정(구름 고래) · 패스 · 출석판 전용 = 판매 줄 없음(시즌 구역 · 장착 칩에만)
			saleRow(ctx, env, view, "gliderSkin", skin, view.gliderSkins and view.gliderSkins[skin.id] == true, (view.productTokens or {})["glider_" .. skin.id], "glider_" .. skin.id, "shop.cos.gliderSub")
		end
	end
end
-- QUEUE-ALL6 H 소품(칸 하나짜리) - 칸별 묶음
function CosmeticTab.renderItems(ctx, env)
	local view = env.state.view
	for _, slotId in ipairs(CosmeticSlotData.itemSlots) do
		local any = false
		for _, item in ipairs(CosmeticSlotData.items) do
			if item.slot == slotId and forSale(item) and released(view, "item_" .. item.id) then
				if not any then
					ctx.line(Text.get("shop.slot." .. slotId), "textSecondary", 1, "ItemSlot_" .. slotId)
					any = true
				end
				saleRow(ctx, env, view, "cosmeticItem", item, view.items and view.items[item.id] == true, (view.productTokens or {})["item_" .. item.id], "item_" .. item.id, "shop.cos.itemSub." .. slotId)
			end
		end
	end
end

function CosmeticTab.renderEquip(ctx, env)
	local view = env.state.view
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
				owned = isGlider and view.gliderSkins[entry.id] or (not isGlider and view.themes[entry.id] and (not entry.looks or entry.looks[slot.id] ~= "")) -- QUEUE-ALL9C 1-6: 그 칸 모양이 없는 세트(스타터 별빛 = 대시만) 제외
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
