-- QUEUE-ALL9B R 재화 칸(공용 - HUD 오른쪽 위 재화 칸 · 가방 위쪽 재화 줄이 같은 모듈). 재화 목록 = ItemInfoData.currencyBar(기존 재화만).
--   값 = 서버가 내리는 Player Attribute(ItemInfoData.items[id].owned.attr)만 읽는다 - 클라가 계산한 값을 믿지 않는다.
--   표기 = NumberFormat.currency(1만 미만 쉼표 · ko 만/억 · en K/M/B) · 정확한 값 = PC 마우스 올리기 / 폰 길게 누르기(그동안 숫자 자리에 쉼표 값).
--   늘어나면 숫자 옆 "+n"이 gainSeconds 동안 떠올랐다 사라진다: batchSeconds 안의 여러 변화는 하나로 묶고 · 한 칸에서 초당 2.5번 넘게 새로 뜨지 않으며(깜빡임 < 3/s) ·
--   보유량의 10% 이상 = 금색 굵게(큰 변화만 강조) · 줄어듦은 숫자만 바뀐다.
--   ALL9C 창 이동 · 저장 규칙에 넣을 수 있게 칸 루트에 Attribute HudSlot = "currency"(HUD) / "currencyBag"(가방)를 붙인다(이름 · 위치는 호출부가 정한다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ItemInfoData = require(ReplicatedStorage.Shared.data.ItemInfoData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local ArtImage = require(script.Parent.ArtImage)

local CurrencyBar = {}
CurrencyBar.cfg = ItemInfoData.currencyBar

local player = Players.LocalPlayer
local MIN_GAP = 0.4 -- 한 칸 "+n" 새로 뜨는 최소 간격(초당 2.5번)

function CurrencyBar.attrOf(id)
	local item = ItemInfoData.items[id]
	return item and item.owned and item.owned.attr
end

function CurrencyBar.valueOf(id)
	local attr = CurrencyBar.attrOf(id)
	return attr and tonumber(player:GetAttribute(attr)) or 0
end

function CurrencyBar.text(value)
	return NumberFormat.currency(value, Text.languageFor())
end

-- 재화 하나(아이콘 + 숫자 + 떠오르는 +n). opts = { height, iconSize, textSize, order }. 반환: 칸 Frame
function CurrencyBar.item(parent, id, opts)
	opts = opts or {}
	local height = opts.height or 26
	local frame = Instance.new("TextButton") -- 칸 자체가 누르기 · 올리기 · 길게 누르기를 받는다(자동 폭 칸 안에 꽉 찬 버튼을 두면 서로 늘어난다)
	frame.Text = ""
	frame.AutoButtonColor = false
	frame.Name = "Cur_" .. id
	frame.LayoutOrder = opts.order or 0
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Size = UDim2.new(0, 0, 0, height)
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local iconSize = opts.iconSize or math.floor(height * 0.8)
	local icon = ArtImage.label(frame, "icons/reward/" .. id, UDim2.fromOffset(iconSize, iconSize), "")
	icon.Name = "Icon"
	icon.LayoutOrder = 1
	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = opts.textSize or 13
	label.TextColor3 = UIColors.textPrimary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame
	-- 떠오르는 +n(숫자 칸의 자식 = 목록 배치 밖)
	local gain = Instance.new("TextLabel")
	gain.Name = "Gain"
	gain.BackgroundTransparency = 1
	-- 자리: "above" = 숫자 위(가방 줄 - 위는 헤더 띠) · "left" = 칸 왼쪽 바깥(HUD - 위는 지역 이름 · 아래는 Lv 칩이라 비어 있는 왼쪽)
	local side = opts.gainSide or "above"
	local gainFrom = side == "left" and UDim2.new(0, -8, 0.5, 0) or UDim2.new(1, 0, 0, 2)
	local gainTo = side == "left" and UDim2.new(0, -8, 0.5, -8) or UDim2.new(1, 0, 0, -8)
	gain.AnchorPoint = side == "left" and Vector2.new(1, 0.5) or Vector2.new(1, 1)
	gain.Position = gainFrom
	gain.AutomaticSize = Enum.AutomaticSize.X
	gain.Size = UDim2.new(0, 0, 0, 14)
	gain.Font = Enum.Font.GothamBold
	gain.TextSize = 12
	gain.TextTransparency = 1
	gain.TextXAlignment = Enum.TextXAlignment.Right
	gain.ZIndex = label.ZIndex + 1
	gain.Parent = side == "left" and icon or label -- 목록 배치 밖(칸 자식이면 UIListLayout이 줄에 끼운다)

	local connections = {}
	local attr = CurrencyBar.attrOf(id)
	local shown = CurrencyBar.valueOf(id)
	local exact = false
	local pending, scheduled, lastShow = 0, false, -math.huge
	local function render()
		label.Text = exact and NumberFormat.commas(shown) or CurrencyBar.text(shown)
	end
	local function showGain()
		scheduled = false
		if pending <= 0 or not frame.Parent then
			pending = 0
			return
		end
		local wait = lastShow + MIN_GAP - os.clock()
		if wait > 0 then -- 깜빡임 제한: 다음 칸으로 미루며 계속 묶는다
			scheduled = true
			task.delay(wait, showGain)
			return
		end
		local big = pending >= math.max(shown, 1) * 0.1
		gain.Text = "+" .. CurrencyBar.text(pending)
		gain.TextColor3 = big and UIColors.gold or UIColors.success
		gain.TextSize = big and 13 or 12
		gain.Position = gainFrom
		gain.TextTransparency = 0
		local t = TweenInfo.new(CurrencyBar.cfg.gainSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(gain, t, { Position = gainTo, TextTransparency = 1 }):Play()
		pending = 0
		lastShow = os.clock()
	end
	if attr then
		table.insert(connections, player:GetAttributeChangedSignal(attr):Connect(function()
			local v = CurrencyBar.valueOf(id)
			local delta = v - shown
			shown = v
			render()
			if delta > 0 then
				pending += delta
				if not scheduled then
					scheduled = true
					task.delay(CurrencyBar.cfg.batchSeconds, showGain)
				end
			end
		end))
	end
	-- 정확한 값: PC = 마우스 올리기 · 폰 = 0.5초 길게 누르기(떼면 돌아감)
	local hit = frame
	if opts.onActivated then -- HUD 칸 펼치기 등(누르기 = 호출부)
		table.insert(connections, hit.Activated:Connect(opts.onActivated))
	end
	local function setExact(on)
		exact = on
		render()
	end
	table.insert(connections, hit.MouseEnter:Connect(function()
		setExact(true)
	end))
	table.insert(connections, hit.MouseLeave:Connect(function()
		setExact(false)
	end))
	table.insert(connections, hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			local token = {}
			hit:SetAttribute("PressToken", tostring(token))
			task.delay(0.5, function()
				if hit:GetAttribute("PressToken") == tostring(token) then
					setExact(true)
				end
			end)
		end
	end))
	table.insert(connections, hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			hit:SetAttribute("PressToken", nil)
			setExact(false)
		end
	end))
	frame.Destroying:Connect(function()
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
	end)
	render()
	return frame
end

-- 재화 여러 개를 한 줄(넘치면 다음 줄 - wrap)로. 반환: 줄 Frame
function CurrencyBar.row(parent, ids, opts)
	opts = opts or {}
	local row = Instance.new("Frame")
	row.Name = opts.name or "CurrencyRow"
	row.BackgroundTransparency = 1
	row.Size = opts.size or UDim2.new(1, 0, 0, opts.height or 26)
	row.AutomaticSize = opts.automaticSize or Enum.AutomaticSize.None
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = opts.vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = opts.align or Enum.HorizontalAlignment.Left
	layout.Padding = UDim.new(0, opts.gap or 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Wraps = opts.wrap == true
	layout.Parent = row
	for i, id in ipairs(ids) do
		CurrencyBar.item(row, id, { height = opts.itemHeight or 22, textSize = opts.textSize, order = i, onActivated = opts.onActivated, gainSide = opts.gainSide })
	end
	return row
end

return CurrencyBar
