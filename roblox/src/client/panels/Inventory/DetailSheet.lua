local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local Loot = require(ReplicatedStorage.Shared.Loot)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Gem = require(ReplicatedStorage.Shared.Gem)
local Text = require(ReplicatedStorage.Shared.Text)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local ItemActions = require(script.Parent.ItemActions)
local DetailCard = require(script.Parent.DetailCard)
local ItemConfirm = require(script.Parent.ItemConfirm)
local Compare = require(script.Parent.Compare)
local Hint = require(script.Parent.Parent.GemWorkshop.Hint)

-- P2.5b A: [계승](착용 중인 같은 부위보다 기본 효과가 좋은 가방 장비일 때만). 규칙 = shared/Inherit · 창 = panels/Inherit.
local Inherit = require(ReplicatedStorage.Shared.Inherit)
local InheritPanel = require(script.Parent.Parent.Inherit)
-- P2.5b B · C: 보석 분해(가루) · 재련 창.
local GemCraft = require(ReplicatedStorage.Shared.GemCraft)
local GemForge = require(script.Parent.Parent.GemForge)

-- P3b C1: 옵션 굴림 위치(그 등급 · 레벨 범위의 어디쯤인가 - 장비 보기 창과 같은 EquipCompare.rollPercent). 치명은 치확 / 치피 두 굴림.
local EquipCompare = require(ReplicatedStorage.Shared.EquipCompare)
local function rollText(item)
	local option = item and item.option
	if not option or not option.roll then
		return ""
	end
	if option.id == "crit" then
		return Text.get("gear.detail.qualityCrit", { pct = ("%.0f"):format(EquipCompare.rollPercent(option.roll)), pct2 = ("%.0f"):format(EquipCompare.rollPercent(option.roll2 or option.roll)) })
	end
	return Text.get("gear.detail.quality", { pct = ("%.0f"):format(EquipCompare.rollPercent(option.roll)) })
end

-- 상세(S20b · QUEUE-ALL2 P2 ref 17) - PC = 오른쪽 단 상세 카드(항상 보임 - 고른 게 없으면 안내), 폰 = 아래에서 올라오는 시트(선택이 있을 때만 · 왼쪽 카드 스크롤 + 오른쪽 버튼 · 닫기 44).
--   카드 본문 = DetailCard(이름 · 등급 칩 · 착용 대비 ▲▼ · 옵션 게이지 · 세계 번호 카드 · 보석 홈 · 잠금 토글). 버튼 = 장착(해제) · 각성 · 계승 · 분해 · 판매 · 리롤 · 재련 - 그 선택에 쓸 수 있는 것만 보이고,
--   잠긴 장비의 분해 · 판매는 회색 + 자물쇠. 이유 한 줄(DetailHint)은 버튼 묶음 바로 위. 서버 요청(Sell · Lock · Dismantle · Equip · Awaken · GemCraft)과 확인 창 규칙은 그대로다.
local DetailSheet = {}

function DetailSheet.create(S, R)
local player = S.player
local content = R.content
local sellRequest = ReplicatedStorage:WaitForChild("SellRequest")
local lockRequest = ReplicatedStorage:WaitForChild("LockRequest")
local dismantleRequest = ReplicatedStorage:WaitForChild("DismantleRequest")

local detail = Instance.new("Frame")
detail.Name = "Detail"
detail.BackgroundColor3 = UIColors.panel
detail.BackgroundTransparency = 0.1
detail.BorderSizePixel = 0
detail.Parent = content
R.detail = detail
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = detail
	local stroke = Instance.new("UIStroke")
	stroke.Name = "CardStroke"
	stroke.Color = Color3.new(1, 1, 1) -- ref 17: 오른쪽 카드 = 흰 테두리
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = detail
end

local card = DetailCard.build(detail, S)
local confirm = ItemConfirm.create(content, player)

local actions = Instance.new("Frame")
actions.Name = "Actions"
actions.BackgroundTransparency = 1
actions.Parent = detail

-- S20d: 버튼 위 한 줄 - 착용 · 해제를 못 할 때의 이유(빨강) · 보석 [장착]이 밀어낼 보석 미리보기 · 각성 결과(보조색).
local dhint = Instance.new("TextLabel")
dhint.Name = "DetailHint"
dhint.BackgroundTransparency = 1
dhint.Font = Enum.Font.Gotham
dhint.TextSize = Theme.textSize("caption") -- 12px 미만 금지
dhint.TextXAlignment = Enum.TextXAlignment.Left
dhint.TextTruncate = Enum.TextTruncate.AtEnd
dhint.TextColor3 = UIColors.textSecondary
dhint.Text = ""
dhint.Visible = false
dhint.Parent = detail

local function setHint(text, isReason)
	dhint.Visible = text ~= nil and text ~= ""
	dhint.Text = text or ""
	dhint.TextColor3 = isReason and UIColors.danger or UIColors.textSecondary
end

-- 버튼 틀. style: primary(장착 - 초록) · awaken(각성 - 흰 바탕) · inherit(계승 - 파랑) · plain(분해 · 판매) · gold(리롤 · 재련). width는 배치가 다시 정한다(PrimordialActions가 같은 틀을 쓴다).
local STYLES = {
	primary = { bg = UIColors.success, bgT = 0.05, text = Color3.new(1, 1, 1), stroke = UIColors.success, strokeT = 0.4 },
	awaken = { bg = Color3.new(1, 1, 1), bgT = 0.02, text = Color3.fromRGB(230, 40, 170), stroke = Color3.new(1, 1, 1), strokeT = 0.5 },
	inherit = { bg = Color3.fromRGB(74, 144, 226), bgT = 0.05, text = Color3.new(1, 1, 1), stroke = Color3.fromRGB(74, 144, 226), strokeT = 0.4 },
	plain = { bg = UIColors.slot, bgT = 0.05, text = UIColors.textPrimary, stroke = UIColors.rim, strokeT = UIColors.rimTransparency },
	gold = { bg = UIColors.panel, bgT = UIColors.panelTransparency, text = UIColors.gold, stroke = UIColors.gold, strokeT = 0.58 },
}
local function makeActionButton(order, width, style)
	local look = STYLES[style] or STYLES.plain
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = order
	btn.Text = ""
	btn.Size = UDim2.new(0, width, 0, 44)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = Theme.textSize("header")
	btn.BackgroundColor3 = look.bg
	btn.BackgroundTransparency = look.bgT
	btn.TextColor3 = look.text
	btn.TextWrapped = true -- "각성 12,345" · "리롤(3장)"처럼 긴 글은 두 줄(버튼 높이 44)
	btn.Visible = false
	btn.Parent = actions
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = look.stroke
	stroke.Transparency = look.strokeT
	stroke.Parent = btn
	return btn, stroke
end

local function setEnabled(btn, enabled)
	btn.Active = enabled
	btn.AutoButtonColor = enabled
	btn.TextTransparency = enabled and 0 or 0.6
end

-- 잠긴 장비의 분해 · 판매 버튼 오른쪽 위 자물쇠
local function addLockMark(btn)
	local holder = Instance.new("Frame")
	holder.Name = "LockMark"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -6, 0, 5)
	holder.Size = UDim2.new(0, 12, 0, 12)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = btn
	ItemIcons.lock(holder, 12, UIColors.xp)
	return holder
end

local equipButton = makeActionButton(1, 96, "primary")
equipButton.Name = "EquipButton"
equipButton.Text = Text.get("inv.act.equip")
local inheritButton = makeActionButton(3, 96, "inherit") -- P2.5b A: 착용 중인 같은 부위보다 좋은 가방 장비일 때만
inheritButton.Name = "InheritButton"
inheritButton.Text = Text.get("inv.act.inherit")
-- 분해(23-2) - 상위 등급(영웅 ~ 태초)만 대상. 분해 = 보석 가루(보석) · 판매 = 골드.
local dismantleButton = makeActionButton(4, 96, "plain")
dismantleButton.Name = "DismantleButton"
dismantleButton.Text = Text.get("inv.act.dismantle")
local dismantleLock = addLockMark(dismantleButton)
local sellButton = makeActionButton(5, 96, "plain")
sellButton.Name = "SellButton"
sellButton.Text = Text.get("inv.act.sell")
local sellLock = addLockMark(sellButton)
-- 리롤(26-3) - 고대 · 태초의 가방 / 착용 장비만(Gem.isRerollableGrade). S20e: 누르면 "보석상인에게서 가능" 안내(서버 요청 없음).
local rerollButton = makeActionButton(6, 96, "gold")
rerollButton.Name = "RerollButton"
local craftButton = makeActionButton(7, 96, "gold") -- P2.5b B: 보석(홈 · 가방)을 골랐을 때만 - 보석 가공 창(재련 · 일괄 분해)
craftButton.Name = "CraftButton"
craftButton.Text = Text.get("inv.act.craft")
S.primordialActions = require(script.Parent.PrimordialActions).create(makeActionButton, setHint) -- D1: [각성](태초 · 초월 가방 · 착용 장비)
local awakenButton = S.primordialActions.button()
local ORDERED = { equipButton, awakenButton, inheritButton, dismantleButton, sellButton, rerollButton, craftButton }

-- ═══ 상세 갱신 ═══
local function hideButtons()
	for _, btn in ipairs(ORDERED) do
		btn.Visible = false
	end
	dismantleLock.Visible, sellLock.Visible = false, false
end

local function setReroll(gradeId)
	local eligible = Gem.isRerollableGrade(gradeId)
	rerollButton.Visible = eligible
	if eligible then
		local state = S.gemState and S.gemState()
		local tickets = (state and state.rerollTickets and state.rerollTickets[gradeId]) or 0
		rerollButton.Text = Text.get("inv.act.reroll", { count = tostring(tickets) })
		setEnabled(rerollButton, true)
	end
end

local function iconKey(item)
	return ItemIcons.keyFor(item.part or "armor", item.grade, item.itemLevel, nil, item.setZone)
end

local function refreshBag(item)
	local classId = player:GetAttribute("ClassId")
	local described = ItemDescribe.item(item, classId)
	local equippedSame = S.equippedByPart()[item.part or "armor"]
	local sellable = item.grade ~= "transcendent" -- Q4: 초월 = 판매 불가(서버가 막는다)
	local lines = { { text = described.meta, color = UIColors.textPrimary }, Compare.baseLine(item, equippedSame) }
	for _, line in ipairs(Compare.optionLines(item, equippedSame, classId, false)) do
		table.insert(lines, line)
	end
	table.insert(lines, { text = sellable and Text.get("gear.detail.sellPrice", { price = NumberFormat.currency(Loot.getSellPrice(item), Text.languageFor()), quality = rollText(item) }) or Text.get("gear.detail.noSell", { quality = rollText(item) }), color = UIColors.textSecondary })
	if sellable and S.isDismantleEligibleGrade(item.grade) then -- QUEUE-ALL9C 1-10: 분해 시 · 판매 시 나란히(분해 가능한 장비)
		table.insert(lines, { text = ItemConfirm.rewardLine(item), color = UIColors.textSecondary })
	end
	card.set({
		title = Text.get("inv.detail.inBag", { name = described.title }), -- P3b C1: 장착 여부(착용 칸은 "(착용 중)")
		gradeId = item.grade, part = item.part or "armor", iconKey = iconKey(item),
		lines = lines, option = item, notes = described.note, stamp = item.primordial, locked = item.locked == true,
	})
	-- S20d: [장착] = 가방 칸 더블클릭 · 우클릭과 같은 통로(S.equipFromBag). 못 하면 회색 + 이유 1줄.
	local canEquip, blockReason = S.itemActions.canEquip(S.selectedValue)
	equipButton.Visible = true
	equipButton.Text = Text.get("inv.act.equip")
	setEnabled(equipButton, canEquip)
	if blockReason and blockReason ~= "busy" then
		setHint(ItemActions.reasonText(blockReason), true)
	end
	inheritButton.Visible = Inherit.isUpgrade(equippedSame, item)
	setEnabled(inheritButton, true)
	-- 분해: 영웅 이상 · 안 잠김 · 초월 아님(C5-7). 판매: 잠겨도 눌리게 둔다(눌렀을 때 "잠금을 풀어야" 이유 한 줄 - P3c E3) · 초월은 판매 불가.
	local dismantleEligible = not item.locked and S.isDismantleEligibleGrade(item.grade) and item.grade ~= "transcendent"
	dismantleButton.Visible = true
	setEnabled(dismantleButton, dismantleEligible)
	dismantleLock.Visible = item.locked == true
	sellButton.Visible = true
	sellButton.Active, sellButton.AutoButtonColor = sellable, sellable
	sellButton.TextTransparency = (item.locked or not sellable) and 0.6 or 0
	sellLock.Visible = item.locked == true
	setReroll(item.grade)
	S.primordialActions.refresh("bag", S.selectedValue, item, blockReason ~= nil and blockReason ~= "busy")
end

local function refreshEquipped(part, item)
	local described = ItemDescribe.item(item, player:GetAttribute("ClassId"))
	card.set({
		title = Text.get("inv.detail.equipped", { name = described.title }),
		gradeId = item.grade, part = item.part or part, iconKey = iconKey(item),
		lines = { { text = described.meta .. rollText(item), color = UIColors.textPrimary } },
		option = item, notes = described.note, stamp = item.primordial,
	})
	-- S20d: [해제] = 착용 칸 더블클릭 · 우클릭과 같은 통로(S.unequipToBag). 가방이 가득 차면 회색 + 이유 1줄(서버도 같은 이유로 거절한다).
	local canUnequip, blockReason = S.itemActions.canUnequip(part)
	equipButton.Visible = true
	equipButton.Text = Text.get("inv.act.unequip")
	setEnabled(equipButton, canUnequip)
	if blockReason and blockReason ~= "busy" then
		setHint(ItemActions.reasonText(blockReason), true)
	end
	setReroll(item.grade)
	S.primordialActions.refresh("equip", part, item, blockReason ~= nil and blockReason ~= "busy")
end

local function refreshDetailBody()
	setHint(nil) -- 아래 분기가 필요한 것만 다시 채운다
	hideButtons()
	S.primordialActions.refresh(nil) -- D1: 태초 가방 · 착용 분기만 다시 켠다
	local gemState = S.gemState and S.gemState()
	if S.selectedKind == "bag" then
		local item = S.inventory[S.selectedValue]
		if not item then
			S.selectedKind, S.selectedValue = nil, nil
			card.clear(Text.get("inv.detail.empty"), Text.get("inv.detail.emptyHint"))
			return
		end
		refreshBag(item)
	elseif S.selectedKind == "equip" and S.selectedValue ~= "weapon" and S.equippedByPart()[S.selectedValue] then
		refreshEquipped(S.selectedValue, S.equippedByPart()[S.selectedValue])
	elseif S.selectedKind == "equip" and S.selectedValue == "weapon" then
		-- 무기: 이름에 등급을 붙인다(20-1 [2]) · 강화 단계(+N)는 메타 줄 · 옵션 없음(20.67 [1] - 무기는 강화만) · 보석 홈 줄(누르면 보석 탭).
		local gradeId = S.weaponGradeId()
		local described = ItemDescribe.weapon(gradeId, player:GetAttribute("WeaponLevel") or 0)
		card.set({
			title = described.title, gradeId = gradeId, part = "weapon", iconKey = ItemIcons.keyFor("weapon", gradeId, nil, player:GetAttribute("ClassId")),
			lines = { { text = Text.get("gear.detail.weaponMeta", { meta = described.meta }), color = UIColors.textPrimary } }, gems = true,
		})
	elseif S.selectedKind == "gemSlot" and type(S.selectedValue) == "number" and gemState and Gem.isFilled(gemState.gems, S.selectedValue) then
		local gem = gemState.gems[S.selectedValue]
		card.set({
			title = Text.get("gear.detail.slotTitle", { slot = ("%d"):format(S.selectedValue), name = ItemDescribe.gem(gem).title }), gradeId = gem.grade, part = "weapon",
			lines = { { text = Text.get("gear.detail.slotLine", { grade = ArmorData.grades[Gem.gradeCapForSlot(S.selectedValue, S.gemState and S.gemState() and S.gemState().transcendSlots)].displayName, quality = rollText(gem) }), color = UIColors.textPrimary } },
			option = gem, notes = ItemDescribe.gem(gem).note, gems = true,
		})
		craftButton.Visible = true -- P2.5b B: 장착 중 보석도 재련된다(해제 불필요) · 리롤 버튼은 보석 탭 행 자체에 있다(중복 방지)
		setEnabled(craftButton, true)
	elseif S.selectedKind == "gemBag" and type(S.selectedValue) == "number" and gemState and gemState.gemInventory[S.selectedValue] then
		local gem = gemState.gemInventory[S.selectedValue]
		-- P3c E4: 판매가도 같이(판매 = 골드 · 분해 = 가루 - 판매가는 분해 가루 가치의 절반).
		card.set({
			title = ItemDescribe.gem(gem).title, gradeId = gem.grade, part = "weapon",
			lines = { { text = Text.get("gear.detail.gemBagLine", { price = NumberFormat.currency(GemCraft.sellPrice(gem, player:GetAttribute("AccountBestStage") or 1), Text.languageFor()), dust = ("%d"):format(GemCraft.dustYield(gem)), quality = rollText(gem) }), color = UIColors.textPrimary } },
			option = gem, notes = ItemDescribe.gem(gem).note, gems = true,
		})
		-- S20c: [장착] = 자동 장착(GemActions - PC 더블클릭 · 우클릭 · 폰 탭 선택과 같은 통로). 요청 중이면 회색.
		local canEquip = S.gemCanAutoEquip(S.selectedValue)
		equipButton.Visible = true
		equipButton.Text = Text.get("inv.act.equip")
		setEnabled(equipButton, canEquip)
		if canEquip then
			setHint(S.gemReplaceText(S.selectedValue)) -- 밀려날 보석 미리보기(교체가 없으면 nil = 안 보인다)
		end
		-- P3c E4 · P2.5b C: 보석 판매(→ 골드) · 분해(→ 가루) - 보석은 전부 영웅 이상이라 매번 확인창을 거친다.
		sellButton.Visible, dismantleButton.Visible, craftButton.Visible = true, true, true
		setEnabled(sellButton, true)
		setEnabled(dismantleButton, true)
		setEnabled(craftButton, true)
	else
		card.clear(Text.get("inv.detail.empty"), Text.get("inv.detail.emptyHint"))
	end
end

-- ═══ 버튼 입력 ═══
-- 잠금 토글(가방 장비만). 태초 · 초월 잠금 해제 = 확인 두 번(D1 ⑦ · C5-7) → 서버도 이중 확인 표식이 없으면 거절한다.
card.onLock(function()
	if S.selectedKind ~= "bag" then
		return
	end
	local item = S.inventory[S.selectedValue]
	if not item then
		return
	end
	local index = S.selectedValue
	if (item.grade == "primordial" or item.grade == "transcendent") and item.locked then
		local first, second = require(script.Parent.PrimordialActions).unlockTexts(item)
		confirm.askTwice(first, second, function()
			lockRequest:FireServer(index, false, "primordial-confirmed-twice")
		end)
		return
	end
	lockRequest:FireServer(index, not item.locked)
end)
card.onGems(function()
	R.selectTab("보석")
end)

-- S21-0 B1: 판매 · 분해 요청을 보내는 즉시 선택을 비운다(+화면을 바로 다시 그린다) - table.remove가 배열을 당겨서 같은 index가 다음 장비를 가리키게 되기 전에 끊는다.
sellButton.Activated:Connect(function()
	if S.selectedKind == "gemBag" then -- P3c E4: 보석 → 골드(확인창 뒤 GemCraftRequest - 결과 토스트는 GemForge가 낸다)
		local gem = S.gemState().gemInventory[S.selectedValue]
		if not gem then
			return
		end
		local index = S.selectedValue
		confirm.item("판매", gem, function()
			S.selectedKind, S.selectedValue = nil, nil
			S.rebuildGrid()
			ReplicatedStorage:WaitForChild("GemCraftRequest"):FireServer("sell", index)
		end, true)
		return
	end
	if S.selectedKind ~= "bag" then
		return
	end
	local item = S.inventory[S.selectedValue]
	if not item then
		return
	end
	if item.locked then
		setHint(Text.get("inv.lock.needUnlockSell"), true) -- P3c E3: 잠금 = 보호(서버도 "locked"로 거절한다)
		return
	end
	local index = S.selectedValue
	local signature = Loot.itemSignature(item) -- 서버가 같은 장비인지 대조(칸 밀림 방지)
	local function doSell()
		S.selectedKind, S.selectedValue = nil, nil
		S.rebuildGrid()
		sellRequest:FireServer("sell", index, signature)
	end
	if S.isDismantleEligibleGrade(item.grade) then -- 영웅 등급 이상(B2 - 분해 문턱과 같다)
		confirm.item("판매", item, doSell)
	else
		doSell()
	end
end)

dismantleButton.Activated:Connect(function()
	if S.selectedKind == "gemBag" then -- P2.5b C: 보석 → 가루
		local gem = S.gemState().gemInventory[S.selectedValue]
		if not gem then
			return
		end
		local index = S.selectedValue
		confirm.item("분해", gem, function()
			S.selectedKind, S.selectedValue = nil, nil
			S.rebuildGrid()
			ReplicatedStorage:WaitForChild("GemCraftRequest"):FireServer("dismantle", index)
		end, true)
		return
	end
	if S.selectedKind ~= "bag" then
		return
	end
	local item = S.inventory[S.selectedValue]
	if not item or item.locked or not S.isDismantleEligibleGrade(item.grade) then
		return
	end
	local index = S.selectedValue
	confirm.item("분해", item, function() -- 분해는 항상 영웅 이상만 대상이라 매번 확인창을 거친다
		S.selectedKind, S.selectedValue = nil, nil
		S.rebuildGrid()
		dismantleRequest:FireServer(index)
	end)
end)

equipButton.Activated:Connect(function()
	if S.selectedKind == "gemBag" then
		S.gemAutoEquip(S.selectedValue)
	elseif S.selectedKind == "bag" then
		S.equipFromBag(S.selectedValue) -- S20d: 더블클릭 · 우클릭과 같은 통로(ItemActions - 요청 중 잠금 · 이유 토스트)
	elseif S.selectedKind == "equip" and S.selectedValue ~= "weapon" then
		S.unequipToBag(S.selectedValue)
	end
end)

-- S20e: 변환 · 리롤은 보석상인의 "보석 공방"에서만 된다 - 누르면 토스트 "보석상인에게서 가능" + [위치 안내](서버 요청 없음).
rerollButton.Activated:Connect(function()
	if S.selectedKind == "bag" or (S.selectedKind == "equip" and S.selectedValue ~= "weapon") then
		Hint.toast()
	end
end)

-- P2.5b B: [재련] - 보석 가공 창(고른 보석이 재련 대상 - 홈이면 장착 중인 채로).
craftButton.Activated:Connect(function()
	if S.selectedKind == "gemSlot" and type(S.selectedValue) == "number" then
		GemForge.open("slot", S.selectedValue, "refine")
	elseif S.selectedKind == "gemBag" and type(S.selectedValue) == "number" then
		GemForge.open("bag", S.selectedValue, "refine")
	end
end)

-- P2.5b A: [계승] - 계승 창(가방 창은 닫히고 계승 창이 끝나면 돌아온다). 판정 · 비용 · 능력치는 계승 창이 서버에 묻는다.
inheritButton.Activated:Connect(function()
	if S.selectedKind ~= "bag" then
		return
	end
	local item = S.inventory[S.selectedValue]
	local part = item and (item.part or "armor")
	local equipped = part and S.equippedByPart()[part]
	if item and Inherit.isUpgrade(equipped, item) then
		InheritPanel.open(part, S.selectedValue, equipped, item)
	end
end)

-- 폰 시트 닫기: 선택을 비운다. 가방 칸의 선택 테두리가 rebuildGrid에서 같이 꺼진다.
local sheetClose = Instance.new("TextButton")
sheetClose.Name = "SheetClose"
sheetClose.Text = ""
sheetClose.AutoButtonColor = false
sheetClose.Size = UDim2.new(0, 44, 0, 44)
sheetClose.BackgroundColor3 = UIColors.panel
sheetClose.BackgroundTransparency = UIColors.panelTransparency
sheetClose.Visible = false
sheetClose.Parent = detail
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = sheetClose
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Parent = sheetClose
	for _, rotation in ipairs({ 45, -45 }) do -- 헤더 닫기와 같은 X 모양(회전한 막대 2개)
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(0.5, 0, 0.5, 0)
		bar.Size = UDim2.new(0, 13, 0, 2)
		bar.Rotation = rotation
		bar.BackgroundColor3 = UIColors.textSecondary
		bar.BorderSizePixel = 0
		bar.Parent = sheetClose
	end
end
sheetClose.Activated:Connect(function()
	S.selectedKind, S.selectedValue = nil, nil
	S.rebuildGrid()
end)
R.sheetClose = sheetClose

-- ═══ 배치 ═══
-- 보이는 버튼을 줄 맞춰 놓는다. 반환: 묶음 높이. PC = 3열(카드 폭을 나눠 가진다) · 폰 = 76 폭 버튼을 한 줄에 perRow개.
local PHONE_BUTTON_W, PHONE_GAP, PC_GAP = 76, 6, 8
local PHONE_INFO_MIN, PHONE_ACTIONS_MIN = 200, 240
local function visibleButtons()
	local list = {}
	for _, btn in ipairs(ORDERED) do
		if btn.Visible then
			table.insert(list, btn)
		end
	end
	return list
end

local function actionsGeometry(L)
	local list = visibleButtons()
	local n = #list
	if L.mode == "phone" then
		local avail = L.winW - 16 - 52 - PHONE_INFO_MIN
		local perRow = math.clamp(math.floor((avail + PHONE_GAP) / (PHONE_BUTTON_W + PHONE_GAP)), 1, math.max(n, 1))
		local rows = n > 0 and math.ceil(n / perRow) or 0
		local height = rows > 0 and rows * L.actionH + (rows - 1) * PHONE_GAP or 0
		return list, perRow, PHONE_BUTTON_W, rows, height, PHONE_GAP
	end
	local perRow = 3
	local width = math.floor(((L.detailW - 20) - (perRow - 1) * PC_GAP) / perRow)
	local rows = n > 0 and math.ceil(n / perRow) or 0
	local height = rows > 0 and rows * L.actionH + (rows - 1) * PC_GAP or 0
	return list, perRow, width, rows, height, PC_GAP
end

-- 폰 시트 높이(버튼 줄 수에 따라): 위 여백 8 + 이유 줄 18 + 버튼 묶음 + 아래 여백 8(최소 96 - 이름 칸 + 그림 줄이 보이는 높이)
local function phoneSheetHeight(L)
	local _, _, _, _, height = actionsGeometry(L)
	return math.max(96, 8 + 18 + height + 8)
end

local lastCardWidth, lastCardPhone
local function placeDetail(L)
	local phone = L.mode == "phone"
	local list, perRow, buttonW, _, groupH, gap = actionsGeometry(L)
	local width, height, infoX, infoY, infoW, infoH, groupX, groupW
	if phone then
		height = phoneSheetHeight(L)
		width = L.winW
		detail.Position = UDim2.new(0, 0, 0, L.winH - height)
		detail.Size = UDim2.new(0, width, 0, height)
		local used = math.min(perRow, math.max(#list, 1))
		groupW = math.max(used * buttonW + (used - 1) * gap, PHONE_ACTIONS_MIN)
		groupX = width - 8 - 52 - groupW
		infoX, infoY, infoW, infoH = 8, 8, groupX - 16, height - 16
		sheetClose.Position = UDim2.new(0, width - 8 - 44, 0, 8)
	else
		width, height = L.detailW, L.detailH
		detail.Position = UDim2.new(0, L.detailX, 0, L.detailY)
		detail.Size = UDim2.new(0, width, 0, height)
		groupX, groupW = 10, width - 20
		infoX, infoY, infoW = 10, 10, width - 20
		infoH = height - 10 - groupH - 4 - 18 - 6 - 10
	end
	sheetClose.Visible = phone
	local groupTop = height - (phone and 8 or 10) - groupH
	actions.Position = UDim2.new(0, groupX, 0, groupTop)
	actions.Size = UDim2.new(0, groupW, 0, groupH)
	for index, btn in ipairs(list) do
		local row, col = math.floor((index - 1) / perRow), (index - 1) % perRow
		local x = phone and (groupW - (math.min(perRow, #list) * (buttonW + gap) - gap)) + col * (buttonW + gap) or col * (buttonW + gap)
		btn.Position = UDim2.new(0, x, 0, row * (L.actionH + gap))
		btn.Size = UDim2.new(0, buttonW, 0, L.actionH)
		btn.TextSize = Theme.textSize(phone and "body" or "header")
	end
	-- S20d: 이유 줄 = 버튼 묶음 바로 위(아래 끝 = 묶음 위 - 4)
	dhint.Position = UDim2.new(0, groupX, 0, groupTop - 4 - 16)
	dhint.Size = UDim2.new(0, groupW, 0, 16)
	card.scroll.Position = UDim2.new(0, infoX, 0, infoY)
	card.scroll.Size = UDim2.new(0, infoW, 0, math.max(0, infoH))
	if infoW ~= lastCardWidth or phone ~= lastCardPhone then
		lastCardWidth, lastCardPhone = infoW, phone
		card.layout(infoW, phone)
	end
end

-- 폰 시트: 선택이 없으면 숨는다(PC 카드는 항상 보인다). refreshDetail이 끝날 때마다 다시 정한다.
local function applySheetVisibility()
	local shown = S.mode ~= "phone" or S.selectedKind ~= nil
	detail.Visible = shown
	-- 폰: 시트가 올라오면 본문 프레임이 그만큼 짧아진다(ZIndexBehavior가 Global이라 겹치면 뒤 프레임이 시트 위로 비친다). 값이 바뀔 때만 배치를 다시 적용한다.
	local inset = (S.mode == "phone" and shown and R.layout) and phoneSheetHeight(R.layout) or 0
	if inset ~= S.sheetInset then
		S.sheetInset = inset
		R.applyLayout()
	elseif R.layout then
		placeDetail(R.layout)
	end
end

local function refreshDetail()
	if S.itemActions.isPending() then
		-- S20d: 착용 · 해제 요청 중에는 서버 스냅샷이 먼저 와 가방 index가 밀려 있다 - 본문을 다시 그리면 잠깐 다른 아이템이 보인다. 버튼만 잠그고 결과가 오면(onDone) 한 번에 그린다.
		setEnabled(equipButton, false)
		return
	end
	refreshDetailBody()
	applySheetVisibility()
	if S.paintGearSelection then
		S.paintGearSelection()
	end
end
S.refreshDetail = refreshDetail

table.insert(R.layouts, function(L)
	placeDetail(L)
	applySheetVisibility()
end)
end

return DetailSheet
