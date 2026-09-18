-- 보스 처치 시간 모형(29-1, PRD 20.73 [3] "기준은 코드 모형 눈금"). BossPatterns.lua의 스케줄러 규칙을
-- 그대로 옮긴 순수 함수다 - 한 번에 하나·최소 간격(격노 시 단축)·가장 오래 기다린 것부터·priority·
-- firstAtSeconds·자리 비우기·입장 유예. 실제 전투를 돌리지 않고 BossData만 읽어 "기준 플레이어가
-- 패턴을 전부 피하며 싸우면 몇 초 걸리는가"를 낸다. DevTools "/gg boss sim"과 자동 검증 블록이 쓴다.
--
-- 모형의 가정(전부 BossData.mechanics.sim - 게임 판정에는 안 쓰인다):
--   · 보스 HP = 기준 플레이어 순딜 referenceKillSeconds(60)초분 × N^p, 파티 딜 = N배.
--   · 패턴이 시작되면 회피 비용(evadeSeconds)만큼 딜이 0이다. 보스는 그 패턴의 구속 시간 동안 다음
--     패턴을 시작하지 않는다(진동파는 마지막 파동이 최대 반경에 닿을 때까지 - 코드 그대로).
--   · 게이트(PRD 20.73 [2-8] A-3): 첫 기믹 예고와 함께 서고(×g), 기믹 판정 때만 바뀐다. 판정 성공이면
--     열리고, 실패면 서고 + 전원이 잡혀 trap.autoReleaseSeconds 동안 딜 0.
-- 이 파일을 고치면 세션 스크래치패드의 python 모형과 어긋난다 - 둘은 같은 알고리즘이고, 어긋났는지는
-- 자동 검증 블록(29-1)이 기본형 73.3초 / 4인 37.8초로 확인한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)

local BossSim = {}

-- BossPatterns.lua의 PATTERN_ORDER·WAVE_MAX_RADIUS_FACTOR와 같은 값(서버 모듈이라 여기서 못 읽는다).
local PATTERN_ORDER = { "heavy", "shockwave", "meteor", "charge", "cross", "gimmick" }
local WAVE_MAX_RADIUS_FACTOR = math.sqrt(2) + 0.05

-- bossId의 현재 BossData에서 모형용 패턴표를 만든다. includeGimmick이면 공통 기믹 패턴
-- (BossData.mechanics.gimmick - 보스별 패턴표가 아직 없는 동안의 자리)을 얹는다.
function BossSim.patternsFor(bossId, includeGimmick)
	local boss = BossData.bosses[bossId]
	if not boss then
		return nil
	end
	local sim = BossData.mechanics.sim
	local evade = sim.evadeSeconds
	local patterns = {}

	patterns.heavy = { interval = boss.heavyAttackIntervalSeconds, bound = boss.telegraphWarmupSeconds, evade = evade.center }

	local shock = boss.patterns.shockwave
	if shock then
		patterns.shockwave = {
			interval = shock.intervalSeconds,
			bound = shock.telegraphSeconds + shock.repeatIntervalSeconds * (shock.waveCount - 1)
				+ (shock.layerGapSeconds or 0) * ((shock.layers or 1) - 1)
				+ WorldConfig.bossArena.halfSizeStuds * WAVE_MAX_RADIUS_FACTOR / shock.waveSpeedStuds,
			evade = evade.jump * shock.waveCount,
		}
	end
	local meteor = boss.patterns.meteor
	if meteor then
		patterns.meteor = {
			interval = meteor.intervalSeconds,
			bound = meteor.telegraphSeconds,
			evade = meteor.count == 1 and evade.meteorLarge or evade.meteor,
		}
	end
	local charge = boss.patterns.charge
	if charge then
		local dashCount = charge.dashCount or 1
		patterns.charge = {
			interval = charge.intervalSeconds,
			bound = (charge.focusSeconds + sim.chargeTravelSeconds) * dashCount + charge.recoverSeconds,
			evade = evade.charge * dashCount,
		}
	end
	local cross = boss.patterns.cross
	if cross then
		patterns.cross = {
			interval = cross.intervalSeconds,
			bound = cross.telegraphSeconds * cross.volleys,
			evade = evade.line * cross.volleys,
		}
	end
	if includeGimmick then
		local gimmick = BossData.mechanics.gimmick
		patterns.gimmick = {
			interval = gimmick.intervalSeconds,
			first = gimmick.firstAtSeconds,
			priority = gimmick.priority,
			gimmick = true,
			bound = gimmick.telegraphSeconds,
			resolve = gimmick.telegraphSeconds,
			evade = evade.gimmick,
		}
	end
	return patterns, boss
end

-- options = { partySize(1), gate(bool - 게이트를 쓰는가), breaks("always"/"never"/"failFirst") }
-- 반환 = { seconds, counts = { [id] = 횟수 }, firstGimmickAt, gimmickCount }
function BossSim.run(patterns, boss, options)
	options = options or {}
	local sim = BossData.mechanics.sim
	local tick = sim.tickSeconds
	local n = options.partySize or 1
	local maxHp = sim.referenceKillSeconds * BossRules.partySizeHpMultiplier(n)
	local hp = maxHp
	local gateMultiplier = BossRules.gateDamageTakenMultiplier()
	local trapSeconds = BossData.mechanics.trap.autoReleaseSeconds
	local breaks = options.breaks or "always"

	local nextAt, seen, counts = {}, {}, {}
	for _, id in ipairs(PATTERN_ORDER) do
		local p = patterns[id]
		if p then
			nextAt[id] = p.first or p.interval
			counts[id] = 0
		end
	end

	local t, lastEnd = 0, 0
	local current, currentEnd, evadeUntil = nil, 0, 0
	local armed, pendingResolve = false, nil
	local firstGimmickAt, gimmickIndex = nil, 0

	while hp > 0 and t < 2000 do
		if not current then
			local enraged = hp / maxHp <= boss.enragedHpFraction
			local gap = enraged and boss.enragedPatternMinGapSeconds or boss.patternMinGapSeconds
			if t >= boss.entryGraceSeconds and t >= lastEnd + gap then
				local reserved = nil
				for _, id in ipairs(PATTERN_ORDER) do
					local p = patterns[id]
					if p and p.priority and p.first and not seen[id] and (not reserved or nextAt[id] < reserved) then
						reserved = nextAt[id]
					end
				end
				local pick, pickAt, pickPriority = nil, math.huge, false
				for _, id in ipairs(PATTERN_ORDER) do
					local p = patterns[id]
					if p and t >= nextAt[id] then
						local priority = p.priority == true
						local blocked = not priority and reserved ~= nil and t + p.bound + gap > reserved
						if not blocked and ((priority and not pickPriority) or (priority == pickPriority and nextAt[id] < pickAt)) then
							pick, pickAt, pickPriority = id, nextAt[id], priority
						end
					end
				end
				if pick then
					local p = patterns[pick]
					current, currentEnd, evadeUntil = pick, t + p.bound, t + p.evade
					counts[pick] += 1
					seen[pick] = true
					if p.gimmick then
						if not firstGimmickAt then
							firstGimmickAt = t
							armed = options.gate == true
						end
						pendingResolve = t + p.resolve
					end
				end
			end
		end
		if pendingResolve and t >= pendingResolve then
			pendingResolve = nil
			gimmickIndex += 1
			local ok = breaks == "always" or (breaks == "failFirst" and gimmickIndex >= 2)
			if options.gate then
				armed = not ok
			end
			if not ok then
				evadeUntil = math.max(evadeUntil, t + trapSeconds)
			end
		end
		if current and t >= currentEnd then
			nextAt[current] = t + patterns[current].interval
			lastEnd = t
			current = nil
		end
		if t >= evadeUntil then
			hp -= n * (armed and gateMultiplier or 1) * tick
		end
		t += tick
	end

	return {
		seconds = t,
		counts = counts,
		firstGimmickAt = firstGimmickAt,
		gimmickCount = counts.gimmick or 0,
	}
end

return BossSim
