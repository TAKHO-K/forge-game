-- QUEUE-ALL1 P3 §3 균열 시간(서버): 1초마다 시간표(RiftRules.stateAt - UTC · 모든 서버 동시)를 보고 Workspace 속성 RiftActive · RiftEndsAt · RiftNextAt을 맞추고,
--   DropTable.activeBoost(등급 배율 - 서버 굴림 · 이 VM의 확률 공개)를 켜고 끈다. 시작 · 끝 = 전원 배너(RiftBanner) - 모든 서버가 같은 시각에 스스로 보낸다(서버 간 통신 없음).
--   개발(Studio): Workspace 속성 RiftForce = true(강제 켬) | false(강제 끔) | nil(시간표) · /gg rift on|off|auto(DevTools).
--   골드 배율 = RiftService.goldMultiplier()(CombatResolution이 처치 골드에 곱한다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RiftData = require(ReplicatedStorage.Shared.data.RiftData)
local RiftRules = require(ReplicatedStorage.Shared.RiftRules)
local DropTable = require(ReplicatedStorage.Shared.DropTable)

local banner = Instance.new("RemoteEvent")
banner.Name = "RiftBanner" -- 서버 → 클라: { kind = "start" | "finish", endsAt }
banner.Parent = ReplicatedStorage

local wasActive = nil
local function tick()
	local now = os.time()
	local state = RiftRules.stateAt(now)
	local force = Workspace:GetAttribute("RiftForce")
	local active = state.active
	local endsAt = state.endsAt
	if force == true then
		active = true
		endsAt = Workspace:GetAttribute("RiftForceEndsAt") or (now + RiftData.durationSeconds)
		if not Workspace:GetAttribute("RiftForceEndsAt") then
			Workspace:SetAttribute("RiftForceEndsAt", endsAt)
		end
		if now >= endsAt then
			Workspace:SetAttribute("RiftForce", nil)
			Workspace:SetAttribute("RiftForceEndsAt", nil)
			active = false
		end
	elseif force == false then
		active = false
	end
	Workspace:SetAttribute("RiftActive", active)
	Workspace:SetAttribute("RiftEndsAt", active and endsAt or nil)
	Workspace:SetAttribute("RiftNextAt", state.nextStartsAt)
	DropTable.activeBoost = active and RiftData.gradeMultiplier or nil
	if wasActive ~= nil and active ~= wasActive then
		banner:FireAllClients({ kind = active and "start" or "finish", endsAt = endsAt })
		print(("[forge-game] 균열 %s(남은 %s초)"):format(active and "열림" or "닫힘", active and tostring(endsAt - now) or "-"))
	end
	wasActive = active
end

task.spawn(function()
	while true do
		local ok, err = pcall(tick)
		if not ok then
			warn("[RiftService] " .. tostring(err))
		end
		task.wait(1)
	end
end)
