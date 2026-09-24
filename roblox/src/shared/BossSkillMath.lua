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
		if skill.sequential then
			return skill.telegraphSeconds + BossSkillMath.repeatSeconds(skill) * (skill.count - 1)
		end
		return skill.telegraphSeconds
	elseif primitive == "charge" then
		local travel = chargeTravelSeconds or (arenaHalfSizeStuds * 2 / skill.speedStuds)
		return (skill.telegraphSeconds + travel) * (skill.dashCount or 1) + skill.recoverSeconds
	elseif primitive == "line" then
		return skill.telegraphSeconds * (skill.volleys or 1)
	elseif primitive == "gimmick" then
		return skill.telegraphSeconds + (skill.recoverSeconds or 0)
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
		walk("직선 옆걸음", skill.telegraphSeconds, distance)
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
	elseif primitive == "line" then
		hits = skill.volleys or 1
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

return BossSkillMath
