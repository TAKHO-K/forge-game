-- QUEUE-MENU2 F: 전설 일러스트 재생기 자리(데이터 = shared/data/LegendData) - 그림 · 움직임 데이터가 오기 전 = 임시 실루엣(직업색) + temp 연출.
--   LegendPlayer.new(holder) → { select(classId), confirm(classId, done), stop() }
--   select = 그 직업 전설을 보이고 앞으로 살짝(선택 강조) · anim.states.idle 재생 / confirm = 섬광(flashSeconds)으로 가리며 액션 포즈로 교체 → actionHoldSeconds 유지 → done()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LegendData = require(ReplicatedStorage.Shared.data.LegendData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)

local LegendPlayer = {}

local function imageOf(id)
	return id and ("rbxassetid://" .. tostring(id)) or nil
end

function LegendPlayer.new(holder)
	local frame = Instance.new("Frame")
	frame.Name = "LegendStage"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ClipsDescendants = true
	frame.Parent = holder

	local figure = Instance.new("ImageLabel") -- 그림이 있으면 이것(대기 · 액션 교체)
	figure.Name = "Figure"
	figure.BackgroundTransparency = 1
	figure.AnchorPoint = Vector2.new(0.5, 1)
	figure.Position = UDim2.fromScale(0.5, 1)
	figure.Size = UDim2.fromScale(0.9, 0.95)
	figure.ScaleType = Enum.ScaleType.Fit
	figure.Parent = frame

	local silhouette = Instance.new("Frame") -- 임시 실루엣(머리 + 몸 · 직업색)
	silhouette.Name = "TempSilhouette"
	silhouette.BackgroundTransparency = 1
	silhouette.AnchorPoint = Vector2.new(0.5, 1)
	silhouette.Position = UDim2.fromScale(0.5, 0.92)
	silhouette.Size = UDim2.fromScale(0.42, 0.8)
	silhouette.Parent = frame
	local head = Instance.new("Frame")
	head.AnchorPoint = Vector2.new(0.5, 0)
	head.Position = UDim2.fromScale(0.5, 0)
	head.Size = UDim2.fromScale(0.38, 0.22)
	head.BorderSizePixel = 0
	head.Parent = silhouette
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(1, 0)
	hc.Parent = head
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(0.8, 0.74)
	body.BorderSizePixel = 0
	body.Parent = silhouette
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0.2, 0)
	bc.Parent = body
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "LegendName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.fromScale(0.5, 0.02)
	nameLabel.Size = UDim2.new(1, -16, 0, 26)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 20
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Parent = frame

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 5
	flash.Parent = frame

	local self = {}
	local playing = {}
	local current = nil

	function self.stop()
		for _, t in ipairs(playing) do
			t:Cancel()
		end
		playing = {}
	end

	-- 움직임 데이터 재생(LegendData.anim.states[이름].tracks) - 없으면 아무것도 안 함
	local parts = { figure = figure, glow = frame, weapon = figure, sparkle = frame }
	local function playState(name)
		local state = LegendData.anim and LegendData.anim.states and LegendData.anim.states[name]
		for _, tr in ipairs(state and state.tracks or {}) do
			local target = parts[tr.part]
			if target and tr.prop and tr.to ~= nil then
				local ok, tween = pcall(function()
					local info = TweenInfo.new(tr.seconds or 1, Enum.EasingStyle[tr.easing or "Sine"], Enum.EasingDirection[tr.direction or "InOut"], tr.repeats or 0, tr.reverses == true, tr.delay or 0)
					return TweenService:Create(target, info, { [tr.prop] = tr.to })
				end)
				if ok then
					tween:Play()
					table.insert(playing, tween)
				end
			end
		end
	end

	local function showArt(classId, pose)
		local art = LegendData.classes[classId] or {}
		local img = imageOf(pose == "action" and (art.action or art.idle) or art.idle)
		figure.Image = img or ""
		figure.Visible = img ~= nil
		silhouette.Visible = img == nil
		local color = UIColors.classAccent[classId] or Color3.fromRGB(160, 160, 170)
		head.BackgroundColor3, body.BackgroundColor3 = color, color
		nameLabel.Text = Text.get("class.name." .. tostring(classId))
		frame:SetAttribute("LegendClass", classId)
		frame:SetAttribute("LegendPose", pose)
	end

	function self.select(classId)
		self.stop()
		current = classId
		showArt(classId, "idle")
		local T = LegendData.temp
		local base = silhouette.Visible and UDim2.fromScale(0.42, 0.8) or UDim2.fromScale(0.9, 0.95)
		local target = silhouette.Visible and silhouette or figure
		target.Size = base
		local grow = UDim2.fromScale(base.X.Scale * T.selectScale, base.Y.Scale * T.selectScale)
		TweenService:Create(target, TweenInfo.new(T.selectSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = grow }):Play()
		playState("select")
		playState("idle")
	end

	function self.confirm(classId, done)
		local T = LegendData.temp
		self.stop()
		flash.BackgroundTransparency = 0
		showArt(classId or current, "action")
		playState("confirm")
		TweenService:Create(flash, TweenInfo.new(T.flashSeconds), { BackgroundTransparency = 1 }):Play()
		task.delay(T.flashSeconds + T.actionHoldSeconds, function()
			if done then
				done()
			end
		end)
	end

	return self
end

return LegendPlayer
