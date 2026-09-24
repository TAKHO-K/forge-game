-- P3c A5 맵 이탈 방지 ③(마지막 겹): 보스전 멤버가 원 밖 · 바닥 아래로 나가면 옮긴다. 규칙 = BossArenaMapData.containment 주석.
-- P3d B: 옮기는 자리 = 본인의 보스방 스폰 자리(입장 자리 - 멤버 순번) · 체력 비율 · 기믹 누적은 그대로 · 직후 returnProtectSeconds 보호(받는 피해 0배 + 넉백 안 받음).
-- ①(넉백 상한) · ②(착지 경계)가 지키면 이 복귀는 한 번도 일어나지 않아야 한다 - 일어나면 "[forge-game] 위치 보정" 줄이 남고 corrections()에 쌓인다(검증이 0을 확인한다).
-- BossEncounter가 보스전 시작 · 끝에 track · untrack을 부른다(이 모듈은 BossEncounter를 모른다 - 순환 require 없음).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaContainment = require(ReplicatedStorage.Shared.ArenaContainment)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossArenaMap = require(script.Parent.BossArenaMap)
local GroundProbe = require(script.Parent.GroundProbe)
local PlayerState = require(script.Parent.PlayerState)

local BossArenaContainment = {}

local CONTAINMENT = BossArenaMapData.containment
local tracked = {} -- [encounter] = true
local corrections = {} -- { { player, zoneKey, reason, from, to, at, hpBefore, hpAfter, spawn } } - 검증 · 로그용
local protectedUntil = setmetatable({}, { __mode = "k" }) -- [Player] = os.clock 기준 보호 끝
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

-- P3d B2: 복귀 직후 보호 중인가(BossPatterns · BossArenaMap이 넉백을 건너뛴다).
function BossArenaContainment.isProtected(player)
	return (protectedUntil[player] or 0) > os.clock()
end
BossArenaMap.isLaunchProtected = BossArenaContainment.isProtected -- 구조물 파편 넉백(BossArenaMap은 이 모듈을 모른다 - 훅으로 건다)

-- P3d B1: 이 멤버의 스폰 자리(입장 자리 - BossEncounter가 입장 · 재도전 때 쓰는 것과 같은 순번). 구조물에 덮였으면 nil.
function BossArenaContainment.spawnPointFor(encounter, member)
	local members = encounter.members or {}
	local index = table.find(members, member) or 1
	local point = BossArenaMap.entryPosition(encounter.zoneKey, index, math.max(#members, 1))
	if BossArenaMap.overlapsObstacle(encounter.zoneKey, point, 1.5, 0.5) then
		return nil
	end
	return point
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
	local to = BossArenaContainment.spawnPointFor(encounter, member)
	local spawn = to ~= nil
	if not to then
		local point = ArenaContainment.rescuePoint(zone, root.Position, function(p)
			return BossArenaMap.overlapsObstacle(encounter.zoneKey, p, 1.5, 0.5)
		end)
		to = Vector3.new(point.X, (GroundProbe.surfaceY(point.X, point.Z, floorTopY) or floorTopY) + 3, point.Z)
	end
	local from = root.Position
	local hpBefore = PlayerState.getHp(member)
	character:PivotTo(CFrame.new(to))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	PlayerState.setIncomingDamageMultiplierUntil(member, 0, CONTAINMENT.returnProtectSeconds)
	protectedUntil[member] = os.clock() + CONTAINMENT.returnProtectSeconds
	local hpAfter = PlayerState.getHp(member)
	table.insert(corrections, { player = member, zoneKey = encounter.zoneKey, reason = reason, from = from, to = to, at = os.clock(), hpBefore = hpBefore, hpAfter = hpAfter, spawn = spawn })
	print(("[forge-game] 위치 보정(맵 이탈 복귀): %s - %s (%.1f, %.1f, %.1f) → %s (%.1f, %.1f, %.1f), 체력 %s 그대로 · 보호 %.2f초"):format(
		member.Name, reason, from.X, from.Y, from.Z, spawn and "스폰 자리" or "안전 지점(스폰 자리가 막힘)", to.X, to.Y, to.Z, tostring(hpAfter), CONTAINMENT.returnProtectSeconds))
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
