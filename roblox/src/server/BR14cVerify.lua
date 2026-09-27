-- BR1-4c 자동 검증 - 사용자 플레이 체감 후속(c-1 ~ c-12).
--   (가) 순수: c-3 유도 투사체 회피(회전 상한) 표 · c-8 지진파 도달 표 · c-9 지진파 뒤 흐름(스킬 길이 불변) · c-10 모션 자가 점검(보스 × 항목) · c-12 구조물 조각 수 · 클라 파트 증가.
--   (나) 실제 서버: c-1 붕괴 원인 실측(옛 규칙) → 수정 뒤 조각마다 3점 낙하 + 실제 캐릭터 낙하 + 다음 붕괴 복구 · c-3 유도(0.5초 갱신 · 3초 뒤 직진) ·
--        c-4 진입 연출(보스 피해 · 행동 없음 · 기록 시작) · c-5 처치 순간 투사체 정리 · c-9 지진파 단계 · c-11 눈덩이 파묻힘 → 배출 → 기절.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRig = require(ReplicatedStorage.Shared.BossRig)
local BossMotion = require(ReplicatedStorage.Shared.BossMotion)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)

local V = {}
local ALL = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[BR1-4c][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[BR1-4c][%s] %s"):format(tag, label))
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

function V.runPure()
	print("===BR1-4c 검증 시작(가)===")
	local r = newRecorder("가")
	local walk = 16

	r.section("c-3 유도 투사체 회전 상한", function()
		local rows, ok = {}, true
		for _, id in ipairs(ALL) do
			local b = BossData.bosses[id]
			for _, sid in ipairs(b.skillOrder) do
				local s = b.skills[sid]
				if s and s.primitive == "projectile" and (s.turnRateDeg or 0) > 0 then
					local checks = BossSkillMath.dodgeChecks(s, 8, walk)
					local turn
					for _, c in ipairs(checks) do
						if c.label:find("회전 상한") then
							turn = c
						end
					end
					table.insert(rows, ("%s.%s 회전 %d°/초 · 속도 %d · 옆으로 달리면 필요 회전 %.0f°/초(%s)"):format(id, sid, s.turnRateDeg, s.speedStuds, turn and turn.availableSeconds or -1, turn and (turn.ok and "따돌림" or "못 따돌림") or "?"))
					ok = ok and turn ~= nil and turn.ok
				end
			end
		end
		local H = BossData.mechanics.homing
		r.check(("유도 규칙(대상 고정 · %.1f초마다 갱신 · %.1f초 뒤 직진) · 회피 부등식 추가: %s"):format(H.retargetSeconds, H.homingSeconds, table.concat(rows, " · ")), ok)
	end)

	r.section("c-8 지진파 도달(보이는 것 = 판정)", function()
		local maxR = BossSkillMath.WAVE_MAX_RADIUS_STUDS
		local arena = BossArenaMapData.geometry.radiusStuds
		local rows = {}
		for _, id in ipairs(ALL) do
			local b = BossData.bosses[id]
			for _, sid in ipairs(b.skillOrder) do
				local s = b.skills[sid]
				if s and s.primitive == "ring" then
					local waves = BossSkillMath.ringWaves(s)
					local speed = waves[1].speedStuds
					table.insert(rows, ("%s.%s 속도 %d · 최대 반경 %.1f까지 %.1f초"):format(id, sid, speed, maxR, maxR / speed))
				end
			end
		end
		r.note(("지진파 판정 최대 반경 %.1f(보스 기준 · 그림도 같은 값에서 멈춤) · 아레나 반경 %d → 보스가 가운데일 때만 벽까지 · 가운데서 d 떨어지면 먼 쪽 벽 전 (d − %.1f)에서 끝 · %s"):format(maxR, arena, maxR - arena, table.concat(rows, " · ")))
	end)

	r.section("c-9 지진파 뒤 흐름", function()
		local rows, ok = {}, true
		for _, id in ipairs(ALL) do
			local b = BossData.bosses[id]
			for _, sid in ipairs(b.skillOrder) do
				local s = b.skills[sid]
				if s and s.randomRhythm then
					local waves = BossSkillMath.ringWaves(s)
					local last = waves[#waves]
					local travel = BossSkillMath.WAVE_MAX_RADIUS_STUDS / last.speedStuds + (last.layers - 1) * last.layerGapSeconds
					local after = s.afterWaves and (s.afterWaves.finishSeconds + s.afterWaves.restSeconds) or 0
					table.insert(rows, ("%s.%s 마무리 %.1f + 휴식 %.1f · 마지막 파동이 벽까지 %.1f초 → 스킬 길이 변화 %+.1f초"):format(id, sid, s.afterWaves and s.afterWaves.finishSeconds or 0, s.afterWaves and s.afterWaves.restSeconds or 0, travel, math.max(after - travel, 0)))
					ok = ok and s.afterWaves ~= nil and after <= travel
				end
			end
		end
		r.check("지진파 4종 뒤 마무리 강타 · 휴식(파동이 벽까지 가는 시간 안 = 스킬 길이 · 처치 시간 불변): " .. table.concat(rows, " · "), ok)
	end)

	r.section("c-12 구조물 조각 수 · 클라 파트 증가", function()
		local Looks = require(script.Parent.BossArenaLooks)
		local PROP = require(ReplicatedStorage.Shared.data.ArenaPropData)
		-- 옛 빌더(HEAD BossArenaLooks)의 구조물당 파트 수 - 비교 기준
		local OLD = { rockpile = 8, dolmen = 4, block = 2, boulder = 2, stump = 2, cluster = 3, icePillars = 6, snowMound = 1, statue = 3, brokenArch = 3,
			ruinGate = 3, crystalCluster = 3, ruinFragment = 1, cactus = 3, rodWreck = 3, rubble = 3, runeStones = 8 }
		local worst, over, cells = 0, {}, {}
		for kind in pairs(OLD) do
			local shape = BossArenaMapData.featureShapes[kind]
			local n = Looks.pieceCount(kind, shape and #shape.colliders or 1)
			worst = math.max(worst, n)
			if n > PROP.maxPartsPerStructure then
				table.insert(over, kind)
			end
		end
		for bossId, map in pairs(BossArenaMapData.maps) do
			local maxOld, maxNew = 0, 0
			for _, entry in ipairs(map.layout) do
				local shape = BossArenaMapData.featureShapes[entry.kind]
				maxOld = math.max(maxOld, OLD[entry.kind] or 0)
				maxNew = math.max(maxNew, Looks.pieceCount(entry.kind, shape and #shape.colliders or 1))
			end
			local cap = BossArenaMapData.regrow.maxObstacles
			table.insert(cells, ("%s 14개 최악 %d → %d(+%d)"):format(bossId, maxOld * cap, maxNew * cap, (maxNew - maxOld) * cap))
		end
		table.sort(cells)
		r.check(("구조물당 조각 최대 %d(상한 %d · 넘는 kind %d개) · 동시 상한 14개 기준 클라 파트: %s"):format(worst, PROP.maxPartsPerStructure, #over, table.concat(cells, " · ")), #over == 0)
	end)

	r.section("c-10 모션 자가 점검(보스 × 항목)", function()
		local rows, ok = {}, true
		for _, id in ipairs(ALL) do
			local rig = BossRigSpec.rigs[id]
			local data = BossData.bosses[id]
			local S = data.sizeScale
			local ctx = BossMotion.context(id, rig, data.skills, data.moveSpeedStuds)
			local rest = BossMotion.prepare(rig)
			local worstFloat, worstSink, worstPop, handBelow = 0, 0, 0, 0
			local buried = {}
			local prev = nil
			local function sample(st, t)
				local pose, info = BossMotion.evaluate(ctx, st, t)
				local frames = BossRig.solve(rig, CFrame.identity, S, BossMotion.toTransforms(rest, S, pose))
				-- 발 접지 보정(클라 BossAnimator와 같은 식) 전 오차
				local minY = math.huge
				for _, f in ipairs(rig.feet) do
					minY = math.min(minY, (frames[f.part] * CFrame.new(f.at * S)).Position.Y)
				end
				local err = minY - (-1.5 * S)
				local fix = info.airborne and 0 or math.clamp(-err, -0.6 * S, 0.6 * S)
				if not info.airborne and not st.deadAt then
					worstFloat = math.max(worstFloat, err + fix) -- 보정 뒤 남는 뜬 발(단위 stud)
					worstSink = math.max(worstSink, -(err + fix))
				end
				for _, hand in ipairs({ "Hand_R", "Hand_L" }) do
					local h = frames[hand]
					if h and not st.deadAt then
						handBelow = math.max(handBelow, (-1.5 * S) - (h.Position.Y + fix) - 0.5 * S) -- 손이 바닥을 반 단위 넘게 뚫음
					end
				end
				return frames
			end
			for _, sid in ipairs(data.skillOrder) do
				local s = data.skills[sid]
				local clip = BossMotion.clip(id, rig, BossMotion.clipNameForSkill(id, rig, sid, s) or "")
				if clip and clip.buried then
					buried[sid] = true
				end
				if s.primitive ~= "grab" and not (clip and clip.buried) then
					local hit = s.telegraphSeconds or 1.5
					prev = nil
					for k = 0, math.floor((hit + 2) * 60) do
						local t = k / 60
						local frames = sample({ act = sid, actAt = 0, actHit = hit, speed = 0, lookYaw = 0, inCombat = true }, t)
						if prev then
							for name, cf in pairs(frames) do
								local d = (cf.Position - prev[name].Position).Magnitude * 60
								if name ~= "HumanoidRootPart" then
									worstPop = math.max(worstPop, d / S)
								end
							end
						end
						prev = frames
					end
				end
			end
			for _, st in ipairs({ { stunAt = 0, stunUntil = 4 }, { deadAt = 0 }, { act = "grab", actAt = 0, actHit = 5, pickAt = 5.5, inCombat = true } }) do
				for t = 0, 4, 0.1 do
					sample(st, t)
				end
			end
			local b = {}
			for sid in pairs(buried) do
				table.insert(b, sid)
			end
			table.sort(b)
			table.insert(rows, ("%s 뜬 발 %.2f · 파묻힘 %.2f · 손 관통 %.1f · 가장 빠른 부위 %.0f단위/초%s"):format(id, worstFloat, worstSink, handBelow, worstPop, #b > 0 and (" · 모래 속 의도(" .. table.concat(b, ",") .. ")") or ""))
			ok = ok and worstFloat < 0.3 and worstSink < 0.3
		end
		r.check("자가 점검(발 접지 보정 뒤 · 뛰는 동작 · 사망 제외 · 기준 < 0.3 stud): " .. table.concat(rows, " · "), ok)
	end)

	local pass, total = r.summary()
	print(("===BR1-4c 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===BR1-4c 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local H = require(script.Parent.BR1Verify).helpers
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local MonsterState = require(script.Parent.MonsterState)
	local HeightGuard = require(script.Parent.HeightGuard)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local FLOOR = BossArenaMap.floorTopY()
	local sent = {}
	local function hook()
		table.clear(sent)
		BossPatterns.debugSendHook = function(kind, payload)
			table.insert(sent, { kind = kind, payload = payload, at = os.clock() })
		end
	end
	local function countKind(kind)
		local n, last = 0, nil
		for _, e in ipairs(sent) do
			if e.kind == kind then
				n += 1
				last = e
			end
		end
		return n, last
	end

	r.section("c-1 붕괴 원인 · 3점 낙하 · 복구", function()
		local model, data, encounter = H.spawnBoss(player, env, "section_guardian", 4501, 15)
		assert(model, "보스 스폰 실패")
		local zone = WorldConfig.zones[encounter.zoneKey]
		local st = MonsterState.getBossPatternState(model)
		st.env = { phase = "armed", phaseEndsAt = 0, taken = {} }
		st.graceUntil = os.clock() + 999
		root.Anchored = true
		root.CFrame = CFrame.new(zone.center + Vector3.new(0, FLOOR + 30, 0))
		BossArenaMap.debugMoundCenterOnly = true -- 옛 규칙으로 원인 실측
		hook()
		H.drive(player, root, model, data, data.environment.telegraphSeconds + 3, function()
			return countKind("envStart") > 0
		end)
		local _, tel = countKind("envTelegraph")
		assert(tel, "붕괴 전조 없음")
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = true
		local function probe(z, frac)
			local a = math.rad(z.startDeg + z.widthDeg / 2)
			local rad = z.hub + 3 + (z.radius - z.hub - 9) * frac
			local at = Vector3.new(z.center.X, FLOOR + 12, z.center.Z) + Vector3.new(math.cos(a), 0, math.sin(a)) * rad
			local hit = Workspace:Raycast(at, Vector3.new(0, -40, 0), params)
			return hit, rad
		end
		local function sweep()
			local cells, holes, total = {}, 0, 0
			for _, z in ipairs(tel.payload.zones) do
				for _, frac in ipairs({ 0, 0.5, 1 }) do
					local hit, rad = probe(z, frac)
					total += 1
					holes += hit == nil and 1 or 0
					table.insert(cells, ("조각%d r%.0f %s"):format(z.index, rad, hit and ("%s @%.1f"):format(hit.Instance.Name, hit.Position.Y - FLOOR) or "구멍"))
				end
			end
			return cells, holes, total
		end
		-- 둔덕(원판 층) 중 무너진 조각에 걸친 점 - 그 점 아래가 비는가(3점 표본이 둔덕을 비껴갈 수 있어 따로 잰다)
		local sliceIndexOf = require(ReplicatedStorage.Shared.BossSkillMath).sliceIndexOf
		local sf = BossArenaMap.sliceFloorOf(encounter.zoneKey)
		local function moundSweep()
			local cells, stand, total = {}, 0, 0
			for _, mound in ipairs(BossArenaMap.moundsOf(encounter.zoneKey)) do
				local rr = mound.Size.Y / 2
				for k = 0, 23 do
					local a = k / 24 * 2 * math.pi
					local p = mound.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * rr * 0.9
					local i = sf and sliceIndexOf(zone.center, p, sf.count, sf.hubRadius, 0)
					if i and sf.collapsed and sf.collapsed[i] then
						local hit = Workspace:Raycast(Vector3.new(p.X, FLOOR + 12, p.Z), Vector3.new(0, -40, 0), params)
						total += 1
						stand += hit and 1 or 0
						table.insert(cells, ("둔덕(반경 %.0f · 윗면 +%.1f) 조각%d %s"):format(rr, mound.Position.Y + mound.Size.X / 2 - FLOOR, i,
							hit and ("%s @%.1f"):format(hit.Instance.Name, hit.Position.Y - FLOOR) or "구멍"))
						break
					end
				end
			end
			return cells, stand, total
		end
		local cells0, holes0, total0 = sweep()
		-- 둔덕마다 중심이 아닌 조각 하나를 더 무너뜨린다(무작위 붕괴가 걸친 조각을 안 고를 수 있다 - 원인 재현을 확실히)
		for _, mound in ipairs(BossArenaMap.moundsOf(encounter.zoneKey)) do
			local own = sf and sliceIndexOf(zone.center, mound.Position, sf.count, sf.hubRadius, 0)
			for k = 0, 23 do
				local a = k / 24 * 2 * math.pi
				local p = mound.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * mound.Size.Y / 2 * 0.9
				local i = sf and sliceIndexOf(zone.center, p, sf.count, sf.hubRadius, 0)
				if i and i ~= own then
					BossArenaMap.setSliceCollapsed(encounter.zoneKey, i, true)
					break
				end
			end
		end
		local mcells0, mstand0, mtotal0 = moundSweep()
		r.note(("원인 실측(옛 규칙 - 둔덕 = 중심 조각만): %d/%d점 구멍 · %s | 무너진 조각에 걸친 둔덕 %d개 중 밟힘 %d · %s"):format(holes0, total0, table.concat(cells0, " · "),
			mtotal0, mstand0, table.concat(mcells0, " · ")))
		-- 수정 규칙으로 다시 계산(걸친 둔덕도 꺼짐)
		BossArenaMap.debugMoundCenterOnly = nil
		for _, z in ipairs(tel.payload.zones) do
			BossArenaMap.setSliceCollapsed(encounter.zoneKey, z.index, true)
		end
		local cells1, holes1, total1 = sweep()
		local mcells1, mstand1, mtotal1 = moundSweep()
		-- 실제 캐릭터: 가운데 쪽 끝(중앙 구역 높이 근처)에서 떨어뜨려 빠지는가
		local z1 = tel.payload.zones[1]
		local a = math.rad(z1.startDeg + z1.widthDeg / 2)
		local spot = Vector3.new(z1.center.X, FLOOR + 4, z1.center.Z) + Vector3.new(math.cos(a), 0, math.sin(a)) * (z1.hub + 4)
		root.Anchored = false
		character:PivotTo(CFrame.new(spot))
		HeightGuard.reset(player)
		local fell = false
		H.drive(player, root, model, data, 3, function()
			fell = fell or countKind("voidFall") > 0
			return fell
		end)
		r.check(("수정 뒤: %d/%d점 구멍(기대 전부) · 걸친 둔덕 %d개 중 밟힘 %d(기대 0) · 가운데 쪽 끝(반경 %.0f)에서 실제 캐릭터 낙하 → 전멸기 + 복귀 %s · %s · %s"):format(holes1, total1,
			mtotal1, mstand1, z1.hub + 4, tostring(fell), table.concat(cells1, " · "), table.concat(mcells1, " · ")),
			holes1 == total1 and mstand1 == 0 and fell)
		-- 다음 붕괴 때 복구: 앞 조각은 돌아온다
		root.Anchored = true
		root.CFrame = CFrame.new(zone.center + Vector3.new(0, FLOOR + 30, 0))
		local prevZones = tel.payload.zones
		table.clear(sent)
		st.env.phase, st.env.phaseEndsAt = "armed", 0
		H.drive(player, root, model, data, data.environment.telegraphSeconds + 3, function()
			return countKind("envStart") > 0
		end)
		local restored, checked = 0, 0
		local _, tel2 = countKind("envTelegraph")
		for _, z in ipairs(prevZones) do
			local stillDown = false
			for _, z2 in ipairs(tel2 and tel2.payload.zones or {}) do
				stillDown = stillDown or z2.index == z.index
			end
			if not stillDown then
				checked += 1
				local hit = probe(z, 0.5)
				restored += hit and 1 or 0
			end
		end
		r.check(("다음 붕괴 때 앞 조각 복구 %d/%d(바닥 있음)"):format(restored, checked), checked > 0 and restored == checked)
		BossPatterns.debugSendHook = nil
		BossEncounter.despawnFor(player)
	end)

	r.section("c-4 진입 연출", function()
		BossEncounter.despawnFor(player)
		env.applyStage(player, 15)
		BossEncounter.setDebugForcedBoss(player, "section_guardian")
		local t0 = os.clock()
		BossEncounter.spawnFor(player, 15)
		local model = BossEncounter.getActive(player)
		local encounter = BossEncounter.getEncounter(player)
		assert(model and encounter, "보스 스폰 실패")
		local introUntil = model:GetAttribute("BossIntroUntil")
		local seconds = introUntil and introUntil - Workspace:GetServerTimeNow() or 0
		local _, maxHp = MonsterState.getBossHp(model)
		local _, dealt = MonsterState.applyDamage(model, maxHp * 0.1, 15, player)
		local locked = player:GetAttribute("BossIntroLock") == true
		local recordShift = encounter.startedAt - t0
		task.wait(seconds + 0.3)
		local _, dealt2 = MonsterState.applyDamage(model, maxHp * 0.01, 15, player)
		r.check(("연출 %.2f초 · 연출 중 보스 피해 %.1f(기대 0) · 입력 잠금 %s · 기록 시작 +%.2f초(연출 뒤) · 끝난 뒤 피해 %.1f(>0) · 잠금 풀림 %s"):format(seconds, dealt or 0, tostring(locked), recordShift,
			dealt2 or 0, tostring(player:GetAttribute("BossIntroLock") == nil)), seconds > 0.9 and (dealt or 0) == 0 and locked and recordShift >= seconds - 0.1 and (dealt2 or 0) > 0 and player:GetAttribute("BossIntroLock") == nil)
		BossEncounter.despawnFor(player)
	end)

	r.section("c-3 유도(0.5초 갱신 · 3초 뒤 직진) · c-5 처치 순간 정리", function()
		local model, data, encounter = H.spawnBoss(player, env, "section_guardian", 4701, 15)
		assert(model, "보스 스폰 실패")
		local zone = WorldConfig.zones[encounter.zoneKey]
		local st = MonsterState.getBossPatternState(model)
		root.Anchored = true
		local startAt = zone.center + Vector3.new(70, FLOOR + 3, -40)
		root.CFrame = CFrame.new(startAt)
		BossPatterns.force(model, data, "orbs")
		-- 대상(개발 캐릭터)이 옆으로 달린다(걷기 16) - 목표 갱신 간격 · 3초 뒤 직진 확인
		local dirs, retargets, lastAim, tracked = {}, 0, nil, nil
		local t0 = os.clock()
		H.drive(player, root, model, data, data.skills.orbs.telegraphSeconds + 5.5, function()
			local t = os.clock() - t0
			root.CFrame = CFrame.new(startAt + Vector3.new(0, 0, t * 16))
			local p = tracked
			if not p then
				for _, q in ipairs(st.projectiles or {}) do
					if q.target == player then
						p = q
						tracked = q
					end
				end
			end
			if p then
				if p.aimAt ~= lastAim then
					retargets += 1
					lastAim = p.aimAt
				end
				table.insert(dirs, { at = os.clock() - p.bornAt, dir = p.dir })
			end
			return false
		end)
		local turnAfter3, turnBefore = 0, 0
		for i = 2, #dirs do
			local d = math.deg(math.acos(math.clamp(dirs[i].dir:Dot(dirs[i - 1].dir), -1, 1)))
			if dirs[i].at > BossData.mechanics.homing.homingSeconds + 0.15 then -- 경계 틱(지연 0.25에서 3.0초 틱이 3.05 뒤에 기록됨 - Play 3 X 0.02°)
				turnAfter3 = math.max(turnAfter3, d)
			else
				turnBefore = math.max(turnBefore, d)
			end
		end
		r.check(("구체(회전 %d°/초): 따라가는 %.1f초 동안 목표 갱신 %d회(0.5초마다 ≈ 7) · 그동안 틱당 최대 회전 %.2f° · 3초 뒤 회전 %.3f°(기대 0 - 직진)"):format(data.skills.orbs.turnRateDeg or 0, 3, retargets, turnBefore, turnAfter3),
			tracked ~= nil and retargets >= 5 and retargets <= 9 and turnAfter3 < 0.01)
		-- c-5: 투사체가 떠 있는 채 처치 경로(clearProps) → 목록 비움
		BossPatterns.force(model, data, "orbs")
		H.drive(player, root, model, data, data.skills.orbs.telegraphSeconds + 0.4)
		local before = #(st.projectiles or {})
		BossPatterns.clearProps(model, { player })
		r.check(("처치 순간 정리: 떠 있던 투사체 %d → %d · 파동 %d"):format(before, #(st.projectiles or {}), #(st.waves or {})), before > 0 and #(st.projectiles or {}) == 0 and #(st.waves or {}) == 0)
		BossEncounter.despawnFor(player)
	end)

	r.section("c-9 지진파 단계", function()
		local model, data = H.spawnBoss(player, env, "section_guardian", 4801, 15)
		assert(model, "보스 스폰 실패")
		local phases, t0 = {}, os.clock()
		BossPatterns.force(model, data, "shockwave")
		local st = MonsterState.getBossPatternState(model)
		local last
		H.drive(player, root, model, data, 16, function()
			if st.phase ~= last then
				last = st.phase
				table.insert(phases, ("%s@%.1f"):format(tostring(st.phase), os.clock() - t0))
			end
			return st.current == nil and os.clock() - t0 > 1
		end)
		local joined = table.concat(phases, " → ")
		r.check(("진동파 단계: %s(마무리 강타 → 숨 고르기 → 파동 대기 → 끝)"):format(joined), joined:find("quakeFinish") ~= nil and joined:find("quakeRest") ~= nil)
		BossEncounter.despawnFor(player)
	end)

	r.section("c-11 눈덩이 파묻힘 → 배출 → 기절", function()
		local PlayerStun = require(script.Parent.PlayerStun)
		local BossTrap = require(script.Parent.BossTrap)
		local model, data, encounter = H.spawnBoss(player, env, "frost_giant", 4901, 15)
		assert(model, "보스 스폰 실패")
		local zone = WorldConfig.zones[encounter.zoneKey]
		local st = MonsterState.getBossPatternState(model)
		local e = data.skills.snowball.engulf
		root.Anchored = false
		root.CFrame = CFrame.new(zone.center + Vector3.new(45, FLOOR + 3, 0))
		H.fullHeal(player)
		local events = {}
		BossPatterns.debugEventHook = function(kind, record)
			if kind == "snowballEngulf" or kind == "snowballEject" then
				events[kind] = events[kind] or record
			end
		end
		hook()
		local since = os.clock()
		BossPatterns.force(model, data, "snowball")
		local placed, maxDrift, stunnedSeen, lastPos = false, 0, false, nil
		H.drive(player, root, model, data, data.skills.snowball.telegraphSeconds + 8, function()
			if not placed then
				local p = (st.projectiles or {})[1]
				if p and p.skill.engulf then
					placed = true
					local at = p.position + Vector3.new(p.dir.X, 0, p.dir.Z).Unit * 14
					root.CFrame = CFrame.new(at.X, FLOOR + 3, at.Z) -- 굴러오는 길 위에 선다
				end
			end
			if events.snowballEngulf and not events.snowballEject then
				-- 파묻힌 동안 서버 자리 = 눈덩이 중심 위(따라 굴러간다)
				for _, p in ipairs(st.projectiles or {}) do
					if p.riders and #p.riders > 0 then
						maxDrift = math.max(maxDrift, (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(p.position.X, 0, p.position.Z)).Magnitude)
					end
				end
			end
			if events.snowballEject then
				stunnedSeen = stunnedSeen or PlayerStun.isStunned(player)
			end
			return events.snowballEject ~= nil and os.clock() - events.snowballEject.at > 0.2
		end)
		BossPatterns.debugEventHook = nil
		local engulfed, ejected = events.snowballEngulf, events.snowballEject
		local buried = engulfed and ejected and (ejected.at - engulfed.at) or -1
		local at = ejected and ejected.position
		local inZone = at and (Vector3.new(at.X, 0, at.Z) - Vector3.new(zone.center.X, 0, zone.center.Z)).Magnitude <= (zone.radius or 140)
		local clear = at and not BossArenaMap.overlapsObstacle(encounter.zoneKey, at, BossData.mechanics.dodge.characterHalfWidthStuds, 0)
		local rolledBack = HeightGuard.flaggedSince(player, since)
		r.check(("파묻힘 %.2f초(상한 %.1f 또는 벽 - 이유 %s) · 따라 구른 서버 자리 어긋남 최대 %.1f · 배출 자리 아레나 안 %s · 구조물 밖 %s · 잡힘 풀림 %s · 기절 %s(%.1f초) · 합계 ≤ %.1f초 · 높이 검사 되돌림 %s(기대 false)"):format(
			buried, e.maxSeconds, tostring(ejected and ejected.why), maxDrift, tostring(inZone), tostring(clear), tostring(not BossTrap.isTrapped(player)),
			tostring(stunnedSeen), e.stunSeconds, e.maxSeconds + e.stunSeconds, tostring(rolledBack)),
			engulfed ~= nil and buried > 0 and buried <= e.maxSeconds + 0.1 and maxDrift < 1 and inZone and clear and not BossTrap.isTrapped(player) and stunnedSeen and not rolledBack)
		BossEncounter.despawnFor(player)
	end)

	BossArenaMap.debugMoundCenterOnly = nil -- 리뷰 5: 섹션이 중간에 실패해도 옛 규칙이 켜진 채 남지 않게
	if root then
		root.Anchored = false
	end
	env.restore(player)
	local pass, total = r.summary()
	print(("===BR1-4c 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
