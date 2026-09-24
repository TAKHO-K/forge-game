-- P3c 자동 검증(docs/phase/P3c-log.md). (가) = 서버 시작 때 순수 계산 · (나) = 보스 검증 체인 끝(실제 보스전 · 스탠드인 · 실제 판정 경로).
--   (가) A1 줄넘기 리듬 회피 부등식 표 · A2 가장 가까운 대상(동률 무작위) · A4 다중 피격 높이 · 추적 뒤 고정 · A5 이탈 시뮬 1,000회 ·
--        B1 · B5 무작위 배치 100시드 × 6맵(갇힘 · 벽 근처 · 돌진 보장 · 같은 시드 = 같은 배치) · B4 반경 · 둔덕 높이 · C1 천장 보정 배수 · C3 태초 보석 ×1.2 ·
--        C4 레벨당 필요 경험치 변화율 · v35 이관 · C7 시즌 번호 · E4 보석 판매가 < 가루 가치
--   (나) A2 4인 발탄식 유도(가장 가까운 사람 · 대상 고정 · 구조물 충돌 · 기절 6초) · A3 전갈 1 · 2회차 판정 · A4 번개 추적 · 다중 피격 넉백 · A5 맵 밖 → 복귀 ·
--        B 6맵 배치 · 파트 수 · B2 큰 블록 5타 · 금 · 위에서 부서짐 · B4 둔덕 · 큰 블록 위 판정 · E3 잠금 판매 거절 · E4 보석 판매 · C7 명예의 전당(_verify 저장소)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local ArenaLayout = require(ReplicatedStorage.Shared.ArenaLayout)
local ArenaContainment = require(ReplicatedStorage.Shared.ArenaContainment)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local Option = require(ReplicatedStorage.Shared.Option)
local GemCraft = require(ReplicatedStorage.Shared.GemCraft)
local LeaderboardRules = require(ReplicatedStorage.Shared.LeaderboardRules)

local P3cVerify = {}

local RING_BOSSES = { "section_guardian", "abyssal_lord", "storm_lord" }
local ALL_BOSSES = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[P3c][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[P3c][%s] %s"):format(tag, label))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return passCount, totalCount
	end
	return r
end

local function near(a, b, tolerance)
	return a ~= nil and b ~= nil and math.abs(a - b) <= (tolerance or 1e-6)
end

-- 이탈 시뮬의 파라미터(실제 패턴 데이터 그대로).
function P3cVerify.containmentParams()
	local storm = BossData.bosses.storm_lord.skills
	local launch = storm.strike.onHit[1]
	return {
		strike = { heightStuds = launch.heightStuds, distanceStuds = launch.distanceStuds, extraHeightPerCoHit = launch.extraHeightPerCoHit, maxHeightStuds = launch.maxHeightStuds,
			radiusStuds = storm.strike.radiusStuds * BossRules.maxSkillRangeScale() },
		topBreak = { heightStuds = BossArenaMapData.obstacle.topBreak.heightStuds, distanceStuds = BossArenaMapData.obstacle.topBreak.distanceStuds },
		whirlSpinStuds = storm.whirl.onHit[1].spinRadiusStuds, whirlHeightStuds = storm.whirl.onHit[1].heightStuds,
		pushStuds = BossData.mechanics.rescue.push.graveRadiusStuds, dashStuds = 16, walkStuds = 30,
		perchHeightStuds = BossArenaMapData.obstacle.climbHeightStuds, wallHeightStuds = BossArenaMapData.geometry.wallHeightStuds,
	}
end

-- ═══ (가) ═══

function P3cVerify.runPure()
	print("===P3c 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("A1 줄넘기 리듬", function()
		for _, bossId in ipairs(RING_BOSSES) do
			local boss = BossData.bosses[bossId]
			for id, skill in pairs(boss.skills) do
				if skill.primitive == "ring" then
					local waves = BossSkillMath.ringWaves(skill)
					local beats = {}
					for index, wave in ipairs(waves) do
						table.insert(beats, ("%d: %.2f초 · 속도 %d · 겹 %d"):format(index, wave.startSeconds, wave.speedStuds, wave.layers))
					end
					local allOk, rows = true, {}
					for _, scale in ipairs({ 1, BossRules.maxSkillRangeScale() }) do
						local checks = BossSim.checkDodge(bossId, scale)
						for _, row in ipairs(checks) do
							if row.skillId == id then
								allOk = allOk and row.ok
								if scale == 1 then
									table.insert(rows, ("%s %.2f ≥ %.2f"):format(row.label, row.availableSeconds, row.requiredSeconds))
								end
							end
						end
					end
					r.check(("A1 %s.%s 리듬 \"%s\" [%s] | 회피 부등식(배율 1 · 최대): %s"):format(bossId, id, skill.rhythm and skill.rhythm.label or "옛 모양",
						table.concat(beats, " / "), table.concat(rows, " · ")), allOk and skill.rhythm ~= nil)
				end
			end
		end
		for _, bossId in ipairs(ALL_BOSSES) do
			local _, ok1 = BossSim.checkDodge(bossId, 1)
			local _, okMax = BossSim.checkDodge(bossId, BossRules.maxSkillRangeScale())
			r.check(("A 회피 부등식 전체 %s: 배율 1 %s · 최대 %s"):format(bossId, ok1 and "통과" or "실패", okMax and "통과" or "실패"), ok1 and okMax)
		end
	end)

	r.section("A2 가장 가까운 대상", function()
		local origin = Vector3.new(0, 0, 0)
		local index = BossSkillMath.nearestIndex(origin, { Vector3.new(50, 0, 0), Vector3.new(0, 0, 20), Vector3.new(-70, 0, 5) })
		local counts, draws = { 0, 0, 0 }, 600
		local rng = Random.new(7)
		for _ = 1, draws do
			local pick, ties = BossSkillMath.nearestIndex(origin, { Vector3.new(30, 0, 0), Vector3.new(-30, 0, 0), Vector3.new(0, 0, 30.04) }, function()
				return rng:NextNumber()
			end)
			counts[pick] += 1
			assert(ties == 3)
		end
		r.check(("A2 가장 가까운 자리 = %d번(기대 2) · 동률 3자리(차 0.04 ≤ 0.05) %d회 뽑기 = %d · %d · %d(각 1/3 ± 0.08)"):format(index, draws, counts[1], counts[2], counts[3]),
			index == 2 and math.abs(counts[1] / draws - 1 / 3) < 0.08 and math.abs(counts[2] / draws - 1 / 3) < 0.08 and math.abs(counts[3] / draws - 1 / 3) < 0.08)
		-- 발탄식 유도(순수 기하): 보스 중심 · 가장 가까운 사람이 구조물 뒤 → 경로가 그 구조물에 닿는다.
		local obstacles = { { id = 7, center = Vector3.new(30, 0, 0), radius = 4.5 } }
		local players = { Vector3.new(40, 0, 0), Vector3.new(-60, 0, 20), Vector3.new(0, 0, -75), Vector3.new(55, 0, 60) }
		local target = BossSkillMath.nearestIndex(origin, players)
		local dir = (players[target] - origin).Unit
		local id, contact = ArenaLayout.firstOnPath(obstacles, origin, dir, 135, BossArenaMapData.obstacle.chargeBodyHalfStuds)
		r.check(("A2 4인 발탄식(기하): 대상 %d번(구조물 뒤 40stud) · 경로의 구조물 #%s · 닿는 거리 %.1f(기대 30 − 4.5 − 3 = 22.5) · 기절 %.1f초(돌진 헤롱 %.1f + %.1f)"):format(
			target, tostring(id), contact or -1, BossData.bosses.section_guardian.skills.charge.recoverSeconds + BossArenaMapData.obstacle.chargeStunBonusSeconds,
			BossData.bosses.section_guardian.skills.charge.recoverSeconds, BossArenaMapData.obstacle.chargeStunBonusSeconds),
			target == 1 and id == 7 and near(contact, 22.5) and near(BossData.bosses.section_guardian.skills.charge.recoverSeconds + BossArenaMapData.obstacle.chargeStunBonusSeconds, 6))
	end)

	r.section("A3 경계에서 다시 출발하는 돌진", function()
		local ArenaShape = require(ReplicatedStorage.Shared.ArenaShape)
		local zone = WorldConfig.zones.bossArena1
		local margin = BossData.bosses.scorpion_queen.skills.stab.arenaMarginStuds
		local dir = Vector3.new(math.cos(0.7), 0, math.sin(0.7))
		local first = ArenaShape.clip(zone, zone.center, dir, margin)
		local stop = zone.center + dir * first -- 첫 돌진이 멈춘 자리(부동소수로 경계보다 아주 조금 밖일 수 있다)
		local back = ArenaShape.clip(zone, stop, -dir, margin)
		local out = ArenaShape.clip(zone, stop, dir, margin)
		r.check(("A3 벽 여백에서 멈춘 자리 → 안쪽으로 다시 돌진 %.1fstud(기대 지름 − 여백×2 = %.1f) · 바깥쪽 %.2f(기대 0) - Play 1의 \"경로 0.0stud\" 재발 방지"):format(
			back, 2 * (zone.radius - margin), out), near(back, 2 * (zone.radius - margin), 1e-3) and out <= 1e-3) -- Studio Vector3는 단정밀도(Play 2: 270.0 ± 1e-6 X)
	end)

	r.section("A4 번개", function()
		local strike = BossData.bosses.storm_lord.skills.strike
		local launch = strike.onHit[1]
		local heights = {}
		for coHits = 1, 4 do
			local h = math.min(launch.heightStuds + launch.extraHeightPerCoHit * (coHits - 1), launch.maxHeightStuds)
			heights[coHits] = select(1, ArenaContainment.limitLaunch(nil, Vector3.zero, Vector3.zero, h, 0))
		end
		r.check(("A4 함께 맞은 수 1 · 2 · 3 · 4 → 넉백 높이 %.1f · %.1f · %.1f · %.1f(상한 %.1f < 판정 높이차 상한 %d)"):format(heights[1], heights[2], heights[3], heights[4],
			BossArenaMapData.containment.maxLaunchHeightStuds, TerrainConfig.heightToleranceStuds),
			near(heights[1], 5) and near(heights[2], 6) and near(heights[3], 7) and near(heights[4], 7.5) and BossArenaMapData.containment.maxLaunchHeightStuds < TerrainConfig.heightToleranceStuds)
		local track = strike.trackAfterHit
		local rows = {}
		local ok = true
		for _, scale in ipairs({ 1, BossRules.maxSkillRangeScale() }) do
			for _, row in ipairs(BossSim.checkDodge("storm_lord", scale)) do
				if row.skillId == "strike" then
					ok = ok and row.ok
					table.insert(rows, ("×%.3f %s %.2f ≥ %.2f"):format(scale, row.label, row.availableSeconds, row.requiredSeconds))
				end
			end
		end
		r.check(("A4 추적 %.2f초 → 고정 뒤 %.2f초에 떨어짐 · 구속 %.2f초 | %s"):format(track.trackSeconds, track.lockTelegraphSeconds,
			BossSkillMath.boundSeconds(strike, 140), table.concat(rows, " · ")), ok)
	end)

	r.section("A5 이탈 시뮬", function()
		local zone = WorldConfig.zones.bossArena1
		local sim = BossArenaMapData.containment.sim
		local counts = ArenaContainment.simulate(zone, P3cVerify.containmentParams(), sim.trials, sim.seed, sim.maxEvents)
		local kinds = {}
		for kind, n in pairs(counts.byKind) do
			table.insert(kinds, ("%s %d"):format(kind, n))
		end
		table.sort(kinds)
		r.check(("A5 무작위 패턴 조합 %d회: 이탈 %d · 벽 넘김 %d · 가장 높은 정점 %.1f(벽 %d) · 가장 먼 착지 %.1f(반경 %d) · 사건 %s"):format(
			counts.trials, counts.exits, counts.overWall, counts.maxApex, BossArenaMapData.geometry.wallHeightStuds, counts.maxRadial, zone.radius, table.concat(kinds, " · ")),
			counts.trials == sim.trials and counts.exits == 0 and counts.overWall == 0)
		-- 한 번의 넉백: 벽 1stud에서 바깥으로 거리 12를 받아도 착지는 벽에서 3 안쪽.
		local at = zone.center + Vector3.new(zone.radius - 1.5, 0, 0)
		local h, d = ArenaContainment.limitLaunch(zone, at, Vector3.new(1, 0, 0), 20, 30)
		local inside = ArenaContainment.isOutside(zone, at + Vector3.new(d, 0, 0), nil)
		r.check(("A5 벽 1.5stud 바깥쪽 넉백(높이 20 · 거리 30 요청) → 높이 %.1f · 거리 %.2f · 착지 원 밖=%s · 복귀 자리(원 밖 10) 중심에서 %.1f"):format(h, d, tostring(inside),
			(ArenaContainment.rescuePoint(zone, zone.center + Vector3.new(zone.radius + 10, 0, 0)) - zone.center).Magnitude),
			near(h, 7.5) and d <= 1e-6 and not inside)
	end)

	r.section("B 무작위 배치 100시드", function()
		for _, bossId in ipairs(ALL_BOSSES) do
			local theme = BossArenaMapData.maps[bossId]
			local options = ArenaLayout.optionsFor(BossData.bosses[bossId])
			options.forceConnectivity = true -- 검증은 싼 검사가 실패해도 연결(갇힘)을 늘 잰다
			local fails, trapped, nearWall, minWall, minPair, minCov, maxAttempts, minItems, maxItems = 0, 0, 0, math.huge, math.huge, 1, 0, math.huge, 0
			for seed = 1, 100 do
				local layout = ArenaLayout.generate(theme, seed * 7919, options)
				local report = ArenaLayout.validate(layout, options)
				fails += report.ok and 0 or 1
				trapped += report.connected and 0 or 1
				nearWall += report.minWallGap < BossArenaMapData.layout.wallGapStuds - 1e-6 and 1 or 0
				minWall, minPair, minCov = math.min(minWall, report.minWallGap), math.min(minPair, report.minPairGap), math.min(minCov, report.coverage)
				maxAttempts = math.max(maxAttempts, layout.attempts)
				minItems, maxItems = math.min(minItems, #layout.items), math.max(maxItems, #layout.items)
				if seed % 20 == 0 then
					task.wait()
				end
			end
			local again = ArenaLayout.generate(theme, 42, options)
			local same = ArenaLayout.generate(theme, 42, options)
			local identical = #again.items == #same.items and again.items[1].x == same.items[1].x and again.items[#again.items].z == same.items[#same.items].z
			r.check(("B %s(%s) 100시드: 실패 %d · 갇힘 %d · 벽 근처(< %d) %d · 벽 틈 최소 %.1f · 서로 %.1f · 돌진 보장 최소 %.0f%%(기준 %.0f%%) · 구조물 %d ~ %d · 최대 시도 %d · 같은 시드 = 같은 배치 %s"):format(
				bossId, theme.name, fails, trapped, BossArenaMapData.layout.wallGapStuds, nearWall, minWall, minPair, minCov * 100, options.coverageMin * 100, minItems, maxItems, maxAttempts, tostring(identical)),
				fails == 0 and trapped == 0 and nearWall == 0 and identical)
		end
		local geometry = BossArenaMapData.geometry
		local mounds = BossArenaMapData.layout.mounds
		r.check(("B4 반경 %d ≤ 진동파 최대 반경 %.1f · 둔덕 층 %.1f ≤ 계단 한 단 %d · 높이 상한 %.1f < 판정 높이차 %d · 큰 블록 윗면 %.1f + 넉백 상한 %.1f = %.1f < 벽 %d"):format(
			geometry.radiusStuds, geometry.waveMaxRadiusStuds, mounds.stepStuds, TerrainConfig.maxStepHeightStuds, mounds.maxHeightStuds, TerrainConfig.heightToleranceStuds,
			BossArenaMapData.obstacle.climbHeightStuds, BossArenaMapData.containment.maxLaunchHeightStuds, BossArenaMapData.obstacle.climbHeightStuds + BossArenaMapData.containment.maxLaunchHeightStuds,
			geometry.wallHeightStuds),
			geometry.radiusStuds <= geometry.waveMaxRadiusStuds and mounds.stepStuds <= TerrainConfig.maxStepHeightStuds and mounds.maxHeightStuds < TerrainConfig.heightToleranceStuds
				and BossArenaMapData.obstacle.climbHeightStuds + BossArenaMapData.containment.maxLaunchHeightStuds < geometry.wallHeightStuds)
	end)

	r.section("C 경제 결정", function()
		local discount = EnhanceConfig.ceilingDiscount
		local offset = CharacterLevelConfig.levelStageOffset
		local lo, hi = discount.rampFromLevel + offset, discount.fullAtLevel + offset
		local mid = (lo + hi) / 2
		local base20 = EnhanceConfig.goldCost[21]
		local expected = math.floor(GoldCost.cost(base20, hi + 1000, "enhance") * discount.factor)
		r.check(("C1 천장 보정 배수: 스테이지 %d → %.3f · %d → %.3f · %d → %.3f · +19 → +20 1회는 보정 없음(%s) · +20 → +21 @%d = %s(기대 %s)"):format(
			lo, Enhance.getCeilingCostFactor(lo), math.floor(mid), Enhance.getCeilingCostFactor(mid), hi, Enhance.getCeilingCostFactor(hi),
			tostring(Enhance.getCost(19, hi + 1000) == GoldCost.cost(EnhanceConfig.goldCost[20], hi + 1000, "enhance")), hi + 1000, tostring(Enhance.getCost(20, hi + 1000)), tostring(expected)),
			near(Enhance.getCeilingCostFactor(lo), 1) and near(Enhance.getCeilingCostFactor(hi), discount.factor) and near(Enhance.getCeilingCostFactor(mid), (1 + discount.factor) / 2, 1e-3)
				and Enhance.getCost(19, hi + 1000) == GoldCost.cost(EnhanceConfig.goldCost[20], hi + 1000, "enhance") and Enhance.getCost(20, hi + 1000) == expected)
		local ratio = Option.gradeFactor("primordial") / Option.gradeFactor("ancient")
		r.check(("C3 태초 보석 ÷ 고대 = ×%.3f(기준 ≥ ×1.2)"):format(ratio), ratio >= 1.2 - 1e-9)
		local minR, minAt, maxR, maxAt = math.huge, 0, 0, 0
		for level = 1, 30000 do
			local rr = CharacterLevel.getExpToNextLevel(level + 1) / CharacterLevel.getExpToNextLevel(level)
			if rr < minR then
				minR, minAt = rr, level
			end
			if rr > maxR then
				maxR, maxAt = rr, level
			end
			if level % 5000 == 0 then
				task.wait()
			end
		end
		local at125 = CharacterLevel.getExpToNextLevel(126) / CharacterLevel.getExpToNextLevel(125)
		local capExp = CharacterLevel.getExpForLevel(34230)
		r.check(("C4 레벨당 필요 경험치 비: 125 → 126 = ×%.4f(옛 ×0.0077) · 1 ~ 30,000 최소 ×%.4f(@%d) · 최대 ×%.4f(@%d, 상한 ×1.35) · 처치 수 126 = %d(×6 · 그대로 %d) · 배수 1로 돌아오는 레벨 %d · 누적(34,230) %.3g < 1e300"):format(
			at125, minR, minAt, maxR, maxAt, CharacterLevel.getExpectedKills(126, 6), math.ceil(CharacterLevel.getTargetKills(126) / 6 - 1e-9),
			(function()
				local l = 126
				while CharacterLevel.getExpScale(l) > 1 do
					l += 1
				end
				return l
			end)(), capExp),
			at125 >= 1 and at125 <= 1.1 and minR >= 1 and maxR <= 1.35 and CharacterLevel.getExpectedKills(126, 6) == math.ceil(CharacterLevel.getTargetKills(126) / 6 - 1e-9) and capExp < 1e300)
		-- v35 이관: 레벨 300 중간(진행 40%)의 옛 경험치 → 새 곡선에서 같은 레벨 · 같은 진행률.
		local SaveSystem = require(script.Parent.SaveSystem)
		-- 옛 곡선(v34 - 배수 없음)의 레벨 300 임계값 · 필요량.
		local function oldNeed(level)
			return math.floor(CharacterLevel.getTargetKills(level) * CharacterLevel.getMonsterExpAtLevel(level) + 0.5)
		end
		local oldAt300 = CharacterLevel.getExpForLevel(126)
		for level = 126, 299 do
			oldAt300 += oldNeed(level)
		end
		local oldNeed300 = oldNeed(300)
		local data = SaveSystem.defaultProfile()
		data.version = 34
		local classId = next(data.classes)
		data.classes[classId].characterExp = oldAt300 + oldNeed300 * 0.4
		local low = next(data.classes, classId)
		if low then
			data.classes[low].characterExp = 1000
		end
		local migrated = SaveSystem.migrate(data)
		local exp = migrated.classes[classId].characterExp
		local level = CharacterLevel.getLevelFromExp(exp)
		local progress = CharacterLevel.getProgress(exp, level).ratio
		r.check(("C4 이관 v34 → v%d: 레벨 %d(기대 300) · 진행률 %.3f(기대 0.400) · 126 아래 경험치 그대로 %s · isValidProfile %s"):format(migrated.version, level, progress,
			tostring(not low or migrated.classes[low].characterExp == 1000), tostring(SaveSystem.isValidProfile(migrated))),
			migrated.version == 35 and level == 300 and near(progress, 0.4, 1e-6) and (not low or migrated.classes[low].characterExp == 1000) and SaveSystem.isValidProfile(migrated))
		local cfg = { seasonId = 3, seasonLengthDays = 28, seasonStartUnix = 0 }
		local fixed = LeaderboardRules.seasonAt(1e9, cfg)
		cfg.seasonStartUnix = 1000000000
		local s1 = LeaderboardRules.seasonAt(1000000000, cfg)
		local s1b = LeaderboardRules.seasonAt(1000000000 + 28 * 86400 - 1, cfg)
		local s2 = LeaderboardRules.seasonAt(1000000000 + 28 * 86400, cfg)
		local before = LeaderboardRules.seasonAt(999999999, cfg)
		r.check(("C7 시즌 번호: 시작일 없음 → seasonId(%d) · 시작 %d · 27일 23:59:59 %d · 28일 %d · 시작 전 %d · 기간 %d일 · 전당 상위 %d"):format(fixed, s1, s1b, s2, before,
			LeaderboardConfig.seasonLengthDays, LeaderboardConfig.hallTopN),
			fixed == 3 and s1 == 1 and s1b == 1 and s2 == 2 and before == 1 and LeaderboardConfig.seasonLengthDays == 28)
	end)

	r.section("E4 보석 판매가", function()
		local rows, ok = {}, true
		for _, grade in ipairs({ "epic", "legendary", "relic", "ancient", "primordial" }) do
			for _, itemLevel in ipairs({ 1, 100, 5000 }) do
				local gem = { grade = grade, itemLevel = itemLevel }
				local price, dustValue = GemCraft.sellPrice(gem, 500), GemCraft.dustGoldValue(gem, 500)
				ok = ok and price >= 1 and price < dustValue
				if itemLevel == 100 then
					table.insert(rows, ("%s %d < %d"):format(ArmorData.grades[grade].displayName, price, dustValue))
				end
			end
		end
		r.check(("E4 보석 판매가 < 분해 가루 가치(스테이지 500 · itemLevel 100): %s"):format(table.concat(rows, " · ")), ok)
	end)

	local passCount, totalCount = r.summary()
	print(("===P3c 검증 끝(가)=== %d/%d 통과"):format(passCount, totalCount))
end

-- ═══ (나) ═══

local function fullHeal(player)
	local PlayerState = require(script.Parent.PlayerState)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	PlayerDamage.syncHud(player)
end

local function place(root, position)
	root.CFrame = CFrame.new(position)
	RunService.Heartbeat:Wait()
end

local function spawnBoss(player, env, bossId, seed)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local MonsterState = require(script.Parent.MonsterState)
	BossEncounter.despawnFor(player)
	env.applyStage(player, BossData.stageInterval)
	BossEncounter.setDebugForcedBoss(player, bossId)
	BossArenaMap.debugNextSeed = seed
	BossEncounter.spawnFor(player, BossData.stageInterval)
	local model = BossEncounter.getActive(player)
	local encounter = BossEncounter.getEncounter(player)
	return model, model and MonsterState.getData(model), encounter
end

-- 스탠드인 멤버(테이블 Player - 29-4 newStandIn과 같은 모양). root.Position을 바꿔 옮긴다.
local function newStandIn(model, members, name, position)
	local PlayerState = require(script.Parent.PlayerState)
	local BossEncounter = require(script.Parent.BossEncounter)
	local fakeRoot = { Position = position }
	local fake = { Name = name, UserId = -9600 - #members, Parent = Workspace }
	fake.Character = {
		FindFirstChild = function(_, child)
			return child == "HumanoidRootPart" and fakeRoot or nil
		end,
		FindFirstChildOfClass = function()
			return nil
		end,
	}
	function fake:SetAttribute() end
	function fake:GetAttribute()
		return nil
	end
	PlayerState.init(fake)
	table.insert(members, fake)
	BossEncounter.debugAddMember(model, fake)
	return fake, fakeRoot
end

local function clearStandIns(player, standIns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossTrap = require(script.Parent.BossTrap)
	local PlayerState = require(script.Parent.PlayerState)
	local encounter = BossEncounter.getEncounter(player)
	for _, fake in ipairs(standIns) do
		BossTrap.release(fake, "reset")
		PlayerState.clear(fake)
		if encounter then
			local at = table.find(encounter.members, fake)
			if at then
				table.remove(encounter.members, at)
			end
		end
	end
	table.clear(standIns)
end

-- 보스를 직접 step한다(멤버 전원 - 스탠드인 포함). 개발 캐릭터를 어그로 밖에 두면 MonsterAI는 이 보스를 안 돌린다.
local function drive(player, root, model, data, seconds, untilFn, keepHp)
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local startedAt = os.clock()
	while os.clock() - startedAt < seconds do
		RunService.Heartbeat:Wait()
		if not keepHp then
			fullHeal(player)
		end
		if not model.Parent then
			break
		end
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, BossEncounter.getMembersOfModel(model))
		if untilFn and untilFn() then
			break
		end
	end
end

-- 중심에서 방향 dir로 벽까지(양쪽) 구조물이 없는 방위를 찾는다.
local function clearDirection(zoneKey, zone, both)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local body = BossArenaMapData.obstacle.chargeBodyHalfStuds
	for step = 0, 71 do
		local angle = math.rad(step * 5 + 3)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local wall = zone.center + dir * (zone.radius - 5)
		local clear = BossArenaMap.firstOnPath(zoneKey, zone.center, dir, zone.radius, body) == nil
		if both then
			clear = clear and BossArenaMap.firstOnPath(zoneKey, wall, -dir, zone.radius * 2, body) == nil
		end
		-- 발탄식이 아닌 검사(클리어 경로)는 입장 방위 · 킷(피뢰침 ±8)을 피할 필요가 없다 - 돌진은 킷을 통과한다.
		if clear then
			return dir
		end
	end
	return nil
end

function P3cVerify.runLive(player, env)
	print("===P3c 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local BossArenaContainment = require(script.Parent.BossArenaContainment)
	local MonsterState = require(script.Parent.MonsterState)
	local PlayerState = require(script.Parent.PlayerState)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local FLOOR = BossArenaMap.floorTopY()
	local events = {}
	BossPatterns.debugEventHook = function(kind, record)
		table.insert(events, { kind = kind, at = os.clock(), record = record })
	end
	local standIns = {}
	-- 앞 블록(P3b(나) D3)이 건 "받는 피해 0"(40초)이 남아 있으면 피해로 재는 항목이 거짓 X가 난다(P3c Play 1 - 파편 −0%) - 먼저 푼다.
	PlayerState.clearIncomingDamageMultiplier(player)
	-- 섹션이 에러로 끝나도 다음 섹션이 깨끗하게 시작하게(리뷰 10): 고정 해제 · 고정 시드 비우기 · 스탠드인 정리.
	local rawSection = r.section
	r.section = function(name, fn)
		rawSection(name, fn)
		if root then
			root.Anchored = false
		end
		BossArenaMap.debugNextSeed = nil
		BossPatterns.debugJudgeHook = nil
		BossPatterns.debugSendHook = nil
		clearStandIns(player, standIns)
		PlayerState.clearIncomingDamageMultiplier(player)
	end

	r.section("A2 4인 발탄식 유도", function()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 101)
		local zone = WorldConfig.zones[encounter.zoneKey]
		-- 중심에서 곧게 갔을 때 처음 걸리는 것이 자기 자신인 구조물(작은 것 · 큰 블록 모두 된다).
		local target = nil
		for _, o in ipairs(BossArenaMap.obstacles(encounter.zoneKey)) do
			local dir = Vector3.new(o.center.X - zone.center.X, 0, o.center.Z - zone.center.Z).Unit
			if o.group ~= "feature" and BossArenaMap.firstOnPath(encounter.zoneKey, zone.center, dir, zone.radius, BossArenaMapData.obstacle.chargeBodyHalfStuds) == o.id then
				target = o
				break
			end
		end
		assert(target, "곧게 닿는 구조물이 없다")
		local dir = Vector3.new(target.center.X - zone.center.X, 0, target.center.Z - zone.center.Z).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local distance = (Vector3.new(target.center.X, 0, target.center.Z) - Vector3.new(zone.center.X, 0, zone.center.Z)).Magnitude
		root.Anchored = true
		-- 개발 캐릭터 = 4번째 사람(가장 멀리 - 반대편 130). Play 1은 80에 두어 구조물 뒤 사람(최대 약 117)보다 가까웠다(검증 쪽 X).
		place(root, zone.center - dir * 130 + Vector3.new(0, FLOOR + 3, 0))
		local members = { player }
		local behind, behindRoot = newStandIn(model, members, "Behind", zone.center + dir * (distance + target.radius + 6) + Vector3.new(0, FLOOR + 3, 0))
		table.insert(standIns, behind)
		local b = newStandIn(model, members, "Side", zone.center + side * (distance + 30) + Vector3.new(0, FLOOR + 3, 0))
		table.insert(standIns, b)
		local c, cRoot = newStandIn(model, members, "Late", zone.center - side * (distance + 40) + Vector3.new(0, FLOOR + 3, 0))
		table.insert(standIns, c)
		table.clear(events)
		BossPatterns.force(model, data, "charge")
		local st = MonsterState.getBossPatternState(model)
		local moved = false
		drive(player, root, model, data, 10, function()
			if st.phase == "focus" and not moved and os.clock() - (events[1] and events[1].at or os.clock()) > 0.6 then
				cRoot.Position = zone.center + Vector3.new(0, FLOOR + 3, 0) + side * 4 -- 전조 도중 다른 사람이 보스 코앞으로 - 대상은 바뀌면 안 된다
				moved = true
			end
			return st.phase == "chargeRecover"
		end)
		local targets, ended = {}, nil
		for _, e in ipairs(events) do
			if e.kind == "chargeTarget" then
				table.insert(targets, e.record)
			elseif e.kind == "chargeEnd" then
				ended = e.record
			end
		end
		local lastBreak = BossArenaMap.lastBreak(encounter.zoneKey)
		r.check(("A2 4인(개발 + 스탠드인 3): 대상 %s(기대 Behind - 구조물 #%d 뒤) · 전조 중 다른 사람이 코앞으로 와도 대상 확정 %d번(기대 1) · 경로의 구조물 #%s · 충돌 %s · 기절 %.2f초(기대 6) · 부서짐 %s(#%s)"):format(
			tostring(targets[1] and targets[1].player and targets[1].player.Name), target.id, #targets, tostring(targets[1] and targets[1].obstacleId), tostring(ended and ended.crashed),
			ended and ended.recoverSeconds or -1, tostring(lastBreak and lastBreak.cause), tostring(lastBreak and lastBreak.id)),
			targets[1] and targets[1].player == behind and #targets == 1 and targets[1].obstacleId == target.id and ended and ended.crashed and near(ended.recoverSeconds, 6)
				and lastBreak and lastBreak.cause == "charge" and lastBreak.id == target.id)
		r.note(("A2 기록: 전조 시작 · 대상 확정 · 판정(돌진 끝) · 기절 = %s"):format(ended and ("충돌 뒤 헤롱 " .. ended.recoverSeconds .. "초") or "없음"))
		behindRoot.Position = behindRoot.Position -- (자리 유지)
		clearStandIns(player, standIns)
		root.Anchored = false
		BossEncounter.despawnFor(player)
	end)

	r.section("A3 전갈 여왕 2회 돌진", function()
		local model, data, encounter = spawnBoss(player, env, "scorpion_queen", 202)
		local zone = WorldConfig.zones[encounter.zoneKey]
		local dir = clearDirection(encounter.zoneKey, zone, true)
		assert(dir, "양쪽이 빈 방위가 없다")
		local side = Vector3.new(-dir.Z, 0, dir.X)
		root.Anchored = true
		place(root, zone.center + side * 70 + Vector3.new(0, FLOOR + 3, 0))
		local members = { player }
		local victim = newStandIn(model, members, "Victim", zone.center + dir * 30 + Vector3.new(0, FLOOR + 3, 0))
		table.insert(standIns, victim)
		local hpBefore = PlayerState.getHp(victim)
		local maxHp = PlayerState.getMaxHp(victim)
		table.clear(events)
		BossPatterns.force(model, data, "stab")
		local st = MonsterState.getBossPatternState(model)
		drive(player, root, model, data, 14, function()
			return st.phase == "chargeRecover"
		end)
		local hits = {}
		for _, e in ipairs(events) do
			if e.kind == "chargeHit" and e.record.player == victim then
				table.insert(hits, e.record.dashIndex)
			end
		end
		local lost = (hpBefore - PlayerState.getHp(victim)) / maxHp
		r.check(("A3 같은 사람이 1 · 2회차 모두 판정: 돌진 [%s](기대 1 · 2) · 잃은 체력 %.1f%%(기대 27.5 × 2 = 55 - 무적 시간 · 발동 상한이 2회차를 막지 않는다)"):format(
			table.concat(hits, " · "), lost * 100), #hits == 2 and hits[1] == 1 and hits[2] == 2 and near(lost, 0.55, 0.01))
		clearStandIns(player, standIns)
		root.Anchored = false
		BossEncounter.despawnFor(player)
	end)

	r.section("A4 번개 추적 · 다중 피격", function()
		local model, data, encounter = spawnBoss(player, env, "storm_lord", 303)
		local zone = WorldConfig.zones[encounter.zoneKey]
		root.Anchored = true
		place(root, zone.center + Vector3.new(0, FLOOR + 3, 50))
		local members = { player }
		local s1, s1Root = newStandIn(model, members, "S1", zone.center + Vector3.new(40, FLOOR + 3, 0))
		local s2 = newStandIn(model, members, "S2", zone.center + Vector3.new(41, FLOOR + 3, 1))
		local s3 = newStandIn(model, members, "S3", zone.center + Vector3.new(-45, FLOOR + 3, 0))
		for _, s in ipairs({ s1, s2, s3 }) do
			table.insert(standIns, s)
		end
		table.clear(events)
		local sends = {}
		BossPatterns.debugSendHook = function(kind, payload, serverTime)
			if kind == "meteorImpact" or kind == "meteorLock" or kind == "meteor" then
				table.insert(sends, { kind = kind, at = os.clock(), payload = payload })
			end
		end
		BossPatterns.force(model, data, "strike")
		local impacts, moved = 0, false
		drive(player, root, model, data, 8, function()
			for _, s in ipairs(sends) do
				if s.kind == "meteorImpact" and not s.counted then
					s.counted = true
					impacts += 1
				end
			end
			if impacts == 1 and not moved then
				s1Root.Position = zone.center + Vector3.new(48, FLOOR + 3, 4) -- 넉백으로 날아간 자리(추적 중)
				moved = true
			end
			return impacts >= 2
		end)
		BossPatterns.debugSendHook = nil
		local impactAt, lockAt, secondAt = {}, nil, nil
		for _, s in ipairs(sends) do
			if s.kind == "meteorImpact" then
				table.insert(impactAt, s.at)
			elseif s.kind == "meteorLock" then
				lockAt = s.at
			end
		end
		secondAt = impactAt[2]
		local launches, lock = {}, nil
		for _, e in ipairs(events) do
			if e.kind == "launch" then
				table.insert(launches, e.record)
			elseif e.kind == "trackLock" then
				lock = e.record
			end
		end
		-- P3d G-f: "함께 맞은 수" = 같은 원 안(옛 = 회차 전체 4명). 배치상 S1 · S2(1.4stud 곁)만 같은 원 - 2명 → 높이 6, 개발 캐릭터 · S3은 혼자 → 5.
		local firstCo, firstH, soloCo = 0, 0, 0
		for _, launch in ipairs(launches) do
			if launch.player == s1 and firstCo == 0 then
				firstCo, firstH = launch.coHits, launch.limitedHeight
			elseif launch.player == player and soloCo == 0 then
				soloCo = launch.coHits
			end
		end
		local s1Lock = nil
		for _, entry in ipairs(lock and lock.locked or {}) do
			if entry.player == s1 then
				s1Lock = entry.position
			end
		end
		local track = data.skills.strike.trackAfterHit
		r.check(("A4 첫 낙뢰에 같은 원에서 함께 맞은 수 S1 %d(기대 2 - S1 · S2) · 개발 %d(기대 1) → S1 넉백 높이 %.2f(기대 6) · 추적 고정 %.2f초 뒤(기대 %.2f) · 고정 → 둘째 판정 %.2f초(기대 %.2f) · S1 고정 자리 = 날아간 자리 %s"):format(
			firstCo, soloCo, firstH, (lockAt and impactAt[1]) and (lockAt - impactAt[1]) or -1, track.trackSeconds, (secondAt and lockAt) and (secondAt - lockAt) or -1, track.lockTelegraphSeconds,
			tostring(s1Lock and (Vector3.new(s1Lock.X, 0, s1Lock.Z) - Vector3.new(zone.center.X + 48, 0, zone.center.Z + 4)).Magnitude < 0.5)),
			firstCo == 2 and soloCo == 1 and near(firstH, 6) and lockAt and near(lockAt - impactAt[1], track.trackSeconds, 0.1) and secondAt and near(secondAt - lockAt, track.lockTelegraphSeconds, 0.1)
				and s1Lock ~= nil and (Vector3.new(s1Lock.X, 0, s1Lock.Z) - Vector3.new(zone.center.X + 48, 0, zone.center.Z + 4)).Magnitude < 0.5)
		clearStandIns(player, standIns)
		root.Anchored = false
		BossEncounter.despawnFor(player)
	end)

	r.section("A5 맵 밖 → 복귀", function()
		local _, _, encounter = spawnBoss(player, env, "section_guardian", 404)
		local zone = WorldConfig.zones[encounter.zoneKey]
		root.Anchored = false
		local before = #BossArenaContainment.corrections()
		local hp = PlayerState.getHp(player)
		place(root, zone.center + Vector3.new(zone.radius + 12, FLOOR + 3, 0))
		local waited = 0
		while #BossArenaContainment.corrections() == before and waited < 2 do
			waited += task.wait(0.05)
		end
		local fix = BossArenaContainment.corrections()[before + 1]
		local after = root.Position
		local d = (Vector3.new(after.X, 0, after.Z) - Vector3.new(zone.center.X, 0, zone.center.Z)).Magnitude
		r.check(("A5 원 밖 12stud로 옮김 → %.2f초 뒤 보정(%s) · 중심에서 %.1f(< 반경 %d) · 체력 %s"):format(waited, tostring(fix and fix.reason), d, zone.radius,
			tostring(PlayerState.getHp(player) == hp)), fix ~= nil and fix.reason == "outside" and d < zone.radius and PlayerState.getHp(player) == hp)
		local before2 = #BossArenaContainment.corrections()
		place(root, zone.center + Vector3.new(30, FLOOR - 12, 0))
		waited = 0
		while #BossArenaContainment.corrections() == before2 and waited < 2 do
			waited += task.wait(0.05)
		end
		local fix2 = BossArenaContainment.corrections()[before2 + 1]
		r.check(("A5 바닥 아래 12stud → %.2f초 뒤 보정(%s) · 발밑 높이 %.1f(바닥 %.1f 위) · 체력 %s"):format(waited, tostring(fix2 and fix2.reason), root.Position.Y, FLOOR,
			tostring(PlayerState.getHp(player) == hp)), fix2 ~= nil and fix2.reason == "fell" and root.Position.Y > FLOOR and PlayerState.getHp(player) == hp)
		BossEncounter.despawnFor(player)
	end)

	r.section("B 6맵 배치 · 파트 수", function()
		local rows = {}
		for index, bossId in ipairs(ALL_BOSSES) do
			local _, _, encounter = spawnBoss(player, env, bossId, 500 + index)
			local zone = WorldConfig.zones[encounter.zoneKey]
			local layout = BossArenaMap.getLayout(encounter.zoneKey)
			local report = ArenaLayout.validate(layout, ArenaLayout.optionsFor(BossData.bosses[bossId]))
			local baseModel, dressing = BossArenaMap.debugModels(encounter.zoneKey)
			local function parts(instance)
				local n = 0
				for _, d in ipairs(instance and instance:GetDescendants() or {}) do
					n += d:IsA("BasePart") and 1 or 0
				end
				return n
			end
			local colliders, mounds = 0, 0
			local tall = Workspace:FindFirstChild("BossArenaTallColliders")
			local GroundProbe = require(script.Parent.GroundProbe)
			for _, folder in ipairs({ GroundProbe.folder(), tall }) do
				for _, child in ipairs(folder and folder:GetChildren() or {}) do
					if (child.Name == "ArenaObstacleCollider" or child.Name == "BossArenaMound") and (Vector3.new(child.Position.X, 0, child.Position.Z) - Vector3.new(zone.center.X, 0, zone.center.Z)).Magnitude < zone.radius then
						if child.Name == "BossArenaMound" then
							mounds += 1
						else
							colliders += 1
						end
					end
				end
			end
			local total = parts(baseModel) + 1 + parts(dressing) + colliders + mounds + #(encounter.kitParts or {})
			table.insert(rows, ("%s 시드 %d 구조물 %d · 둔덕 %d(층 %d) · 파트 %d(기반 %d · 장식+구조물 %d · 충돌 %d · 킷 %d)"):format(bossId, layout.seed, #layout.items, #layout.mounds, mounds,
				total, parts(baseModel) + 1, parts(dressing), colliders, #(encounter.kitParts or {})))
			r.check(("B %s(%s): 시드 %d · 구조물 %d · 검사(벽 %.1f · 서로 %.1f · 연결 %s · 돌진 %.0f%%) 통과=%s"):format(bossId, BossArenaMapData.maps[bossId].name, layout.seed, #layout.items,
				report.minWallGap, report.minPairGap, tostring(report.connected), report.coverage * 100, tostring(report.ok)), report.ok and layout.seed == 500 + index)
			if bossId == "frost_giant" then
				task.wait(0.5)
				local all, allParts = 0, 0
				for _, d in ipairs(Workspace:GetDescendants()) do
					all += 1
					allParts += d:IsA("BasePart") and 1 or 0
				end
				r.note(("B 성능: 보스전 장면(서리 거인) 워크스페이스 인스턴스 %d · 파트 %d(P2.5a 기준선 1,908 ~ 1,918 · 1,067 ~ 1,069 / P3a 2,004 · 1,139)"):format(all, allParts))
			end
			BossEncounter.despawnFor(player)
		end
		r.note("B 파트 표: " .. table.concat(rows, " / "))
	end)

	r.section("B2 큰 블록 5타 · 금 · 위에서 부서짐", function()
		local _, _, encounter = spawnBoss(player, env, "section_guardian", 606)
		local zoneKey = encounter.zoneKey
		local block = nil
		for _, o in ipairs(BossArenaMap.obstacles(zoneKey)) do
			if o.climbable then
				block = o
			end
		end
		assert(block, "큰 블록이 없다")
		local need = BossArenaMapData.obstacle.hitsToBreak
		local crackedAt = nil
		for hit = 1, need - 1 do
			MonsterState.applyDamage(block.model, 1, BossData.stageInterval, player, { committedAt = os.clock() })
			task.wait(BossArenaMapData.obstacle.hitIntervalSeconds + 0.05)
			for _, o in ipairs(BossArenaMap.obstacles(zoneKey)) do
				if o.id == block.id and o.cracked and not crackedAt then
					crackedAt = hit
				end
			end
		end
		local still = false
		for _, o in ipairs(BossArenaMap.obstacles(zoneKey)) do
			still = still or o.id == block.id
		end
		fullHeal(player)
		root.Anchored = true
		place(root, block.center + Vector3.new(0, block.height + 3, 0))
		local hpBefore = PlayerState.getHp(player) / PlayerState.getMaxHp(player)
		MonsterState.applyDamage(block.model, 1, BossData.stageInterval, player, { committedAt = os.clock() })
		local info = BossArenaMap.lastBreak(zoneKey)
		local hpAfter = PlayerState.getHp(player) / PlayerState.getMaxHp(player)
		root.Anchored = false
		r.check(("B2 %s(반경 %.1f · 윗면 %.1f): %d타까지 남음=%s · 금 표시 %s타째(기대 %d) · %d타째 부서짐(%s) · 위에 선 사람 튕김 %d · 체력 −%.0f%%(기대 10)"):format(
			block.kind, block.radius, block.height, need - 1, tostring(still), tostring(crackedAt), need - BossArenaMapData.obstacle.crackAtHitsLeft, need,
			tostring(info and info.cause), info and #info.launched or 0, (hpBefore - hpAfter) * 100),
			still and crackedAt == need - BossArenaMapData.obstacle.crackAtHitsLeft and info and info.id == block.id and info.cause == "hits" and #info.launched == 1
				and near(hpBefore - hpAfter, BossArenaMapData.obstacle.topBreak.maxHpFraction, 1e-6))
		BossEncounter.despawnFor(player)
	end)

	r.section("B4 높이별 판정", function()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 707)
		local zone = WorldConfig.zones[encounter.zoneKey]
		local layout = BossArenaMap.getLayout(encounter.zoneKey)
		local judged = {}
		BossPatterns.debugJudgeHook = function(record)
			table.insert(judged, record)
		end
		local spots = {}
		local mound = layout.mounds[1]
		if mound then
			table.insert(spots, { label = ("둔덕 윗면(+%.1f)"):format(mound.layers * mound.stepStuds), position = zone.center + Vector3.new(mound.x, FLOOR + mound.layers * mound.stepStuds + 3, mound.z) })
		end
		for _, o in ipairs(BossArenaMap.obstacles(encounter.zoneKey)) do
			if o.climbable then
				table.insert(spots, { label = ("큰 블록 윗면(+%.1f)"):format(o.height), position = o.center + Vector3.new(0, o.height + 3, 0) })
				break
			end
		end
		table.insert(spots, { label = "바닥(+0)", position = zone.center + Vector3.new(60, FLOOR + 3, 0) })
		root.Anchored = true
		local rows, allHit = {}, true
		for _, spot in ipairs(spots) do
			place(root, spot.position)
			table.clear(judged)
			BossPatterns.force(model, data, "meteor")
			local st = MonsterState.getBossPatternState(model)
			drive(player, root, model, data, 4, function()
				return #judged > 0
			end)
			local hit = judged[1] and judged[1].hits[player] ~= nil
			allHit = allHit and hit
			table.insert(rows, ("%s 낙석 판정=%s"):format(spot.label, tostring(hit)))
			BossPatterns.interrupt(model, data)
			-- 진동파: 서 있으면(점프 안 함) 맞는다 - 둔덕 · 블록 위에서도 공중 판정이 "공중 아님"이어야 한다. 체력이 아니라 판정 계측(waveHit)으로 센다(면역 · 쉴드와 무관).
			fullHeal(player)
			table.clear(events)
			BossPatterns.force(model, data, "shockwave")
			drive(player, root, model, data, 9, function()
				return st.phase == "normal"
			end)
			local waveHit = false
			for _, e in ipairs(events) do
				waveHit = waveHit or (e.kind == "waveHit" and e.record.player == player)
			end
			allHit = allHit and waveHit
			table.insert(rows, ("%s 진동파(서 있음) 맞음=%s"):format(spot.label, tostring(waveHit)))
			fullHeal(player)
		end
		root.Anchored = false
		BossPatterns.debugJudgeHook = nil
		r.check(("B4 높이별: %s"):format(table.concat(rows, " · ")), allHit and #spots >= 2)
		BossEncounter.despawnFor(player)
	end)

	r.section("E3 · E4 판매", function()
		local GemCraftRequest = require(script.Parent.GemCraftRequest)
		local profile = PlayerProfile.getProfile(player)
		local classState = profile.classes[profile.classId]
		table.insert(profile.inventory, { grade = "rare", part = "armor", itemLevel = 10, dropStage = 10, tierIndex = 1, locked = true })
		local lockedIndex = #profile.inventory
		local ok, why = PlayerProfile.sellItem(player, lockedIndex)
		local stillThere = profile.inventory[lockedIndex] ~= nil and profile.inventory[lockedIndex].locked == true
		table.remove(profile.inventory, lockedIndex)
		r.check(("E3 잠긴 장비 판매 → %s · %s(기대 false · locked) · 가방에 남음 %s"):format(tostring(ok), tostring(why), tostring(stillThere)), ok == false and why == "locked" and stillThere)
		table.insert(classState.gemInventory, { grade = "relic", itemLevel = 100, option = { id = "attackPercent", roll = 1 } })
		local index = #classState.gemInventory
		local gem = classState.gemInventory[index]
		local price = GemCraft.sellPrice(gem, PlayerProfile.getAccountBestStage(player))
		local goldBefore = profile.gold
		local count = #classState.gemInventory
		local sold, reason, result = GemCraftRequest.handle(player, "sell", index)
		local badOk, badWhy = GemCraftRequest.handle(player, "sell", 999)
		r.check(("E4 보석 판매(유물 · 레벨 100): %s · 골드 +%s(기대 %d) · 보석 %d → %d · 없는 칸 %s/%s"):format(tostring(sold), tostring(result and result.gold), price, count, #classState.gemInventory,
			tostring(badOk), tostring(badWhy)),
			sold and reason == nil and result.gold == price and profile.gold - goldBefore == price and #classState.gemInventory == count - 1 and badOk == false and badWhy == "not_found")
	end)

	r.section("C7 명예의 전당(_verify)", function()
		local Leaderboard = require(script.Parent.Leaderboard)
		Leaderboard.debugSeason = 2
		local wrote = Leaderboard.snapshotHall(1)
		local hall = Leaderboard.getHall(1)
		local boards = 0
		for _ in pairs(hall and hall.boards or {}) do
			boards += 1
		end
		Leaderboard.debugResetRateLimit(player)
		local response = Leaderboard.handle(player, "hall", "personal")
		Leaderboard.debugSeason = nil
		Leaderboard.debugResetRateLimit(player)
		r.check(("C7 시즌 2 기준 시즌 1 전당: 쓰기 %s(이미 있으면 false) · 읽기 %s · 순위표 %d(기대 6) · 저장소 %s · hall 응답 ok=%s 시즌 %s · 개인 %d줄"):format(tostring(wrote), tostring(hall ~= nil), boards,
			Leaderboard.hallStoreName(), tostring(response and response.ok), tostring(response and response.season), response and #(response.entries or {}) or -1),
			hall ~= nil and boards == 6 and hall.season == 1 and response and response.ok and response.season == 1 and Leaderboard.hallStoreName():find("_verify") ~= nil)
	end)

	BossPatterns.debugEventHook = nil
	env.restore(player)
	local orphan = 0
	for _, m in ipairs(MonsterState.getAllModels()) do
		local d = MonsterState.getData(m)
		if d and d.isBoss and not BossEncounter.getEncounterByModel(m) then
			orphan += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d"):format(orphan), orphan == 0)
	local passCount, totalCount = r.summary()
	print(("===P3c 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

return P3cVerify
