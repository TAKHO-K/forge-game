-- 보스 인스턴스 스폰·퇴장 단일 관리 통로(15-1, 20-2b에서 아레나 격리, 24-1에서 파티 확장).
-- 사냥터가 스테이지 무관 공용 공간 하나뿐이라(HuntingGround.server.lua - 격자 9자리 고정),
-- 보스는 그 안에 상주하는 대신 "이 플레이어(들)가 지금 보스 스테이지에 있다"는 사실에 맞춰
-- 전용 인스턴스로 스폰한다 - 여러 플레이어가 서로 다른 스테이지에 있어도 서로의 보스를
-- 방해하지 않는다.
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
-- 24-1 파티(PRD 20.47 [6](라) "activeBosses[Player] → 파티 단위"): 진실의 출처는 이제
-- "encounter" 하나다 - { model, data, stage, members(실제 Player 목록), party, size(입장 머릿수,
-- 더미 포함 - 보스 HP 배수의 N), rotationOwner(순환을 소모한 플레이어 = 리더), slot, zoneKey,
-- isTutorial }. encounterOf[Player]가 그 플레이어의 활성 보스전이고, 솔로는 members 1명짜리
-- encounter다(코드 경로 하나 - "솔로를 N=1 파티로 통일"). 옛 activeBosses[player]를 읽던
-- 호출부는 getActive(player)(= encounterOf[player].model)로 그대로 동작한다.
--
-- 사용자 지시: 보스전 중 죽어도 그 아레나로 다시 스폰된다(아래 CharacterAdded 훅) -
-- 스테이지를 실제로 옮길 때만(StageServer.server.lua가 despawnFor/leaveFor를 부를 때)
-- 사냥터로 돌아간다.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local BossPatterns = require(script.Parent.BossPatterns)
local GroundProbe = require(script.Parent.GroundProbe)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local PartyState = require(script.Parent.PartyState)

local BossEncounter = {}

-- [Player] = encounter / [Model] = encounter. 처치(CombatResolution → clearForModel)와 물러남
-- (despawnFor/leaveFor) 둘 다 여기서 지운다 - 어느 쪽이든 "지금 이 플레이어의 활성 보스전"은
-- 이 두 테이블로만 판단한다.
local encounterOf = {}
local encounterByModel = {}

-- 아레나 슬롯 배정 - encounter 하나에 슬롯 하나. 반납되면 freeSlots로 돌아가 다음 팀이 쓴다.
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

-- 파티 입장 시 멤버끼리 겹치지 않게 입장점 좌우로 벌리는 간격(캐릭터 반폭 1의 4배 - 연출값).
local ENTRY_SPREAD_STUDS = 4

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

local function allocateSlot()
	-- 서버 정원(12명)을 넘는 동시 보스전은 설계상 안 생겨야 하지만(PRD 20.38 [6]), 혹시
	-- freeSlots가 바닥나면 1번을 같이 쓴다 - 아레나가 겹쳐 불편할 뿐 에러는 나지 않는다.
	return table.remove(freeSlots) or 1
end

local function releaseSlot(slot)
	if slot then
		table.insert(freeSlots, slot)
	end
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

local function huntingGroundReturnPosition()
	return WorldConfig.huntingGround.center + Vector3.new(0, 5, 0)
end

-- 멤버 index번째의 입장 위치 - 입장점을 중심으로 좌우로 벌린다(파티가 한 점에 겹쳐 서지 않게).
local function entryPositionForIndex(zone, index, count)
	local offset = (index - 1 - (count - 1) / 2) * ENTRY_SPREAD_STUDS
	return arenaEntryPosition(zone) + Vector3.new(offset, 0, 0)
end

local function memberIndex(encounter, player)
	return table.find(encounter.members, player) or 1
end

-- ═══ 조회 ═══

function BossEncounter.getEncounter(player)
	return encounterOf[player]
end

function BossEncounter.getEncounterByModel(model)
	return encounterByModel[model]
end

-- 옛 activeBosses[player] 계약 - "이 플레이어의 활성 보스 모델"(없으면 nil).
function BossEncounter.getActive(player)
	local encounter = encounterOf[player]
	return encounter and encounter.model
end

-- 이 보스와 싸우는 실제 멤버 목록(퇴장·탈퇴로 빠진 사람은 이미 없다). BossPatterns(피해·연출
-- 대상)·CombatResolution(보상 후보)·MonsterAI(대상 재선택)가 읽는다. 없으면 빈 목록.
function BossEncounter.getMembersOfModel(model)
	local encounter = encounterByModel[model]
	return encounter and encounter.members or {}
end

function BossEncounter.getRotationOwner(model)
	local encounter = encounterByModel[model]
	return encounter and encounter.rotationOwner
end

local function isAlive(player)
	local hp = PlayerState.getHp(player)
	local character = player.Character
	return hp ~= nil and hp > 0 and character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
end

-- 살아 있는 멤버 중 position에 가장 가까운 사람(MonsterAI의 보스 평타·패턴 조준 대상 재선택 -
-- PRD 20.47 [6](나) "평타 추격 대상 = 가장 가까운 멤버, 매 틱 재선택"). 없으면 nil.
function BossEncounter.nearestLivingMember(model, position)
	local best, bestDistance = nil, math.huge
	for _, member in ipairs(BossEncounter.getMembersOfModel(model)) do
		if isAlive(member) then
			local root = member.Character:FindFirstChild("HumanoidRootPart")
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
			if d < bestDistance then
				best, bestDistance = member, d
			end
		end
	end
	return best
end

-- excludePlayer(선택): 이 사람은 죽은 것으로 센다 - Humanoid.Died 시점엔 PlayerDamage를 거치지 않은
-- 죽음(로블록스 메뉴 리셋·낙사 등)이라 PlayerState.hp가 아직 0이 아닐 수 있다. 21-3 솔로 규칙
-- ("죽으면 리셋")이 그런 죽음에도 그대로 성립해야 하므로 죽는 당사자는 항상 제외한다.
function BossEncounter.livingMemberCount(encounter, excludePlayer)
	local n = 0
	for _, member in ipairs(encounter.members) do
		if member ~= excludePlayer and isAlive(member) then
			n += 1
		end
	end
	return n
end

-- ═══ 스폰 ═══

-- 공통 스폰 - members(실제 Player 목록)를 slot 하나의 아레나로 전원 텔레포트하고 보스를 세운다.
-- size는 보스 HP 배수의 N(더미 포함 머릿수, PRD 20.47 [6](가) "N은 입장 인원이지 유효 DPS
-- 환산이 아니다"). 이미 encounter가 있는 멤버가 섞여 있으면 호출부가 먼저 정리해야 한다.
local function spawnEncounter(data, stage, members, party, size, rotationOwner, isTutorial)
	local slot = allocateSlot()
	local zoneKey = zoneKeyForSlot(slot)
	buildArena(zoneKey)
	local zone = WorldConfig.zones[zoneKey]

	for i, member in ipairs(members) do
		teleportTo(member, entryPositionForIndex(zone, i, #members))
	end

	-- Y는 바닥 윗면(ARENA_FLOOR_TOP_Y) + 1.5 - HuntingGround.server.lua의 tier 몬스터
	-- 스폰 높이(FLOOR_Y+FLOOR_THICKNESS/2+1.5)와 같은 관례.
	local spawnPosition = zone.center + Vector3.new(0, ARENA_FLOOR_TOP_Y + 1.5, 0)
	local model = MonsterSpawner.spawn(data, spawnPosition, zoneKey)

	local encounter = {
		model = model,
		data = data,
		stage = stage,
		members = table.clone(members),
		party = party,
		size = size,
		rotationOwner = rotationOwner,
		slot = slot,
		zoneKey = zoneKey,
		isTutorial = isTutorial or false,
		startedAt = os.clock(),
	}
	for _, member in ipairs(members) do
		encounterOf[member] = encounter
	end
	encounterByModel[model] = encounter
	BossPatterns.setGrace(model, data, data.entryGraceSeconds) -- 입장 2초 유예(20.44 [3](다))
	return encounter
end

-- targetStage가 보스 스테이지이고 아직 이 플레이어의 보스가 없으면 솔로로 스폰한다. 이미
-- 있으면(예: 같은 스테이지 안에서 위/아래로 왔다 갔다) 아무것도 안 한다 - 중복 스폰 방지.
function BossEncounter.spawnFor(player, stage)
	if not BossRules.isBossStage(stage) then
		return
	end
	if encounterOf[player] then
		return
	end

	-- 23-5: 어느 종이 나올지는 더 이상 무작위가 아니라 이 플레이어의 순환 상태가 정한다
	-- (PlayerProfile.getBossForStage, PRD 20.50 [5]) - 여기가 실제로 "이 스테이지에 처음
	-- 진입하는 순간"이다(위 두 return이 이미 걸러낸 뒤 - 보스 스테이지가 아니거나 이미
	-- 활성 보스가 있으면 순환을 건드리지 않는다).
	local bossId = PlayerProfile.getBossForStage(player, stage)
	if not bossId then
		return
	end

	local data = BossRules.buildInstanceData(stage, bossId, 1)
	if not data then
		return
	end

	local encounter = spawnEncounter(data, stage, { player }, nil, 1, player, false)
	print(("[forge-game] 보스 등장: %s - 스테이지 %d, 대상 %s (아레나 %s)"):format(
		data.displayName, stage, player.Name, encounter.zoneKey))
end

-- 파티 보스 입장 검사(PRD 20.47 [6](라)) - 멤버 전원이 (1) StageServer 게이트(최고 도달+1 이내,
-- 바로 아래 보스 클리어)와 (2) 밴드(bossStage ≤ rec(L_i) + band)를 통과해야 한다. 하나라도
-- 막히면 { {player, reason}, ... } 목록을 돌려준다(빈 목록 = 통과). 밴드가 없으면 레벨 10 친구를
-- 보스마다 데리고 가 최고 도달 스테이지를 100까지 끌어올리는 캐리(= 리더보드 조작)가 열린다.
function BossEncounter.checkPartyEntry(party, stage)
	local blocked = {}
	for _, member in ipairs(PartyState.getMemberPlayers(party)) do
		local best = PlayerProfile.getInfiniteStageBest(member)
		local reason = nil
		if not best then
			reason = "no_profile"
		elseif stage > best + 1 then
			reason = "range"
		else
			local requiredBossStage = BossRules.getBossStageBelow(stage)
			if requiredBossStage > 0 and requiredBossStage > (PlayerProfile.getBestBossCleared(member) or 0) then
				reason = "boss_locked"
			else
				local level = PlayerProfile.getCharacterLevel(member) or 1
				local cap = BossRules.partyEntryStageCap(level)
				if stage > cap then
					reason = ("band(권장 %d+%d)"):format(cap - BossRules.partyEntryBand(), BossRules.partyEntryBand())
				end
			end
		end
		if reason then
			table.insert(blocked, { player = member, reason = reason })
		end
	end
	return blocked
end

-- 파티 보스 스폰(리더가 보스 스테이지로 이동할 때 StageServer가 부른다). 검사는 호출부가
-- checkPartyEntry로 먼저 끝냈다고 가정한다. 순환은 리더 것만 소모한다(rotationOwner) - 다른
-- 멤버의 bossRotation은 읽지도 쓰지도 않는다(지시 4 "남의 순환 인덱스가 소모되면 안 된다").
function BossEncounter.spawnForParty(party, leader, stage)
	if not BossRules.isBossStage(stage) then
		return false
	end
	if encounterOf[leader] then
		return false
	end
	local members = PartyState.getMemberPlayers(party)
	for _, member in ipairs(members) do
		if encounterOf[member] then
			BossEncounter.leaveFor(member) -- 남아 있던 솔로 보스전은 물러난다(PartyServer가 합류 시 이미 정리하지만 방어).
		end
	end

	local bossId = PlayerProfile.getBossForStage(leader, stage)
	if not bossId then
		return false
	end
	local size = PartyState.getSize(party)
	local data = BossRules.buildInstanceData(stage, bossId, size)
	if not data then
		return false
	end

	local encounter = spawnEncounter(data, stage, members, party, size, leader, false)
	local names = {}
	for _, member in ipairs(members) do
		table.insert(names, member.Name)
	end
	print(("[forge-game] 파티 보스 등장: %s - 스테이지 %d, 인원 %d(실제 %d: %s), HP 배수 %.3f (아레나 %s)"):format(
		data.displayName, stage, size, #members, table.concat(names, ","), data.partyHpMultiplier, encounter.zoneKey))
	return true
end

-- 23-1 견습 모드 전용 - targetStage 대신 (tierIndex, patternKeys, hpScale, weaponMultiplier)를
-- 받아 BossRules.buildTutorialInstanceData로 인스턴스를 만든다는 점만 spawnFor와 다르다.
-- 아레나 슬롯 배정·텔레포트·입장 유예는 완전히 같은 코드를 재사용한다(견습 보스도 결국
-- "이 플레이어의 활성 보스" 하나이므로 encounter를 그대로 공유해도 안전하다 - 무한 모드
-- 보스와 견습 보스가 동시에 뜰 일이 없다, 견습 중엔 무한 모드 진행 자체가 잠겨 있고 파티도
-- 못 든다). BossRules.isBossStage 검사를 하지 않는다 - 견습 스테이지(TutorialData.monsterStage=1)는
-- BossData.stageInterval의 배수가 아니어도 된다.
function BossEncounter.spawnTutorialFor(player, tierIndex, stage, patternKeys, hpScale, weaponMultiplier)
	if encounterOf[player] then
		return
	end

	local data = BossRules.buildTutorialInstanceData(tierIndex, stage, patternKeys, hpScale, weaponMultiplier)
	if not data then
		return
	end

	local encounter = spawnEncounter(data, stage, { player }, nil, 1, nil, true)
	print(("[forge-game] 견습 보스 등장: %s - tier%d, 대상 %s (아레나 %s)"):format(
		data.displayName, tierIndex, player.Name, encounter.zoneKey))
end

-- ═══ 퇴장 ═══

-- encounter 전체를 끝낸다(처치는 destroyModel=false - MonsterSpawner.despawn이 사체 유지 후
-- 정리한다 / 물러남은 true - 즉시 지운다). 남은 멤버 전원을 사냥터로 돌려보내고 슬롯을 반납한다.
local function endEncounter(encounter, destroyModel)
	for _, member in ipairs(encounter.members) do
		if encounterOf[member] == encounter then
			encounterOf[member] = nil
		end
		if member.Parent then
			teleportTo(member, huntingGroundReturnPosition())
		end
	end
	encounter.members = {}
	encounterByModel[encounter.model] = nil
	if destroyModel then
		MonsterState.clear(encounter.model)
		encounter.model:Destroy()
	end
	releaseSlot(encounter.slot)
	encounter.slot = nil
end

-- 처치되지 않은 채로 물러날 때(스테이지 하향/상향 이동, 견습 중단)만 부른다 - 이 플레이어가
-- 속한 보스전 전체가 끝난다(파티면 멤버 전원이 사냥터로 돌아간다 - 리더가 스테이지를 옮기면
-- 파티 보스전이 끝난다는 뜻). 처치는 CombatResolution.lua가 MonsterSpawner.despawn(죽음 연출
-- 포함)을 직접 호출한 뒤 clearForModel로 이 테이블만 지운다.
function BossEncounter.despawnFor(player)
	local encounter = encounterOf[player]
	if not encounter then
		return
	end
	endEncounter(encounter, true)
end

-- 이 플레이어만 보스전에서 빠진다(파티원의 스테이지 이동·퇴장·파티 이탈). 보스 HP·인원 배수는
-- 입장 순간에 고정돼 있어 바뀌지 않는다(PRD 20.47 [6](다) "이탈의 대가는 파티가 진다" - 남은
-- 사람이 더 큰 HP를 상대한다, HP를 낮추는 조작 불가). 마지막 한 명이 빠지면 보스도 물러난다.
function BossEncounter.leaveFor(player)
	local encounter = encounterOf[player]
	if not encounter then
		return
	end
	local index = table.find(encounter.members, player)
	if index then
		table.remove(encounter.members, index)
	end
	encounterOf[player] = nil
	if player.Parent then
		teleportTo(player, huntingGroundReturnPosition())
	end
	if #encounter.members == 0 then
		endEncounter(encounter, true)
		print(("[forge-game] 보스 물러남: 마지막 멤버 %s 이탈"):format(player.Name))
	else
		print(("[forge-game] 보스전 이탈: %s (남은 멤버 %d, HP 배수 %.3f 유지)"):format(
			player.Name, #encounter.members, encounter.data.partyHpMultiplier or 1))
	end
end

-- CombatResolution.lua가 보스를 죽인 직후 부른다 - 인스턴스 자체는 MonsterSpawner.despawn이
-- 이미(사체 유지 후) 정리하므로, 여기서는 추적 테이블만 지우고 멤버 전원을 사냥터로
-- 돌려보낸다(처치도 "그 보스와의 볼일이 끝났다"는 점에서 despawnFor와 같은 결과 - 돌아간다).
function BossEncounter.clearForModel(model)
	local encounter = encounterByModel[model]
	if encounter then
		endEncounter(encounter, false)
	end
end

-- 옛 계약(TutorialState.onBossCleared) - 이 플레이어의 보스전을 처치 후 정리한다.
function BossEncounter.clearFor(player)
	local encounter = encounterOf[player]
	if encounter then
		endEncounter(encounter, false)
	end
end

-- 플레이어 사망 시 보스 리셋(21-3 [1]). 죽음을 반복해 조금씩 깎아 이기는 구멍을 막는다 -
-- HP 최대치 복구 + 진행 중인 패턴·파동·연출 취소 + 보스를 중앙 스폰 자리로 되돌려 idle.
-- 재도전 횟수 제한은 없다(21-1 결정).
-- 24-1 파티: 살아 있는 멤버가 하나라도 남아 있으면 리셋하지 않는다(PRD 20.47 [6](다) "생존자
-- 0명 → 즉시 전체 리셋", 솔로 N=1이면 정확히 21-3 규칙). 죽은 멤버는 리스폰 후 아레나로
-- 돌아온다(아래 CharacterAdded 훅).
function BossEncounter.resetFor(player)
	local encounter = encounterOf[player]
	local model = encounter and encounter.model
	if not model or not model.Parent then
		return
	end
	local survivors = BossEncounter.livingMemberCount(encounter, player)
	if survivors > 0 then
		print(("[forge-game] 파티원 사망: %s - 생존자 %d명 남아 보스 유지"):format(player.Name, survivors))
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
	for _, member in ipairs(encounter.members) do
		if typeof(member) == "Instance" then
			member:SetAttribute("TickDamage", 0)
		end
	end
	print(("[forge-game] 보스 리셋: %s 사망(생존자 0) - %s HP 최대치 복구"):format(player.Name, data.displayName))
end

-- 보스전 도중 죽어도(사용자 지시) 그 아레나로 다시 스폰된다 - 스테이지를 실제로 옮길
-- 때만(위 despawnFor/leaveFor/clearFor) 사냥터로 돌아간다. encounterOf에 아직 이 플레이어의
-- 보스전이 남아 있다는 것 자체가 "아직 그 보스전 중"이라는 뜻이므로, 이 하나의 조건만
-- 보면 된다 - 별도 "보스전 중" 플래그를 새로 만들지 않는다(19-4가 겪은 유령 상태
-- 문제를 반복하지 않으려면 진실의 출처를 하나로 유지해야 한다).
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- 21-3 [1]: 죽는 순간(Humanoid.Died - PlayerDamage가 Health=0을 넣는 그 신호) 보스를
		-- 리셋한다. task.defer로 한 틱 미룬다 - Died가 보스 패턴의 피해 적용 도중(BossPatterns.
		-- step 안)에서 동기로 발화하면 진행 중인 상태 테이블을 그 함수가 아직 쓰고 있다.
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			if encounterOf[player] then
				task.defer(BossEncounter.resetFor, player)
			end
		end)

		local encounter = encounterOf[player]
		if not encounter or not encounter.slot then
			return
		end
		local zone = WorldConfig.zones[encounter.zoneKey]
		teleportTo(player, entryPositionForIndex(zone, memberIndex(encounter, player), #encounter.members))
		-- 재도전 2초 유예 - 솔로(또는 전원 사망 리셋 직후)만. 파티에서 남이 싸우는 중에 부활자
		-- 하나가 보스 패턴을 멈추게 할 수는 없다(PRD 20.47 [6](나) "부활자는 보스를 멈출 수 없다").
		if BossEncounter.livingMemberCount(encounter) <= 1 then
			local data = MonsterState.getData(encounter.model)
			if data then
				BossPatterns.setGrace(encounter.model, data, data.entryGraceSeconds)
			end
		end
	end)
end)

-- 퇴장 - 자기 보스전에서만 빠진다(파티면 나머지가 이어서 싸운다, N·HP 배수 고정).
Players.PlayerRemoving:Connect(function(player)
	BossEncounter.leaveFor(player)
end)

-- 파티 이탈(탈퇴·추방·견습 진입·해산) - 파티 보스전 중이었으면 그 사람만 빠진다. "disband"(마지막
-- 한 명이 남아 파티가 자동 해산)는 예외 - 남은 사람은 그 보스전을 혼자 이어간다(HP 배수는
-- 그대로 - 이탈의 대가). 견습 진입("tutorial")도 빠진다 - 견습은 싱글이다.
PartyState.onMemberRemoved(function(player, party, reason)
	local encounter = encounterOf[player]
	if not encounter or encounter.party ~= party then
		return
	end
	if reason == "disband" then
		encounter.party = nil
		return
	end
	BossEncounter.leaveFor(player)
end)

return BossEncounter
