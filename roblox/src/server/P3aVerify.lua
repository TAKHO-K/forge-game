-- P3a 자동 검증 - 파티원 진도(A) · 리더보드 L1(B) · 원형 보스맵(C) · 장판 판정(D)(docs/phase/P3a-log.md). DevTools.server.lua가 부른다.
--   (가) runPure = 순수 함수 · 데이터(서버 시작 때, 플레이어 없이): 진도 판정 시나리오 표 · 인코딩 정밀도 · 저장소 이름 · 원형 도형 · 맵 6종 배치 간격 · 가장자리 회피(C2) 전후.
--   (나) runLive = 실제 Player(보스 검증 체인의 끝): 실제 처치 경로의 진도 · 도달 · 건너뛰기 · 리더보드 쓰기/읽기/부정 방지(_verify 저장소).
--        맵 · 구조물 · 장판 실측은 P3aArenaVerify(같은 체인). 검증이 바꾼 프로필 값은 env.ensureBackup/restore가 되돌린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local LeaderboardRules = require(ReplicatedStorage.Shared.LeaderboardRules)
local ArenaShape = require(ReplicatedStorage.Shared.ArenaShape)
local ArenaLayout = require(ReplicatedStorage.Shared.ArenaLayout) -- P3c B1: 구조물 자리는 보스 등장마다 무작위(검증은 고정 시드)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local BossRules = require(ReplicatedStorage.Shared.BossRules)

local P3aVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[P3a][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function recorder.section(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			recorder.check(("%s 실행 중 에러: %s"):format(label, tostring(err)), false)
		end
	end
	function recorder.summary()
		return passCount, totalCount
	end
	return recorder
end
P3aVerify.newRecorder = newRecorder

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-9)
end

-- ═══ (가) ═══

-- 파티 4인 시나리오(지시 재검증 표) - 순수 판정. 반환: 행 목록(보고서가 그대로 옮긴다).
function P3aVerify.partyScenarios()
	local interval, threshold = BossData.stageInterval, CombatConfig.contributionRewardThreshold
	local stage = 15
	local scenarios = {
		{ name = "① 전원 같은 최고(10) · 전원 10% 이상", members = { { best = 10, ratio = 0.35 }, { best = 10, ratio = 0.30 }, { best = 10, ratio = 0.20 }, { best = 10, ratio = 0.15 } },
			expect = { true, true, true, true }, party = true },
		{ name = "② 1명 진도 다름(최고 15 - 이미 깼다)", members = { { best = 10, ratio = 0.35 }, { best = 10, ratio = 0.30 }, { best = 10, ratio = 0.20 }, { best = 15, ratio = 0.15 } },
			expect = { true, true, true, false }, party = false },
		{ name = "③ 1명 피해 10% 미만(5%)", members = { { best = 10, ratio = 0.40 }, { best = 10, ratio = 0.30 }, { best = 10, ratio = 0.25 }, { best = 10, ratio = 0.05 } },
			expect = { true, true, true, false }, party = false },
		{ name = "④ 치유사 포함 - 치유사 피해 12%(치유량은 안 센다)", members = { { best = 10, ratio = 0.40 }, { best = 10, ratio = 0.28 }, { best = 10, ratio = 0.20 }, { best = 10, ratio = 0.12, healer = true } },
			expect = { true, true, true, true }, party = true },
		{ name = "④' 치유사 포함 - 치유사 피해 4%(힐을 많이 했어도)", members = { { best = 10, ratio = 0.40 }, { best = 10, ratio = 0.30 }, { best = 10, ratio = 0.26 }, { best = 10, ratio = 0.04, healer = true } },
			expect = { true, true, true, false }, party = false },
		{ name = "⑥ 솔로 재도전(최고 15에서 스테이지 15를 다시)", members = { { best = 15, ratio = 1 } }, expect = { false }, party = false, solo = true },
	}
	local rows = {}
	for _, scenario in ipairs(scenarios) do
		local verdict = LeaderboardRules.evaluateClear({ stage = stage, interval = interval, threshold = threshold, isParty = not scenario.solo, members = scenario.members })
		local ok = verdict.partyRecord == scenario.party
		for i, expected in ipairs(scenario.expect) do
			ok = ok and verdict.advanced[i] == expected
		end
		table.insert(rows, { name = scenario.name, reasons = verdict.reasons, party = verdict.partyRecord, ok = ok })
	end
	return rows
end

function P3aVerify.runPure()
	print("===P3a 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("A 진도 판정 시나리오", function()
		for _, row in ipairs(P3aVerify.partyScenarios()) do
			r.check(("A %s → 멤버 [%s] · 파티 기록 %s"):format(row.name, table.concat(row.reasons, ", "), row.party and "기록" or "없음"), row.ok)
		end
		-- 다음 보스 스테이지 = 최고 + 간격(0이면 첫 보스).
		r.check(("A 다음 보스 스테이지: 최고 0 → %d · 최고 25 → %d(기대 %d · %d)"):format(
			LeaderboardRules.nextBossStage(0, BossData.stageInterval), LeaderboardRules.nextBossStage(25, BossData.stageInterval), BossData.stageInterval, 25 + BossData.stageInterval),
			LeaderboardRules.nextBossStage(0, BossData.stageInterval) == BossData.stageInterval and LeaderboardRules.nextBossStage(25, BossData.stageInterval) == 25 + BossData.stageInterval)
	end)

	r.section("B 인코딩", function()
		local cap = InfiniteStageConfig.safeStageCap
		local maxValue = LeaderboardRules.encode(cap, 0)
		local stage, seconds = LeaderboardRules.decode(maxValue)
		r.check(("B 최대 인코딩(안전 상한 %d · 0초) = %.0f < 2^53(%.0f) · 되돌리면 %d · %.1f초"):format(cap, maxValue, 2 ^ 53, stage, seconds),
			maxValue < 2 ^ 53 and stage == cap and seconds == 0)
		local exact = true
		for _, sample in ipairs({ { 5, 12.3 }, { 34230, 999999.9 }, { 100, 0.05 }, { 25300, 3600.4 } }) do
			local s, t = LeaderboardRules.decode(LeaderboardRules.encode(sample[1], sample[2]))
			exact = exact and s == sample[1] and near(t, math.floor(sample[2] / LeaderboardConfig.timeUnitSeconds + 0.5) * LeaderboardConfig.timeUnitSeconds, 1e-6)
		end
		r.check("B 왕복: (5, 12.3초) · (34230, 999999.9초) · (100, 0.05초) · (25300, 3600.4초) - 스테이지 그대로 · 시간 0.1초 단위 반올림", exact)
		local ordered = LeaderboardRules.encode(10, 3600) > LeaderboardRules.encode(5, 1)
			and LeaderboardRules.encode(10, 30) > LeaderboardRules.encode(10, 31)
			and LeaderboardRules.encode(10, 30.04) == LeaderboardRules.encode(10, 30.0)
		r.check("B 정렬: 높은 스테이지가 느려도 위 · 같은 스테이지는 빠른 쪽이 위 · 0.05초 미만 차는 같은 값", ordered)
		local capUnits = LeaderboardConfig.timeCapUnits - 1
		local capped = select(2, LeaderboardRules.decode(LeaderboardRules.encode(10, 1e9)))
		r.check(("B 시간 상한: 10억 초 → %.1f초(상한 %d단위 = %.1f시간)"):format(capped, capUnits, capUnits * LeaderboardConfig.timeUnitSeconds / 3600),
			near(capped, capUnits * LeaderboardConfig.timeUnitSeconds, 1e-6))
		local key = LeaderboardRules.partyKey({ 99999999999, -12345678901, 1, 12345678901 })
		r.check(("B 파티 키(4명 · 11자리 · 음수 Studio id): %s(%d자 ≤ 50) · 순서 무관 같은 키"):format(key, #key),
			#key <= 50 and key == LeaderboardRules.partyKey({ 1, 12345678901, 99999999999, -12345678901 }))
		local longest = 0
		for _, kind in ipairs({ "personal", "party", "partyDetail", "cards", "class_dualblade", "class_greatsword" }) do
			longest = math.max(longest, #(LeaderboardConfig.namePrefix .. "_verify_s" .. LeaderboardConfig.seasonId .. "_" .. kind))
		end
		r.check(("B 저장소 이름 최장 %d자 ≤ 50(공식 한도)"):format(longest), longest <= 50)
		local minSeconds = LeaderboardRules.minClearSeconds(1000, { 50, 50 })
		r.check(("B 이론 최소 시간: HP 1000 ÷ DPS(50 + 50) = %.1f초(기대 10) · DPS 0이면 0(거절 안 함)"):format(minSeconds),
			near(minSeconds, 10) and LeaderboardRules.minClearSeconds(1000, {}) == 0)
	end)

	r.section("C 원형 도형", function()
		local zone = { center = Vector3.new(0, 0, -3000), radius = 120, halfSize = 120 }
		local inside = ArenaShape.contains(zone, Vector3.new(84, 0, -3000 + 84)) -- 반경 118.8
		local outside = ArenaShape.contains(zone, Vector3.new(90, 0, -3000 + 90)) -- 127.3 - 사각형 안 · 원 밖
		local clamped = ArenaShape.clamp(zone, Vector3.new(200, 5, -3000), 2)
		local clip = ArenaShape.clip(zone, Vector3.new(0, 0, -3000), Vector3.new(1, 0, 0), 4)
		local clipDiag = ArenaShape.clip(zone, Vector3.new(60, 0, -3000), Vector3.new(0, 0, 1), 0)
		r.check(("C 원 판정: 반경 118.8 안=%s · 127.3(옛 사각형 모서리) 밖=%s · 누르기 (200,5,0) → (%.1f, %.1f, %.1f)(기대 118, 5, 0) · 중심→+X 자르기 %.1f(기대 116) · (60,0)→+Z %.2f(기대 √(120²−60²) = 103.92)"):format(
			tostring(inside), tostring(not outside), clamped.X, clamped.Y, clamped.Z - zone.center.Z, clip, clipDiag),
			inside and not outside and near(clamped.X, 118, 1e-6) and clamped.Y == 5 and near(clip, 116, 1e-6) and near(clipDiag, math.sqrt(120 ^ 2 - 60 ^ 2), 1e-6))
		local arena = WorldConfig.zones.bossArena1
		local arena2 = WorldConfig.zones.bossArena2
		local spacing = math.abs(arena.center.Z - arena2.center.Z)
		local outer = BossArenaMapData.geometry.radiusStuds + BossArenaMapData.geometry.wallThicknessStuds + BossArenaMapData.geometry.rimWidthStuds
		r.check(("C 슬롯: 아레나 반경 %d(데이터 %d - P3c B4 140) · 슬롯 간격 %.0f > 테라스까지 지름 %.0f"):format(arena.radius, BossArenaMapData.geometry.radiusStuds, spacing, outer * 2),
			arena.radius == BossArenaMapData.geometry.radiusStuds and spacing > outer * 2)
	end)

	r.section("C 맵 6종 배치", function()
		local geometry, obstacleCfg = BossArenaMapData.geometry, BossArenaMapData.obstacle
		local R = geometry.radiusStuds
		local ids = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }
		local layoutCfg = BossArenaMapData.layout
		for _, bossId in ipairs(ids) do
			local theme = BossArenaMapData.maps[bossId]
			-- P3c B1: 구조물 자리는 무작위 - 고정 시드 1의 배치를 옛 잣대(벽 · 서로 · 중심 · 입장 · 킷 · 높이)로 잰다. 100시드 전수는 P3c(가) B5.
			local layout = ArenaLayout.generate(theme, 1, ArenaLayout.optionsFor(BossData.bosses[bossId]))
			local spots = {}
			for _, item in ipairs(layout.items) do
				table.insert(spots, { x = item.x, z = item.z, r = item.radius, angle = math.deg(math.atan2(item.z, item.x)), h = item.colliders[1].h, low = item.group ~= "feature" })
			end
			local minWall, minPair, minCenter, minEntry, minKit = math.huge, math.huge, math.huge, math.huge, math.huge
			local entry = { x = math.cos(math.rad(geometry.entryAngleDeg)) * geometry.entryDistanceStuds, z = math.sin(math.rad(geometry.entryAngleDeg)) * geometry.entryDistanceStuds }
			local kit = BossData.bosses[bossId].arenaKit
			for i, a in ipairs(spots) do
				local d = math.sqrt(a.x ^ 2 + a.z ^ 2)
				minWall = math.min(minWall, R - (d + a.r))
				minCenter = math.min(minCenter, d - a.r)
				minEntry = math.min(minEntry, math.sqrt((a.x - entry.x) ^ 2 + (a.z - entry.z) ^ 2) - a.r)
				for j = i + 1, #spots do
					local b = spots[j]
					minPair = math.min(minPair, math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) - a.r - b.r)
				end
				for _, part in ipairs(kit and kit.parts or {}) do
					local footprint = part.radiusStuds or math.sqrt((part.size.X / 2) ^ 2 + (part.size.Z / 2) ^ 2)
					if part.shape == "cylinder" then
						footprint = part.size.Y / 2
					end
					minKit = math.min(minKit, math.sqrt((a.x - part.offset.X) ^ 2 + (a.z - part.offset.Z) ^ 2) - a.r - footprint)
				end
			end
			local heightsOk = true
			for _, a in ipairs(spots) do
				-- 계단 한 단(2)보다 높고(보스 걸음 우회) 보스 지면 탐지 창(발 + probeUp 4)보다 낮다(리뷰 2 - 넘으면 광선이 기둥 속에서 시작해 못 본다) · 고도차 상한 6 이하.
				-- P3c B3의 작은 지형지물(feature)은 모양별 높이라 여기서 빼고 P3c(가)가 잰다(키 큰 기둥은 지면 폴더 밖).
				heightsOk = heightsOk and (not a.low or (a.h > 2 and a.h < 4 and a.h <= 6))
			end
			r.check(("C %s(%s): 시드 1 구조물 %d개 · 벽과 틈 최소 %.1f(≥ %d) · 서로 %.1f(≥ %d) · 중심과 %.1f(≥ %d) · 입장 자리와 %.1f(≥ 10) · 킷과 %s(≥ %d) · 큰 · 작은 구조물 높이 2 < h < 4"):format(
				bossId, theme.name, #spots, minWall, layoutCfg.wallGapStuds, minPair, layoutCfg.minGapStuds, minCenter, layoutCfg.centerClearStuds, minEntry,
				minKit == math.huge and "없음" or ("%.1f"):format(minKit), layoutCfg.kitGapStuds),
				#spots >= 4 and minWall >= layoutCfg.wallGapStuds - 1e-6 and minPair >= layoutCfg.minGapStuds - 1e-6 and minCenter >= layoutCfg.centerClearStuds - 1e-6
					and minEntry >= 10 and (minKit == math.huge or minKit >= layoutCfg.kitGapStuds - 1e-6) and heightsOk)
		end
		-- 전갈 여왕: 돌진이 멈추는 자리(중심에서 반경 − 벽 여백)가 유사 웅덩이 안인가(29-3 "웅덩이에서 끝난 돌진은 헤롱이 길다"의 뜻 유지).
		local scorpion = BossData.bosses.scorpion_queen
		local chargeSkill = nil
		for _, skill in pairs(scorpion.skills) do
			if skill.primitive == "charge" then
				chargeSkill = skill
			end
		end
		local stop = R - chargeSkill.arenaMarginStuds
		local pools = 0
		for _, part in ipairs(scorpion.arenaKit.parts) do
			if part.tag == "quicksand" and math.abs(math.abs(part.offset.X) - stop) <= part.radiusStuds and part.offset.Z == 0 then
				pools += 1
			end
		end
		r.check(("C 전갈 여왕: ±X 돌진 정지점(중심에서 %.0f)을 덮는 유사 웅덩이 %d곳(기대 2)"):format(stop, pools), pools == 2)
		-- P3c C8: 뺑뺑이 5바퀴 규칙은 없앴다(돌진 대상 = 가장 가까운 사람 · 구조물 파괴 규칙 하나로 통일 - hitsToBreak 5 · 돌진 1방).
		r.check(("C 뺑뺑이 규칙 제거(P3c C8): 데이터 smashAfterLaps=%s · 파괴 %d타 · 돌진 1방"):format(tostring(obstacleCfg.smashAfterLaps), obstacleCfg.hitsToBreak),
			obstacleCfg.smashAfterLaps == nil and obstacleCfg.hitsToBreak == 5)
	end)

	local passCount, totalCount = r.summary()
	print(("===P3a 검증 끝(가)=== %d/%d 통과"):format(passCount, totalCount))
end

-- (가C2) 가장자리 회피 전 · 후 - 계산이 무거워(몬테카를로 칸 × 변형) 서버 시작 때 (가)와 같이 돌면 보스 체인의 실시간 검증을 밀어냈다(P3a Play 2: 29-3 구출 · 끌어내기 ·
-- UI 타이밍 X). 그래서 보스 검증 체인의 **맨 끝 단계**로 따로 돈다(실시간 검증과 겹치지 않는다). 플레이어는 안 쓴다.
function P3aVerify.runEdge()
	print("===P3a 검증 시작(가C2)===")
	local r = newRecorder("가C2")
	r.section("C2 가장자리 회피(전 · 후)", function()
		local rows = P3aVerify.edgeEvasion(tonumber(P3aVerify.edgeTrials) or 2000)
		for _, row in ipairs(rows) do
			r.check(("C2 %s: 실패 %d/%d · p99 여유 최소 %.3f초%s"):format(row.label, row.fails, row.cells, row.worst, row.failList ~= "" and (" - " .. row.failList) or ""), row.expectFail or row.fails == 0)
		end
	end)
	local passCount, totalCount = r.summary()
	print(("===P3a 검증 끝(가C2)=== %d/%d 통과"):format(passCount, totalCount))
end

-- C2: 가장자리 표본 - 원 둘레 48지점 × 벽에서 1 · 3stud(대상 원 벽 여백 = 데이터 값). 원은 모든 둘레점이 대칭이라, 구조물이 영향권(EDGE_INFLUENCE_STUDS) 안에
-- 있는 지점만 그 기하로 따로 재고 나머지는 대표 계산을 공유한다. 보스 3종(밀도 대상 스킬 - 낙석 · 낙빙 · 독침)은 각자 자기 맵의 구조물로 잰다.
-- 비교(전): 옛 정사각형(S15 checkDensityWall) 직선 벽 1 · 3stud · 모서리 1 · 3stud(여백 2). 반환: 행 목록.
-- 구조물이 이 거리(가장자리 표본점에서 구조물 가장자리까지) 안일 때만 그 기하로 따로 잰다 - 탈출 탐색은 산개 반경 + 원 반경(최대 약 25stud) 안에서 끝난다.
local EDGE_INFLUENCE_STUDS = 30

function P3aVerify.edgeEvasion(trials)
	local density = BossData.mechanics.stageDensity
	local seedBase = 20260920 -- S14 · S15와 같은 칸 seed
	local targets = { { "section_guardian", "meteor" }, { "frost_giant", "icefall" }, { "scorpion_queen", "sting" } }
	local scales = { 1, BossRules.maxSkillRangeScale() }
	local parties = { 1, 4 }
	local R = BossArenaMapData.geometry.radiusStuds
	local margin = BossArenaMapData.geometry.circleTargetMarginStuds
	local function sweep(label, fn, expectFail)
		local fails, cells, worst, list = 0, 0, math.huge, {}
		for _, target in ipairs(targets) do
			for extra = 0, density.maxExtra do
				for _, scale in ipairs(scales) do
					for _, party in ipairs(parties) do
						local result = fn(target, extra, { rangeScale = scale, partySize = party }, seedBase + cells)
						cells += 1
						task.wait() -- Studio 스크립트 시간 한도(P3a Play 1: 양보 없이 돌다 "Script timeout"으로 (가)가 끊겼다)
						worst = math.min(worst, result.telegraphSeconds - result.p99)
						if not result.ok then
							fails += 1
							table.insert(list, ("%s e%d ×%.3f %d인"):format(target[2], extra, scale, party))
						end
					end
				end
			end
		end
		return { label = label, fails = fails, cells = cells, worst = worst, failList = table.concat(list, " · "), expectFail = expectFail }
	end
	local rows = {}
	table.insert(rows, sweep("전 · 정사각형 직선 벽 1stud(여백 2)", function(t, e, o, s) o.wallStuds = 1 return BossSim.checkDensityWall(t[1], t[2], e, trials, s, o) end, true))
	table.insert(rows, sweep("전 · 정사각형 모서리 1stud(여백 2)", function(t, e, o, s) o.wallStuds = 1 o.wallZStuds = 1 return BossSim.checkDensityWall(t[1], t[2], e, trials, s, o) end, true))
	table.insert(rows, sweep("전 · 정사각형 모서리 3stud(여백 2)", function(t, e, o, s) o.wallStuds = 3 o.wallZStuds = 3 return BossSim.checkDensityWall(t[1], t[2], e, trials, s, o) end, true))
	for _, depth in ipairs({ 1, 3 }) do
		-- 48지점: 그 보스 맵의 구조물이 영향권 안이면 그 기하로, 아니면 대표 결과를 쓴다(대칭). 대표 결과 = 구조물 없는 둘레점.
		local obstacleNear = 0
		local row = sweep(("후 · 원 R%d 둘레 48지점 깊이 %dstud(여백 %d)"):format(R, depth, margin), function(t, e, o, s)
			o.arenaRadiusStuds, o.depthStuds, o.clampMarginStuds = R, depth, margin
			local canonical = BossSim.checkDensityCircle(t[1], t[2], e, trials, s, o)
			local worstResult = canonical
			for point = 1, 48 do
				local theta = 2 * math.pi * (point - 1) / 48
				local px, pz = math.cos(theta) * (R - depth), math.sin(theta) * (R - depth)
				local near = {}
				-- P3c B1: 구조물은 무작위 배치 - 시드 P3aVerify.edgeLayoutSeeds개(기본 3)의 배치를 모두 대 본다(충돌 원 단위). 100시드 전수는 하네스(보고서 ⑤).
				for seedIndex = 1, P3aVerify.edgeLayoutSeeds or 3 do
					local layout = ArenaLayout.generate(BossArenaMapData.maps[t[1]], seedIndex, ArenaLayout.optionsFor(BossData.bosses[t[1]]))
					for _, item in ipairs(layout.items) do
						for _, c in ipairs(item.colliders) do
							local ox, oz = c.x - px, c.z - pz
							if math.sqrt(ox * ox + oz * oz) - c.r <= EDGE_INFLUENCE_STUDS then
								-- 대상 기준 좌표를 "벽이 -X" 틀로 돌린다(바깥 법선 (cosθ, sinθ) → (−1, 0)).
								local rot = math.pi - theta
								table.insert(near, { x = ox * math.cos(rot) - oz * math.sin(rot), z = ox * math.sin(rot) + oz * math.cos(rot), radius = c.r })
							end
						end
					end
				end
				if #near > 0 then
					obstacleNear += 1
					o.obstacles = near
					local local_ = BossSim.checkDensityCircle(t[1], t[2], e, trials, s, o)
					o.obstacles = nil
					if local_.p99 > worstResult.p99 or not local_.ok then
						worstResult = local_
					end
				end
			end
			return worstResult
		end, false)
		row.label ..= (" - 구조물 영향권 지점 %d(3보스 × 48칸 누계)"):format(obstacleNear)
		table.insert(rows, row)
	end
	return rows
end

-- ═══ (나) ═══

-- 실제 처치 경로로 보스를 잡는다(27-3과 같은 방식). secondsAgo = 보스전이 몇 초 전에 시작한 것으로 칠까(서버 시간 기록 - 부정 방지 최소 시간을 넘기려면 길게).
local function killBoss(ctx, stage, secondsAgo, standInRatio)
	local BossEncounter, MonsterState, MonsterSpawner, CombatResolution, TutorialState = ctx.BossEncounter, ctx.MonsterState, ctx.MonsterSpawner, ctx.CombatResolution, ctx.TutorialState
	local player = ctx.player
	BossEncounter.despawnFor(player)
	ctx.env.applyStage(player, stage)
	BossEncounter.spawnFor(player, stage)
	local model = BossEncounter.getActive(player)
	if not model then
		return false
	end
	BossEncounter.getEncounter(player).startedAt = os.clock() - secondsAgo
	local pStage = TutorialState.getMonsterStage(player)
	local _, maxHp = MonsterState.getBossHp(model)
	if standInRatio then
		local standIn = { Name = "P3aStandIn", Parent = true }
		BossEncounter.debugAddMember(model, standIn)
		MonsterState.applyDamage(model, maxHp * standInRatio, pStage, standIn)
	end
	local isDead = MonsterState.applyDamage(model, maxHp, pStage, player)
	MonsterSpawner.updateHpLabel(model)
	CombatResolution.resolveHit(player, model, isDead)
	BossEncounter.despawnFor(player)
	return true
end

local function waitWrites(Leaderboard)
	local waited = 0
	while Leaderboard.pendingWrites() > 0 and waited < 40 do
		task.wait(0.25)
		waited += 0.25
	end
	return Leaderboard.pendingWrites() == 0
end

function P3aVerify.runLive(player, env)
	print("===P3a 검증 시작(나)===")
	local r = newRecorder("나")
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local Leaderboard = require(script.Parent.Leaderboard)
	local ctx = {
		player = player, env = env,
		BossEncounter = require(script.Parent.BossEncounter), MonsterState = require(script.Parent.MonsterState),
		MonsterSpawner = require(script.Parent.MonsterSpawner), CombatResolution = require(script.Parent.CombatResolution),
		TutorialState = require(script.Parent.TutorialState),
	}
	env.ensureBackup(player)
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end
	local profile = PlayerProfile.getProfile(player)
	local classState = profile.classes[profile.classId]
	local interval = BossData.stageInterval

	r.section("A 실제 처치 경로", function()
		local base = 40 -- 검증용 기준 최고(보스 스테이지)
		classState.stageProgress.bestBossCleared = base
		classState.stageProgress.infiniteBest = base
		PlayerProfile.setLeaderboardTaintedForDevTools(player, true) -- A는 진도만 본다(리더보드는 B)
		local nextStage = base + interval
		killBoss(ctx, nextStage, 600)
		local afterNext = PlayerProfile.getBestBossCleared(player)
		local reach = PlayerProfile.getInfiniteStageBest(player)
		r.check(("A 다음 보스(%d) 솔로 처치 → 개인 최고 %d → %d(기대 %d) · 도달 %d(기대 ≥ %d - 다음 스테이지로 갈 수 있다)"):format(nextStage, base, afterNext, nextStage, reach, nextStage),
			afterNext == nextStage and reach >= nextStage)
		killBoss(ctx, base, 600) -- 낮은 보스 재도전
		r.check(("A 낮은 보스(%d) 재도전 → 개인 최고 %d 그대로"):format(base, PlayerProfile.getBestBossCleared(player)), PlayerProfile.getBestBossCleared(player) == nextStage)
		local stageTwo = nextStage + interval
		killBoss(ctx, stageTwo, 600, 0.09) -- 파티원(스탠드인) 9% 미달 · 본인 91%
		r.check(("A 파티원 9%% 미달 · 본인 91%% → 본인은 오름 %d(기대 %d - 멤버별 규칙)"):format(PlayerProfile.getBestBossCleared(player), stageTwo), PlayerProfile.getBestBossCleared(player) == stageTwo)
		-- 건너뛰기: 일반 스테이지로 도달만 올린다 → 개인 최고 · 리더보드 변화 없음.
		local statsBefore = Leaderboard.stats()
		local bestBefore = PlayerProfile.getBestBossCleared(player)
		PlayerProfile.setInfiniteStage(player, stageTwo + 3)
		local statsAfter = Leaderboard.stats()
		r.check(("A 일반 스테이지 %d로 이동(도달 %d) → 개인 최고 %d 그대로 · 리더보드 쓰기 %d → %d(변화 없음)"):format(stageTwo + 3, PlayerProfile.getInfiniteStageBest(player),
			PlayerProfile.getBestBossCleared(player), statsBefore.orderedWrite, statsAfter.orderedWrite),
			PlayerProfile.getBestBossCleared(player) == bestBefore and statsBefore.orderedWrite == statsAfter.orderedWrite)
	end)

	r.section("B 리더보드 쓰기 · 읽기(_verify 저장소)", function()
		r.check(("B 쓰기 모드 = %s(기대 verify) · 저장소 이름 %s"):format(Leaderboard.writeMode(), Leaderboard.storeName("personal")),
			Leaderboard.writeMode() == "verify" and Leaderboard.storeName("personal"):find("_verify", 1, true) ~= nil)
		local base = 60
		classState.stageProgress.bestBossCleared = base
		classState.stageProgress.infiniteBest = base
		PlayerProfile.setLeaderboardTaintedForDevTools(player, false)
		local statsBefore = Leaderboard.stats()
		local stage = base + interval
		killBoss(ctx, stage, 600)
		local judgement = Leaderboard.lastJudgement()
		local wrote = waitWrites(Leaderboard)
		local statsAfter = Leaderboard.stats()
		r.check(("B 기록 처치(스테이지 %d · 600초) → 판정 %s · 개인 쓰기 %d건 · 정렬 쓰기 +%d · 일반 쓰기 +%d(기대 +2 · +2 = 개인 · 직업 / 카드 2) · 대기 끝=%s"):format(stage,
			judgement and (judgement.rejected or "통과") or "없음", judgement and #judgement.writes or 0,
			statsAfter.orderedWrite - statsBefore.orderedWrite, statsAfter.plainWrite - statsBefore.plainWrite, tostring(wrote)),
			judgement and not judgement.rejected and #judgement.writes == 1 and statsAfter.orderedWrite - statsBefore.orderedWrite == 2
				and statsAfter.plainWrite - statsBefore.plainWrite == 2 and wrote and statsAfter.failures == statsBefore.failures)
		Leaderboard.refreshBoard("personal")
		Leaderboard.refreshBoard("class:" .. profile.classId)
		local rank, entry = Leaderboard.rankInCache("personal", player.UserId)
		local classRank, classEntry = Leaderboard.rankInCache("class:" .. profile.classId, player.UserId)
		r.check(("B 읽기(상위 %d 캐시): 개인 %s위 · 스테이지 %s(기대 ≥ %d) / 직업 %s위 · 스테이지 %s · 시간 %s초"):format(LeaderboardConfig.topN,
			tostring(rank), tostring(entry and entry.stage), stage, tostring(classRank), tostring(classEntry and classEntry.stage), tostring(classEntry and classEntry.seconds)),
			rank ~= nil and entry.stage >= stage and classRank ~= nil and classEntry.stage >= stage)
		local board = Leaderboard.handle(player, "board", "personal", nil, 1e9)
		local limited = Leaderboard.handle(player, "board", "personal", nil, 1e9 + 0.1)
		local me = Leaderboard.handle(player, "me", "class:" .. profile.classId, nil, 1e9 + 5)
		local card = Leaderboard.handle(player, "card", "class:" .. profile.classId, "u" .. player.UserId, 1e9 + 10)
		Leaderboard.debugResetRateLimit(player)
		local weaponOnly = card.ok and type(card.card) == "table" and card.card.weapon ~= nil and card.card.equipment == nil
		r.check(("B Remote: board %s(%d줄) · 1초 안 재요청 %s · me %s(%s위) · card %s(무기만 - 방어구 없음=%s)"):format(tostring(board.ok), board.entries and #board.entries or 0,
			tostring(limited.reason), tostring(me.ok), tostring(me.rank), tostring(card.ok), tostring(weaponOnly)),
			board.ok and #board.entries > 0 and limited.reason == "rate_limited" and me.ok and me.rank ~= nil and weaponOnly)
		local roundTrip, back = Leaderboard.debugRoundTrip(LeaderboardRules.encode(InfiniteStageConfig.safeStageCap, 0))
		r.check(("B 정렬 저장소 왕복(최대 인코딩 %.0f) → %s(같은 값=%s - 공식 문서에 범위가 없어 실측)"):format(LeaderboardRules.encode(InfiniteStageConfig.safeStageCap, 0), tostring(back), tostring(roundTrip)), roundTrip)
	end)

	r.section("B3 부정 방지", function()
		local base = 80
		classState.stageProgress.bestBossCleared = base
		classState.stageProgress.infiniteBest = base
		PlayerProfile.setLeaderboardTaintedForDevTools(player, false)
		local before = Leaderboard.stats()
		-- 이론 최소 시간이 의미 있게 큰 스테이지에서 잰다(개발 계정은 낮은 스테이지 보스를 이론상 1ms 안에 잡는다 - P3a Play 1: 스테이지 85에서 최소 0.0005초).
		-- 기록 판정(거절)은 진도와 무관하게 먼저 돈다 - 스테이지가 "다음 보스"가 아니어도 된다.
		local probeStage = 5000
		killBoss(ctx, probeStage, 0)
		local probe = Leaderboard.lastJudgement()
		local minSeconds = probe and probe.minSeconds or 0
		before = Leaderboard.stats()
		killBoss(ctx, probeStage, minSeconds * 0.5) -- 이론 최소의 절반 = 물리적으로 불가능
		local judgement = Leaderboard.lastJudgement()
		waitWrites(Leaderboard)
		local after = Leaderboard.stats()
		r.check(("B3 스테이지 %d 이론 최소 %.3f초의 절반(%.3f초)에 처치 → %s · 쓰기 %d건(기대 0) · 거절 +%d"):format(probeStage, minSeconds, minSeconds * 0.5,
			tostring(judgement and judgement.rejected), after.orderedWrite - before.orderedWrite, after.rejected - before.rejected),
			minSeconds > 0.05 and judgement and judgement.rejected == "too_fast" and after.orderedWrite == before.orderedWrite and after.rejected == before.rejected + 1)
		PlayerProfile.markLeaderboardTainted(player)
		local tainted = select(2, Leaderboard.eligibility(player))
		local before2 = Leaderboard.stats()
		killBoss(ctx, base + 2 * interval, 600)
		waitWrites(Leaderboard)
		local after2 = Leaderboard.stats()
		r.check(("B3 /gg 표시 계정 → 이유 %s · 기록 처치여도 쓰기 %d건(기대 0)"):format(tostring(tainted), after2.orderedWrite - before2.orderedWrite),
			tainted == "gg_tainted" and after2.orderedWrite == before2.orderedWrite)
		r.check(("B3 스탠드인 · Studio 수동 Play 제외 규칙: 스탠드인 이유 %s"):format(select(2, Leaderboard.eligibility({ Name = "x" }))), select(2, Leaderboard.eligibility({ Name = "x" })) == "stand_in")
	end)

	r.section("B 요청 수 vs 공식 한도", function()
		-- 공식(2026-09 Creator Hub "Error codes and limits"): 정렬 저장소 쓰기 30 + 인원 × 5 / 분 · 목록(GetSortedAsync) 5 + 인원 × 2 / 분 · 읽기 60 + 인원 × 40 / 분 · 일반 쓰기 60 + 인원 × 40 / 분.
		local boards = 2 + #ClassData.order
		local listPerMinute = boards * 60 / LeaderboardConfig.refreshSeconds
		local rows = {}
		local ok = true
		for _, n in ipairs({ 1, 4, 12 }) do
			local listLimit = 5 + n * 2
			-- 쓰기 최악: 인원 전원이 1분에 보스 하나씩 기록(개인 + 직업 = 2) + 파티 1 - 실제로는 보스 1마리 ≥ 수십 초.
			local orderedWrites = n * 2 + math.ceil(n / 4)
			local orderedLimit = 30 + n * 5
			table.insert(rows, ("%d명: 목록 %.1f/분(한도 %d) · 정렬 쓰기 최악 %d/분(한도 %d)"):format(n, listPerMinute, listLimit, orderedWrites, orderedLimit))
			ok = ok and listPerMinute <= listLimit and orderedWrites <= orderedLimit
		end
		r.check(("B 요청 수: 순위표 %d개 × %d초 주기 - %s"):format(boards, LeaderboardConfig.refreshSeconds, table.concat(rows, " · ")), ok)
	end)

	env.restore(player)
	local passCount, totalCount = r.summary()
	print(("===P3a 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

return P3aVerify
