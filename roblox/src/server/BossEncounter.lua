-- 플레이어별 보스 인스턴스 스폰·퇴장 단일 관리 통로(15-1, 20-2b에서 아레나 격리로 개정).
-- 사냥터가 스테이지 무관 공용 공간 하나뿐이라(HuntingGround.server.lua - 격자 9자리 고정),
-- 보스는 그 안에 상주하는 대신 "이 플레이어가 지금 보스 스테이지에 있다"는 사실에 맞춰
-- 그 플레이어 전용 인스턴스로 스폰한다 - 여러 플레이어가 서로 다른 스테이지에 있어도
-- 서로의 보스를 방해하지 않는다.
--
-- 20-2b 개정 이유: "맵 중앙에 보스가 스폰된다"는 버그 - 옛 spawnPositionFor는 "플레이어
-- 20stud 앞"을 계산했는데, 접속 시 복원(StageServer.server.lua PlayerAdded)이 캐릭터가
-- 막 스폰된 직후 위치(=사실상 리스폰 구역, 맵 원점)를 기준으로 이 함수를 불렀다. 게다가
-- 보스에게 zoneKey가 없어(MonsterState.getZoneKey가 nil) 구역 경계 리쉬 자체가 안 걸리고
-- "자기 스폰 지점에서 38.4stud"라는 거리 리쉬만 봤다 - 죽어서 리스폰해도 로블록스 기본
-- 스폰 지점이 그 근처라 계속 다시 얻어맞는 죽음 루프까지 생겼다. 해결책: 슈퍼그리드와
-- 완전히 분리된 먼 아레나(WorldConfig.zones.bossArenaN, 인원수만큼 슬롯)로 플레이어를
-- 순간이동시키고, 보스에게 그 아레나의 zoneKey를 실제로 준다 - MonsterAI.server.lua의
-- 기존 구역 리쉬(16-6)를 그대로 재사용해 "아레나를 벗어나면 포기하고 돌아간다"가 자동
-- 성립한다(이 파일은 새 리쉬 로직을 만들지 않는다).
--
-- 사용자 지시: 보스전 중 죽어도 그 아레나로 다시 스폰된다(아래 CharacterAdded 훅) -
-- 스테이지를 실제로 옮길 때만(StageServer.server.lua가 despawnFor를 부를 때) 사냥터로
-- 돌아간다.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local BossPatterns = require(script.Parent.BossPatterns)
local GroundProbe = require(script.Parent.GroundProbe)

local BossEncounter = {}

-- [Player] = Model. 죽여서 없어진 경우(CombatResolution이 clearFor를 부른다)와 스테이지를
-- 벗어나 물러난 경우(despawnFor) 둘 다 여기서 지운다 - 어느 쪽이든 "지금 이 플레이어의
-- 활성 보스"는 이 테이블 하나로만 판단한다.
local activeBosses = {}

-- [Player] = 1..slotCount. 아레나 슬롯 배정 - 반납되면 freeSlots로 돌아가 다음 사람이 쓴다.
local slotByPlayer = {}
local freeSlots = {}
for i = WorldConfig.bossArena.slotCount, 1, -1 do
	table.insert(freeSlots, i)
end

-- 슬롯당 한 번만 짓는다(zoneKey -> true). 서버가 켜져 있는 동안 아레나는 파괴하지 않는다 -
-- 몬스터 격자(HuntingGround)처럼 상시 존재하는 고정 지형으로 취급한다.
local builtArenas = {}

local ARENA_WALL_COLOR = Color3.fromRGB(40, 20, 20) -- 사냥터 담장(70,65,60)보다 어둡게 - "다른 곳"이라는 신호.
local ARENA_FLOOR_COLOR = Color3.fromRGB(30, 15, 15)
-- HuntingGround.server.lua의 FLOOR_THICKNESS(=2)·FLOOR_Y(=0, 바닥 "중심" 기준)와 같은
-- 관례를 그대로 쓴다 - 바닥 윗면은 항상 FLOOR_Y+FLOOR_THICKNESS/2 = 1이다. 두 시스템이
-- 같은 기준을 안 쓰면 나중에 유지보수할 때 "이 파일의 Y는 왜 다른가"를 매번 되짚어야 한다.
local ARENA_FLOOR_THICKNESS_STUDS = 2
local ARENA_FLOOR_TOP_Y = ARENA_FLOOR_THICKNESS_STUDS / 2 -- 1

local function zoneKeyForSlot(slot)
	return "bossArena" .. slot
end

local function buildArena(zoneKey)
	if builtArenas[zoneKey] then
		return
	end
	builtArenas[zoneKey] = true

	local zone = WorldConfig.zones[zoneKey]
	local half = zone.halfSize
	local wallsCfg = WorldConfig.walls
	local thickness = wallsCfg.thicknessStuds

	local floor = Instance.new("Part")
	floor.Name = "BossArenaFloor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.Slate
	floor.Color = ARENA_FLOOR_COLOR
	floor.Size = Vector3.new(half * 2, ARENA_FLOOR_THICKNESS_STUDS, half * 2)
	floor.Position = Vector3.new(zone.center.X, 0, zone.center.Z)
	floor.Parent = GroundProbe.folder() -- 22-4: 지면 폴더(보스 지면 추적·돌진 Y·드랍 스냅의 대상)

	local wallY = ARENA_FLOOR_TOP_Y + wallsCfg.heightStuds / 2
	local function wall(sizeX, sizeZ, offsetX, offsetZ)
		local part = Instance.new("Part")
		part.Name = "BossArenaWall"
		part.Anchored = true
		part.CanCollide = true
		part.Material = Enum.Material.Slate
		part.Color = ARENA_WALL_COLOR
		part.Size = Vector3.new(sizeX, wallsCfg.heightStuds, sizeZ)
		part.Position = zone.center + Vector3.new(offsetX, wallY, offsetZ)
		part.Parent = Workspace
	end

	-- 4면 전부 막는다 - 문이 없다(텔레포트 전용 입장이라 걸어 들어올 필요가 없다).
	wall(thickness, half * 2 + thickness * 2, half + thickness / 2, 0)
	wall(thickness, half * 2 + thickness * 2, -half - thickness / 2, 0)
	wall(half * 2 + thickness * 2, thickness, 0, half + thickness / 2)
	wall(half * 2 + thickness * 2, thickness, 0, -half - thickness / 2)
end

local function allocateSlot(player)
	local existing = slotByPlayer[player]
	if existing then
		return existing
	end
	-- 서버 정원(12명)을 넘는 동시 보스전은 설계상 안 생겨야 하지만(PRD 20.38 [6]), 혹시
	-- freeSlots가 바닥나면 1번을 같이 쓴다 - 아레나가 겹쳐 불편할 뿐 에러는 나지 않는다.
	local slot = table.remove(freeSlots) or 1
	slotByPlayer[player] = slot
	return slot
end

local function releaseSlot(player)
	local slot = slotByPlayer[player]
	if not slot then
		return
	end
	slotByPlayer[player] = nil
	table.insert(freeSlots, slot)
end

-- 아레나 안쪽, 벽에서 10stud 떨어진 가장자리 - 보스(중앙 스폰)를 바로 마주보게 한다.
-- Y는 바닥 윗면(ARENA_FLOOR_TOP_Y) + 3 - HuntingGround.server.lua가 플레이어 관련
-- 텔레포트 지점에 쓰는 것과 같은 여유(예: 포탈 도착점 FLOOR_Y+FLOOR_THICKNESS/2+3).
local function arenaEntryPosition(zone)
	return zone.center + Vector3.new(0, ARENA_FLOOR_TOP_Y + 3, zone.halfSize - 10)
end
BossEncounter.entryPositionFor = arenaEntryPosition -- 22-4: 심연 복귀(TerrainServer)가 같은 입장점을 쓴다

local function teleportTo(player, position)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = CFrame.new(position, position + Vector3.new(0, 0, -1))
	end
end

-- targetStage가 보스 스테이지이고 아직 이 플레이어의 보스가 없으면 스폰한다. 이미
-- 있으면(예: 같은 스테이지 안에서 위/아래로 왔다 갔다) 아무것도 안 한다 - 중복 스폰 방지.
function BossEncounter.spawnFor(player, stage)
	if not BossRules.isBossStage(stage) then
		return
	end
	if activeBosses[player] then
		return
	end

	local data = BossRules.buildInstanceData(stage)
	if not data then
		return
	end

	local slot = allocateSlot(player)
	local zoneKey = zoneKeyForSlot(slot)
	buildArena(zoneKey)
	local zone = WorldConfig.zones[zoneKey]

	teleportTo(player, arenaEntryPosition(zone))

	-- Y는 바닥 윗면(ARENA_FLOOR_TOP_Y) + 1.5 - HuntingGround.server.lua의 tier 몬스터
	-- 스폰 높이(FLOOR_Y+FLOOR_THICKNESS/2+1.5)와 같은 관례.
	local spawnPosition = zone.center + Vector3.new(0, ARENA_FLOOR_TOP_Y + 1.5, 0)
	local model = MonsterSpawner.spawn(data, spawnPosition, zoneKey)
	activeBosses[player] = model
	BossPatterns.setGrace(model, data, data.entryGraceSeconds) -- 입장 2초 유예(20.44 [3](다))
	print(("[forge-game] 보스 등장: %s - 스테이지 %d, 대상 %s (아레나 %s)"):format(
		data.displayName, stage, player.Name, zoneKey))
end

-- 처치되지 않은 채로 물러날 때(스테이지 하향/상향 이동, 퇴장)만 부른다 - 처치는
-- CombatResolution.lua가 MonsterSpawner.despawn(죽음 연출 포함)을 직접 호출한 뒤
-- clearFor로 이 테이블만 지운다. 스테이지를 실제로 옮기는 것이므로 사냥터로 돌려보낸다.
function BossEncounter.despawnFor(player)
	local model = activeBosses[player]
	if not model then
		return
	end
	activeBosses[player] = nil
	MonsterState.clear(model)
	model:Destroy()
	teleportTo(player, WorldConfig.huntingGround.center + Vector3.new(0, 5, 0))
end

-- CombatResolution.lua가 보스를 죽인 직후 부른다 - 인스턴스 자체는 MonsterSpawner.despawn이
-- 이미(사체 유지 후) 정리하므로, 여기서는 추적 테이블만 지우고 사냥터로 돌려보낸다(처치도
-- "그 보스와의 볼일이 끝났다"는 점에서 despawnFor와 같은 결과 - 돌아간다).
function BossEncounter.clearFor(player)
	activeBosses[player] = nil
	teleportTo(player, WorldConfig.huntingGround.center + Vector3.new(0, 5, 0))
end

function BossEncounter.getActive(player)
	return activeBosses[player]
end

-- 플레이어 사망 시 보스 리셋(21-3 [1]). 죽음을 반복해 조금씩 깎아 이기는 구멍을 막는다 -
-- HP 최대치 복구 + 진행 중인 패턴·파동·연출 취소 + 보스를 중앙 스폰 자리로 되돌려 idle.
-- 재도전 횟수 제한은 없다(21-1 결정). 19-4 개인 인스턴스 구조와의 정합: activeBosses[player]
-- 하나가 "이 플레이어의 보스"이므로 다른 플레이어의 보스는 건드리지 않는다.
function BossEncounter.resetFor(player)
	local model = activeBosses[player]
	if not model or not model.Parent then
		return
	end
	local data = MonsterState.getData(model)
	if not data then
		return
	end
	BossPatterns.reset(model, data)
	MonsterState.resetBossHp(model)
	MonsterSpawner.updateHpLabel(model)
	MonsterState.setAiState(model, "idle")
	MonsterState.setAiTarget(model, nil)
	model:PivotTo(CFrame.new(MonsterState.getSpawnPosition(model)))
	player:SetAttribute("TickDamage", 0)
	print(("[forge-game] 보스 리셋: %s 사망 - %s HP 최대치 복구"):format(player.Name, data.displayName))
end

-- 보스전 도중 죽어도(사용자 지시) 그 아레나로 다시 스폰된다 - 스테이지를 실제로 옮길
-- 때만(위 despawnFor/clearFor) 사냥터로 돌아간다. activeBosses에 아직 이 플레이어의
-- 보스가 남아 있다는 것 자체가 "아직 그 보스전 중"이라는 뜻이므로, 이 하나의 조건만
-- 보면 된다 - 별도 "보스전 중" 플래그를 새로 만들지 않는다(19-4가 겪은 유령 상태
-- 문제를 반복하지 않으려면 진실의 출처를 하나로 유지해야 한다).
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- 21-3 [1]: 죽는 순간(Humanoid.Died - PlayerDamage가 Health=0을 넣는 그 신호) 보스를
		-- 리셋한다. task.defer로 한 틱 미룬다 - Died가 보스 패턴의 피해 적용 도중(BossPatterns.
		-- step 안)에서 동기로 발화하면 진행 중인 상태 테이블을 그 함수가 아직 쓰고 있다.
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			if activeBosses[player] then
				task.defer(BossEncounter.resetFor, player)
			end
		end)

		local slot = slotByPlayer[player]
		local model = activeBosses[player]
		if not model or not slot then
			return
		end
		teleportTo(player, arenaEntryPosition(WorldConfig.zones[zoneKeyForSlot(slot)]))
		local data = MonsterState.getData(model)
		if data then
			BossPatterns.setGrace(model, data, data.entryGraceSeconds) -- 재도전 2초 유예
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	releaseSlot(player)
end)

return BossEncounter
