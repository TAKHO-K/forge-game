-- 플레이어 쪽 Y축 지형 규칙(22-4). 두 가지 + G2a 서버 높이 검증(HeightGuard.poll - 같은 폴링):
--   (1) 등반 한계 통일 - Humanoid.MaxSlopeAngle 기본값 89°(거의 수직도 오른다)를 몬스터와 같은
--       TerrainConfig.maxSlopeDegrees(45°)로 잠근다. 리스폰마다 Humanoid가 새로 생기므로
--       CharacterAdded마다 다시 건다(PlayerProfile의 WalkSpeed 재적용과 같은 이유). 그래야
--       "나는 오르는데 몬스터는 못 오는" 지형이 생기지 않는다(의도된 안전지대는 높이차 상한
--       8을 넘는 절벽으로만 만든다 - 경사로 만들지 않는다).
--   (2) 심연 복귀 - 루트가 TerrainConfig.voidReturnY(-24) 아래로 떨어지면 지금 서 있는(XZ) 구역의
--       입구로 되돌린다(20.49가 드래곤 돌길에 정한 "심연 바닥이 입구 패드로 텔레포트"의 일반화).
--       tier 구역 → 그 구역 entrance(복귀 패드 자리), 보스 아레나 → 아레나 입장점, 그 외(복도·
--       안전 구역·맵 밖) → 리스폰 중심. 피해·사망 없음 - 엔진의 FallenPartsDestroyHeight(-500)
--       사망보다 먼저 잡는다. 0.25초 폴링(TerrainConfig.voidCheckIntervalSeconds) - 낙하
--       속도(중력 196)로 -24까지 0.5초는 걸리므로 충분하다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local BossEncounter = require(script.Parent.BossEncounter)
local HeightGuard = require(script.Parent.HeightGuard) -- G2a: 서버 높이 검증(같은 0.25초 폴링)
local TeleportArrival = require(script.Parent.TeleportArrival)
local WorldHazards = require(script.Parent.WorldHazards) -- M1-3: 물살 속도 상한 · 선인장(같은 0.25초 폴링)
WorldHazards.start()

-- 바닥 윗면 관례(HuntingGround FLOOR_Y+FLOOR_THICKNESS/2 = 1) 위 3stud - 포탈 도착점·아레나
-- 입장점이 쓰는 것과 같은 여유.
local RETURN_HEIGHT_ABOVE_FLOOR_TOP = 3
local FLOOR_TOP_Y = 1

local function returnPositionFor(position)
	for _, zoneKey in ipairs(WorldConfig.zoneOrder) do
		local zone = WorldConfig.zones[zoneKey]
		if zone.role == "tier" and ZoneBounds.isInside(position, zoneKey) then
			return Vector3.new(zone.entrance.X, FLOOR_TOP_Y + RETURN_HEIGHT_ABOVE_FLOOR_TOP, zone.entrance.Z)
		end
	end
	for zoneKey, zone in pairs(WorldConfig.zones) do
		if zone.role == "bossArena" and ZoneBounds.isInside(position, zoneKey) then
			return BossEncounter.entryPositionFor(zone)
		end
	end
	local spawn = WorldConfig.zones.spawn.arrival -- M1: 허브 리스폰 자리(중심은 나무 줄기)
	return Vector3.new(spawn.X, FLOOR_TOP_Y + RETURN_HEIGHT_ABOVE_FLOOR_TOP, spawn.Z)
end

local function returnFromVoid(player, rootPart)
	local fellAt = rootPart.Position
	local destination = returnPositionFor(fellAt)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.CFrame = CFrame.new(destination)
	HeightGuard.reset(player)
	TeleportArrival.mark(player, destination) -- M1-2c 도착 대기
	print(("[forge-game] 심연 복귀: %s (%.0f, %.1f, %.0f) → %s"):format(player.Name, fellAt.X, fellAt.Y, fellAt.Z, tostring(destination)))
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.MaxSlopeAngle = TerrainConfig.maxSlopeDegrees
		HeightGuard.reset(player)
	end)
end)
Players.PlayerRemoving:Connect(HeightGuard.forget)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < TerrainConfig.voidCheckIntervalSeconds then
		return
	end
	elapsed = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart.Position.Y < TerrainConfig.voidReturnY then
			returnFromVoid(player, rootPart)
		end
		HeightGuard.poll(player, os.clock())
		WorldHazards.poll(player, os.clock())
	end
end)

print(("[forge-game] TerrainServer 로드됨 - 등반 한계 %d°, 심연 복귀선 y=%d"):format(
	TerrainConfig.maxSlopeDegrees, TerrainConfig.voidReturnY))
