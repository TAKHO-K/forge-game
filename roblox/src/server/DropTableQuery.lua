-- 드랍표 화면용 조회(P2 E1 - UI는 P4). 같은 몬스터 · 같은 사냥 스테이지 · 같은 플레이어라면 서버의 실제 굴림(CombatResolution → Loot.rollArmorDrop)과
-- 한 자리도 다르지 않은 확률을 돌려준다 - 둘 다 DropTable.effectiveRate · DropTable.gradeRow · Loot.expectedArmorDropCount · Loot.expectedMaterialCount를 부른다.
-- describe는 순수 함수(검증이 합성 입력으로 부른다), forPlayer는 실제 Player의 최고 · 사냥 스테이지 · 경험치 배수를 모아 describe를 부른다(DropTableServer가 쓴다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerProfile = require(script.Parent.PlayerProfile)
local TutorialState = require(script.Parent.TutorialState)

local DropTableQuery = {}

-- 반환: { tierIndex, monsterName, huntStage, bestStage, armorPerKill(접두사 없는 기본형 기준 기대 장비 개수),
--   primordial = { baseRate, levelDecay, effectiveRate }, grades = { { id, chance } … }(ArmorData.gradeOrder 순, 합 1),
--   materials = { { id, perKill } … }(받는 사람 스테이지가 minStage 이상인 재료만) }. tier가 표 밖이면 nil.
function DropTableQuery.describe(playerInfo, tierIndex, huntStage, expGainMultiplier)
	local key = MonsterData.tierOrder[tierIndex]
	if not key then
		return nil
	end
	local monsterInfo = { tierIndex = tierIndex }
	local rate = DropTable.effectiveRate(playerInfo, monsterInfo, huntStage)
	local row = DropTable.gradeRow(tierIndex, rate)
	local grades = {}
	for _, gradeId in ipairs(ArmorData.gradeOrder) do
		if row[gradeId] then
			table.insert(grades, { id = gradeId, chance = row[gradeId] })
		end
	end
	local killUnits = MonsterData[key].rewardRatio ^ MonsterData.fairnessExponent -- MonsterState.getKillUnits의 접두사 없는 값
	local materials = {}
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		if huntStage >= EnhanceMaterialData.materials[materialId].minStage then
			table.insert(materials, { id = materialId, perKill = Loot.expectedMaterialCount(materialId, killUnits, expGainMultiplier or 1) })
		end
	end
	return {
		tierIndex = tierIndex,
		monsterName = MonsterData[key].displayName,
		huntStage = huntStage,
		bestStage = playerInfo.bestStage,
		armorPerKill = Loot.expectedArmorDropCount(tierIndex, 1), -- G1-2: 처치 시간 보정 전(느린 처치 기준 상한) - 실제는 받는 사람의 처치 시간에 따라 × DropTable.timeFairnessFactor
		primordial = {
			baseRate = DropTable.primordialBaseRate(tierIndex),
			levelDecay = DropTable.levelDecay(playerInfo.bestStage, huntStage),
			effectiveRate = rate,
		},
		grades = grades,
		materials = materials,
	}
end

-- 실제 Player 기준(CombatResolution.grantKillReward와 같은 값을 모은다: 사냥 스테이지 = TutorialState.getMonsterStage, 최고 = 활성 직업 infiniteBest).
function DropTableQuery.forPlayer(player, tierIndex)
	local huntStage = TutorialState.getMonsterStage(player)
	return DropTableQuery.describe({ bestStage = PlayerProfile.getInfiniteStageBest(player) }, tierIndex, huntStage, PlayerProfile.getExpGainMultiplier(player))
end

return DropTableQuery
