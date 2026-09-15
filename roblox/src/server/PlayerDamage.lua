-- 플레이어가 몬스터에게 맞았을 때의 피해 계산·적용 단일 통로(21-3). MonsterAI.server.lua에
-- 로컬 함수로 있던 computeHitDamage/applyHitToPlayer/syncHud를 그대로 뽑아냈다 - 보스
-- 패턴(BossPatterns.lua)이 잡몹 평타·강공격과 같은 식으로 피해를 넣어야 하는데, Script인
-- MonsterAI에서는 require로 꺼내 쓸 수 없어서다(CombatResolution.lua가 AttackServer에서
-- 처치 처리를 뽑아낸 것과 같은 이유). 동작은 바꾸지 않았다 - 옮기기만 했다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerState = require(script.Parent.PlayerState)
local PlayerProfile = require(script.Parent.PlayerProfile)

local PlayerDamage = {}

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
	local defense = classId and PlayerCombat.getDefense(classId, armorBonus) or CombatConfig.playerDefense
	local reduction = defense / (defense + CombatConfig.damageReductionAlpha * attack)
	return attack * (1 - reduction)
end

-- 감소율까지 적용된 최종 피해를 넣고 사망 처리까지 한다 - 모든 피격 경로의 마지막 공통
-- 지점. 받는 피해 배율(대검 E 채널링·대시, PlayerState)은 여기서 곱한다.
local function applyFinalDamage(targetPlayer, damage, label)
	damage *= PlayerState.getIncomingDamageMultiplier(targetPlayer)
	local newHp = math.max(PlayerState.getHp(targetPlayer) - damage, 0)
	PlayerState.setHp(targetPlayer, newHp)
	PlayerState.setLastCombatActionAt(targetPlayer, os.clock()) -- 자동회복 5초 대기 타이머 리셋(17-1)
	PlayerDamage.syncHud(targetPlayer)

	print(("[forge-game] 플레이어 피격%s: %s - %.2f 데미지 (남은 HP %.2f/%d)"):format(
		label and ("(" .. label .. ")") or "", targetPlayer.Name, damage, newHp, PlayerState.getMaxHp(targetPlayer)))

	if newHp <= 0 then
		print(("[forge-game] 플레이어 사망: %s"):format(targetPlayer.Name))
		local character = targetPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- 실제 HP는 PlayerState가 관리한다. Humanoid.Health=0은 로블록스 리스폰
			-- 처리(사냥터에 이미 있는 SpawnLocation으로 자동 복귀)를 트리거하는 신호일 뿐이다.
			humanoid.Health = 0
		end
	end
	return damage
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
