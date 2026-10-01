-- QUEUE-ALL1 ★0-2 나무 바람(클라 겉모습만): CollectionService "TreeSway"(server/TreeSkin이 단 들판 · 허브 나무 잎 메시) 중 카메라 radiusStuds 안의 가까운 maxParts개만
--   잎 밑동(경계 상자 아래 가운데) 기준으로 아주 작게 흔든다(degrees · periodSeconds). 폰(터치 전용) · 그래픽 품질 3 이하 = 끔(TreeArtData.wind.mobile).
--   서버 파트의 CFrame을 로컬에서만 바꾼다(복제 없음) · 멀어지면 원래 자리로 되돌린다.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local W = require(ReplicatedStorage.Shared.data.TreeArtData).wind
local GraphicsMode = require(script.Parent.GraphicsMode)

local function allowed()
	if GraphicsMode.isLite() then -- QUEUE-ALL6 A2: 그래픽 가벼움 = 바람 끔(폰 · 저사양 첫 접속 기본)
		return false
	end
	if not W.mobile and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and Players.LocalPlayer:GetAttribute("GraphicsMode") ~= "normal" then -- 폰이라도 "보통"을 직접 고르면 켬
		return false
	end
	local ok, level = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel.Value
	end)
	return not ok or level == 0 or level > 3 -- 0 = 자동
end

local origin = {} -- [part] = { cf, base(밑동 CFrame), phase }
local near = {}

local function info(part)
	local e = origin[part]
	if not e then
		local cf = part.CFrame
		local base = CFrame.new((cf * CFrame.new(0, -part.Size.Y / 2, 0)).Position)
		e = { cf = cf, rel = base:ToObjectSpace(cf), base = base, phase = (part.Position.X * 0.37 + part.Position.Z * 0.21) % (2 * math.pi) }
		origin[part] = e
	end
	return e
end

local function restore(part)
	local e = origin[part]
	if e and part.Parent then
		part.CFrame = e.cf
	end
end

CollectionService:GetInstanceRemovedSignal("TreeSway"):Connect(function(part)
	origin[part] = nil
	near[part] = nil
end)

-- 0.5초마다 가까운 목록 다시
local acc = 0
local enabled = allowed()
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.5 then
		return
	end
	acc = 0
	enabled = allowed()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cam = camera.CFrame.Position
	local list = {}
	if enabled then
		for _, part in ipairs(CollectionService:GetTagged("TreeSway")) do
			if part:IsA("BasePart") and part:IsDescendantOf(Workspace) then
				local d = (part.Position - cam).Magnitude
				if d <= W.radiusStuds then
					table.insert(list, { part = part, d = d })
				end
			end
		end
		table.sort(list, function(a, b)
			return a.d < b.d
		end)
	end
	local keep = {}
	for i = 1, math.min(#list, W.maxParts) do
		keep[list[i].part] = true
	end
	for part in pairs(near) do
		if not keep[part] then
			restore(part)
		end
	end
	near = keep
end)

RunService.RenderStepped:Connect(function()
	if not enabled then
		return
	end
	local t = os.clock()
	local w = 2 * math.pi / W.periodSeconds
	local k = math.rad(W.degrees)
	for part in pairs(near) do
		local e = info(part)
		local a = math.sin(t * w + e.phase) * k
		local b = math.cos(t * w * 0.7 + e.phase) * k * 0.6
		part.CFrame = e.base * CFrame.Angles(a, 0, b) * e.rel
	end
end)
