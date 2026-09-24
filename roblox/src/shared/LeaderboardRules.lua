-- 리더보드 · 진도 갱신의 순수 규칙(P3a A · B). 서버(CombatResolution · Leaderboard)와 검증(가)가 같은 함수를 쓴다 - 플레이어 · 저장소를 모른다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)

local LeaderboardRules = {}

-- "자기 최고 다음 보스 스테이지" - 최고 클리어가 0(아직 없음)이면 첫 보스 스테이지(= 간격).
function LeaderboardRules.nextBossStage(bestBossCleared, interval)
	return (bestBossCleared or 0) + interval
end

-- 보스 처치 한 번의 진도 판정(사용자 확정 규칙 - P3a).
-- input = { stage, interval, threshold, isParty, members = { { best = 그 멤버의 최고 클리어(nil = 프로필 없음), ratio = 보스에게 넣은 피해 비율 }, ... } }
-- 반환 = { advanced = { [i] = bool }, reasons = { [i] = "advanced" | "not_next" | "low_damage" | "no_profile" }, partyRecord = bool }
--   · 개인 최고가 오르는 조건: 도전한 스테이지 = 자기 최고 다음 보스 스테이지 AND 본인 피해 비율 ≥ threshold. 멤버마다 따로 본다(남이 미달이어도 나는 오른다).
--   · 파티 기록: 파티(실제 멤버 2명 이상)이고 **전원**이 이번 처치로 올랐을 때만.
function LeaderboardRules.evaluateClear(input)
	local advanced, reasons = {}, {}
	local allAdvanced = #input.members > 0
	for i, member in ipairs(input.members) do
		local reason
		if member.best == nil then
			reason = "no_profile"
		elseif input.stage ~= LeaderboardRules.nextBossStage(member.best, input.interval) then
			reason = "not_next"
		elseif (member.ratio or 0) < input.threshold then
			reason = "low_damage"
		else
			reason = "advanced"
		end
		reasons[i] = reason
		advanced[i] = reason == "advanced"
		allAdvanced = allAdvanced and advanced[i]
	end
	return {
		advanced = advanced,
		reasons = reasons,
		partyRecord = input.isParty == true and #input.members >= 2 and allAdvanced,
	}
end

-- 클리어 시간(초) → 저장 단위(0.1초, 반올림, 0 ~ 상한 − 1).
function LeaderboardRules.timeUnits(seconds)
	local units = math.floor(Sanitize.number(seconds, 0) / LeaderboardConfig.timeUnitSeconds + 0.5)
	return math.clamp(units, 0, LeaderboardConfig.timeCapUnits - 1)
end

-- (스테이지, 시간) → 정수 하나. 스테이지가 높을수록, 같으면 시간이 짧을수록 크다(내림차순 정렬 = 순위).
function LeaderboardRules.encode(stage, seconds)
	return stage * LeaderboardConfig.stageScale + (LeaderboardConfig.timeCapUnits - 1 - LeaderboardRules.timeUnits(seconds))
end

-- 정수 → (스테이지, 시간 초).
function LeaderboardRules.decode(value)
	local stage = math.floor(value / LeaderboardConfig.stageScale)
	local units = LeaderboardConfig.timeCapUnits - 1 - (value - stage * LeaderboardConfig.stageScale)
	return stage, units * LeaderboardConfig.timeUnitSeconds
end

-- 멤버 한 명의 이론 최대 DPS(부정 방지 - 이보다 빠를 수 없다). attack = 최종 공격력 · cooldownSeconds = 평타 쿨(공속 반영 전 버프 없음) ·
-- critDamage = 치명 피해 배율 최대 · extraMultiplier = 보스가 받는 피해 배율 최대 × 치유사 버프 최대 같은 곱.
function LeaderboardRules.memberDpsCap(attack, cooldownSeconds, critDamage, extraMultiplier)
	local anti = LeaderboardConfig.antiCheat
	local perSecond = anti.maxBuffSpeedMultiplier / math.max(cooldownSeconds, 1e-3)
	return Sanitize.number(attack * math.max(critDamage, 1) * perSecond * anti.burstFactor * (extraMultiplier or 1), 0)
end

-- 이론 최소 클리어 시간 = 보스 최대 HP ÷ Σ 멤버 이론 최대 DPS. DPS 합이 0이면(계산 불가) 0 - 거절하지 않는다.
function LeaderboardRules.minClearSeconds(bossMaxHp, dpsCaps)
	local total = 0
	for _, dps in ipairs(dpsCaps) do
		total += dps
	end
	if total <= 0 then
		return 0
	end
	return Sanitize.number(bossMaxHp / total, 0)
end

-- 파티 기록 키 = 멤버 UserId 오름차순을 이은 것(같은 구성 = 같은 키 - 그 구성의 최고 기록 하나). 4명 × 11자리 + 구분자 < 50자(키 상한).
function LeaderboardRules.partyKey(userIds)
	local sorted = table.clone(userIds)
	table.sort(sorted)
	local parts = {}
	for i, id in ipairs(sorted) do
		parts[i] = tostring(id)
	end
	return "p" .. table.concat(parts, "_")
end

return LeaderboardRules
