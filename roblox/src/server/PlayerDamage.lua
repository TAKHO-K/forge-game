-- 플레이어가 몬스터에게 맞았을 때의 피해 계산·적용 단일 통로(21-3). MonsterAI.server.lua에
-- 로컬 함수로 있던 computeHitDamage/applyHitToPlayer/syncHud를 그대로 뽑아냈다 - 보스
-- 패턴(BossPatterns.lua)이 잡몹 평타·강공격과 같은 식으로 피해를 넣어야 하는데, Script인
-- MonsterAI에서는 require로 꺼내 쓸 수 없어서다(CombatResolution.lua가 AttackServer에서
-- 처치 처리를 뽑아낸 것과 같은 이유). 동작은 바꾸지 않았다 - 옮기기만 했다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)
local PlayerShield = require(script.Parent.PlayerShield)
local PlayerState = require(script.Parent.PlayerState)
local PlayerProfile = require(script.Parent.PlayerProfile)

local PlayerDamage = {}

-- P3a D4: 맞은 표시 - 피격마다 맞은 사람의 클라에 "얼마 맞았나 · 쉴드가 얼마 막았나"를 알린다(PlayerHitFeedback). 체력바만 줄던 옛 표시로는 신규 보호(×0.1 ~)로
-- 작아진 피해나 쉴드가 다 막은 피격이 "안 맞은 것처럼" 보였다 - 판정은 있었고 피해만 줄었다는 것을 숫자로 보여 준다(그리기는 클라 PlayerHitFeedback).
local hitFeedback = Instance.new("RemoteEvent")
hitFeedback.Name = "PlayerHitFeedback"
hitFeedback.Parent = ReplicatedStorage

-- 클라이언트 체력바(PlayerHealthBar.client.lua)는 Humanoid.Health가 아니라 이 Attribute를
-- 읽는다 - PlayerState가 유일한 HP 소스이므로 HP가 바뀌는 모든 지점에서 이걸 같이 불러야 한다.
function PlayerDamage.syncHud(player)
	player:SetAttribute("Hp", PlayerState.getHp(player))
	player:SetAttribute("MaxHp", PlayerState.getMaxHp(player))
end

-- 몬스터 평타 1회가 실제로 얼마나 깎는지(감소율 적용 후). 체력바 눈금(9-5)과 실제
-- 피격 데미지가 같은 계산을 써야 눈금이 "몇 대"를 정확히 의미한다.
-- 방어력은 클래스 배율이 걸린다(10-3 [3] - 대검 1.3배로 더 튼튼하고 활 0.6배로 더 약하다).
-- 클래스를 아직 안 고른 순간(접속 직후 선택 UI가 뜨기 전)은 배율 없는 기본값으로 방어한다.
-- 장비 방어력(12-1 [4])은 착용한 갑옷이 있으면 Loot.getArmorDefense가 계산하고, 없으면 0 -
-- PlayerCombat.getDefense가 "(기본값 + 장비 보너스) 전체에 클래스 배율을 곱한다"는 9-4/10-3
-- 원칙을 그대로 지킨다.
function PlayerDamage.computeHitDamage(attack, targetPlayer)
	local classId = PlayerProfile.getClassId(targetPlayer)
	local armorBonus = Loot.getArmorDefense(PlayerProfile.getEquippedArmor(targetPlayer))
	-- 23-3: 보석 "심판의 표식"(defensePercent 축) - PlayerCombat.getDefense의 세 번째 자리.
	local defensePercentBonus = PlayerProfile.getDefensePercentBonus(targetPlayer)
	local defense = classId and PlayerCombat.getDefense(classId, armorBonus, defensePercentBonus) or CombatConfig.playerDefense
	local reduction = defense / (defense + CombatConfig.damageReductionAlpha * attack)
	-- S21-0 A2: 피해 계산 출구. 공격력·방어력이 둘 다 inf가 되면 reduction = inf/inf = NaN이라
	-- 매 히트 HP가 영구히 NaN으로 고장 난다(PRD 감사 §1-2 ④) - 여기서 0 데미지로 끊는다.
	return Sanitize.number(attack * (1 - reduction), 0)
end

-- 플레이어 HP를 깎는 유일한 통로(S13b) - "쉴드 흡수 → HP" 순서와 사망 처리를 여기서만 한다. HP를 직접 낮추는 다른 코드(PlayerState.setHp · Humanoid:TakeDamage ·
-- Humanoid.Health 대입)는 쉴드를 우회하므로 두지 않는다(우회 경로 전수 조사 결과는 PRD 20.99). 피해 배율(대시 · 잡힘)은 이 함수 앞에서 곱한다 - 여기 오는 damage는 최종 피해다.
-- opts.ignoresShield: true면 쉴드를 건드리지 않고 HP를 깎는다 - 낙사 같은 판정형 피해 · 딜링모드 자기 소모(피해가 아니라 비용이라 쉴드로 막으면 안 된다).
--   보스 즉사 패턴이 쉴드를 뚫는지는 Fable이 정한다(지금 그 패턴에 이 플래그를 주는 곳은 없다).
-- opts.label: 로그 꼬리표. opts.silent: 로그를 안 남긴다(매 프레임 소모용).
-- 반환: 쉴드 흡수 전 피해(= damage), 쉴드가 흡수한 양, 이번에 죽었는가.
function PlayerDamage.takeDamage(targetPlayer, damage, opts)
	opts = opts or {}
	local hpDamage, absorbed = damage, 0
	if not opts.ignoresShield then
		hpDamage, absorbed = PlayerShield.absorb(targetPlayer, damage)
	end
	local newHp = math.max(PlayerState.getHp(targetPlayer) - hpDamage, 0)
	PlayerState.setHp(targetPlayer, newHp)
	PlayerState.setLastCombatActionAt(targetPlayer, os.clock()) -- 자동회복 5초 대기 타이머 리셋(17-1)
	PlayerDamage.syncHud(targetPlayer)
	if not opts.silent and typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Player") then
		hitFeedback:FireClient(targetPlayer, hpDamage, absorbed) -- P3a D4
	end

	if not opts.silent then
		print(("[forge-game] 플레이어 피격%s: %s - %.2f 데미지%s (남은 HP %.2f/%d)"):format(
			opts.label and ("(" .. opts.label .. ")") or "", targetPlayer.Name, damage,
			absorbed > 0 and (" (쉴드 흡수 %.2f)"):format(absorbed) or "", newHp, PlayerState.getMaxHp(targetPlayer)))
	end

	local died = newHp <= 0
	if died then
		PlayerShield.clear(targetPlayer)
		if not opts.silent then
			print(("[forge-game] 플레이어 사망: %s"):format(targetPlayer.Name))
		end
		local character = targetPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- 실제 HP는 PlayerState가 관리한다. Humanoid.Health=0은 로블록스 리스폰
			-- 처리(사냥터에 이미 있는 SpawnLocation으로 자동 복귀)를 트리거하는 신호일 뿐이다.
			humanoid.Health = 0
		end
	end
	return damage, absorbed, died
end

-- P2.5c 결정 2: 신규 보호 배율 - 받는 사람의 **최고** 무한 스테이지(지금 직업 infiniteBest) ≤ 20일 때만(PlayerCombat.getNewbieDamageMultiplier).
-- 지금 스테이지가 아니라 최고를 보는 이유(리뷰 1): 지금 스테이지는 언제든 내릴 수 있어, 파티원이 스테이지 1로 내려 두고 리더의 고스테이지 보스에 들어가면
-- 피해가 ×0.1이 됐다. 최고 스테이지는 내려가지 않는다 - 진짜 신규만 보호받는다. 스탠드인(표 Player)은 nil이라 1. 체력바 눈금(MonsterAI TickDamage)도 이 함수를 곱한다.
-- 검증 전용(DevTools 자동 검증 체인만 켠다): 옛 보스 · 피격 검증은 "보호 없는 피해"를 기대값으로 박아 두었고, 검증용 개발 프로필은 최고 스테이지가 20 이하일 수 있다
-- (P2.5c Play 1 - 최고 5에서 ×0.158이 걸려 29-1 · 29-3 · 29-4 · S13b가 X). 체인이 도는 동안만 true - 신규 보호 자체는 P25c(나)가 다시 켜고 잰다.
PlayerDamage.debugNewbieProtectionOff = false

-- G1-3: 레벨차 계수 - 받는 피해(CharacterLevelConfig.levelGap). 스테이지 = 그 사람의 지금 스테이지(보스전이면 리더가 연 보스 스테이지와 같다 - 파티원은 자기 스테이지). 스탠드인은 1.
function PlayerDamage.getLevelGapTakeMultiplier(targetPlayer)
	return CharacterLevel.levelGapTakeMultiplier(PlayerProfile.getCharacterLevel(targetPlayer), PlayerProfile.getInfiniteStage(targetPlayer))
end

function PlayerDamage.getNewbieMultiplier(targetPlayer)
	if PlayerDamage.debugNewbieProtectionOff then
		return 1
	end
	return PlayerCombat.getNewbieDamageMultiplier(PlayerProfile.getInfiniteStageBest(targetPlayer))
end

-- 감소율까지 적용된 최종 피해를 넣고 사망 처리까지 한다 - 모든 피격 경로의 마지막 공통
-- 지점. 받는 피해 배율(대검 E 채널링·대시, PlayerState)은 여기서 곱한다.
local function applyFinalDamage(targetPlayer, damage, label)
	damage *= PlayerState.getIncomingDamageMultiplier(targetPlayer)
	damage *= PlayerDamage.getNewbieMultiplier(targetPlayer)
	damage *= PlayerDamage.getLevelGapTakeMultiplier(targetPlayer) -- G1-3: 레벨차 계수(받는 피해)
	-- 29-1(PRD 20.73 [2-8] A-1 "잡힌 동안 받는 피해"): 잡히면 못 피하므로 모든 패턴이 확정 피격이다 -
	-- 배율(지금은 0 = 면역)을 곱하고, 0이면 피격 자체가 없던 것으로 친다(자동회복 타이머도 안 건드린다).
	local trapMultiplier = PlayerState.getTrapDamageMultiplier(targetPlayer)
	if trapMultiplier then
		damage *= trapMultiplier
		if damage <= 0 then
			return 0
		end
	end
	-- S21-0 A2: 실제로 HP를 깎기 직전의 마지막 출구(모든 피해 경로의 공통 지점) - 배율들이
	-- 오염된 값과 곱해져도 여기서 한 번 더 끊는다.
	damage = Sanitize.number(damage, 0)
	-- 반환은 지금까지처럼 피해 하나(호출자들이 "피격이 있었나"로 읽는다) - 쉴드가 다 막아도 피격은 피격이다. 흡수량이 필요한 곳은 takeDamage를 직접 부른다.
	return (PlayerDamage.takeDamage(targetPlayer, damage, { label = label }))
end

-- 몬스터 공격력(rawAttack)을 방어력 감소식에 넣어 적용한다 - 잡몹 평타·보스 평타·강공격·
-- 진동파·낙석·십자 화염이 전부 이 경로다(방어력이 먹힌다 - 대검의 정체성 유지).
--
-- damageMultiplier(21-3, 기본 1)는 감소식을 거친 "피해"에 곱한다 - 공격력에 곱하지 않는다.
-- 15-1의 강공격은 공격력에 ×3을 곱해 감소식에 넣었는데(heavyAttack = attack×3), 감소율
-- D/(D+αA)가 A에 대해 비선형이라 앵커(생존 7타, 감소율 0.59)에서 실제 피해는 평타의 ×4.9
-- (최대체력의 70.5%)였다 - PRD 20.44 [3](나)가 "잡몹 평타 ×3 ≈ 43%"로 계산한 표(피해에
-- 곱한 값)와 어긋나 "진동파 29% + 강공격 43% = 생존" 관계가 실제로는 111%로 깨졌다
-- (21-3 [4] 검증에서 발견, 20.46 참고). PRD 표대로 "피해 ×m"으로 통일한다 - 그래야 ×2/×3이
-- 직업·방어력과 무관하게 항상 생존 타수의 2/7·3/7이다.
function PlayerDamage.applyHit(targetPlayer, rawAttack, label, damageMultiplier)
	if (PlayerState.getHp(targetPlayer) or 0) <= 0 then
		return 0 -- 죽어서 리스폰 대기 중인 시체는 때리지 않는다(사망 로그 중복 방지)
	end
	local damage = PlayerDamage.computeHitDamage(rawAttack, targetPlayer) * (damageMultiplier or 1)
	return applyFinalDamage(targetPlayer, damage, label)
end

-- 최대체력 비율 피해(21-3, 보스 돌진 - 방어 무관). 받는 피해 배율(대시 50% 등)은 그대로
-- 곱한다 - "방어 무관"이지 "감소 무관"이 아니다(PRD 5.4 대시 설계가 만든 "일단 대시 vs
-- 제대로 피하기"의 대비를 여기서도 유지한다, 20.46 [0] 계산 참고).
function PlayerDamage.applyMaxHpFraction(targetPlayer, fraction, label)
	if (PlayerState.getHp(targetPlayer) or 0) <= 0 then
		return 0
	end
	return applyFinalDamage(targetPlayer, PlayerState.getMaxHp(targetPlayer) * fraction, label)
end

return PlayerDamage
