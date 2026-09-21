local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Gem = require(ReplicatedStorage.Shared.Gem)
local HelpTooltip = require(script.Parent.Parent.Parent.HelpTooltip)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Layout = require(script.Parent.Layout)

-- 장비 칸(S20b: InventoryUI 분할) - 착용 중 4칸(무기 · 갑옷 · 장갑 · 신발) · 옵션 보너스 박스 · 총 스탯 3줄. 세로 스크롤 ScrollingFrame이다(PC = 왼쪽 칸 · 폰 = "장비" 탭 본문).
local GearTab = {}

function GearTab.create(S, R)
local player = S.player
local content = R.content
local GEAR_SLOT_SIZE = Layout.gearSlot

local gear = Instance.new("ScrollingFrame")
gear.Name = "Gear"
gear.BackgroundTransparency = 1
gear.BorderSizePixel = 0
gear.ScrollBarThickness = 4
gear.CanvasSize = UDim2.new(0, 0, 0, 0)
gear.Parent = content
R.gearFrame = gear

local gearRightLine = Instance.new("Frame") -- PC: 장비 칸과 가방 사이 세로선
gearRightLine.AnchorPoint = Vector2.new(1, 0)
gearRightLine.Position = UDim2.new(1, 0, 0, 0)
gearRightLine.BackgroundColor3 = UIColors.rim
gearRightLine.BackgroundTransparency = UIColors.rimTransparency
gearRightLine.BorderSizePixel = 0
gearRightLine.Parent = gear

S.makeSectionLabel(gear, "착용 중", 14)

local gearGrid = Instance.new("Frame")
gearGrid.Position = UDim2.new(0, 14, 0, 34)
gearGrid.Size = UDim2.new(1, -28, 0, GEAR_SLOT_SIZE * 2 + 9)
gearGrid.BackgroundTransparency = 1
gearGrid.Parent = gear

local gearGridLayout = Instance.new("UIGridLayout")
gearGridLayout.CellSize = UDim2.new(0, GEAR_SLOT_SIZE, 0, GEAR_SLOT_SIZE)
gearGridLayout.CellPadding = UDim2.new(0, 9, 0, 9)
gearGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gearGridLayout.Parent = gearGrid

-- 26-3(PRD 20.67 [12] "총 스탯 상한 표시") - 옛 "특수 옵션 · 전설 이상에서 표시" 자리
-- 표시("연속격" 등 규칙형 옵션 시절의 미구현 placeholder, 지금 옵션 체계와 무관)를
-- 재사용한다 - 총 스탯 3줄 위 89px가 이미 이 목적으로 예약돼 있었다(새 자리를 만들지
-- 않는다). 활성 옵션 축(장비 3부위+보석 5개 합산, 0이 아닌 것만)을 위력→신속→방어→건강→
-- 성장→재생→흡혈 순으로 최대 4개까지 보여준다. 함수로 감싸 내부 부품(박스·패딩·레이아웃·
-- 헤더)이 최상위 레지스터를 안 먹게 한다(setupOptionRow와 같은 이유 - 200개 한계 실측).
local optionStatsRows
do
	local function setupOptionStatsBox()
		local optionStatsBox = Instance.new("Frame")
		optionStatsBox.Position = UDim2.new(0, 14, 0, 34 + GEAR_SLOT_SIZE * 2 + 9 + 12)
		optionStatsBox.Size = UDim2.new(1, -28, 0, 89)
		optionStatsBox.BackgroundTransparency = 1
		optionStatsBox.Parent = gear
		R.optionStatsBox = optionStatsBox
		do
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 7)
			corner.Parent = optionStatsBox
			local stroke = Instance.new("UIStroke")
			stroke.Color = UIColors.rim
			stroke.Transparency = 0.84
			stroke.Parent = optionStatsBox
		end

		local optionStatsPadding = Instance.new("UIPadding")
		optionStatsPadding.PaddingLeft = UDim.new(0, 8)
		optionStatsPadding.PaddingRight = UDim.new(0, 8)
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
		optionStatsHeader.Text = "옵션 보너스"
		optionStatsHeader.Parent = optionStatsBox

		-- 25-3: `(상한N%)` 표기(26-3)가 왜 있는지 설명이 없어서 붙인다(단계 3). 이 박스는
		-- 창 왼쪽에 붙어 있어 패널을 왼쪽으로 열면 창 밖으로 잘린다 - 오른쪽(기본값)으로 연다.
		HelpTooltip.attach(optionStatsHeader, UDim2.new(1, -8, 0.5, 0),
			"스탯마다 상한이 있습니다. 상한에 도달하면 초과분은 버려집니다.")

		local rows = {}
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
			table.insert(rows, row)
		end
		return rows
	end
	optionStatsRows = setupOptionStatsBox()
end

-- 총 스탯 3줄. reserved 바로 아래, 위쪽 테두리로 구분한다(목업 .stats border-top).
local statsTop = 34 + GEAR_SLOT_SIZE * 2 + 9 + 12 + 89 + 12
local statsBorder = Instance.new("Frame")
statsBorder.Position = UDim2.new(0, 14, 0, statsTop)
statsBorder.Size = UDim2.new(1, -28, 0, 1)
statsBorder.BackgroundColor3 = UIColors.rim
statsBorder.BackgroundTransparency = UIColors.rimTransparency
statsBorder.BorderSizePixel = 0
statsBorder.Parent = gear

local statRows = {} -- 배치(layout)가 y를 다시 정하는 총 스탯 줄
local function makeStatRow(labelText, valueColor, y)
	local row = Instance.new("Frame")
	row.Position = UDim2.new(0, 14, 0, y)
	row.Size = UDim2.new(1, -28, 0, 20)
	row.BackgroundTransparency = 1
	row.Parent = gear
	table.insert(statRows, row)

	local key = Instance.new("TextLabel")
	key.BackgroundTransparency = 1
	key.Size = UDim2.new(0.5, 0, 1, 0)
	key.Font = Enum.Font.GothamBold
	key.TextSize = Theme.textSize("caption") -- 16-6 [4]: 12px 미만 금지.
	key.TextColor3 = UIColors.textTertiary
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.Text = labelText
	key.Parent = row

	local value = Instance.new("TextLabel")
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, 0, 0, 0)
	value.Size = UDim2.new(0.5, 0, 1, 0)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.TextSize = Theme.textSize("body")
	value.TextColor3 = valueColor
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Text = "-"
	value.Parent = row

	return value
end

local statsY = statsTop + 12
local atkValueLabel = makeStatRow("공격력", UIColors.ember, statsY)
local defValueLabel = makeStatRow("방어력", Color3.fromRGB(127, 179, 232), statsY + 26)
local hpValueLabel = makeStatRow("최대 체력", UIColors.hp, statsY + 52)

-- ═══ 총 스탯 갱신 ═══

local function refreshStats()
	-- 26-3 수정: refreshOptionStats를 S.refreshStats 안으로 완전히 옮긴다(refreshStats가
	-- 유일한 호출부다) - 최상위 레지스터를 하나도 안 먹게 한다(위 InfiniteStage 주석과
	-- 같은 이유, 실제로 여기까지 옮겨도 여전히 200 한계를 넘겨 이렇게까지 해야 했다).
	local Option = require(ReplicatedStorage.Shared.Option)
	local OptionData = require(ReplicatedStorage.Shared.data.OptionData)

	-- 장비 3부위 옵션 + 보석 5개를 한 목록으로 모은다(PlayerProfile.buildOptionSources와
	-- 같은 모양 - 서버 전용 모듈이라 여기선 같은 필드({option,grade,itemLevel})를 그대로
	-- 다시 조립한다. 계산 자체는 새로 만들지 않는다 - Option.sumAxisBonus 하나만 쓴다).
	local function clientOptionSources()
		local sources = {}
		for _, item in ipairs({ S.equippedArmor, S.equippedGloves, S.equippedShoes }) do
			if item then
				table.insert(sources, item)
			end
		end
		for slot = 1, Gem.slotCount do
			if Gem.isFilled(S.gemState().gems, slot) then
				table.insert(sources, S.gemState().gems[slot])
			end
		end
		return sources
	end

	-- 옵션 보너스 박스(위 optionStatsRows)에 보일 축 순서 - [2] 표 순서(위력·신속 DPS,
	-- 방어·건강 생존, 성장·재생·흡혈 유틸).
	local axes = {
		{ id = "attackPercent", label = "위력" },
		{ id = "speedPercent", label = "신속" },
		{ id = "defensePercent", label = "방어" },
		{ id = "maxHpPercent", label = "건강" },
		{ id = "expGain", label = "성장" },
		{ id = "healingPower", label = "재생" },
		{ id = "lifesteal", label = "흡혈" },
	}

	local function refreshOptionStats(classId)
		local sources = clientOptionSources()
		local shown = 0
		for _, axis in ipairs(axes) do
			local value = Option.sumAxisBonus(sources, axis.id, classId)
			if math.abs(value) > 0.0005 and shown < #optionStatsRows then
				shown += 1
				local row = optionStatsRows[shown]
				local def = OptionData.options[axis.id]
				-- [12] "상한에 걸린 축은 총 스탯 패널에 (상한 N%)를 붙이고 값 텍스트를
				-- ember로".
				local capText = def.cap and (" (상한%d)"):format(math.floor(def.cap * 100 + 0.5)) or ""
				local atCap = def.cap and value >= def.cap - 0.0005
				row.Text = ("%s %+.1f%%%s"):format(axis.label, value * 100, capText)
				row.TextColor3 = atCap and UIColors.ember or UIColors.textSecondary
				row.Visible = true
			end
		end
		for i = shown + 1, #optionStatsRows do
			optionStatsRows[i].Visible = false
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
	-- 16-6: 장갑 공격력% 보너스가 공격력 계산에 들어간다 - 서버(AttackServer)와 같은
	-- PlayerCombat.getAttack 4번째 인자를 그대로 쓴다.
	local attack = PlayerCombat.getAttack(weapon, classId, characterLevel, Loot.getGlovesAttackPercent(S.equippedGloves))
	local defense = PlayerCombat.getDefense(classId, Loot.getArmorDefense(S.equippedArmor))

	atkValueLabel.Text = NumberFormat.format(attack)
	defValueLabel.Text = NumberFormat.format(defense)
	refreshOptionStats(classId)
end

S.refreshStats = refreshStats

local function rebuildGearSlots()
	for _, child in ipairs(gearGrid:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local equipped = S.equippedByPart()

	for order, part in ipairs(S.GEAR_ORDER) do
		local filled = part == "weapon" or equipped[part] ~= nil
		-- 16-6부터 갑옷·장갑·신발 전부 실제로 착용·해제할 수 있다 - 셋 다 클릭 가능.
		local interactive = true

		local slot = Instance.new(interactive and "TextButton" or "Frame")
		slot.Name = "Gear_" .. part
		slot.LayoutOrder = order
		slot.BackgroundColor3 = UIColors.slot
		slot.BackgroundTransparency = UIColors.slotTransparency
		if slot:IsA("TextButton") then
			slot.Text = ""
			slot.AutoButtonColor = false
		end
		slot.Parent = gearGrid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = slot

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Parent = slot

		local color = UIColors.textTertiary
		if filled then
			if part == "weapon" then
				local visual = ItemVisualData.gradeVisuals[S.weaponGradeId()]
				color = visual and visual.color or UIColors.textPrimary
				stroke.Color = color
				stroke.Transparency = 0
			else
				local visual = ItemVisualData.gradeVisuals[equipped[part].grade]
				color = visual and visual.color or UIColors.textPrimary
				stroke.Color = color
				stroke.Transparency = 0
			end
		else
			-- 빈 슬롯은 점선(지시 - "아직 못 채운 칸이 눈에 보여야 파밍 동기가 생긴다").
			stroke.Color = UIColors.rim
			stroke.Transparency = 0.4
			-- Roblox UIStroke는 점선을 못 그린다(LineJoinMode/ApplyStrokeMode 어느 쪽도
			-- 점선 옵션이 없다) - 대신 살짝 더 옅고 배경을 더 어둡게 해 "비어 있다"는
			-- 인상을 준다(색만으로 구분, 목업의 점선 대체).
			slot.BackgroundTransparency = 0.5
		end

		local iconHolder = Instance.new("Frame")
		iconHolder.AnchorPoint = Vector2.new(0.5, 0.42)
		iconHolder.Position = UDim2.new(0.5, 0, 0.42, 0)
		iconHolder.Size = UDim2.new(0, 26, 0, 26)
		iconHolder.BackgroundTransparency = 1
		iconHolder.Parent = slot
		ItemIcons.byPart[part](iconHolder, 26, color)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.Position = UDim2.new(0.5, 0, 1, -8)
		nameLabel.Size = UDim2.new(1, -8, 0, 14) -- 16-6 [4]: 9.5->12px로 키운 만큼 높이도 12->14.
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = Theme.textSize("caption")
		nameLabel.TextColor3 = filled and UIColors.textSecondary or UIColors.textTertiary
		nameLabel.Text = ItemVisualData.partDisplayNames[part]
		nameLabel.Parent = slot

		if filled then
			local level = part == "weapon" and (player:GetAttribute("WeaponLevel") or 0) or equipped[part].itemLevel
			local lvTag = Instance.new("TextLabel")
			lvTag.AnchorPoint = Vector2.new(1, 1)
			lvTag.Position = UDim2.new(1, -5, 1, -4)
			lvTag.Size = UDim2.new(0, 38, 0, 14) -- 16-6 [4]: 9->12px로 키운 만큼 높이도 12->14, 폭도 34->38.
			lvTag.BackgroundTransparency = 1
			lvTag.Font = Enum.Font.GothamBold
			lvTag.TextSize = Theme.textSize("caption")
			lvTag.TextXAlignment = Enum.TextXAlignment.Right
			lvTag.TextColor3 = UIColors.textTertiary
			lvTag.Text = ("Lv.%d"):format(level)
			lvTag.Parent = slot

			-- 26-3(PRD 20.67 [12] "가방 셀 옵션 태그는 기존 lvTag와 같은 규격의 두 번째
			-- 태그") - 착용 부위(무기 제외)에 옵션이 있으면 같은 방식으로 보여준다.
			local optionItem = part ~= "weapon" and equipped[part]
			if optionItem and optionItem.option then
				-- 옵션 이름 · 직업 불일치 · 직업색은 ItemDescribe.optionTag(S20). 색: 불일치 = 회색이 우선 · 직업 특화 옵션 = 직업색(S13 미결 3) · 공통 옵션 = 등급색.
				local tag = ItemDescribe.optionTag(optionItem, player:GetAttribute("ClassId"))
				if tag then
					local optionVisual = ItemVisualData.gradeVisuals[optionItem.grade]
					local optionTag = Instance.new("TextLabel")
					optionTag.AnchorPoint = Vector2.new(0, 1)
					optionTag.Position = UDim2.new(0, 5, 1, -4)
					optionTag.Size = UDim2.new(0, 44, 0, 14)
					optionTag.BackgroundTransparency = 1
					optionTag.Font = Enum.Font.GothamBold
					optionTag.TextSize = Theme.textSize("caption")
					optionTag.TextXAlignment = Enum.TextXAlignment.Left
					optionTag.TextTruncate = Enum.TextTruncate.AtEnd
					optionTag.TextColor3 = tag.mismatched and UIColors.textTertiary
						or (tag.accentClassId and UIColors.classAccent[tag.accentClassId])
						or (optionVisual and optionVisual.color or UIColors.textPrimary)
					optionTag.Text = tag.text
					optionTag.Parent = slot
				end
			end
		end

		if interactive then
			slot.Activated:Connect(function()
				if part == "weapon" then
					S.selectedKind, S.selectedValue = "equip", "weapon"
				elseif filled then
					S.selectedKind, S.selectedValue = "equip", part
				else
					return -- 빈 슬롯은 선택할 게 없다(착용된 것도, 보관함에서 고른 것도 아니다).
				end
				S.refreshDetail()
			end)
		end
	end
end
S.rebuildGearSlots = rebuildGearSlots

-- 배치(S20b): 착용 칸 열 수 · 세로 위치를 폭에서 다시 정한다. 폰(폭 넓음)은 4칸이 한 줄, PC(폭 228)는 2 × 2.
table.insert(R.layouts, function(L)
	gear.Position = UDim2.new(0, 0, 0, L.bodyTop)
	gear.Size = L.mode == "phone" and UDim2.new(1, 0, 0, L.bodyH) or UDim2.new(0, L.gearW, 0, L.bodyH)
	local cols = L.gearCols
	local rows = math.ceil(#S.GEAR_ORDER / cols)
	local gridHeight = rows * GEAR_SLOT_SIZE + (rows - 1) * 9
	gearGridLayout.FillDirectionMaxCells = cols
	gearGrid.Size = UDim2.new(1, -28, 0, gridHeight)
	R.optionStatsBox.Position = UDim2.new(0, 14, 0, 34 + gridHeight + 12)
	local top = 34 + gridHeight + 12 + 89 + 12
	statsBorder.Position = UDim2.new(0, 14, 0, top)
	for i, row in ipairs(statRows) do
		row.Position = UDim2.new(0, 14, 0, top + 12 + (i - 1) * 26)
	end
	local canvasHeight = math.max(top + 12 + 52 + 20 + 14, L.bodyH)
	gear.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
	gearRightLine.Size = UDim2.new(0, 1, 0, canvasHeight)
	gearRightLine.Visible = L.mode == "pc"
end)
end

return GearTab
