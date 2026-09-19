-- 토스트(30-0 S06, PRD 20.81 [D-3]). 줄(lane) 3개: TC(시스템 · 1행 · 3초) · TR(드랍 피드 · 3행 · 5초 · 대기열 8) · BC(획득 팝업 · 1행 · 3초).
-- 새 알림은 직접 Frame을 세우지 않고 Toast.push(lane, { text, colorName, seconds, priority, groupKey, richParts })로만 낸다.
--   · richParts = { { text, colorName }, ... } - 한 행 안에서 부분마다 색을 다르게(RichText). 없으면 text 한 색.
--   · 행이 다 차면 대기열(최대 8)에 쌓는다. 넘치면 priority가 가장 낮은 것부터(같으면 오래된 것부터) 버린다.
--   · 같은 groupKey가 1초 안에 오면 새 행을 세우지 않고 한 행으로 묶는다("… ×3") - 20.73 [5-3](드랍 피드)의 요구.
-- 자리 · 크기는 ScreenMap의 슬롯(TC.toastLane · TR.dropFeed · BC.pickupPopup)에서 온다. 모양 = panel + rim + 모서리 10.
-- 기존 토스트 5종(SaveNotice · LevelUp · ZoneBlocked · TreasureChest · ItemPickup)은 아직 이걸 안 쓴다(S17).

local Players = game:GetService("Players")

local ScreenMap = require(script.Parent.Parent.ScreenMap)
local Theme = require(script.Parent.Theme)

local Toast = {}

Toast.groupWindowSeconds = 1
Toast.queueMax = 8
local ROW_GAP = 3
local TEXT_PAD = 10

-- 줄 정의: 구역 · 슬롯(ScreenMap) · 최대 행 수 · 기본 시간(초). 행 높이는 슬롯 높이에서 나온다.
local LANES = {
	TC = { zone = "TC", slot = "toastLane", rows = 1, seconds = 3, align = Enum.VerticalAlignment.Top },
	TR = { zone = "TR", slot = "dropFeed", rows = 3, seconds = 5, align = Enum.VerticalAlignment.Top },
	BC = { zone = "BC", slot = "pickupPopup", rows = 1, seconds = 3, align = Enum.VerticalAlignment.Bottom },
}

local gui
local lanes = {} -- 줄 이름 -> { frame, cfg, rowHeight, active = {행...}, queue = {item...} }

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
			active = {},
			queue = {},
			nextOrder = 0,
		}
	end
end

local function escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function buildText(item, count)
	local body
	if item.richParts then
		local parts = {}
		for _, part in ipairs(item.richParts) do
			table.insert(parts, ('<font color="%s">%s</font>'):format(Theme.colorHex(part.colorName or "textPrimary"), escape(part.text)))
		end
		body = table.concat(parts)
	else
		body = escape(item.text or "")
	end
	if count > 1 then
		body ..= ('<font color="%s"> ×%d</font>'):format(Theme.colorHex("textSecondary"), count)
	end
	return body
end

local showNext

local function removeRow(lane, row)
	if row.removed then
		return
	end
	row.removed = true
	local index = table.find(lane.active, row)
	if index then
		table.remove(lane.active, index)
	end
	row.frame:Destroy()
	showNext(lane)
	if #lane.active == 0 then
		lane.frame.Visible = false
	end
end

local function scheduleExpire(lane, row, seconds)
	row.token += 1
	local token = row.token
	task.delay(seconds, function()
		if row.token == token then
			removeRow(lane, row)
		end
	end)
end

local function showRow(lane, item)
	lane.nextOrder += 1
	local frame = Instance.new("Frame")
	frame.Name = "ToastRow"
	frame.LayoutOrder = lane.nextOrder
	frame.Size = UDim2.new(1, 0, 0, lane.rowHeight)
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BackgroundTransparency = Theme.colors.panelTransparency
	frame.Parent = lane.frame
	Theme.corner(frame, Theme.corner.button)
	Theme.stroke(frame)

	local label = Theme.label(frame, "", "caption", item.colorName or "textPrimary")
	label.Name = "Text"
	label.RichText = true
	label.Position = UDim2.new(0, TEXT_PAD, 0, 0)
	label.Size = UDim2.new(1, -TEXT_PAD * 2, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	local count = item.count or 1 -- 대기 중에 합쳐진 것은 그 횟수로 시작한다
	label.Text = buildText(item, count)

	local row = { frame = frame, label = label, item = item, count = count, lastAt = os.clock(), token = 0, removed = false }
	table.insert(lane.active, row)
	lane.frame.Visible = true
	scheduleExpire(lane, row, item.seconds)
end

showNext = function(lane)
	while #lane.queue > 0 and #lane.active < lane.cfg.rows do
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

-- item = { text, colorName, seconds, priority, groupKey, richParts }. 반환: "shown" · "merged" · "queued" (전시장 · 검사용).
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
		lastAt = os.clock(),
	}
	if entry.groupKey and tryMerge(lane, entry) then
		return "merged"
	end
	if #lane.active < lane.cfg.rows then
		showRow(lane, entry)
		return "shown"
	end
	table.insert(lane.queue, entry)
	if #lane.queue > Toast.queueMax then
		dropLowest(lane)
	end
	return "queued"
end

-- 줄의 지금 상태({ rows = 보이는 행 수, queued = 대기 수, maxRows }). 아직 줄을 만들기 전이면 0.
function Toast.debugState(laneName)
	local lane = lanes[laneName]
	if not lane then
		return { rows = 0, queued = 0, maxRows = LANES[laneName] and LANES[laneName].rows or 0 }
	end
	return { rows = #lane.active, queued = #lane.queue, maxRows = lane.cfg.rows }
end

-- 보이는 행 · 대기열을 전부 지운다(전시장 정리용).
function Toast.clear()
	for _, lane in pairs(lanes) do
		lane.queue = {}
		for _, row in ipairs(table.clone(lane.active)) do
			removeRow(lane, row)
		end
	end
end

return Toast
