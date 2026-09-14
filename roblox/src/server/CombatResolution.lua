-- 몬스터 한 마리가 데미지를 맞은 뒤의 공통 처리(20-2a) - AttackServer.server.lua에 있던
-- "죽었으면 그다음"(경합 가드·보상 지급·despawn)을 뽑아냈다. 평타는 한 번에 대상 하나만
-- 때리지만 스킬(SkillServer.server.lua)은 한 번의 캐스트로 여러 대상을 때릴 수 있어, 이
-- 죽음 처리 로직을 두 곳이 복사해서 쓰면 나중에 하나만 고치고 잊어버릴 위험이 생긴다
-- (19-4가 이미 겪은 "경합 가드"의 섬세함 - MonsterState.tryClaimDeath 순서를 그대로 지켜야
-- 한다). applyDamage 자체(HP 차감)는 호출부가 각자 하고, "죽었으면 그다음"만 여기로 온다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local Loot = require(ReplicatedStorage.Shared.Loot)
local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local BossEncounter = require(script.Parent.BossEncounter)
local ImmediateSave = require(script.Parent.ImmediateSave)

local CombatResolution = {}

-- AttackServer.server.lua/SkillServer.server.lua가 각자 만든 RemoteEvent 인스턴스를 여기
-- 넘겨준다(둘 다 같은 골드/레벨업 팝업 이벤트를 공유해야 한다 - 새로 만들지 않는다). 두
-- 스크립트 다 자기 RemoteEvent를 만든 직후 이 함수를 부른다 - 순서 무관, init을 두 번
-- 불러도 같은 인스턴스를 넘기면 안전하다(멱등).
function CombatResolution.init(goldGainedEvent, levelUpEvent)
	CombatResolution.goldGained = goldGainedEvent
	CombatResolution.levelUp = levelUpEvent
end

-- 처치 보상 지급 1인분(19-4 [2]) - 보스(단독 수령)와 잡몹(기여자 각자)이 똑같이 이 함수
-- 하나로 받는다. AttackServer.server.lua의 grantKillReward를 그대로 옮겼다(동작 변경 없음).
local function grantKillReward(recipient, target, monsterData, deathPosition)
	local isBoss = monsterData.isBoss
	local isSparkle = MonsterState.isSparkle(target)
	local recipientStage = PlayerProfile.getInfiniteStage(recipient) or 1
	local dropStage = isBoss and monsterData.stageNumber or recipientStage

	local goldDrop = MonsterState.getGoldDropFor(target, recipientStage)
	if isSparkle then
		goldDrop = math.floor(goldDrop * RareMonsterConfig.goldMultiplier)
	end
	PlayerProfile.addGold(recipient, goldDrop)
	CombatResolution.goldGained:FireClient(recipient, goldDrop)

	local expReward = MonsterState.getExpRewardFor(target, recipientStage)
	local oldLevel, newLevel = PlayerProfile.addCharacterExp(recipient, expReward)
	if newLevel and newLevel ~= oldLevel then
		CombatResolution.levelUp:FireClient(recipient, newLevel)
	end

	local armorDrop
	if isBoss then
		-- 20-4 [1]: "그 스테이지 보스를 처음 깼는가"로 분기한다. 첫 처치만 확정 드랍
		-- (Loot.rollBossFirstClearDrop) - 재도전은 잡몹과 같은 25% 확률·등급 굴림
		-- (Loot.rollArmorDrop)으로 떨어진다. 재입장 자체는 막지 않는다(지시 원문) - 막는
		-- 것은 확정 보상뿐이다.
		local stage = monsterData.stageNumber
		if PlayerProfile.hasBossFirstClearReward(recipient, stage) then
			armorDrop = Loot.rollArmorDrop(dropStage, newLevel or oldLevel, monsterData.tierIndex)
		else
			armorDrop = Loot.rollBossFirstClearDrop(dropStage, newLevel or oldLevel, PlayerProfile.getRebirthCount(recipient))
			PlayerProfile.markBossFirstClearReward(recipient, stage)
		end
	elseif isSparkle then
		armorDrop = Loot.rollSparkleArmorDrop(dropStage, newLevel or oldLevel, monsterData.tierIndex)
	else
		armorDrop = Loot.rollArmorDrop(dropStage, newLevel or oldLevel, monsterData.tierIndex)
	end
	if armorDrop then
		ItemDropSpawner.spawn(armorDrop, deathPosition, recipient)
		print(("[forge-game] 드랍: %s등급 %s (%s)"):format(armorDrop.grade, armorDrop.part,
			isBoss and "보스" or (isSparkle and "반짝이" or "잡몹")))
	end
end

local function handleBossDeath(attacker, target)
	local monsterData = MonsterState.getData(target)
	local deathPosition = target.PrimaryPart.Position

	-- 보스는 개인 인스턴스라 이 죽음을 처리하는 호출자(attacker) 1인이 그대로 가져간다
	-- (19-4 [3] 지시 - "역할이 다르므로 구조가 달라도 된다"). 스킬로 막타를 낸 경우도
	-- 그 캐스터가 attacker다(SkillServer.server.lua 호출부 참고).
	grantKillReward(attacker, target, monsterData, deathPosition)
	PlayerProfile.setBossCleared(attacker, monsterData.stageNumber)
	ImmediateSave.request(attacker)
	BossEncounter.clearFor(attacker)
	print(("[forge-game] 보스 처치: %s - 스테이지 %d"):format(attacker.Name, monsterData.stageNumber))
end

local function handleMobDeath(target)
	local monsterData = MonsterState.getData(target)
	local deathPosition = target.PrimaryPart.Position

	-- 공유 잡몹(19-4 [2], PRD 20.13 C안) - 막타 1인이 아니라 기여 비율 이상인 전원이
	-- 각자 온전한 보상을 받는다. contributor.Parent 검사는 방어적 가드(AttackServer.
	-- server.lua 원본 주석 참고).
	for contributor, ratio in pairs(MonsterState.getContributors(target)) do
		if ratio >= CombatConfig.contributionRewardThreshold and contributor.Parent then
			grantKillReward(contributor, target, monsterData, deathPosition)
		end
	end
end

-- 호출부(AttackServer·SkillServer)가 MonsterState.applyDamage까지 끝낸 뒤, 죽음 여부와
-- 무관하게 매 타격마다 부른다. isDead가 아니면 아무 것도 안 한다 - 항상 불러도 안전하다.
-- attacker는 "이 타격을 낸 사람"(보스면 이 사람이 보상을 가져간다, 잡몹이면 기여자 목록만
-- 쓰이고 attacker 자체는 안 쓰인다 - 그래도 호출부 계약을 하나로 통일하기 위해 항상 받는다).
function CombatResolution.resolveHit(attacker, target, isDead)
	if not isDead then
		return
	end

	-- 처치 경합 가드(15-1 검증 중 재현, 19-4) - 같은 몬스터가 거의 동시에 두 번 죽음
	-- 판정을 받아도(연타·평타+스킬 동시 등) 오직 첫 번째만 통과한다. despawn 전에 이걸
	-- 확인해야 두 번째 요청이 이미 지워진 데이터를 읽으려 하지 않는다.
	if not MonsterState.tryClaimDeath(target) then
		return
	end

	local monsterData = MonsterState.getData(target)
	if monsterData.isBoss then
		handleBossDeath(attacker, target)
	else
		handleMobDeath(target)
	end

	MonsterSpawner.despawn(target)
end

return CombatResolution
