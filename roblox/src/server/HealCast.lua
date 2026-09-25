-- 치유 시전의 서버 판정(20-6 [5] · 24-3 · 26-2 · 30-0 S13). SkillServer의 shape="heal" 분기가 부른다 - 스크립트(Script)는 require할 수 없어 자동 검증(BalanceDecisionVerify)이
-- "실제 castHeal 경로"를 밟도록 이 로직만 모듈로 뺐다(쿨다운 · 결과 이벤트 · markCast는 SkillServer에 그대로 있다).
--
-- 자기 회복: 최대체력 × def.healPercentOfMaxHp × 재생 배수(PlayerProfile.getHealingPowerMultiplier - 자동회복과 같은 배수).
-- 힐러 버프(24-3): 파티에서만 · 멤버 전원(힐러 포함)에게 서버가 직접 건다.
-- 파티 회복(S13 · PRD 20.81 [B-3]): def.partyHeal이면 같은 루프에서 **힐러가 아닌 멤버마다** 그 멤버의 최대체력 × def.healPercentOfMaxHp × 힐러의 재생 배수 ×
-- (치명이면 def.critHealMultiplier). 치명 굴림은 자기 힐에서 굴린 결과 하나를 전원에게 쓴다(다시 굴리지 않는다). 받는 사람의 재생 옵션은 곱하지 않는다.
-- 쉴드(S13b): 딜링모드가 켜져 있고 파티가 있으면(usesShield) 회복 대신 **자신 포함** 멤버 전원에게 쉴드를 건다 - 쉴드량 = 그 멤버의 "힐량"(위 파티 회복과 같은 식) × def.shield.healRatio × 치명 배율
-- (같은 치명 굴림 함수 rollCrit - 힐 치명 규칙이 바뀌면 쉴드도 같이 바뀐다). 층 규칙(최대 4겹 · 반감 · 같은 시전자 교체)은 PlayerShield · ShieldLayers. 힐러 버프는 쉴드를 줄 때도 그대로 건다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local BuffState = require(script.Parent.BuffState)
local PartyState = require(script.Parent.PartyState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerShield = require(script.Parent.PlayerShield)
local PlayerState = require(script.Parent.PlayerState)

local HealCast = {}

-- 파티원이 받은 회복량(amount)과 치명 여부 - 받은 멤버의 클라(PartyHealView)가 자기 캐릭터 위에 자기 힐과 같은 숫자로 그린다.
local partyHealReceived = Instance.new("RemoteEvent")
partyHealReceived.Name = "PartyHealReceived"
partyHealReceived.Parent = ReplicatedStorage

-- HP는 PlayerState가 유일한 소스 - 바꾸는 모든 지점에서 Hp Attribute를 같이 동기화한다(MonsterAI.server.lua의 syncHud와 같은 원칙). 검증의 스탠드인(테이블)에는 Attribute가 없다.
local function setHp(player, value)
	PlayerState.setHp(player, value)
	if typeof(player) == "Instance" then
		player:SetAttribute("Hp", value)
	end
end

-- 치유의 치명 굴림 - 자기 힐 · 파티 회복 · 쉴드가 전부 이 함수 하나로 굴린다(테이블 필드라 자동 검증이 굴림을 고정해 "같은 함수를 쓰는가"를 잰다).
-- calcDamage를 그대로 쓰지 않는다 - 크리 롤(RNG 소스 하나로 통일)만 재사용하고, 배율은 SkillData의 critHealMultiplier(고정 2배, PRD 4.3)로 따로 곱한다.
-- class.critDmg를 그대로 썼다면 힐러 기준 1.8배가 나와 PRD 수치와 어긋난다.
-- P2.5a D(결정 5): 옵션 치명 확률(critRateBonus - PlayerProfile.getCritBonus 첫 값)이 치유 치명 굴림에도 더해진다(평타와 같은 옵션 합).
function HealCast.rollCrit(baseHeal, classId, critRateBonus)
	local _, isCrit = PlayerCombat.calcDamage(baseHeal, classId, critRateBonus)
	return isCrit
end

-- 치유 배수 = 재생 옵션 배수 × (1 + 최종 데미지 버킷) - 자기 회복 · 파티 회복 · 쉴드가 같은 값을 쓴다(P3b D: 스킬 툴팁도 이 함수를 부른다).
function HealCast.healingPower(player)
	local weapon = PlayerProfile.getWeapon(player)
	local finalBonus = PlayerCombat.getFinalDamageBonus(weapon and weapon.level or 0, PlayerProfile.getOptionBonus(player, "finalDamage"))
	return PlayerProfile.getHealingPowerMultiplier(player) * (1 + finalBonus)
end

-- 자기 회복량(치명 아님 · 최대체력 상한 적용 전) - cast와 같은 식(P3b D 툴팁).
function HealCast.baseHeal(player, def)
	return (PlayerState.getMaxHp(player) or 0) * def.healPercentOfMaxHp * HealCast.healingPower(player)
end

-- 이 시전이 쉴드를 주는가: 쉴드가 정의된 치유 + 딜링모드 켜짐 + 파티 있음(솔로는 지금까지처럼 자기 회복 - 딜링모드 가동률 60% 설계가 Q 자기 치유를 전제한다).
function HealCast.usesShield(player, def)
	return def.shield ~= nil and BuffState.get(player, "dealingMode") ~= nil and PartyState.getParty(player) ~= nil
end

-- 반환: healAmount(자기 회복량 - 상한 적용 전, 쉴드 모드는 0), isCrit, healed(파티 회복을 받은 멤버 목록 - 힐러 제외 · 더미 · 죽은 멤버 제외),
-- shielded(쉴드 모드에서 { member, result(PlayerShield.add의 결과) } 목록 - 죽은 멤버 · HP 없는 스탠드인 제외). 파티가 있으면 버프(항상)와 파티 회복(def.partyHeal) 또는 쉴드도 처리한다.
function HealCast.cast(player, def, classId, cooldownSeconds)
	local maxHp = PlayerState.getMaxHp(player)
	local hp = PlayerState.getHp(player)
	-- 26-2(PRD 20.67 [2] "재생 - 힐러 치유 회복량 ×(1+x)") - PlayerProfile.getHealingPowerMultiplier가 자동회복(PlayerRegen.server.lua)과 같은 배수를 쓴다.
	-- P2.5a R5: 치유량도 최종 데미지 버킷(강화 단계 + 옵션 finalDamage)을 곱한다 - 평타와 같은 PlayerCombat.getFinalDamageBonus.
	-- P2.5a D(결정 5): 치유 치명 = 옵션 치명 확률 · 치명 피해가 평타처럼 더해진다(배율 = SkillData critHealMultiplier + 옵션 치명 피해).
	local healingPower = HealCast.healingPower(player)
	local optionCritRate, optionCritDmg = PlayerProfile.getCritBonus(player)
	local baseHeal = maxHp * def.healPercentOfMaxHp * healingPower
	local isCrit = HealCast.rollCrit(baseHeal, classId, optionCritRate)
	local critMultiplier = isCrit and (def.critHealMultiplier + optionCritDmg) or 1
	local shieldMode = HealCast.usesShield(player, def)
	local healAmount = 0
	if not shieldMode then
		healAmount = baseHeal * critMultiplier
		setHp(player, math.min(hp + healAmount, maxHp))
	end

	-- 힐러 버프(24-3, PRD 20.64) - 파티에서만 발동한다(지시 6, 솔로 자기힐로 자기버프를 받아 딜을 올리는 경로 차단 - PartyState.getParty가 nil이면 여기서 끝난다).
	-- 멤버 전원(힐러 자신 포함, PRD 20.64 [1] "힐러 자신도 대상이다")에게 서버가 직접 건다 - 클라이언트가 버프를 주장할 길이 없다. 같은 buffId를 다시 걸면
	-- BuffState.apply의 기본 동작(mode 미지정 = refresh)이 그대로 덮어써 지속시간만 갱신되고 중첩되지 않는다.
	local healed = {}
	local shielded = {}
	local party = PartyState.getParty(player)
	if party then
		local multiplier = 1 + PartyConfig.healerBuffFraction
		-- 26-2: 실제(옵션 반영) 쿨다운에서 파생시킨다 - 치유 쿨다운이 짧아지면 버프도 그만큼 자주 갱신되므로 지속시간도 같이 짧아져야
		-- SkillData.lua의 "제때 힐을 돌리면 안 끊긴다" 관계가 유지된다.
		local durationSeconds = cooldownSeconds * def.partyBuffDurationMultiplier
		for _, member in ipairs(PartyState.getMemberPlayers(party)) do
			-- Player가 아닌 것(검증의 스탠드인 테이블)에는 버프 알림(SetAttribute · FireClient)을 못 보낸다 - PartyState.fireClient와 같은 거름.
			if typeof(member) == "Instance" then
				-- P3d-F 전수 점검 E: 치유사가 둘이면 짧은 지속(쿨감이 높은 쪽)의 재시전이 긴 쪽의 남은 시간을 줄였다 - 더 늦은 만료를 남긴다(배율은 같은 값 하나 - 중첩 없음 그대로).
				local existing = BuffState.get(member, "healerBuff")
				local remaining = existing and existing.expiresAt and (existing.expiresAt - os.clock()) or 0
				BuffState.apply(member, "healerBuff", {
					durationSeconds = math.max(durationSeconds, remaining),
					multiplier = multiplier,
					displayName = "치유 버프",
					colorName = "success",
				})
			end
			-- 더미(Player 없음)는 getMemberPlayers에 안 들어온다. 스탠드인은 HP 상태가 없으면 건너뛴다. 죽은 멤버(HP 0)는 회복하지 않는다(부활은 이 세션이 아니다).
			if shieldMode then
				local memberMaxHp = PlayerState.getMaxHp(member)
				local memberHp = PlayerState.getHp(member)
				if memberMaxHp and memberHp and memberHp > 0 then
					local amount = memberMaxHp * def.healPercentOfMaxHp * healingPower * def.shield.healRatio * critMultiplier
					table.insert(shielded, { member = member, result = PlayerShield.add(member, player, amount, def.shield.durationSeconds) })
				end
			elseif def.partyHeal and member ~= player then
				local memberMaxHp = PlayerState.getMaxHp(member)
				local memberHp = PlayerState.getHp(member)
				if memberMaxHp and memberHp and memberHp > 0 then
					local amount = memberMaxHp * def.healPercentOfMaxHp * healingPower * critMultiplier
					setHp(member, math.min(memberHp + amount, memberMaxHp))
					table.insert(healed, member)
					if typeof(member) == "Instance" then
						partyHealReceived:FireClient(member, amount, isCrit)
					end
				end
			end
		end
	end

	return healAmount, isCrit, healed, shielded
end

return HealCast
