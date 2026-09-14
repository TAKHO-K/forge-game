-- 서버 권위 공격 판정. 클라이언트는 "공격하겠다"는 의사 + 조준점(aimPoint, 16-7)만
-- 보낸다 - 사거리 검증·대상 선정·쿨다운 관리·데미지 계산은 전부 여기서만 한다. aimPoint는
-- "어느 방향으로 대상을 고를지"에만 쓰이는 힌트일 뿐(아래 AimPicker.pick), 사거리·데미지·
-- 최종 대상 확정은 클라이언트 값을 그대로 믿지 않고 항상 서버가 다시 계산한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local AttackMotionData = require(ReplicatedStorage.Shared.data.AttackMotionData)
local ProjectileConfig = require(ReplicatedStorage.Shared.data.ProjectileConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local AimPicker = require(ReplicatedStorage.Shared.AimPicker)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local CombatResolution = require(script.Parent.CombatResolution)
local BuffState = require(script.Parent.BuffState)

local attackRequest = Instance.new("RemoteEvent")
attackRequest.Name = "AttackRequest"
attackRequest.Parent = ReplicatedStorage

-- damage/isCrit/isDead/isComboHit는 기존 그대로. missed(20-2b, 신규)가 true면 나머지
-- 필드는 의미 없다(전부 0/false로 채워 보낸다) - 원거리 투사체가 도달 시점에 빗나간
-- 경우에만 true다. 근접(대검·쌍검)은 즉시 판정이라 missed가 아예 안 나온다(항상 false).
local attackResult = Instance.new("RemoteEvent")
attackResult.Name = "AttackResult"
attackResult.Parent = ReplicatedStorage

-- 원거리(활·힐러) 발사 즉시 신호 - 클라가 이 시점에 투사체 시각 재생을 시작한다(20-2b [2]).
-- 실제 피해 판정은 attackResult로 따로, 화살/구슬이 도달하는 시점에 온다 - 이 이벤트는
-- "쐈다"만 알린다.
local attackLaunched = Instance.new("RemoteEvent")
attackLaunched.Name = "AttackLaunched"
attackLaunched.Parent = ReplicatedStorage

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
	-- 기존과 똑같이 계산된다. 활 속사(20-2b [1][3]) - 버프가 없으면 BuffState.getValue가
	-- 기본값 1을 돌려줘 역시 기존과 똑같이 계산된다.
	local buffSpeedMultiplier = BuffState.getValue(player, "quickShot", 1)
	local cooldown = PlayerCombat.getAttackCooldown(classId, PlayerProfile.getSpeedPercentBonus(player), buffSpeedMultiplier)
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
	-- 활 백스텝샷 사거리 버프(20-4 [2]) - 충전이 남아 있는 동안(BuffState.getField가 만료·
	-- 소진된 버프는 자동으로 기본값 1을 돌려준다) 대상 판정 사거리를 넓힌다. 실제 상한은
	-- PlayerCombat.getBuffedAttackRange가 어그로 범위 아래로 자른다(주석 참고).
	local rangeMultiplier = BuffState.getField(player, "backstepShotBuff", "rangeMultiplier", 1)
	local attackRange = PlayerCombat.getBuffedAttackRange(classId, rangeMultiplier)
	local target = AimPicker.pick(rootPart.Position, safeAimPoint, attackRange, MonsterState.getAllModels())
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
	-- 치명타 롤 자체는 여기서(발사 시점) 미리 정한다 - 원거리 투사체 색(화살/구슬)이 발사
	-- 즉시 정해져야 클라가 "맞을지 미리 안다"는 위화감 없이 보인다(Projectiles.lua 원본
	-- 주석과 같은 이유). 실제로 맞는지(도달 시점 재검증)는 아래에서 따로 판단한다.
	local characterLevel = PlayerProfile.getCharacterLevel(player)
	local atk = PlayerCombat.getAttack(weapon, classId, characterLevel, PlayerProfile.getAttackPercentBonus(player))
	local base = atk
	if isComboHit then
		base *= CombatConfig.comboHitMultiplier
	end

	-- 활 백스텝샷(20-2b [1][4], PRD-forge-game.md 4.3) - "다음 평타 5발에 마법피해 추가 +
	-- 그 5발 치명타 확률 +30%p". 버프가 없으면 두 값 다 0이라 기존과 똑같이 계산된다.
	-- 이 평타 하나에 실제로 적용된 순간에만 충전을 소모한다(맞았는지와 무관 - 쐈다는
	-- 사실 자체가 소모 조건이다, 근접도 같은 지점이라 대검/쌍검에 이 버프가 걸릴 일이
	-- 생기면 자동으로 똑같이 동작한다).
	local bonusDamageCoefficient = BuffState.getField(player, "backstepShotBuff", "damageCoefficient", 0)
	local critRateBonus = BuffState.getField(player, "backstepShotBuff", "critRateBonus", 0)
	if bonusDamageCoefficient > 0 or critRateBonus > 0 then
		base += bonusDamageCoefficient * atk
		BuffState.consumeCharge(player, "backstepShotBuff")
	end

	local damage, isCrit = PlayerCombat.calcDamage(base, classId, critRateBonus)
	local attackerStage = PlayerProfile.getInfiniteStage(player) or 1

	local projectileKind = ProjectileConfig.kindByClass[classId]
	if not projectileKind then
		-- 근접(대검·쌍검) - 즉시 판정(기존 동작 그대로, 20-2a까지와 완전히 같다).
		local isDead = MonsterState.applyDamage(target, damage, attackerStage, player)
		MonsterSpawner.updateHpLabel(target)
		attackResult:FireClient(player, target, damage, isCrit, isDead, isComboHit, false)
		CombatResolution.resolveHit(player, target, isDead)
		return
	end

	local targetRootAtLaunch = target.PrimaryPart
	local launchPosition = targetRootAtLaunch and targetRootAtLaunch.Position
	local distance = launchPosition and (launchPosition - rootPart.Position).Magnitude or 0

	-- 벽 차단(20-2b [2]) - aimPoint가 담장 너머 몬스터를 가리켜도 실제로는 못 나간다.
	-- SkillServer.server.lua computeDashEndpoint와 같은 원리(플레이어 자신 + 살아있는
	-- 몬스터 전원을 제외해 담장·지형에만 막히게 한다) - 발사 자체를 취소한다(투사체를
	-- 보여준 다음 중간에 없애면 "왜 사라졌지"가 되므로, 나갈 수 없으면 아예 안 나간다).
	if launchPosition and distance > 0 then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local excluded = { character }
		for _, model in ipairs(MonsterState.getAllModels()) do
			table.insert(excluded, model)
		end
		raycastParams.FilterDescendantsInstances = excluded
		local wallHit = Workspace:Raycast(rootPart.Position, launchPosition - rootPart.Position, raycastParams)
		if wallHit and wallHit.Distance < distance - 1 then
			attackResult:FireClient(player, target, 0, false, false, isComboHit, true)
			return
		end
	end

	-- 원거리(활·힐러, 20-2b [2]) - "클라가 맞았다고 보고하는 구조로 만들지 마라"는 지시대로
	-- 서버가 도달 시점을 직접 계산해 그때 판정한다. 발사는 즉시 알려 클라가 투사체를
	-- 그 순간부터 날아가게 하고(activeLaunched), 실제 피해 적용은 화살/구슬이 도달할
	-- 시점(releaseDelay + travelTime 뒤)까지 미룬다.
	attackLaunched:FireClient(player, target, isCrit)

	-- releaseDelay - 활은 시위를 당기는 예비동작이 끝나야 실제로 발사된다(9-2/14-2,
	-- WeaponVisual.getReleaseDelay와 같은 산식을 공유 정적 데이터로 재계산한다 - 서버는
	-- 클라이언트 애니메이션 상태를 모르므로 "정상적으로 지금 막 스윙을 시작했다"고
	-- 가정한 근사치다. 콤보로 스윙이 끊기고 새로 시작되는 드문 경우엔 클라 쪽 실제
	-- 재생 시점과 몇십ms 어긋날 수 있지만, 피해 판정 자체(누가 맞았는가)에는 영향이 없다).
	local motion = AttackMotionData[classId]
	local releaseDelay = (motion and motion.releaseT) and motion.releaseT * motion.totalDurationSeconds or 0
	local travelTime = distance / ProjectileConfig.speedStudsPerSec[projectileKind]

	task.delay(releaseDelay + travelTime, function()
		-- 도달 시점 재검증. 몬스터가 이미 없어졌으면(다른 공격자가 먼저 죽였거나 despawn)
		-- MonsterState.getData가 nil을 돌려준다 - 조용히 빗나간다.
		local currentRoot = target.Parent and target.PrimaryPart
		if not currentRoot or not MonsterState.getData(target) then
			attackResult:FireClient(player, target, 0, false, false, isComboHit, true)
			return
		end

		-- 비행 중 이동한 거리가 허용 폭(ProjectileConfig.hitToleranceStuds)을 넘으면
		-- 빗나간다 - "몬스터가 움직이므로 빗나갈 수 있다"는 지시를 그대로 구현한다.
		if launchPosition and (currentRoot.Position - launchPosition).Magnitude > ProjectileConfig.hitToleranceStuds then
			attackResult:FireClient(player, target, 0, false, false, isComboHit, true)
			return
		end

		local isDead = MonsterState.applyDamage(target, damage, attackerStage, player)
		MonsterSpawner.updateHpLabel(target)
		attackResult:FireClient(player, target, damage, isCrit, isDead, isComboHit, false)
		CombatResolution.resolveHit(player, target, isDead)
	end)
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
