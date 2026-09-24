-- 스킬 수치의 서버 단일 출처(P3b D). 스킬 판정(SkillServer)과 스킬 툴팁(Remote SkillInfoRequest)이 **같은 함수**로 공격력 · 타격 계수 · 쿨다운 · 치명 · 버프 값을 얻는다 -
-- 툴팁 값이 실제 피해와 달라질 길이 없다(화면용 복사 계산 없음). 문구(발동 방식 · 사거리 · 규칙)는 shared/SkillTooltipText가 SkillData에서 만든다.
--   · 공격력 = PlayerCombat.getAttack(무기 · 직업 · 레벨 · 공격력% · 최종 데미지 버킷 옵션 · 마일스톤) - 평타 · 스킬 공통(최종 데미지 버킷은 여기 들어 있다).
--   · 1타 계수 = SkillData 계수 × (1 + 그 스킬 옵션 "skill_<직업>_<칸>") ÷ 틱 수(채널형) - 관통돌진 · 회전베기 · 난무.
--   · 치명 = 직업 치명 확률 · 치명 피해 + 장비 · 보석 치명 옵션(PlayerProfile.getCritBonus) - PlayerCombat.calcDamage에 그대로 들어간다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local PlayerProfile = require(script.Parent.PlayerProfile)
local BuffState = require(script.Parent.BuffState)
local HealCast = require(script.Parent.HealCast)
local PlayerState = require(script.Parent.PlayerState)

local SkillStats = {}

-- 그 스킬 칸의 옵션 합(없으면 0). 옵션 id = OptionData의 skill_<직업>_<칸>.
function SkillStats.optionBonus(player, classId, slot)
	return PlayerProfile.getOptionBonus(player, ("skill_%s_%s"):format(classId, slot))
end

-- 지금 공격력(평타 · 스킬 공통).
function SkillStats.attack(player, classId, weapon)
	weapon = weapon or PlayerProfile.getWeapon(player)
	if not weapon then
		return 0
	end
	return PlayerCombat.getAttack(weapon, classId, PlayerProfile.getCharacterLevel(player), PlayerProfile.getAttackPercentBonus(player),
		PlayerProfile.getOptionBonus(player, "finalDamage"), PlayerProfile.getMilestoneMultiplier(player)) -- P2.5a R5: 최종 데미지 버킷 · P2.5b D: 마일스톤 영구 배율
end

-- 타격 1회의 공격력 대비 계수(옵션 반영 · 채널형은 틱 수로 나눈 값). 계수가 없는 스킬(버프 · 소환 · 치유)은 nil.
function SkillStats.hitCoefficient(player, classId, slot, def)
	if not def.coefficient then
		return nil
	end
	return def.coefficient * (1 + SkillStats.optionBonus(player, classId, slot)) / (def.tickCount or 1)
end

-- 실제 쿨다운(26-2 옵션 · S13b 쉴드 쿨다운). SkillServer의 쿨다운 게이트와 결과 이벤트가 이 값을 쓴다.
function SkillStats.cooldown(player, classId, slot, def)
	local cooldownSeconds = def.cooldownSeconds
	if classId == "bow" and slot == "E" then
		cooldownSeconds *= 1 + SkillStats.optionBonus(player, classId, slot)
	elseif classId == "healer" and slot == "Q" then
		if HealCast.usesShield(player, def) then
			cooldownSeconds = def.shield.cooldownSeconds -- S13b: 딜링모드 쉴드 시전은 쉴드의 쿨다운(치유 옵션은 그대로 곱한다)
		end
		cooldownSeconds *= 1 + SkillStats.optionBonus(player, classId, slot)
	end
	return cooldownSeconds
end

-- 속사(활 Q) 공속 배율 = min(상한, (기본 + 직업 치명 확률 × 계수) × (1 + 옵션)) - 옵션은 상한으로 자르기 전에 곱한다(26-2).
function SkillStats.quickShotMultiplier(player, classId, def)
	local critRate = ClassData.classes[classId].critRate
	return math.min(def.attackSpeedCap, (def.attackSpeedBase + critRate * def.attackSpeedCritCoefficient) * (1 + SkillStats.optionBonus(player, classId, "Q")))
end

-- 그림자분신(쌍검 Q) 지속 = 기본 × (1 + 옵션) - 분신과 확정 치명 창이 같은 값을 쓴다.
function SkillStats.decoyDuration(player, classId, def)
	return def.durationSeconds * (1 + SkillStats.optionBonus(player, classId, "Q"))
end

-- 치명 확률 · 치명 피해(스킬 타격에 쓰이는 값 - 직업 + 옵션).
function SkillStats.crit(player, classId)
	local class = ClassData.classes[classId]
	local optionRate, optionDmg = PlayerProfile.getCritBonus(player)
	return class.critRate + optionRate, class.critDmg + optionDmg, optionRate, optionDmg
end

-- 툴팁 수치(Remote SkillInfoRequest의 응답). 반환 { classId, attack, critRate, critDmg, healerBuff, slots = { Q = {...}, E = {...} } }.
-- 칸마다: cooldown · hitCoefficient · hitDamage(치명 아님 1타) · critHitDamage(치명 1타) · hits(1회 시전의 대상당 타격 수) · 모양별 값(속사 배율 · 분신 지속 · 치유량 · 딜링모드 배율 · 소모율).
function SkillStats.info(player)
	local classId = PlayerProfile.getClassId(player)
	local classSkills = classId and SkillData[classId]
	if not classSkills then
		return nil
	end
	local atk = SkillStats.attack(player, classId)
	local critRate, critDmg = SkillStats.crit(player, classId)
	local result = {
		classId = classId,
		attack = atk,
		critRate = critRate,
		critDmg = critDmg,
		healerBuff = PartyConfig.healerBuffFraction,
		slots = {},
	}
	for _, slot in ipairs({ "Q", "E" }) do
		local def = classSkills[slot]
		if def then
			local entry = {
				cooldown = SkillStats.cooldown(player, classId, slot, def),
				optionBonus = SkillStats.optionBonus(player, classId, slot),
				hits = def.tickCount or 1,
			}
			local coefficient = SkillStats.hitCoefficient(player, classId, slot, def)
			if coefficient then
				entry.hitCoefficient = coefficient
				entry.hitDamage = atk * coefficient
				entry.critHitDamage = atk * coefficient * critDmg
				entry.castCoefficient = coefficient * entry.hits -- 1회 시전의 대상당 합(채널형 = 틱 수만큼)
				entry.castDamage = entry.hitDamage * entry.hits
			end
			if def.shape == "selfBuff" then
				entry.speedMultiplier = SkillStats.quickShotMultiplier(player, classId, def)
				entry.arrowDamage = atk * def.stuckArrowDamageCoefficient
			elseif def.shape == "dash" and def.damageCoefficient then
				entry.bonusDamage = atk * def.damageCoefficient
			elseif def.shape == "summon" then
				entry.duration = SkillStats.decoyDuration(player, classId, def)
			elseif def.shape == "heal" then
				entry.heal = HealCast.baseHeal(player, def)
				entry.critHealMultiplier = def.critHealMultiplier + select(4, SkillStats.crit(player, classId))
				entry.shieldMode = HealCast.usesShield(player, def)
				entry.maxHp = PlayerState.getMaxHp(player)
			elseif def.shape == "toggle" then
				local weapon = PlayerProfile.getWeapon(player)
				entry.investmentScale = PlayerCombat.getInvestmentScale(weapon and weapon.level or 0, PlayerProfile.getAttackPercentBonus(player), def.investmentScaling)
				entry.attackMultiplier = def.attackMultiplier * entry.investmentScale
				entry.drainPerSecond = def.drainPercentPerSecond * (1 + entry.optionBonus)
				entry.active = BuffState.get(player, "dealingMode") ~= nil
			end
			result.slots[slot] = entry
		end
	end
	return result
end

-- 툴팁 조회 Remote(요청자별 0.3초 간격 - 창을 여닫는 입력보다 느린 사람 손이 기준).
local remote = Instance.new("RemoteFunction")
remote.Name = "SkillInfoRequest"
remote.Parent = ReplicatedStorage
local lastRequestAt = setmetatable({}, { __mode = "k" })
remote.OnServerInvoke = function(player)
	local now = os.clock()
	if lastRequestAt[player] and now - lastRequestAt[player] < 0.3 then
		return { ok = false, reason = "rate_limited" }
	end
	lastRequestAt[player] = now
	local info = SkillStats.info(player)
	return info and { ok = true, info = info } or { ok = false, reason = "no_class" }
end

return SkillStats
