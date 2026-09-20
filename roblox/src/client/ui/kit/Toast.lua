-- 토스트(30-0 S06, PRD 20.81 [D-3]). 줄(lane) 3개: TC(시스템 · 1행 · 3초) · TR(드랍 피드 · 3줄 · 4초) · BC(획득 팝업 · 1행 · 3초).
-- 새 알림은 직접 Frame을 세우지 않고 Toast.push(lane, { text, colorName, seconds, priority, groupKey, richParts, fadeSeconds, moreFormat, rainbow })로만 낸다.
--   · richParts = { { text, colorName | color(Color3), size?(px), bold?, onActivate? }, ... } - 한 행 안에서 부분마다 색을 다르게(RichText). 없으면 text 한 색.
--   · TC · BC: 행이 다 차면 대기열(최대 8)에 쌓는다. 넘치면 priority가 가장 낮은 것부터(같으면 오래된 것부터) 버린다.
--   · TR(S10 - 사용자 결정 2026-09-20, PRD 20.93 · 보완): 대기열이 없다. 새 알림이 맨 위에 쌓이고 줄 수(capacity)가 차면 가장 오래된 줄이 밀려난다.
--     줄 수 = 칩 스택 아래 끝 ~ 그 아래 첫 HUD 위 끝 사이에 들어가는 줄 수(최대 3) - FeedLayout이 잰다. 창 크기 · 칩 · 투표 패널이 바뀌면 다시 재고, 줄어들면 오래된 줄부터 밀어낸다.
--     0줄이면 상단 가운데 띠(1줄)로 옮겨 가고, 태초 배너(TC)가 떠 있으면 그 바로 아래에 붙는다.
--   · TC: 화면 높이가 낮아 슬롯(y 64 + 높이 40)이 중앙 금지 구역 위 경계(화면 높이 25%)를 넘으면 행 높이를 줄이고 글씨를 한 단계 낮춘다(centerSafe).
--   · 같은 groupKey가 1초 안에 오면 새 행을 세우지 않고 한 행으로 묶는다("… ×3" - moreFormat이 있으면 "… 외 2" 꼴) - 20.73 [5-3](드랍 피드)의 요구.
--   · fadeSeconds가 있으면 seconds가 지난 뒤 그 시간 동안 흐려지며 사라진다(없으면 바로 사라진다). rainbow = true면 테두리가 무지개로 흐른다(태초 배너).
--   · S12b: richParts 항목에 bold = true(굵게) · onActivate = function(handle)(그 부분을 누르면 부른다 - 이름 클릭 메뉴 · 아이템 옵션 툴팁)를 줄 수 있다. handle = { toggleTooltip(desc) - ItemTooltip을 그 행 옆에 토글 }.
--     행을 **누르고 있는 동안**(또는 툴팁이 열려 있는 동안) 사라지는 타이머가 멈춘다 - 손을 떼거나 툴팁을 닫으면 seconds를 다시 센다. 툴팁이 열린 행이 밀려나면 툴팁도 닫힌다.
-- 자리 · 크기는 ScreenMap의 슬롯(TC.toastLane · TR.dropFeed · BC.pickupPopup)에서 온다. 모양 = panel + rim + 모서리 10.
-- 기존 토스트 5종(SaveNotice · LevelUp · ZoneBlocked · TreasureChest · ItemPickup)은 아직 이걸 안 쓴다(S17).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local FeedLayout = require(script.Parent.Parent.FeedLayout)
local ItemTooltip = require(script.Parent.ItemTooltip)
local ScreenMap = require(script.Parent.Parent.ScreenMap)
local Theme = require(script.Parent.Theme)

local Toast = {}

Toast.groupWindowSeconds = 1
Toast.queueMax = 8
local ROW_GAP = 3
local TEXT_PAD = 10

-- 줄 정의: 구역 · 슬롯(ScreenMap) · 최대 행 수 · 기본 시간(초). 행 높이는 슬롯 높이에서 나온다.
--   evict = 행이 다 차면 대기열이 아니라 가장 오래된 행을 밀어낸다 · newestOnTop = 새 행이 맨 위 · fit = 남은 자리로 줄 수(capacity)를 정한다(rows는 그 최대) · centerSafe = 낮은 화면에서 행이 중앙 금지 구역을 안 건드리게 줄인다.
local LANES = {
	TC = { zone = "TC", slot = "toastLane", rows = 1, seconds = 3, align = Enum.VerticalAlignment.Top, centerSafe = true },
	TR = { zone = "TR", slot = "dropFeed", rows = 3, seconds = 4, align = Enum.VerticalAlignment.Top, evict = true, newestOnTop = true, fit = true },
	BC = { zone = "BC", slot = "pickupPopup", rows = 1, seconds = 3, align = Enum.VerticalAlignment.Bottom },
}

local gui
local tooltip -- 알림 속 아이템 옵션 툴팁(ItemTooltip) - 처음 열 때 만든다. 한 번에 하나
local tooltipOwner -- 툴팁이 떠 있는 행
local lanes = {} -- 줄 이름 -> { frame, cfg, rowHeight, capacity, strip, active = {행...}, queue = {item...}, evicted }
local relayoutFeed -- 아래에서 정의(TC 줄의 행이 늘고 줄 때도 부른다 - 띠가 배너 아래로 가야 한다)
local rainbowGradients = {} -- 흐르는 무지개 테두리(태초 배너)의 UIGradient들 - 사라진 것은 돌 때 치운다

local function ensureGui()
	if gui then
		return
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "ToastGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8 -- 피드 · 토스트 대역(PRD [D-1]) - HUD(0 ~ 5)보다 위, station(10 ~)보다 아래
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	for laneName, cfg in pairs(LANES) do
		local slotDef = ScreenMap.slot(cfg.zone, cfg.slot)
		local frame = Instance.new("Frame")
		frame.Name = slotDef.instanceName
		frame.BackgroundTransparency = 1
		frame.Size = slotDef.size
		frame.Visible = false -- 행이 있을 때만 보인다(빈 줄이 겹침 검사에 잡히지 않게)
		ScreenMap.place(frame, cfg.zone, cfg.slot)
		frame.Parent = gui

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment = cfg.align
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, ROW_GAP)
		layout.Parent = frame

		lanes[laneName] = {
			frame = frame,
			cfg = cfg,
			rowHeight = (slotDef.size.Y.Offset - (cfg.rows - 1) * ROW_GAP) / cfg.rows,
			baseRowHeight = (slotDef.size.Y.Offset - (cfg.rows - 1) * ROW_GAP) / cfg.rows,
			capacity = cfg.rows,
			strip = false,
			active = {},
			queue = {},
			nextOrder = 0,
			evicted = 0,
		}
	end

	if lanes.TR and lanes.TR.cfg.fit then
		FeedLayout.bind(gui.Parent, gui, function()
			relayoutFeed()
		end)
		relayoutFeed()
	end

	RunService.RenderStepped:Connect(function(dt)
		for index = #rainbowGradients, 1, -1 do
			local gradient = rainbowGradients[index]
			if gradient.Parent then
				gradient.Rotation = (gradient.Rotation + dt * 40) % 360
			else
				table.remove(rainbowGradients, index)
			end
		end
	end)
end

local function escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- 부분의 색: color(Color3 - 등급색처럼 UIColors에 없는 값)가 있으면 그것, 없으면 colorName(UIColors), 둘 다 없으면 textPrimary.
local function partHex(part)
	local color = part.color
	if color then
		return ("#%02X%02X%02X"):format(math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	end
	return Theme.colorHex(part.colorName or "textPrimary")
end

local function buildText(item, count)
	local body
	if item.richParts then
		local parts = {}
		for _, part in ipairs(item.richParts) do
			local text = escape(part.text)
			if part.bold then
				text = "<b>" .. text .. "</b>"
			end
			if part.size then -- S12b: 조각마다 글씨 크기(이름 표시의 "Lv" 조각이 한 단계 작다)
				table.insert(parts, ('<font size="%d" color="%s">%s</font>'):format(part.size, partHex(part), text))
			else
				table.insert(parts, ('<font color="%s">%s</font>'):format(partHex(part), text))
			end
		end
		body = table.concat(parts)
	else
		body = escape(item.text or "")
	end
	if count > 1 then
		local suffix = item.moreFormat and item.moreFormat:format(count - 1) or (" ×%d"):format(count)
		body ..= ('<font color="%s">%s</font>'):format(Theme.colorHex("textSecondary"), escape(suffix))
	end
	return body
end

local showNext

local function removeRow(lane, row)
	if row.removed then
		return
	end
	row.removed = true
	if tooltipOwner == row then
		tooltipOwner = nil
		tooltip.hide()
	end
	local index = table.find(lane.active, row)
	if index then
		table.remove(lane.active, index)
	end
	row.frame:Destroy()
	showNext(lane)
	if #lane.active == 0 then
		lane.frame.Visible = false
	end
	if lane.cfg.zone == "TC" then
		relayoutFeed()
	end
end

-- seconds 뒤에 사라진다. fadeSeconds가 있으면 그 시간 동안 흐려진 뒤 지운다(묶임으로 다시 예약되면 이전 예약은 token으로 무효).
local function scheduleExpire(lane, row, seconds)
	row.token += 1
	local token = row.token
	task.delay(seconds, function()
		if row.token ~= token or row.removed then
			return
		end
		if row.holdCount > 0 or row.pinned then
			row.expireDeferred = true -- 누르고 있거나 툴팁이 열려 있다 - 놓는 순간 다시 센다
			return
		end
		local fade = row.item.fadeSeconds
		if not fade or fade <= 0 then
			removeRow(lane, row)
			return
		end
		row.fading = true
		local info = TweenInfo.new(fade, Enum.EasingStyle.Linear)
		row.fadeTweens = {
			TweenService:Create(row.frame, info, { BackgroundTransparency = 1 }),
			TweenService:Create(row.label, info, { TextTransparency = 1 }),
			TweenService:Create(row.stroke, info, { Transparency = 1 }),
		}
		for _, tween in ipairs(row.fadeTweens) do
			tween:Play()
		end
		task.delay(fade, function()
			if row.token == token then
				removeRow(lane, row)
			end
		end)
	end)
end

-- ═══ S12b: 누르고 있는 동안 · 툴팁이 열린 동안 타이머 정지 ═══

-- 흐려지던 중에 눌렀으면 되돌린다(진행 중인 사라짐을 취소하고 다시 또렷하게).
local function restoreVisual(row)
	if not row.fading then
		return
	end
	row.fading = false
	row.token += 1 -- 진행 중이던 사라짐 예약을 무효로
	for _, tween in ipairs(row.fadeTweens or {}) do
		tween:Cancel()
	end
	row.frame.BackgroundTransparency = Theme.colors.panelTransparency
	row.label.TextTransparency = 0
	row.stroke.Transparency = row.item.rainbow and 0 or Theme.colors.rimTransparency
	row.expireDeferred = true
end

-- 누르지도 않고 툴팁도 없으면, 미뤄 둔 사라짐을 seconds부터 다시 센다.
local function releaseIfIdle(lane, row)
	if row.removed or row.holdCount > 0 or row.pinned or not row.expireDeferred then
		return
	end
	row.expireDeferred = false
	scheduleExpire(lane, row, row.item.seconds)
end

local function setPressing(lane, row, pressing)
	local wanted = pressing and 1 or 0
	if row.holdCount == wanted then
		return
	end
	row.holdCount = wanted
	if pressing then
		restoreVisual(row)
	else
		releaseIfIdle(lane, row)
	end
end

local function closeTooltip()
	local owner = tooltipOwner
	if not owner then
		return
	end
	tooltipOwner = nil
	tooltip.hide()
	owner.pinned = false
	releaseIfIdle(owner.lane, owner)
end

local function toggleTooltip(lane, row, desc)
	if tooltipOwner == row then
		closeTooltip()
		return
	end
	if not tooltip then
		tooltip = ItemTooltip.build({ parent = gui, name = "ToastItemTooltip" })
		tooltip.root.ZIndex = 10
	end
	closeTooltip()
	tooltip.set(desc)
	tooltip.root.Visible = true
	local position = row.frame.AbsolutePosition
	ItemTooltip.placeNear(tooltip.root, { min = position, max = position + row.frame.AbsoluteSize }, gui.AbsoluteSize)
	tooltipOwner = row
	row.pinned = true
	restoreVisual(row)
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- 히트 영역 하나에 "누르는 동안" 신호를 잇는다.
local function connectHitPressing(lane, row, hit)
	hit.InputBegan:Connect(function(input)
		if isPress(input) then
			setPressing(lane, row, true)
		end
	end)
	hit.InputEnded:Connect(function(input)
		if isPress(input) then
			setPressing(lane, row, false)
		end
	end)
end

-- 행의 글 조각 중 onActivate가 있는 것마다 그 글자 폭만큼 투명 버튼(히트 영역)을 깐다. 라벨은 가운데 정렬이라 조각 폭(TextService)의 합으로 시작 x를 구한다.
-- 폭은 근사값이다(굵게 조각은 GothamBold로 잰다) - 양쪽 2px만 넓힌다. 모바일은 폭 44 이상.
local function layoutHits(lane, row)
	for _, hit in ipairs(row.hits) do
		hit:Destroy()
	end
	row.hits = {}
	local parts = row.item.richParts
	if not parts then
		return
	end
	local size, font = row.label.TextSize, row.label.Font
	local big = Vector2.new(2000, 100)
	local widths, total = {}, 0
	for index, part in ipairs(parts) do
		widths[index] = TextService:GetTextSize(part.text, part.size or size, part.bold and Enum.Font.GothamBold or font, big).X
		total += widths[index]
	end
	if row.count > 1 then
		local suffix = row.item.moreFormat and row.item.moreFormat:format(row.count - 1) or (" ×%d"):format(row.count)
		total += TextService:GetTextSize(suffix, size, font, big).X
	end
	local rowWidth = lane.frame.Size.X.Offset
	local x = TEXT_PAD + math.max(0, (rowWidth - TEXT_PAD * 2 - total) / 2)
	row.handle = {
		toggleTooltip = function(desc)
			toggleTooltip(lane, row, desc)
		end,
	}
	for index, part in ipairs(parts) do
		if part.onActivate then
			local width = math.max(widths[index] + 4, Theme.isMobile and Theme.touchMin or 0)
			local hit = Instance.new("TextButton")
			hit.Name = "Hit" .. index
			hit.AutoButtonColor = false
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.AnchorPoint = Vector2.new(0.5, 0)
			hit.Position = UDim2.new(0, math.clamp(x + widths[index] / 2, width / 2, rowWidth - width / 2), 0, 0)
			hit.Size = UDim2.new(0, width, 1, 0)
			hit.ZIndex = 2
			hit.Parent = row.frame
			hit.Activated:Connect(function()
				part.onActivate(row.handle)
			end)
			table.insert(row.hits, hit)
		end
		x += widths[index]
	end
end

-- 행을 누르는 동안(마우스 · 터치) 사라지는 타이머를 멈춘다. 행 전체 + 히트 영역 어디서 누르든 같다.
local function connectPressing(lane, row)
	connectHitPressing(lane, row, row.frame)
	row.frame.MouseLeave:Connect(function()
		setPressing(lane, row, false)
	end)
	for _, hit in ipairs(row.hits) do
		connectHitPressing(lane, row, hit)
	end
end

-- 중앙 금지 구역 위 경계(화면 높이 25%)가 슬롯 아래 끝(y + 높이)보다 위로 올라오면 행 높이를 위 경계 1px 위까지로 줄인다(nil = 줄일 필요 없음). 순수 함수 - screenHeight만 본다.
function Toast.centerSafeRowHeight(screenHeight)
	local slotDef = ScreenMap.slot("TC", "toastLane")
	local top = slotDef.position.Y.Offset
	local zoneTop = math.floor(screenHeight * ScreenMap.centerFraction.top)
	if zoneTop >= top + slotDef.size.Y.Offset then
		return nil
	end
	return math.max(zoneTop - 1 - top, Theme.text.caption + 4)
end

local function showRow(lane, item)
	lane.nextOrder += 1
	local compactHeight = lane.cfg.centerSafe and Toast.centerSafeRowHeight(gui.AbsoluteSize.Y) or nil
	lane.rowHeight = compactHeight or lane.baseRowHeight
	if lane.cfg.centerSafe then
		local slotDef = ScreenMap.slot(lane.cfg.zone, lane.cfg.slot)
		lane.frame.Size = UDim2.new(slotDef.size.X.Scale, slotDef.size.X.Offset, 0, lane.rowHeight)
	end
	local frame = Instance.new("Frame")
	frame.Name = "ToastRow"
	frame.LayoutOrder = lane.cfg.newestOnTop and -lane.nextOrder or lane.nextOrder
	frame.Size = UDim2.new(1, 0, 0, lane.rowHeight)
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BackgroundTransparency = Theme.colors.panelTransparency
	frame.Parent = lane.frame
	Theme.corner(frame, Theme.corner.button)
	local stroke = Theme.stroke(frame)
	if item.rainbow then
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0
		stroke.Thickness = 2
		local gradient = Instance.new("UIGradient")
		gradient.Color = ItemVisualData.rainbowSequence
		gradient.Parent = stroke
		table.insert(rainbowGradients, gradient)
	end

	local label = Theme.label(frame, "", "caption", item.colorName or "textPrimary")
	label.Name = "Text"
	label.RichText = true
	label.Position = UDim2.new(0, TEXT_PAD, 0, 0)
	label.Size = UDim2.new(1, -TEXT_PAD * 2, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	if compactHeight then
		label.TextSize = Theme.text.caption -- 한 단계 낮춤: 모바일 확대(x1.15)를 뺀 기본 caption(12 - 12 미만 금지선)
	end
	local count = item.count or 1 -- 대기 중에 합쳐진 것은 그 횟수로 시작한다
	label.Text = buildText(item, count)

	local row = {
		frame = frame, label = label, stroke = stroke, item = item, count = count, lastAt = os.clock(), token = 0, removed = false,
		lane = lane, holdCount = 0, pinned = false, expireDeferred = false, fading = false, hits = {},
	}
	if item.richParts then
		for _, part in ipairs(item.richParts) do
			if part.onActivate then
				frame.Active = true -- 행 위를 눌러도 뒤(기본공격)로 새지 않는다
				layoutHits(lane, row)
				connectPressing(lane, row)
				break
			end
		end
	end
	table.insert(lane.active, row)
	lane.frame.Visible = true
	scheduleExpire(lane, row, item.seconds)
	if lane.cfg.zone == "TC" then
		relayoutFeed()
	end
end

showNext = function(lane)
	while #lane.queue > 0 and #lane.active < lane.capacity do
		showRow(lane, table.remove(lane.queue, 1))
	end
end

-- 같은 groupKey의 행(보이는 것 → 대기 중인 것 순)이 1초 안에 있으면 그 행에 합친다. 합쳤으면 true.
local function tryMerge(lane, item)
	local now = os.clock()
	for _, row in ipairs(lane.active) do
		if row.item.groupKey == item.groupKey and now - row.lastAt <= Toast.groupWindowSeconds then
			row.count += 1
			row.lastAt = now
			row.label.Text = buildText(row.item, row.count)
			if #row.hits > 0 then
				layoutHits(lane, row)
				for _, hit in ipairs(row.hits) do
					connectHitPressing(lane, row, hit)
				end
			end
			scheduleExpire(lane, row, row.item.seconds)
			return true
		end
	end
	for _, queued in ipairs(lane.queue) do
		if queued.groupKey == item.groupKey and now - queued.lastAt <= Toast.groupWindowSeconds then
			queued.count = (queued.count or 1) + 1
			queued.lastAt = now
			return true
		end
	end
	return false
end

-- 줄 수(capacity)를 바꾼다. 보이는 행이 새 줄 수를 넘으면 가장 오래된 것부터 밀어낸다(active는 들어온 순서).
local function applyCapacity(lane, rows)
	lane.capacity = rows
	while #lane.active > rows do
		removeRow(lane, lane.active[1])
		lane.evicted += 1
	end
end

-- 태초 배너(TC 줄)가 떠 있으면 그 아래 끝 y(없으면 nil). 행 높이는 showRow가 정한 값이다(낮은 화면에서는 줄어든다).
local function bannerBottom()
	local banner = lanes.TC
	if not banner or #banner.active == 0 then
		return nil
	end
	return ScreenMap.slot(banner.cfg.zone, banner.cfg.slot).position.Y.Offset + banner.rowHeight
end

relayoutFeed = function()
	local lane = lanes.TR
	if not gui or not lane or not lane.cfg.fit then
		return
	end
	local placement = FeedLayout.measure(gui.Parent, gui.AbsoluteSize, {
		rowHeight = lane.rowHeight,
		gap = ROW_GAP,
		maxRows = lane.cfg.rows,
		bannerBottom = bannerBottom(),
	})
	applyCapacity(lane, placement.rows)
	lane.strip = placement.strip
	local slotDef = ScreenMap.slot(lane.cfg.zone, lane.cfg.slot)
	lane.frame.AnchorPoint = placement.anchor
	lane.frame.Position = placement.position
	lane.frame.Size = UDim2.new(0, slotDef.size.X.Offset, 0, placement.rows * lane.rowHeight + (placement.rows - 1) * ROW_GAP)
end

-- 대기열이 넘치면 priority가 가장 낮은 것(같으면 가장 오래된 것)을 버린다.
local function dropLowest(lane)
	local lowestIndex, lowestPriority = 1, math.huge
	for index, queued in ipairs(lane.queue) do
		if queued.priority < lowestPriority then
			lowestIndex, lowestPriority = index, queued.priority
		end
	end
	table.remove(lane.queue, lowestIndex)
end

-- item = { text, colorName, seconds, priority, groupKey, richParts, fadeSeconds, moreFormat, rainbow }.
-- 반환: "shown" · "merged" · "queued" · "evicted"(TR: 보이긴 했고 가장 오래된 줄이 밀려났다) (전시장 · 검사용).
function Toast.push(laneName, item)
	ensureGui()
	local lane = lanes[laneName]
	assert(lane, "Toast.push: 알 수 없는 줄 - " .. tostring(laneName) .. " (TC · TR · BC)")
	local entry = {
		text = item.text,
		richParts = item.richParts,
		colorName = item.colorName,
		seconds = item.seconds or lane.cfg.seconds,
		priority = item.priority or 0,
		groupKey = item.groupKey,
		fadeSeconds = item.fadeSeconds,
		moreFormat = item.moreFormat,
		rainbow = item.rainbow,
		lastAt = os.clock(),
	}
	if entry.groupKey and tryMerge(lane, entry) then
		return "merged"
	end
	if #lane.active < lane.capacity then
		showRow(lane, entry)
		return "shown"
	end
	if lane.cfg.evict then
		removeRow(lane, lane.active[1]) -- active는 들어온 순서라 첫 행이 가장 오래된 것이다
		lane.evicted += 1
		showRow(lane, entry)
		return "evicted"
	end
	table.insert(lane.queue, entry)
	if #lane.queue > Toast.queueMax then
		dropLowest(lane)
	end
	return "queued"
end

-- 줄의 지금 상태({ rows = 보이는 행 수, queued = 대기 수, maxRows, capacity = 지금 들어가는 줄 수, strip = 상단 띠로 옮겨 갔는가, evicted = 밀려난 누계 }). 아직 줄을 만들기 전이면 0.
function Toast.debugState(laneName)
	local lane = lanes[laneName]
	if not lane then
		return { rows = 0, queued = 0, maxRows = LANES[laneName] and LANES[laneName].rows or 0, capacity = 0, strip = false, evicted = 0 }
	end
	return { rows = #lane.active, queued = #lane.queue, maxRows = lane.cfg.rows, capacity = lane.capacity, strip = lane.strip, evicted = lane.evicted }
end

-- 검사용: 줄 수를 강제로 바꾼다(줄어들면 오래된 행이 밀려난다 - 실제 재배치와 같은 함수). Toast.debugRelayout()이나 Toast.clear()로 실제 값으로 되돌린다.
function Toast.debugSetCapacity(laneName, rows)
	applyCapacity(lanes[laneName], rows)
end

function Toast.debugRelayout()
	relayoutFeed()
end

-- 줄의 보이는 행 글자(위에서 아래 순서 · 태그 없는 글) - 검사용. 행 Frame의 LayoutOrder 순서 = 화면 순서.
function Toast.debugTexts(laneName)
	local lane = lanes[laneName]
	local rows = {}
	if lane then
		for _, row in ipairs(lane.active) do
			table.insert(rows, row)
		end
		table.sort(rows, function(a, b)
			return a.frame.LayoutOrder < b.frame.LayoutOrder
		end)
	end
	local texts = {}
	for _, row in ipairs(rows) do
		table.insert(texts, (row.label.Text:gsub("<[^>]+>", "")))
	end
	return texts
end

-- 검사용: 줄의 보이는 행을 화면 순서로 돌려준다. 각 항목 = { activate(partIndex), press(), release(), pinned(), held(), removed(), tooltipOpen(), hitCount() } - 사람 손 대신 그 행을 누르는 함수들.
function Toast.debugRows(laneName)
	local lane = lanes[laneName]
	local rows = {}
	if lane then
		for _, row in ipairs(lane.active) do
			table.insert(rows, row)
		end
		table.sort(rows, function(a, b)
			return a.frame.LayoutOrder < b.frame.LayoutOrder
		end)
	end
	local list = {}
	for _, row in ipairs(rows) do
		table.insert(list, {
			parts = row.item.richParts,
			activate = function(partIndex)
				row.item.richParts[partIndex].onActivate(row.handle)
			end,
			press = function()
				setPressing(lane, row, true)
			end,
			release = function()
				setPressing(lane, row, false)
			end,
			pinned = function()
				return row.pinned
			end,
			held = function()
				return row.holdCount > 0
			end,
			removed = function()
				return row.removed
			end,
			tooltipOpen = function()
				return tooltipOwner == row and tooltip ~= nil and tooltip.root.Visible
			end,
			hitCount = function()
				return #row.hits
			end,
		})
	end
	return list
end

-- 보이는 행 · 대기열을 전부 지운다(전시장 정리용).
function Toast.clear()
	for _, lane in pairs(lanes) do
		lane.queue = {}
		lane.evicted = 0
		for _, row in ipairs(table.clone(lane.active)) do
			removeRow(lane, row)
		end
	end
	relayoutFeed() -- 검사가 강제로 바꾼 줄 수를 실제 값으로 되돌린다
end

return Toast
