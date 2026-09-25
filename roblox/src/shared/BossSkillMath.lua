-- 보스 스킬 데이터에서 계산되는 값들(29-2, PRD 20.75) - 순수 함수. 서버(BossPatterns - 자리 비우기의 구속 시간),
-- 모형(BossSim), 규칙(BossRules - 스테이지 범위 배율)이 같이 쓴다. 스킬의 "시전 시간·후딜"을 데이터에 손으로
-- 적지 않고 모양 파라미터에서 여기서 계산하는 이유: 값이 두 군데 있으면 어긋난다(20.73 [3]의 교훈).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BossData = require(ReplicatedStorage.Shared.data.BossData)

local BossSkillMath = {}

-- 파동 최대 반경(P3a C: 아레나 크기와 떼어 고정 - BossArenaMapData.geometry.waveMaxRadiusStuds 주석). BossPatterns.lua도 같은 값을 쓴다.
BossSkillMath.WAVE_MAX_RADIUS_STUDS = require(ReplicatedStorage.Shared.data.BossArenaMapData).geometry.waveMaxRadiusStuds

-- 스킬의 펄스 목록(circleBoss). pulses가 없으면 { innerRadiusStuds, radiusStuds } 하나짜리.
function BossSkillMath.pulsesOf(skill)
	if skill.pulses then
		return skill.pulses
	end
	return { { innerRadiusStuds = skill.innerRadiusStuds or 0, radiusStuds = skill.radiusStuds } }
end

-- P3c A1 줄넘기 리듬: ring 스킬의 파동 목록 - { startSeconds(스킬 시작부터 찍는 순간), speedStuds, layers, layerGapSeconds } × 파동 수.
-- skill.rhythm(보스별 리듬 - 파동마다 앞 파동과의 간격 gapSeconds · 속도 · 겹 수)이 있으면 그것을, 없으면 옛 필드(waveCount ·
-- repeatIntervalSeconds · waveSpeedStuds · layers)에서 같은 모양을 만든다. 판정(BossPatterns) · 구속 시간 · 회피 검사 · 모형(BossSim) · 클라가 이 목록 하나를 읽는다.
function BossSkillMath.ringWaves(skill)
	local waves = {}
	local baseLayers, baseGap = skill.layers or 1, skill.layerGapSeconds or 0
	if skill.rhythm then
		local start = skill.telegraphSeconds
		for index, wave in ipairs(skill.rhythm) do
			if index > 1 then
				start += wave.gapSeconds
			end
			table.insert(waves, {
				startSeconds = start, speedStuds = wave.speedStuds or skill.waveSpeedStuds,
				layers = wave.layers or baseLayers, layerGapSeconds = wave.layerGapSeconds or baseGap,
				air = wave.air, -- BR1 공중 파동 { minStuds, maxStuds } - 발 높이(지면 기준)가 이 띠인 사람만 맞는다(서 있으면 안전)
			})
		end
		return waves
	end
	for index = 1, skill.waveCount do
		table.insert(waves, {
			startSeconds = skill.telegraphSeconds + skill.repeatIntervalSeconds * (index - 1), speedStuds = skill.waveSpeedStuds,
			layers = baseLayers, layerGapSeconds = baseGap,
		})
	end
	return waves
end

-- BR1-2 지진파 무작위 리듬(skill.randomRhythm - BossData quakeRhythm): 박 수 = 곡선 단계(tier) 확률표 · 순서 = 읽을 수 있는 조합(sequences[박 수]) · 직전과 같은 조합 금지(lastKey).
-- key(예 "GAG")를 주면 그 조합 그대로(하네스). rng01 = 0 ~ 1 난수. 반환 = skill.rhythm과 같은 모양의 표, 조합 key.
function BossSkillMath.rhythmFromKey(spec, key)
	local rhythm = { label = "무작위 " .. #key .. "박 " .. key }
	local prev = nil
	for i = 1, #key do
		local t = key:sub(i, i)
		local wave = { speedStuds = spec.speedStuds, air = t == "A" and spec.air or nil, layers = spec.layers, layerGapSeconds = spec.layerGapSeconds }
		if prev then
			wave.gapSeconds = prev == "A" and spec.gapAfterAirSeconds or spec.gapAfterGroundSeconds
		end
		rhythm[i] = wave
		prev = t
	end
	return rhythm
end

function BossSkillMath.rollRhythm(skill, rng01, key, tier, lastKey)
	local spec = skill.randomRhythm
	if not key then
		local weights = spec.countWeightsByTier[math.clamp(tier or 1, 1, #spec.countWeightsByTier)]
		local roll, count = rng01(), nil
		for _, n in ipairs({ 3, 4, 5 }) do
			roll -= weights[n] or 0
			if roll < 0 and not count then
				count = n
			end
		end
		count = count or 5
		local list = spec.sequences[count]
		local choices = {}
		for _, candidate in ipairs(list) do
			if candidate ~= lastKey or #list == 1 then
				table.insert(choices, candidate)
			end
		end
		key = choices[math.clamp(math.floor(rng01() * #choices) + 1, 1, #choices)]
	end
	return BossSkillMath.rhythmFromKey(spec, key), key
end

-- 연발(sequential) 원의 둘째부터의 예고 길이 상한. P3c A4 추적(skill.trackAfterHit - 폭풍 군주의 낙뢰): 앞 판정에 누가 맞았으면 다음 원이 그 사람을 trackSeconds 동안
-- 따라가다 멈추고 lockTelegraphSeconds 뒤에 떨어진다 - 그 회차는 추적 + 고정이 된다(아무도 안 맞았으면 옛 repeatTelegraphSeconds).
function BossSkillMath.repeatSeconds(skill)
	local seconds = skill.repeatTelegraphSeconds or skill.telegraphSeconds
	local track = skill.trackAfterHit
	if track then
		seconds = math.max(seconds, track.trackSeconds + track.lockTelegraphSeconds)
	end
	return seconds
end

-- BR1: 연발 원(circleTarget)의 칸 목록 - skill.shots(칸마다 반경 · 배율 · 전조 - 작게 → 크게)가 있으면 그것, 없으면 count개가 같은 값.
-- 반환: { { radiusStuds, multiplier, telegraphSeconds } } - 첫 칸 전조 = telegraphSeconds, 둘째부터 = repeatSeconds(추적은 그 값이 이긴다).
function BossSkillMath.shotsOf(skill, count)
	local shots = {}
	local n = skill.shots and #skill.shots or (count or skill.count or 1)
	for index = 1, n do
		local shot = skill.shots and skill.shots[index] or {}
		shots[index] = {
			radiusStuds = shot.radiusStuds or skill.radiusStuds,
			multiplier = shot.multiplier or (skill.damage and skill.damage.multiplier),
			telegraphSeconds = shot.telegraphSeconds or (index == 1 and skill.telegraphSeconds or BossSkillMath.repeatSeconds(skill)),
		}
	end
	return shots
end

-- BR1: 직선(line) · 부채꼴(sector)의 볼리 목록 - skill.volleyShots(볼리마다 배율 · 전조 · 반폭 · 폭 · 회전 - 마지막이 강함)가 있으면 그것, 없으면 volleys개가 같은 값.
function BossSkillMath.volleysOf(skill)
	local volleys = {}
	local n = skill.volleyShots and #skill.volleyShots or (skill.volleys or 1)
	for index = 1, n do
		local shot = skill.volleyShots and skill.volleyShots[index] or {}
		volleys[index] = {
			multiplier = shot.multiplier or skill.damage.multiplier,
			telegraphSeconds = shot.telegraphSeconds or skill.telegraphSeconds,
			halfWidthStuds = shot.halfWidthStuds or skill.halfWidthStuds,
			angleDeg = shot.angleDeg or skill.angleDeg, -- 부채꼴 폭
			radiusStuds = shot.radiusStuds or skill.radiusStuds,
			rotateDeg = shot.rotateDeg, -- 부채꼴: 앞 볼리에서 이만큼 돌린다(없으면 다시 대상 쪽)
		}
	end
	return volleys
end

-- BR1 널뛰기(사용자 보완 B - 심해 군주 밥상뒤집기): 판이 가운데 받침점을 축으로 뒤집힌다. 판 위의 자리 along(판 길이 방향, 받침점 기준 −L ~ L)에서
-- 지렛대 비율 lever = |along| ÷ L - 받침점에서 멀수록 높이 · 멀리(방향 = 판 바깥쪽 = along의 부호) · 크게 맞는다. 반환: lever, 높이, 거리, 피해 배율.
function BossSkillMath.seesawLaunch(seesaw, halfLengthStuds, along)
	local lever = math.clamp(math.abs(along) / math.max(halfLengthStuds, 1e-3), 0, 1)
	local function lerp(a, b)
		return a + (b - a) * lever
	end
	return lever, lerp(seesaw.minHeightStuds, seesaw.maxHeightStuds), lerp(seesaw.minDistanceStuds, seesaw.maxDistanceStuds), lerp(seesaw.minMultiplier, seesaw.maxMultiplier)
end

-- BR1-2 프라이팬(밥상뒤집기): 판 위 사람의 발사. rel = 판 가운데 → 그 사람(수평) · airborne = 뒤집히는 순간 떠 있었나 · rand01 = 0 ~ 1 난수 함수.
-- 반환: 방향(단위), 높이, 거리, 피해 배율, 별 반짝(거리 ≥ starDistanceStuds).
function BossSkillMath.panLaunch(pan, rel, airborne, rand01)
	local base = rel.Magnitude > 0.5 and math.atan2(rel.Z, rel.X) or rand01() * 2 * math.pi
	local angle = base + math.rad((rand01() * 2 - 1) * pan.scatterDeg)
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local distance = pan.distanceStuds + rand01() * pan.distanceJitter
	local height = pan.heightStuds
	if airborne then
		distance *= pan.airborneDistanceScale
		height += pan.airborneHeightBonus
	end
	return dir, height, distance, pan.multiplier, distance >= pan.starDistanceStuds
end

-- ─────────────────────────── BR1-3 새 조각의 순수 계산(서버 판정 · 클라 그림 · 하네스가 같은 함수) ───────────────────────────
-- 에네르기파 휩쓸기(sweep): 시작 각 = 대상 방향 − 방향 × sweepDeg ÷ 2(dirSign +1 = 반시계 · −1 = 시계). t초(발사부터) 뒤 빔의 각(도). 끝났으면 끝 각 + done.
function BossSkillMath.sweepAngleAt(skill, centerDeg, dirSign, t)
	local startDeg = centerDeg - dirSign * skill.sweepDeg / 2
	local f = math.clamp(t / skill.sweepSeconds, 0, 1)
	return startDeg + dirSign * skill.sweepDeg * f, t >= skill.sweepSeconds
end

-- 휩쓸기 회피 최악(근접 standoff ~ 반경): 반원 안 자리(가운데 각에서 φ · 거리 d)에서 가장 가까운 안전(뒤 반원 경계까지 d·cosφ · 반경 밖 R − d)까지 걷는 시간과
-- 쓸 수 있는 시간(전조 + 빔이 그 각에 닿기까지 = sweepSeconds × (90 − φ) ÷ 180 - 시작 쪽이 φ = +90)의 여유가 가장 작은 자리. 반환: available, required, distance.
function BossSkillMath.sweepWorst(skill, standoffStuds, walkSpeedStuds)
	local dodge = BossData.mechanics.dodge
	local R = skill.radiusStuds
	local best = nil
	for phi = -90, 90, 5 do
		local c = math.cos(math.rad(phi))
		local d = standoffStuds
		while d <= R do
			local dist = math.min(d * c, R - d) + dodge.characterHalfWidthStuds
			local required = dodge.perceptionSeconds + dist / walkSpeedStuds * dodge.marginFactor
			local available = skill.telegraphSeconds + skill.sweepSeconds * (90 - phi) / 180
			if not best or available - required < best.available - best.required then
				best = { available = available, required = required, distance = dist }
			end
			d += 1
		end
	end
	return best.available, best.required, best.distance
end

-- 분신 부메랑(boomerang): 발사부터 t초 뒤 분신이 보스에서 떨어진 거리(0 ~ length)와 구간("out" · "turn" · "back"). 다 돌아왔으면 nil.
function BossSkillMath.boomerangAt(skill, length, t)
	local outT = length / skill.outSpeedStuds
	if t < outT then
		return t * skill.outSpeedStuds, "out"
	end
	t -= outT
	if t < skill.turnSeconds then
		return length, "turn"
	end
	t -= skill.turnSeconds
	local back = length - t * skill.backSpeedStuds
	if back > 0 then
		return back, "back"
	end
	return nil, nil
end

-- 피자 조각(slices): 점 p가 들어 있는 조각 번호(1 ~ count). 가운데 허브 안이면 nil. 조각 k = 각 [offsetDeg + (k − 1) × 360/count, + 360/count).
function BossSkillMath.sliceIndexOf(center, p, count, hubRadius, offsetDeg)
	local dx, dz = p.X - center.X, p.Z - center.Z
	if dx * dx + dz * dz <= hubRadius * hubRadius then
		return nil
	end
	local deg = (math.deg(math.atan2(dz, dx)) - (offsetDeg or 0)) % 360
	return math.floor(deg / (360 / count)) + 1
end

-- 무너질 조각 고르기: excluded[k] = 못 고르는 조각(보스 · 스폰) · previous[k] = 지난번 무너진 조각(되도록 피한다) · nonAdjacent = 서로 붙지 않게.
-- 후보가 모자라면 previous → nonAdjacent 순으로 규칙을 푼다. 반환: 조각 번호 목록.
function BossSkillMath.pickSlices(count, want, excluded, previous, nonAdjacent, rand01)
	local function adjacent(a, b)
		local d = math.abs(a - b)
		return d == 1 or d == count - 1
	end
	for _, relax in ipairs({ { prev = true, adj = nonAdjacent }, { prev = false, adj = nonAdjacent }, { prev = false, adj = false } }) do
		local pool = {}
		for k = 1, count do
			if not excluded[k] and not (relax.prev and previous[k]) then
				table.insert(pool, k)
			end
		end
		-- 섞기(피셔-예이츠)
		for i = #pool, 2, -1 do
			local j = 1 + math.floor(rand01() * i)
			j = math.clamp(j, 1, i)
			pool[i], pool[j] = pool[j], pool[i]
		end
		local chosen = {}
		for _, k in ipairs(pool) do
			local ok = true
			for _, other in ipairs(chosen) do
				ok = ok and not (relax.adj and adjacent(k, other))
			end
			if ok then
				table.insert(chosen, k)
			end
			if #chosen >= want then
				return chosen
			end
		end
		if #chosen >= want then
			return chosen
		end
	end
	return {}
end

-- 판 털기(halfMap): 방위 a(라디안)의 절반 판 = 중심에서 side(−sin a, cos a) 쪽. 점 p가 판 위면 경계(지름)까지의 거리, 아니면 nil.
function BossSkillMath.halfMapDepth(center, angleRad, p)
	local sx, sz = -math.sin(angleRad), math.cos(angleRad)
	local depth = (p.X - center.X) * sx + (p.Z - center.Z) * sz
	return depth > 0 and depth or nil
end

-- 수정 오르골: 보여 주는 간격(스테이지 1 ~ protectedUntilStage = 가장 느리게 · 그 뒤 곡선 단계별) · 무작위 순서(중복 허용) · 입력 한 번 진행.
function BossSkillMath.orgelShowInterval(skill, stage)
	if (stage or 1) <= skill.protectedUntilStage then
		return skill.protectedShowInterval
	end
	local tier = BossSkillMath.curveRow(stage).tier
	return skill.showIntervalByTier[math.clamp(tier, 1, #skill.showIntervalByTier)]
end

-- 인원 n의 순서 길이(sequenceLengthByParty - 없으면 sequenceLength).
function BossSkillMath.orgelLength(skill, memberCount)
	local list = skill.sequenceLengthByParty
	if not list then
		return skill.sequenceLength
	end
	return list[math.clamp(memberCount or 1, 1, #list)]
end

-- 파티 단위 전멸기의 제한 시간(2인 이상 = limitSecondsParty - 없으면 limitSeconds).
function BossSkillMath.gimmickLimitSeconds(skill, memberCount)
	return ((memberCount or 1) > 1 and skill.limitSecondsParty) or skill.limitSeconds
end

-- 모형 전용(M1 A안 가정): 파티 보정으로 늘어난 어려움 k - 1인 성공 확률 s가 s^k가 된다.
--   둔덕 = 둔덕 수 비 × 시간 비(솔로 대비) · 오르골 = 순서 길이 비(한 음씩 따로 기억한다고 본다). 보정이 없으면 1.
function BossSkillMath.partyGimmickHardness(skill, memberCount)
	local k = 1
	if skill.mound and skill.mound.countByParty then
		local list = skill.mound.countByParty
		k *= list[math.clamp(memberCount or 1, 1, #list)] / list[1]
	end
	k *= skill.limitSeconds / BossSkillMath.gimmickLimitSeconds(skill, memberCount)
	if skill.sequenceLengthByParty then
		k *= BossSkillMath.orgelLength(skill, memberCount) / BossSkillMath.orgelLength(skill, 1)
	end
	return k
end

function BossSkillMath.orgelSequence(skill, rand01, memberCount)
	local list = {}
	for i = 1, BossSkillMath.orgelLength(skill, memberCount) do
		list[i] = math.clamp(1 + math.floor(rand01() * skill.bells), 1, skill.bells)
	end
	return list
end

-- 반환: 새 진행(맞힌 수), 맞았는가. 틀리면 0(처음부터 - 순서는 그대로).
function BossSkillMath.orgelAdvance(progress, sequence, bell)
	if sequence[progress + 1] == bell then
		return progress + 1, true
	end
	return 0, false
end

-- BR1-2 보스 에어본 높이(시작부터 t초): 떠오름 riseSeconds → 떨어짐 fallSeconds(사인 곡선 - 꼭대기 liftStuds). 다 떨어졌으면 nil(그 뒤는 기절).
function BossSkillMath.bossAirborneHeight(cfg, t)
	if t >= cfg.riseSeconds + cfg.fallSeconds then
		return nil
	end
	local f = t < cfg.riseSeconds and (t / cfg.riseSeconds) or (1 - (t - cfg.riseSeconds) / cfg.fallSeconds)
	return math.sin(math.clamp(f, 0, 1) * math.pi / 2) * cfg.liftStuds
end

-- BR1 돌진: 둘째 돌진부터의 전조(repeatTelegraphSeconds - 없으면 첫 돌진과 같다).
function BossSkillMath.dashTelegraph(skill, dashIndex)
	if dashIndex > 1 and skill.repeatTelegraphSeconds then
		return skill.repeatTelegraphSeconds
	end
	return skill.telegraphSeconds
end

local function sumTelegraphs(list)
	local total = 0
	for _, entry in ipairs(list) do
		total += entry.telegraphSeconds
	end
	return total
end

-- 이 스킬이 보스를 묶는 시간(시작 ~ 다음 스킬을 고를 수 있게 되는 순간). chargeTravelSeconds를 안 주면 상한
-- (아레나를 끝에서 끝까지 달리는 경우 - 자리 비우기는 넉넉한 쪽이 안전하다).
function BossSkillMath.boundSeconds(skill, arenaHalfSizeStuds, chargeTravelSeconds)
	local primitive = skill.primitive
	if primitive == "circleBoss" then
		return skill.telegraphSeconds * #BossSkillMath.pulsesOf(skill)
	elseif primitive == "ring" then
		-- 가장 늦게 사라지는 파동(마지막 겹이 최대 반경에 닿는 순간)까지. 리듬이 없으면 옛 식 그대로다.
		local maxRadius = BossSkillMath.WAVE_MAX_RADIUS_STUDS
		local bound = 0
		for _, wave in ipairs(BossSkillMath.ringWaves(skill)) do
			bound = math.max(bound, wave.startSeconds + wave.layerGapSeconds * (wave.layers - 1) + maxRadius / wave.speedStuds)
		end
		return bound
	elseif primitive == "circleTarget" then
		if skill.ambush then -- BR1 잠행: 전조(파고들기) + 추적 + 멈춘 뒤 전조
			return skill.telegraphSeconds + skill.ambush.trackSeconds + skill.ambush.lockTelegraphSeconds
		elseif skill.chain then -- BR1 연쇄: 전조 뒤 원이 차례로 솟는다
			return skill.telegraphSeconds + skill.chain.intervalSeconds * (skill.chain.count - 1)
		elseif skill.shots then
			return sumTelegraphs(BossSkillMath.shotsOf(skill))
		elseif skill.sequential then
			return skill.telegraphSeconds + BossSkillMath.repeatSeconds(skill) * (skill.count - 1)
		end
		return skill.telegraphSeconds
	elseif primitive == "charge" then
		local travel = chargeTravelSeconds or (arenaHalfSizeStuds * 2 / skill.speedStuds)
		local dashes = skill.dashCount or 1
		return skill.telegraphSeconds + BossSkillMath.dashTelegraph(skill, 2) * (dashes - 1) + travel * dashes + skill.recoverSeconds
	elseif primitive == "line" or primitive == "sector" then
		return sumTelegraphs(BossSkillMath.volleysOf(skill))
	elseif primitive == "projectile" then
		-- 투사체는 쏜 뒤 스킬과 떨어져 난다(BossPatterns - 보스는 다음 스킬을 고를 수 있다). 묶는 시간 = 전조 + 연사 간격.
		return skill.telegraphSeconds + (skill.launchIntervalSeconds or 0) * ((skill.count or 1) - 1)
	elseif primitive == "grab" then
		-- 잡으면 들고 있다가(holdSeconds) 던지거나, 풀리면 기절(stunSeconds) - 상한은 둘을 더한 값.
		local grab = BossData.mechanics.airGrab
		return skill.telegraphSeconds + grab.chaseMaxSeconds + grab.liftSeconds + grab.holdSeconds + grab.stunSeconds -- BR1-2: 다가가 잡기 + 들고 있기(마지막 뒤) + 기절(상한 - 자리 비우기용)
	elseif primitive == "vortex" then
		return skill.telegraphSeconds + (skill.burstTelegraphSeconds or 0)
	elseif primitive == "gimmick" then
		return skill.telegraphSeconds + (skill.recoverSeconds or 0)
	elseif primitive == "sweep" then
		return skill.telegraphSeconds + skill.sweepSeconds -- BR1-3 에네르기파
	elseif primitive == "boomerang" then
		local length = (arenaHalfSizeStuds or 96) * 2
		return skill.telegraphSeconds + length / skill.outSpeedStuds + skill.turnSeconds + length / skill.backSpeedStuds -- BR1-3 분신 부메랑(상한)
	elseif primitive == "sandSearch" then
		return skill.telegraphSeconds + skill.limitSeconds + skill.stunSeconds -- BR1-3 진짜 전갈 찾기(상한 - 기절 포함)
	elseif primitive == "orgel" then
		return skill.telegraphSeconds + skill.protectedShowInterval * BossSkillMath.orgelLength(skill, 4) + skill.limitSeconds + math.max(skill.stunSeconds, skill.statue.seconds) -- BR1-3 수정 오르골(상한)
	elseif primitive == "reflect" then
		return skill.telegraphSeconds + skill.stanceSeconds -- BR1-2 반사: 결계 전조 + 반사 동안(되돌린 투사체는 스킬과 떨어져 난다)
	elseif primitive == "colorMatch" then
		return skill.telegraphSeconds + (skill.recoverSeconds or 1) -- BR1-2 색 맞추기
	elseif primitive == "lightningRods" then
		return skill.telegraphSeconds + skill.discharges * (skill.markSeconds + skill.trackSeconds + skill.lockSeconds + skill.gapSeconds) -- BR1-2 번개 조준경(상한)
	elseif primitive == "sonic" then
		return skill.telegraphSeconds + skill.tickSeconds * (skill.ticks - 1) + (skill.recoverSeconds or 0.5) -- BR1-2 음파 포효
	end
	return skill.telegraphSeconds
end

-- P3c A2 돌진 대상: 전조가 시작되는 순간 origin(보스)에서 수평으로 가장 가까운 자리의 번호. 차가 tieStuds(기본 0.05) 안인 자리들은 동률 -
-- random01()(0 ~ 1)로 그중 하나를 고른다. positions가 비었으면 nil. 서버(BossPatterns)와 검증이 같은 함수를 쓴다.
function BossSkillMath.nearestIndex(origin, positions, random01, tieStuds)
	local best = math.huge
	local distances = {}
	for index, position in ipairs(positions) do
		local dx, dz = position.X - origin.X, position.Z - origin.Z
		distances[index] = math.sqrt(dx * dx + dz * dz)
		best = math.min(best, distances[index])
	end
	local ties = {}
	for index, distance in ipairs(distances) do
		if distance <= best + (tieStuds or 0.05) then
			table.insert(ties, index)
		end
	end
	if #ties == 0 then
		return nil
	end
	return ties[math.clamp(1 + math.floor((random01 and random01() or 0) * #ties), 1, #ties)], #ties
end

-- 29-5 탱커 훅 ①: 이 스킬을 탱커의 반사가 되돌릴 수 있는가(스킬 데이터의 reflectable - 없으면 false). 아직 읽는 곳이 없다.
function BossSkillMath.isReflectable(skill)
	return skill ~= nil and skill.reflectable == true
end

-- ─────────────────────────── 회피 부등식(B) ───────────────────────────
-- telegraph ≥ perception + (회피 거리 ÷ 이동 속도) × margin. 점프 회피(ring)는 거리가 아니라 "다음 파동 전에 다시
-- 뛸 수 있는가"(repeatInterval ≥ perception + 체공 × margin)와 "겹이 점프 한 번에 다 지나가는가"로 검사한다.
-- standoffStuds = 보스가 멈춰 서는 거리(근접 플레이어가 서는 자리), walkSpeedStuds = 검사 기준 이동 속도.
-- 반환: { { label, availableSeconds, requiredSeconds, distanceStuds, ok }, ... } - 판정이 여러 번인 스킬은 여러 줄.
function BossSkillMath.dodgeChecks(skill, standoffStuds, walkSpeedStuds)
	local dodge = BossData.mechanics.dodge
	local half = dodge.characterHalfWidthStuds
	local checks = {}
	local function walk(label, availableSeconds, distanceStuds, speedMultiplier)
		local required = dodge.perceptionSeconds + distanceStuds / (walkSpeedStuds * (speedMultiplier or 1)) * dodge.marginFactor
		table.insert(checks, {
			label = label, availableSeconds = availableSeconds, requiredSeconds = required,
			distanceStuds = distanceStuds, ok = availableSeconds >= required,
		})
	end

	local primitive = skill.primitive
	if primitive == "circleBoss" then
		-- 근접 자리(standoff)와 원거리 자리 사이 어디에 서 있든 가장 가까운 안전지대(안쪽 구멍 또는 바깥)까지.
		-- 도넛이면 띠의 한가운데가 최악이다. 연속 펄스도 펄스마다 같은 구간 전체에서 최악을 찾는다(보수적).
		for index, pulse in ipairs(BossSkillMath.pulsesOf(skill)) do
			local inner, outer = pulse.innerRadiusStuds or 0, pulse.radiusStuds
			local worst = 0
			local d = math.max(standoffStuds, inner)
			local to = math.min(math.max(dodge.rangedStandoffStuds, standoffStuds), outer)
			while d <= to + 1e-6 do
				local need = inner > 0 and math.min(d - inner, outer - d) or (outer - d)
				worst = math.max(worst, need)
				d += 0.5
			end
			walk(("펄스 %d"):format(index), skill.telegraphSeconds, worst + half)
		end
	elseif primitive == "circleTarget" and skill.shots then
		for index, shot in ipairs(BossSkillMath.shotsOf(skill)) do -- BR1 칸별 크기(작게 → 크게)
			walk(("연발 %d"):format(index), shot.telegraphSeconds, shot.radiusStuds + half)
		end
	elseif primitive == "circleTarget" and skill.chain then
		walk("연쇄 옆으로", skill.telegraphSeconds, skill.radiusStuds + half)
	elseif primitive == "circleTarget" and skill.ambush then
		walk("멈춘 뒤 밖으로", skill.ambush.lockTelegraphSeconds, skill.radiusStuds + half)
	elseif primitive == "circleTarget" then
		walk("첫 원", skill.telegraphSeconds, skill.radiusStuds + half)
		if skill.sequential and skill.count > 1 then
			walk("연발", skill.repeatTelegraphSeconds or skill.telegraphSeconds, skill.radiusStuds + half)
			-- P3c A4: 추적하던 원이 멈춘 뒤 떨어질 때까지(짧은 전조) - 멈춘 순간 원 한가운데에 있어도 벗어난다.
			if skill.trackAfterHit then
				walk("추적 뒤 고정", skill.trackAfterHit.lockTelegraphSeconds, skill.radiusStuds + half)
			end
		end
		-- 29-4 유인 경로(skill.route - 폭풍 군주의 낙뢰): 첫 발을 한 구역 곁에서 받고 다음 발의 예고 안에 다른 구역의 충전 거리
		-- 안으로 걸어 들어가는 거리. 원이 넓어지면(범위 배율) 실제 거리는 줄지만 넓히지 않은 값으로 검사한다(보수적).
		if skill.route then
			walk("구역 사이", skill.repeatTelegraphSeconds or skill.telegraphSeconds, skill.route.distanceStuds)
		end
	elseif primitive == "charge" then
		walk("경로 옆걸음", skill.telegraphSeconds, skill.pathHalfWidthStuds + half)
		if (skill.dashCount or 1) > 1 and skill.repeatTelegraphSeconds then
			walk("다음 돌진 옆걸음", skill.repeatTelegraphSeconds, skill.pathHalfWidthStuds + half)
		end
	elseif primitive == "sector" then
		-- BR1 부채꼴(보스 중심 · 대상 쪽): 근접 자리 ~ 원거리 자리 어디에 서 있든 가장 가까운 밖(옆 경계선 또는 반경 밖)까지의 최악.
		-- 180° 이상이면 옆 경계선 = 보스를 지나는 지름(대상의 수직 거리 = d). jumpable이면 걷기 대신 "보고 뛰기"(인지만)가 답이다.
		for index, volley in ipairs(BossSkillMath.volleysOf(skill)) do
			local worst = 0
			if skill.dodge and skill.dodge.distanceStuds then
				worst = skill.dodge.distanceStuds - half
			else
				local d = standoffStuds
				local to = math.min(math.max(dodge.rangedStandoffStuds, standoffStuds), volley.radiusStuds)
				local halfAngle = math.rad(math.min(volley.angleDeg, 180) / 2)
				while d <= to + 1e-6 do
					local side = volley.angleDeg >= 180 and d or d * math.sin(halfAngle)
					worst = math.max(worst, math.min(side, volley.radiusStuds - d))
					d += 0.5
				end
			end
			if skill.jumpable then
				table.insert(checks, { label = ("부채꼴 %d 점프"):format(index), availableSeconds = volley.telegraphSeconds, requiredSeconds = dodge.perceptionSeconds, distanceStuds = 0, ok = volley.telegraphSeconds >= dodge.perceptionSeconds })
			else
				walk(("부채꼴 %d 밖으로"):format(index), volley.telegraphSeconds, worst + half)
			end
		end
	elseif primitive == "projectile" then
		-- BR1 투사체. 지면(ground): 대상 쪽으로 굴러오는 것을 옆으로 비킨다 - 쓸 수 있는 시간 = 전조 + 보스 곁에서 닿기까지.
		-- 공중(air): 대상을 쫓는다 - 느리면(속도 < 걷기) 땅에서 걸어 따돌리고, 빠르면 궤도를 바꾸거나 착지한다(인지만 되면 된다).
		local arrival = skill.telegraphSeconds + standoffStuds / skill.speedStuds
		if skill.heightMode == "ground" then
			walk("굴러오는 것 옆으로", arrival, skill.radiusStuds + half)
		elseif skill.speedStuds < walkSpeedStuds then
			table.insert(checks, { label = "걸어서 따돌리기(속도)", availableSeconds = walkSpeedStuds, requiredSeconds = skill.speedStuds, distanceStuds = 0, ok = true })
		else
			table.insert(checks, { label = "궤도 바꾸기(인지)", availableSeconds = arrival, requiredSeconds = dodge.perceptionSeconds, distanceStuds = 0, ok = arrival >= dodge.perceptionSeconds })
		end
	elseif primitive == "lightningRods" then
		-- BR1-2 번개 조준경: 표적이 된 뒤 조준경이 멈추기까지(mark + track) 가장 가까운 피뢰침으로 유인 · 멈춘 뒤(lock) 낙뢰 원 밖으로
		walk("피뢰침으로 유인", skill.markSeconds + skill.trackSeconds, skill.dodge.distanceStuds)
		walk("멈춘 낙뢰 밖으로", skill.lockSeconds, skill.strike.radiusStuds + half)
	elseif primitive == "colorMatch" then
		-- BR1-2 색 맞추기: 가장 먼 자리에서 가장 가까운 단 + 색이 틀리면 한 번 내려갔다 다시 올라서기(점프 1회 = 체공 × 여유)
		walk("같은 색 발판까지", skill.telegraphSeconds - dodge.jumpAirSeconds * dodge.marginFactor, skill.dodge.distanceStuds)
	elseif primitive == "sonic" then
		-- BR1-2 음파 포효: 곁에 선 큰 기둥 뒤까지(데이터 dodge.distanceStuds)
		walk("엄폐물 뒤로", skill.telegraphSeconds, skill.dodge.distanceStuds)
	elseif primitive == "reflect" and skill.counter then
		-- BR1-3 아르마딜로 반격 가시: 떨어질 자리(때린 순간의 내 자리)의 원 밖으로 - 원 한가운데(보스 바로 옆 근접)에서도
		walk("가시 자리 밖으로", skill.counter.delaySeconds, skill.counter.radiusStuds + half)
	elseif primitive == "reflect" then
		-- BR1-2 되돌아오는 투사체: 모으기 + 원거리 자리(rangedStandoff)에서 닿기까지 안에 옆으로 (반경 + 몸통)
		walk("되돌아오는 것 옆으로", skill.projectile.windupSeconds + dodge.rangedStandoffStuds / skill.projectile.speedStuds, skill.projectile.radiusStuds + half)
	elseif primitive == "sweep" then
		-- BR1-3 에네르기파: 반원 안 가장 나쁜 자리에서 뒤 반원 · 반경 밖까지(BossSkillMath.sweepWorst)
		local available, required, distance = BossSkillMath.sweepWorst(skill, standoffStuds, walkSpeedStuds)
		table.insert(checks, { label = "휩쓸기 뒤 반원 · 밖으로", availableSeconds = available, requiredSeconds = required, distanceStuds = distance, ok = available >= required })
	elseif primitive == "boomerang" then
		-- BR1-3 분신 부메랑: 선 옆으로(가는 길) - 오는 길은 같은 선(그대로 보인다)
		walk("분신 길 옆으로", skill.telegraphSeconds, skill.halfWidthStuds + half)
	elseif primitive == "sandSearch" or primitive == "orgel" then
		-- BR1-3 진짜 전갈 찾기(가장 먼 둔덕까지) · 수정 오르골(종 사이 최악 네 번) - 제한 시간 안에 걸어서
		walk(primitive == "orgel" and "종 다섯 번 치기" or "진짜 둔덕까지", skill.limitSeconds, skill.dodge.distanceStuds)
	elseif primitive == "grab" then
		-- BR1 대공 잡기: 보고 내려올 시간 - 인지 + 한 체공 최대(공중 점프 2 + 대시 = 1.961초 - movement-metrics v2). 착지하면 연속 체공이 0이 된다.
		local need = dodge.perceptionSeconds + BossData.mechanics.airGrab.maxAirSeconds
		table.insert(checks, { label = "보고 착지", availableSeconds = skill.telegraphSeconds, requiredSeconds = need, distanceStuds = 0, ok = skill.telegraphSeconds >= need })
	elseif primitive == "vortex" then
		-- BR1 소용돌이: 당기는 힘을 거슬러(걷기 − 당김) 반경 밖으로 · 끌림이 끝난 뒤 폭발 원 밖.
		walk("끌림 거슬러 밖으로", skill.telegraphSeconds, skill.radiusStuds + half, (walkSpeedStuds - skill.pullStudsPerSecond) / walkSpeedStuds)
	elseif primitive == "line" then
		local distance = skill.halfWidthStuds + half
		if (skill.directions or 1) > 1 and skill.centered then
			-- 대상 쪽으로 펼친 부채꼴: 빔 사이가 아니라 부채 전체의 옆으로 나가야 한다. 거리 조건(targetWithin)이
			-- 있으면 그 거리, 없으면 원거리 자리에서의 호 길이.
			local reach = dodge.rangedStandoffStuds
			for _, condition in ipairs(skill.conditions or {}) do
				if condition.type == "targetWithin" then
					reach = condition.studs
				end
			end
			local halfFanDeg = skill.stepDeg * ((skill.directions - 1) / 2)
			distance = reach * math.sin(math.rad(halfFanDeg)) + skill.halfWidthStuds + half
		end
		if skill.volleyShots then
			for index, volley in ipairs(BossSkillMath.volleysOf(skill)) do -- BR1 볼리별 전조 · 반폭
				walk(("직선 %d 옆걸음"):format(index), volley.telegraphSeconds, distance - skill.halfWidthStuds + volley.halfWidthStuds)
			end
		else
			walk("직선 옆걸음", skill.telegraphSeconds, distance)
		end
	elseif primitive == "ring" then
		local waves = BossSkillMath.ringWaves(skill)
		-- 첫 파동: 서 있다가 뛰면 된다 - 찍기 예고 + 파동이 standoff까지 오는 시간 안에 인지만 하면 된다.
		local firstArrival = waves[1].startSeconds + standoffStuds / waves[1].speedStuds
		table.insert(checks, { label = "첫 점프", availableSeconds = firstArrival, requiredSeconds = dodge.perceptionSeconds, distanceStuds = 0, ok = firstArrival >= dodge.perceptionSeconds })
		-- P3c A1: 다시 뛰기 = 앞 파동의 마지막 겹과 다음 파동이 **같은 자리에 닿는 시각 차**. 속도가 다르면 거리에 따라 차가 변한다(빠른 파동이 느린 파동을
		-- 뒤따르면 멀수록 좁아진다) - 차는 거리에 대해 1차식이라 보스 곁(standoff)과 파동이 사라지는 반경(WAVE_MAX) 두 끝에서 최솟값이 난다.
		local required = dodge.perceptionSeconds + dodge.jumpAirSeconds * dodge.marginFactor
		for index = 2, #waves do
			local before, after = waves[index - 1], waves[index]
			local lastLayer = before.startSeconds + before.layerGapSeconds * (before.layers - 1)
			local worst, worstAt = math.huge, standoffStuds
			for _, d in ipairs({ standoffStuds, BossSkillMath.WAVE_MAX_RADIUS_STUDS }) do
				local gap = (after.startSeconds + d / after.speedStuds) - (lastLayer + d / before.speedStuds)
				if gap < worst then
					worst, worstAt = gap, d
				end
			end
			table.insert(checks, {
				label = ("다시 뛰기 %d→%d(최악 거리 %.0f)"):format(index - 1, index, worstAt), availableSeconds = worst, requiredSeconds = required,
				distanceStuds = 0, ok = worst >= required,
			})
		end
		-- M1-0: G2a의 "한 체공에 두 박자 불가" 검사는 폐기했다(공중 점프 자유화 - 한 체공으로 여러 박자를 넘는 것은 G2b 난이도에서 다룬다 · 측정 = M1-0 보고서).
		for index, wave in ipairs(waves) do
			if wave.layers > 1 then
				-- 겹: 마지막 겹이 다 지나갈 때까지가 체공 시간 안이어야 점프 한 번에 넘는다.
				local passSeconds = wave.layerGapSeconds * (wave.layers - 1) + skill.waveThicknessStuds / wave.speedStuds
				table.insert(checks, { label = ("겹 통과 %d"):format(index), availableSeconds = dodge.jumpAirSeconds, requiredSeconds = passSeconds, distanceStuds = 0, ok = dodge.jumpAirSeconds >= passSeconds })
			end
		end
	elseif primitive == "gimmick" then
		local d = skill.dodge or { distanceStuds = 0 }
		walk("안전지대까지", d.noticeSeconds or skill.telegraphSeconds, d.distanceStuds, d.speedMultiplier)
		-- 29-3 마무리 일격(보스 앞쪽 원): 최악의 자리 = 원의 한가운데(근접 자리가 곧 원의 중심이다) → 반경 + 몸통 반폭.
		if skill.finisher then
			walk("마무리 일격 밖으로", skill.finisher.telegraphSeconds, skill.finisher.radiusStuds + half)
		end
	end
	return checks
end

-- ─────────────────────────── 피해 몫(D) ───────────────────────────
-- 앵커 빌드(생존 surviveTargetHits타)에서 이 스킬의 "실수 1회"(판정 한 번)가 최대체력에서 차지하는 몫과,
-- 한 번의 발동에서 받을 수 있는 최대 몫(모든 판정을 다 맞음). %최대체력 스킬의 발동당 합은
-- mechanics.gimmickFailMaxHpFraction에서 잘린다(BossMechanics가 강제).
function BossSkillMath.damageShares(skill, surviveTargetHits)
	local damage = skill.damage
	if damage.kind == "currentHp" then
		return damage.fraction, damage.fraction -- BR1 대공 잡기: 현재 체력 비율(가장 나쁜 경우 = 가득 찬 체력의 그 비율)
	end
	-- BR1 칸 · 볼리마다 배율이 다른 스킬: 한 판정 = 가장 큰 칸, 발동 전부 = 합.
	local list = nil
	if skill.primitive == "circleTarget" and skill.shots then
		list = BossSkillMath.shotsOf(skill)
	elseif (skill.primitive == "line" or skill.primitive == "sector") and skill.volleyShots then
		list = BossSkillMath.volleysOf(skill)
	end
	if list and damage.kind == "attack" then
		local maxMultiplier, sum = 0, 0
		for _, entry in ipairs(list) do
			maxMultiplier = math.max(maxMultiplier, entry.multiplier)
			sum += entry.multiplier
		end
		return maxMultiplier / surviveTargetHits, sum / surviveTargetHits
	end
	local hits = 1
	local primitive = skill.primitive
	if primitive == "circleBoss" then
		hits = #BossSkillMath.pulsesOf(skill)
	elseif primitive == "ring" then
		hits = #BossSkillMath.ringWaves(skill)
	elseif primitive == "circleTarget" then
		hits = skill.sequential and skill.count or 1
	elseif primitive == "charge" then
		hits = skill.dashCount or 1
	elseif primitive == "line" or primitive == "sector" then
		hits = skill.volleys or 1
	elseif primitive == "projectile" then
		hits = skill.count or 1
	elseif primitive == "boomerang" then
		hits = 2 -- BR1-3 가는 길 · 오는 길
	end
	if primitive == "colorMatch" or primitive == "lightningRods" or primitive == "sandSearch" or primitive == "orgel" then
		return skill.failMaxHpFraction, skill.failMaxHpFraction -- BR1-2 색 맞추기 · 번개 조준경 실패(보호막 무시 90%)
	end
	if primitive == "sonic" then
		return skill.tickFraction, skill.tickFraction * skill.ticks -- BR1-2 음파: 한 틱 · 전부(보호막 무시 - 발동당 상한 대신 틱 합 90%)
	end
	if damage.kind == "maxHp" then
		local cap = BossData.mechanics.gimmickFailMaxHpFraction
		return math.min(damage.fraction, cap), math.min(damage.fraction * hits, cap)
	end
	-- attack 배율: 한 판정 = 배율 ÷ 생존 타수. 겹(layers)은 한 번의 실수에 겹 수만큼 맞는다(리듬이면 겹이 가장 많은 파동).
	local layers = skill.layers or 1
	if primitive == "ring" then
		for _, wave in ipairs(BossSkillMath.ringWaves(skill)) do
			layers = math.max(layers, wave.layers)
		end
	end
	local single = damage.multiplier * layers / surviveTargetHits
	return single, single * hits
end

-- "2연타" 검사에 쓰는 몫: %최대체력 스킬은 발동당 합계(연속 찌르기 27.5% × 2 = 55%처럼 한 스킬이 곧 한 덩어리의
-- 실수다 - 상한도 발동 단위로 걸린다), attack 배율 스킬은 판정 한 번(줄넘기 세 번을 다 틀리는 것은 실수 세 번이다).
function BossSkillMath.mistakeShare(skill, surviveTargetHits)
	local single, total = BossSkillMath.damageShares(skill, surviveTargetHits)
	return skill.damage.kind == "maxHp" and total or single
end

-- ─────────────────────────── 스테이지 범위 배율 ───────────────────────────
-- scale배로 넓힌 스킬표 사본(원본 BossData는 절대 안 건드린다). 넓어지는 것은 "걸어서 벗어나는 거리"를 정하는
-- 길이뿐이다 - 반경·안쪽 반경·직선 반폭·돌진 경로 반폭·산개 거리. 파동 두께·속도(점프 회피), 예고 시간, 쿨은 그대로.
local SCALED_FIELDS = { "radiusStuds", "innerRadiusStuds", "halfWidthStuds", "pathHalfWidthStuds", "scatterStuds" }

function BossSkillMath.scaleSkills(skills, scale)
	if scale == 1 then
		return skills
	end
	local scaled = {}
	for id, skill in pairs(skills) do
		local copy = table.clone(skill)
		for _, field in ipairs(SCALED_FIELDS) do
			if copy[field] then
				copy[field] *= scale
			end
		end
		if copy.finisher then -- 29-3: 마무리 일격의 원도 "걸어서 벗어나는 거리"다
			copy.finisher = table.clone(copy.finisher)
			copy.finisher.radiusStuds *= scale
		end
		if copy.shots then -- BR1 칸별 반경도 "걸어서 벗어나는 거리"다
			local shots = {}
			for index, shot in ipairs(copy.shots) do
				shots[index] = table.clone(shot)
				if shot.radiusStuds then
					shots[index].radiusStuds = shot.radiusStuds * scale
				end
			end
			copy.shots = shots
		end
		if copy.pulses then
			local pulses = {}
			for index, pulse in ipairs(copy.pulses) do
				pulses[index] = { innerRadiusStuds = (pulse.innerRadiusStuds or 0) * scale, radiusStuds = pulse.radiusStuds * scale }
			end
			copy.pulses = pulses
		end
		scaled[id] = copy
	end
	return scaled
end

-- ─────────────────────────── 스테이지 밀도(S14, PRD 20.81 [C-3]) ───────────────────────────
-- 밀도 대상 조건: circleTarget · 동시 산개(sequential 아님) · scatterStuds > 0 · 기믹 아님 · gate 없음. 스킬의 densityScalable 플래그가
-- 이 조건과 어긋나면 안 된다(검증이 6종 전부를 대조한다) - 플래그가 실제로 늘리는 것이고, 이 함수는 그 플래그가 맞는지 재는 잣대다.
function BossSkillMath.densityEligible(skill)
	return skill.primitive == "circleTarget" and not skill.sequential and (skill.scatterStuds or 0) > 0
		and skill.role ~= "gimmick" and skill.gate == nil
end

-- 밀도 extra만큼 늘린 스킬표 사본(원본 BossData는 절대 안 건드린다). 대상 스킬의 count += extra, scatterStuds ×= sqrt((count + extra) ÷ count) -
-- 여기서 count는 스킬의 원래 count 필드다(countPerMember 몫은 그대로 - 입장 인원 몫은 BossPatterns.circleCount가 따로 더한다).
-- 범위 배율을 먼저 곱한 표(scaleSkills 결과)를 받는 것이 정해진 순서다: 배율 → 밀도. extra가 0이면 받은 표를 그대로 돌려준다.
function BossSkillMath.densifySkills(skills, extra)
	if extra <= 0 then
		return skills
	end
	local dense = table.clone(skills)
	for id, skill in pairs(skills) do
		if skill.densityScalable then
			local copy = table.clone(skill)
			copy.scatterStuds = skill.scatterStuds * math.sqrt((skill.count + extra) / skill.count)
			copy.count = skill.count + extra
			dense[id] = copy
		end
	end
	return dense
end

-- ─────────────────────────── BR1-2 스테이지 난이도 곡선(shared/data/BossCurveData - docs/design/boss-br1-2.md §1) ───────────────────────────
local BossCurveData = require(ReplicatedStorage.Shared.data.BossCurveData)

-- 이 스테이지의 곡선 행(fromStage ≤ stage인 마지막 행).
function BossSkillMath.curveRow(stage)
	local row = BossCurveData.rows[1]
	for _, r in ipairs(BossCurveData.rows) do
		if (stage or 1) >= r.fromStage then
			row = r
		end
	end
	return row
end

-- 인당 투사체 개수 = BR1 기본 개수 × 행 배율(반올림 · 1 ~ perPersonMax).
function BossSkillMath.perPersonCount(baseCount, row)
	local scaled = (baseCount or 1) * row.projectileCountScale
	if scaled ~= math.huge then
		scaled = math.floor(scaled + 0.5)
	end
	return math.clamp(scaled, 1, BossCurveData.perPersonMax)
end

local TELEGRAPH_FIT_SKIP = { gimmick = true, ring = true, grab = true, reflect = true, sonic = true, colorMatch = true, lightningRods = true, sandSearch = true, orgel = true }

-- 넓어진 범위에서 회피 부등식이 깨지면 모자란 만큼 **모든 전조 칸에** 더한다(큰 범위 = 긴 전조 - 무게 원칙). 사본을 고친다.
function BossSkillMath.fitTelegraphs(skill, standoffStuds, walkSpeedStuds)
	if TELEGRAPH_FIT_SKIP[skill.primitive] then
		return skill, 0
	end
	local added = 0
	for _ = 1, 4 do
		local deficit = 0
		for _, check in ipairs(BossSkillMath.dodgeChecks(skill, standoffStuds, walkSpeedStuds)) do
			if check.distanceStuds > 0 and not check.ok then
				deficit = math.max(deficit, check.requiredSeconds - check.availableSeconds)
			end
		end
		if deficit <= 0 then
			break
		end
		deficit = math.ceil((deficit + 0.01) * 100) / 100
		added += deficit
		skill.telegraphSeconds += deficit
		if skill.repeatTelegraphSeconds then
			skill.repeatTelegraphSeconds += deficit
		end
		for _, key in ipairs({ "shots", "volleyShots" }) do
			if skill[key] then
				local list = {}
				for index, entry in ipairs(skill[key]) do
					list[index] = table.clone(entry)
					if entry.telegraphSeconds then
						list[index].telegraphSeconds = entry.telegraphSeconds + deficit
					end
				end
				skill[key] = list
			end
		end
		for _, key in ipairs({ "ambush", "trackAfterHit", "finisher" }) do
			if skill[key] and skill[key].lockTelegraphSeconds then
				skill[key] = table.clone(skill[key])
				skill[key].lockTelegraphSeconds += deficit
			elseif skill[key] and key == "finisher" then
				skill[key] = table.clone(skill[key])
				skill[key].telegraphSeconds += deficit
			end
		end
	end
	return skill, added
end

-- 곡선 행을 스킬표 사본에 얹는다(원본 BossData는 안 건드린다). 순서: (이미 곱한 이속 보정 위에) 장판 범위 × → 장판 개수 ± → 연쇄 칸 ± → 투사체 인당 개수 · 반경 → 전조 맞춤.
-- zoneExtra를 따로 주면(견습 = 0) 행 값 대신 쓴다. 반환: 새 표, 전조를 늘린 스킬 { [id] = 초 }.
function BossSkillMath.applyCurve(skills, row, zoneExtraOverride, walkSpeedStuds)
	local zoneScaled = {}
	for id, skill in pairs(skills) do
		if skill.primitive ~= "projectile" then
			zoneScaled[id] = skill
		end
	end
	zoneScaled = BossSkillMath.scaleSkills(zoneScaled, row.zoneRangeScale)
	local extra = zoneExtraOverride or row.zoneExtra
	local out, fitted = {}, {}
	for id, skill in pairs(skills) do
		local copy = table.clone(zoneScaled[id] or skill)
		if copy.primitive == "projectile" then
			copy.baseCount = skill.count or 1
			copy.count = BossSkillMath.perPersonCount(skill.count or 1, row)
			copy.radiusStuds = skill.radiusStuds * row.projectileRadiusScale
		end
		if extra ~= 0 and copy.densityScalable and copy.count then
			local count = math.max(1, copy.count + extra)
			copy.scatterStuds = copy.scatterStuds * math.sqrt(count / copy.count)
			copy.count = count
		end
		if copy.chain and (row.chainExtra or 0) ~= 0 then
			copy.chain = table.clone(copy.chain)
			copy.chain.count = math.max(3, copy.chain.count + row.chainExtra)
		end
		if walkSpeedStuds then
			local _, added = BossSkillMath.fitTelegraphs(copy, 8, walkSpeedStuds)
			if added > 0 then
				fitted[id] = added
			end
		end
		out[id] = copy
	end
	return out, fitted
end

return BossSkillMath
