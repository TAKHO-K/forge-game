-- 상점 [치장] 탭(QUEUE-B1 B2 UI). 치장은 반짝 조각 또는 로벅스로만 산다 - **골드 가격은 표시하지 않는다**(서버 CosmeticService도 골드를 받지 않는다).
--   ① 조각 잔액 · 받을 선물 ② 테마 세트 3(4칸 해금) ③ 글라이더 스킨 2 - 각각 보유 표시 · [조각 n] · [로벅스 n](준비 중 = 회색) ④ 칸 5개 장착 고르기(산 것 중 · 기본으로 되돌리기)
--   ⑤ 이름표 색(편의 패스가 있을 때만). 요청 = ShopRequest(buyShards · buyRobux · equip · giftClaim) · 화면 = ShopSync 표(MonetizationService.view) 그대로.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)

local CosmeticTab = {}

local function nameOf(kind, id)
	local list = kind == "cosmeticTheme" and CosmeticSlotData.sets or CosmeticSlotData.gliderSkins
	for _, entry in ipairs(list) do
		if entry.id == id then
			return entry.name
		end
	end
	return tostring(id)
end
CosmeticTab.nameOf = nameOf

-- 판매 행 하나(테마 세트 · 글라이더 공통). kind = "cosmeticTheme" | "gliderSkin" · productKey = MonetizationData.products 키
local function saleRow(ctx, env, view, kind, entry, owned, shardPrice, productKey, subtitleKey)
	local buttons
	if owned then
		buttons = { { name = "Owned_" .. entry.id, text = Text.get("shop.owned"), enabled = false } }
	else
		buttons = {
			{ name = "Shards_" .. entry.id, text = Text.get("shop.shardPrice", { n = tostring(shardPrice) }), kind = "primary",
				enabled = (view.shards or 0) >= shardPrice and not env.busy(), onActivated = function()
					env.send("buyShards", kind, entry.id)
				end },
			env.robuxButton(productKey, "Robux_" .. entry.id),
		}
	end
	ctx.row({
		name = "Sale_" .. entry.id,
		title = entry.name,
		titleColor = owned and "success" or nil,
		subtitle = Text.get(owned and "shop.cos.ownedSub" or subtitleKey),
		buttons = buttons,
	})
end

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
		saleRow(ctx, env, view, "cosmeticTheme", set, view.themes and view.themes[set.id] == true, view.shardPrices.theme, "theme_" .. set.id, "shop.cos.themeSub")
	end
	ctx.section(Text.get("shop.cos.gliderSection"), "GliderSection")
	for _, skin in ipairs(CosmeticSlotData.gliderSkins) do
		saleRow(ctx, env, view, "gliderSkin", skin, view.gliderSkins and view.gliderSkins[skin.id] == true, view.shardPrices.gliderSkin, "glider_" .. skin.id, "shop.cos.gliderSub")
	end

	ctx.section(Text.get("shop.cos.equipSection"), "EquipSection")
	local equipped = view.equipped or {}
	for _, slot in ipairs(CosmeticSlotData.slots) do
		local isGlider = slot.id == "gliderSkin"
		local options = {}
		for _, entry in ipairs(isGlider and CosmeticSlotData.gliderSkins or CosmeticSlotData.sets) do
			local owned = isGlider and view.gliderSkins[entry.id] or (not isGlider and view.themes[entry.id])
			if owned then
				table.insert(options, { id = entry.id, text = entry.name })
			end
		end
		local current = equipped[slot.id]
		ctx.line(Text.get("shop.cos.slotLine", { slot = Text.get("shop.slot." .. slot.id),
			current = current and nameOf(isGlider and "gliderSkin" or "cosmeticTheme", current) or Text.get("shop.cos.default") }), "textPrimary", 1, "Slot_" .. slot.id)
		if #options == 0 then
			ctx.line(Text.get(isGlider and "shop.cos.noGlider" or "shop.cos.noTheme"), "textSecondary", 1, "SlotEmpty_" .. slot.id)
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
end

return CosmeticTab
