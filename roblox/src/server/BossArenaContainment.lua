-- P3c A5 맵 이탈 방지 ③(마지막 겹): 보스전 멤버가 원 밖 · 바닥 아래로 나가거나 벽 윗면에 1초 넘게 머물면(G1-0) 옮긴다. 규칙 = BossArenaMapData.containment 주석.
-- P3d B: 옮기는 자리 = 본인의 보스방 스폰 자리(입장 자리 - 멤버 순번) · 체력 비율 · 기믹 누적은 그대로 · 직후 returnProtectSeconds 보호(받는 피해 0배 + 넉백 안 받음).
-- ①(넉백 상한) · ②(착지 경계)가 지키면 이 복귀는 한 번도 일어나지 않아야 한다 - 일어나면 "[forge-game] 위치 보정" 줄이 남고 corrections()에 쌓인다(검증이 0을 확인한다).
-- BossEncounter가 보스전 시작 · 끝에 track · untrack을 부른다(이 모듈은 BossEncounter를 모른다 - 순환 require 없음).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaContainment = require(ReplicatedStorage.Shared.ArenaContainment)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossArenaMap = require(script.Parent.BossArenaMap)
local BossArenaProps = require(script.Parent.BossArenaProps)
local GroundProbe = require(script.Parent.GroundProbe)
local PlayerState = require(script.Parent.PlayerState)
local HeightGuard = require(script.Parent.HeightGuard) -- G2a: 복귀 순간이동 뒤 높이 기준 새로

local BossArenaContainment = {}

local CONTAINMENT = BossArenaMapData.containment
local tracked = {} -- [encounter] = true
local corrections = {} -- { { player, zoneKey, reason, from, to, at, hpBefore, hpAfter, spawn } } - 검증 · 로그용
local protectedUntil = setmetatable({}, { __mode = "k" }) -- [Player] = os.clock 기준 보호 끝
local offFloorSince = setmetatable({}, { __mode = "k" }) -- G1-0: [Player] = 벽 윗면 높이에 처음 선 시각(os.clock)
local GEOMETRY = BossArenaMapData.geometry
local elapsed = 0

function BossArenaContainment.track(encounter)
	tracked[encounter] = true
end

function BossArenaContainment.untrack(encounter)
	tracked[encounter] = nil
	for _, member in ipairs(encounter.members or {}) do
		offFloorSince[member] = nil -- 리뷰 7
	end
end

function BossArenaContainment.corrections()
	return corrections
end

-- P3d B2: 복귀 직후 보호 중인가(BossPatterns · BossArenaMap이 넉백을 건너뛴다).
function BossArenaContainment.isProtected(player)
	return (protectedUntil[player] or 0) > os.clock()
end
BossArenaMap.isLaunchProtected = BossArenaContainment.isProtected -- 구조물 파편 넉백(BossArenaMap은 이 모듈을 모른다 - 훅으로 건다)

-- G1-0: 그 자리 둘레에 동적 지형(얼음 기둥 · 모래 구덩이)이 있는가.
local function propNear(encounter, point)
	for _, prop in ipairs(encounter.model and BossArenaProps.list(encounter.model) or {}) do
		local dx, dz = point.X - prop.position.X, point.Z - prop.position.Z
		if math.sqrt(dx * dx + dz * dz) < (prop.radius or 0) + CONTAINMENT.spawnPropClearStuds then
			return true
		end
	end
	return false
end

-- P3d B1: 이 멤버의 스폰 자리(입장 자리 - BossEncounter가 입장 · 재도전 때 쓰는 것과 같은 순번). 구조물에 덮였으면 nil.
function BossArenaContainment.spawnPointFor(encounter, member)
	local members = encounter.members or {}
	local index = table.find(members, member) or 1
	local point = BossArenaMap.entryPosition(encounter.zoneKey, index, math.max(#members, 1))
	if BossArenaMap.overlapsObstacle(encounter.zoneKey, point, 1.5, 0.5) then
		return nil
	end
	-- G1-0: 동적 지형(얼음 기둥 · 모래 구덩이)이 스폰 자리를 덮었어도 안전 지점으로(끼임 0)
	if propNear(encounter, point) then
		return nil
	end
	-- 리뷰 10: 그 자리 지면 위(둔덕 가장자리에 걸린 순번이면 둔덕 윗면 위)로 올린다
	local floorTopY = BossArenaMap.floorTopY()
	local groundY = GroundProbe.surfaceY(point.X, point.Z, floorTopY) or floorTopY
	return Vector3.new(point.X, groundY + 3, point.Z)
end

-- 한 멤버를 검사하고 필요하면 옮긴다. 반환: 옮겼는가.
function BossArenaContainment.checkMember(encounter, member)
	local zone = WorldConfig.zones[encounter.zoneKey or ""]
	local character = typeof(member) == "Instance" and member.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not zone or not zone.radius or not root or root.Anchored then
		offFloorSince[member] = nil -- 리뷰 7: 고정(잡힘 · 끼임) · 캐릭터 없음 동안은 시간을 새로 잰다
		return false
	end
	local floorTopY = BossArenaMap.floorTopY()
	local outside, reason = ArenaContainment.isOutside(zone, root.Position, floorTopY)
	-- G1-0: 벽 윗면 높이에 offFloorReturnSeconds 넘게 머물면(벽 위에 착지) 바닥 위가 아닌 것으로 보고 복귀
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local standing = (humanoid and humanoid.HipHeight or 2) + root.Size.Y / 2
	-- 리뷰 1: 회오리 체공(무적 출처 launchHold) 중에는 붙잡힌 높이라 벽 위가 아니다 - 끝난 뒤부터 잰다
	local lifted = PlayerState.debugIncomingSources(member).launchHold ~= nil
	if not lifted and ArenaContainment.isOffFloorHeight(root.Position.Y - standing, floorTopY, GEOMETRY.wallHeightStuds) then
		offFloorSince[member] = offFloorSince[member] or os.clock()
		if not outside and os.clock() - offFloorSince[member] >= CONTAINMENT.offFloorReturnSeconds then
			outside, reason = true, "offFloor"
		end
	else
		offFloorSince[member] = nil
	end
	if not outside then
		return false
	end
	offFloorSince[member] = nil
	local to = BossArenaContainment.spawnPointFor(encounter, member)
	local spawn = to ~= nil
	if not to then
		local point = ArenaContainment.rescuePoint(zone, root.Position, function(p)
			return BossArenaMap.overlapsObstacle(encounter.zoneKey, p, 1.5, 0.5) or propNear(encounter, p) -- 리뷰 6: 대체 자리도 동적 지형 피함
		end)
		to = Vector3.new(point.X, (GroundProbe.surfaceY(point.X, point.Z, floorTopY) or floorTopY) + 3, point.Z)
	end
	local from = root.Position
	local hpBefore = PlayerState.getHp(member)
	character:PivotTo(CFrame.new(to))
	HeightGuard.reset(member)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	PlayerState.setInvulnerableUntil(member, CONTAINMENT.returnProtectSeconds, "returnProtect") -- P3d-F B6: 무적은 별도 플래그(회전베기 등 다른 출처의 배율을 덮지 않는다)
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
