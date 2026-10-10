-- QUEUE-ALL3 Q1 도감 오른쪽 상세 칸(칸을 눌렀을 때만 - 설명 글은 여기에만).
--   큰 그림(3D 모델이 캐시에 있으면 회전 미리보기 ViewportFrame 1개 - 고른 칸 하나만 · 없으면 2D 그림) · 이름 · 등급 · 어디서(구역 이름 + 작은 지도 조각 + [길 안내]) · 진행 · 보상 그림 + 수량 · [받기](크게 · 초록).
--   Detail.build(parent, S) -> D · D.show(S) · D.stop()(창 닫힘 - 회전 멈춤). 인스턴스는 build 안에서만 만든다(보상 줄 · 3D 모델은 show가 갈아 끼운다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local NEW_LOOK = require(ReplicatedStorage.Shared.data.UiV2Flags).codexNewLook -- UI-1b 1-b 18
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Button = require(script.Parent.Parent.Parent.ui.kit.Button)
local ArtImage = require(script.Parent.Parent.Parent.ui.ArtImage)
local RewardIcons = require(script.Parent.Parent.Parent.ui.RewardIcons)
local Info = require(script.Parent.Info)
local Grid = require(script.Parent.Grid)

local Detail = {}

local PAD = 8
local EDGE = WorldMapData.edge.radius
local PART_KEY = { armor = "codex.v2.part.armor", gloves = "codex.v2.part.gloves", shoes = "codex.v2.part.shoes" }

local function toMap(position)
	return Vector2.new((position.X + EDGE) / (2 * EDGE), (position.Z + EDGE) / (2 * EDGE))
end

local function mapSnippet(parent, size)
	local m = Instance.new("Frame")
	m.Name = "MapSnippet"
	m.Size = UDim2.fromOffset(size, size)
	m.BackgroundColor3 = Color3.fromRGB(46, 70, 92)
	m.ClipsDescendants = true
	m.Parent = parent
	Theme.corner(m, size)
	local img = WorldMapData.map.image and ArtImage.get(WorldMapData.map.image)
	if img then
		local bg = Instance.new("ImageLabel")
		bg.Name = "MapImage"
		bg.BackgroundTransparency = 1
		bg.Size = UDim2.fromScale(1, 1)
		bg.Image = img
		bg.Parent = m
	end
	local discs = {}
	for _, z in ipairs(Info.zones) do
		local c = toMap(WorldMapLayout.regionCenter(z))
		local rr = WorldMapData.layout.regionRadius / (2 * EDGE)
		local d = Instance.new("Frame")
		d.Name = "Zone_" .. z.key
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = UDim2.fromScale(c.X, c.Y)
		d.Size = UDim2.fromScale(rr * 2, rr * 2)
		local t = z.floorTint or { 140, 150, 140 }
		d.BackgroundColor3 = Color3.fromRGB(t[1], t[2], t[3]):Lerp(Color3.fromRGB(96, 160, 90), 0.35)
		d.BackgroundTransparency = img and 1 or 0
		d.Parent = m
		Theme.corner(d, 9999)
		local st = Theme.stroke(d)
		st.Color, st.Thickness, st.Transparency = Theme.colors.ember, 2, 1
		discs[z.key] = st
	end
	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	local hr = WorldMapData.hub.safeRadius / EDGE
	hub.Size = UDim2.fromScale(hr, hr)
	hub.BackgroundColor3 = Color3.fromRGB(120, 190, 100)
	hub.BackgroundTransparency = img and 1 or 0
	hub.Parent = m
	Theme.corner(hub, 9999)
	local pin = Instance.new("ImageLabel")
	pin.Name = "Target"
	pin.AnchorPoint = Vector2.new(0.5, 1)
	pin.Size = UDim2.fromOffset(18, 18)
	pin.BackgroundTransparency = 1
	pin.Image = ArtImage.get(require(game:GetService("ReplicatedStorage").Shared.UiModel).mapIcon("map.pin.quest")) or ""
	pin.ZIndex = 3
	pin.Parent = m
	return m, discs, pin
end

function Detail.build(parent, S)
	local D = {}
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Detail"
	scroll.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	scroll.BackgroundTransparency = 0.2
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent
	Theme.corner(scroll, 10)
	D.root = scroll

	local holder = Instance.new("Frame")
	holder.Name = "PicHolder"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.BackgroundColor3 = Color3.fromRGB(34, 40, 54)
	holder.Parent = scroll
	Theme.corner(holder, 12)
	local pic = Grid.picture(holder, "", UDim2.fromScale(0.05, 0.05), UDim2.fromScale(0.9, 0.9))
	local pic2 = Grid.picture(holder, "", UDim2.fromScale(0.52, 0.52), UDim2.fromScale(0.46, 0.46), nil, "Pic2")
	local parts = {}
	for i = 1, 3 do
		parts[i] = Grid.picture(holder, "", UDim2.fromScale((i - 1) / 3 + 0.01, 0.3), UDim2.fromScale(0.31, 0.4), nil, "Part" .. i)
	end
	local unknown = Theme.label(holder, "?", "title", "textPrimary")
	unknown.Name = "Unknown"
	unknown.Size = UDim2.fromScale(1, 1)
	unknown.TextXAlignment = Enum.TextXAlignment.Center
	unknown.TextSize = 36
	unknown.TextStrokeTransparency = 0.2
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Model"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(170, 170, 185)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1.5, -1)
	vp.Visible = false
	vp.Parent = holder
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.Parent = vp
	vp.CurrentCamera = cam

	local name = Theme.label(scroll, "", "header", "textPrimary")
	name.Name = "ItemName"
	local grade = Theme.label(scroll, "", "caption", "textPrimary")
	grade.Name = "Grade"
	grade.Font = Theme.font
	local desc = Theme.label(scroll, "", "caption", "textSecondary")
	desc.Name = "Desc"
	desc.TextWrapped = true
	desc.TextTruncate = Enum.TextTruncate.None
	desc.TextYAlignment = Enum.TextYAlignment.Top
	local where = Theme.label(scroll, "", "caption", "textPrimary")
	where.Name = "Where"
	local snippet, discs, target = mapSnippet(scroll, 72)
	local guide = Button.build({ parent = scroll, kind = "secondary", text = Text.get("codex.v2.guide"), width = 96, height = 44, onActivated = function()
		if D.guide then
			D.guide()
		end
	end })
	guide.root.Name = "Guide"
	local progress = Theme.label(scroll, "", "caption", "textPrimary")
	progress.Name = "Progress"
	progress.Font = Theme.font
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(50, 56, 70)
	bar.BorderSizePixel = 0
	bar.Parent = scroll
	Theme.corner(bar, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.colors.gold
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Theme.corner(fill, 4)
	local rewardHolder = Instance.new("Frame")
	rewardHolder.Name = "RewardHolder"
	rewardHolder.BackgroundTransparency = 1
	rewardHolder.Parent = scroll
	local claim = Button.build({ parent = scroll, kind = "claim", text = Text.get("codex.v2.claim"), width = 120, height = S.claimH, onActivated = function()
		if D.claim then
			D.claim()
		end
	end })
	claim.root.Name = "Claim"
	local empty = Theme.label(scroll, Text.get("codex.v2.selectHint"), "caption", "textSecondary")
	empty.Name = "EmptyHint"
	empty.TextWrapped = true
	empty.TextXAlignment = Enum.TextXAlignment.Center

	-- 3D 회전(고른 칸 1개만 · 카메라가 모델 둘레를 돈다)
	local orbit, model
	local function stopModel()
		if orbit then
			orbit:Disconnect()
			orbit = nil
		end
		if model then
			model:Destroy()
			model = nil
		end
		vp.Visible = false
	end
	D.stop = stopModel
	local function showModel(spec)
		stopModel()
		if not spec then
			return false
		end
		local ok, src = pcall(function()
			local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
			if spec.weapon then
				return ArtMeshKit.weaponModel(spec.weapon, spec.grade, NEW_LOOK and { v4Only = true } or nil)
			end
			local m = ArtMeshKit.get(spec.key)
			return m and m:Clone() or nil
		end)
		if not ok or not src then
			return false
		end
		model = src
		model.Parent = vp
		local cf, size = model:GetBoundingBox()
		local center = cf.Position
		local dist = (size.Magnitude / 2) / math.tan(math.rad(cam.FieldOfView / 2)) * 1.05
		local angle = 0
		local function place()
			cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(angle) * dist, dist * 0.25, math.cos(angle) * dist), center)
		end
		place()
		orbit = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 0.7
			place()
		end)
		vp.Visible = true
		return true
	end

	local rewardRow
	function D.show()
		local sel = S.selected
		local w = S.detailW
		local inner = w - PAD * 2 - 6
		local P = math.min(S.phone and 92 or 120, inner)
		holder.Size = UDim2.fromOffset(P, P)
		holder.Position = UDim2.new(0.5, -3, 0, PAD)
		pic.Visible, pic2.Visible, unknown.Visible = false, false, false
		pic.ImageColor3, pic.ImageTransparency = Color3.new(1, 1, 1), 0
		for _, p in ipairs(parts) do
			p.Visible = false
		end
		stopModel()
		if rewardRow then
			rewardRow:Destroy()
			rewardRow = nil
		end
		D.guide, D.claim = nil, nil
		local all = { name, grade, desc, where, snippet, guide.root, progress, bar, rewardHolder, claim.root }
		for _, g in ipairs(all) do
			g.Visible = false
		end
		empty.Visible = false
		holder.BackgroundColor3 = Color3.fromRGB(34, 40, 54)
		local ts = Theme.textSize("caption")
		local y = PAD + P + 8
		local function place(inst, h, x, width)
			inst.Position = UDim2.fromOffset(x or PAD, y)
			inst.Size = UDim2.fromOffset(width or inner, h)
			inst.Visible = true
			y += h + 4
		end
		if not sel then
			local tabIcon = "icons/codex/tab_equipment"
			for _, t in ipairs(Info.tabs) do
				if t.id == S.tab then
					tabIcon = "icons/codex/tab_" .. t.icon
				end
			end
			pic.Image = ArtImage.get(tabIcon) or ""
			pic.Visible = true
			place(empty, ts * 3 + 6)
			scroll.CanvasSize = UDim2.fromOffset(0, y + PAD)
			return
		end
		local view = S.view
		local m, cv, ids, reward, goldText, whereInfo
		local pr = { v = 0, need = 1, done = false, claimed = false, claimable = false }
		if sel.kind == "bingo" then
			m = { kind = "armor", zone = sel.zone, grade = sel.grade }
			local lines, claimIds, sum = {}, {}, {}
			local anyClaim = false
			for i, p in ipairs(Info.parts) do
				local id = ("armor:%s:%s:%s"):format(sel.zone, sel.grade, p)
				local c = view.cells[id]
				parts[i].Image = ArtImage.get(("icons/armor/%s_%s_%s"):format(p, sel.zone, sel.grade)) or ""
				parts[i].Visible = true
				if c then
					pr.v += c.done and 1 or 0
					table.insert(lines, Text.get("codex.v2.partLine", { part = Text.get(PART_KEY[p]), v = tostring(c.v), need = tostring(c.need) }))
					if c.done and not c.claimed then
						table.insert(claimIds, id)
						anyClaim = true
					end
				end
			end
			pr.need, pr.done = 3, pr.v == 3
			pr.claimable = anyClaim
			pr.claimed = pr.done and not anyClaim
			-- 보상 = 받을 부위들의 합(받을 것이 없으면 3부위 전체 미리보기)
			for _, p in ipairs(Info.parts) do
				local id = ("armor:%s:%s:%s"):format(sel.zone, sel.grade, p)
				local c = view.cells[id]
				if not anyClaim or (c and c.done and not c.claimed) then
					local r = Info.reward(Info.meta(id))
					for k, v in pairs(r or {}) do
						sum[k] = (sum[k] or 0) + v
					end
				end
			end
			reward, goldText = sum, sum.gold and NumberFormat.format(sum.gold) or nil
			ids = claimIds
			desc.Text = table.concat(lines, "\n")
			whereInfo = Info.where(m)
		elseif sel.kind == "board" then
			local b
			for _, bb in ipairs(view.board) do
				if bb.threshold == sel.threshold then
					b = bb
				end
			end
			if not b then
				S.selected = nil
				return D.show()
			end
			pic.Image = ArtImage.get("icons/codex/tab_rewards") or ""
			pic.Visible = true
			pr = { v = math.min(view.score, b.threshold), need = b.threshold, done = b.done, claimed = b.claimed, claimable = b.done and not b.claimed }
			reward, goldText = Info.reward({ kind = "board", threshold = b.threshold })
			ids = { sel.id }
			name.Text = Text.get("codex.v2.boardStep", { n = tostring(b.threshold) })
			name.TextColor3 = Theme.colors.gold
			place(name, ts + 8)
		else
			m = Info.meta(sel.id)
			cv = view.cells[sel.id]
			if not m or not cv then
				S.selected = nil
				return D.show()
			end
			local p = Info.picture(view, m)
			pic.Image = ArtImage.get(p.key) or ""
			pic.Visible = true
			if p.silhouette then
				pic.ImageColor3 = Color3.new(0, 0, 0)
				unknown.Visible = true
			elseif p.dim then
				pic.ImageColor3, pic.ImageTransparency = Color3.fromRGB(120, 124, 132), 0.65
			end
			if p.tint then
				holder.BackgroundColor3 = p.tint
			end
			if p.overlay then
				pic2.Image = ArtImage.get(p.overlay) or ""
				pic2.Visible = true
			end
			if NEW_LOOK and m.kind == "boss" and not Info.unknown(view, m) then -- UI-1b 1-b 18: 보스 = F 초상(새 모습 · 옛 몸 3D 안 씀)
				local e = require(script.Parent.Parent.Parent.ui.v2.BossPortrait).entry(m.bossId)
				local img = e and ArtImage.get(e.image)
				if img then
					pic.Image = img
					pic.ImageColor3, pic.ImageTransparency = Color3.new(1, 1, 1), 0
					pic.Visible, pic2.Visible = true, false
				end
			elseif showModel(Info.model(view, m)) then
				pic.Visible, pic2.Visible = false, false
			end
			pr = { v = cv.v, need = cv.need, done = cv.done, claimed = cv.claimed, claimable = cv.done and not cv.claimed }
			reward, goldText = Info.reward(m)
			ids = { sel.id }
			desc.Text = Info.hint(view, m) or ""
			whereInfo = Info.where(m)
		end
		if m then
			local n, g, color = Info.detailName(view, m)
			name.Text = n
			name.TextColor3 = Theme.colors.textPrimary
			place(name, ts + 8)
			grade.Text = g or ""
			grade.TextColor3 = color
			place(grade, ts + 4)
			if desc.Text ~= "" then
				local lines = select(2, desc.Text:gsub("\n", "")) + 1
				local est = math.max(lines, math.ceil(#desc.Text / 3 * ts * 0.9 / math.max(1, inner)) + lines - 1)
				place(desc, est * (ts + 3) + 2)
			end
		end
		if whereInfo then
			where.Text = Text.get("codex.v2.where", { place = whereInfo.place })
			place(where, ts + 4)
			for key, st in pairs(discs) do
				st.Transparency = key == whereInfo.zone and 0 or 1
			end
			local g = whereInfo.guide
			if whereInfo.position then -- UI-1b: 위치 없음(탐험의 알) = 지도 조각 · [길 안내] 없음
				local r = toMap(whereInfo.position)
				target.Position = UDim2.fromScale(r.X, r.Y)
				snippet.Position = UDim2.fromOffset(PAD, y)
				snippet.Visible = true
				guide.root.Position = UDim2.fromOffset(PAD + 72 + 8, y + 14)
				guide.root.Visible = g ~= nil
				y += 72 + 6
			end
			D.guide = g and function()
				local ok = false
				if g.quest then
					ok = require(S.clientRoot.QuestGuide).go(g.quest, false)
				else
					ok = require(S.clientRoot.MapPins).go(g.pos, g.label, false)
				end
				if ok then
					S.close()
				end
			end or nil
		end
		progress.Text = Text.get("codex.v2.progress", { v = tostring(pr.v), need = tostring(pr.need) })
		progress.TextColor3 = pr.done and Theme.colors.gold or Theme.colors.textPrimary
		place(progress, ts + 4)
		place(bar, 8)
		fill.Size = UDim2.fromScale(math.clamp(pr.v / math.max(1, pr.need), 0, 1), 1)
		local iconSize = S.phone and 30 or 28
		if reward and next(reward) then
			place(rewardHolder, iconSize)
			rewardRow = RewardIcons.row(rewardHolder, reward, iconSize, { goldText = goldText, name = "RewardRow" })
		end
		claim.setText(pr.claimable and Text.get("codex.v2.claim") or (pr.claimed and Text.get("codex.v2.claimed") or Text.get("codex.v2.locked")))
		claim.setEnabled(pr.claimable)
		claim.root.Size = UDim2.fromOffset(inner, S.claimH)
		claim.root.Position = UDim2.fromOffset(PAD, y + 2)
		claim.root.Visible = true
		y += S.claimH + 6
		if pr.claimable then
			D.claim = function()
				S.claim(ids, rewardRow)
			end
		end
		scroll.CanvasSize = UDim2.fromOffset(0, y + PAD)
	end
	return D
end

return Detail
