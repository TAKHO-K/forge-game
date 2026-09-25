-- BR1-2 음파 포효의 그림(서버 BossSonic이 보낸 사실만 - 판정 없음). 파티클 방출기 0(풀 파트 · 트윈 · BossFx).
--   sonicTelegraph  보스가 숨을 들이쉰다: 아레나 가장자리에서 보스 쪽으로 좁혀 오는 고리 3개 + 새 큰 얼음 기둥 자리의 흰 테
--   sonicTick       보스에서 퍼지는 큰 음파 고리(틱마다) · 엄폐물마다 금(검은 줄) + 흔들림 먼지 - 남은 내구가 적을수록 금이 많다 · 부서지면 파편
--                   내가 가려졌으면 머리 위 "가려짐! 0"(파랑), 맞았으면 붉은 번쩍임 - "숨으니 피해가 0이다"가 한눈에
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local BossFx = require(script.Parent.BossFx)

local BossSonicView = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local SAFE = Color3.fromRGB(120, 200, 255)
local DANGER = UIColors.danger

local live = {}

local function newPart(size, color, transparency)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0
	part.Parent = Workspace
	live[part] = true
	return part
end

local function destroy(part)
	if live[part] then
		live[part] = nil
		part:Destroy()
	end
end

-- 원통 고리(두께 thickness의 얇은 원판 가장자리처럼 보이게 - 조각 24개)
local function ringParts(center, radius, color, transparency, height)
	local parts = {}
	local n = 24
	for i = 1, n do
		local a = i / n * 2 * math.pi
		local seg = newPart(Vector3.new(radius * 2 * math.pi / n + 0.5, height or 3, 1.2), color, transparency)
		seg.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * radius, (height or 3) / 2, math.sin(a) * radius)) * CFrame.Angles(0, -a + math.pi / 2, 0)
		table.insert(parts, seg)
	end
	return parts
end

local function animateRing(center, fromRadius, toRadius, seconds, color, transparency, height)
	local steps = 12
	local parts = nil
	for i = 0, steps do
		task.delay(seconds * i / steps, function()
			if parts then
				for _, p in ipairs(parts) do
					destroy(p)
				end
			end
			local r = fromRadius + (toRadius - fromRadius) * (i / steps)
			parts = ringParts(center, math.max(r, 1), color, transparency + (1 - transparency) * (i / steps) * 0.6, height)
		end)
	end
	task.delay(seconds + 0.1, function()
		if parts then
			for _, p in ipairs(parts) do
				destroy(p)
			end
		end
	end)
end

local function floatText(text, color)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "SonicResult"
	gui.Size = UDim2.new(0, 160, 0, 44)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.7), { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	task.delay(0.75, function()
		gui:Destroy()
	end)
end

function BossSonicView.telegraph(data)
	for i = 1, 3 do
		task.delay((i - 1) * data.seconds / 3, function()
			animateRing(data.center, 120, 6, data.seconds / 3, SAFE, 0.5, 2)
		end)
	end
	for _, position in ipairs(data.pillars or {}) do
		BossFx.ring(position, 1, 7, WHITE, 0.6)
	end
end

function BossSonicView.tick(data)
	animateRing(data.center, 8, 150, 0.7, WHITE, 0.35, 4)
	BossFx.shake(data.center, 0.5)
	for _, cover in ipairs(data.eroded or {}) do
		local base = Vector3.new(cover.position.X, data.center.Y, cover.position.Z)
		if cover.broken then
			for _ = 1, 6 do
				BossFx.chunk(base + Vector3.new(0, 3, 0), Vector3.new(math.random(-12, 12), 14, math.random(-12, 12)), 0.9, Color3.fromRGB(190, 225, 255), 0.6)
			end
		else
			-- 금: 남은 내구가 적을수록 줄이 많다(1 ~ 5줄) · 흔들림 먼지
			local lines = math.clamp(math.floor((1 - cover.left) * 5 + 1), 1, 5)
			for k = 1, lines do
				local a = math.random() * 2 * math.pi
				local crack = newPart(Vector3.new(0.3, 2 + math.random() * 3, 0.3), Color3.fromRGB(30, 30, 40), 0.1)
				crack.Material = Enum.Material.SmoothPlastic
				crack.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * (cover.radius + 0.1), 1.5 + k * 0.8, math.sin(a) * (cover.radius + 0.1))) * CFrame.Angles(0, 0, math.rad(math.random(-40, 40)))
				task.delay(1.2, function()
					destroy(crack)
				end)
			end
			BossFx.puff(base + Vector3.new(0, 1, 0), cover.radius + 1, WHITE, 0.4, Vector3.new(0, 3, 0))
		end
	end
	local me = player.UserId
	for _, id in ipairs(data.shielded or {}) do
		if id == me then
			floatText("가려짐! 0", SAFE)
		end
	end
	for _, id in ipairs(data.hit or {}) do
		if id == me then
			floatText("음파!", DANGER)
		end
	end
end

function BossSonicView.reset()
	for part in pairs(live) do
		part:Destroy()
	end
	live = {}
end

return BossSonicView
