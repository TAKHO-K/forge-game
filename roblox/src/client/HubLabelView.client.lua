-- QUEUE-ALL8 C 허브 3D 이름표: 거리 규칙 · 겹침 우선순위 · 페이드 · 폰 글자 상한(수치 = data/HubLabelData).
--   대상 = 허브 안(WorldMapLayout.inHub) 이름표 빌보드 - 자리 · 거리 이름(LabelGui) · 기능 아이콘(HubServiceIcon) · 강화대 · 제단 · 보석상인(NameplateGui) · 포탈 안내판.
--   만드는 쪽(server/WorldMap · client/HubServices · WorldClient)은 그대로 두고, 여기서는 보이기(Enabled · 투명도) · 크기만 바꾼다(로컬 - 복제 안 됨).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local L = require(ReplicatedStorage.Shared.data.HubLabelData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)

local player = Players.LocalPlayer

local function isTouchLayout()
	return UserInputService.TouchEnabled or (RunService:IsStudio() and player:GetAttribute("ForceTouchLayout") == true)
end

-- 요소 = 빌보드 하나(이름 또는 아이콘). 표지 = 같은 자리의 이름 + 아이콘 묶음
local elems = {} -- [BillboardGui] = 요소
local hosts = {} -- [BasePart] = { name = 요소, icon = 요소 }

local function hostOf(gui)
	local h = gui.Adornee or gui.Parent
	return h and h:IsA("BasePart") and h or nil
end

local function classify(gui, host)
	if gui.Name == "HubServiceIcon" then
		return "icon"
	end
	if gui.Name == "LabelGui" then
		if host:GetAttribute("Facility") then
			return "street"
		end
		local spot = host:GetAttribute("Spot")
		if spot then
			return L.npcSpots[spot] and "npc" or "function"
		end
		return nil
	end
	if gui.Name == "NameplateGui" then
		local m = host:FindFirstAncestorOfClass("Model")
		return m and L.nameplates[m.Name] or nil
	end
	if gui:FindFirstAncestor(L.portalSignFolder) then
		return "building"
	end
	return nil
end

-- 글자 · 그림 원래 투명도(페이드 = 원래 값에서 1까지)
local function captureLooks(gui)
	local looks = {}
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") then
			table.insert(looks, { d, "TextTransparency", d.TextTransparency })
			table.insert(looks, { d, "TextStrokeTransparency", d.TextStrokeTransparency })
			if d.TextScaled and not d:FindFirstChildOfClass("UITextSizeConstraint") then
				local c = Instance.new("UITextSizeConstraint")
				c.Name = "HubLabelCap"
				c.MaxTextSize = isTouchLayout() and L.phone.maxTextSize or L.maxTextSize
				c.Parent = d
			end
		elseif d:IsA("ImageLabel") then
			table.insert(looks, { d, "ImageTransparency", d.ImageTransparency })
		end
		if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
			table.insert(looks, { d, "BackgroundTransparency", d.BackgroundTransparency })
		end
	end
	return looks
end

local function register(gui)
	if elems[gui] or not gui:IsA("BillboardGui") then
		return
	end
	local host = hostOf(gui)
	if not host or not WorldMapLayout.inHub(host.Position) then
		return
	end
	local kind = classify(gui, host)
	if not kind then
		return
	end
	local e = {
		gui = gui, host = host, kind = kind,
		baseSize = gui.Size,
		looks = captureLooks(gui),
		alpha = 1, want = true, shown = true, since = 0, scale = 1,
	}
	elems[gui] = e
	hosts[host] = hosts[host] or {}
	if kind == "icon" then
		hosts[host].icon = e
	else
		hosts[host].name = e
	end
	gui.AncestryChanged:Connect(function()
		if not gui:IsDescendantOf(Workspace) and not gui:IsDescendantOf(player.PlayerGui) then
			elems[gui] = nil
			local h = hosts[host]
			if h then
				if h.icon == e then
					h.icon = nil
				end
				if h.name == e then
					h.name = nil
				end
			end
		end
	end)
end

local function consider(d)
	if d:IsA("BillboardGui") then
		task.defer(register, d) -- 만드는 쪽이 글자 · 자식을 다 붙인 뒤
	end
end
for _, d in ipairs(Workspace:GetDescendants()) do
	consider(d)
end
Workspace.DescendantAdded:Connect(consider)

local function applyCaps()
	local touch = isTouchLayout()
	local cap = touch and L.phone.maxTextSize or L.maxTextSize
	for _, e in pairs(elems) do
		for _, d in ipairs(e.gui:GetDescendants()) do
			if d:IsA("UITextSizeConstraint") and d.Name == "HubLabelCap" then
				d.MaxTextSize = cap
			end
		end
	end
end

-- 거리 규칙: 이 요소가 보일 자격(겹침 전)
local function eligible(e, dist)
	if e.kind == "street" then
		return true
	end
	if dist >= L.farStuds then
		return false
	end
	if e.kind == "icon" or e.kind == "building" then
		return true
	end
	return dist < L.nearStuds -- 이름(기능 · NPC) = 가까이만
end

local function worldPos(e)
	return e.host.Position + e.gui.StudsOffsetWorldSpace
end

local function decide(now)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local from = root and root.Position or cam.Focus.Position
	local touch = isTouchLayout()
	local cands = {}
	for _, e in pairs(elems) do
		local dist = (worldPos(e) - from).Magnitude
		e.scale = (touch and L.phone.scale or 1) * ((e.kind == "street" and dist >= L.farStuds) and L.streetFarScale or 1)
		local ok = eligible(e, dist) and dist <= e.gui.MaxDistance
		local rect
		if ok then
			local sp, onScreen = cam:WorldToViewportPoint(worldPos(e))
			if onScreen and sp.Z > 0 then
				local w, h = e.baseSize.X.Offset * e.scale, e.baseSize.Y.Offset * e.scale
				rect = { sp.X - w / 2, sp.Y - h / 2, sp.X + w / 2, sp.Y + h / 2 }
			else
				ok = false
			end
		end
		e.next = ok
		if ok then
			local pr = L.priority[e.kind == "icon" and ((hosts[e.host] and hosts[e.host].name and hosts[e.host].name.kind) or "function") or e.kind]
			table.insert(cands, { e = e, rect = rect, pr = pr, dist = dist })
		end
	end
	table.sort(cands, function(a, b)
		if a.pr ~= b.pr then
			return a.pr < b.pr
		end
		return a.dist < b.dist
	end)
	local placed = {}
	local pad = L.overlapPadPx
	for _, c in ipairs(cands) do
		local r = c.rect
		local hit = false
		for _, q in ipairs(placed) do
			if q.host ~= c.e.host and r[1] < q.rect[3] + pad and q.rect[1] < r[3] + pad and r[2] < q.rect[4] + pad and q.rect[2] < r[4] + pad then
				hit = true -- 같은 자리의 이름 · 아이콘끼리는 겹침으로 안 본다(위아래로 붙어 있다)
				break
			end
		end
		if hit then
			c.e.next = false
		else
			table.insert(placed, { rect = r, host = c.e.host })
		end
	end
	-- 상태 유지(holdSeconds 동안 같은 판정이 이어져야 바꾼다)
	for _, e in pairs(elems) do
		if e.next ~= e.want then
			e.want = e.next
			e.since = now
		end
		if e.shown ~= e.want and now - e.since >= L.holdSeconds then
			e.shown = e.want
		end
		local s = e.scale
		e.gui.Size = UDim2.new(e.baseSize.X.Scale, e.baseSize.X.Offset * s, e.baseSize.Y.Scale, e.baseSize.Y.Offset * s)
	end
end

local function paint(e)
	local a = e.alpha
	e.gui.Enabled = a > 0.01
	for _, l in ipairs(e.looks) do
		l[1][l[2]] = l[3] + (1 - l[3]) * (1 - a)
	end
end

local first = true
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc >= 1 / L.updateHz or first then
		acc = 0
		decide(os.clock())
		if first then -- 처음 = 기다림 · 페이드 없이 바로
			first = false
			for _, e in pairs(elems) do
				e.shown = e.want
				e.alpha = e.shown and 1 or 0
				paint(e)
			end
		end
	end
	local step = dt / L.fadeSeconds
	for _, e in pairs(elems) do
		local target = e.shown and 1 or 0
		if e.alpha ~= target then
			e.alpha = target > e.alpha and math.min(target, e.alpha + step) or math.max(target, e.alpha - step)
			paint(e)
		end
	end
end)

applyCaps()
player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(applyCaps)
