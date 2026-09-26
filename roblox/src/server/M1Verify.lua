-- M1 자동 검증(맵 확장 그레이박스 · docs/phase/M1-report.md). (가) = 서버 시작 때 순수 계산 · (나) = 검증 체인(실제 서버 경로 - 개발 캐릭터를 옮겨 잰다).
--   (가) 배치 규칙(겹침 0) · 이동 거리(허브 → 캠프 480 ~ 640 · 캠프 → 관문 1,440 ~ 2,400) · 구역-보스 배정 = 배치표 1줄 · 구역 개방 표 · 나무(모든 이동 가능 · 시간 목표 · 움직이는 발판 상한) ·
--        둥지(단계별 기술 · 퍼즐 = 공중 2 + 대시 필수 · 선반 ≥ 23) · 봉인 입구(나무와 안 겹침 · 되돌림 자리 밖) · 밀어내기 자리 · 몬스터 지대 상태 전이 · 개미지옥 탈출 표 · 저장 v39 이관 · 파티 보정 A안
--   (나) 잠금 밀어내기 · 캠프 포탈 개방 · 허브 포탈 · 허브 귀환(쿨) · 미리 불러오기 · 몬스터 지대 켜짐/정리 · 보스 관문 → 아레나 → 이탈 → 관문 앞 · 리프트 · 정거장 · 떨어짐 복귀 ·
--        심연 복귀 · 높은 곳 착지 복귀 · 봉인 되돌림 · 칭호 1회
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)

local M1Verify = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[M1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[M1][%s] %s"):format(tag, label))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return pass, total
	end
	return r
end

-- ─────────────────────────── (가) ───────────────────────────
function M1Verify.runPure()
	print("===M1 검증 시작(가)===")
	local r = newRecorder("가")
	local D = WorldMapData
	r.section("배치", function()
		local problems = WorldMapLayout.validate()
		r.check(("배치 규칙: 지형 · 둥지 · 사냥 지대 · 도로 · 캠프 · 관문 겹침 %d(기대 0)%s"):format(#problems, #problems > 0 and (" - " .. table.concat(problems, " / ")) or ""), #problems == 0)
		for _, z in ipairs(D.zones) do
			local a, b = WorldMapLayout.routeLength(z, "hubEdge", "camp"), WorldMapLayout.routeLength(z, "camp", "gate")
			r.check(("거리 %s: 허브 끝 → 캠프 %.0f(480 ~ 640 · %.0f초) · 캠프 → 관문 %.0f(1,440 ~ 2,400 · %.0f초)"):format(z.key, a, a / 16, b, b / 16), a >= 480 and a <= 640 and b >= 1440 and b <= 2400)
		end
	end)
	r.section("구역-보스", function()
		local lap1 = BossData.placement.laps[1]
		local same = true
		for k, z in ipairs(D.zones) do
			same = same and lap1[k] == z.bossId and BossRules.bossIdForStage(k * BossData.stageInterval) == z.bossId
		end
		local problems = BossRules.validatePlacement()
		r.check(("배정: 스테이지 5k 보스 = 구역 k 보스(%s) %s · 배치표 규칙 위반 %d · T1 = 견습 보스 %s"):format(table.concat(lap1, "→"), tostring(same), #problems, tostring(D.zones[1].bossId == BossData.tutorialBossId)),
			same and #problems == 0 and D.zones[1].bossId == BossData.tutorialBossId)
		local Travel = require(script.Parent.Travel)
		local rows, ok = {}, true
		for _, best in ipairs({ 0, 4, 5, 10, 15, 20, 25, 30, 500 }) do
			local n = Travel.unlockedCountFor(best)
			table.insert(rows, ("%d→%d"):format(best, n))
			local expect = math.min(6, 1 + math.floor(math.min(best, 30) / 5))
			ok = ok and n == expect
		end
		r.check(("구역 개방(계정 최고 보스 → 열린 구역 수): %s"):format(table.concat(rows, " · ")), ok)
		local z = D.zones[3]
		local inside = WorldMapLayout.regionCenter(z) + WorldMapLayout.dirOf(z.angleDeg) * 200
		local out = Travel.pushOutPoint(z, inside)
		r.check(("밀어내기: %s 안 → 허브 쪽 원 밖(중심 거리 %.0f ≥ %d) · 다른 구역 %s"):format(z.key, (out - WorldMapLayout.regionCenter(z)).Magnitude, D.layout.regionRadius, tostring(WorldMapLayout.zoneAt(out) and WorldMapLayout.zoneAt(out).key)),
			(out - WorldMapLayout.regionCenter(z)).Magnitude >= D.layout.regionRadius and WorldMapLayout.zoneAt(out) == nil)
	end)
	r.section("나무", function()
		local T = WorldMapLayout.tree()
		local C = D.hub.tree.course
		local bad = {}
		for _, m in ipairs(T.moves) do
			local ok
			if m.via == "bounce" then
				ok = m.rise <= C.bounce.reachStuds and m.gap <= C.bounce.horizontalMax
			elseif m.via == "launch" then
				ok = m.gap <= C.pad.maxGap and m.rise <= C.pad.maxRise
			elseif m.via == "climb" or m.via == "tunnel" then
				ok = true
			else
				ok = WorldMapLayout.moveSkill(m.rise, m.gap) ~= nil
			end
			if not ok then
				table.insert(bad, ("구간 %d %s %s(오름 %.1f · 간격 %.1f)"):format(m.leg, m.path, m.k, m.rise, m.gap))
			end
		end
		r.check(("나무 이동 %d개 모두 가능(movement-metrics v2 · 80%% 여유): 불가 %d%s"):format(#T.moves, #bad, #bad > 0 and (" - " .. table.concat(bad, " / ")) or ""), #bad == 0)
		local legs, fast, slow, lastFast, lastSlow = WorldMapLayout.treeClimbSeconds(function(rise, gap)
			return (WorldMapLayout.moveSkill(rise, gap))
		end)
		for i, row in ipairs(legs) do
			r.note(("구간 %d %s(%s): 안쪽 %d칸 %.0f초 / 바깥 %d칸 %.0f초"):format(i, C.legs[i].name, C.legs[i].theme, row.innerMoves, row.inner, row.outerMoves, row.outer))
		end
		r.check(("오르는 시간(보통 실력 가정): 바닥 → 정상 %.1f ~ %.1f분(목표 6 ~ 8) · 최고 정거장 → 정상 %.0f ~ %.0f초(목표 90 ~ 120)"):format(fast / 60, slow / 60, lastFast, lastSlow),
			fast >= 360 and slow <= 480 and lastFast >= 90 and lastSlow <= 120)
		local list = {}
		WorldMapLayout.buildTree(list)
		r.check(("움직이는 발판(매달린 열매 + 흔들 잎) %d ≤ 상한 %d · 나무 도형 %d"):format(T.movingCount, C.movingMax, #list), T.movingCount <= C.movingMax)
		-- 위로 갈수록 어렵게: 마지막 구간에 대시 조합이 있고 첫 구간엔 없다
		local dashFirst, dashLast = 0, 0
		for _, m in ipairs(T.moves) do
			if m.via == "jump" or m.via == "ring" then
				local skill = WorldMapLayout.moveSkill(m.rise, m.gap)
				if skill == "hard" then
					if m.leg == 1 then
						dashFirst += 1
					elseif m.leg == #C.legs then
						dashLast += 1
					end
				end
			end
		end
		r.check(("난이도 상승: 첫 구간 대시 조합 %d(기대 0) · 마지막 구간 %d(기대 > 0)"):format(dashFirst, dashLast), dashFirst == 0 and dashLast > 0)
	end)
	r.section("둥지", function()
		for _, z in ipairs(D.zones) do
			local counts, bad = { walk = 0, chain = 0, puzzle = 0 }, {}
			for i, n in ipairs(z.nests) do
				local meta = WorldMapLayout.nest(z, i, {})
				counts[n.difficulty] += 1
				for _, leap in ipairs(meta.leaps) do
					local skill, name = WorldMapLayout.moveSkill(leap.rise, leap.gap)
					if leap.need == "easy" and skill ~= "easy" then
						table.insert(bad, ("%d %s(%s)"):format(i, n.difficulty, name))
					elseif leap.need == "puzzle" and not (name == "공중2+대시") then
						table.insert(bad, ("%d 퍼즐 도약 = %s(기대 공중2+대시)"):format(i, name))
					end
				end
				if n.difficulty == "walk" and meta.slopeDeg > 45 then
					table.insert(bad, ("%d 경사 %.0f°"):format(i, meta.slopeDeg))
				end
				if n.difficulty == "puzzle" and meta.ledgeFromGround < 23 then
					table.insert(bad, ("%d 선반 %.0f < 23"):format(i, meta.ledgeFromGround))
				end
			end
			r.check(("둥지 %s: %d곳(걸어서 %d · 연속 점프 %d · 퍼즐 %d) · 위반 %d%s"):format(z.key, #z.nests, counts.walk, counts.chain, counts.puzzle, #bad, #bad > 0 and (" - " .. table.concat(bad, " / ")) or ""),
				#z.nests >= 5 and #z.nests <= 8 and counts.walk >= 1 and #bad == 0)
		end
	end)
	r.section("봉인 입구", function()
		local boxes = WorldMapLayout.sealedBoxes()
		local T = WorldMapLayout.tree()
		local hits = 0
		for _, el in ipairs(T.elements) do
			for _, b in ipairs(boxes) do
				if WorldMapLayout.insideSealed(b, el.center) then
					hits += 1
				end
			end
		end
		local backOk = true
		for _, b in ipairs(boxes) do
			local front = (b.cf * CFrame.new(0, 3, -12)).Position
			for _, b2 in ipairs(boxes) do
				backOk = backOk and not WorldMapLayout.insideSealed(b2, front)
			end
			backOk = backOk and WorldMapLayout.zoneAt(front) == nil
		end
		local ledgeSkill, ledgeName = WorldMapLayout.moveSkill(WorldMapData.sealed.door.ledgeH, 2)
		r.check(("봉인 입구 %d곳: 나무 요소가 봉인 상자 안 %d · 되돌림 자리 밖 %s · 틈 선반(%d) = %s(%s - 닿을 것 같은 자리)"):format(#boxes, hits, tostring(backOk), WorldMapData.sealed.door.ledgeH, ledgeName, tostring(ledgeSkill)),
			#boxes == 5 and hits == 0 and backOk and ledgeSkill ~= nil)
	end)
	r.section("몬스터 지대", function()
		local SpawnSites = require(script.Parent.SpawnSites)
		local cfg = D.spawnSites
		local a1 = SpawnSites.nextState(false, -math.huge, 1, 1, 100)
		local a2, t2 = SpawnSites.nextState(true, 100, 0, 1, 130)
		local a3 = SpawnSites.nextState(true, 100, 0, 0, 100 + cfg.idleSeconds - 1)
		local a4 = SpawnSites.nextState(true, 100, 0, 0, 100 + cfg.idleSeconds)
		r.check(("지대 상태: 가까이 → 켜짐 %s · 유지 반경 안 → 켜짐 %s(시각 갱신 %s) · 비고 %d초 전 %s · %d초 뒤 %s"):format(tostring(a1), tostring(a2), tostring(t2 == 130), cfg.idleSeconds - 1, tostring(a3), cfg.idleSeconds, tostring(a4)),
			a1 and a2 and t2 == 130 and a3 and not a4)
	end)
	r.section("BR1-3 후속", function()
		local sand = BossData.bosses.scorpion_queen.skills.sandSearch
		local orgel = BossData.bosses.crystal_queen.skills.orgel
		local ok = sand.mound.countByParty[1] == 3 and sand.mound.countByParty[2] == 4 and sand.mound.countByParty[4] == 5 and BossSkillMath.gimmickLimitSeconds(sand, 2) == 12
			and BossSkillMath.orgelLength(orgel, 1) == 5 and BossSkillMath.orgelLength(orgel, 2) == 6 and BossSkillMath.orgelLength(orgel, 4) == 7
		r.check("파티 보정 A안: 둔덕 3/4/5/5 · 파티 제한 12초 · 오르골 5/6/7/7", ok)
		r.check(("구간 수호자 2회차 체력 ×%.1f(기대 1.3)"):format(BossData.bosses.section_guardian.repeatHpMultiplier or 0), BossData.bosses.section_guardian.repeatHpMultiplier == 1.3)
		-- 개미지옥 탈출 표(끌림 합 상한 = 한 구덩이 · 걷기 16)
		local env = BossData.bosses.scorpion_queen.environment.zones
		local rows, okAll = {}, true
		for _, d in ipairs({ 0.5, env.coreRadiusStuds, 10, env.radiusStuds - 2 }) do
			local net = 16 - env.pullStudsPerSecond
			local t = (env.radiusStuds - d) / net
			table.insert(rows, ("중심 %.1f → %.1f초"):format(d, t))
			okAll = okAll and net > 0
		end
		r.check(("개미지옥 탈출(반경 %d · 끌림 %d · 걷기 16 · 겹쳐도 끌림 합 ≤ %d): %s"):format(env.radiusStuds, env.pullStudsPerSecond, env.pullStudsPerSecond, table.concat(rows, " · ")), okAll)
	end)
	r.section("저장", function()
		local SaveSystem = require(script.Parent.SaveSystem)
		local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
		local old = SaveSystem.defaultProfile()
		if old then
			old.version = 37
			old.world, old.peakLevel, old.titles = nil, nil, nil
			local migrated = SaveSystem.migrate(old)
			r.check(("저장 v%d: v37 → v%d · world.portals 표 %s · peakLevel %s · titles 표 %s"):format(SaveConfig.saveVersion, migrated.version, tostring(type(migrated.world) == "table"), tostring(migrated.peakLevel), tostring(type(migrated.titles) == "table")),
				SaveConfig.saveVersion >= 39 and migrated.version == SaveConfig.saveVersion and type(migrated.world.portals) == "table" and migrated.peakLevel >= 1 and type(migrated.titles) == "table")
		else
			r.check("저장: 기본 프로필 없음", false)
		end
	end)
	local pass, total = r.summary()
	print(("===M1 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) ───────────────────────────
function M1Verify.runLive(player, env)
	print("===M1 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local Travel = require(script.Parent.Travel)
	local SpawnSites = require(script.Parent.SpawnSites)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossGate = require(script.Parent.BossGate)
	local HeightGuard = require(script.Parent.HeightGuard)
	local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
	local D = WorldMapData
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	assert(root, "캐릭터 없음")
	local guardOff = HeightGuard.debugOff
	HeightGuard.debugOff = true -- 순간이동 검증(높이 검증은 G2a(나) · M1-0(나)가 잰다)
	local function put(p)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(p)
	end
	local function flatDist(a, b)
		return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
	end
	local st = Travel.stateOf(player)
	r.section("잠금", function()
		ReplicatedStorage:SetAttribute("DebugZonesUnlocked", 1)
		task.wait(0.6)
		local z2 = WorldMapLayout.zoneByKey("tier2")
		local pushes = st.pushes
		put(WorldMapLayout.regionCenter(z2) + Vector3.new(0, 6, 0))
		task.wait(1.0)
		local zNow = WorldMapLayout.zoneAt(root.Position)
		r.check(("잠긴 구역(tier2) 안 → 밀어내기 %d회 · 지금 구역 %s · 미리 불러오기 %s"):format(st.pushes - pushes, tostring(zNow and zNow.key), tostring(Travel.lastTeleport and Travel.lastTeleport.streamed)),
			st.pushes > pushes and zNow == nil)
		ReplicatedStorage:SetAttribute("DebugZonesUnlocked", nil)
	end)
	r.section("포탈 · 귀환", function()
		local z1 = WorldMapLayout.zoneByKey("tier1")
		local profile = PlayerProfile.getProfile(player)
		profile.world.portals.tier1 = nil
		put(WorldMapLayout.camp(z1) + Vector3.new(0, 4, 0))
		task.wait(1.0)
		r.check(("캠프 도착 → 포탈 개방 %s · PortalsOpen [%s]"):format(tostring(PlayerProfile.isPortalOpen(player, "tier1")), tostring(player:GetAttribute("PortalsOpen"))), PlayerProfile.isPortalOpen(player, "tier1"))
		st.padAt = -math.huge
		put(WorldMapLayout.hubPortal(z1) + Vector3.new(0, 4, 0))
		task.wait(1.0)
		r.check(("허브 포탈 → 캠프: 캠프까지 %.0f(기대 < 20)"):format(flatDist(root.Position, WorldMapLayout.camp(z1))), flatDist(root.Position, WorldMapLayout.camp(z1)) < 20)
		st.hubAt = -math.huge
		local ok1 = Travel.requestHub(player)
		Travel.pollRecall(player, os.clock() + D.travel.recall.castSeconds) -- M1-2: 시전 3초(시전 · 취소는 M1-2(나)가 잰다)
		task.wait(0.3)
		local atHub = flatDist(root.Position, WorldConfig.zones.spawn.arrival) < 10
		local ok2, why2 = Travel.requestHub(player)
		r.check(("허브 귀환 %s → 허브 %s · 바로 다시 = %s(%s - 쿨 %d초)"):format(tostring(ok1), tostring(atHub), tostring(ok2), tostring(why2), D.travel.hubReturnCooldownSeconds), ok1 and atHub and not ok2 and why2 == "cooldown")
		local okP, whyP = Travel.partyTeleportCheck(player, player)
		r.check(("파티원 곁으로(파티 없음) = %s(%s)"):format(tostring(okP), tostring(whyP)), not okP and whyP == "not_party")
	end)
	r.section("몬스터 지대", function()
		local z1 = WorldMapLayout.zoneByKey("tier1")
		local hp = WorldMapLayout.huntPoints(z1)[1] -- M1-2: 스폰 범위 지점(어그로 밖 · 활성 반경 안에 선다)
		put(hp.position + Vector3.new(0, 6, 100))
		task.wait(2.2)
		local a1, alive1 = SpawnSites.stats()
		put(WorldConfig.zones.spawn.arrival + Vector3.new(0, 5, 0))
		task.wait(D.spawnSites.idleSeconds + 2.5)
		local a2, alive2 = SpawnSites.stats()
		r.check(("사냥 지대 곁 → 켜진 지대 %d · 몬스터 %d / 모두 떠나 %d초 → 켜진 지대 %d · 몬스터 %d"):format(a1, alive1, D.spawnSites.idleSeconds, a2, alive2), a1 >= 1 and alive1 >= D.spawnSites.group.count and a2 == 0 and alive2 == 0)
	end)
	r.section("보스 관문", function()
		local stage = nil
		for s = BossData.stageInterval, 200, BossData.stageInterval do
			if BossRules.bossIdForStage(s) == "section_guardian" and s <= PlayerProfile.getInfiniteStageBest(player) + 1 then
				stage = s
			end
		end
		assert(stage, "갈 수 있는 수호자 보스 스테이지 없음")
		PlayerProfile.setInfiniteStage(player, stage)
		BossGate.refreshGuide(player)
		local gateZone = player:GetAttribute("BossGateZone")
		put(WorldMapLayout.gate(WorldMapLayout.zoneByKey(gateZone)) + Vector3.new(0, 4, 0))
		st.gateAt = -math.huge
		task.wait(2.0)
		local enc = BossEncounter.getEncounter(player)
		r.check(("스테이지 %d → 안내 %s · 관문 밟음 → 보스전 %s"):format(stage, tostring(gateZone), tostring(enc ~= nil)), gateZone == "tier1" and enc ~= nil)
		BossEncounter.leaveFor(player)
		task.wait(0.3)
		local back = BossGate.returnPoint("tier1")
		r.check(("보스전 이탈 → 관문 앞 복귀(거리 %.0f)"):format(flatDist(root.Position, back)), flatDist(root.Position, back) < 6)
		PlayerProfile.setInfiniteStage(player, math.max(1, stage - 1))
		BossGate.refreshGuide(player)
	end)
	r.section("나무", function()
		local lift = D.hub.tree.course.lift
		put(WorldMapLayout.hubPoint(lift.angleDeg, lift.r, 4))
		task.wait(0.6)
		Travel.rideLift(player) -- M1-2c: 밟기 → 바구니 앞 [F](프롬프트 Triggered와 같은 함수)
		task.wait(0.6)
		local best = Travel.highestStation(PlayerProfile.getPeakLevel(player))
		local stations = WorldMapLayout.stations()
		local expectY = best > 0 and stations[best].y or nil
		r.check(("리프트(역대 최고 Lv %d) → 정거장 %d · 높이 %.0f(기대 %s)"):format(PlayerProfile.getPeakLevel(player), best, root.Position.Y, tostring(expectY and expectY + 3)),
			best == 0 or math.abs(root.Position.Y - (expectY + 3)) < 4)
		if best > 0 then
			put(Vector3.new(90, 6, 90))
			task.wait(1.5)
			r.check(("떨어짐(줄기 옆 바닥) → 마지막 정거장 %d(높이 %.0f)"):format(best, root.Position.Y), math.abs(root.Position.Y - (stations[best].y + 3)) < 4)
			st.checkpoint = nil
			player:SetAttribute("TreeCheckpoint", nil)
		end
	end)
	r.section("복귀", function()
		put(Vector3.new(400, -40, 0))
		task.wait(0.8)
		r.check(("맵 밖 낙하(y −40) → 복귀 y %.0f"):format(root.Position.Y), root.Position.Y > 0)
		-- 높은 곳 착지: 세계 끝 투명 벽 꼭대기에 선다
		local wallTop = D.edge.wallHeight + D.floorTopY
		local a = math.rad(45)
		put(Vector3.new(math.cos(a) * (D.edge.radius + 2), wallTop + 4, math.sin(a) * (D.edge.radius + 2)))
		task.wait(1.6)
		r.check(("높은 곳(세계 끝 벽 위 y %.0f) 착지 → 허브로(허브까지 %.0f)"):format(wallTop, flatDist(root.Position, WorldConfig.zones.spawn.arrival)), flatDist(root.Position, WorldConfig.zones.spawn.arrival) < 12)
	end)
	r.section("봉인 입구", function()
		local profile = PlayerProfile.getProfile(player)
		profile.titles[WorldMapData.sealed.title.id] = nil
		local pushedAll, grants = true, 0
		for _, b in ipairs(WorldMapLayout.sealedBoxes()) do
			put((b.cf * CFrame.new(0, 6, 8)).Position)
			task.wait(0.8)
			local l = b.cf:PointToObjectSpace(root.Position)
			pushedAll = pushedAll and l.Z < 1
			put((b.cf * CFrame.new(b.ledge.localPos + Vector3.new(0, 3.2, 0))).Position)
			local before = PlayerProfile.hasTitle(player, WorldMapData.sealed.title.id)
			task.wait(0.9)
			if not before and PlayerProfile.hasTitle(player, WorldMapData.sealed.title.id) then
				grants += 1
			end
		end
		r.check(("봉인 상자 안 → 5곳 모두 입구 앞으로 %s · 틈 선반 5곳 → 칭호 지급 %d회(기대 1 - 계정 1회)"):format(tostring(pushedAll), grants), pushedAll and grants == 1)
	end)
	put(WorldConfig.zones.spawn.arrival + Vector3.new(0, 5, 0))
	HeightGuard.debugOff = guardOff
	env.restore(player)
	local pass, total = r.summary()
	print(("===M1 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return M1Verify
