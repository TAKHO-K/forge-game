-- QUEUE-ALL6 H 꾸미기 소품 연출(클라 그림만 - 판정 · 드랍 · 저장 무관). 장착 = Player Attribute Cosmetic_<칸>(서버 CosmeticService).
--   처치 이펙트(killFx): 서버 CosmeticKill(처치한 사람 · 모양 · 몹 · 자리) → 몹 복제본이 날아가거나(로켓) 부풀어 터짐(풍선). 진짜 몹은 그 자리에서 죽고 드랍도 그 자리.
--     풀 연출 = 내 화면에서 0.5초에 1번(나머지 = 짧은 별 터짐) · 남의 것 = 작고 옅게 · 보스전 중(내가) = 50% 이하 · 연출 세기 끔 = 안 그림.
--   강화 연출(enhanceFx 황금 망치): EnhanceResult 성공에만 금빛 망치 내려찍기 + 불꽃(실패 · 하락 · 초기화 연출은 그대로).
--   귀환 연출(recallFx 대장간 화로): RecallCastUntil 동안 발밑 둘레 화로 셋 + 불씨 · 끝나면(취소 아님) 불꽃 솟구치며 사라짐 - 남의 귀환도 보인다(옅게).
--   이모트(highFive): EmoteEvent offer = 수락 단추(8초) · play = 두 사람 사이 "짝!" 별 터짐.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Fx = require(script.Parent.ArtV1Fx)
local Text = require(ReplicatedStorage.Shared.Text)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 236, 110) -- 금노랑(위험색 경계 51° 위 - 망치와 모루 테마와 같은 계열)
local STAR = Color3.fromRGB(255, 244, 170)
local lastFullKill = 0

local function scale(isMine)
	local s = isMine and 1 or 0.55 -- 남의 효과 약하게
	if player:GetAttribute("BossEncounterId") ~= nil then
		s = math.min(s, 0.5) -- 보스전 중 ≤ 50%
	end
	return s
end

local function visualClone(model)
	local ok, clone = pcall(function()
		model.Archivable = true
		return model:Clone()
	end)
	if not ok or not clone then
		return nil
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	clone.Name = "CosmeticKillGhost"
	clone.Parent = Workspace
	return clone
end

local function starPop(pos, s)
	Fx.flash(pos, 4 * s, 0.3, STAR)
	Fx.burst(pos, math.floor(10 * s + 0.5), { color = STAR, size = 0.4 * s, speed = 12, spread = 180, gravity = 6, lifetime = { 0.3, 0.6 } })
end

-- ── 처치 이펙트 ──
local function rocket(model, pos, s, full)
	if not full then
		starPop(pos + Vector3.new(0, 2, 0), s * 0.6)
		return
	end
	local ghost = model and model.Parent and visualClone(model)
	if not ghost then
		starPop(pos + Vector3.new(0, 2, 0), s)
		return
	end
	local start = ghost:GetPivot()
	local away = (pos - Workspace.CurrentCamera.CFrame.Position) * Vector3.new(1, 0, 1)
	away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, -1)
	local t0, total = os.clock(), 1.0 -- Play 1: 0.8초 · 위로 70 = 0.2초 만에 화면 밖 → 낮고 길게(멀리 날아가며 지평선 위에서 반짝)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) / total
		if t >= 1 or not ghost.Parent then
			conn:Disconnect()
			if ghost.Parent then
				local at = ghost:GetPivot().Position
				ghost:Destroy()
				Fx.flash(at, 6 * s, 0.35, STAR) -- 하늘 멀리 "반짝"
				Fx.burst(at, math.floor(8 * s + 0.5), { color = STAR, size = 0.6 * s, speed = 6, spread = 180, gravity = 0, lifetime = { 0.3, 0.5 } })
			end
			return
		end
		local p = pos + away * (48 * t) + Vector3.new(0, 26 * t, 0)
		ghost:PivotTo(CFrame.new(p) * start.Rotation * CFrame.Angles(t * 12, t * 8, 0))
		for _, d in ipairs(ghost:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = t * 0.6
			end
		end
	end)
end

local function balloon(model, pos, s, full)
	if not full then
		starPop(pos + Vector3.new(0, 2, 0), s * 0.6)
		return
	end
	local ghost = model and model.Parent and visualClone(model)
	if ghost then
		local base = ghost:GetScale()
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - t0) / 0.28
			if t >= 1 or not ghost.Parent then
				conn:Disconnect()
				if ghost.Parent then
					ghost:Destroy()
				end
				return
			end
			ghost:ScaleTo(base * (1 + 0.45 * t)) -- 부풀어 오름
		end)
	end
	task.delay(0.28, function() -- 펑 + 색종이(파스텔 - 위험색 아님)
		Fx.flash(pos + Vector3.new(0, 2, 0), 5 * s, 0.25, Color3.new(1, 1, 1))
		for _, c in ipairs({ Color3.fromRGB(150, 200, 255), Color3.fromRGB(190, 160, 255), Color3.fromRGB(170, 240, 190), Color3.fromRGB(255, 240, 150) }) do
			Fx.burst(pos + Vector3.new(0, 2, 0), math.floor(5 * s + 0.5), { color = c, size = 0.35 * s, speed = 14, spread = 180, gravity = 18, lifetime = { 0.5, 0.9 }, lightEmission = 0.3 })
		end
	end)
end

local killRemote = ReplicatedStorage:WaitForChild("CosmeticKill", 30)
if killRemote then
	killRemote.OnClientEvent:Connect(function(userId, look, model, pos)
		if not Fx.isOn() or typeof(pos) ~= "Vector3" then
			return
		end
		local isMine = userId == player.UserId
		if not isMine and Workspace.CurrentCamera and (pos - Workspace.CurrentCamera.CFrame.Position).Magnitude > 140 then
			return
		end
		local now = os.clock()
		local full = now - lastFullKill >= 0.5 -- 풀 연출 0.5초에 1번(내 화면 기준)
		if full then
			lastFullKill = now
		end
		local s = scale(isMine)
		if look == "rocketPop" then
			rocket(typeof(model) == "Instance" and model or nil, pos, s, full)
		elseif look == "balloonPop" then
			balloon(typeof(model) == "Instance" and model or nil, pos, s, full)
		end
	end)
end

-- ── 강화 성공 황금 망치(내 강화만) ──
local enhanceResult = ReplicatedStorage:WaitForChild("EnhanceResult", 30)
if enhanceResult then
	enhanceResult.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or data.result ~= "success" or player:GetAttribute("Cosmetic_enhanceFx") ~= "goldenHammer" or not Fx.isOn() then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local at = root.Position + root.CFrame.LookVector * 3 - Vector3.new(0, 2.4, 0) -- 발 높이 + 0.6(모루를 내려찍는 자리)
		-- Play 1: Neon 머리 + 5 위 시작 = 번쩍이는 "해"처럼 보였다 → 금속 금빛 머리 · 바로 위 3.2에서 수직으로 내려찍기
		local top = CFrame.new(at + Vector3.new(0, 3.2, 0)) * root.CFrame.Rotation
		local head = Fx.part("GoldenHammerHead", Vector3.new(1.6, 0.9, 0.9), GOLD, top, Enum.PartType.Block, Enum.Material.Metal)
		head.Reflectance = 0.25
		local handle = Fx.part("GoldenHammerHandle", Vector3.new(0.28, 2.2, 0.28), Color3.fromRGB(150, 110, 60), top * CFrame.new(0, 1.5, 0), Enum.PartType.Block, Enum.Material.Wood)
		local hit = top - Vector3.new(0, 2.75, 0) -- 머리 바닥 = 땅
		TweenService:Create(head, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), { CFrame = hit }):Play()
		TweenService:Create(handle, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), { CFrame = hit * CFrame.new(0, 1.5, 0) }):Play()
		task.delay(0.22, function()
			Fx.flash(at, 4, 0.3, GOLD)
			Fx.ring(at - Vector3.new(0, 0.5, 0), 9, 0.5, GOLD, 0.2, 0.2)
			Fx.burst(at, 18, { color = GOLD, size = 0.35, speed = 16, spread = 70, gravity = 28, lifetime = { 0.4, 0.8 } })
			TweenService:Create(head, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			TweenService:Create(handle, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(head, 0.8)
		Debris:AddItem(handle, 0.8)
	end)
end

-- ── 귀환 대장간 화로(모든 사람 - 남의 것은 옅게) ──
local braziers = {} -- [Player] = { parts }
local function clearBraziers(p, finished)
	local list = braziers[p]
	braziers[p] = nil
	if not list then
		return
	end
	for _, part in ipairs(list) do
		if finished and part.Name == "BrazierBowl" then
			Fx.burst(part.Position + Vector3.new(0, 0.6, 0), 8, { color = GOLD, size = 0.3, speed = 14, spread = 25, gravity = -2, lifetime = { 0.4, 0.8 } })
		end
		TweenService:Create(part, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		Debris:AddItem(part, 0.4)
	end
end
local function startBraziers(p)
	clearBraziers(p, false)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not root or not Fx.isOn() then
		return
	end
	local s = scale(p == player)
	local feet = root.Position - Vector3.new(0, 3, 0)
	local list = {}
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		local spot = feet + Vector3.new(math.cos(a) * 3.2, 0.5, math.sin(a) * 3.2)
		local bowl = Fx.part("BrazierBowl", Vector3.new(0.9, 1.4, 1.4), Color3.fromRGB(70, 66, 72), CFrame.new(spot) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder, Enum.Material.Metal)
		local fire = Fx.part("BrazierFire", Vector3.new(0.8, 0.8, 0.8) * s, GOLD, CFrame.new(spot + Vector3.new(0, 0.7, 0)), Enum.PartType.Ball, Enum.Material.Neon)
		fire.Transparency = 1 - 0.8 * s
		TweenService:Create(fire, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = fire.Size * 1.35 }):Play()
		table.insert(list, bowl)
		table.insert(list, fire)
	end
	braziers[p] = list
end
local function watch(p)
	p:GetAttributeChangedSignal("RecallCastUntil"):Connect(function()
		if p:GetAttribute("Cosmetic_recallFx") ~= "forgeBrazier" then
			return
		end
		if p:GetAttribute("RecallCastUntil") then
			startBraziers(p)
		else
			local cancelled = (p:GetAttribute("RecallCancelAt") or 0) > Workspace:GetServerTimeNow() - 0.5
			clearBraziers(p, not cancelled) -- 끝(사라짐) = 불꽃 솟구침 · 취소 = 그냥 꺼짐
		end
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(p)
	clearBraziers(p, false)
end)

-- ── 하이파이브 ──
local emoteEvent = ReplicatedStorage:WaitForChild("EmoteEvent", 30)
local emoteRequest = ReplicatedStorage:WaitForChild("EmoteRequest", 30)
local offerGui = nil
local function closeOffer()
	if offerGui then
		offerGui:Destroy()
		offerGui = nil
	end
end
if emoteEvent then
	emoteEvent.OnClientEvent:Connect(function(kind, a, b)
		if kind == "offer" then
			closeOffer()
			local from = Players:GetPlayerByUserId(a)
			local gui = Instance.new("ScreenGui")
			gui.Name = "HighFiveOffer"
			gui.ResetOnSpawn = false
			gui.DisplayOrder = 40
			local button = Instance.new("TextButton")
			button.Name = "Accept"
			button.AnchorPoint = Vector2.new(0.5, 1)
			button.Position = UDim2.new(0.5, 0, 1, -170)
			button.Size = UDim2.fromOffset(260, 48)
			button.BackgroundColor3 = Color3.fromRGB(60, 120, 90)
			button.TextColor3 = Color3.new(1, 1, 1)
			button.Font = Enum.Font.GothamBold
			button.TextSize = 16
			button.Text = Text.get("cos.emote.offer", { name = from and from.DisplayName or "?" })
			button.Parent = gui
			Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
			button.Activated:Connect(function()
				if emoteRequest then
					emoteRequest:FireServer("accept", a)
				end
				closeOffer()
			end)
			gui.Parent = player:WaitForChild("PlayerGui")
			offerGui = gui
			task.delay(8, function()
				if offerGui == gui then
					closeOffer()
				end
			end)
		elseif kind == "play" then
			local pa, pb = Players:GetPlayerByUserId(a), Players:GetPlayerByUserId(b)
			local ra = pa and pa.Character and pa.Character:FindFirstChild("HumanoidRootPart")
			local rb = pb and pb.Character and pb.Character:FindFirstChild("HumanoidRootPart")
			if ra and rb and Fx.isOn() then
				local mid = (ra.Position + rb.Position) / 2 + Vector3.new(0, 1.5, 0)
				local s = scale(a == player.UserId or b == player.UserId)
				Fx.flash(mid, 5 * s, 0.3, STAR)
				Fx.burst(mid, math.floor(14 * s + 0.5), { color = STAR, size = 0.35 * s, speed = 10, spread = 180, gravity = 4, lifetime = { 0.4, 0.7 } })
				local hold = Fx.part("HighFiveLabelAnchor", Vector3.one * 0.1, STAR, CFrame.new(mid))
				hold.Transparency = 1
				local g = Instance.new("BillboardGui")
				g.Size = UDim2.fromOffset(90, 40)
				g.Adornee = hold
				g.LightInfluence = 0
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(1, 1)
				t.Font = Enum.Font.GothamBlack
				t.TextScaled = true
				t.TextColor3 = STAR
				t.TextStrokeTransparency = 0.2
				t.Text = Text.get("cos.emote.clap")
				t.Parent = g
				g.Parent = hold
				TweenService:Create(hold, TweenInfo.new(0.7), { CFrame = CFrame.new(mid + Vector3.new(0, 2, 0)) }):Play()
				TweenService:Create(t, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				Debris:AddItem(hold, 0.75)
			end
		elseif kind == "fail" then
			require(script.Parent.ui.kit.Toast).push("TC", { text = Text.get("cos.emote.fail." .. tostring(a)), colorName = "textPrimary", seconds = 2 })
		end
	end)
end

-- 이모트 쓰기(캐릭터 창 꾸미기 탭 단추가 부른다) - 공용 입구
local CosmeticFxApi = Instance.new("BindableEvent")
CosmeticFxApi.Name = "CosmeticEmoteUse"
CosmeticFxApi.Parent = script
CosmeticFxApi.Event:Connect(function()
	if emoteRequest then
		emoteRequest:FireServer("request")
	end
end)
