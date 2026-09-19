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
local TreasureChestConfig = require(ReplicatedStorage.Shared.data.TreasureChestConfig)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local BossEncounter = require(script.Parent.BossEncounter)
local ImmediateSave = require(script.Parent.ImmediateSave)
local TutorialState = require(script.Parent.TutorialState)
local PartyState = require(script.Parent.PartyState)

local CombatResolution = {}

-- AttackServer.server.lua/SkillServer.server.lua가 각자 만든 RemoteEvent 인스턴스를 여기
-- 넘겨준다(둘 다 같은 골드/레벨업 팝업 이벤트를 공유해야 한다 - 새로 만들지 않는다). 두
-- 스크립트 다 자기 RemoteEvent를 만든 직후 이 함수를 부른다 - 순서 무관, init을 두 번
-- 불러도 같은 인스턴스를 넘기면 안전하다(멱등).
function CombatResolution.init(goldGainedEvent, levelUpEvent)
	CombatResolution.goldGained = goldGainedEvent
	CombatResolution.levelUp = levelUpEvent
	-- 보물상자 알림 이벤트(22-2 [3])는 MonsterSpawner가 만든다 - 여기선 찾아만 둔다.
	CombatResolution.treasureChestNotice = ReplicatedStorage:FindFirstChild("TreasureChestNotice")
end

-- 처치 보상 지급 1인분(19-4 [2]) - 보스(단독 수령)와 잡몹(기여자 각자)이 똑같이 이 함수
-- 하나로 받는다. AttackServer.server.lua의 grantKillReward를 그대로 옮겼다(동작 변경 없음).
local function grantKillReward(recipient, target, monsterData, deathPosition)
	local isBoss = monsterData.isBoss
	local isSparkle = MonsterState.isSparkle(target)
	local recipientStage = TutorialState.getMonsterStage(recipient)
	local dropStage = isBoss and monsterData.stageNumber or recipientStage

	local goldDrop = MonsterState.getGoldDropFor(target, recipientStage)
	if isSparkle then
		-- 반짝이 자신의 처치 골드는 절반(웹 규칙) + 전용 보상으로 "그 구역 잡몹 N마리분"
		-- 골드를 얹는다(22-2 [2], RareMonsterConfig.goldBonusKillEquivalent 주석 - 등급표는
		-- 절대 안 올린다). 기준은 접두사 없는 기본형 골드(InfiniteStage 배율만).
		local baseGold = InfiniteStage.getGoldReward(monsterData.goldDrop, recipientStage)
		goldDrop = math.floor(goldDrop * RareMonsterConfig.goldMultiplier + baseGold * RareMonsterConfig.goldBonusKillEquivalent)
	end
	goldDrop = math.floor(goldDrop)
	PlayerProfile.addGold(recipient, goldDrop)
	CombatResolution.goldGained:FireClient(recipient, goldDrop)

	local expReward = MonsterState.getExpRewardFor(target, recipientStage)
	local oldLevel, newLevel = PlayerProfile.addCharacterExp(recipient, expReward)
	if newLevel and newLevel ~= oldLevel then
		CombatResolution.levelUp:FireClient(recipient, newLevel)
	end

	-- 26-1: 드랍 옵션의 직업 특화 후보는 "그 순간 플레이어의 직업"(PRD 20.67 [1]).
	local classId = PlayerProfile.getClassId(recipient)

	local armorDrop
	if isBoss then
		-- 20-4 [1]: "그 스테이지 보스를 처음 깼는가"로 분기한다. 첫 처치만 확정 드랍
		-- (Loot.rollBossFirstClearDrop) - 재도전은 잡몹과 같은 25% 확률·등급 굴림
		-- (Loot.rollArmorDrop)으로 떨어진다. 재입장 자체는 막지 않는다(지시 원문) - 막는
		-- 것은 확정 보상뿐이다.
		local stage = monsterData.stageNumber
		if PlayerProfile.hasBossFirstClearReward(recipient, stage) then
			armorDrop = Loot.rollArmorDrop(dropStage, newLevel or oldLevel, monsterData.tierIndex, nil, classId)
		else
			armorDrop = Loot.rollBossFirstClearDrop(dropStage, newLevel or oldLevel, PlayerProfile.getRebirthCount(recipient), classId)
			PlayerProfile.markBossFirstClearReward(recipient, stage)
		end
	elseif isSparkle then
		armorDrop = Loot.rollSparkleArmorDrop(dropStage, newLevel or oldLevel, monsterData.tierIndex, classId)
	else
		-- 접두사 변종(22-2 [1]) - 드랍 확률에도 보상 배율(= HP 배율)을 곱한다(공평성).
		armorDrop = Loot.rollArmorDrop(dropStage, newLevel or oldLevel, monsterData.tierIndex, MonsterState.getRewardMultiplier(target), classId)
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

	-- 24-1 파티: 보상은 잡몹과 같은 규칙 - 기여 비율(damage/maxHp) 임계값 이상인 멤버 전원이
	-- 각자 독립 1인분(나눠 갖지 않는다, 지시 4). 솔로면 멤버가 attacker 하나뿐이고 기여 1.0이라
	-- 19-4 이후 동작과 완전히 같다. 후보는 encounter 멤버(BossEncounter)이지 attacker가 아니다 -
	-- 막타 1인이 아니라 "같이 싸운 사람"이 기준이다. encounter가 없으면(DevTools 등) attacker.
	local candidates = BossEncounter.getMembersOfModel(target)
	if #candidates == 0 then
		candidates = { attacker }
	end
	local contributions = MonsterState.getContributors(target)
	local rewarded = {}
	local underThreshold = {}
	for _, member in ipairs(candidates) do
		local ratio = contributions[member] or 0
		if member.Parent and ratio >= CombatConfig.contributionRewardThreshold then
			grantKillReward(member, target, monsterData, deathPosition)
			ImmediateSave.request(member)
			table.insert(rewarded, ("%s(%.0f%%)"):format(member.Name, ratio * 100))
		elseif member.Parent then
			table.insert(underThreshold, { player = member, ratio = ratio })
			print(("[forge-game] 보스 보상 제외: %s - 기여 %.1f%% < %.0f%%"):format(member.Name, ratio * 100, CombatConfig.contributionRewardThreshold * 100))
		end
	end

	-- 25-3(PRD 20.47 [6](라) "클리어 인정") - 스테이지 클리어 기록(bestBossCleared)은 위 보상
	-- 지급과 별개다. 파티 전원이 기여 10% 이상일 때만 전원에게 남는다 - 한 명이라도 미달이면
	-- 아무도 이 처치로는 기록을 얻지 못한다(보상은 각자 독립 지급 그대로, 절대 같은 분기에
	-- 묶지 않는다). 못 깬 사람을 이미 깬 파티원들이 데려가 캐리하는 경로를 막는 장치다.
	if #underThreshold == 0 then
		for _, member in ipairs(candidates) do
			if member.Parent then
				PlayerProfile.setBossCleared(member, monsterData.stageNumber)
			end
		end
	else
		for _, entry in ipairs(underThreshold) do
			PartyState.notify(entry.player, ("스테이지 클리어가 인정되지 않았습니다 - 기여 %.1f%%(최소 %.0f%% 필요)"):format(
				entry.ratio * 100, CombatConfig.contributionRewardThreshold * 100))
		end
		for _, member in ipairs(candidates) do
			local ratio = contributions[member] or 0
			if member.Parent and ratio >= CombatConfig.contributionRewardThreshold then
				PartyState.notify(member, "파티원 기여 미달로 이 처치는 스테이지 클리어로 기록되지 않았습니다")
			end
		end
	end

	-- 29-5: 보스의 정체가 스테이지만의 함수가 되면서(BossRules.bossIdForStage) 23-5의 "처치하면 pending을 지운다"는 없어졌다.
	BossEncounter.clearForModel(target)
	print(("[forge-game] 보스 처치: %s(스테이지 %d) - 보상 %d명 [%s]"):format(
		monsterData.displayName, monsterData.stageNumber, #rewarded, table.concat(rewarded, ", ")))
end

-- 보물상자 파괴(22-2 [3]) - 한 번이라도 유효 피격한 전원이 각자 독립적으로 골드를 받는다
-- (나눠 갖지 않는다 - 19-4 잡몹 기여 지급과 같은 철학). 금액은 "그 구역 잡몹 N마리분"을
-- 받는 사람의 스테이지 기준으로 계산한다(잡몹 골드와 같은 InfiniteStage 배율). 장비는
-- 안 준다(등급 체계 밖의 축만 - TreasureChestConfig 주석).
local function handleChestBreak(target)
	local chestData = MonsterState.getData(target)
	local baseData = chestData.baseData
	local count = 0
	for hitter in pairs(MonsterState.getChestHitters(target)) do
		if hitter.Parent then
			local stage = TutorialState.getMonsterStage(hitter)
			local gold = math.floor(InfiniteStage.getGoldReward(baseData.goldDrop, stage) * TreasureChestConfig.goldKillEquivalent)
			PlayerProfile.addGold(hitter, gold)
			CombatResolution.goldGained:FireClient(hitter, gold)
			count += 1
			print(("[forge-game] 보물상자 보상: %s +%d 골드"):format(hitter.Name, gold))
		end
	end
	print(("[forge-game] 보물상자 파괴 - %d명 보상"):format(count))
	if CombatResolution.treasureChestNotice then
		CombatResolution.treasureChestNotice:FireAllClients(("보물상자가 열렸습니다 - %d명이 보상을 받았습니다"):format(count))
	end
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
			-- 23-1: 골드·경험치·드랍은 위 grantKillReward가 이미 견습 stage 기준으로 계산했다
			-- (recipientStage가 TutorialState.getMonsterStage를 거친다) - 여기선 그 처치가
			-- "지금 단계가 가르치는 구역"에서 났는지만 추가로 확인해 진행도를 올린다.
			if TutorialState.isTutorialZoneKill(contributor, target) then
				TutorialState.registerKill(contributor)
			end
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
	if monsterData.isTutorial then
		-- 23-1: 견습 보스는 무한 모드 보상 경로(handleBossDeath - bestBossCleared·
		-- rollBossFirstClearDrop)를 전혀 타지 않는다. 그 두 값 다 무한 모드 진행도라
		-- 손대면 지시("무한 stage 필드는 건드리지 마라")를 어긴다 - 전용 경로가 필요한 이유.
		TutorialState.onBossCleared(attacker, target)
	elseif monsterData.isBoss then
		handleBossDeath(attacker, target)
	elseif monsterData.isChest then
		handleChestBreak(target)
	else
		handleMobDeath(target)
	end

	MonsterSpawner.despawn(target)
end

return CombatResolution
