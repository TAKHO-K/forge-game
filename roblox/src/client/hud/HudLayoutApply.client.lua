-- UI-1 7b단계 HUD 배치 적용(08 v7 §6): 저장된 배치(Attribute HudLayoutPc · HudLayoutPhone = "id:x,y;…" 기준 px)를 실제 HUD 프레임에 "기본 자리 + 옮긴 만큼"으로 더한다.
--   HUD 모듈을 고치지 않는다: 각 모듈이 Position을 정할 때마다(화면 크기 · 보스전 · 칩 줄 따라가기) 그 값 + 옮긴 만큼(기준 px × 배율 m)을 다시 얹는다.
--   요소 · 경로 = UiLayoutData.hudEdit.v7 · 규칙 = shared/HudEditRules · 편집 중 미리보기 = HudEdit가 Attribute HudLayoutPreview로 같은 길을 쓴다. 스위치 = UiV2Flags.map.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

if not require(ReplicatedStorage.Shared.data.UiV2Flags).map then
	return
end
local HudEditRules = require(ReplicatedStorage.Shared.HudEditRules)
local HudPlace = require(ReplicatedStorage.Shared.HudPlace)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local hooks = {} -- [GuiObject] = { base = UDim2, applied = UDim2, id }
local deltas = {} -- [id] = Vector2(기준 px)
local device, m = "pc", 1

local function current()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local phone = HudPlace.isPhone(v.X, v.Y, UserInputService.TouchEnabled, UserInputService.KeyboardEnabled) or player:GetAttribute("ForceTouchLayout") == true
		or ReplicatedStorage:GetAttribute("ForceTouchLayout") == true
	return phone and "phone" or "pc", HudPlace.scale(math.max(v.X, 1), math.max(v.Y, 1), phone)
end

local function offsetOf(id)
	local d = deltas[id]
	return d and UDim2.fromOffset(d.X * m, d.Y * m) or UDim2.new()
end

local function reapply(obj)
	local h = hooks[obj]
	if not h then
		return
	end
	h.applied = h.base + offsetOf(h.id)
	h.busy = true
	obj.Position = h.applied
	h.busy = false
end

local function hook(obj, id)
	if hooks[obj] then
		hooks[obj].id = id
		reapply(obj)
		return
	end
	local h = { base = obj.Position, id = id }
	hooks[obj] = h
	obj:GetPropertyChangedSignal("Position"):Connect(function()
		if h.busy or obj.Position == h.applied then
			return
		end
		h.base = obj.Position -- 모듈이 새로 정한 자리 = 새 기준
		reapply(obj)
	end)
	obj.Destroying:Connect(function()
		hooks[obj] = nil
	end)
	reapply(obj)
end

local function find(path)
	local node = playerGui
	for part in path:gmatch("[^/]+") do
		node = node and node:FindFirstChild(part)
	end
	return node
end

local function refresh()
	device, m = current()
	local value = player:GetAttribute("HudLayoutPreview") -- 편집 중 미리보기(HudEdit)
	if type(value) ~= "string" then
		value = player:GetAttribute(device == "phone" and "HudLayoutPhone" or "HudLayoutPc")
	end
	local pos = HudEditRules.parse(value)
	table.clear(deltas)
	for _, e in ipairs(HudEditRules.elements(device)) do
		local p = pos[e.id]
		if p then
			deltas[e.id] = Vector2.new(p[1] - e.rect[1], p[2] - e.rect[2])
		end
		for _, path in ipairs(e.paths) do
			local obj = find(path)
			if obj and obj:IsA("GuiObject") then
				hook(obj, e.id)
			end
		end
	end
	for obj in pairs(hooks) do
		reapply(obj)
	end
end

for _, name in ipairs({ "HudLayoutPc", "HudLayoutPhone", "HudLayoutPreview", "ForceTouchLayout" }) do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
local NAMES = {} -- 요소 프레임 이름(경로 끝) - 이 이름이 새로 생길 때만 다시 건다
for _, e in ipairs(require(ReplicatedStorage.Shared.data.UiLayoutData).hudEdit.v7.elements) do
	for _, list in pairs(e.paths) do
		for _, path in ipairs(list) do
			NAMES[path:match("([^/]+)$")] = true
		end
	end
end
playerGui.DescendantAdded:Connect(function(d) -- 늦게 지어지는 HUD(파티 목록 · 보스 바 · 폰 전투 묶음)
	if NAMES[d.Name] and d:IsA("GuiObject") then
		task.defer(refresh)
	end
end)
task.delay(3, refresh)
refresh()
