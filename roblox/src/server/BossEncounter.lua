-- 플레이어별 보스 인스턴스 스폰·퇴장 단일 관리 통로(15-1). 사냥터가 스테이지 무관 공용
-- 공간 하나뿐이라(HuntingGround.server.lua - 격자 9자리 고정), 보스는 그 안에 상주하는
-- 대신 "이 플레이어가 지금 보스 스테이지에 있다"는 사실에 맞춰 그 플레이어 전용
-- 인스턴스로 스폰한다 - 여러 플레이어가 서로 다른 스테이지에 있어도 서로의 보스를
-- 방해하지 않는다(잡몹의 "몬스터 한 마리당 대상 하나" 어그로 설계와 같은 선상의 타협 -
-- MonsterState.setStage 주석 참고).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)

local BossEncounter = {}

-- [Player] = Model. 죽여서 없어진 경우(AttackServer가 clearFor를 부른다)와 스테이지를
-- 벗어나 물러난 경우(despawnFor) 둘 다 여기서 지운다 - 어느 쪽이든 "지금 이 플레이어의
-- 활성 보스"는 이 테이블 하나로만 판단한다.
local activeBosses = {}

-- 보스 스폰 위치 - 사냥터 바닥 위, 플레이어 앞쪽으로 살짝 띄운다(플레이어 캐릭터가 아직
-- 없으면 사냥터 중심을 대신 쓴다 - 접속 직후 스테이지 이동은 사실상 없지만 방어적으로 둔다).
local function spawnPositionFor(player)
	local floorTopY = WorldConfig.huntingGround.center.Y + WorldConfig.huntingGround.size.Y / 2 + 1.5
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		local center = WorldConfig.huntingGround.center
		return Vector3.new(center.X, floorTopY, center.Z)
	end

	local lookDirection = rootPart.CFrame.LookVector
	local aheadXZ = Vector3.new(lookDirection.X, 0, lookDirection.Z)
	if aheadXZ.Magnitude < 0.01 then
		aheadXZ = Vector3.new(0, 0, -1)
	else
		aheadXZ = aheadXZ.Unit
	end

	local spawnXZ = rootPart.Position + aheadXZ * 20
	return Vector3.new(spawnXZ.X, floorTopY, spawnXZ.Z)
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

	local model = MonsterSpawner.spawn(data, spawnPositionFor(player))
	activeBosses[player] = model
	print(("[forge-game] 보스 등장: %s - 스테이지 %d, 대상 %s"):format(data.displayName, stage, player.Name))
end

-- 처치되지 않은 채로 물러날 때(스테이지 하향 이동, 퇴장)만 부른다 - 처치는 AttackServer가
-- MonsterSpawner.despawn(죽음 연출 포함)을 직접 호출한 뒤 clearFor로 이 테이블만 지운다.
function BossEncounter.despawnFor(player)
	local model = activeBosses[player]
	if not model then
		return
	end
	activeBosses[player] = nil
	MonsterState.clear(model)
	model:Destroy()
end

-- AttackServer가 보스를 죽인 직후 부른다 - 인스턴스 자체는 MonsterSpawner.despawn이 이미
-- (사체 유지 후) 정리하므로, 여기서는 추적 테이블에서만 지운다.
function BossEncounter.clearFor(player)
	activeBosses[player] = nil
end

function BossEncounter.getActive(player)
	return activeBosses[player]
end

return BossEncounter
