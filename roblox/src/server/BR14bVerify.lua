-- BR1-4b 자동 검증 - 보스 모션(관절 리그 · 모션 계산 · 서버 알림 · 잡기 부착점). 판정 코드 경로는 바꾸지 않았다(알림 Attribute · 잡힌 사람 자리만).
--   (가) 순수: 리그 무결성(보스별 부위 · 관절 수) · 쓰는 동작의 관절 이름 · 자세 범위(무릎 · 팔꿈치 꺾임) · 동작 = 판정 시각(타격 프레임 ≤ 0.12초 뒤) ·
--        발 미끄러짐(걷기 FK) · 잡기 부착점(손 · 어깨 · 꼬리 · 집게) · 계산 비용 · 판 털기 최대 거리.
--   (나) 실제 서버: 보스 6종 리그 스폰(루트만 Anchored · 부위 충돌 · 쿼리) · 스킬 알림(BossAct · 전조 초 = 판정 시각) · 판정 시각 표(debugJudgeHook) · 잡기 부착점에 매달림(스탠드인).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local BossMotionData = require(ReplicatedStorage.Shared.data.BossMotionData)
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
		print(("[BR1-4b][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[BR1-4b][%s] %s"):format(tag, label))
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

-- 그 보스가 실제로 쓰는 동작 이름(스킬 · 환경 · 던지기 · 공통)
local function usedClips(id)
	local rig = BossRigSpec.rigs[id]
	local data = BossData.bosses[id]
	local boss = BossMotionData.bosses[id]
	local names, seen = {}, {}
	local function add(n, why)
		if n and not seen[n] then
			seen[n] = true
			table.insert(names, { name = n, why = why })
		end
	end
	for _, sid in ipairs(data.skillOrder) do
		local skill = data.skills[sid]
		if skill and skill.primitive ~= "grab" then
			add(BossMotion.clipNameForSkill(id, rig, sid, skill), sid)
		end
	end
	add(boss.env, "env")
	add(boss.throw, "throw")
	for _, n in ipairs({ "basic_R", "basic_L", "grab_tele", "grab_reach", "grab_hold", "grab_snatch" }) do
		add(n, n)
	end
	return names
end

local function jointSet(rig)
	local set = {}
	for _, j in ipairs(rig.joints) do
		set[j.name] = true
	end
	return set
end

function V.runPure()
	print("===BR1-4b 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("리그 무결성 · 부위 · 관절 수", function()
		local rows, ok = {}, true
		for _, id in ipairs(ALL) do
			local rig = BossRigSpec.rigs[id]
			local parts, bad = { HumanoidRootPart = true }, {}
			for _, j in ipairs(rig.joints) do
				if not parts[j.parent] then
					table.insert(bad, j.name .. "(부모 없음)")
				end
				if parts[j.part] then
					table.insert(bad, j.part .. "(이름 겹침)")
				end
				parts[j.part] = true
			end
			for name, a in pairs(rig.attach) do
				if not parts[a.part] then
					table.insert(bad, "부착 " .. name)
				end
			end
			for _, slot in ipairs(BossRigSpec.holdSlots[rig.plan]) do
				if not rig.attach[slot] then
					table.insert(bad, "들기 " .. slot)
				end
			end
			local js = jointSet(rig)
			for _, chain in ipairs(rig.chains or {}) do
				for _, jn in ipairs(chain) do
					if not js[jn] then
						table.insert(bad, "사슬 " .. jn)
					end
				end
			end
			local old = 3 + #(BossData.bosses[id].attachments or {}) -- 옛 모델 = 루트 · 몸통 · 머리 + 부착물
			table.insert(rows, ("%s 부위 %d(옛 %d · +%d) · 관절 %d%s"):format(id, #rig.joints + 1, old, #rig.joints + 1 - old, #rig.joints, #bad > 0 and (" 문제 " .. table.concat(bad, ",")) or ""))
			ok = ok and #bad == 0 and parts.Body and parts.Head
		end
		r.check("리그: " .. table.concat(rows, " · "), ok)
	end)

	r.section("쓰는 동작의 관절 이름", function()
		local rows, ok = {}, true
		for _, id in ipairs(ALL) do
			local rig = BossRigSpec.rigs[id]
			local js = jointSet(rig)
			local missingClips, unknown = {}, {}
			for _, u in ipairs(usedClips(id)) do
				local clip = BossMotion.clip(id, rig, u.name)
				if not clip then
					table.insert(missingClips, u.name .. "(" .. u.why .. ")")
				else
					for _, list in ipairs({ clip.pre or {}, clip.post or {} }) do
						for _, key in ipairs(list) do
							for joint in pairs(key.pose) do
								if not js[joint] then
									unknown[joint .. "@" .. u.name] = true
								end
							end
						end
					end
				end
			end
			local u = {}
			for k in pairs(unknown) do
				table.insert(u, k)
			end
			table.sort(u)
			ok = ok and #missingClips == 0 and #u == 0
			table.insert(rows, ("%s 동작 %d%s%s"):format(id, #usedClips(id), #missingClips > 0 and (" 없음 " .. table.concat(missingClips, ",")) or "", #u > 0 and (" 모르는 관절 " .. table.concat(u, ",", 1, math.min(#u, 6))) or ""))
		end
		r.check("동작 · 관절: " .. table.concat(rows, " · "), ok)
	end)

	r.section("자세 범위 · 동작 = 판정 시각", function()
		local worst, bad, timing = {}, 0, {}
		for _, id in ipairs(ALL) do
			local rig = BossRigSpec.rigs[id]
			local data = BossData.bosses[id]
			local ctx = BossMotion.context(id, rig, data.skills, data.moveSpeedStuds)
			local maxKnee, maxElbow = 0, 0
			for _, sid in ipairs(data.skillOrder) do
				local skill = data.skills[sid]
				local hit = skill.telegraphSeconds or 1.5
				for t = 0, hit + 2.5, 0.05 do
					local st = { act = sid, actAt = 0, actHit = hit, speed = (t % 1 < 0.5) and 0 or data.moveSpeedStuds, gait = t }
					local pose = BossMotion.evaluate(ctx, st, t)
					for joint, v in pairs(pose) do
						for i = 1, 6 do
							if v[i] ~= v[i] then
								bad += 1
							end
						end
						if joint:find("^Knee_") then
							maxKnee = math.max(maxKnee, -v[1], v[1] > 12 and 999 or 0) -- 무릎은 뒤로만(rx ≤ 0)
						elseif joint:find("^Elbow_") and rig.plan == "biped" then
							maxElbow = math.max(maxElbow, v[1], v[1] < -20 and 999 or 0) -- 팔꿈치는 앞으로만
						end
					end
				end
				-- 타격 프레임: A2-M1 타격 정렬 뒤 = BossMotion.contactTime(접촉 자세 시각) − 판정(hit) - 전조가 있는 동작은 0(보이는 타격 = 판정 순간)
				local clip = BossMotion.clip(id, rig, BossMotion.clipNameForSkill(id, rig, sid, skill) or "")
				if clip and clip.post and clip.post[1] and table.find(BossMotionData.bosses[id].signature, sid) then
					local off = BossMotion.contactTime(clip, hit) - hit
					table.insert(timing, ("%s.%s 판정 %.2f초 → 타격 프레임 %+.2f"):format(id, sid, hit, off))
					if off > 0.12 or off < -0.001 then
						bad += 1
					end
				end
			end
			table.insert(worst, ("%s 무릎 %.0f° 팔꿈치 %.0f°"):format(id, maxKnee, maxElbow))
			if maxKnee > 150 or maxElbow > 170 then
				bad += 1
			end
		end
		r.check(("자세 범위(무릎 ≤ 150° 뒤로만 · 팔꿈치 ≤ 170° 앞으로만 · NaN 0): %s · 문제 %d"):format(table.concat(worst, " · "), bad), bad == 0)
		r.note("대표 패턴 타격 프레임: " .. table.concat(timing, " · "))
	end)

	r.section("발 미끄러짐(걷기 FK)", function()
		local rows, ok = {}, true
		for _, id in ipairs(ALL) do
			local rig = BossRigSpec.rigs[id]
			local data = BossData.bosses[id]
			local S = data.sizeScale
			local ctx = BossMotion.context(id, rig, data.skills, data.moveSpeedStuds)
			local rest = BossMotion.prepare(rig)
			local v = data.moveSpeedStuds
			local stride = ctx.walk.stride * S
			local foot = rig.plan == "scorpion" and "Shin1_L" or "Foot_L"
			local samples = {}
			local dt = 1 / 60
			for k = 0, 180 do
				local t = k * dt
				local dist = v * t
				local st = { speed = v, gait = (dist / (2 * stride)) % 1, lookYaw = 0 }
				local pose = BossMotion.evaluate(ctx, st, 10) -- 대기 흔들림은 고정 시각(걷기만 본다)
				local rootCF = CFrame.new(0, 0, -dist)
				local frames = BossRig.solve(rig, rootCF, S, BossMotion.toTransforms(rest, S, pose))
				local cf = frames[foot]
				local tip = rig.plan == "scorpion" and (cf * CFrame.new(0, -0.975 * S, 0)).Position or (cf * CFrame.new(0, -0.15 * S, 0)).Position
				samples[k] = tip
			end
			-- 딛는 동안(걸음 위상 - 이 발의 딛는 구간 가운데 = cos(2π × 위상) < −0.5) 발의 수평 속도 ÷ 몸 속도
			local slideSum, n = 0, 0
			for k = 1, 180 do
				local g = (v * k * dt / (2 * stride)) % 1
				if math.cos(2 * math.pi * g) < -0.5 then
					local d = Vector3.new(samples[k].X - samples[k - 1].X, 0, samples[k].Z - samples[k - 1].Z).Magnitude / dt
					slideSum += d / v
					n += 1
				end
			end
			local slide = n > 0 and slideSum / n or 1
			table.insert(rows, ("%s %.0f%%"):format(id, slide * 100))
			ok = ok and slide < 0.4
		end
		r.check("딛는 발 미끄러짐(몸 속도 대비 · 기대 < 40%): " .. table.concat(rows, " · "), ok)
	end)

	r.section("잡기 부착점(손 · 어깨 · 꼬리 · 집게)", function()
		local rows, ok = {}, true
		for _, id in ipairs(ALL) do
			local rig = BossRigSpec.rigs[id]
			local data = BossData.bosses[id]
			local S = data.sizeScale
			local ctx = BossMotion.context(id, rig, data.skills, data.moveSpeedStuds)
			local rest = BossMotion.prepare(rig)
			local cells = {}
			for _, slot in ipairs(BossRigSpec.holdSlots[rig.plan]) do
				local minY, far = math.huge, 0
				for k = 0, 11 do -- 들고 있는 동안 여러 시각(흔들림 · 두리번 · 발버둥 흔들림) 중 가장 낮은 발
					local now = 1000 + k * 0.37
					local pose = BossMotion.evaluate(ctx, { act = "grab", actAt = now - 8, actHit = 5, speed = 0, pickAt = now - 2.5 }, now)
					local at = BossRig.attachPoint(rig, CFrame.new(0, 1.5 * S - BossRig.rootLift(rig, S), 0), S, BossMotion.toTransforms(rest, S, pose), slot) -- A2-M1 접지: 루트 = 바닥 + 1.5 × S − 들어 올림(= 실전 루트 바닥 + 1.5)
					minY = math.min(minY, at.Position.Y - BossRigSpec.holdHangStuds - 3) -- 잡힌 사람 발(루트 − 3)
					far = math.max(far, Vector3.new(at.Position.X, 0, at.Position.Z).Magnitude)
				end
				table.insert(cells, ("%s(발 최저 %.1f · 곁 %.1f)"):format(slot, minY, far))
				ok = ok and minY > 1.0 and far < 30
			end
			table.insert(rows, id .. " " .. table.concat(cells, " "))
		end
		r.check("잡힌 사람 발이 땅 위(1 넘게) · 보스 곁 30 안: " .. table.concat(rows, " · "), ok)
	end)

	r.section("계산 비용 · 결정성", function()
		local id = "scorpion_queen" -- 관절이 가장 많다(48)
		local rig = BossRigSpec.rigs[id]
		local data = BossData.bosses[id]
		local ctx = BossMotion.context(id, rig, data.skills, data.moveSpeedStuds)
		local rest = BossMotion.prepare(rig)
		local st = { act = "clawSweep", actAt = 0, actHit = 1.5, speed = 6, gait = 0.3, swingAt = 0.5, swingN = 1 }
		local t0 = os.clock()
		for k = 1, 400 do
			BossMotion.toTransforms(rest, data.sizeScale, BossMotion.evaluate(ctx, st, 1 + k * 0.01))
		end
		local us = (os.clock() - t0) / 400 * 1e6
		local st2 = { act = "grab", actAt = 0, actHit = 5, speed = 0, pickAt = 5.2, noOverlap = true } -- A2-M1: 서버 잡기 FK는 겹침 지연 끔(server/BossAirGrab과 같게)
		local t1 = os.clock()
		for k = 1, 400 do
			BossRig.attachPoint(rig, CFrame.identity, data.sizeScale, BossMotion.toTransforms(rest, data.sizeScale, BossMotion.evaluate(ctx, st2, 8 + k * 0.01)), "Tail1")
		end
		local fk = (os.clock() - t1) / 400 * 1e6
		local a = BossMotion.evaluate(ctx, st, 3.21)
		local b = BossMotion.evaluate(ctx, st, 3.21)
		local same = true
		for joint, v in pairs(a) do
			for i = 1, 6 do
				same = same and b[joint] and b[joint][i] == v[i]
			end
		end
		r.check(("자세 계산 %.0fμs/보스(관절 48 · 클라 프레임당) · 서버 잡기 FK %.0fμs/보스 · 틱(잡힌 사람 수와 무관 - 보스당 1회) · 12아레나 동시 잡기 = %.2fms/틱 · 같은 입력 같은 자세 %s"):format(us, fk, fk * 12 / 1000, tostring(same)), same and fk * 12 < 4000)
	end)

	r.section("판 털기(프라이팬) 날아가는 거리", function()
		local pan = BossData.bosses.abyssal_lord.environment.onStart.pan
		local function at(u, airborne)
			local _, height, distance, _, star = BossSkillMath.panLaunch(pan, Vector3.new(10, 0, 0), airborne, function()
				return u
			end)
			return distance, height, star
		end
		local d0, h0 = at(0, false)
		local d1, _, s1 = at(0.999, false)
		local a1, ah1 = at(0.999, true)
		r.note(("판 위에 서 있기만(땅): 거리 %.0f ~ %.0f(높이 %.0f) · 최대 %.0f에서 별 반짝 %s(별 = %d 이상 → 확률 %.0f%%) · 떠 있으면 최대 %.0f(높이 %.0f)"):format(
			d0, d1, h0, d1, tostring(s1), pan.starDistanceStuds, math.clamp((pan.distanceStuds + pan.distanceJitter - pan.starDistanceStuds) / pan.distanceJitter, 0, 1) * 100, a1, ah1))
	end)

	local pass, total = r.summary()
	print(("===BR1-4b 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===BR1-4b 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local H = require(script.Parent.BR1Verify).helpers
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local MonsterState = require(script.Parent.MonsterState)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local standIns = {}

	r.section("보스 6종 리그 스폰 · 알림 · 판정 시각", function()
		local rows, ok, timing = {}, true, {}
		for i, id in ipairs(ALL) do
			local model, data = H.spawnBoss(player, env, id, 4800 + i, 15)
			assert(model, "보스 스폰 실패 " .. id)
			local motors, parts, anchored, collide, query = 0, 0, 0, 0, 0
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("Motor6D") then
					motors += 1
				elseif d:IsA("BasePart") then
					parts += 1
					anchored += d.Anchored and 1 or 0
					collide += d.CanCollide and 1 or 0
					query += (d.CanQuery and d.Name ~= "HumanoidRootPart" and d.Name ~= "Body" and d.Name ~= "Head") and 1 or 0
				end
			end
			local rig = BossRigSpec.rigs[id]
			local good = model:GetAttribute("BossRig") == id and motors == #rig.joints and anchored == 1 and collide == 0 and query == 0 and model:FindFirstChild("Body") and model:FindFirstChild("Head")
			-- 대표 패턴 2개: 알림(BossAct · 전조) = 서버 판정 시각
			for _, sid in ipairs(BossMotionData.bosses[id].signature) do
				local skill = data.skills[sid]
				local judgedAt, startAt = nil, nil
				BossPatterns.debugJudgeHook = function(rec)
					if rec.skill == sid and not judgedAt then
						judgedAt = rec.serverTime
					end
				end
				model:SetAttribute("BossActAt", nil)
				BossPatterns.force(model, data, sid)
				H.drive(player, root, model, data, (skill.telegraphSeconds or 1.5) + 4, function()
					startAt = startAt or model:GetAttribute("BossActAt")
					return judgedAt ~= nil and model:GetAttribute("BossAct") == nil
				end)
				BossPatterns.debugJudgeHook = nil
				local hit = model:GetAttribute("BossActHit")
				local diff = (judgedAt and startAt and hit) and (judgedAt - (startAt + hit)) or nil
				table.insert(timing, ("%s.%s 알림 전조 %.2f · 판정 %s"):format(id, sid, hit or -1, diff and ("%+.2f초"):format(diff) or "(장판 판정 없음 - 채널/이동형)"))
				ok = ok and hit ~= nil and (diff == nil or math.abs(diff) < 0.12)
			end
			table.insert(rows, ("%s 관절 %d · 부위 %d · Anchored %d · 충돌 %d · 새 부위 쿼리 %d%s"):format(id, motors, parts, anchored, collide, query, good and "" or "(X)"))
			ok = ok and good
			BossEncounter.despawnFor(player)
		end
		r.check("리그 스폰: " .. table.concat(rows, " · "), ok)
		r.note("판정 시각(서버 판정 − 알림 전조 끝): " .. table.concat(timing, " · "))
	end)

	r.section("잡기 부착점에 매달림(스탠드인 · 수호자 2명 · 전갈 3명)", function()
		local BossData_ = BossData
		local rows, ok = {}, true
		for _, case in ipairs({ { "section_guardian", 2 }, { "scorpion_queen", 3 } }) do
			local id, n = case[1], case[2]
			local model, data, encounter = H.spawnBoss(player, env, id, 4900 + n, 15)
			assert(model, "보스 스폰 실패")
			local zone = require(ReplicatedStorage.Shared.data.WorldConfig).zones[encounter.zoneKey]
			local floorY = require(script.Parent.BossArenaMap).floorTopY()
			root.Anchored = true
			root.CFrame = CFrame.new(zone.center + Vector3.new(0, floorY + 3, 70))
			local fakes = {}
			for i = 1, n do
				local a = i / n * 2 * math.pi
				local f = H.newStandIn(model, ("R%d"):format(i), zone.center + Vector3.new(math.cos(a) * 12, floorY + 3, math.sin(a) * 12))
				f.debugAirborne = true
				table.insert(standIns, f)
				table.insert(fakes, f)
			end
			local st = MonsterState.getBossPatternState(model)
			BossPatterns.force(model, data, "grab")
			H.drive(player, root, model, data, data.skills.grab.telegraphSeconds + BossData_.mechanics.airGrab.chaseMaxSeconds * n + 1.5, function()
				return st.grabHeld and #st.grabHeld == n
			end)
			H.drive(player, root, model, data, 0.9) -- 낚아챔(0.7초) 뒤 들고 있는 자세
			local pivot = model:GetPivot().Position
			local cells = {}
			local slots = BossRigSpec.holdSlots[BossRigSpec.rigs[id].plan]
			for i, f in ipairs(fakes) do
				local rootPos = f.Character:FindFirstChild("HumanoidRootPart").Position
				local idx = table.find(st.grabHeld, f)
				local rel = rootPos - pivot
				table.insert(cells, ("%s → %s(높이 %.1f · 곁 %.1f)"):format(f.Name, idx and slots[idx] or "?", rootPos.Y - floorY - 3, Vector3.new(rel.X, 0, rel.Z).Magnitude))
				ok = ok and idx ~= nil and rootPos.Y - floorY - 3 > 0.5 and Vector3.new(rel.X, 0, rel.Z).Magnitude < 25
			end
			table.insert(rows, ("%s %d/%d 잡힘: %s"):format(id, #(st.grabHeld or {}), n, table.concat(cells, " · ")))
			ok = ok and #(st.grabHeld or {}) == n
			H.clearStandIns(player, standIns)
			BossEncounter.despawnFor(player)
		end
		r.check("잡힌 사람이 보이는 부착점 자리(발이 땅 위 · 보스 곁 25 안): " .. table.concat(rows, " · "), ok)
	end)

	if root then
		root.Anchored = false
	end
	H.clearStandIns(player, standIns)
	env.restore(player)
	local pass, total = r.summary()
	print(("===BR1-4b 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
