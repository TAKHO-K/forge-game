-- 파티 목록 뷰(S18, PRD 20.81 [D-2] ML · [D-3] ListRow + Gauge · [D-5] 모바일 축약형). 데이터를 받아 그리기만 한다 - 서버 신호 · Attribute 읽기는 PartyList.client.lua가 한다.
-- 자체 점검(PartyHudCheck)이 두 모드를 직접 지어 보므로 ScreenGui 없이 parent만 받는다.
--   PC(compact = false): 멤버 블록 = ListRow(40: 제목 "★n Lv.35 이름" · 부제 "직업 · 스테이지 N" · 왼쪽 칸 = 직업 첫 글자) + Gauge(10) 체력 줄 - 폭 220. 버프 링(초록) · 쉴드 띠(흰) · 파티장 = 금색 이름은 옛 PartyHud 그대로다.
--   모바일 축약형(compact = true): 이름 없이 체력 줄 4개 · 폭 96 · 파티장은 줄 왼쪽 작은 ●. 행(44)을 누르면 2초간 이름이 뜬다(hover 아님). 경험치 칩도 폭 96.
--   모바일은 세로 중앙에 놓인 목록의 아래 끝이 BL 터치 예약 구역(조이스틱 · 대시 버튼)에 닿으면 메뉴바와 같은 규칙(ScreenMap.mobileMenuBarShiftUp)으로 위로 민다.
-- view = { list, setMembers(members), setExpBonus(bonus), applyPosition(viewportHeight), height(), rowCount(), rows, chip, destroy() }.
-- members[i] = { nameText, level, rebirth, className, stage, ratio(체력 0~1), shieldRatio(0~1), buffActive, isLeader } - nameText는 표시이름(+ "(더미)" · "✚" 꼬리).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local Gauge = require(script.Parent.Parent.ui.kit.Gauge)
local ListRow = require(script.Parent.Parent.ui.kit.ListRow)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Theme = require(script.Parent.Parent.ui.kit.Theme)

local PartyListView = {}

PartyListView.pc = { width = 220, rowHeight = 40, gaugeHeight = 10, gaugeGap = 2, padding = 6, chipWidth = 108, chipBlock = 22 }
PartyListView.compact = { width = 96, rowHeight = 44, gaugeHeight = 10, gaugeWidth = 78, gaugeLeft = 16, gaugeTop = 28, dotSize = 8, padding = 0, chipWidth = 96, chipBlock = 26, tipWidth = 176, tipSeconds = 2 }
local CHIP_HEIGHT = 22
local NAME_SIZE = 14 -- PC 제목 글씨(Theme body) - ★n · Lv 조각은 PlayerLabelFormat이 한 단계 낮춘다

local function firstChar(text)
	local stop = utf8.offset(text, 2)
	return stop and text:sub(1, stop - 1) or text
end

-- 목록 높이(px): 멤버 count명 + 경험치 칩(보이면). 순수 함수 - 자체 점검이 폰 높이별로 그대로 부른다.
function PartyListView.heightFor(count, chipVisible, compact)
	local m = compact and PartyListView.compact or PartyListView.pc
	local memberHeight = compact and m.rowHeight or (m.rowHeight + m.gaugeGap + m.gaugeHeight)
	local blocks = count + (chipVisible and 1 or 0)
	local height = count * memberHeight + (chipVisible and m.chipBlock or 0)
	return height + math.max(0, blocks - 1) * m.padding
end

local function addShield(gauge)
	-- S13b: 쉴드 총량 - 체력 막대 위쪽 절반에 겹쳐 그리는 흰 띠(폭 = 쉴드 ÷ 최대체력, 최대 100%).
	local shield = Instance.new("Frame")
	shield.Name = "ShieldFill"
	shield.Size = UDim2.new(0, 0, 0, 3)
	shield.BackgroundColor3 = Color3.new(1, 1, 1)
	shield.BorderSizePixel = 0
	shield.Visible = false
	shield.ZIndex = 2
	shield.Parent = gauge.root
	return shield
end

local function setGauge(gauge, shield, ratio, shieldRatio)
	if math.abs(gauge.getValue() - ratio) > 1e-4 then
		gauge.setValue(ratio)
	end
	shield.Visible = shieldRatio > 0
	shield.Size = UDim2.new(shieldRatio, 0, 0, 3)
end

-- PC 멤버 블록: ListRow(40) + Gauge(10)
local function buildPcMember(list, order)
	local m = PartyListView.pc
	local block = Instance.new("Frame")
	block.Name = "PartyMember" .. order
	block.LayoutOrder = order
	block.Size = UDim2.new(0, m.width, 0, m.rowHeight + m.gaugeGap + m.gaugeHeight)
	block.BackgroundTransparency = 1
	block.Parent = list

	local row = ListRow.build({ parent = block, name = "PartyRow", height = m.rowHeight, width = m.width, title = "", subtitle = "", iconText = "" })
	row.root.Active = false -- 목록 위를 눌러도 기본공격 입력을 먹지 않는다(옛 Frame 목록과 같다)
	local title = row.root:FindFirstChild("Title")
	title.RichText = true
	title.Font = Theme.font
	local icon = row.root:FindFirstChild("Icon")
	local stroke = row.root:FindFirstChildOfClass("UIStroke")
	local gauge = Gauge.build({ parent = block, name = "HealthGauge", height = m.gaugeHeight, width = m.width, position = UDim2.new(0, 0, 0, m.rowHeight + m.gaugeGap), trackColorName = "hpDark", fillColorName = "hp" })
	local shield = addShield(gauge)

	local refs = { block = block, row = row, gauge = gauge, title = title, icon = icon, stroke = stroke, shield = shield }
	function refs.apply(data)
		title.Text = PlayerLabelFormat.richText(data.nameText, data.level, data.rebirth, NAME_SIZE)
		title.TextColor3 = data.isLeader and UIColors.gold or UIColors.textPrimary
		icon.Text = firstChar(data.className)
		row.setSubtitle(("%s · 스테이지 %s"):format(data.className, tostring(data.stage or "-")))
		setGauge(gauge, shield, data.ratio, data.shieldRatio)
		-- 24-3: 링 색으로 버프 여부를 구분한다(새 파티클 · 새 색 없이 기존 rim/success 재사용).
		stroke.Color = data.buffActive and UIColors.success or UIColors.rim
		stroke.Transparency = data.buffActive and 0.2 or UIColors.rimTransparency
	end
	function refs.setVisible(visible)
		block.Visible = visible
	end
	return refs
end

-- 모바일 축약 행: 체력 줄 + 파티장 ● + 누르면 2초간 이름
local function buildCompactMember(list, order)
	local m = PartyListView.compact
	local button = Instance.new("TextButton")
	button.Name = "PartyMember" .. order
	button.LayoutOrder = order
	button.AutoButtonColor = false
	button.Text = ""
	button.Size = UDim2.new(0, m.width, 0, m.rowHeight)
	button.BackgroundTransparency = 1
	button.Parent = list

	local dot = Instance.new("Frame")
	dot.Name = "LeaderDot"
	dot.Size = UDim2.new(0, m.dotSize, 0, m.dotSize)
	dot.Position = UDim2.new(0, 4, 0, m.gaugeTop + (10 - m.dotSize) / 2)
	dot.BackgroundColor3 = UIColors.gold
	dot.BorderSizePixel = 0
	dot.Visible = false
	dot.Parent = button
	Theme.corner(dot, m.dotSize / 2)

	local gauge = Gauge.build({ parent = button, name = "HealthGauge", height = m.gaugeHeight, width = m.gaugeWidth, position = UDim2.new(0, m.gaugeLeft, 0, m.gaugeTop), trackColorName = "hpDark", fillColorName = "hp" })
	local shield = addShield(gauge)

	local tip = Instance.new("Frame")
	tip.Name = "NameTip"
	tip.Position = UDim2.new(0, m.gaugeLeft, 0, 2)
	tip.Size = UDim2.new(0, m.tipWidth, 0, CHIP_HEIGHT)
	tip.BackgroundColor3 = UIColors.panel
	tip.BackgroundTransparency = UIColors.panelTransparency
	tip.Visible = false
	tip.ZIndex = 3
	tip.Parent = button
	Theme.corner(tip, Theme.corner.chip)
	local tipLabel = Theme.label(tip, "", "caption", "textPrimary")
	tipLabel.Name = "Text"
	tipLabel.RichText = true
	tipLabel.Position = UDim2.new(0, 6, 0, 0)
	tipLabel.Size = UDim2.new(1, -12, 1, 0)
	tipLabel.ZIndex = 4

	local refs = { block = button, gauge = gauge, dot = dot, tip = tip, tipLabel = tipLabel, shield = shield, tipToken = 0 }
	function refs.apply(data)
		dot.Visible = data.isLeader == true
		tipLabel.Text = PlayerLabelFormat.richText(data.nameText, data.level, data.rebirth, Theme.textSize("caption"))
		setGauge(gauge, shield, data.ratio, data.shieldRatio)
	end
	function refs.setVisible(visible)
		button.Visible = visible
		if not visible then
			tip.Visible = false
		end
	end
	function refs.showTip()
		refs.tipToken += 1
		local token = refs.tipToken
		tip.Visible = true
		task.delay(m.tipSeconds, function()
			if refs.tipToken == token then
				tip.Visible = false
			end
		end)
	end
	button.Activated:Connect(refs.showTip)
	return refs
end

function PartyListView.build(opts)
	local compact = opts.compact == true
	local m = compact and PartyListView.compact or PartyListView.pc

	local list = Instance.new("Frame")
	list.Name = "PartyList"
	ScreenMap.place(list, "ML", "partyList") -- S16: 메뉴바 오른쪽 옆(x = 14 + 48 + 8)
	list.AutomaticSize = Enum.AutomaticSize.XY
	list.Size = UDim2.new(0, 0, 0, 0)
	list.BackgroundTransparency = 1
	list.Visible = false
	list.Parent = opts.parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, m.padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- 30-0 S09(PRD 20.73 [6]): 목록 맨 위의 "경험치 +20%" 칩 - 도움말을 안 열어도 파티의 이득이 보인다. 0이면(솔로 · 더미만 있는 파티) 숨긴다.
	local chipHolder = Instance.new("Frame")
	chipHolder.Name = "PartyExpChipHolder"
	chipHolder.LayoutOrder = 0
	chipHolder.Size = UDim2.new(0, m.chipWidth, 0, m.chipBlock)
	chipHolder.BackgroundTransparency = 1
	chipHolder.Visible = false
	chipHolder.Parent = list
	local chip = Instance.new("Frame")
	chip.Name = "PartyExpChip"
	chip.Size = UDim2.new(1, 0, 0, CHIP_HEIGHT)
	chip.BackgroundColor3 = UIColors.panel
	chip.BackgroundTransparency = UIColors.panelTransparency
	chip.Parent = chipHolder
	Theme.corner(chip, CHIP_HEIGHT / 2)
	local chipStroke = Theme.stroke(chip)
	chipStroke.Color = UIColors.success
	chipStroke.Transparency = 0.4
	local chipText = Theme.label(chip, "", "caption", "success")
	chipText.Name = "Text"
	chipText.Font = Theme.font
	chipText.Size = UDim2.new(1, 0, 1, 0)
	chipText.TextXAlignment = Enum.TextXAlignment.Center

	local view = { list = list, chip = chip, chipHolder = chipHolder, rows = {}, compact = compact, memberCount = 0 }

	function view.height()
		return PartyListView.heightFor(view.memberCount, chipHolder.Visible, compact)
	end

	function view.setExpBonus(bonus)
		chipHolder.Visible = bonus > 0
		if bonus > 0 then
			chipText.Text = ("경험치 +%d%%"):format(math.floor(bonus * 100 + 0.5))
		end
	end

	function view.setMembers(members)
		view.memberCount = #members
		for index = #view.rows + 1, #members do
			view.rows[index] = compact and buildCompactMember(list, index) or buildPcMember(list, index)
		end
		for index, row in ipairs(view.rows) do
			local data = members[index]
			row.setVisible(data ~= nil)
			if data then
				row.apply(data)
			end
		end
		list.Visible = #members > 0
	end

	-- 모바일: 세로 중앙 목록의 아래 끝이 BL 터치 예약 구역 위 끝에 닿으면 닿지 않을 만큼만 위로 민다(메뉴바와 같은 함수). PC는 슬롯 그대로.
	function view.applyPosition(viewportHeight)
		local slotDef = ScreenMap.slot("ML", "partyList")
		local shift = compact and ScreenMap.mobileMenuBarShiftUp(viewportHeight, view.height()) or 0
		list.Position = UDim2.new(slotDef.position.X.Scale, slotDef.position.X.Offset, slotDef.position.Y.Scale, slotDef.position.Y.Offset - shift)
		return shift
	end

	function view.rowCount()
		return view.memberCount
	end

	function view.destroy()
		list:Destroy()
	end

	return view
end

return PartyListView
