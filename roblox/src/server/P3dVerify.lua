-- P3d 자동 검증(docs/phase/P3d-log.md). (가) = 서버 시작 때 순수 계산 · (가E) = 체인 끝(무거운 100시드 재생성) · (나) = 보스 검증 체인 끝(실제 보스전 · 스탠드인 · 실제 판정 경로).
--   (가) F3 툴팁 · 칩 같은 값 · G-e 첫 시즌 KST · B2 보호 범위 · B3 이탈 · 복귀 시뮬 1,000회 · D2 재생성 회피 부등식(kind마다) · A 연출 데이터(지진파 보스 3종 모션 · 박자 · 상한)
--   (가E) 무거운 계산 - 체인 끝: F1 파티 구성 속도(경제 시뮬 F4 - 딜러3+치유사1 = 딜러4의 100 ~ 105% · 2+2 ≤ 3+1 · 치유사4 가장 느림) · G-d 견습 시뮬 ·
--        E3 재생성 100시드 × 6맵(겹침 0 · 갇힘 0 · 스폰 자리 덮임 0)
--   (나) B 맵 밖 → 스폰 자리 · 체력 · 기믹 누적 그대로 · 보호 0.75초(피해 0 · 넉백 무시) · C 단상 위 지진파 안 맞음 · 1번째 금 · 2번째 무너짐(위 사람 떨어짐 · 피해 없음) ·
--        D 재생성(onComplete · 전조 1.5초 · 발밑 · 피해 · 밀림 · 끼임 3타 탈출 · 6초 자동 파괴 · 상한 · 누수) · E2 모래 구덩이 위 구조물 3틱 붕괴 · F2 버프 중첩 없음 · F3 툴팁 소스 · G-g 라이브 제외

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ArenaLayout = require(ReplicatedStorage.Shared.ArenaLayout)
local ArenaContainment = require(ReplicatedStorage.Shared.ArenaContainment)
local LeaderboardRules = require(ReplicatedStorage.Shared.LeaderboardRules)
local SkillTooltipText = require(ReplicatedStorage.Shared.SkillTooltipText)

local P3dVerify = {}

local ALL_BOSSES = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }
local GEOMETRY = BossArenaMapData.geometry
local REGROW = BossArenaMapData.regrow
local DODGE = BossData.mechanics.dodge

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[P3d][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[P3d][%s] %s"):format(tag, label))
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

-- 입장(스폰) 자리 - BossArenaMap.entryPosition과 같은 식(아레나 중심 기준).
local function spawnSpots()
	local spots = {}
	for n = 1, 4 do
		spots[n] = {}
		for i = 1, n do
			local offsetDeg = math.deg((i - 1 - (n - 1) / 2) * 4 / GEOMETRY.entryDistanceStuds)
			local a = math.rad(GEOMETRY.entryAngleDeg + offsetDeg)
			spots[n][i] = Vector3.new(math.cos(a), 0, math.sin(a)) * GEOMETRY.entryDistanceStuds
		end
	end
	return spots
end

-- ═══ (가) ═══

function P3dVerify.runPure()
	print("===P3d 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("F3 툴팁 · 칩 같은 값", function()
		local info = { classId = "healer", attack = 1000, critRate = 0.1, critDmg = 1.5, healerBuff = PartyConfig.healerBuffFraction, slots = {} }
		local built = SkillTooltipText.build("healer", "Q", info)
		local line = nil
		for _, entry in ipairs(built and built.lines or {}) do
			if entry.label == "파티 버프" then
				line = entry.text
			end
		end
		local chip = "✚ 피해 +" .. SkillTooltipText.pct(PartyConfig.healerBuffFraction)
		local value = SkillTooltipText.pct(PartyConfig.healerBuffFraction)
		r.check(("F3 툴팁 \"%s\" · 칩 \"%s\" - 같은 값 %s"):format(tostring(line), chip, value), line ~= nil and line:find(value, 1, true) ~= nil and value == "17.4%")
	end)

	r.section("G-e 첫 시즌 KST", function()
		local expected = { { 2026, 10, 1, 1790780400 }, { 2027, 1, 1, 1798729200 }, { 2028, 2, 29, 1835362800 }, { 2026, 3, 1, 1772290800 } }
		local ok, rows = true, {}
		for _, e in ipairs(expected) do
			local v = LeaderboardRules.kstMidnightUnix(e[1], e[2], e[3])
			ok = ok and v == e[4]
			table.insert(rows, ("%d-%02d-%02d → %d"):format(e[1], e[2], e[3], v))
		end
		local cfg = { seasonId = 3, seasonLengthDays = 28, seasonStartUnix = 0, firstSeasonDateKst = { 2026, 10, 1 } }
		local s1 = LeaderboardRules.seasonAt(1790780400 + 5, cfg)
		local s2 = LeaderboardRules.seasonAt(1790780400 + 28 * 86400 + 5, cfg)
		local ends = LeaderboardRules.seasonEndsAt(1, cfg)
		r.check(("G-e KST 0시 [%s] · 오픈일 설정 → 시즌 %d · 28일 뒤 %d · 시즌 1 끝 %d · 지금 설정 firstSeasonDateKst = %s(nil = P6에서 확정)"):format(table.concat(rows, " · "), s1, s2, ends,
			tostring(LeaderboardConfig.firstSeasonDateKst)), ok and s1 == 1 and s2 == 2 and ends == 1790780400 + 28 * 86400)
	end)

	r.section("B 복귀 규칙 · 시뮬", function()
		local c = BossArenaMapData.containment
		local zone = { center = Vector3.zero, radius = GEOMETRY.radiusStuds }
		local counts = ArenaContainment.simulateReturn(zone, {
			spawns = spawnSpots(), launchDistance = 12, damagePerHit = 0.1, protectSeconds = c.returnProtectSeconds,
			checkSeconds = c.checkIntervalSeconds, chainWindowSeconds = 1.25, walkStuds = 20, dashStuds = 16,
		}, c.sim.trials, c.sim.seed, c.sim.maxEvents)
		r.check(("B2 보호 %.2f초(지시 0.5 ~ 1) · B3 시뮬 %d조합: 이탈 %d → 복귀 %d · 연쇄 %d · 체력 변화 %d · 누적 변화 %d · 스폰 원 밖 %d · 보호로 무시한 넉백 %d"):format(c.returnProtectSeconds,
			counts.trials, counts.exits, counts.returns, counts.chainExits, counts.hpChanged, counts.stacksChanged, counts.spawnOutside, counts.suppressed),
			c.returnProtectSeconds >= 0.5 and c.returnProtectSeconds <= 1 and counts.trials == c.sim.trials and counts.exits > 0 and counts.returns == counts.exits
				and counts.chainExits == 0 and counts.hpChanged == 0 and counts.stacksChanged == 0 and counts.spawnOutside == 0)
	end)

	r.section("D2 재생성 회피 부등식", function()
		local rows, ok = {}, true
		local seen = {}
		for _, bossId in ipairs(ALL_BOSSES) do
			for _, spec in ipairs(BossArenaMapData.maps[bossId].layout) do
				if spec.group ~= "big" and not seen[spec.kind] then
					seen[spec.kind] = true
					local footprint = spec.group == "feature" and BossArenaMapData.featureShapes[spec.kind].footprint or spec.radius[2]
					local need = DODGE.perceptionSeconds + (footprint + DODGE.characterHalfWidthStuds) / WorldConfig.playerWalkSpeedStuds * DODGE.marginFactor
					ok = ok and need <= REGROW.telegraphSeconds
					table.insert(rows, ("%s %.2f"):format(spec.kind, need))
				end
			end
		end
		local timed = {}
		for _, bossId in ipairs(ALL_BOSSES) do
			for id, skill in pairs(BossData.bosses[bossId].skills) do
				for _, effect in ipairs(skill.onComplete or {}) do
					if effect.type == "regrowObstacles" then
						table.insert(timed, bossId .. "." .. id)
					end
				end
			end
		end
		table.sort(timed)
		r.check(("D2 전조 %.1f초 ≥ 필요(인지 %.1f + (발자국 + 1) ÷ %d × %.2f): %s | D1 재생성 시점 %d종: %s"):format(REGROW.telegraphSeconds, DODGE.perceptionSeconds, WorldConfig.playerWalkSpeedStuds,
			DODGE.marginFactor, table.concat(rows, " · "), #timed, table.concat(timed, " · ")), ok and #timed == 6)
	end)

	r.section("A 연출 데이터", function()
		local rows, ok = {}, true
		for _, bossId in ipairs(ALL_BOSSES) do
			local hasRing = false
			for _, skill in pairs(BossData.bosses[bossId].skills) do
				hasRing = hasRing or skill.primitive == "ring"
			end
			local style = BossFxData.bosses[bossId] and BossFxData.bosses[bossId].slam
			ok = ok and ((hasRing and style ~= nil) or (not hasRing and style == nil))
			table.insert(rows, ("%s %s"):format(bossId, style or (hasRing and "없음(X)" or "-")))
		end
		ok = ok and BossFxData.windupFraction + BossFxData.holdFraction < 1 and BossFxData.maxActive > 0 and BossFxData.otherPlayerWeight < 1
		r.check(("A1 지진파 모션: %s · 박자 들기 %.2f + 멈칫 %.2f + 찍기 %.2f · 동시 상한 %d · 다른 멤버 배율 %.1f"):format(table.concat(rows, " · "), BossFxData.windupFraction, BossFxData.holdFraction,
			1 - BossFxData.windupFraction - BossFxData.holdFraction, BossFxData.maxActive, BossFxData.otherPlayerWeight), ok)
	end)

	local pass, total = r.summary()
	print(("===P3d 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ═══ (가E) E3 재생성 100시드 × 6맵 - 무거운 계산이라 체인 끝 ═══
function P3dVerify.runRegrowSeeds()
	print("===P3d 검증 시작(가E)===")
	local r = newRecorder("가E")
	-- P3d Play 1: 경제 시뮬(F1 · G-d)은 무겁다 - 서버 시작 때 (가)에서 돌면 실시간 검증(29-1 첫 기믹 시각 · 29-2 step 성능)과 겹쳐 X가 났다. 체인 끝에서 돈다.
	r.section("F1 파티 구성 속도", function()
		local EconSimTables = require(script.Parent.EconSimTables)
		local healer = EconSimTables.healer()
		local target = PartyConfig.healerBuffTargetSpeed
		local allOk, rows = true, {}
		for _, entry in ipairs(healer.compositions) do
			local v = {}
			for index, speed in ipairs(entry.speeds) do
				v[index] = speed.healMode
			end
			local ok = v[2] >= target[1] - 1e-9 and v[2] <= target[2] + 1e-9 and v[3] <= v[2] and v[5] <= math.min(v[1], v[2], v[3], v[4])
			allOk = allOk and ok
			table.insert(rows, ("%s·%s %.3f/%.3f/%.3f/%.3f/%.3f"):format(entry.tier, entry.dealerClass, v[1], v[2], v[3], v[4], v[5]))
		end
		r.check(("F1 b = %.4f(옛 식 %.5f) · 치유모드 딜러4/3+1/2+2/1+3/치유사4: %s | 3+1 ∈ [%.2f, %.2f] · 2+2 ≤ 3+1 · 치유사4 가장 느림"):format(PartyConfig.healerBuffFraction,
			PartyConfig.healerBuffFormulaFraction, table.concat(rows, " · "), target[1], target[2]), allOk and #rows == 6)
	end)

	r.section("G-d 견습 시뮬", function()
		local EconSim = require(script.Parent.EconSim)
		local seconds, level = EconSim.tutorialOnly("casual")
		r.check(("G-d 캐주얼 견습 7단계 = %.1f분 · 끝난 레벨 %d(캐주얼 tutorial = %s) - 스테이지 20 도달(견습 포함)은 /gg econ 보고서 · 하네스 13.3분"):format(seconds / 60, level,
			tostring(require(ReplicatedStorage.Shared.data.EconSimConfig).profiles.casual.tutorial)), seconds > 60 and level >= 2)
	end)

	local startedAt = os.clock()
	local state = REGROW.check.seedBase
	local function rng()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	local spots = spawnSpots()
	local total = { spawned = 0, under = 0, skipped = 0, overlap = 0, trapped = 0, covered = 0, events = 0 }
	for _, bossId in ipairs(ALL_BOSSES) do
		local boss = BossData.bosses[bossId]
		local theme = BossArenaMapData.maps[bossId]
		local opts = ArenaLayout.optionsFor(boss)
		local perMap = { spawned = 0, skipped = 0, overlap = 0, trapped = 0, cap = 0 }
		for s = 1, REGROW.check.seeds do
			local layout = ArenaLayout.generate(theme, REGROW.check.seedBase + s, opts)
			local items = table.clone(layout.items)
			local nextId = 1000
			for _ = 1, REGROW.check.events do
				total.events += 1
				local members = {}
				for _ = 1, 1 + math.floor(rng() * 4) do
					for _ = 1, 50 do
						local a, d = rng() * 2 * math.pi, math.sqrt(rng()) * (GEOMETRY.radiusStuds - 2)
						local x, z = math.cos(a) * d, math.sin(a) * d
						local free = true
						for _, it in ipairs(items) do
							for _, c in ipairs(it.colliders) do
								free = free and ((x - c.x) ^ 2 + (z - c.z) ^ 2 > (c.r + 1) ^ 2)
							end
						end
						if free then
							table.insert(members, { x = x, z = z })
							break
						end
					end
				end
				local ba, bd = rng() * 2 * math.pi, math.sqrt(rng()) * 120
				local bossPos = { x = math.cos(ba) * bd, z = math.sin(ba) * bd }
				local pits = {}
				for _ = 1, math.floor(rng() * 4) do
					local pa, pd = rng() * 2 * math.pi, math.sqrt(rng()) * 120
					table.insert(pits, { x = math.cos(pa) * pd, z = math.sin(pa) * pd, r = 8 })
				end
				if #items >= REGROW.maxObstacles then
					perMap.skipped += 1
					perMap.cap += 1
				else
					nextId += 1
					local item = ArenaLayout.regrowSpot(theme, items, rng, { kit = opts.kit, coverageMin = 0, members = members, boss = bossPos, pits = pits, mounds = layout.mounds }, nextId)
					if not item then
						perMap.skipped += 1
					else
						perMap.spawned += 1
						total.under += item.underMember and 1 or 0
						-- 겹침(독립 계산): 구조물 · 모래 구덩이 · 보스 · 킷
						local bad = false
						for _, other in ipairs(items) do
							bad = bad or math.sqrt((item.x - other.x) ^ 2 + (item.z - other.z) ^ 2) - item.radius - other.radius < BossArenaMapData.layout.minGapStuds - 1e-6
						end
						for _, p in ipairs(pits) do
							bad = bad or math.sqrt((item.x - p.x) ^ 2 + (item.z - p.z) ^ 2) - item.radius - p.r < REGROW.pitGapStuds
						end
						bad = bad or math.sqrt((item.x - bossPos.x) ^ 2 + (item.z - bossPos.z) ^ 2) - item.radius < REGROW.bossClearStuds
						for _, k in ipairs(opts.kit) do
							bad = bad or math.sqrt((item.x - k.x) ^ 2 + (item.z - k.z) ^ 2) - item.radius - k.r < BossArenaMapData.layout.kitGapStuds - 1e-6
						end
						perMap.overlap += bad and 1 or 0
						table.insert(items, item)
						if not ArenaLayout.connectivity(items, opts) then
							perMap.trapped += 1
						end
						for n = 1, 4 do
							for i = 1, n do
								for _, c in ipairs(item.colliders) do
									if (spots[n][i].X - c.x) ^ 2 + (spots[n][i].Z - c.z) ^ 2 < (c.r + 2) ^ 2 then
										total.covered += 1
									end
								end
							end
						end
					end
				end
			end
			if s % 20 == 0 then
				task.wait()
			end
		end
		r.check(("E3 %s: 재생성 %d · 건너뜀 %d(상한 %d) · 겹침 %d · 갇힘 %d"):format(bossId, perMap.spawned, perMap.skipped, perMap.cap, perMap.overlap, perMap.trapped),
			perMap.overlap == 0 and perMap.trapped == 0 and perMap.spawned > 0)
		total.spawned += perMap.spawned
		total.skipped += perMap.skipped
		total.overlap += perMap.overlap
		total.trapped += perMap.trapped
	end
	r.check(("E3 합계 %d맵 × %d시드 × %d회 = %d: 재생성 %d(멤버 발밑 %d) · 건너뜀 %d · 겹침 %d · 갇힘 %d · 스폰 자리 덮임 %d · %.1f초"):format(#ALL_BOSSES, REGROW.check.seeds, REGROW.check.events,
		total.events, total.spawned, total.under, total.skipped, total.overlap, total.trapped, total.covered, os.clock() - startedAt), total.overlap == 0 and total.trapped == 0 and total.covered == 0 and total.under > 0)
	local pass, count = r.summary()
	print(("===P3d 검증 끝(가E)=== %d/%d 통과"):format(pass, count))
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

-- 스탠드인 멤버(P3c와 같은 모양 - 테이블 Player). root.Position을 바꿔 옮긴다.
local function newStandIn(model, members, name, position)
	local PlayerState = require(script.Parent.PlayerState)
	local BossEncounter = require(script.Parent.BossEncounter)
	local fakeRoot = { Position = position }
	local fake = { Name = name, UserId = -9700 - #members, Parent = Workspace }
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

local function colliderCount()
	local GroundProbe = require(script.Parent.GroundProbe)
	local n = 0
	for _, folder in ipairs({ GroundProbe.folder(), Workspace:FindFirstChild("BossArenaTallColliders") }) do
		for _, child in ipairs(folder and folder:GetChildren() or {}) do
			n += child.Name == "ArenaObstacleCollider" and 1 or 0
		end
	end
	return n
end

function P3dVerify.runLive(player, env)
	print("===P3d 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local BossArenaContainment = require(script.Parent.BossArenaContainment)
	local BossArenaProps = require(script.Parent.BossArenaProps)
	local BossMechanics = require(script.Parent.BossMechanics)
	local MonsterState = require(script.Parent.MonsterState)
	local PlayerState = require(script.Parent.PlayerState)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	local root = nil
	local function refreshRoot()
		for _ = 1, 100 do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			root = character and character:FindFirstChild("HumanoidRootPart")
			if root and humanoid and humanoid.Health > 0 then
				return
			end
			task.wait(0.1)
		end
	end
	refreshRoot()
	local FLOOR = BossArenaMap.floorTopY()
	local events = {}
	BossPatterns.debugEventHook = function(kind, record)
		table.insert(events, { kind = kind, at = os.clock(), record = record })
	end
	local standIns = {}
	PlayerState.clearIncomingDamageMultiplier(player)
	local rawSection = r.section
	r.section = function(name, fn)
		refreshRoot()
		fullHeal(player)
		rawSection(name, fn)
		if root then
			root.Anchored = false
		end
		BossArenaMap.debugNextSeed = nil
		clearStandIns(player, standIns)
		PlayerState.clearIncomingDamageMultiplier(player)
		fullHeal(player)
	end
	local function eventsOf(kind, since)
		local list = {}
		for _, e in ipairs(events) do
			if e.kind == kind and e.at >= (since or 0) then
				table.insert(list, e.record)
			end
		end
		return list
	end

	r.section("B 맵 밖 → 스폰 자리", function()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 801)
		local zone = WorldConfig.zones[encounter.zoneKey]
		BossPatterns.setGrace(model, data, 60)
		fullHeal(player)
		BossMechanics.applyGimmickDamage(model, player, 0.1, "P3d 검증 누적") -- 기믹 누적 10% + 체력 −10%
		local stackBefore = BossMechanics.gimmickDamageOf(model, player)
		local hpBefore = PlayerState.getHp(player)
		local spawn = BossArenaContainment.spawnPointFor(encounter, player)
		local before = #BossArenaContainment.corrections()
		root.Anchored = false
		place(root, zone.center + Vector3.new(zone.radius + 12, FLOOR + 3, 0))
		local waited = 0
		while #BossArenaContainment.corrections() == before and waited < 2 do
			waited += task.wait(0.05)
		end
		local fix = BossArenaContainment.corrections()[before + 1]
		local protectedNow = BossArenaContainment.isProtected(player)
		local hitDuring = PlayerDamage.applyHit(player, 1, "P3d 보호 확인", 1)
		local dist = spawn and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(spawn.X, 0, spawn.Z)).Magnitude or -1
		r.check(("B1 원 밖 12 → %.2f초 뒤 %s(스폰 자리 %s) · 스폰까지 %.2fstud · 체력 %.1f → %.1f · 기믹 누적 %.3f → %.3f"):format(waited, tostring(fix and fix.reason),
			tostring(fix and fix.spawn), dist, hpBefore, PlayerState.getHp(player), stackBefore, BossMechanics.gimmickDamageOf(model, player)),
			fix ~= nil and fix.spawn == true and dist >= 0 and dist < 2 and near(PlayerState.getHp(player), hpBefore, 1e-6) and near(BossMechanics.gimmickDamageOf(model, player), stackBefore))
		task.wait(BossArenaMapData.containment.returnProtectSeconds + 0.1)
		local protectedAfter = BossArenaContainment.isProtected(player)
		fullHeal(player)
		local hitAfter = PlayerDamage.applyHit(player, 1, "P3d 보호 끝 확인", 1) -- 약하게(Play 1: 1000은 개발 캐릭터를 죽여 다음 섹션이 옛 루트를 붙잡았다)
		fullHeal(player)
		r.check(("B2 보호 %.2f초: 복귀 직후 보호 %s · 그때 피격 %.2f(기대 0) · %.2f초 뒤 보호 %s · 피격 %.2f(> 0)"):format(BossArenaMapData.containment.returnProtectSeconds, tostring(protectedNow),
			hitDuring, BossArenaMapData.containment.returnProtectSeconds + 0.1, tostring(protectedAfter), hitAfter), protectedNow and hitDuring == 0 and not protectedAfter and hitAfter > 0)
		BossEncounter.despawnFor(player)
	end)

	r.section("C 단상", function()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 802)
		local zone = WorldConfig.zones[encounter.zoneKey]
		BossPatterns.setGrace(model, data, 60)
		local dais = nil
		for _, o in ipairs(BossArenaMap.obstacles(encounter.zoneKey)) do
			if o.climbable and not dais then
				dais = o
			end
		end
		assert(dais, "단상이 없다")
		local c = dais.colliders[1]
		root.Anchored = true
		place(root, Vector3.new(c.center.X, FLOOR + c.h + 3, c.center.Z)) -- 발 = 윗면
		local members = { player }
		local s2 = newStandIn(model, members, "S2", zone.center + Vector3.new(0, FLOOR + 3, -45))
		table.insert(standIns, s2)
		fullHeal(player)
		local hpBefore = PlayerState.getHp(player)
		local since = os.clock()
		BossPatterns.force(model, data, "shockwave")
		local st = MonsterState.getBossPatternState(model)
		drive(player, root, model, data, 12, function()
			return os.clock() - since > 1 and st.phase == "normal"
		end, true)
		local mine, s2Hits = 0, 0
		for _, rec in ipairs(eventsOf("waveHit", since)) do
			mine += rec.player == player and 1 or 0
			s2Hits += rec.player == s2 and 1 or 0
		end
		local results = {}
		for _, rec in ipairs(eventsOf("daisWave", since)) do
			if rec.id == dais.id then
				table.insert(results, ("%d:%s"):format(rec.waveIndex, tostring(rec.result)))
			end
		end
		local info = nil
		for _, e in ipairs(events) do
			if e.kind == "daisWave" and e.record.id == dais.id and e.record.result == "break" then
				info = e.record
			end
		end
		local droppedMe = false
		for _, p in ipairs(info and info.onTop or {}) do
			droppedMe = droppedMe or p == player
		end
		r.check(("C1 단상 위 지진파 판정 %d(기대 0) · 바닥 S2 %d(> 0) · 체력 %.1f → %.1f(피해 없음)"):format(mine, s2Hits, hpBefore, PlayerState.getHp(player)),
			mine == 0 and s2Hits > 0 and near(PlayerState.getHp(player), hpBefore, 1e-6))
		r.check(("C2 단상 #%d 파동별: [%s](기대 1:crack · 2:break) · 무너질 때 위에 개발 캐릭터 %s · 남은 단상 %s"):format(dais.id, table.concat(results, " · "), tostring(droppedMe),
			tostring(BossArenaMap.debugObstacle(encounter.zoneKey, dais.id) ~= nil)),
			results[1] == "1:crack" and results[2] == "2:break" and droppedMe and BossArenaMap.debugObstacle(encounter.zoneKey, dais.id) == nil)
		root.Anchored = false
		BossEncounter.despawnFor(player)
	end)

	r.section("D 재생성 · 끼임", function()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 803)
		local zone = WorldConfig.zones[encounter.zoneKey]
		local zoneKey = encounter.zoneKey
		BossPatterns.setGrace(model, data, 120)
		local layoutCount = #BossArenaMap.obstacles(zoneKey)
		local collidersBefore = colliderCount()
		root.Anchored = true
		place(root, zone.center + Vector3.new(0, FLOOR + 3, 60))
		local members = { player }
		local s1, s1Root = newStandIn(model, members, "S1", zone.center + Vector3.new(-60, FLOOR + 3, 0))
		table.insert(standIns, s1)
		-- ① 진동파가 정상으로 끝나면 재생성 전조가 온다(onComplete)
		local since = os.clock()
		BossPatterns.force(model, data, "shockwave")
		local plan = nil
		drive(player, root, model, data, 12, function()
			PlayerState.setHp(s1, PlayerState.getMaxHp(s1))
			local plans = eventsOf("regrowPlan", since)
			plan = plans[1] and plans[1].plan
			return plan ~= nil
		end)
		assert(plan, "재생성 전조가 안 왔다")
		-- ② 전조 안에 개발 캐릭터를 가장 큰 충돌 원 한가운데(끼임), S1을 그 원 가장자리 바깥쪽(밀림)에 세운다
		local big = plan.worldColliders[1]
		for _, c in ipairs(plan.worldColliders) do
			if c.r > big.r then
				big = c
			end
		end
		local itemCenter = zone.center + Vector3.new(plan.item.x, 0, plan.item.z)
		local out = Vector3.new(big.center.X - itemCenter.X, 0, big.center.Z - itemCenter.Z)
		out = out.Magnitude > 0.1 and out.Unit or Vector3.new(1, 0, 0)
		place(root, Vector3.new(big.center.X, FLOOR + 3, big.center.Z)) -- 고정한 채로 옮긴다(자리가 흔들리면 끼임 · 밀림 경계가 달라진다) - 풀림 확인은 ③에서 Anchored = false로 본다
		s1Root.Position = big.center + out * (big.r + 0.4) + Vector3.new(0, 3, 0)
		fullHeal(player)
		local hpMe, hpS1 = PlayerState.getHp(player), PlayerState.getHp(s1)
		local waited = 0
		local spawned = nil
		while not spawned and waited < REGROW.telegraphSeconds + 1 do
			waited += task.wait(0.05)
			for _, rec in ipairs(eventsOf("regrowSpawn", since)) do
				if rec.id == plan.item.id then -- 이 계획의 솟음만(Play 3: 다른 계획과 섞였다)
					spawned = rec
				end
			end
		end
		assert(spawned, "재생성이 안 솟았다")
		local outcome = {}
		for _, o in ipairs(spawned.outcomes) do
			outcome[o.player] = o.outcome
		end
		local s1Dist = (Vector3.new(s1Root.Position.X, 0, s1Root.Position.Z) - Vector3.new(big.center.X, 0, big.center.Z)).Magnitude
		local obstacle = BossArenaMap.debugObstacle(zoneKey, spawned.id)
		r.check(("D1 · D2 진동파 끝 → 재생성 %s(%s) · 전조 %.2f초(기대 %.1f) · 개발 = %s(원 한가운데) · S1 = %s → 원 중심에서 %.2f(기대 r %.1f + %.1f) · 피해 개발 %.1f · S1 %.1f · 고정 %s · 받는 피해 ×%.0f"):format(
			plan.item.kind, plan.item.underMember and "멤버 발밑 노림" or "빈 자리", spawned.telegraph, REGROW.telegraphSeconds, tostring(outcome[player]), tostring(outcome[s1]), s1Dist, big.r, REGROW.pushOutStuds,
			hpMe - PlayerState.getHp(player), hpS1 - PlayerState.getHp(s1), tostring(root.Anchored), PlayerState.getIncomingDamageMultiplier(player)), -- 고정은 검증이 이미 걸었다 - 참이어야 할 뿐 증거는 ③ 풀림

			near(spawned.telegraph, REGROW.telegraphSeconds, 0.15) and outcome[player] == "encase" and outcome[s1] == "push" and near(s1Dist, big.r + REGROW.pushOutStuds, 0.05)
				and hpMe - PlayerState.getHp(player) == 0 and hpS1 - PlayerState.getHp(s1) > 0 and root.Anchored and PlayerState.getIncomingDamageMultiplier(player) == 1) -- P3d-F B5: 끼이는 순간 피해 0 · 끼인 동안 무적 아님(×1)
		-- ③ 3타에 부수고 풀려난다
		for hit = 1, REGROW.escapeHits do
			MonsterState.applyDamage(obstacle.model, 1, BossData.stageInterval, player, { committedAt = os.clock() })
			if hit < REGROW.escapeHits then
				task.wait(BossArenaMapData.obstacle.hitIntervalSeconds + 0.05)
			end
		end
		local info = BossArenaMap.lastBreak(zoneKey)
		local releasedMe = false
		for _, p in ipairs(info and info.released or {}) do
			releasedMe = releasedMe or p == player
		end
		r.check(("D3 끼임 3타: 부서짐 %s(cause %s) · 풀림 %s · 고정 %s · 받는 피해 ×%.0f"):format(tostring(info and info.id == spawned.id), tostring(info and info.cause), tostring(releasedMe),
			tostring(root.Anchored), PlayerState.getIncomingDamageMultiplier(player)), info and info.id == spawned.id and info.cause == "escape" and releasedMe and not root.Anchored and PlayerState.getIncomingDamageMultiplier(player) == 1)
		-- ④ 6초 자동 파괴(스탠드인을 직접 끼운다)
		local plan2 = BossArenaMap.planRegrow(zoneKey, { members = {}, boss = model.PrimaryPart.Position, pits = {} })
		local obstacle2 = plan2 and BossArenaMap.spawnRegrown(zoneKey, plan2)
		assert(obstacle2, "두 번째 재생성 실패")
		BossArenaMap.encase(zoneKey, obstacle2, s1, s1Root)
		local encasedAt = os.clock()
		local done = nil
		while os.clock() - encasedAt < REGROW.encaseAutoBreakSeconds + 1.5 do
			task.wait(0.1)
			local last = BossArenaMap.lastBreak(zoneKey)
			if last and last.id == obstacle2.id then
				done = last
				break
			end
		end
		r.check(("D3 자동 파괴: %.2f초 뒤(기대 %.0f) cause %s · 풀린 사람 %d"):format(os.clock() - encasedAt, REGROW.encaseAutoBreakSeconds, tostring(done and done.cause), done and #done.released or -1),
			done ~= nil and done.cause == "expire" and near(os.clock() - encasedAt, REGROW.encaseAutoBreakSeconds, 0.6) and #done.released == 1)
		-- ⑤ 상한 · 누수: 상한까지 세우고 → 하나 더는 "cap" → 리셋 뒤 배치 수 · 충돌 기둥 수가 처음과 같다
		local made, why = 0, nil
		for _ = 1, 20 do
			local p = BossArenaMap.planRegrow(zoneKey, { members = {}, boss = model.PrimaryPart.Position, pits = {} })
			if not p then
				why = select(2, BossArenaMap.planRegrow(zoneKey, { members = {}, boss = model.PrimaryPart.Position, pits = {} }))
				break
			end
			BossArenaMap.spawnRegrown(zoneKey, p)
			made += 1
		end
		local atCap = #BossArenaMap.obstacles(zoneKey)
		BossArenaMap.resetObstacles(zoneKey)
		r.check(("D4 상한: %d개 더 세움 → %d개(상한 %d) · 다음 = %s · 리셋 뒤 %d(배치 %d) · 충돌 기둥 %d → %d"):format(made, atCap, REGROW.maxObstacles, tostring(why), #BossArenaMap.obstacles(zoneKey), layoutCount,
			collidersBefore, colliderCount()), atCap <= REGROW.maxObstacles and #BossArenaMap.obstacles(zoneKey) == layoutCount and colliderCount() == collidersBefore) -- P3d-F B4: 상한이면 가장 오래된 재생성분을 교체(20회 내내 계속 세운다 - 개수는 상한을 안 넘는다)
		root.Anchored = false
		BossEncounter.despawnFor(player)
	end)

	r.section("E2 모래 구덩이 위 구조물", function()
		local model, data, encounter = spawnBoss(player, env, "scorpion_queen", 804)
		local zoneKey = encounter.zoneKey
		BossPatterns.setGrace(model, data, 60)
		root.Anchored = true
		place(root, WorldConfig.zones[zoneKey].center + Vector3.new(0, FLOOR + 3, 60))
		local target = nil
		for _, o in ipairs(BossArenaMap.obstacles(zoneKey)) do
			if not o.climbable and not target then
				target = o
			end
		end
		assert(target, "구조물이 없다")
		local def = data.props.pit
		local prop = BossArenaProps.spawn(model, "pit", def, Vector3.new(target.center.X, FLOOR, target.center.Z))
		prop.armedAt = os.clock()
		prop.lastTickAt = {}
		local since = os.clock()
		drive(player, root, model, data, 4, function()
			local last = BossArenaMap.lastBreak(zoneKey)
			return last ~= nil and last.id == target.id
		end)
		local ticks = {}
		for _, rec in ipairs(eventsOf("pitRattle", since)) do
			if rec.id == target.id then
				table.insert(ticks, ("%d%s"):format(rec.ticks, rec.broke and "(무너짐)" or ""))
			end
		end
		local last = BossArenaMap.lastBreak(zoneKey)
		r.check(("E2 구덩이 위 %s #%d: 틱 [%s](기대 1 · 2 · 3 무너짐) · cause %s · %.2f초"):format(target.kind, target.id, table.concat(ticks, " · "), tostring(last and last.cause), os.clock() - since),
			#ticks == def.breaksObstacles.ticks and last and last.id == target.id and last.cause == "pit")
		BossArenaProps.clear(model)
		root.Anchored = false
		BossEncounter.despawnFor(player)
	end)

	r.section("F2 · F3 · G-g", function()
		local BuffState = require(script.Parent.BuffState)
		local SkillStats = require(script.Parent.SkillStats)
		local Leaderboard = require(script.Parent.Leaderboard)
		local b = PartyConfig.healerBuffFraction
		BuffState.apply(player, "healerBuff", { durationSeconds = 10, multiplier = 1 + b, displayName = "치유 버프", colorName = "success" })
		BuffState.apply(player, "healerBuff", { durationSeconds = 6, multiplier = 1 + b, displayName = "치유 버프", colorName = "success" }) -- 둘째 치유사
		local multiplier = BuffState.getField(player, "healerBuff", "multiplier", 1)
		BuffState.clear(player, "healerBuff")
		local info = SkillStats.info(player)
		local ok, why = Leaderboard.eligibility(player)
		r.check(("F2 치유사 둘이 걸어도 배율 %.4f(기대 %.4f - 중첩 없음) · F3 툴팁 소스 SkillStats.healerBuff %.4f · G-g 제외 목록 %s(개발 계정 %d 포함 %s) · 검증 모드 기록 가능 %s(%s)"):format(multiplier, 1 + b,
			info and info.healerBuff or -1, table.concat(LeaderboardConfig.excludedUserIds, ","), player.UserId, tostring(table.find(LeaderboardConfig.excludedUserIds, player.UserId) ~= nil), tostring(ok), tostring(why)),
			near(multiplier, 1 + b) and info and near(info.healerBuff, b) and (ok or why ~= "excluded"))
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
	print(("===P3d 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

return P3dVerify
