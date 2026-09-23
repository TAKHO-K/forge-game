-- 몬스터 한 마리가 데미지를 맞은 뒤의 공통 처리(20-2a) - AttackServer.server.lua에 있던
-- "죽었으면 그다음"(경합 가드·보상 지급·despawn)을 뽑아냈다. 평타는 한 번에 대상 하나만
-- 때리지만 스킬(SkillServer.server.lua)은 한 번의 캐스트로 여러 대상을 때릴 수 있어, 이
-- 죽음 처리 로직을 두 곳이 복사해서 쓰면 나중에 하나만 고치고 잊어버릴 위험이 생긴다
-- (19-4가 이미 겪은 "경합 가드"의 섬세함 - MonsterState.tryClaimDeath 순서를 그대로 지켜야
-- 한다). applyDamage 자체(HP 차감)는 호출부가 각자 하고, "죽었으면 그다음"만 여기로 온다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local Loot = require(ReplicatedStorage.Shared.Loot)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)
local TreasureChestConfig = require(ReplicatedStorage.Shared.data.TreasureChestConfig)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local ItemDropState = require(script.Parent.ItemDropState)
local InventorySync = require(script.Parent.InventorySync)
local BossEncounter = require(script.Parent.BossEncounter)
local ImmediateSave = require(script.Parent.ImmediateSave)
local ProtectionTickets = require(script.Parent.ProtectionTickets)
local TutorialState = require(script.Parent.TutorialState)
local PartyState = require(script.Parent.PartyState)
local DropNotice = require(script.Parent.DropNotice)
-- P2 G: 불러오는 순간 PartyState에 파티 경험치 조건 판정을 등록한다(경험치 지급 경로가 이 모듈을 지난다).
require(script.Parent.PartyExpBonus)

local CombatResolution = {}

-- 강화 재료 획득 알림(28-1 S04) - 재료는 골드처럼 즉시 지급이라 "방금 얼마를 받았다"는 일회성 연출 신호(클라 MaterialHud)만 보낸다. 보유량 자체는
-- Attribute(PlayerProfile)가 유일한 소스다.
local materialGained = Instance.new("RemoteEvent")
materialGained.Name = "MaterialGained"
materialGained.Parent = ReplicatedStorage

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

-- 보스 장비 드랍 통계(검증용 카운터 - GroundProbe.stats와 같은 결) - 두 시점의 차로 "가방 직행 몇 번 · 땅에 몇 번 ·
-- 가득 알림 몇 번"을 읽는다.
local dropStats = { toBag = 0, toGround = 0, fullNotices = 0 }

function CombatResolution.dropStats()
	return dropStats.toBag, dropStats.toGround, dropStats.fullNotices
end

-- 보스 장비 드랍은 땅이 아니라 가방으로 바로 간다(PRD 20.81 [C-1]) - 보스 처치 직후 멤버 전원이 사냥터로 돌아가서
-- 아레나 땅에 남은 드랍은 주울 수 없었다. 성공하면 줍기와 같은 ItemPickedUp(획득 팝업)을 쏜다. 가방이 가득이면 false를
-- 돌려주고 호출부가 deferred에 담는다 - 땅에 떨어뜨리는 일은 복귀 텔레포트 뒤(flushDeferredBossDrops)다.
local function deliverBossDropToBag(recipient, item)
	if not PlayerProfile.addArmorDrop(recipient, item) then
		return false
	end
	-- ItemPickedUp은 ItemDropServer가 만든 인스턴스를 그대로 쓴다(새 이벤트를 만들지 않는다).
	local pickedUp = ReplicatedStorage:FindFirstChild("ItemPickedUp")
	if pickedUp then
		pickedUp:FireClient(recipient, item)
		dropStats.toBag += 1
	end
	return true
end

-- 가방이 가득이라 못 넣은 보스 드랍을 "그 사람이 사냥터로 돌아간 자리의 발밑"에 떨어뜨린다. handleBossDeath가
-- BossEncounter.clearForModel(멤버 전원 복귀 텔레포트) 뒤에 부른다 - 텔레포트 전에 부르면 아레나에 떨어진다. 알림은 여기서
-- 한 번 보내고, 모델에는 "알림 끝" 표시를 남겨 줍기 판정(ItemDropServer)이 같은 알림을 또 보내지 않게 한다.
local function flushDeferredBossDrops(deferred, fallbackPosition)
	for _, entry in ipairs(deferred) do
		local player = entry.player
		if player.Parent then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local model = ItemDropSpawner.spawn(entry.item, root and root.Position or fallbackPosition, player)
			ItemDropState.setFullNotified(model, true)
			InventorySync.notifyFull(player)
			dropStats.toGround += 1
			dropStats.fullNotices += 1
		end
	end
end

-- 강화 재료 지급 1인분(28-1 S04) - killUnits = 이 처치가 "몇 마리분"인가(호출부가 정한다). 기대 개수는 받는 사람의 스테이지(minStage 게이트) ·
-- 경험치 배수(PlayerProfile.getExpGainMultiplier)로 정해지고(Loot.rollMaterialDrops), 땅이 아니라 즉시 프로필에 들어간다. 돌려주는 값 =
-- { [재료 id] = 개수 }(검증이 읽는다). 호출부가 grantKillReward · handleChestBreak라 기여 10% 게이트를 자동으로 탄다.
local function grantMaterials(recipient, recipientStage, killUnits)
	local drops = Loot.rollMaterialDrops(recipientStage, killUnits, PlayerProfile.getExpGainMultiplier(recipient))
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		local count = drops[materialId]
		if count then
			PlayerProfile.addMaterial(recipient, materialId, count)
			materialGained:FireClient(recipient, materialId, count)
		end
	end
	return drops
end

-- 처치 보상 지급 1인분(19-4 [2]) - 보스(단독 수령)와 잡몹(기여자 각자)이 똑같이 이 함수
-- 하나로 받는다. AttackServer.server.lua의 grantKillReward를 그대로 옮겼다(동작 변경 없음).
-- deferredBossDrops(보스 전용) - 가방이 가득이라 땅으로 가야 하는 보스 장비를 담는 목록. 호출부가 복귀 텔레포트 뒤에 비운다.
local function grantKillReward(recipient, target, monsterData, deathPosition, deferredBossDrops)
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

	-- 28-1 S04: 강화 재료. 마릿수분 = 잡몹 tier r^p × 접두사(골드와 같은 배율) / 보스 hpMultiplier(20) / 반짝이 자기 몫 + 보너스(goldBonusKillEquivalent).
	-- 견습 중에는 recipientStage(견습 단계의 스테이지)가 minStage 미만이라 자연히 안 나온다 - 별도 분기 없음.
	local killUnits
	if isBoss then
		killUnits = BossData.bosses[monsterData.id].hpMultiplier
	elseif isSparkle then
		killUnits = MonsterState.getKillUnits(target) + RareMonsterConfig.goldBonusKillEquivalent
	else
		killUnits = MonsterState.getKillUnits(target)
	end
	grantMaterials(recipient, recipientStage, killUnits)

	-- 26-1: 드랍 옵션의 직업 특화 후보는 "그 순간 플레이어의 직업"(PRD 20.67 [1]).
	local classId = PlayerProfile.getClassId(recipient)

	-- 28-1(S01): 드랍 기준은 캐릭터 레벨이 아니라 스테이지다(dropStage - 보스는 보스 스테이지, 그 밖은 받는 사람 자신의
	-- 스테이지). 잡몹은 0개 이상의 배열이 돌아온다(기대 개수가 1을 넘으면 여러 개).
	local armorDrops
	if isBoss then
		-- 20-4 [1]: "그 스테이지 보스를 처음 깼는가"로 분기한다. 첫 처치는 등급을 끌어올린 확정 드랍
		-- (Loot.rollBossFirstClearDrop), 재도전은 등급 상승 없는 확정 1개(Loot.rollBossRetryDrop, 28-1 [2-2]).
		-- 재입장 자체는 막지 않는다(지시 원문) - 막는 것은 등급 상승뿐이다.
		local stage = monsterData.stageNumber
		if PlayerProfile.hasBossFirstClearReward(recipient, stage) then
			armorDrops = { Loot.rollBossRetryDrop(dropStage, classId) }
		else
			armorDrops = { Loot.rollBossFirstClearDrop(dropStage, PlayerProfile.getRebirthCount(recipient), classId) }
			PlayerProfile.markBossFirstClearReward(recipient, stage)
		end
	elseif isSparkle then
		armorDrops = { Loot.rollSparkleArmorDrop(dropStage, monsterData.tierIndex, classId) }
	else
		-- 접두사 변종(22-2 [1]) - 기대 드랍 개수에도 보상 배율(= HP 배율)을 곱한다(공평성).
		-- P2 E1 · E3: 태초 확률 = DropTable.effectiveRate(받는 사람의 활성 직업 최고 스테이지, 몬스터 tier, 받는 사람의 사냥 스테이지) - 조회 API와 같은 함수.
		local primordialRate = DropTable.effectiveRate({ bestStage = PlayerProfile.getInfiniteStageBest(recipient) }, { tierIndex = monsterData.tierIndex }, dropStage)
		armorDrops = Loot.rollArmorDrop(dropStage, monsterData.tierIndex, MonsterState.getRewardMultiplier(target), classId, primordialRate)
	end
	for _, armorDrop in ipairs(armorDrops) do
		-- 30-0 S10: 굴려진 순간의 파티원 드랍 알림(PRD 20.73 [5-3]) - 땅 스폰 · 가방 직행 둘 다의 앞이다. 이 함수만 부른다(견습 지급 · 대여 · 분해 · 상점은 여기를 안 탄다).
		DropNotice.publish(recipient, armorDrop)
		local kind = isBoss and "보스" or (isSparkle and "반짝이" or "잡몹")
		if isBoss then
			-- 28-1 [C-1]: 보스 장비는 가방으로 직행한다. 가득이면 복귀 뒤 발밑(flushDeferredBossDrops).
			local inBag = deliverBossDropToBag(recipient, armorDrop)
			if not inBag then
				table.insert(deferredBossDrops, { player = recipient, item = armorDrop })
			end
			print(("[forge-game] 드랍: %s등급 %s (%s) → %s"):format(armorDrop.grade, armorDrop.part, kind, inBag and "가방" or "땅(가방 가득)"))
		else
			ItemDropSpawner.spawn(armorDrop, deathPosition, recipient)
			print(("[forge-game] 드랍: %s등급 %s (%s)"):format(armorDrop.grade, armorDrop.part, kind))
		end
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
	local deferredBossDrops = {}
	for _, member in ipairs(candidates) do
		local ratio = contributions[member] or 0
		if member.Parent and ratio >= CombatConfig.contributionRewardThreshold then
			grantKillReward(member, target, monsterData, deathPosition, deferredBossDrops)
			-- 28-1 S05: 보스 방지권 - 계정 단위 첫 클리어(직업별 bossFirstClearStages와 별개). 기여 10%를 넘긴 수령자만 여기까지 온다. 지급은 바로 아래 즉시 저장 요청에 실린다.
			ProtectionTickets.grantForBoss(member, monsterData.stageNumber)
			-- 30-0 S11: 보스 도감 도장 - 새로 찍힌 것은 아래 즉시 저장 요청에 실린다(견습 보스는 이 함수를 안 탄다).
			PlayerProfile.markBossCodex(member, monsterData.id)
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
	-- 28-1 [C-1]: 가방이 가득이라 못 넣은 장비는 멤버 전원이 사냥터로 돌아간 "뒤"에 그 발밑에 떨어뜨린다(위 clearForModel이 텔레포트).
	flushDeferredBossDrops(deferredBossDrops, BossEncounter.huntingGroundReturnPosition())
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
			-- 28-1 S04: 상자는 골드와 같은 "goldKillEquivalent(30)마리분" 재료도 준다(때린 사람 각자, 받는 사람의 스테이지 기준).
			grantMaterials(hitter, stage, TreasureChestConfig.goldKillEquivalent)
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
	-- P2.5a D(결정 10): 파티 경험치의 "최근 활동" = 적에게 실제로 명중한 순간(평타 · 스킬 모두 여기로 온다). 구출 대상(피해 0 · 적 아님)은 세지 않는다.
	if attacker and not MonsterState.isRescueTarget(target) then
		PartyState.noteActivity(attacker)
	end
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
