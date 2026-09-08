-- 서버 권위 공격 판정. 클라이언트는 "공격하겠다"는 의사만 보낸다(RemoteEvent 인자 없음) -
-- 사거리 검증·대상 선정·쿨다운 관리·데미지 계산은 전부 여기서만 한다. 클라이언트가 보낸
-- 좌표·대상·데미지 값을 받는 코드는 없다(애초에 그런 인자를 받지 않는다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local Loot = require(ReplicatedStorage.Shared.Loot)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)

local attackRequest = Instance.new("RemoteEvent")
attackRequest.Name = "AttackRequest"
attackRequest.Parent = ReplicatedStorage

local attackResult = Instance.new("RemoteEvent")
attackResult.Name = "AttackResult"
attackResult.Parent = ReplicatedStorage

-- 처치 순간 골드 팝업(10-1)용. 골드 자체는 PlayerProfile.addGold가 Attribute로 이미
-- 동기화한다 - 이 이벤트는 "방금 얼마 벌었다"는 일회성 연출 신호만 보낸다.
local goldGained = Instance.new("RemoteEvent")
goldGained.Name = "GoldGained"
goldGained.Parent = ReplicatedStorage

-- 레벨업 알림(13-2)용. characterExp 자체는 PlayerProfile.addCharacterExp가 Attribute로 이미
-- 동기화한다 - 이 이벤트는 레벨이 실제로 오른 순간에만 쏘는 일회성 연출 신호다(매 처치마다
-- 쏘지 않는다 - goldGained와 다르게 레벨업은 드물다).
local levelUp = Instance.new("RemoteEvent")
levelUp.Name = "LevelUp"
levelUp.Parent = ReplicatedStorage

local lastAttackTick = {} -- [Player] = os.clock() 시각

-- 자동 타겟: 사거리 안에서 가장 가까운 몬스터 하나. 어느 몬스터를 때릴지는
-- 클라이언트가 정하지 않는다 - 여기서만 정한다.
local function findNearestMonsterInRange(originPosition)
	local nearestModel, nearestDistance = nil, math.huge

	for _, model in ipairs(MonsterState.getAllModels()) do
		local rootPart = model.PrimaryPart
		if rootPart then
			local distance = (rootPart.Position - originPosition).Magnitude
			if distance <= CombatConfig.attackRangeStuds and distance < nearestDistance then
				nearestModel, nearestDistance = model, distance
			end
		end
	end

	return nearestModel
end

attackRequest.OnServerEvent:Connect(function(player)
	-- 프로필 로드가 아직 안 끝난 접속 직후, 혹은 클래스를 아직 안 고른 상태에서 공격이
	-- 들어올 수 있다 - 공격력·쿨다운 둘 다 클래스가 있어야 계산할 수 있으니 헛스윙으로
	-- 처리한다(10-3 [3] - 클래스 배율이 실제로 평타에 반영되는 첫 지점).
	local weapon = PlayerProfile.getWeapon(player)
	local classId = PlayerProfile.getClassId(player)
	if not weapon or not classId then
		return
	end

	local now = os.clock()
	local last = lastAttackTick[player]
	local cooldown = PlayerCombat.getAttackCooldown(classId)
	if last and now - last < cooldown then
		return -- 쿨다운이 안 지났다 - 조용히 무시
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	lastAttackTick[player] = now -- 헛스윙이어도 쿨다운은 소모한다

	local target = findNearestMonsterInRange(rootPart.Position)
	if not target then
		return -- 사거리 안에 몬스터가 없다 - 헛스윙
	end

	-- 공격력 = 무기 기본값 × 강화 배율 × 등급 배율 × 클래스 배율 × 캐릭터 레벨계수(10-2 [1],
	-- 10-3 [3], 13-2에서 레벨계수가 들어갔다). 배율이 곱해지는 지점은 PlayerCombat 하나뿐이다.
	-- 치명타(10-4)는 이 base를 calcDamage에 넘겨서 판정한다 - 판정도 서버 여기 한 곳뿐이다.
	local characterLevel = PlayerProfile.getCharacterLevel(player)
	local base = PlayerCombat.getAttack(weapon, classId, characterLevel)
	local damage, isCrit = PlayerCombat.calcDamage(base, classId)
	local newHp = MonsterState.getHp(target) - damage
	MonsterState.setHp(target, newHp)
	MonsterSpawner.updateHpLabel(target)

	attackResult:FireClient(player, target, damage, isCrit)

	if newHp <= 0 then
		-- despawn이 MonsterState.clear를 즉시 호출해 데이터를 지우므로, 그 전에 골드값·경험치·
		-- 스테이지를 먼저 읽는다. getGoldDrop·getExpReward는 무한 모드 스테이지 배율(11-1)이
		-- 적용된 값이다.
		local goldDrop = MonsterState.getGoldDrop(target)
		local expReward = MonsterState.getExpReward(target)
		local dropStage = MonsterState.getStage(target) or 1
		local deathPosition = target.PrimaryPart.Position
		PlayerProfile.addGold(player, goldDrop)
		goldGained:FireClient(player, goldDrop)

		-- 경험치 지급(13-2) - 골드와 같은 경로, 서버만 지급한다. 레벨업이 일어났으면 그
		-- 순간에만 알림을 쏜다(매 처치마다 쏘는 goldGained와 다르게 레벨업은 드문 이벤트).
		-- 아이템 레벨 각인(아래)보다 먼저 지급해야 이번 처치로 오른 레벨이 드랍에 반영된다.
		local oldLevel, newLevel = PlayerProfile.addCharacterExp(player, expReward)
		if newLevel and newLevel ~= oldLevel then
			levelUp:FireClient(player, newLevel)
		end

		-- 갑옷 드랍 판정(12-1 [2], 13-2에서 itemLevel 각인 추가). 서버가 여기서만 굴린다.
		-- 14-1부터 인벤토리에 바로 들어가지 않는다 - 바닥에 떨어뜨리고(ItemDropSpawner),
		-- 실제로 인벤토리에 반영되는 건 줍는 순간(ItemDropServer.server.lua의 거리 판정)이다.
		-- 인벤토리가 가득 찬 경우도 여기서 취소하지 않는다 - "땅에 있는데 못 줍는" 상태로
		-- 남겨 둔다(14-1 판단, ItemDropServer 참고).
		local armorDrop = Loot.rollArmorDrop(dropStage, newLevel or oldLevel)
		if armorDrop then
			ItemDropSpawner.spawn(armorDrop, deathPosition, player)
		end

		MonsterSpawner.despawn(target)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackTick[player] = nil
end)
