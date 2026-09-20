-- 파티 조합별 보스 처치 시간 · 받은 피해 · 쉴드 흡수량 측정 모형(S13b) - 값을 정하는 도구가 아니라 재는 도구다(보고만, 확정 금지).
-- BalanceSim.simulateHealerCycle(힐러 1명의 전투 → 이탈 → 회복 → 복귀 단계 기계)을 그대로 잇고, 거기에 파티(딜러 · 힐러 여러 명)와 쉴드 층(ShieldLayers - 서버 PlayerShield와 같은 규칙)을 얹는다.
-- 모형의 가정(측정 보고에 같이 적는다):
--   · 딜러는 항상 전투 중이고 죽지 않는다(그래서 딜러 HP는 안 든다 - 받은 피해만 센다). 기존 r · b 앵커(PartyConfig)도 딜러 가동률을 100%로 본다.
--   · 피격은 전투 중인 멤버마다 초당 hitsPerSecond × hitRatio(최대체력 비율)로 연속 적용한다(simulateHealerCycle과 같은 기준 시나리오 - BalanceSim 주석 참고).
--   · 힐러: 전투 = 딜링모드 켜짐(소모 drain · 피격 · 딜). HP가 reserve 이하면 이탈(딜링모드 끔) → 회복(자동회복 + 치유) → 복귀. 회복 단계의 Q는 일반 치유(자신 + 파티원 각각 healPercentOfMaxHp × 치명 기대 배율).
--   · 쉴드 모드(opts.shield = true): 전투 중인 힐러의 Q = 멤버 전원(자신 포함, 전원 생존)에게 쉴드. 아니면 옛 동작(Q = 치유). 치명은 기대 배율로 반영한다.
--   · Q는 쿨타임이 차면 바로 쓴다(전원 시작 시각 0 - 여러 힐러의 시전이 겹치는 쪽, 반감 규칙이 가장 자주 걸리는 쪽이다).
--   · 파티 딜 = (딜러 수 × 1 + 전투 중인 힐러 수 × healerRaw) × (힐러가 1명이라도 있으면 1 + 힐러 버프 b). 단위 = 대검 딜러 1명(BalanceSim.simulateCombat 로테이션 60초 총딜 기준).
-- 순수 함수다(플레이어 · 시계를 모른다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local ShieldLayers = require(ReplicatedStorage.Shared.ShieldLayers)

local PartyShieldSim = {}

-- params:
--   dealers, healers          인원(합 = 파티 인원)
--   healerRaw                 힐러 딜링모드 100% 가동 딜 ÷ 대검 딜러 딜(BalanceSim 앵커 로테이션 비)
--   bossHpUnits               보스 HP = 딜러 1명이 bossHpUnits초에 깎는 양(딜 단위 × 초)
--   hitsPerSecond, hitRatio   전투 중 멤버 1명의 피격(초당 횟수 · 1회당 최대체력 비율)
--   regenPerSecond            자동 회복률(기본 CombatConfig.regenPercentPerSecond, 0 = 보스전 조건)
--   shield                    true면 전투 중 Q가 쉴드, false면 치유
--   drainPerSecond            딜링모드 소모율(기본 SkillData.healer.E.drainPercentPerSecond)
--   reserveRatio · retreatSeconds · returnSeconds   simulateHealerCycle과 같은 기본값(0.3 · 2 · 2)
--   maxSeconds                시뮬레이션 상한(기본 3600)
-- 반환: { killSeconds(상한이면 nil), damageIn(받은 피해 합 - 쉴드 전), absorbed(쉴드 흡수 합), hpLoss(쉴드 뒤 HP 손실 합), shieldUptime(멤버 평균), avgLayers(멤버 평균, 전체 시간),
--         avgLayersWhileShielded, healerFightRatio(힐러 평균 전투 시간 비율), casts(쉴드 시전 횟수), rejected(5겹째 거절), halved(반감된 층 수), replaced(교체 횟수) } - 피해 단위 = 멤버 최대체력 비율의 합.
function PartyShieldSim.run(params)
	local healerQ = SkillData.healer.Q
	local healerE = SkillData.healer.E
	local dealers, healers = params.dealers, params.healers
	local total = dealers + healers
	local healerRaw = params.healerRaw
	local bossHp = params.bossHpUnits
	local incoming = params.hitsPerSecond * params.hitRatio
	local drain = params.drainPerSecond or healerE.drainPercentPerSecond
	local regen = params.regenPerSecond
	if regen == nil then
		regen = CombatConfig.regenPercentPerSecond
	end
	local regenDelay = CombatConfig.regenDelaySeconds
	local reserve = params.reserveRatio or 0.3
	local retreatSeconds = params.retreatSeconds or 2
	local returnSeconds = params.returnSeconds or 2
	local shieldMode = params.shield == true
	local maxSeconds = params.maxSeconds or 3600
	local dt = 0.05

	local critExpected = 1 + ClassData.classes.healer.critRate * (healerQ.critHealMultiplier - 1)
	local healFraction = healerQ.healPercentOfMaxHp * critExpected
	local shieldAmount = healerQ.healPercentOfMaxHp * (healerQ.shield and healerQ.shield.healRatio or 0) * critExpected
	local shieldCooldown = healerQ.shield and healerQ.shield.cooldownSeconds or healerQ.cooldownSeconds
	local buffMultiplier = healers > 0 and (1 + PartyConfig.healerBuffFraction) or 1

	-- 멤버: 1..dealers = 딜러, 그 뒤 = 힐러. 힐러만 HP · 단계 기계를 든다.
	local members = {}
	for index = 1, total do
		members[index] = {
			isHealer = index > dealers,
			layers = {},
			hp = 1.0,
			phase = "fight",
			phaseLeft = 0,
			lastCombatAt = 0,
			nextQAt = 0,
			fightSeconds = 0,
			shieldSeconds = 0,
			layerSeconds = 0,
		}
	end

	local damageIn, absorbedTotal, hpLoss = 0, 0, 0
	local casts, rejected, halved, replaced = 0, 0, 0, 0
	local shieldedMemberSeconds, layerMemberSeconds = 0, 0
	local progress = 0
	local t = 0
	while progress < bossHp and t < maxSeconds do
		-- ① Q: 쿨타임이 찬 힐러가 쓴다(쉴드 모드에서 전투 중이면 쉴드, 아니면 치유).
		for index = dealers + 1, total do
			local healer = members[index]
			if t >= healer.nextQAt then
				if shieldMode and healer.phase == "fight" then
					casts += 1
					for _, target in ipairs(members) do
						local result = ShieldLayers.add(target.layers, healer, shieldAmount, healerQ.shield.durationSeconds, t)
						if not result.applied then
							rejected += 1
						else
							halved += result.halved and 1 or 0
							replaced += result.replaced and 1 or 0
						end
					end
					healer.nextQAt = t + shieldCooldown
				else
					healer.hp = math.min(healer.hp + healFraction, 1)
					for _, other in ipairs(members) do
						if other.isHealer and other ~= healer then
							other.hp = math.min(other.hp + healFraction, 1)
						end
					end
					healer.nextQAt = t + healerQ.cooldownSeconds
				end
			end
		end

		-- ② 피격 · 소모 · 단계 기계.
		local fightingHealers = 0
		for _, member in ipairs(members) do
			local fighting = not member.isHealer or member.phase == "fight"
			if fighting then
				local hit = incoming * dt
				damageIn += hit
				local remaining, absorbed = ShieldLayers.absorb(member.layers, hit, t)
				absorbedTotal += absorbed
				hpLoss += remaining
				if member.isHealer then
					member.hp -= remaining + drain * dt -- 소모는 피해가 아니라 비용 - 쉴드를 안 건드린다(ignoresShield)
					member.lastCombatAt = t
					member.fightSeconds += dt
					fightingHealers += 1
					if member.hp <= reserve then
						member.phase = "retreat"
						member.phaseLeft = retreatSeconds
					end
				end
			elseif member.phase == "retreat" then
				member.phaseLeft -= dt
				if member.phaseLeft <= 0 then
					member.phase = "regen"
				end
			elseif member.phase == "regen" then
				if t - member.lastCombatAt >= regenDelay then
					member.hp = math.min(member.hp + regen * dt, 1)
				end
				if member.hp >= 1 then
					member.phase = "return"
					member.phaseLeft = returnSeconds
				end
			elseif member.phase == "return" then
				member.phaseLeft -= dt
				if member.phaseLeft <= 0 then
					member.phase = "fight"
				end
			end
		end

		-- ③ 딜 · 쉴드 통계.
		progress += (dealers + fightingHealers * healerRaw) * buffMultiplier * dt
		for _, member in ipairs(members) do
			local layerCount = ShieldLayers.count(member.layers, t)
			if layerCount > 0 then
				shieldedMemberSeconds += dt
				layerMemberSeconds += layerCount * dt
			end
		end
		t += dt
	end

	local healerFight = 0
	for index = dealers + 1, total do
		healerFight += members[index].fightSeconds
	end
	local memberSeconds = t * total
	return {
		killSeconds = progress >= bossHp and t or nil,
		elapsed = t,
		damageIn = damageIn,
		absorbed = absorbedTotal,
		hpLoss = hpLoss,
		shieldUptime = memberSeconds > 0 and shieldedMemberSeconds / memberSeconds or 0,
		avgLayers = memberSeconds > 0 and layerMemberSeconds / memberSeconds or 0,
		avgLayersWhileShielded = shieldedMemberSeconds > 0 and layerMemberSeconds / shieldedMemberSeconds or 0,
		healerFightRatio = healers > 0 and t > 0 and healerFight / healers / t or nil,
		casts = casts,
		rejected = rejected,
		halved = halved,
		replaced = replaced,
	}
end

return PartyShieldSim
