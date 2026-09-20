-- 치유 시전의 서버 판정(20-6 [5] · 24-3 · 26-2 · 30-0 S13). SkillServer의 shape="heal" 분기가 부른다 - 스크립트(Script)는 require할 수 없어 자동 검증(BalanceDecisionVerify)이
-- "실제 castHeal 경로"를 밟도록 이 로직만 모듈로 뺐다(쿨다운 · 결과 이벤트 · markCast는 SkillServer에 그대로 있다).
--
-- 자기 회복: 최대체력 × def.healPercentOfMaxHp × 재생 배수(PlayerProfile.getHealingPowerMultiplier - 자동회복과 같은 배수).
-- 힐러 버프(24-3): 파티에서만 · 멤버 전원(힐러 포함)에게 서버가 직접 건다.
-- 파티 회복(S13 · PRD 20.81 [B-3]): def.partyHeal이면 같은 루프에서 **힐러가 아닌 멤버마다** 그 멤버의 최대체력 × def.healPercentOfMaxHp × 힐러의 재생 배수 ×
-- (치명이면 def.critHealMultiplier). 치명 굴림은 자기 힐에서 굴린 결과 하나를 전원에게 쓴다(다시 굴리지 않는다). 받는 사람의 재생 옵션은 곱하지 않는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local BuffState = require(script.Parent.BuffState)
local PartyState = require(script.Parent.PartyState)
local PlayerProfile = require(script.Parent.PlayerProfile)
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

-- 반환: healAmount(자기 회복량 - 상한 적용 전), isCrit, healed(파티 회복을 받은 멤버 목록 - 힐러 제외 · 더미 · 죽은 멤버 제외). 파티가 있으면 버프(항상)와 파티 회복(def.partyHeal)도 처리한다.
function HealCast.cast(player, def, classId, cooldownSeconds)
	local maxHp = PlayerState.getMaxHp(player)
	local hp = PlayerState.getHp(player)
	-- 26-2(PRD 20.67 [2] "재생 - 힐러 치유 회복량 ×(1+x)") - PlayerProfile.getHealingPowerMultiplier가 자동회복(PlayerRegen.server.lua)과 같은 배수를 쓴다.
	local healingPower = PlayerProfile.getHealingPowerMultiplier(player)
	local baseHeal = maxHp * def.healPercentOfMaxHp * healingPower
	-- calcDamage를 그대로 쓰지 않는다 - 크리 롤(RNG 소스 하나로 통일)만 재사용하고, 배율은 SkillData의 critHealMultiplier(고정 2배, PRD 4.3)로 따로 곱한다.
	-- class.critDmg를 그대로 썼다면 힐러 기준 1.8배가 나와 PRD 수치와 어긋난다.
	local _, isCrit = PlayerCombat.calcDamage(baseHeal, classId)
	local healAmount = isCrit and baseHeal * def.critHealMultiplier or baseHeal
	setHp(player, math.min(hp + healAmount, maxHp))

	-- 힐러 버프(24-3, PRD 20.64) - 파티에서만 발동한다(지시 6, 솔로 자기힐로 자기버프를 받아 딜을 올리는 경로 차단 - PartyState.getParty가 nil이면 여기서 끝난다).
	-- 멤버 전원(힐러 자신 포함, PRD 20.64 [1] "힐러 자신도 대상이다")에게 서버가 직접 건다 - 클라이언트가 버프를 주장할 길이 없다. 같은 buffId를 다시 걸면
	-- BuffState.apply의 기본 동작(mode 미지정 = refresh)이 그대로 덮어써 지속시간만 갱신되고 중첩되지 않는다.
	local healed = {}
	local party = PartyState.getParty(player)
	if party then
		local multiplier = 1 + PartyConfig.healerBuffFraction
		-- 26-2: 실제(옵션 반영) 쿨다운에서 파생시킨다 - 치유 쿨다운이 짧아지면 버프도 그만큼 자주 갱신되므로 지속시간도 같이 짧아져야
		-- SkillData.lua의 "제때 힐을 돌리면 안 끊긴다" 관계가 유지된다.
		local durationSeconds = cooldownSeconds * def.partyBuffDurationMultiplier
		for _, member in ipairs(PartyState.getMemberPlayers(party)) do
			-- Player가 아닌 것(검증의 스탠드인 테이블)에는 버프 알림(SetAttribute · FireClient)을 못 보낸다 - PartyState.fireClient와 같은 거름.
			if typeof(member) == "Instance" then
				BuffState.apply(member, "healerBuff", {
					durationSeconds = durationSeconds,
					multiplier = multiplier,
					displayName = "치유 버프",
					colorName = "success",
				})
			end
			-- 더미(Player 없음)는 getMemberPlayers에 안 들어온다. 스탠드인은 HP 상태가 없으면 건너뛴다. 죽은 멤버(HP 0)는 회복하지 않는다(부활은 이 세션이 아니다).
			if def.partyHeal and member ~= player then
				local memberMaxHp = PlayerState.getMaxHp(member)
				local memberHp = PlayerState.getHp(member)
				if memberMaxHp and memberHp and memberHp > 0 then
					local amount = memberMaxHp * def.healPercentOfMaxHp * healingPower * (isCrit and def.critHealMultiplier or 1)
					setHp(member, math.min(memberHp + amount, memberMaxHp))
					table.insert(healed, member)
					if typeof(member) == "Instance" then
						partyHealReceived:FireClient(member, amount, isCrit)
					end
				end
			end
		end
	end

	return healAmount, isCrit, healed
end

return HealCast
