local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GradeColor = require(game:GetService("ReplicatedStorage").Shared.GradeColor) -- QUEUE-ALL9C 2-2 등급 색 쓰임별(text · border)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local SetData = require(ReplicatedStorage.Shared.data.SetData)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local SetBonus = require(ReplicatedStorage.Shared.SetBonus)
local Text = require(ReplicatedStorage.Shared.Text)
local Gem = require(ReplicatedStorage.Shared.Gem)
local HelpTooltip = require(script.Parent.Parent.Parent.HelpTooltip)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local ItemActions = require(script.Parent.ItemActions)
local ItemCell = require(script.Parent.ItemCell)

-- 장비 칸(S20b · QUEUE-ALL2 P2 ref 17) - 왼쪽 단 "착용 중": 캐릭터 그림 둘레에 4칸(왼쪽 = 갑옷 · 신발 / 오른쪽 = 무기 · 장갑 - 이 게임에 없는 머리 · 장신구 칸은 그리지 않는다) ·
--   총 스탯 3줄 · 세트 효과 칸(모은 부위 · 2부위 / 3부위 효과 - 켜진 줄 = 채운 점 + 초록) · 옵션 보너스 칸. 세로 스크롤 ScrollingFrame이다(PC = 왼쪽 단 · 폰 = "장비" 탭 본문 - 폰은 캐릭터 그림 없이 4칸 한 줄).
local GearTab = {}

-- 세트 표시용 퍼센트("5" · "4.7")
local function percentText(value)
	local text = ("%.1f"):format(value * 100)
	return (text:gsub("%.0$", ""))
end

function GearTab.create(S, R)
local player = S.player
local content = R.content
local LABEL_H = 18

local refs = {}
local function build()
	local gear = Instance.new("ScrollingFrame")
	gear.Name = "Gear"
	gear.BackgroundColor3 = UIColors.slot
	gear.BackgroundTransparency = 0.55
	gear.BorderSizePixel = 0
	gear.ScrollBarThickness = 4
	gear.CanvasSize = UDim2.new(0, 0, 0, 0)
	gear.Parent = content
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = gear

	local title = Theme.label(gear, Text.get("inv.equipped.title"), "header", "textPrimary")
	title.Name = "Title"
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Position = UDim2.new(0, 0, 0, 8)
	title.Size = UDim2.new(1, 0, 0, 22)

	-- 캐릭터 그림: 실제 아바타 썸네일(rbxthumb) · Studio 시험 계정(음수 id)은 도형 실루엣.
	local figure = Instance.new("Frame")
	figure.Name = "Figure"
	figure.BackgroundTransparency = 1
	figure.Parent = gear
	local shadow = Instance.new("Frame")
	shadow.AnchorPoint = Vector2.new(0.5, 1)
	shadow.Position = UDim2.new(0.5, 0, 1, 0)
	shadow.Size = UDim2.new(1.1, 0, 0, 16)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.Parent = figure
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(1, 0)
	shadowCorner.Parent = shadow
	-- QUEUE-ALL6 E4: 3D 미리보기(내 캐릭터 복제 · 회전 · 끌기) - 캐릭터가 없을 때만 옛 2D 썸네일
	local preview = require(script.Parent.CharacterPreview).create(figure)
	preview.frame.AnchorPoint = Vector2.new(0.5, 1)
	preview.frame.Position = UDim2.new(0.5, 0, 1, -6)
	preview.frame.Size = UDim2.new(1.1, 0, 1, -6) -- Play E5: 1.6배 = 착용 칸 카드 밑으로 들어가 몸이 가려졌다 → 카드 사이 틈(76)까지
	refs.preview = preview
	-- QUEUE-ALL9E1 LOOK2 보정 2: "내 아바타 옷 보이기"(기본 끔 = 바닥층 누빔 옷 · 켬 = 본인 옷 + 갑옷 판 · 겹침 허용) - 서버가 캐릭터에 적용(모두에게 같게) · 직업별 저장
	local clothes = Instance.new("TextButton")
	clothes.Name = "OwnClothesToggle"
	-- 자리 = 장비 칸 아래(R.layoutGear - 폰은 캐릭터 그림이 숨겨져 그림 안에 두면 안 보였다)
	clothes.BackgroundColor3 = UIColors.slot
	clothes.BackgroundTransparency = 0.2
	clothes.AutoButtonColor = true
	clothes.Font = Enum.Font.GothamBold
	clothes.TextSize = Theme.textSize("caption")
	clothes.TextColor3 = Theme.color("textPrimary")
	clothes.TextWrapped = true
	clothes.Parent = gear
	refs.clothes = clothes
	Instance.new("UICorner", clothes).CornerRadius = UDim.new(0, 8)
	local function showClothes()
		clothes.Text = Text.get(player:GetAttribute("ShowOwnClothes") == true and "inv.ownClothes.on" or "inv.ownClothes.off")
	end
	showClothes()
	player:GetAttributeChangedSignal("ShowOwnClothes"):Connect(function()
		showClothes()
		task.delay(0.6, preview.refresh) -- 서버가 옷을 갈아입힌 뒤 미리보기 다시
	end)
	clothes.Activated:Connect(function()
		local remote = ReplicatedStorage:FindFirstChild("OwnClothesToggle")
		if remote then
			remote:FireServer(player:GetAttribute("ShowOwnClothes") ~= true)
		end
	end)
	local fallbacks = {} -- Play E5: 창이 캐릭터보다 먼저 지어지면 2D가 깔린 채 나중 3D가 위에 겹쳐 보였다 → 3D가 서면 숨김
	local rawRefresh = preview.refresh
	function preview.refresh()
		local ok = rawRefresh()
		if ok then
			for _, f in ipairs(fallbacks) do
				f.Visible = false
			end
		end
		return ok
	end
	player.CharacterAdded:Connect(function() -- 첫 스폰 · 부활 뒤 다시(착용 코드가 방어구를 붙일 시간)
		task.delay(1.5, preview.refresh)
	end)
	if preview.refresh() then
		-- 3D가 섰다(아래 2D 대체는 건너뜀)
	elseif player.UserId > 0 then
		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.BackgroundTransparency = 1
		avatar.AnchorPoint = Vector2.new(0.5, 1)
		avatar.Position = UDim2.new(0.5, 0, 1, -6)
		avatar.Size = UDim2.new(1.6, 0, 1, -6)
		avatar.ScaleType = Enum.ScaleType.Fit
		avatar.Image = ("rbxthumb://type=Avatar&id=%d&w=150&h=150"):format(player.UserId)
		avatar.Parent = figure
		table.insert(fallbacks, avatar)
	else
		for _, piece in ipairs({
			{ 0.5, 0.06, 0.42, 0.18, UIColors.textSecondary }, -- 머리
			{ 0.5, 0.26, 0.62, 0.36, Color3.fromRGB(74, 144, 226) }, -- 몸
			{ 0.36, 0.62, 0.24, 0.32, UIColors.slot }, -- 왼다리
			{ 0.64, 0.62, 0.24, 0.32, UIColors.slot }, -- 오른다리
		}) do
			local part = Instance.new("Frame")
			part.AnchorPoint = Vector2.new(0.5, 0)
			part.Position = UDim2.new(piece[1], 0, piece[2], 0)
			part.Size = UDim2.new(piece[3], 0, piece[4], 0)
			part.BackgroundColor3 = piece[5]
			part.BorderSizePixel = 0
			part.Parent = figure
			table.insert(fallbacks, part)
			local partCorner = Instance.new("UICorner")
			partCorner.CornerRadius = UDim.new(0, 4)
			partCorner.Parent = part
		end
	end

	local slots = Instance.new("Frame")
	slots.Name = "Slots"
	slots.BackgroundTransparency = 1
	slots.Size = UDim2.new(1, 0, 0, 0)
	slots.Parent = gear

	-- 박스 하나(패널색 바탕 + 옅은 테두리)
	local function box(name)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundColor3 = UIColors.panel
		frame.BackgroundTransparency = 0.35
		frame.BorderSizePixel = 0
		frame.Parent = gear
		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0, 8)
		boxCorner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = UIColors.rim
		stroke.Transparency = 0.84
		stroke.Parent = frame
		return frame
	end

	-- 총 스탯 3줄
	local statsBox = box("Stats")
	local statValues = {}
	for i, spec in ipairs({ { "inv.stat.attack", UIColors.ember }, { "inv.stat.defense", Color3.fromRGB(127, 179, 232) }, { "inv.stat.maxHp", UIColors.hp } }) do
		local key = Theme.label(statsBox, Text.get(spec[1]), "caption", "textSecondary")
		key.Font = Enum.Font.GothamBold
		key.Position = UDim2.new(0, 10, 0, 6 + (i - 1) * 22)
		key.Size = UDim2.new(0.5, -10, 0, 20)
		local value = Theme.label(statsBox, "-", "body", "textPrimary")
		value.Font = Enum.Font.GothamBold
		value.TextColor3 = spec[2]
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -10, 0, 6 + (i - 1) * 22)
		value.Size = UDim2.new(0.5, -10, 0, 20)
		statValues[i] = value
	end

	-- 세트 효과 칸: 제목(세트 문양 + 이름) · 단계 줄(점 + 글) · 안내 한 줄
	local setBox = box("SetEffect")
	setBox.Visible = SetData.enabled
	local setTitle = Theme.label(setBox, "", "caption", "textPrimary")
	setTitle.Font = Enum.Font.GothamBold
	setTitle.TextColor3 = UIColors.gold
	setTitle.Position = UDim2.new(0, 10, 0, 8)
	setTitle.Size = UDim2.new(1, -20, 0, 18)
	local tierRows = {}
	for i = 1, #SetData.tiers do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0, 10, 0, 8 + 22 + (i - 1) * 20)
		row.Size = UDim2.new(1, -20, 0, 18)
		row.Parent = setBox
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.new(0, 0, 0.5, 0)
		dot.Size = UDim2.new(0, 10, 0, 10)
		dot.BorderSizePixel = 0
		dot.Parent = row
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		local dotStroke = Instance.new("UIStroke")
		dotStroke.Thickness = 1.5
		dotStroke.Parent = dot
		local label = Theme.label(row, "", "caption", "textSecondary")
		label.Font = Enum.Font.GothamBold
		label.Position = UDim2.new(0, 16, 0, 0)
		label.Size = UDim2.new(1, -16, 1, 0)
		tierRows[i] = { dot = dot, dotStroke = dotStroke, label = label }
	end
	local setHint = Theme.label(setBox, "", "caption", "textSecondary")
	setHint.Position = UDim2.new(0, 10, 0, 8 + 22 + #SetData.tiers * 20 + 2)
	setHint.Size = UDim2.new(1, -20, 0, 16)
	local setHeight = 8 + 22 + #SetData.tiers * 20 + 2 + 16 + 8

	-- 26-3(PRD 20.67 [12] "총 스탯 상한 표시") - 옵션 보너스 칸: 활성 옵션 축(장비 3부위 + 보석 5개 합산, 0이 아닌 것만)을 위력 → 신속 → 방어 → 건강 → 성장 → 재생 → 흡혈 순으로 최대 4개.
	local optionStatsBox = box("OptionStats")
	R.optionStatsBox = optionStatsBox
	local optionStatsPadding = Instance.new("UIPadding")
	optionStatsPadding.PaddingLeft = UDim.new(0, 10)
	optionStatsPadding.PaddingRight = UDim.new(0, 10)
	optionStatsPadding.PaddingTop = UDim.new(0, 6)
	optionStatsPadding.Parent = optionStatsBox
	local optionStatsLayout = Instance.new("UIListLayout")
	optionStatsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionStatsLayout.Padding = UDim.new(0, 2)
	optionStatsLayout.Parent = optionStatsBox
	local optionStatsHeader = Instance.new("TextLabel")
	optionStatsHeader.LayoutOrder = 0
	optionStatsHeader.BackgroundTransparency = 1
	optionStatsHeader.Size = UDim2.new(1, 0, 0, 14)
	optionStatsHeader.Font = Enum.Font.GothamBold
	optionStatsHeader.TextSize = Theme.textSize("caption") -- 16-6 [4]: 12px 미만 금지.
	optionStatsHeader.TextXAlignment = Enum.TextXAlignment.Left
	optionStatsHeader.TextColor3 = UIColors.textTertiary
	optionStatsHeader.Text = Text.get("gear.stats.header")
	optionStatsHeader.Parent = optionStatsBox
	-- 25-3: `(상한N%)` 표기(26-3)가 왜 있는지 설명 - 창 왼쪽 단이라 오른쪽(기본값)으로 연다.
	HelpTooltip.attach(optionStatsHeader, UDim2.new(1, -8, 0.5, 0), Text.get("gear.stats.capHelp"))
	local optionRows = {}
	for i = 1, 4 do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 15)
		row.Font = Enum.Font.GothamBold
		row.TextSize = Theme.textSize("caption") -- 16-6 [4]: 12px 미만 금지.
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = UIColors.textSecondary
		row.Text = ""
		row.Visible = false
		row.Parent = optionStatsBox
		table.insert(optionRows, row)
	end

	refs.gear, refs.title, refs.figure, refs.slots = gear, title, figure, slots
	refs.statsBox, refs.statValues = statsBox, statValues
	refs.setBox, refs.setTitle, refs.tierRows, refs.setHint, refs.setHeight = setBox, setTitle, tierRows, setHint, setHeight
	refs.optionStatsBox, refs.optionRows = optionStatsBox, optionRows
end
build()

local gear = refs.gear
R.gearFrame = gear

-- ═══ 총 스탯 · 옵션 보너스 갱신 ═══
local function refreshStats()
	local Option = require(ReplicatedStorage.Shared.Option)
	local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
	local atkValueLabel, defValueLabel, hpValueLabel = refs.statValues[1], refs.statValues[2], refs.statValues[3]

	-- 장비 3부위 옵션 + 보석 5개를 한 목록으로 모은다(PlayerProfile.buildOptionSources와 같은 모양 - 계산은 Option.sumAxisBonus 하나만 쓴다).
	local function clientOptionSources()
		local sources = {}
		for _, item in ipairs({ S.equippedArmor, S.equippedGloves, S.equippedShoes }) do
			if item then
				table.insert(sources, item)
			end
		end
		local gemState = S.gemState and S.gemState()
		for slot = 1, Gem.slotCount do
			if gemState and Gem.isFilled(gemState.gems, slot) then
				table.insert(sources, gemState.gems[slot])
			end
		end
		return sources
	end

	local axes = {
		{ id = "attackPercent", labelKey = "inv.axis.attackPercent" },
		{ id = "speedPercent", labelKey = "inv.axis.speedPercent" },
		{ id = "defensePercent", labelKey = "inv.axis.defensePercent" },
		{ id = "maxHpPercent", labelKey = "gear.stats.maxHpPercent" },
		{ id = "expGain", labelKey = "inv.axis.expGain" },
		{ id = "healingPower", labelKey = "inv.axis.healingPower" },
		{ id = "lifesteal", labelKey = "inv.axis.lifesteal" },
	}

	local function refreshOptionStats(classId)
		local sources = clientOptionSources()
		local rows = refs.optionRows
		local shown = 0
		for _, axis in ipairs(axes) do
			local value = Option.sumAxisBonus(sources, axis.id, classId)
			if math.abs(value) > 0.0005 and shown < #rows then
				shown += 1
				local row = rows[shown]
				local def = OptionData.options[axis.id]
				-- [12] "상한에 걸린 축은 총 스탯 패널에 (상한 N%)를 붙이고 값 텍스트를 ember로".
				local capText = def.cap and Text.get("gear.stats.cap", { cap = ("%d"):format(math.floor(def.cap * 100 + 0.5)) }) or ""
				local atCap = def.cap and value >= def.cap - 0.0005
				row.Text = Text.get("gear.stats.row", { axis = Text.get(axis.labelKey), value = ("%+.1f"):format(value * 100), cap = capText })
				row.TextColor3 = atCap and UIColors.ember or UIColors.textSecondary
				row.Visible = true
			end
		end
		for i = shown + 1, #rows do
			rows[i].Visible = false
		end
	end

	local classId = player:GetAttribute("ClassId")
	local maxHp = player:GetAttribute("MaxHp")
	hpValueLabel.Text = maxHp and NumberFormat.format(maxHp) or "-"
	if not classId or classId == "" then
		atkValueLabel.Text = "-"
		defValueLabel.Text = "-"
		refreshOptionStats(nil)
		return
	end
	local weaponLevel = player:GetAttribute("WeaponLevel") or 0
	local weaponGrade = player:GetAttribute("WeaponGrade") or 0
	local characterLevel = player:GetAttribute("CharacterLevel") or 1
	local weapon = { id = WeaponData.starterId, level = weaponLevel, grade = weaponGrade }
	-- 16-6: 장갑 공격력% 보너스가 공격력 계산에 들어간다 - 서버(AttackServer)와 같은 PlayerCombat.getAttack 인자를 그대로 쓴다.
	local attack = PlayerCombat.getAttack(weapon, classId, characterLevel, Loot.getGlovesAttackPercent(S.equippedGloves), nil, player:GetAttribute("MilestoneMultiplier") or 1,
		{ gloves = S.equippedGloves and S.equippedGloves.itemLevel or 0, shoes = S.equippedShoes and S.equippedShoes.itemLevel or 0 }) -- C5-1 딜 부위 itemLevel 지수 -- P2.5b D: 마일스톤 영구 배율
	local defense = PlayerCombat.getDefense(classId, Loot.getArmorDefense(S.equippedArmor))
	atkValueLabel.Text = NumberFormat.format(attack)
	defValueLabel.Text = NumberFormat.format(defense)
	refreshOptionStats(classId)
end
S.refreshStats = refreshStats

-- ═══ 세트 효과 칸 ═══
local function refreshSetBox()
	if not SetData.enabled then
		refs.setBox.Visible = false
		return
	end
	local equipment = S.equippedByPart()
	local zone, count, scale = SetBonus.state(equipment)
	local name
	if zone then
		for _, part in ipairs(SetData.parts) do
			local item = equipment[part]
			if item and item.setZone == zone then
				name = SetBonus.setName(zone, item.dropStage)
				break
			end
		end
	end
	local oldEmblem = refs.setBox:FindFirstChild("SetEmblem")
	if oldEmblem then
		oldEmblem:Destroy()
	end
	if name then
		refs.setTitle.Text = Text.get("inv.set.title", { name = name })
		local emblem = ItemCell.emblem(refs.setBox, zone, 18)
		if emblem then
			emblem.AnchorPoint = Vector2.new(1, 0)
			emblem.Position = UDim2.new(1, -8, 0, 8)
		end
	else
		refs.setTitle.Text = Text.get("inv.set.titleNone")
	end
	local unique = zone and SetData.uniqueThreePiece and SetData.zoneThreePiece and SetData.zoneThreePiece[zone]
	for i, tier in ipairs(SetData.tiers) do
		local axis, value = tier.axis, tier.value
		if unique and tier.pieces == #SetData.parts then
			axis, value = unique.axis, unique.value
		end
		local active = zone ~= nil and count >= tier.pieces
		local effect = Text.get("inv.set.effect", { axis = Text.get("inv.axis." .. axis), value = percentText(value * (active and scale or 1)) })
		local row = refs.tierRows[i]
		row.label.Text = Text.get(active and "inv.set.tierOn" or "inv.set.tierOff", { pieces = tostring(tier.pieces), effect = effect })
		row.label.TextColor3 = active and UIColors.success or UIColors.textSecondary
		row.dot.BackgroundColor3 = active and UIColors.success or UIColors.panel
		row.dot.BackgroundTransparency = active and 0 or 1
		row.dotStroke.Color = active and UIColors.success or UIColors.textSecondary
	end
	refs.setHint.Text = Text.get("inv.set.hint", { count = tostring(zone and count or 0), total = tostring(#SetData.parts) })
end

local isDoubleClick = ItemActions.doubleClickTracker() -- S20d: 착용 중 칸 더블클릭(0.35초) = 해제
local slotFrames = {} -- 부위 -> 칸

-- 해제 거절 연출의 좌표(S20d): 그 부위 칸의 중심(폰에서 이 탭이 안 보이면 nil).
function S.gearSlotCenter(part)
	return S.visibleCenter(slotFrames[part])
end

-- 고른 칸 = 흰 테두리(가방 칸과 같은 규칙). refreshDetail이 끝날 때마다 부른다.
function S.paintGearSelection()
	for part, slot in pairs(slotFrames) do
		local stroke = slot:FindFirstChild("SelectionStroke")
		if stroke then
			stroke.Transparency = (S.selectedKind == "equip" and S.selectedValue == part) and 0 or 1
		end
	end
end

local function onSlotActivated(part, filled)
	if S.selectedKind == "equip" and S.selectedValue == part and (part == "weapon" or filled) then
		S.selectedKind, S.selectedValue = nil, nil -- P3b C1: 같은 칸을 다시 누르면 상세가 닫힌다(토글). 그 두 번째 클릭이 0.35초 안(PC 더블클릭)이면 기존대로 해제한다.
		if part ~= "weapon" and not S.tapMode() and isDoubleClick(part) then
			S.unequipToBag(part)
			return
		end
	elseif part == "weapon" then
		S.selectedKind, S.selectedValue = "equip", "weapon"
	elseif filled then
		-- S20d: PC 더블클릭 = 해제 / 한 번 클릭 · 탭 방식(폰) = 선택(해제는 상세의 [해제] 버튼). 착용 · 해제는 S.unequipToBag(ItemActions) 한 곳으로 간다.
		if not S.tapMode() and isDoubleClick(part) then
			S.unequipToBag(part)
			return
		end
		S.selectedKind, S.selectedValue = "equip", part
	else
		return -- 빈 칸은 선택할 게 없다
	end
	S.refreshDetail()
end

local function makeSlot(part, order, equipped)
	local item = part ~= "weapon" and equipped[part] or nil
	local filled = part == "weapon" or item ~= nil
	local slot = Instance.new("TextButton")
	slot.Name = "Gear_" .. part
	slot.LayoutOrder = order
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.BackgroundColor3 = UIColors.slot
	slot.BackgroundTransparency = filled and UIColors.slotTransparency or 0.5
	slot.Parent = refs.slots

	local selection = Instance.new("UIStroke")
	selection.Name = "SelectionStroke"
	selection.Thickness = 3
	selection.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	selection.Color = Color3.new(1, 1, 1)
	selection.Transparency = (S.selectedKind == "equip" and S.selectedValue == part) and 0 or 1
	selection.Parent = slot

	local classId = player:GetAttribute("ClassId")
	if part == "weapon" then
		local gradeId = S.weaponGradeId()
		local visual = ItemVisualData.gradeVisuals[gradeId]
		ItemCell.paint(slot, {
			gradeId = gradeId,
			part = "weapon",
			iconKey = ItemIcons.keyFor("weapon", gradeId, nil, classId),
			iconColor = visual and GradeColor.text(gradeId) or UIColors.textPrimary, -- QUEUE-ALL9C 2-2
			iconSize = 30,
			topLeft = { text = ("+%d"):format(player:GetAttribute("WeaponLevel") or 0), color = UIColors.xp }, -- 무기만 강화(+N)가 있다
		}, S.applyGradeVisual)
	elseif item then
		local visual = ItemVisualData.gradeVisuals[item.grade]
		local color = visual and GradeColor.text(item.grade) or UIColors.textPrimary -- QUEUE-ALL9C 2-2
		local topLeft
		local optionTag = item.option and ItemDescribe.optionTag(item, classId)
		if optionTag then
			topLeft = { text = optionTag.text, color = optionTag.mismatched and UIColors.textTertiary or (optionTag.accentClassId and UIColors.classAccent[optionTag.accentClassId]) or color }
		end
		ItemCell.paint(slot, {
			gradeId = item.grade,
			part = part,
			iconKey = ItemIcons.keyFor(part, item.grade, item.itemLevel, nil, item.setZone),
			iconColor = color,
			iconSize = 30,
			topLeft = topLeft,
			level = item.itemLevel,
			locked = item.locked,
			setZone = item.setZone,
		}, S.applyGradeVisual)
	else
		ItemCell.paint(slot, { part = part, iconColor = UIColors.textTertiary, iconSize = 26 }, S.applyGradeVisual) -- 빈 칸: 옅은 테두리 + 흐린 부위 그림
	end

	local nameLabel = Theme.label(slot, Text.name(ItemVisualData.partDisplayNames[part]), "caption", filled and "textSecondary" or "textTertiary")
	nameLabel.Name = "PartName"
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 1, 3)
	nameLabel.Size = UDim2.new(1, 8, 0, LABEL_H - 3)

	slot.Activated:Connect(function()
		onSlotActivated(part, filled)
	end)
	if filled and part ~= "weapon" then
		slot.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				S.unequipToBag(part) -- 우클릭 = 해제(무기는 해제 대상이 아니다)
			end
		end)
	end
	return slot
end

local function rebuildGearSlots()
	if refs.preview then -- QUEUE-ALL6 E4: 장비가 바뀌면 착용 모습 다시(착용 코드가 방어구를 갈아 끼울 시간)
		task.delay(0.6, refs.preview.refresh)
	end
	for _, child in ipairs(refs.slots:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	slotFrames = {}
	local equipped = S.equippedByPart()
	for order, part in ipairs(S.GEAR_ORDER) do
		slotFrames[part] = makeSlot(part, order, equipped)
	end
	refreshSetBox()
	if R.layout then
		R.layoutGear(R.layout)
	end
end
S.rebuildGearSlots = rebuildGearSlots

-- 칸 자리: PC = 캐릭터 둘레(왼쪽 위 갑옷 · 왼쪽 아래 신발 · 오른쪽 위 무기 · 오른쪽 아래 장갑) / 폰 = 4칸 한 줄(무기 · 갑옷 · 장갑 · 신발)
local PC_SPOTS = { armor = { 0, 0 }, shoes = { 0, 1 }, weapon = { 1, 0 }, gloves = { 1, 1 } }

-- 배치: 칸 · 캐릭터 · 스탯 · 세트 · 옵션 칸의 자리를 폭에서 다시 정한다.
function R.layoutGear(L)
	local phone = L.mode == "phone"
	local viewHeight = L.gearH - S.sheetInset
	gear.Position = UDim2.new(0, L.gearX, 0, L.gearY)
	gear.Size = UDim2.new(0, L.gearW, 0, math.max(0, viewHeight))
	gear.BackgroundTransparency = phone and 1 or 0.55
	local size = L.gearSlot
	local width = L.gearW
	local infoX, infoY, infoW
	local slotsBottom
	if phone then
		refs.title.Visible = false
		refs.figure.Visible = false
		for index, part in ipairs(S.GEAR_ORDER) do
			local slot = slotFrames[part]
			if slot then
				slot.Size = UDim2.new(0, size, 0, size)
				slot.Position = UDim2.new(0, 14 + (index - 1) * (size + 10), 0, 8)
			end
		end
		local slotsRight = 14 + #S.GEAR_ORDER * (size + 10)
		slotsBottom = 8 + size + LABEL_H
		if width - slotsRight - 14 >= 240 then
			infoX, infoY, infoW = slotsRight + 4, 8, width - slotsRight - 18
		else
			infoX, infoY, infoW = 14, slotsBottom + 10, width - 28
		end
	else
		refs.title.Visible = true
		local top = 38
		local rowGap = LABEL_H + 10
		local rightX = width - 12 - size
		for part, spot in pairs(PC_SPOTS) do
			local slot = slotFrames[part]
			if slot then
				slot.Size = UDim2.new(0, size, 0, size)
				slot.Position = UDim2.new(0, spot[1] == 0 and 12 or rightX, 0, top + spot[2] * (size + rowGap))
			end
		end
		slotsBottom = top + 2 * size + rowGap + LABEL_H
		local figureW = rightX - (12 + size) - 8
		refs.figure.Visible = figureW >= 56
		refs.figure.Position = UDim2.new(0, 12 + size + 4, 0, top + 6)
		refs.figure.Size = UDim2.new(0, figureW, 0, slotsBottom - top - 6)
		infoX, infoY, infoW = 12, slotsBottom + 10, width - 24
	end
	refs.slots.Size = UDim2.new(1, 0, 0, slotsBottom)
	-- QUEUE-ALL9E1 LOOK2: "내 아바타 옷 보이기" = 장비 칸 바로 아래(폰 = 터치 44 · 칸 줄 폭 / 정보가 아래로 내려가면 그 위에)
	local toggleH = phone and Theme.touchMin or 30
	if refs.clothes then
		if phone and infoX > 14 then
			refs.clothes.Position = UDim2.new(0, 14, 0, slotsBottom + 8)
			refs.clothes.Size = UDim2.new(0, infoX - 4 - 14 - 10, 0, toggleH)
			slotsBottom += 8 + toggleH
		else
			refs.clothes.Position = UDim2.new(0, infoX, 0, infoY)
			refs.clothes.Size = UDim2.new(0, infoW, 0, toggleH)
			infoY += toggleH + 8
		end
	end
	local y = infoY
	refs.statsBox.Position = UDim2.new(0, infoX, 0, y)
	refs.statsBox.Size = UDim2.new(0, infoW, 0, 3 * 22 + 12)
	y += 3 * 22 + 12 + 10
	if refs.setBox.Visible then
		refs.setBox.Position = UDim2.new(0, infoX, 0, y)
		refs.setBox.Size = UDim2.new(0, infoW, 0, refs.setHeight)
		y += refs.setHeight + 10
	end
	refs.optionStatsBox.Position = UDim2.new(0, infoX, 0, y)
	refs.optionStatsBox.Size = UDim2.new(0, infoW, 0, 89)
	y += 89 + 12
	gear.CanvasSize = UDim2.new(0, 0, 0, math.max(y, slotsBottom + 12))
	-- 옵션 보너스 "?" 도움말 버튼: 폰에서는 터치 44(원을 없애고 "?"만 남긴다), PC는 원래 16 원형.
	local help = refs.optionStatsBox:FindFirstChild("HelpButton", true)
	if help then
		help.Size = UDim2.new(0, phone and 44 or 16, 0, phone and 44 or 16)
		help.BackgroundTransparency = phone and 1 or UIColors.panelTransparency
		local helpStroke = help:FindFirstChildOfClass("UIStroke")
		if helpStroke then
			helpStroke.Enabled = not phone
		end
	end
end
table.insert(R.layouts, R.layoutGear)
end

return GearTab
