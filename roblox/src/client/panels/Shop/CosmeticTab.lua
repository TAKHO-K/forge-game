-- 상점 [치장] 탭(QUEUE-B1 B2 UI · QUEUE-ALL9C 1-6R 카드 + 하위 칩). 치장은 꾸미기 토큰 또는 로벅스로만 산다 - **골드 가격은 표시하지 않는다**(서버 CosmeticService도 골드를 받지 않는다).
--   하위 칩(Catalog.CHIPS - 공개 상품 0개 칩은 숨김) 하나 = 카드 격자 + "칸별 장착"(산 것 중 칸마다 고르기 · 기본으로 되돌리기 - 테마 4칸은 세트끼리 섞는다) · 이름표 칩 = 이름표 패스 카드 + 색 · 배지 고르기.
--   요청 = ShopRequest(buyShards · buyRobux · equip · equipAll) · 화면 = ShopSync 표(MonetizationService.view) 그대로.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
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
CosmeticTab.TRY_ITEM_SLOTS = { weaponSkin = true, petAccessory = true } -- QUEUE-ALL6 H 입혀 보기 = 내 화면 Attribute만 바꿔 바로 보이는 칸(처치 · 강화 · 귀환 · 이모트는 서버 사건이 있어야 보임)

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

-- 칩 하나 그리기: 카드 격자 + 칸별 장착
function CosmeticTab.render(ctx, env, chip)
	local view = env.state.view
	local entries = require(script.Parent.Catalog).chipEntries(view, chip)
	local specs = {}
	for _, e in ipairs(entries) do
		table.insert(specs, e.pass and require(script.Parent.ConvenienceTab).passCard(env, e.pass) or require(script.Parent.Catalog).productCard(env, e.key))
	end
	ctx.cards("Cards_" .. chip.id, specs)
	ctx.section(Text.get("shop.equipSection"), "EquipSection")
	if chip.nameplate then
		CosmeticTab.renderNameplate(ctx, env)
	else
		CosmeticTab.renderEquip(ctx, env, chip.slots)
	end
end

function CosmeticTab.renderEquip(ctx, env, onlySlots)
	local view = env.state.view
	local equipped = view.equipped or {}
	for _, slot in ipairs(CosmeticSlotData.slots) do
		if onlySlots and not table.find(onlySlots, slot.id) then
			continue
		end
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
end

-- 이름표 색 · 배지 고르기(패스가 있을 때)
function CosmeticTab.renderNameplate(ctx, env)
	local view = env.state.view
	local equipped = view.equipped or {}
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
