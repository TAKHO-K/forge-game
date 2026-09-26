-- MV1 원거리 공중 정지(사용자 - 프레야식): 활 · 지팡이가 공중에서 쏠 때 짧게(AttackMotionData[직업].air.hoverSeconds) 그 자리에 멈춘다 - 공중 공격 횟수 안에서만(AttackInput이 부른다).
--   물리 = 루트에 속도 0 LinearVelocity(활강과 같은 방식) · 높이를 올리지 않는다(서버 높이 검증과 무관 - 체공만 늘린다: S1 합법 이동 목록 MoveRules.s1Limits().rangedHover).
--   활강 중 · 매달림 중 · 넉백 잠금이면 안 멈춘다. 대공 잡기는 이 정지도 체공으로 센다(보고서).
local Players = game:GetService("Players")

local AirHover = {}
local player = Players.LocalPlayer
local token = 0

function AirHover.hold(seconds)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not seconds or seconds <= 0 or character:GetAttribute("Gliding") or character:GetAttribute("LedgeHanging") or character:GetAttribute("AirLocked") then
		return false
	end
	token += 1
	local mine = token
	local old = root:FindFirstChild("MV1HoverVelocity")
	if old then
		old:Destroy()
	end
	local attach = root:FindFirstChild("MV1HoverAttach") or Instance.new("Attachment")
	attach.Name = "MV1HoverAttach"
	attach.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "MV1HoverVelocity"
	lv.Attachment0 = attach
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root
	root.AssemblyLinearVelocity = Vector3.zero
	character:SetAttribute("MV1Hovering", true)
	task.delay(seconds, function()
		lv:Destroy()
		if mine == token then
			character:SetAttribute("MV1Hovering", nil)
			character:SetAttribute("MV1HoverCount", (character:GetAttribute("MV1HoverCount") or 0) + 1) -- 계측(검증)
		end
	end)
	return true
end

return AirHover
