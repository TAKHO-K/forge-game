-- QUEUE-ALL3 Q1 도감 칸 그리기(탭 본문 1개 = ScrollingFrame 1개 - 창 panels/Codex가 탭마다 처음 볼 때 만든다 · 표가 바뀌면 지금 탭만 다시 그린다).
--   칸 = 큰 그림 + 이름 한 줄 + 진행(3/4) + 완료 표시(✓) · 받을 수 있는 칸 = 금색 테두리 · 고른 칸 = 강조 테두리. 설명 글은 칸에 없다(오른쪽 상세 칸 - CodexV2/Detail).
--   장비 = 빙고판(행 = 등급 · 열 = 세트 구역 · 칸 = 부위 3개 작은 그림 3개) + 태초 보너스 줄 · 보상판 = 가로 진행 줄 1개 + 단계마다 보상 그림 + 수량.
--   칸 인스턴스에는 Attribute CodexCell(칸 id)을 달고 그림 인스턴스 이름은 Pic · Icon(보상) - panels/Codex.debugEmptyPictureCount가 이 이름으로 센다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CodexData = require(ReplicatedStorage.Shared.data.CodexData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Button = require(script.Parent.Parent.Parent.ui.kit.Button)
local ArtImage = require(script.Parent.Parent.Parent.ui.ArtImage)
local RewardIcons = require(script.Parent.Parent.Parent.ui.RewardIcons)
local Info = require(script.Parent.Info)
local CodexRules = require(ReplicatedStorage.Shared.CodexRules)

local Grid = {}

local PAD, GAP = 8, 6
local C_CLAIM = Color3.fromRGB(84, 72, 30)
local C_DONE = Color3.fromRGB(38, 52, 58)
local C_IDLE = Color3.fromRGB(30, 35, 45)

local function label(parent, text, sizeName, color, pos, size, align)
	local l = Theme.label(parent, text, sizeName, "textPrimary")
	l.TextColor3 = color or Theme.colors.textPrimary
	l.Position = pos
	l.Size = size
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	return l
end

-- 그림 한 장(이름 Pic). pic = Info.picture 결과
function Grid.picture(parent, key, pos, size, pic, name)
	local img = Instance.new("ImageLabel")
	img.Name = name or "Pic"
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = ArtImage.get(key) or ""
	img.Position = pos
	img.Size = size
	if pic and pic.silhouette then
		img.ImageColor3 = Color3.new(0, 0, 0)
	elseif pic and pic.dim then
		img.ImageColor3 = Color3.fromRGB(120, 124, 132)
		img.ImageTransparency = 0.65
	end
	img.Parent = parent
	return img
end

local function doneBadge(parent)
	local b = Instance.new("TextLabel")
	b.Name = "Done"
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, -3, 0, 3)
	b.Size = UDim2.fromOffset(20, 20)
	b.BackgroundColor3 = Theme.colors.success
	b.Font = Theme.font
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = "✓"
	b.ZIndex = 3
	b.Parent = parent
	Theme.corner(b, 10)
	return b
end

-- 칸 테두리(고른 칸 = 강조 · 받을 칸 = 금색 · 완료 = 초록 · 나머지 = 얇은 rim) - 고르기만 바뀔 때 창이 이것만 다시 부른다
function Grid.styleStroke(st, state, selected)
	if selected then
		st.Color, st.Transparency, st.Thickness = Theme.colors.ember, 0, 3
	elseif state == "claim" then
		st.Color, st.Transparency, st.Thickness = Theme.colors.gold, 0, 2
	elseif state == "done" then
		st.Color, st.Transparency, st.Thickness = Theme.colors.success, 0.2, 1.5
	else
		st.Color, st.Transparency, st.Thickness = Theme.colors.rim, Theme.colors.rimTransparency, 1
	end
end

-- 칸 틀(버튼): state = "claim" | "done" | "idle"
local function frameCell(S, parent, id, x, y, w, h, state, selected)
	local b = Instance.new("TextButton")
	b.Name = "Cell_" .. id
	b.AutoButtonColor = false
	b.Text = ""
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(w, h)
	b.BackgroundColor3 = state == "claim" and C_CLAIM or (state == "done" and C_DONE or C_IDLE)
	b:SetAttribute("CodexCell", id)
	b:SetAttribute("CodexState", state)
	b.Parent = parent
	Theme.corner(b, 10)
	Grid.styleStroke(Theme.stroke(b), state, selected)
	if state ~= "idle" then
		doneBadge(b)
	end
	return b
end

local function stateOf(cv)
	if cv and cv.done and not cv.claimed then
		return "claim"
	end
	return (cv and cv.done) and "done" or "idle"
end

local function isSelected(S, id)
	return S.selected and S.selected.id == id
end

-- 보통 칸(그림 + 이름 + 진행)
local function itemCell(S, parent, id, x, y)
	local view = S.view
	local m = Info.meta(id)
	local cv = view.cells[id]
	if not m or not cv then
		return
	end
	local w, h = S.cellW, S.cellH
	local b = frameCell(S, parent, id, x, y, w, h, stateOf(cv), isSelected(S, id))
	local pic = Info.picture(view, m)
	local ps = w - 12
	local holder = Instance.new("Frame")
	holder.Name = "PicHolder"
	holder.Position = UDim2.fromOffset(6, 6)
	holder.Size = UDim2.fromOffset(ps, ps)
	holder.BackgroundTransparency = pic.tint and (pic.dim and 0.75 or 0.2) or 1
	holder.BackgroundColor3 = pic.tint or Color3.new()
	holder.Parent = b
	Theme.corner(holder, 8)
	Grid.picture(holder, pic.key, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), pic)
	if pic.overlay then
		Grid.picture(holder, pic.overlay, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), nil, "Pic2")
	end
	if pic.silhouette then
		local q = label(holder, "?", "title", Color3.new(1, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		q.Name = "Unknown"
		q.TextStrokeTransparency = 0.2
	end
	local ts = Theme.textSize("caption")
	label(b, Info.shortName(view, m), "caption", Theme.colors.textPrimary, UDim2.fromOffset(4, ps + 8), UDim2.new(1, -8, 0, ts + 2)).Name = "Name"
	label(b, Text.get("codex.v2.frac", { v = tostring(cv.v), need = tostring(cv.need) }), "caption", cv.done and Theme.colors.gold or Theme.colors.textSecondary,
		UDim2.fromOffset(4, ps + 10 + ts), UDim2.new(1, -8, 0, ts + 2)).Name = "Progress"
	b.Activated:Connect(function()
		S.select({ kind = "cell", id = id })
	end)
end

-- 줄 머리(칭호 그림 + 「이름」 + 완성 ✓)
local function lineHead(S, parent, lineId, l, y)
	local f = Instance.new("Frame")
	f.Name = "Line_" .. lineId
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(PAD, y)
	f.Size = UDim2.new(1, -PAD * 2, 0, 26)
	f.Parent = parent
	local icon = ArtImage.label(f, "icons/reward/title", UDim2.fromOffset(24, 24), "")
	icon.Name = "Icon"
	local t = label(f, Text.get("codex.v2.lineTitle", { name = l.titleName and CodexRules.titleText(l.titleId, l.titleName) or l.titleId }), "body", l.done and Theme.colors.gold or Theme.colors.textPrimary,
		UDim2.fromOffset(30, 0), UDim2.new(1, -60, 1, 0), Enum.TextXAlignment.Left)
	t.Name = "Title"
	if l.done then
		local d = doneBadge(f)
		d.Position = UDim2.new(1, 0, 0, 3)
	end
	return y + 30
end

local function renderLines(S, scroll, tabId)
	local ids = {}
	for id, l in pairs(S.view.lines) do
		if l.tab == tabId then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local oa, ob = Info.lineOrder(a), Info.lineOrder(b)
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	local cols = math.max(1, math.floor((S.gridW - PAD * 2 + GAP) / (S.cellW + GAP)))
	local y = 4
	for _, lid in ipairs(ids) do
		local l = S.view.lines[lid]
		y = lineHead(S, scroll, lid, l, y)
		local n = 0
		for _, cid in ipairs(l.cells) do
			local col = n % cols
			local row = math.floor(n / cols)
			itemCell(S, scroll, cid, PAD + col * (S.cellW + GAP), y + row * (S.cellH + GAP))
			n += 1
		end
		y += math.ceil(n / cols) * (S.cellH + GAP) + 8
	end
	scroll.CanvasSize = UDim2.fromOffset(0, y + 8)
end

-- 장비 빙고판
local function renderArmor(S, scroll)
	local view = S.view
	local LABEL_W, CW, CH = 54, 108, 70
	local ts = Theme.textSize("caption")
	for col, z in ipairs(Info.zones) do
		local line = view.lines["armorZone:" .. z.key]
		local x = PAD + LABEL_W + (col - 1) * (CW + GAP)
		local done = line and line.done
		label(scroll, Text.name(CodexData.zoneShort[z.key]), "caption", done and Theme.colors.gold or Theme.colors.textPrimary, UDim2.fromOffset(x, 2), UDim2.fromOffset(CW, ts + 4)).Name = "ColHead_" .. z.key
		if view.trans and view.trans[z.key] then
			label(scroll, Text.name(CodexData.text.transcendBorder), "caption", Theme.colors.gold, UDim2.fromOffset(x, ts + 6), UDim2.fromOffset(CW, ts + 2)).Name = "Trans_" .. z.key
		end
	end
	local y0 = ts * 2 + 14
	for row, g in ipairs(CodexData.armor.grades) do
		local y = y0 + (row - 1) * (CH + GAP)
		local line = view.lines["armorGrade:" .. g]
		label(scroll, Text.name(ArmorData.grades[g].displayName), "caption", line and line.done and Theme.colors.gold or Info.gradeColor(g), UDim2.fromOffset(PAD, y), UDim2.fromOffset(LABEL_W - 4, CH), Enum.TextXAlignment.Left).Name = "RowHead_" .. g
		for col, z in ipairs(Info.zones) do
			local key = ("bingo:%s:%s"):format(z.key, g)
			local doneParts, claim, v, need = 0, false, 0, 0
			for _, p in ipairs(Info.parts) do
				local c = view.cells[("armor:%s:%s:%s"):format(z.key, g, p)]
				if c then
					doneParts += c.done and 1 or 0
					claim = claim or (c.done and not c.claimed)
					v += c.v
					need += c.need
				end
			end
			local state = claim and "claim" or (doneParts == 3 and "done" or "idle")
			local b = frameCell(S, scroll, key, PAD + LABEL_W + (col - 1) * (CW + GAP), y, CW, CH, state, isSelected(S, key))
			if doneParts < 3 and b:FindFirstChild("Done") then
				b.Done:Destroy() -- 빙고 칸 ✓ = 3부위 다
			end
			if view.trans and view.trans[z.key] then
				b.BackgroundColor3 = claim and C_CLAIM or Color3.fromRGB(46, 38, 14)
			end
			local ps = 30
			for i, p in ipairs(Info.parts) do
				local c = view.cells[("armor:%s:%s:%s"):format(z.key, g, p)]
				local img = Grid.picture(b, ("icons/armor/%s_%s_%s"):format(p, z.key, g), UDim2.fromOffset(6 + (i - 1) * (ps + 4), 6), UDim2.fromOffset(ps, ps), c and not c.done and { dim = c.v == 0 } or nil)
				img.Name = "Pic"
			end
			label(b, Text.get("codex.v2.frac", { v = tostring(doneParts), need = "3" }), "caption", doneParts == 3 and Theme.colors.gold or Theme.colors.textSecondary,
				UDim2.fromOffset(4, ps + 12), UDim2.new(1, -8, 0, ts + 4)).Name = "Progress"
			b.Activated:Connect(function()
				S.select({ kind = "bingo", id = key, zone = z.key, grade = g })
			end)
		end
	end
	-- 태초 보너스 줄(세트당 1칸)
	local y = y0 + #CodexData.armor.grades * (CH + GAP) + 4
	label(scroll, Text.name(ArmorData.grades.primordial.displayName), "caption", Info.gradeColor("primordial"), UDim2.fromOffset(PAD, y), UDim2.fromOffset(LABEL_W - 4, CH), Enum.TextXAlignment.Left).Name = "RowHead_prim"
	for col, z in ipairs(Info.zones) do
		local id = "prim:" .. z.key
		local cv = view.cells[id]
		local b = frameCell(S, scroll, id, PAD + LABEL_W + (col - 1) * (CW + GAP), y, CW, CH, stateOf(cv), isSelected(S, id))
		Grid.picture(b, ("icons/armor/armor_%s_primordial"):format(z.key), UDim2.fromOffset(6, 6), UDim2.fromOffset(38, 38), cv and not cv.done and { dim = true } or nil)
		label(b, Text.get("codex.v2.frac", { v = tostring(cv and cv.v or 0), need = "1" }), "caption", cv and cv.done and Theme.colors.gold or Theme.colors.textSecondary,
			UDim2.fromOffset(4, 48), UDim2.new(1, -8, 0, ts + 4)).Name = "Progress"
		b.Activated:Connect(function()
			S.select({ kind = "cell", id = id })
		end)
	end
	scroll.CanvasSize = UDim2.fromOffset(PAD * 2 + LABEL_W + #Info.zones * (CW + GAP), y + CH + 12)
end

-- 보상판: 가로 진행 줄 1개 + 단계마다 보상 그림 + 수량(글자 설명 없음). 받을 칸 = 빛 + 아주 약한 흔들림 · 받은 칸 = ✓ · 다음 칸 = 강조 테두리
local function renderBoard(S, scroll)
	local view = S.view
	local NODE_W = S.phone and 92 or 86
	local LINE_Y = 34
	local n = #view.board
	local nextIndex
	for i, b in ipairs(view.board) do
		if not b.done then
			nextIndex = i
			break
		end
	end
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(50, 56, 70)
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(PAD + NODE_W / 2, LINE_Y - 3)
	track.Size = UDim2.fromOffset((n - 1) * NODE_W, 6)
	track.Parent = scroll
	Theme.corner(track, 3)
	-- 채움 = 점수가 닿은 곳(두 단계 사이는 비율)
	local fillX, prevT = 0, 0
	for i, b in ipairs(view.board) do
		if view.score >= b.threshold then
			fillX = (i - 1) * NODE_W
			prevT = b.threshold
		else
			if i > 1 then
				fillX += NODE_W * math.clamp((view.score - prevT) / (b.threshold - prevT), 0, 1)
			end
			break
		end
	end
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.colors.gold
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromOffset(math.max(0, fillX), 6)
	fill.Parent = track
	Theme.corner(fill, 3)
	local ts = Theme.textSize("caption")
	local iconSize = S.phone and 24 or 22
	for i, b in ipairs(view.board) do
		local id = "board:" .. b.threshold
		local claim = b.done and not b.claimed
		local node = Instance.new("TextButton")
		node.Name = "Node_" .. b.threshold
		node.AutoButtonColor = false
		node.Text = ""
		node:SetAttribute("CodexCell", id)
		node.AnchorPoint = Vector2.new(0.5, 0)
		node.Position = UDim2.fromOffset(PAD + NODE_W / 2 + (i - 1) * NODE_W, 4)
		node.Size = UDim2.fromOffset(NODE_W - 8, LINE_Y + 18 + 3 * (iconSize + 4))
		node.BackgroundColor3 = claim and C_CLAIM or C_IDLE
		node.BackgroundTransparency = claim and 0.1 or 0.6
		node.Parent = scroll
		Theme.corner(node, 10)
		local st = Theme.stroke(node)
		if isSelected(S, id) then
			st.Color, st.Transparency, st.Thickness = Theme.colors.ember, 0, 3
		elseif claim then
			st.Color, st.Transparency, st.Thickness = Theme.colors.gold, 0, 2.5
			TweenService:Create(st, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.55 }):Play()
			node.Rotation = -1.5
			TweenService:Create(node, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 1.5 }):Play()
		elseif i == nextIndex then
			st.Color, st.Transparency, st.Thickness = Theme.colors.ember, 0.1, 2.5
		end
		local dot = Instance.new("TextLabel")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(0.5, 0, 0, LINE_Y - 4)
		dot.Size = UDim2.fromOffset(40, 24)
		dot.BackgroundColor3 = b.done and Theme.colors.gold or Color3.fromRGB(60, 66, 82)
		dot.Font = Theme.font
		dot.TextSize = ts
		dot.TextColor3 = b.done and Color3.fromRGB(30, 24, 10) or Theme.colors.textPrimary
		dot.Text = tostring(b.threshold)
		dot.Parent = node
		Theme.corner(dot, 12)
		if b.claimed then
			doneBadge(node)
		end
		local r, goldText = Info.reward({ kind = "board", threshold = b.threshold })
		local yy = LINE_Y + 14
		for _, key in ipairs(RewardIcons.order) do
			if r and r[key] and r[key] ~= 0 then
				local row = RewardIcons.row(node, { [key] = r[key] }, iconSize, { goldText = goldText, position = UDim2.fromOffset(6, yy), frameSize = UDim2.new(1, -8, 0, iconSize) })
				row.Name = "Reward_" .. key
				yy += iconSize + 4
			end
		end
		if b.claimed then
			for _, d in ipairs(node:GetDescendants()) do
				if d:IsA("ImageLabel") then
					d.ImageTransparency = 0.45
				end
			end
		end
		node.Activated:Connect(function()
			S.select({ kind = "board", id = id, threshold = b.threshold })
		end)
	end
	local canvasW = PAD * 2 + n * NODE_W
	scroll.CanvasSize = UDim2.fromOffset(canvasW, LINE_Y + 30 + 3 * (iconSize + 4))
	if nextIndex and not S.boardScrolled then
		S.boardScrolled = true
		scroll.CanvasPosition = Vector2.new(math.max(0, PAD + (nextIndex - 1) * NODE_W - S.gridW / 2), 0)
	end
end

-- 칭호: 칭호 그림 + 이름(등급 색) + [고르기]
local function renderTitles(S, scroll)
	local view = S.view
	local ts = Theme.textSize("caption")
	local hint = label(scroll, Text.name(CodexData.text.titleHint), "caption", Theme.colors.textSecondary, UDim2.fromOffset(PAD, 2), UDim2.new(1, -PAD * 2, 0, ts * 2 + 4), Enum.TextXAlignment.Left)
	hint.TextWrapped = true
	local y = ts * 2 + 10
	local rows = { { id = "", name = CodexData.text.titleNone } }
	for _, t in ipairs(view.titles) do
		table.insert(rows, t)
	end
	local ROW = 52
	for _, t in ipairs(rows) do
		local selected = (view.selected or "") == t.id
		local f = Instance.new("Frame")
		f.Name = "Title_" .. (t.id ~= "" and t.id or "none")
		f.BackgroundColor3 = selected and Color3.fromRGB(62, 54, 100) or C_IDLE
		f.Position = UDim2.fromOffset(PAD, y)
		f.Size = UDim2.new(1, -PAD * 2, 0, ROW - 4)
		f.Parent = scroll
		f:SetAttribute("CodexCell", "title:" .. t.id)
		Theme.corner(f, 8)
		local icon = ArtImage.label(f, "icons/reward/title", UDim2.fromOffset(32, 32), "")
		icon.Name = "Icon"
		icon.Position = UDim2.fromOffset(8, (ROW - 4 - 32) / 2)
		label(f, CodexRules.titleText(t.id, t.name), "body", t.grade and Info.gradeColor(t.grade) or Theme.colors.textPrimary, UDim2.fromOffset(48, 0), UDim2.new(1, -160, 1, 0), Enum.TextXAlignment.Left).Name = "Name"
		local b = Button.build({ parent = f, kind = selected and "secondary" or "primary", text = selected and Text.get("codex.v2.usingTitle") or Text.get("codex.v2.useTitle"), width = 96, height = 44,
			position = UDim2.new(1, -2, 0.5, 0), anchorPoint = Vector2.new(1, 0.5), onActivated = function()
				S.send("title", t.id)
			end })
		b.setEnabled(not selected)
		y += ROW
	end
	scroll.CanvasSize = UDim2.fromOffset(0, y + 8)
end

function Grid.render(S, tabId, scroll)
	for _, child in ipairs(scroll:GetChildren()) do
		if not child:IsA("UIBase") then
			child:Destroy()
		end
	end
	if tabId == "armor" then
		renderArmor(S, scroll)
	elseif tabId == "board" then
		renderBoard(S, scroll)
	elseif tabId == "title" then
		renderTitles(S, scroll)
	else
		renderLines(S, scroll, tabId)
	end
end

return Grid
