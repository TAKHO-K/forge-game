-- QUEUE-ALL1 P5 도감 v2 창(K · 메뉴바 칸 - PanelRegistry "codex"). 서버 CodexService가 판정 · 지급 · 화면 표(CodexUpdate)를 준다 - 클라는 계산하지 않는다.
--   탭 = 장비(빙고판 등급 × 세트) · 펫 · 탐험 · 몬스터 · 보스 · 직업 · 점수판 · 칭호. 받을 칸 = 반짝(밝은 칸) + 탭 빨간 점 + [모두 받기]. 줄 완성 = 줄 머리 금색 + 칭호 카드(서버 알림).
--   요청 = CodexRequest("view" | "claim" 칸 id · "all" · "board:<점수>" | "title" id).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodexData = require(ReplicatedStorage.Shared.data.CodexData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.Parent.UIManager)

local CodexPanel = {}
CodexPanel.id = "codex"

local PANEL_SIZE = Vector2.new(640, 470)
local PAD = 10
local GOLD = Color3.fromRGB(255, 214, 90)
local INKGOLD = Color3.fromRGB(30, 24, 10)

local requestRemote = ReplicatedStorage:WaitForChild("CodexRequest")
local updateRemote = ReplicatedStorage:WaitForChild("CodexUpdate")

local built, view
local tab = "armor"

local function gradeColor(grade)
	local v = ItemVisualData.gradeVisuals[grade]
	return v and v.color or Color3.new(1, 1, 1)
end

local function send(action, arg)
	requestRemote:FireServer(action, arg)
end

local function tabClaimable(tabId)
	if not view then
		return false
	end
	if tabId == "board" then
		for _, b in ipairs(view.board) do
			if b.done and not b.claimed then
				return true
			end
		end
		return false
	end
	for _, c in pairs(view.cells) do
		if c.tab == tabId and c.done and not c.claimed then
			return true
		end
	end
	return false
end

local function build()
	local panel = Panel.create({ id = CodexPanel.id, kind = "window", title = CodexData.text.title, size = PANEL_SIZE,
		onOpen = function()
			task.defer(function()
				CodexPanel.render()
				send("view")
			end)
		end })
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, 86)
	top.Parent = panel.content
	local score = Instance.new("TextLabel")
	score.Name = "Score"
	score.BackgroundTransparency = 1
	score.Position = UDim2.fromOffset(PAD, 4)
	score.Size = UDim2.new(1, -220, 0, 30)
	score.Font = Theme.font
	score.TextSize = Theme.textSize("body")
	score.TextColor3 = GOLD
	score.TextXAlignment = Enum.TextXAlignment.Left
	score.Parent = top
	local all = Button.build({ parent = top, kind = "primary", text = CodexData.text.claimAll, width = 120, height = 32, position = UDim2.new(1, -PAD, 0, 2), anchorPoint = Vector2.new(1, 0), onActivated = function()
		send("claim", "all")
	end })
	all.root.Name = "ClaimAll"
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(PAD, 42)
	tabs.Size = UDim2.new(1, -PAD * 2, 0, 38)
	tabs.Parent = top
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 4)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabs
	local tabButtons = {}
	for i, t in ipairs(CodexData.tabs) do
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. t.id
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / #CodexData.tabs, -4, 1, 0)
		b.Font = Theme.font
		b.TextSize = Theme.textSize("caption")
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = t.label
		b.AutoButtonColor = true
		b.Parent = tabs
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(1, 0)
		dot.Position = UDim2.new(1, -3, 0, 3)
		dot.Size = UDim2.fromOffset(9, 9)
		dot.BackgroundColor3 = Color3.fromRGB(235, 60, 60)
		dot.Visible = false
		dot.Parent = b
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		b.Activated:Connect(function()
			tab = t.id
			CodexPanel.render()
		end)
		tabButtons[t.id] = b
	end
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, 88)
	scroll.Size = UDim2.new(1, 0, 1, -88)
	scroll.ScrollBarThickness = 5
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel.content
	built = { panel = panel, scroll = scroll, score = score, tabButtons = tabButtons }
end

local function clearBody()
	for _, child in ipairs(built.scroll:GetChildren()) do
		child:Destroy()
	end
end

local function label(parent, text, size, color, pos, sz, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Theme.font
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Position = pos
	l.Size = sz
	l.Parent = parent
	return l
end

-- 장비 빙고판: 행 = 등급 · 열 = 세트. 칸 = 3부위(갑옷 · 장갑 · 신발) 진행 · 칸 누르면 그 칸 받을 것 전부 받기
local PART_SHORT = { armor = "갑", gloves = "장", shoes = "신" }
local function renderArmor()
	local zones = {}
	for _, z in ipairs(WorldMapData.zones) do
		if CodexData.zoneShort[z.key] then
			table.insert(zones, z.key)
		end
	end
	local LABEL_W, CELL_W, CELL_H, GAP = 64, 88, 58, 4
	local scroll = built.scroll
	for col, zk in ipairs(zones) do
		local line = view.lines["armorZone:" .. zk]
		local x = PAD + LABEL_W + (col - 1) * (CELL_W + GAP)
		local h = label(scroll, CodexData.zoneShort[zk], Theme.textSize("caption"), line and line.done and GOLD or Color3.fromRGB(210, 210, 225), UDim2.fromOffset(x, 0), UDim2.fromOffset(CELL_W, 20), Enum.TextXAlignment.Center)
		h.Name = "ColHead_" .. zk
		if view.trans and view.trans[zk] then
			local t = label(scroll, CodexData.text.transcendBorder, 11, GOLD, UDim2.fromOffset(x, 18), UDim2.fromOffset(CELL_W, 14), Enum.TextXAlignment.Center)
			t.Name = "Trans_" .. zk
		end
	end
	local y0 = 34
	for row, g in ipairs(CodexData.armor.grades) do
		local y = y0 + (row - 1) * (CELL_H + GAP)
		local line = view.lines["armorGrade:" .. g]
		label(scroll, ArmorData.grades[g].displayName, Theme.textSize("caption"), line and line.done and GOLD or gradeColor(g), UDim2.fromOffset(PAD, y), UDim2.fromOffset(LABEL_W - 4, CELL_H))
		for col, zk in ipairs(zones) do
			local x = PAD + LABEL_W + (col - 1) * (CELL_W + GAP)
			local cell = Instance.new("TextButton")
			cell.Name = ("Cell_%s_%s"):format(zk, g)
			cell.AutoButtonColor = false
			cell.Text = ""
			cell.Position = UDim2.fromOffset(x, y)
			cell.Size = UDim2.fromOffset(CELL_W, CELL_H)
			cell.Parent = scroll
			Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 8)
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = cell
			local doneParts, claimable, lines = 0, {}, {}
			for _, p in ipairs({ "armor", "gloves", "shoes" }) do
				local id = ("armor:%s:%s:%s"):format(zk, g, p)
				local c = view.cells[id]
				if c then
					if c.done then
						doneParts += 1
					end
					if c.done and not c.claimed then
						table.insert(claimable, id)
					end
					table.insert(lines, ("%s %d/%d"):format(PART_SHORT[p], c.v, c.need))
				end
			end
			local trans = view.trans and view.trans[zk]
			cell.BackgroundColor3 = #claimable > 0 and Color3.fromRGB(96, 84, 40) or (doneParts == 3 and Color3.fromRGB(52, 48, 72) or Color3.fromRGB(34, 32, 48))
			stroke.Color = trans and GOLD or (doneParts == 3 and GOLD or gradeColor(g))
			stroke.Thickness = trans and 3 or (doneParts == 3 and 2.5 or 1.2)
			stroke.Transparency = doneParts > 0 and 0 or 0.5
			if trans then
				cell.BackgroundColor3 = #claimable > 0 and Color3.fromRGB(96, 84, 40) or INKGOLD
			end
			label(cell, table.concat(lines, "\n"), 12, Color3.new(1, 1, 1), UDim2.fromOffset(6, 3), UDim2.new(1, -12, 1, -6))
			if #claimable > 0 then
				local star = label(cell, "받기", 11, GOLD, UDim2.new(1, -34, 0, 2), UDim2.fromOffset(30, 14), Enum.TextXAlignment.Right)
				star.Name = "ClaimMark"
				cell.Activated:Connect(function()
					for _, id in ipairs(claimable) do
						send("claim", id)
					end
				end)
			end
		end
	end
	-- 보너스 줄(점수 없음): 태초 = 세트당 1칸
	local y = y0 + #CodexData.armor.grades * (CELL_H + GAP) + 4
	label(built.scroll, "태초(보너스)", Theme.textSize("caption"), gradeColor("primordial"), UDim2.fromOffset(PAD, y), UDim2.fromOffset(LABEL_W - 4, 36))
	for col, zk in ipairs(zones) do
		local id = "prim:" .. zk
		local c = view.cells[id]
		local x = PAD + LABEL_W + (col - 1) * (CELL_W + GAP)
		local b = Instance.new("TextButton")
		b.Name = "Prim_" .. zk
		b.Position = UDim2.fromOffset(x, y)
		b.Size = UDim2.fromOffset(CELL_W, 36)
		b.Font = Theme.font
		b.TextSize = 12
		b.TextColor3 = Color3.new(1, 1, 1)
		local claim = c and c.done and not c.claimed
		b.Text = c and (c.claimed and "받음" or (claim and "받기" or (c.done and "완료" or "0/1"))) or "-"
		b.BackgroundColor3 = claim and Color3.fromRGB(96, 84, 40) or Color3.fromRGB(34, 32, 48)
		b.Parent = built.scroll
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		if claim then
			b.Activated:Connect(function()
				send("claim", id)
			end)
		end
	end
	built.scroll.CanvasSize = UDim2.fromOffset(PAD + LABEL_W + #zones * (CELL_W + GAP), y + 48)
end

local ROW_H = 36
local function listRow(y, text, v, need, done, claimed, onClaim, name)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = (done and not claimed) and Color3.fromRGB(80, 70, 36) or Color3.fromRGB(34, 32, 48)
	f.BackgroundTransparency = 0.2
	f.Position = UDim2.fromOffset(PAD, y)
	f.Size = UDim2.new(1, -PAD * 2 - 6, 0, ROW_H - 4)
	f.Parent = built.scroll
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
	label(f, text, 13, Color3.new(1, 1, 1), UDim2.fromOffset(8, 0), UDim2.new(1, -200, 1, 0))
	label(f, ("%s / %s"):format(tostring(v), tostring(need)), 13, done and GOLD or Color3.fromRGB(190, 190, 205), UDim2.new(1, -190, 0, 0), UDim2.fromOffset(80, ROW_H - 4), Enum.TextXAlignment.Right)
	local b = Button.build({ parent = f, kind = "primary", text = claimed and CodexData.text.claimed or (done and CodexData.text.claim or CodexData.text.locked), width = 96, height = ROW_H - 8,
		position = UDim2.new(1, -4, 0.5, 0), anchorPoint = Vector2.new(1, 0.5), onActivated = onClaim })
	b.setEnabled(done and not claimed)
	return y + ROW_H
end

local function renderList(tabId)
	local ids = {}
	for id, l in pairs(view.lines) do
		if l.tab == tabId then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local y = 0
	for _, lid in ipairs(ids) do
		local l = view.lines[lid]
		local head = label(built.scroll, ("%s「%s」"):format(l.done and "★ " or "", l.titleName or l.titleId), Theme.textSize("body"), l.done and GOLD or Color3.fromRGB(210, 210, 225),
			UDim2.fromOffset(PAD, y), UDim2.new(1, -PAD * 2, 0, 26))
		head.Name = "Line_" .. lid
		y += 28
		for _, cid in ipairs(l.cells) do
			local c = view.cells[cid]
			if c then
				y = listRow(y, c.label or cid, c.v, c.need, c.done, c.claimed, function()
					send("claim", cid)
				end, "Row_" .. cid)
			end
		end
		y += 6
	end
	built.scroll.CanvasSize = UDim2.fromOffset(0, y + 8)
end

local function renderBoard()
	local y = 0
	for _, b in ipairs(view.board) do
		local r = CodexData.boardReward(b.threshold)
		y = listRow(y, ("점수 %d · 골드 · 강화석 %d · 반짝 조각 %d"):format(b.threshold, r.enhanceStone, r.sparkleShard), math.min(view.score, b.threshold), b.threshold, b.done, b.claimed, function()
			send("claim", "board:" .. b.threshold)
		end, "Board_" .. b.threshold)
	end
	built.scroll.CanvasSize = UDim2.fromOffset(0, y + 8)
end

local function renderTitles()
	local y = 0
	label(built.scroll, CodexData.text.titleHint, 12, Color3.fromRGB(190, 190, 205), UDim2.fromOffset(PAD, y), UDim2.new(1, -PAD * 2, 0, 20))
	y += 24
	local rows = { { id = "", name = CodexData.text.titleNone } }
	for _, t in ipairs(view.titles) do
		table.insert(rows, t)
	end
	for _, t in ipairs(rows) do
		local selected = (view.selected or "") == t.id
		local f = Instance.new("Frame")
		f.Name = "Title_" .. (t.id ~= "" and t.id or "none")
		f.BackgroundColor3 = selected and Color3.fromRGB(70, 60, 110) or Color3.fromRGB(34, 32, 48)
		f.Position = UDim2.fromOffset(PAD, y)
		f.Size = UDim2.new(1, -PAD * 2 - 6, 0, ROW_H - 4)
		f.Parent = built.scroll
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
		label(f, t.name, 14, t.grade and gradeColor(t.grade) or Color3.new(1, 1, 1), UDim2.fromOffset(8, 0), UDim2.new(1, -120, 1, 0))
		local b = Button.build({ parent = f, kind = selected and "secondary" or "primary", text = selected and "사용 중" or "고르기", width = 96, height = ROW_H - 8,
			position = UDim2.new(1, -4, 0.5, 0), anchorPoint = Vector2.new(1, 0.5), onActivated = function()
				send("title", t.id)
			end })
		b.setEnabled(not selected)
		y += ROW_H
	end
	built.scroll.CanvasSize = UDim2.fromOffset(0, y + 8)
end

function CodexPanel.render()
	if not built or not UIManager.isOpen(CodexPanel.id) then
		return
	end
	clearBody()
	for id, b in pairs(built.tabButtons) do
		b.BackgroundColor3 = id == tab and Color3.fromRGB(96, 80, 160) or Color3.fromRGB(46, 42, 66)
		b.Dot.Visible = tabClaimable(id)
	end
	if not view then
		built.score.Text = "…"
		return
	end
	built.score.Text = CodexData.text.score:format(view.score, view.total)
	if tab == "armor" then
		renderArmor()
	elseif tab == "board" then
		renderBoard()
	elseif tab == "title" then
		renderTitles()
	else
		renderList(tab)
	end
end

function CodexPanel.open()
	if not built then
		build()
	end
	if not UIManager.isOpen(CodexPanel.id) and not UIManager.open(CodexPanel.id) then
		return false
	end
	CodexPanel.render()
	send("view")
	return true
end

function CodexPanel.init()
	if not built then
		build()
	end
	updateRemote.OnClientEvent:Connect(function(v)
		view = v
		CodexPanel.render()
	end)
	ReplicatedStorage:WaitForChild("CodexNotice").OnClientEvent:Connect(function(text)
		if type(text) == "string" then
			Toast.push("TC", { richParts = { { text = text, color = GOLD, bold = true } }, seconds = 4, fadeSeconds = 0.3 })
		end
	end)
end

-- 점검 · 스크린샷용
function CodexPanel.setTab(id)
	tab = id
	CodexPanel.render()
end

return CodexPanel
