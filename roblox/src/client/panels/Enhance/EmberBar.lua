-- UI-1 6단계 불씨 칸(05_enhance-inherit/v4 spec §3 · §6): 칸 1개 = 실패 1번 · 칸 수 = 그 단계 0 → 가득 실패 수(EmberView - 서버와 같은 getGaugeGain).
--   위 = "가득까지 n번"(주인공 숫자 · 호박) + 오른쪽 "불씨 n%" · 칸 줄(칠함 = 세로 그라데이션 · 줄무늬 = 다음 실패 1번 · 불꽃 = 지금 끝) + 메달(가득 = 켜짐) · 아래 = "실패 1번 = 불씨 +n%".
--   결과 연출: 실패 = 새 칸 0.25초 차오름 + "+n%" 떠오름 + n 통 튐 · 하락 · 초기화 = 차오른 뒤 칸 수만 새 단계로 다시 나눔(불씨 % 그대로) · 성공 = 오른쪽 → 왼쪽 0.4초 비움 + 반짝 6개.
--   강화대 창(StationV4)과 큰 창(옛 강화 패널 불씨 줄 자리)이 같은 부품을 쓴다. 수치 · 색 = UiLayoutData.enhance.v4.ember.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EmberView = require(ReplicatedStorage.Shared.EmberView)
local Text = require(ReplicatedStorage.Shared.Text)
local UiModel = require(ReplicatedStorage.Shared.UiModel)
local L = require(ReplicatedStorage.Shared.data.UiLayoutData).enhance.v4
local ArtImage = require(script.Parent.Parent.Parent.ui.ArtImage)
local UiKit = require(script.Parent.Parent.Parent.ui.v2.UiKit)

local EmberBar = {}
local E = L.ember
local IMG = L.images

local function hex(h)
	return Color3.fromHex(h)
end

-- 글자 px × 설정 글자 배율(1 · 1.15 · 1.3) - 칸 · 메달 크기는 고정(spec §8)
function EmberBar.textPx(px)
	return math.floor(px * UiModel.textMul(UiKit.textStep(), UiKit.platformTextName()) + 0.5)
end

local function label(parent, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UiKit.font(font or "koreanBold")
	l.TextSize = EmberBar.textPx(size)
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.RichText = true
	l.Text = ""
	l.Parent = parent
	return l
end

-- 높이: PC 104 · 폰 70(글자 배율만큼 위 · 아래 줄이 늘어남)
function EmberBar.height(phone)
	local s = phone and E.phone or E.pc
	local mul = UiModel.textMul(UiKit.textStep(), UiKit.platformTextName())
	return math.floor((phone and L.phone.ember or L.pc.ember) + (s.big + s.foot) * (mul - 1) + 0.5)
end

-- parent 안 (x, y) 폭 width. 반환 bar = { root, update(state), play(data) }
function EmberBar.build(parent, x, y, width, phone)
	local s = phone and E.phone or E.pc
	local h = EmberBar.height(phone)
	local pad = phone and 8 or 12
	local root = Instance.new("Frame")
	root.Name = "EmberBarV4"
	root.Position = UDim2.fromOffset(x, y)
	root.Size = UDim2.fromOffset(width, h)
	root.BackgroundColor3 = hex(E.base)
	root.Parent = parent
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 10)
	rc.Parent = root
	local rs = Instance.new("UIStroke")
	rs.Thickness = 2
	rs.Color = hex(E.stroke)
	rs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rs.Parent = root

	local topH = EmberBar.textPx(s.big) + 4
	local left = label(root, s.small, Color3.fromRGB(230, 232, 240))
	left.Name = "Left"
	left.Position = UDim2.fromOffset(pad, phone and 4 or 8)
	left.Size = UDim2.new(0.75, -pad, 0, topH)
	local pct = label(root, s.small + 2, Color3.fromRGB(230, 232, 240))
	pct.Name = "Pct"
	pct.TextXAlignment = Enum.TextXAlignment.Right
	pct.AnchorPoint = Vector2.new(1, 0)
	pct.Position = UDim2.new(1, -pad, 0, phone and 4 or 8)
	pct.Size = UDim2.new(0.3, 0, 0, topH)

	local rowY = (phone and 4 or 8) + topH + (phone and 2 or 6)
	local row = Instance.new("Frame")
	row.Name = "Cells"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(pad, rowY + (s.medal - s.cellH) / 2)
	row.Size = UDim2.new(1, -(pad * 2 + s.medal + 8), 0, s.cellH)
	row.ClipsDescendants = false
	row.Parent = root
	local medal = Instance.new("ImageLabel")
	medal.Name = "Medal"
	medal.BackgroundTransparency = 1
	medal.AnchorPoint = Vector2.new(1, 0)
	medal.Position = UDim2.new(1, -pad, 0, rowY)
	medal.Size = UDim2.fromOffset(s.medal, s.medal)
	medal.Image = ArtImage.get(IMG.medalOff) or ""
	medal.Parent = root
	local shimmer = Instance.new("ImageLabel")
	shimmer.Name = "Shimmer"
	shimmer.BackgroundTransparency = 1
	shimmer.Image = ArtImage.get(IMG.shimmer) or ""
	shimmer.Size = UDim2.new(0, s.cellH * 3, 1, 8)
	shimmer.Position = UDim2.new(0, 0, 0, -4)
	shimmer.Visible = false
	shimmer.ZIndex = 4
	shimmer.Parent = row

	local foot = label(root, s.foot, Color3.fromRGB(160, 168, 196))
	foot.Name = "Foot"
	foot.AnchorPoint = Vector2.new(0, 1)
	foot.Position = UDim2.new(0, pad, 1, -(phone and 3 or 6))
	foot.Size = UDim2.new(phone and 1 or 0.6, -pad, 0, EmberBar.textPx(s.foot) + 2)
	local footR = nil
	if not phone then
		footR = label(root, s.foot - 1, Color3.fromRGB(120, 128, 156))
		footR.Name = "FootRight"
		footR.TextXAlignment = Enum.TextXAlignment.Right
		footR.AnchorPoint = Vector2.new(1, 1)
		footR.Position = UDim2.new(1, -pad, 1, -6)
		footR.Size = UDim2.new(0.4, 0, 0, EmberBar.textPx(s.foot) + 2)
	end

	local bar = { root = root }
	local cells = {} -- { frame, fill, stroke }
	local stripe, flame = nil, nil
	local view = nil
	local level = 0

	local function gradient(parent)
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex(E.fill[1])), ColorSequenceKeypoint.new(0.5, hex(E.fill[2])), ColorSequenceKeypoint.new(1, hex(E.fill[3])) })
		g.Parent = parent
	end

	local function cellGeom(n)
		local gap = n > s.manyFrom and s.gapMany or s.gap
		local w = width - pad * 2 - s.medal - 8 -- row 폭(기준 px - 바깥 UIScale과 무관)
		local cw = (w - gap * (n - 1)) / n
		return cw, gap
	end

	-- 칸을 n개로 다시 짓는다(단계가 바뀌면 · 처음)
	local function rebuild(n)
		if stripe then
			stripe.Parent = row -- 칸과 같이 지워지지 않게(줄무늬는 칸 안에 넣어 쓴다)
		end
		for _, c in ipairs(cells) do
			c.frame:Destroy()
		end
		cells = {}
		if n <= 0 then
			return
		end
		local cw, gap = cellGeom(n)
		for i = 1, n do
			local f = Instance.new("Frame")
			f.Name = "Cell" .. i
			f.BackgroundColor3 = hex(E.base)
			f.Position = UDim2.fromOffset((i - 1) * (cw + gap), 0)
			f.Size = UDim2.fromOffset(cw, s.cellH)
			f.ClipsDescendants = true
			f.Parent = row
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, s.corner)
			c.Parent = f
			local st = Instance.new("UIStroke")
			st.Thickness = 2
			st.Color = hex(E.stroke)
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Parent = f
			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.BorderSizePixel = 0
			fill.BackgroundColor3 = Color3.new(1, 1, 1)
			fill.Size = UDim2.fromScale(0, 1)
			fill.Parent = f
			gradient(fill)
			cells[i] = { frame = f, fill = fill, stroke = st }
		end
		if not stripe then
			stripe = Instance.new("ImageLabel")
			stripe.Name = "Stripe"
			stripe.BackgroundTransparency = 1
			stripe.Image = ArtImage.get(IMG.stripe) or ""
			stripe.ScaleType = Enum.ScaleType.Tile
			stripe.TileSize = UDim2.fromOffset(E.stripeTile, E.stripeTile)
			stripe.ZIndex = 2
			flame = Instance.new("ImageLabel")
			flame.Name = "Flame"
			flame.BackgroundTransparency = 1
			flame.Image = ArtImage.get(IMG.flame) or ""
			flame.AnchorPoint = Vector2.new(0.5, 1)
			flame.Size = UDim2.fromOffset(s.cellH, s.cellH)
			flame.ZIndex = 3
			flame.Parent = row
		end
	end

	-- 칠함(조각 칸 허용) · 줄무늬 · 불꽃 · 테
	local function paint(filled, n, full)
		for i, c in ipairs(cells) do
			local f = math.clamp(filled - (i - 1), 0, 1)
			c.fill.Size = UDim2.fromScale(f, 1)
			c.stroke.Color = full and hex(E.strokeFull) or hex(E.stroke)
		end
		local next = math.floor(filled) + 1
		if stripe then
			local target = (not full) and cells[next]
			stripe.Parent = target and target.frame or nil
			stripe.Size = UDim2.fromScale(1, 1)
			local endCell = cells[math.max(1, math.ceil(filled))]
			flame.Visible = filled > 0 and not full and endCell ~= nil
			if endCell then
				local frac = filled - math.floor(filled)
				local fx = endCell.frame.Position.X.Offset + endCell.frame.Size.X.Offset * (frac > 0 and frac or 1)
				flame.Position = UDim2.fromOffset(fx, -2)
			end
		end
		medal.Image = ArtImage.get(full and IMG.medalOn or IMG.medalOff) or ""
		rs.Color = full and hex(E.strokeFull) or hex(E.stroke)
		shimmer.Visible = full
	end

	local function texts(v)
		local amber = E.amber
		if v.cells == 0 then
			left.Text = ""
		elseif v.full then
			left.Text = Text.get("ui1.enh.fullBig", { size = tostring(EmberBar.textPx(s.big)), color = amber })
		else
			left.Text = Text.get(v.left == 1 and "ui1.enh.leftOne" or "ui1.enh.left", { n = tostring(v.left), size = tostring(EmberBar.textPx(s.big)), color = amber })
		end
		pct.Text = Text.get("ui1.enh.emberPct", { pct = tostring(v.pct) })
		foot.Text = v.cells > 0 and Text.get("ui1.enh.perFail", { p = ("%.1f"):format(v.gainPct):gsub("%.0$", "") }) or ""
		if footR then
			footR.Text = v.cells > 0 and Text.get("ui1.enh.cellsInfo", { lv = tostring(level), n = tostring(v.cells) }) or ""
		end
	end

	-- state = Controller.getState() (level · gauge)
	function bar.update(state, keepCells)
		level = state.level
		local v = EmberView.compute(state.level, state.gauge)
		if not keepCells and (not view or #cells ~= v.cells) then
			rebuild(v.cells)
		end
		view = v
		paint(v.filled, v.cells, v.full)
		texts(v)
		local last = cells[v.cells]
		if last and v.left == 1 then
			last.stroke.Color = hex(E.strokeLast)
		end
	end

	local function tween(inst, t, props)
		local tw = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		tw:Play()
		return tw
	end

	local function floatText(text)
		local f = label(root, s.small, hex(E.amber), "number")
		f.Text = text
		f.TextXAlignment = Enum.TextXAlignment.Center
		f.AnchorPoint = Vector2.new(0.5, 1)
		local fx = flame and flame.Position.X.Offset + pad or width / 2
		f.Position = UDim2.fromOffset(fx, row.Position.Y.Offset)
		f.Size = UDim2.fromOffset(80, 20)
		f.ZIndex = 6
		tween(f, 0.6, { Position = UDim2.fromOffset(fx, row.Position.Y.Offset - 24), TextTransparency = 1 })
		task.delay(0.65, function()
			f:Destroy()
		end)
	end

	local function bump()
		local sc = left:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		sc.Parent = left
		sc.Scale = 1.15
		tween(sc, 0.25, { Scale = 1 })
	end

	local function sparks()
		for i = 1, 6 do
			local sp = Instance.new("ImageLabel")
			sp.BackgroundTransparency = 1
			sp.Image = ArtImage.get(IMG.spark) or ""
			sp.AnchorPoint = Vector2.new(0.5, 0.5)
			sp.Size = UDim2.fromOffset(18, 18)
			local x0 = (i - 0.5) / 6 * row.Size.X.Offset
			sp.Position = UDim2.fromOffset(x0, s.cellH / 2)
			sp.ZIndex = 6
			sp.Parent = row
			tween(sp, 0.5, { Position = UDim2.fromOffset(x0 + math.random(-12, 12), -18), ImageTransparency = 1 })
			task.delay(0.55, function()
				sp:Destroy()
			end)
		end
	end

	-- 결과 연출(payload = EnhanceResult · after = 결과 뒤 state). 성공 = 비우기 → 새 단계 칸 · 실패 = 차오름 → (단계 바뀜이면) 다시 나눔
	function bar.play(data, after)
		local before = view
		if not before then
			return bar.update(after)
		end
		if data.result == "success" then
			local n = #cells
			for i = n, 1, -1 do
				local c = cells[i]
				task.delay((n - i) * 0.4 / math.max(n, 1), function()
					if c.fill.Parent then
						tween(c.fill, 0.08, { Size = UDim2.fromScale(0, 1) })
					end
				end)
			end
			sparks()
			task.delay(0.5, function()
				bar.update(after)
			end)
			return
		end
		-- 실패(그대로 · 하락 · 초기화): 지금 칸 기준으로 새 불씨만큼 차오름
		local gain = before.gain
		local newFilled = gain > 0 and math.min(before.cells, (after.gauge or 0) / gain) or 0
		for i, c in ipairs(cells) do
			local f = math.clamp(newFilled - (i - 1), 0, 1)
			tween(c.fill, 0.25, { Size = UDim2.fromScale(f, 1) })
		end
		if (data.gaugeGain or 0) > 0 then
			floatText(Text.get("ui1.enh.plusPct", { p = ("%.1f"):format(data.gaugeGain * 100 / (data.gaugeMax or 1000)):gsub("%.0$", "") }))
		end
		bump()
		task.delay(0.3, function()
			local v = EmberView.compute(after.level, after.gauge)
			if v.cells ~= before.cells then -- 단계 바뀜 = 칸 다시 나눔(불씨 % 그대로)
				local note = label(root, s.foot, hex(E.amber))
				note.Text = Text.get("ui1.enh.reflow", { a = tostring(before.cells), b = tostring(v.cells) })
				note.TextXAlignment = Enum.TextXAlignment.Right
				note.AnchorPoint = Vector2.new(1, 1)
				note.Position = UDim2.new(1, -pad, 1, -(phone and 3 or 6))
				note.Size = UDim2.new(0.6, 0, 0, EmberBar.textPx(s.foot) + 2)
				note.ZIndex = 5
				if footR then
					footR.Visible = false
				end
				task.delay(1.5, function()
					note:Destroy()
					if footR then
						footR.Visible = true
					end
				end)
			end
			bar.update(after)
		end)
	end

	-- 숨쉬기: 줄무늬 투명 0.25 ↔ 0.55(1.2초) · 1번 남음 = 마지막 칸 테 0.8초 · 가득 = 반짝 띠 왼→오 1.6초마다
	local hb = RunService.Heartbeat:Connect(function()
		if not root.Parent or not root.Visible then
			return
		end
		local t = os.clock()
		if stripe and stripe.Parent then
			stripe.ImageTransparency = 0.25 + 0.3 * (0.5 + 0.5 * math.sin(t * 2 * math.pi / E.breathe))
		end
		if view and view.left == 1 and cells[view.cells] then
			cells[view.cells].stroke.Transparency = 0.5 - 0.5 * math.sin(t * 2 * math.pi / E.lastBreathe)
		end
		if shimmer.Visible then
			local p = (t % E.shimmerEvery) / E.shimmerEvery
			shimmer.Position = UDim2.new(p * 1.2 - 0.2, 0, 0, -4)
		end
	end)
	root.Destroying:Connect(function()
		hb:Disconnect()
	end)
	return bar
end

return EmberBar
