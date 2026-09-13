-- 서버 권위 공격 판정. 클라이언트는 "공격하겠다"는 의사 + 조준점(aimPoint, 16-7)만
-- 보낸다 - 사거리 검증·대상 선정·쿨다운 관리·데미지 계산은 전부 여기서만 한다. aimPoint는
-- "어느 방향으로 대상을 고를지"에만 쓰이는 힌트일 뿐(아래 AimPicker.pick), 사거리·데미지·
-- 최종 대상 확정은 클라이언트 값을 그대로 믿지 않고 항상 서버가 다시 계산한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local AimPicker = require(ReplicatedStorage.Shared.AimPicker)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local CombatResolution = require(script.Parent.CombatResolution)

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

-- 골드/레벨업 팝업은 SkillServer.server.lua와 공유한다(20-2a) - CombatResolution이
-- 죽음 처리 중 이 두 이벤트를 쏜다.
CombatResolution.init(goldGained, levelUp)

local lastAttackTick = {} -- [Player] = os.clock() 시각

-- 3타 강타(16-7, 웹 main.js comboCount/comboResetWindow와 동일 값 CombatConfig 참고).
-- 헛스윙도 콤보에 들어간다 - 웹 performAttack()이 대상 유무와 무관하게 매 공격 입력마다
-- comboCount를 올리는 것과 같다.
local comboCounts = {} -- [Player] = number
local lastComboAttackTick = {} -- [Player] = os.clock() 시각

local comboUpdate = Instance.new("RemoteEvent")
comboUpdate.Name = "ComboUpdate"
comboUpdate.Parent = ReplicatedStorage

-- 구역 밖 공격 차단 안내(19-4 [4]-나). 조용히 씹으면 버그로 오해한다는 지시 - 스팸
-- 방지로 플레이어당 3초에 한 번만 띄운다(입구에 서서 연타해도 토스트가 겹쳐 뜨지 않게).
local zoneBlockedNotice = Instance.new("RemoteEvent")
zoneBlockedNotice.Name = "ZoneBlockedNotice"
zoneBlockedNotice.Parent = ReplicatedStorage

local ZONE_BLOCKED_NOTICE_THROTTLE_SECONDS = 3
local lastZoneBlockedNoticeAt = {} -- [Player] = os.clock() 시각

local function notifyZoneBlocked(player)
	local now = os.clock()
	local last = lastZoneBlockedNoticeAt[player]
	if last and now - last < ZONE_BLOCKED_NOTICE_THROTTLE_SECONDS then
		return
	end
	lastZoneBlockedNoticeAt[player] = now
	zoneBlockedNotice:FireClient(player, "구역 안으로 들어가야 공격할 수 있습니다")
end

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
	local target = AimPicker.pick(rootPart.Position, safeAimPoint, PlayerCombat.getAttackRange(classId), MonsterState.getAllModels())
	if not target then
		return -- 사거리 안에 몬스터가 없다 - 헛스윙
	end

	-- 구역 밖 공격 차단(19-4 [4]-나) - 담장(HuntingGround.server.lua)이 1차 방어, 이건
	-- 뚫렸을 때의 2차 방어이자 "입구에 서서 안쪽을 쏘는" 행위 자체를 막는 장치다. 클라이언트
	-- 좌표가 아니라 서버가 들고 있는 rootPart.Position으로 판정한다.
	local targetZoneKey = MonsterState.getZoneKey(target)
	if not ZoneBounds.isInside(rootPart.Position, targetZoneKey) then
		notifyZoneBlocked(player)
		return
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

	-- 19-4(C안) - 잡몹은 공유 HP(비율)라 "이 공격자의 stage 기준" 유효 최대체력으로 나눈
	-- 비율만큼만 깎인다(MonsterState.applyDamage 참고). 보스는 기존 그대로 절대값 차감.
	local attackerStage = PlayerProfile.getInfiniteStage(player) or 1
	local isDead = MonsterState.applyDamage(target, damage, attackerStage, player)
	MonsterSpawner.updateHpLabel(target)

	-- died(14-2)를 같이 보낸다 - 클라이언트가 사망 연출(HitEffects.playDeath)을 정확히
	-- 이 타격에서만 재생하려면 "이 타격으로 죽었는가"를 알아야 한다. isComboHit(16-7)은
	-- 클라이언트가 강타 전용 피드백(히트스톱·카메라 흔들림·확대된 스윙)을 이 타격에서만
	-- 재생하도록 같이 보낸다. damage는 이 공격자 본인 기준 절대값 그대로 보여준다(19-4 [1] -
	-- "옆 사람과 숫자가 다른 건 이미 기본값"이라 데미지 숫자는 바꾸지 않는다, HP바만 비율).
	attackResult:FireClient(player, target, damage, isCrit, isDead, isComboHit)

	-- 죽음 처리(경합 가드·보상·despawn)는 CombatResolution이 맡는다(20-2a - 스킬도 같은
	-- 경로를 타야 해서 뽑아냈다). 동작은 그대로다.
	CombatResolution.resolveHit(player, target, isDead)
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackTick[player] = nil
	comboCounts[player] = nil
	lastComboAttackTick[player] = nil
	lastZoneBlockedNoticeAt[player] = nil
	-- 아직 살아있는 몬스터의 기여 기록에 이 플레이어가 남아있으면(퇴장 시점에 전투 중이었던
	-- 경우) 몬스터가 죽을 때까지 계속 남는다 - 떠나는 쪽이 자기 흔적을 지운다(MonsterAI.
	-- server.lua의 releaseChasersOf와 같은 원칙, 19-4 지시 - 이전 nil 비교 사고 반복 금지).
	MonsterState.clearPlayerContributions(player)
end)
