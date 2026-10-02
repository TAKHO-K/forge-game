-- QUEUE-ALL7B 3 허브 NPC 대기 동작(클라 · 겉모습만): Workspace.HubArt.HubNpc_<id>(server/HubArt) 메시 조각을 HubArtData motion대로 관절(HubArtMeta pivots) 둘레로 돌린다.
--   가까운(motionRadius) NPC만 · 조각 처음 자리 = 모델 WorldPivot 기준으로 한 번 잰다(스트리밍으로 다시 들어오면 다시 잰다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HubArtData = require(ReplicatedStorage.Shared.data.HubArtData)
local HubArtMeta = require(ReplicatedStorage.Shared.data.HubArtMeta)

local player = Players.LocalPlayer
local byId = {}
for _, n in ipairs(HubArtData.npcs) do
	byId[n.id] = n
end

local tracked = {} -- [Model] = { frame, motions = { { parts = { { part, local } }, pivot, axis, offset, amp, period } } }

local function track(model)
	local entry = byId[model:GetAttribute("HubNpc")]
	local meta = entry and HubArtMeta[(entry.model:gsub("^props/", ""))]
	if not meta or tracked[model] then
		return
	end
	local frame = model.WorldPivot
	local motions = {}
	for _, m in ipairs(entry.motion) do
		local list = {}
		for _, name in ipairs(m.parts) do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				table.insert(list, { part = part, ["local"] = frame:ToObjectSpace(part.CFrame) })
			end
		end
		if #list == 0 then -- 조각이 아직 안 들어옴(스트리밍) → 들어오면 다시
			return
		end
		local pv = meta.pivots[m.pivot]
		table.insert(motions, { parts = list, pivot = CFrame.new(pv[1], pv[2], pv[3]), axis = m.axis, offset = m.offset, amp = m.amp, period = m.period })
	end
	tracked[model] = { frame = frame, motions = motions }
end

local function consider(inst)
	if inst:IsA("Model") and inst:GetAttribute("HubNpc") then
		task.defer(track, inst) -- 조각이 다 들어온 뒤
		inst.ChildAdded:Connect(function()
			task.defer(track, inst)
		end)
	end
end
local function watchFolder(folder)
	for _, c in ipairs(folder:GetChildren()) do
		consider(c)
	end
	folder.ChildAdded:Connect(consider)
	folder.ChildRemoved:Connect(function(c)
		tracked[c] = nil
	end)
end
local folder = Workspace:FindFirstChild(HubArtData.folder)
if folder then
	watchFolder(folder)
end
Workspace.ChildAdded:Connect(function(c)
	if c.Name == HubArtData.folder then
		watchFolder(c)
	end
end)

local function angles(axis, deg)
	local r = math.rad(deg)
	if axis == "X" then
		return CFrame.Angles(r, 0, 0)
	elseif axis == "Y" then
		return CFrame.Angles(0, r, 0)
	end
	return CFrame.Angles(0, 0, r)
end

RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not next(tracked) then
		return
	end
	local t = os.clock()
	for model, s in pairs(tracked) do
		if model.Parent and (s.frame.Position - root.Position).Magnitude <= HubArtData.motionRadius then
			for _, m in ipairs(s.motions) do
				local rot = m.pivot * angles(m.axis, m.offset + m.amp * math.sin(2 * math.pi * t / m.period)) * m.pivot:Inverse()
				for _, p in ipairs(m.parts) do
					p.part.CFrame = s.frame * rot * p["local"]
				end
			end
		end
	end
end)
