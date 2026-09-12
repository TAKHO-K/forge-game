-- 플레이어 영구 저장 데이터(골드 등) 단일 관리 통로. PlayerState(전투 중 HP)와 일부러
-- 분리했다 - HP는 리스폰마다 초기화되지만 골드는 그러면 안 된다. 같은 테이블에 두면
-- PlayerState.reset() 같은 리스폰 훅이 실수로 같이 건드릴 위험이 생긴다.
-- 실제 로드/저장(DataStore)은 SaveSystem이 한다 - 이 모듈은 서버 메모리에 올라온
-- 프로필을 들고 있다가 값을 읽고 쓰는 것만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loot = require(ReplicatedStorage.Shared.Loot)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local InventorySync = require(script.Parent.InventorySync)

local PlayerProfile = {}

-- 9-1이 확정한 StarterPlayer.CharacterWalkSpeed 기본값 - 신발 배율(16-6)의 기준점이다.
local BASE_WALK_SPEED_STUDS = 16

-- [Player] = profile 테이블(SaveSystem.defaultProfile()/migrate()와 같은 스키마)
local profiles = {}

-- 로드가 끝난 뒤(SaveServer.server.lua) 호출한다. Gold·WeaponLevel Attribute도 여기서
-- 같이 맞춰서 HUD·강화 UI가 접속 직후부터 정확한 값을 보게 한다.
function PlayerProfile.init(player, profile)
	profiles[player] = profile
	player:SetAttribute("Gold", profile.gold)
	player:SetAttribute("WeaponLevel", profile.equipment.weapon.level)
	-- 캐릭터 레벨(13-2) - 저장에는 누적 경험치만 있고 레벨은 항상 여기서 파생시킨다(단일
	-- 소스 원칙, InfiniteStage의 stage/multiplier 관계와 같은 구조).
	player:SetAttribute("CharacterExp", profile.characterExp)
	player:SetAttribute("CharacterLevel", CharacterLevel.getLevelFromExp(profile.characterExp))
	-- Attribute는 nil을 담지 못한다 - "선택 안 함"을 빈 문자열로 옮긴다. 클라이언트
	-- (ClassSelectUI.client.lua)는 "" 또는 미설정을 "선택 안 함"으로 취급한다.
	player:SetAttribute("ClassId", profile.classId or "")
	-- 무한 모드 스테이지(11-1). 둘 다 nil일 수 없는 필드라(SaveSystem.migrate v4 참고)
	-- classId처럼 빈 문자열로 바꿔치기할 필요가 없다.
	player:SetAttribute("InfiniteStage", profile.stageProgress.infinite)
	player:SetAttribute("InfiniteStageBest", profile.stageProgress.infiniteBest)
	-- 최고로 깬 보스 스테이지(15-1). StageServer의 게이트 검사가 쓰는 값과 같은 소스다.
	player:SetAttribute("BestBossCleared", profile.stageProgress.bestBossCleared)
	-- 신발 배율(16-6) - 로드된 저장에 이미 신발이 있을 수 있으니 접속 직후 한 번 맞춘다.
	PlayerProfile.refreshMovementSpeed(player)
end

-- 저장 시점에 SaveSystem이 통째로 넘겨받아 쓴다.
function PlayerProfile.getProfile(player)
	return profiles[player]
end

function PlayerProfile.getGold(player)
	local profile = profiles[player]
	return profile and profile.gold
end

-- 서버만 호출한다(AttackServer의 몬스터 처치 판정 직후). 클라이언트가 보낸 값으로
-- 골드를 늘리는 경로는 없다 - 이 함수가 유일한 증가 통로다.
function PlayerProfile.addGold(player, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.gold += amount
	player:SetAttribute("Gold", profile.gold)
end

-- 골드가 충분하면 차감하고 true, 부족하면 아무것도 바꾸지 않고 false(10-2 [3] - 확인과
-- 차감을 분리하면 그 사이에 값이 바뀔 여지가 생긴다. 여긴 한 함수 안에서 원자적으로 처리).
function PlayerProfile.trySpendGold(player, amount)
	local profile = profiles[player]
	if not profile or profile.gold < amount then
		return false
	end
	profile.gold -= amount
	player:SetAttribute("Gold", profile.gold)
	return true
end

function PlayerProfile.getCharacterLevel(player)
	local profile = profiles[player]
	return profile and CharacterLevel.getLevelFromExp(profile.characterExp)
end

-- 서버만 호출한다(AttackServer의 몬스터 처치 판정 직후, 골드와 같은 경로). 클라이언트가
-- 보낸 값으로 경험치를 늘리는 경로는 없다 - 이 함수가 유일한 증가 통로다. 레벨업이
-- 일어났으면(oldLevel ~= newLevel) 호출부가 그 사실로 연출(레벨업 알림)을 띄운다 -
-- 이 함수 자체는 판정만 하고 연출은 모른다(단일 책임, AttackServer가 RemoteEvent를 쏜다).
function PlayerProfile.addCharacterExp(player, amount)
	local profile = profiles[player]
	if not profile then
		return nil, nil
	end
	local oldLevel = CharacterLevel.getLevelFromExp(profile.characterExp)
	profile.characterExp += amount
	local newLevel = CharacterLevel.getLevelFromExp(profile.characterExp)
	player:SetAttribute("CharacterExp", profile.characterExp)
	if newLevel ~= oldLevel then
		player:SetAttribute("CharacterLevel", newLevel)
	end
	return oldLevel, newLevel
end

function PlayerProfile.getWeapon(player)
	local profile = profiles[player]
	return profile and profile.equipment.weapon
end

-- 서버만 호출한다(EnhanceServer의 강화 판정 직후). 클라이언트가 보낸 값을 믿지 않는다.
function PlayerProfile.setWeaponLevel(player, level)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.equipment.weapon.level = level
	player:SetAttribute("WeaponLevel", level)
end

function PlayerProfile.getClassId(player)
	local profile = profiles[player]
	return profile and profile.classId
end

-- 서버만 호출한다(ClassServer의 검증 직후). 클라이언트가 보낸 classId를 그대로 믿지 않는다 -
-- 존재하는 클래스인지는 호출부(ClassServer.server.lua)가 ClassData로 이미 확인했다.
function PlayerProfile.setClassId(player, classId)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.classId = classId
	player:SetAttribute("ClassId", classId)
end

function PlayerProfile.getInfiniteStage(player)
	local profile = profiles[player]
	return profile and profile.stageProgress.infinite
end

function PlayerProfile.getInfiniteStageBest(player)
	local profile = profiles[player]
	return profile and profile.stageProgress.infiniteBest
end

-- 서버만 호출한다(StageServer의 검증 직후). 새 최고 기록을 세웠으면 true를 돌려준다 -
-- 호출부가 그때만 즉시저장(ImmediateSave)을 건다. 단순 이동(현재 스테이지 변경)은
-- 골드처럼 잃을 자원이 없는 되돌릴 수 있는 사건이라 주기저장(60초)·퇴장저장으로
-- 충분하다고 판단했다 - 최고 기록만 "다시 오르면 그만"이 아니라 경쟁 축(PRD 20.12)의
-- 실제 성취라 크래시로 잃으면 아쉬움이 다르다.
function PlayerProfile.setInfiniteStage(player, stage)
	local profile = profiles[player]
	if not profile then
		return false
	end
	profile.stageProgress.infinite = stage
	player:SetAttribute("InfiniteStage", stage)

	local isNewBest = stage > profile.stageProgress.infiniteBest
	if isNewBest then
		profile.stageProgress.infiniteBest = stage
		player:SetAttribute("InfiniteStageBest", stage)
	end
	return isNewBest
end

function PlayerProfile.getBestBossCleared(player)
	local profile = profiles[player]
	return profile and profile.stageProgress.bestBossCleared
end

-- 서버만 호출한다(AttackServer의 보스 처치 판정 직후). stage가 이미 기록된 값 이하면
-- 아무것도 안 한다 - 이 값은 "최고 기록"이라 내려갈 일이 없다(infiniteBest와 같은 원칙).
function PlayerProfile.setBossCleared(player, stage)
	local profile = profiles[player]
	if not profile or stage <= profile.stageProgress.bestBossCleared then
		return
	end
	profile.stageProgress.bestBossCleared = stage
	player:SetAttribute("BestBossCleared", stage)
end

function PlayerProfile.getInventory(player)
	local profile = profiles[player]
	return profile and profile.inventory
end

-- 부위 무관 공용 조회(16-6, EquipSlots.order의 아무 부위나 받는다).
function PlayerProfile.getEquipped(player, part)
	local profile = profiles[player]
	return profile and profile.equipment[part]
end

function PlayerProfile.getEquippedArmor(player)
	return PlayerProfile.getEquipped(player, "armor")
end

-- 신발 이동+공속 비율 보너스(16-6). 미착용이면 0(Loot.getShoesSpeedPercent가 nil을 그렇게
-- 처리한다).
function PlayerProfile.getSpeedPercentBonus(player)
	local profile = profiles[player]
	return Loot.getShoesSpeedPercent(profile and profile.equipment.shoes)
end

-- 장갑 공격력 비율 보너스(16-6). AttackServer가 PlayerCombat.getAttack에 그대로 넘긴다.
function PlayerProfile.getAttackPercentBonus(player)
	local profile = profiles[player]
	return Loot.getGlovesAttackPercent(profile and profile.equipment.gloves)
end

-- 신발 착용/해제·로드 직후마다 호출한다(16-6) - 실제 이동속도(Humanoid.WalkSpeed)와
-- 클라이언트가 공격 쿨다운 예측에 쓰는 Attribute를 같이 맞춘다. 캐릭터가 아직 없으면
-- (로드 중·리스폰 사이) WalkSpeed는 건너뛴다 - 아래 PlayerAdded/CharacterAdded 훅이
-- 캐릭터가 생기는 시점에 다시 불러 결국 맞춰준다.
function PlayerProfile.refreshMovementSpeed(player)
	local bonus = PlayerProfile.getSpeedPercentBonus(player)
	player:SetAttribute("SpeedPercentBonus", bonus)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = BASE_WALK_SPEED_STUDS * PlayerCombat.getSpeedMultiplier(bonus)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		-- 리스폰마다 WalkSpeed가 로블록스 기본값으로 되돌아간다 - 신발 배율을 매번 다시 건다.
		PlayerProfile.refreshMovementSpeed(player)
	end)
end)

-- 서버만 호출한다(14-1부터 ItemDropServer.server.lua의 줍기 판정 직후 - 12-1 시점엔
-- AttackServer의 드랍 판정 직후 바로 호출했으나, 14-1이 "바닥에 떨어뜨리고 나중에 줍는다"로
-- 바꾸면서 호출 시점이 옮겨졌다). 칸이 가득 찼으면 false - 인벤토리에 반영하지 않는다.
-- 14-1부터는 이게 "드랍 자체가 취소된다"는 뜻이 아니다 - 땅의 아이템은 그대로 남아
-- 나중에 칸을 비우고 다시 주우러 오면 된다(호출부가 알림을 준다).
function PlayerProfile.addArmorDrop(player, item)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if #profile.inventory >= profile.inventorySlots then
		return false
	end
	table.insert(profile.inventory, item)
	InventorySync.push(player, profile)
	return true
end

-- 서버만 호출한다(InventoryServer의 검증 직후). index는 인벤토리 배열의 1부터 시작하는
-- 위치 - 그 자리 아이템을 착용하고, 기존에 그 부위에 착용 중이던 아이템(있다면)은
-- 인벤토리로 되돌린다. 먼저 빼고 나중에 넣으므로(순서 고정) 칸 수가 항상 그대로 맞아
-- 용량 검사가 필요 없다 - 착용은 "교체"일 뿐 순수 추가가 아니다. 어느 부위에 착용할지는
-- item.part를 그대로 읽는다(16-6부터 갑옷·장갑·신발 3부위 전부 이 함수 하나로 처리 -
-- 이전엔 equipArmor로 갑옷만 다뤘다).
function PlayerProfile.equipItem(player, index)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local item = profile.inventory[index]
	if not item or not item.part then
		return false
	end

	local part = item.part
	table.remove(profile.inventory, index)
	local previous = profile.equipment[part]
	if previous then
		table.insert(profile.inventory, previous)
	end
	profile.equipment[part] = item

	InventorySync.push(player, profile)
	if part == "shoes" then
		PlayerProfile.refreshMovementSpeed(player)
	end
	return true
end

-- 서버만 호출한다. part(갑옷/장갑/신발) 착용을 해제해 인벤토리로 되돌린다 - 순수 추가라
-- 칸이 가득 차 있으면 실패한다(false, "full") - 벗을 자리가 없으면 벗을 수 없다.
function PlayerProfile.unequipItem(player, part)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local current = profile.equipment[part]
	if not current then
		return false, "not_equipped"
	end
	if #profile.inventory >= profile.inventorySlots then
		return false, "full"
	end

	profile.equipment[part] = nil
	table.insert(profile.inventory, current)

	InventorySync.push(player, profile)
	if part == "shoes" then
		PlayerProfile.refreshMovementSpeed(player)
	end
	return true
end

-- 서버만 호출한다(InventoryServer의 SellRequest 처리 직후, 13-1). 잠긴 아이템은 개별 판매도 막는다([2] 판단 -
-- 오클릭 방지가 목적이라면 일괄 판매만 막아서는 부족하다, 개별 판매 버튼도 같은 위험이 있다).
-- 성공하면 실제로 받은 골드(0 이상의 수)를, 실패하면 false + 이유("not_found"/"locked")를
-- 돌려준다 - 판매 자체는 되돌릴 수 없는 사건이라 호출부가 성공 시 ImmediateSave를 건다.
-- 이름이 sellArmor였다가 sellItem으로 바뀌었다(16-6) - 인벤토리엔 이제 갑옷 말고도
-- 장갑·신발이 들어오는데, index 하나로 아무 부위나 파는 로직 자체는 원래도 부위를
-- 몰랐다(item.grade만 본다) - 이름만 실제 동작을 안 속이게 고쳤다.
function PlayerProfile.sellItem(player, index)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local item = profile.inventory[index]
	if not item then
		return false, "not_found"
	end
	if item.locked then
		return false, "locked"
	end

	local price = Loot.getSellPrice(item)
	table.remove(profile.inventory, index)
	profile.gold += price
	player:SetAttribute("Gold", profile.gold)
	InventorySync.push(player, profile)
	return price
end

-- 서버만 호출한다(13-1). "gradeId 등급 이하 전부" 일괄 판매 - ArmorData.gradeOrder의 순서를
-- 기준으로 삼는다(지금은 normal/rare 2종뿐이라 gradeId="normal"이면 일반만, "rare"면 전부).
-- 잠긴 아이템은 대상에서 제외한다. 파는 아이템 목록·총 골드를 먼저 전부 계산한 뒤 한 번에
-- 반영한다(중간에 task.wait 등 yield 지점이 없다 - 다른 요청이 이 사이에 끼어들 수 없으므로
-- "절반만 팔리는" 상태가 구조적으로 생기지 않는다). 반환값: (판매 개수, 총 골드).
function PlayerProfile.sellItemsBulkUpTo(player, gradeId)
	local profile = profiles[player]
	if not profile then
		return 0, 0
	end

	local cutoffIndex
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			cutoffIndex = i
			break
		end
	end
	if not cutoffIndex then
		return 0, 0
	end

	local remaining = {}
	local totalGold = 0
	local soldCount = 0
	for _, item in ipairs(profile.inventory) do
		local itemGradeIndex
		for i, id in ipairs(ArmorData.gradeOrder) do
			if id == item.grade then
				itemGradeIndex = i
				break
			end
		end
		if not item.locked and itemGradeIndex and itemGradeIndex <= cutoffIndex then
			totalGold += Loot.getSellPrice(item)
			soldCount += 1
		else
			table.insert(remaining, item)
		end
	end

	if soldCount == 0 then
		return 0, 0
	end

	profile.inventory = remaining
	profile.gold += totalGold
	player:SetAttribute("Gold", profile.gold)
	InventorySync.push(player, profile)
	return soldCount, totalGold
end

-- 서버만 호출한다(13-1). 잠금은 착용/해제와 같은 되돌릴 수 있는 사건이라(다시 누르면 그만)
-- 즉시저장하지 않는다.
function PlayerProfile.setItemLocked(player, index, locked)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local item = profile.inventory[index]
	if not item then
		return false
	end
	item.locked = locked
	InventorySync.push(player, profile)
	return true
end

function PlayerProfile.clear(player)
	profiles[player] = nil
end

return PlayerProfile
