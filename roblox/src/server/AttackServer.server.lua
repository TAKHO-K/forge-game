-- 서버 권위 공격 판정. 클라이언트는 "공격하겠다"는 의사 + 조준점(aimPoint, 16-7)만
-- 보낸다 - 사거리 검증·대상 선정·쿨다운 관리·데미지 계산은 전부 여기서만 한다. aimPoint는
-- "어느 방향으로 대상을 고를지"에만 쓰이는 힌트일 뿐(아래 AimPicker.pick), 사거리·데미지·
-- 최종 대상 확정은 클라이언트 값을 그대로 믿지 않고 항상 서버가 다시 계산한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local AimPicker = require(ReplicatedStorage.Shared.AimPicker)
local Loot = require(ReplicatedStorage.Shared.Loot)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local BossEncounter = require(script.Parent.BossEncounter)
local ImmediateSave = require(script.Parent.ImmediateSave)

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

-- 3타 강타(16-7, 웹 main.js comboCount/comboResetWindow와 동일 값 CombatConfig 참고).
-- 헛스윙도 콤보에 들어간다 - 웹 performAttack()이 대상 유무와 무관하게 매 공격 입력마다
-- comboCount를 올리는 것과 같다.
local comboCounts = {} -- [Player] = number
local lastComboAttackTick = {} -- [Player] = os.clock() 시각

local comboUpdate = Instance.new("RemoteEvent")
comboUpdate.Name = "ComboUpdate"
comboUpdate.Parent = ReplicatedStorage

attackRequest.OnServerEvent:Connect(function(player, aimPoint)
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
	-- 신발 공속 보너스(16-6) - 미착용이면 PlayerProfile.getSpeedPercentBonus가 0을 돌려줘
	-- 기존과 똑같이 계산된다.
	local cooldown = PlayerCombat.getAttackCooldown(classId, PlayerProfile.getSpeedPercentBonus(player))
	if last and now - last < cooldown then
		return -- 쿨다운이 안 지났다 - 조용히 무시
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	lastAttackTick[player] = now -- 헛스윙이어도 쿨다운은 소모한다
	-- 19-1: 공격 시도(헛스윙 포함)도 "전투 중"이다 - 자동회복이 싸우는 동안엔 켜지지
	-- 않아야 한다(PlayerRegen.server.lua 주석 참고).
	PlayerState.setLastCombatActionAt(player, now)

	-- 3타 강타 콤보 카운터 - 헛스윙도 포함해 이 시점에서 갱신한다(웹과 동일 지점).
	local lastCombo = lastComboAttackTick[player]
	if not lastCombo or now - lastCombo > CombatConfig.comboResetWindowSeconds then
		comboCounts[player] = 0
	end
	comboCounts[player] += 1
	lastComboAttackTick[player] = now
	local isComboHit = comboCounts[player] % CombatConfig.comboHitEvery == 0
	comboUpdate:FireClient(player, comboCounts[player], isComboHit)

	-- aimPoint는 클릭·탭한 지점(AttackInput.client.lua) - 서버 검증: Vector3가 아니면
	-- 무시한다(지시 - "클라가 보낸 방향을 그대로 믿으면 안 된다"). 방향이 없거나 이상한
	-- 값이면 AimPicker가 사거리 안 최근접으로 대체하므로 안전하게 실패한다. 사거리·데미지는
	-- 이 값과 무관하게 아래에서 항상 서버가 다시 계산한다.
	local safeAimPoint = typeof(aimPoint) == "Vector3" and aimPoint or nil
	local target = AimPicker.pick(rootPart.Position, safeAimPoint, CombatConfig.attackRangeStuds, MonsterState.getAllModels())
	if not target then
		return -- 사거리 안에 몬스터가 없다 - 헛스윙
	end

	-- 공격력 = 무기 기본값 × 강화 배율 × 등급 배율 × 클래스 배율 × 캐릭터 레벨계수(10-2 [1],
	-- 10-3 [3], 13-2에서 레벨계수가 들어갔다) × (1+장갑 공격력%, 16-6) × 3타 강타 배율(16-7,
	-- 웹 main.js "attack = getPlayerAttack() * (isComboHit ? comboHitMultiplier : 1)"과 같은
	-- 순서 - 치명타 판정보다 먼저 곱한다). 배율이 곱해지는 지점은 PlayerCombat 하나뿐이다.
	-- 치명타(10-4)는 이 base를 calcDamage에 넘겨서 판정한다 - 판정도 서버 여기 한 곳뿐이다.
	local characterLevel = PlayerProfile.getCharacterLevel(player)
	local base = PlayerCombat.getAttack(weapon, classId, characterLevel, PlayerProfile.getAttackPercentBonus(player))
	if isComboHit then
		base *= CombatConfig.comboHitMultiplier
	end
	local damage, isCrit = PlayerCombat.calcDamage(base, classId)
	local newHp = MonsterState.getHp(target) - damage
	MonsterState.setHp(target, newHp)
	MonsterSpawner.updateHpLabel(target)

	-- died(14-2)를 같이 보낸다 - 클라이언트가 사망 연출(HitEffects.playDeath)을 정확히
	-- 이 타격에서만 재생하려면 "이 타격으로 죽었는가"를 알아야 한다. isComboHit(16-7)은
	-- 클라이언트가 강타 전용 피드백(히트스톱·카메라 흔들림·확대된 스윙)을 이 타격에서만
	-- 재생하도록 같이 보낸다.
	attackResult:FireClient(player, target, damage, isCrit, newHp <= 0, isComboHit)

	if newHp <= 0 then
		-- 처치 경합 가드(15-1 검증 중 재현) - 연타로 두 AttackRequest가 같은 처치 직전
		-- 몬스터를 거의 동시에 때리면, 뒤 이은 ImmediateSave.request(DataStore 호출로 실제
		-- yield한다)가 끝나기 전에 두 번째 요청이 여기 도달해 골드·경험치·드랍을 이중
		-- 지급하는 경합이 실제로 재현됐다. MonsterState.tryClaimDeath는 확인과 표시를
		-- 한 번에 처리해(그 사이 yield 없음) 오직 첫 번째 요청만 통과시킨다 - 뒤따르는
		-- 요청은 조용히 물러난다(이미 처리된 처치이므로 보상도, 로그도 다시 내지 않는다).
		if not MonsterState.tryClaimDeath(target) then
			return
		end

		-- despawn이 MonsterState.clear를 즉시 호출해 데이터를 지우므로, 그 전에 골드값·경험치·
		-- 스테이지를 먼저 읽는다. getGoldDrop·getExpReward는 무한 모드 스테이지 배율(11-1)이
		-- 적용된 값이다(보스는 그 위에 BossRules.buildInstanceData가 미리 곱해 둔 배율까지
		-- 포함된 최종값 - 15-1, MonsterState.setStage의 isBoss 가드 참고).
		local monsterData = MonsterState.getData(target)
		local isBoss = monsterData.isBoss
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
		-- 보스는 확정 드랍(15-1, 지시 [4]) - 잡몹과 같은 25% 확률·등급 굴림을 쓰지 않는다.
		-- 잡몹은 자기 tier(16-6, 17-1부터 드랍표에 실제로 연결)의 등급 확률표를 쓴다 - 보스는
		-- 항상 tier1 기준(Loot.rollBossArmorDrop 내부에서 고정)이라 tierIndex를 안 넘긴다.
		local armorDrop = isBoss
			and Loot.rollBossArmorDrop(dropStage, newLevel or oldLevel)
			or Loot.rollArmorDrop(dropStage, newLevel or oldLevel, monsterData.tierIndex)
		if armorDrop then
			ItemDropSpawner.spawn(armorDrop, deathPosition, player)
		end

		if isBoss then
			-- 보스 처치 기록(15-1) - 이 스테이지 이상으로 이동을 막던 게이트(StageServer)가
			-- 이제부터 풀린다. infiniteBest와 같은 "다시 오르면 그만이 아닌 실제 성취"라
			-- 즉시저장한다.
			PlayerProfile.setBossCleared(player, monsterData.stageNumber)
			ImmediateSave.request(player)
			BossEncounter.clearFor(player)
			print(("[forge-game] 보스 처치: %s - 스테이지 %d"):format(player.Name, monsterData.stageNumber))
		end

		MonsterSpawner.despawn(target)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackTick[player] = nil
	comboCounts[player] = nil
	lastComboAttackTick[player] = nil
end)
