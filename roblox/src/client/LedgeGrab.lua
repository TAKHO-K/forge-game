-- MV1 태초 장갑 = 붙잡기(사용자 수정 - 딜 · 공격 횟수 · 공속 영향 0). 수치 = MovementConfig.ledgeGrab.
--   공중(떨어지는 중 · 느리게 오르는 중)에 앞 벽 · 절벽 모서리가 손 높이 안에 있으면 매달린다 → 점프(DoubleJumpInput)로 올라선다 · hangMaxSeconds 뒤 저절로 놓는다.
--   한 체공 1회(착지하면 다시 찬다 - 캐릭터 Attribute "LedgeUsed"). 매달리는 순간 서버에 LedgeClimb(모서리 윗면 · 벽 방향)를 보낸다 → 서버가 광선으로 다시 확인하고 HeightGuard 허가를 준다(올라서기 = 합법 동작).
--   매달림 · 오르기 동안 루트는 고정하지 않고(Anchored는 복제가 끊긴다) 매 물리 스텝 자리 · 속도를 덮어쓴다. 활강 중 · 넉백 잠금 · 잡힘에는 안 잡는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local LedgeGrab = {}

local L = MovementConfig.ledgeGrab
local ROOT_ABOVE_FEET = MovementConfig.rootAboveFeetStuds
local player = Players.LocalPlayer
local ledgeClimb = ReplicatedStorage:WaitForChild("LedgeClimb")

local hang = nil -- { cf(루트 자리), top(올라설 발 자리), since } | 오르는 중 { climbFrom, climbTo, climbAt }
local AIR = { [Enum.HumanoidStateType.Jumping] = true, [Enum.HumanoidStateType.Freefall] = true }
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function hasGloves()
	local parts = player:GetAttribute("PrimordialParts")
	return type(parts) == "string" and parts:find("gloves", 1, true) ~= nil
end

function LedgeGrab.isHanging()
	return hang ~= nil and hang.climbAt == nil
end

-- 앞 모서리 찾기(순수에 가까운 광선 계산 - 반환: 모서리 윗면 Y, 벽 법선(수평), 벽 맞은 점) 또는 nil.
local function findLedge(character, root, forward)
	params.FilterDescendantsInstances = { character }
	local feetY = root.Position.Y - ROOT_ABOVE_FEET
	-- 가슴 아래 높이(발 + 1.5)에서 앞으로 벽을 찾는다
	local wall = Workspace:Raycast(Vector3.new(root.Position.X, feetY + 1.5, root.Position.Z), forward * (L.reachStuds + 1), params)
	if not wall or math.abs(wall.Normal.Y) > 0.35 then
		return nil
	end
	local normal = Vector3.new(wall.Normal.X, 0, wall.Normal.Z).Unit
	-- 벽 안쪽 0.6에서 손 높이 위부터 아래로 윗면을 찾는다
	local from = wall.Position - normal * 0.6 + Vector3.new(0, feetY + L.maxLedgeAboveFeet + 0.5 - wall.Position.Y, 0)
	local top = Workspace:Raycast(from, Vector3.new(0, -(L.maxLedgeAboveFeet - L.minLedgeAboveFeet + 1), 0), params)
	if not top or top.Normal.Y < 0.7 then
		return nil
	end
	local above = top.Position.Y - feetY
	if above < L.minLedgeAboveFeet or above > L.maxLedgeAboveFeet then
		return nil
	end
	-- 올라설 자리 위가 비었는가
	if Workspace:Raycast(top.Position + Vector3.new(0, 0.1, 0) - normal * (L.climbInStuds - 0.6), Vector3.new(0, L.standClearStuds, 0), params) then
		return nil
	end
	return top.Position.Y, normal, wall.Position
end

local function startHang(character, root, ledgeY, normal, wallPoint)
	local facing = -normal
	local pos = Vector3.new(wallPoint.X, ledgeY - L.hangBelowStuds, wallPoint.Z) + normal * 1.1
	hang = {
		cf = CFrame.lookAt(pos, pos + facing),
		top = Vector3.new(wallPoint.X, ledgeY, wallPoint.Z) + facing * L.climbInStuds,
		since = os.clock(),
	}
	character:SetAttribute("LedgeUsed", true)
	character:SetAttribute("LedgeHanging", true)
	ledgeClimb:FireServer(Vector3.new(wallPoint.X, ledgeY, wallPoint.Z) + facing * 0.6, facing) -- 모서리 윗점(벽 안쪽 0.6 - 서버가 그 점 위에서 다시 잰다)
end

local function endHang(character)
	hang = nil
	if character then
		character:SetAttribute("LedgeHanging", nil)
	end
end

function LedgeGrab.climb()
	if not LedgeGrab.isHanging() then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	hang.climbFrom = hang.cf
	hang.climbTo = CFrame.lookAt(hang.top + Vector3.new(0, ROOT_ABOVE_FEET, 0), hang.top + Vector3.new(0, ROOT_ABOVE_FEET, 0) + hang.cf.LookVector)
	hang.climbAt = os.clock()
	return true
end

RunService.Stepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		if hang then
			endHang(character)
		end
		return
	end
	if hang then
		if hang.climbAt then
			local t = math.clamp((os.clock() - hang.climbAt) / L.climbSeconds, 0, 1)
			root.CFrame = hang.climbFrom:Lerp(hang.climbTo, t)
			root.AssemblyLinearVelocity = Vector3.zero
			if t >= 1 then
				character:SetAttribute("MV1LedgeClimbs", (character:GetAttribute("MV1LedgeClimbs") or 0) + 1) -- 계측(검증)
				endHang(character)
			end
		elseif os.clock() - hang.since > L.hangMaxSeconds or humanoid.PlatformStand or player:GetAttribute("BossTrapKind") then
			endHang(character) -- 놓는다 → 그대로 떨어진다
		else
			root.CFrame = hang.cf
			root.AssemblyLinearVelocity = Vector3.zero
		end
		return
	end
	if not AIR[humanoid:GetState()] then
		if character:GetAttribute("LedgeUsed") and humanoid.FloorMaterial ~= Enum.Material.Air then
			character:SetAttribute("LedgeUsed", nil) -- 착지 = 다시 충전
		end
		return
	end
	if not hasGloves() or character:GetAttribute("LedgeUsed") or character:GetAttribute("Gliding") or character:GetAttribute("AirLocked") or humanoid.PlatformStand or root.Anchored then
		return
	end
	if require(script.Parent.GlideController).isGliding() then
		return
	end
	if root.AssemblyLinearVelocity.Y > L.maxRiseSpeed then
		return
	end
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 1e-3 then
		return
	end
	local ledgeY, normal, wallPoint = findLedge(character, root, forward.Unit)
	if ledgeY then
		startHang(character, root, ledgeY, normal, wallPoint)
	end
end)

player.CharacterAdded:Connect(function()
	hang = nil
end)

return LedgeGrab
