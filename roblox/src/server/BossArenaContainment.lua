-- P3c A5 맵 이탈 방지 ③(마지막 겹): 보스전 멤버가 원 밖 · 바닥 아래로 나가면 피해 없이 안쪽 안전 지점으로 옮긴다. 규칙 = BossArenaMapData.containment 주석.
-- ①(넉백 상한) · ②(착지 경계)가 지키면 이 복귀는 한 번도 일어나지 않아야 한다 - 일어나면 "[forge-game] 위치 보정" 줄이 남고 corrections()에 쌓인다(검증이 0을 확인한다).
-- BossEncounter가 보스전 시작 · 끝에 track · untrack을 부른다(이 모듈은 BossEncounter를 모른다 - 순환 require 없음).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaContainment = require(ReplicatedStorage.Shared.ArenaContainment)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossArenaMap = require(script.Parent.BossArenaMap)
local GroundProbe = require(script.Parent.GroundProbe)

local BossArenaContainment = {}

local CONTAINMENT = BossArenaMapData.containment
local tracked = {} -- [encounter] = true
local corrections = {} -- { { player, zoneKey, reason, from, to, at } } - 검증 · 로그용
local elapsed = 0

function BossArenaContainment.track(encounter)
	tracked[encounter] = true
end

function BossArenaContainment.untrack(encounter)
	tracked[encounter] = nil
end

function BossArenaContainment.corrections()
	return corrections
end

-- 한 멤버를 검사하고 필요하면 옮긴다. 반환: 옮겼는가.
function BossArenaContainment.checkMember(encounter, member)
	local zone = WorldConfig.zones[encounter.zoneKey or ""]
	local character = typeof(member) == "Instance" and member.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not zone or not zone.radius or not root or root.Anchored then
		return false
	end
	local floorTopY = BossArenaMap.floorTopY()
	local outside, reason = ArenaContainment.isOutside(zone, root.Position, floorTopY)
	if not outside then
		return false
	end
	local point = ArenaContainment.rescuePoint(zone, root.Position, function(p)
		return BossArenaMap.overlapsObstacle(encounter.zoneKey, p, 1.5, 0.5)
	end)
	local groundY = GroundProbe.surfaceY(point.X, point.Z, floorTopY) or floorTopY
	local to = Vector3.new(point.X, groundY + 3, point.Z)
	local from = root.Position
	character:PivotTo(CFrame.new(to))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	table.insert(corrections, { player = member, zoneKey = encounter.zoneKey, reason = reason, from = from, to = to, at = os.clock() })
	print(("[forge-game] 위치 보정(맵 이탈 방지): %s - %s (%.1f, %.1f, %.1f) → (%.1f, %.1f, %.1f), 피해 없음"):format(
		member.Name, reason, from.X, from.Y, from.Z, to.X, to.Y, to.Z))
	return true
end

RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < CONTAINMENT.checkIntervalSeconds then
		return
	end
	elapsed = 0
	for encounter in pairs(tracked) do
		for _, member in ipairs(encounter.members or {}) do
			BossArenaContainment.checkMember(encounter, member)
		end
	end
end)

return BossArenaContainment
