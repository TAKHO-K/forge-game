-- W1 자동 검증(무기 규격 + 플레이어 모션). id = "W1(가)" · "W1(나)".
--   (가) 순수: 타격 프레임 ↔ 서버 피해 시각표(무기 × 타 × 배율 ×1 · ×2.5 - 차이 ≤ 0.05초) · 배율 줄이는 순서(전조 → 회복 → 동작 · 타격이 보이게) ·
--        클립 구조(전조 · 동작 · 회복 · 키 포즈 4 · 관절 이름) · ×1 길이 ≈ 공격 간격 · 전환 blend 0.15 ~ 0.3 · 넘어짐 → 일어나기 ≤ 0.8초 ·
--        규격 데이터(WeaponRigCheck.specRows) · 규격 검사 함수(맞는 견본 O · 끝 반대 · 1.5배 길이 · Grip 없음 = X)
--   (나) 실제 서버: 전투 중 표시(CombatUntil) · 공격 모션 중계 Remote · 일어나기 무적(강제 이동 기록 없으면 거절 · 있으면 무적 · 간격 거절 · 무적 끝) ·
--        포즈는 루트를 안 움직인다(이동 판정 무관 - 서버가 본 루트 위치 불변)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PlayerMotionData = require(ReplicatedStorage.Shared.data.PlayerMotionData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local MotionTiming = require(ReplicatedStorage.Shared.MotionTiming)
local WeaponRigCheck = require(ReplicatedStorage.Shared.WeaponRigCheck)
local WeaponRigSpec = require(ReplicatedStorage.Shared.data.WeaponRigSpec)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[W1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[W1][%s] %s"):format(tag, label))
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

local JOINTS = {}
for _, n in ipairs({ "Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist", "RightHip", "RightKnee", "LeftHip", "LeftKnee" }) do
	JOINTS[n] = true
end

local function poseOk(pose)
	if type(pose) ~= "table" then
		return false
	end
	for name, v in pairs(pose) do
		if not JOINTS[name] or type(v) ~= "table" or #v < 3 then
			return false
		end
	end
	return true
end

function V.runPure()
	print("===W1 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("시각표(타격 프레임 ↔ 서버 피해)", function()
		local worst, worstRow, rows = 0, nil, MotionTiming.table({ 1, 2.5 })
		local lines = {}
		for _, row in ipairs(rows) do
			if row.diff > worst then
				worst, worstRow = row.diff, row
			end
			if row.speed == 1 or row.label == "1타" then
				table.insert(lines, ("%s %s ×%.1f 모션 %.3f / 서버 %.3f"):format(row.classId, row.label, row.speed, row.anim, row.server))
			end
		end
		r.note(table.concat(lines, " · "))
		r.check(("무기 5 × 타 5 × 배율 2 = %d칸 · 최대 차이 %.3f초(%s %s ×%.1f) ≤ 0.05"):format(#rows, worst, worstRow and worstRow.classId or "-", worstRow and worstRow.label or "-", worstRow and worstRow.speed or 0),
			#rows == 50 and worst <= 0.05 + 1e-9)
		local rangedSame = true
		for _, row in ipairs(rows) do
			if MotionTiming.isRanged(row.classId) and math.abs(row.anim - row.server) > 1e-9 then
				rangedSame = false
			end
		end
		r.check("원거리(활 · 지팡이) 서버 발사 시각 = 모션 타격 프레임(같은 함수 · 배율 · 3타 · 공중 반영)", rangedSame)
	end)

	r.section("공격 속도 배율(전조부터 줄임)", function()
		local S = PlayerMotionData.speedScale
		local bad = {}
		for classId, w in pairs(PlayerMotionData.weapons) do
			local clips = table.clone(w.attacks)
			table.insert(clips, w.air)
			for i, clip in ipairs(clips) do
				for _, speed in ipairs({ 1.5, 2, 2.5 }) do
					local t = MotionTiming.scale(clip, speed, false)
					local antMin = math.min(clip.ant, math.max(clip.ant * S.antMinFraction, S.antMinSeconds))
					local recCut = t.rec < clip.rec - 1e-9
					local actCut = t.act < clip.act - 1e-9
					local ok = math.abs(t.total - (clip.ant + clip.act + clip.rec) / speed) < 1e-6
						and (not recCut or t.ant <= antMin + 1e-9)
						and (not actCut or t.rec <= clip.rec * S.recMinFraction + 1e-9)
						and t.act >= math.min(clip.act, S.actMinSeconds) - 1e-9
					if not ok then
						table.insert(bad, ("%s#%d ×%.1f"):format(classId, i, speed))
					end
				end
			end
		end
		r.check(("길이 = 원래 ÷ 배율 · 회복을 줄이기 전에 전조가 최소 · 동작을 줄이기 전에 회복이 최소 · 동작 ≥ 최소(타격이 보임) - 틀림 %d%s"):format(#bad, #bad > 0 and (" " .. table.concat(bad, " / ")) or ""), #bad == 0)
	end)

	r.section("클립 구조 · 길이", function()
		local bad, lens = {}, {}
		for classId, w in pairs(PlayerMotionData.weapons) do
			for _, key in ipairs({ "stance", "move", "dash", "getupRise" }) do
				if not poseOk(w[key]) then
					table.insert(bad, classId .. "." .. key)
				end
			end
			local clips = table.clone(w.attacks)
			table.insert(clips, w.air)
			for i, c in ipairs(clips) do
				if not (c.ant > 0 and c.act > 0 and c.rec > 0 and poseOk(c.cocked) and poseOk(c.contact) and poseOk(c.through) and poseOk(c.settle)) then
					table.insert(bad, ("%s#%d"):format(classId, i))
				end
			end
			if #w.attacks ~= 3 then
				table.insert(bad, classId .. " 3타 아님")
			end
			local class = ClassData.classes[classId]
			if class then
				local cd = PlayerCombat.getAttackCooldown(classId, 0, 1)
				local total = w.attacks[1].ant + w.attacks[1].act + w.attacks[1].rec
				table.insert(lens, ("%s %.3f/%.3f"):format(classId, total, cd))
				if math.abs(total - cd) > 0.05 then
					table.insert(bad, classId .. " 길이 ≠ 공격 간격")
				end
			end
		end
		r.check(("무기 5종 · 대기 · 이동 · 대시 · 일어나기 · 3타 · 공중 클립(전조 · 동작 · 회복 · 키 포즈 4 · R15 관절) · ×1 1타 길이 ≈ 공격 간격(%s) - 틀림 %d%s"):format(table.concat(lens, " · "), #bad, #bad > 0 and (" " .. table.concat(bad, " / ")) or ""), #bad == 0)
		local B = PlayerMotionData.blend
		r.check(("전환 blend %.2f ~ %.2f(기본 %.2f) · 꺼내기 두 구간 %.3f · %.3f 안(공격 시작만 %.2f - 타격 프레임 ≤ 0.05 때문 · 보고서)"):format(B.min, B.max, B.default,
			PlayerMotionData.drawSeconds * PlayerMotionData.drawGrabT, PlayerMotionData.drawSeconds * (1 - PlayerMotionData.drawGrabT), B.attackIn),
			B.min >= 0.15 and B.max <= 0.3 and B.default >= B.min and B.default <= B.max
			and PlayerMotionData.drawSeconds * PlayerMotionData.drawGrabT >= B.min and PlayerMotionData.drawSeconds * (1 - PlayerMotionData.drawGrabT) <= B.max)
		local G = PlayerMotionData.getup
		local total = G.bounceSeconds + G.lieSeconds + G.riseSeconds + G.settleSeconds
		r.check(("넘어짐 → 일어나기 %.2f초(튕김 %.2f · 누움 %.2f · 일어남 %.2f · 자세 %.2f) ≤ 0.8 · 무적 %.2f ≤ 전체 · 입력 버퍼 %.2f"):format(total, G.bounceSeconds, G.lieSeconds, G.riseSeconds, G.settleSeconds, G.invulnSeconds, G.bufferSeconds),
			total <= 0.8 and G.invulnSeconds <= total and poseOk(G.bounce) and poseOk(G.lie) and G.bufferSeconds > 0)
	end)

	r.section("무기 규격(WeaponRigSpec · WeaponRigCheck)", function()
		local rows = WeaponRigCheck.specRows()
		local bad = {}
		for _, row in ipairs(rows) do
			if not row.ok then
				table.insert(bad, row.label .. "(" .. row.detail .. ")")
			end
		end
		r.check(("규격 데이터 조각 %d(대검 · 쌍검 2 · 활 · 지팡이 · 방패 · 망치): 쥔 방향 직교 · 손잡이 점 · 수납 · 보조 손 거리 - 틀림 %d%s"):format(#rows, #bad, #bad > 0 and (" " .. table.concat(bad, " / ")) or ""), #rows == 7 and #bad == 0)
		local results = {}
		local allGood, allBad = true, true
		for classId, w in pairs(WeaponRigSpec.weapons) do
			for _, piece in ipairs(w.pieces) do
				local name = piece.name
				local good = WeaponRigCheck.sampleModel(classId, name)
				local okGood = WeaponRigCheck.check(classId, name, good)
				good:Destroy()
				local failures = {}
				for _, badKind in ipairs({ "reverse", "long", "noGrip" }) do
					local m = WeaponRigCheck.sampleModel(classId, name, badKind)
					local ok = WeaponRigCheck.check(classId, name, m)
					m:Destroy()
					if ok then
						table.insert(failures, badKind)
					end
				end
				allGood = allGood and okGood
				allBad = allBad and #failures == 0
				table.insert(results, ("%s.%s %s"):format(classId, name or "main", okGood and "O" or "X"))
			end
		end
		r.check(("규격 검사 함수: 맞는 견본 전부 O(%s) · 끝 반대 · 1.5배 길이 · Grip 없음 = 전부 X %s"):format(table.concat(results, " "), tostring(allBad)), allGood and allBad)
	end)

	local pass, total = r.summary()
	print(("===W1 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player)
	print("===W1 검증 시작(나)===")
	local r = newRecorder("나")
	local PlayerState = require(script.Parent.PlayerState)
	local HeightGuard = require(script.Parent.HeightGuard)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		r.check("캐릭터 없음", false)
		print("===W1 검증 끝(나)=== 0/1 통과")
		return
	end

	r.section("전투 중 표시 · 중계", function()
		player:SetAttribute("CombatUntil", nil)
		PlayerState.setLastCombatActionAt(player, os.clock())
		local untilAt = player:GetAttribute("CombatUntil")
		local left = untilAt and (untilAt - Workspace:GetServerTimeNow()) or -1
		r.check(("전투 행동 → CombatUntil = 서버 시각 + %.1f초(데이터 %d) · 공격 모션 중계 Remote %s"):format(left, PlayerMotionData.combatHoldSeconds, tostring(ReplicatedStorage:FindFirstChild("AttackMotion") ~= nil)),
			math.abs(left - PlayerMotionData.combatHoldSeconds) < 0.5 and ReplicatedStorage:FindFirstChild("AttackMotion") ~= nil)
	end)

	r.section("일어나기 무적(서버 검증)", function()
		local hook = ServerStorage:FindFirstChild("W1GetupHook")
		HeightGuard.reset(player)
		task.wait(PlayerMotionData.getup.serverWindowSeconds + 0.3) -- 앞 블록 · 입장이 남긴 강제 이동 창이 지나가게
		local s0 = hook:Invoke(player, true)
		HeightGuard.exempt(player, 0.3) -- 붙잡힘 예외 = 넘어짐 아님(리뷰 1)
		local sE = hook:Invoke(player, true)
		HeightGuard.grantLaunch(player, 5, 1, "W1검증") -- 보스 발사(넉백)
		local s1 = hook:Invoke(player, true)
		local inv1 = PlayerState.isInvulnerable(player)
		local s2 = hook:Invoke(player, false)
		local s3 = hook:Invoke(player, true) -- 같은 발사로 다시(간격 무시) = 이미 소비
		task.wait(PlayerMotionData.getup.invulnSeconds + 0.15)
		local inv2 = PlayerState.isInvulnerable(player)
		HeightGuard.reset(player)
		r.check(("기록 없음 → %s · 붙잡힘 예외만 → %s · 보스 발사 뒤 → %s(무적 %s) · 곧바로 다시 → %s · 같은 발사 두 번째 → %s · %.2f초 뒤 무적 %s"):format(tostring(s0), tostring(sE), tostring(s1), tostring(inv1), tostring(s2), tostring(s3), PlayerMotionData.getup.invulnSeconds + 0.15, tostring(inv2)),
			s0 == "not_forced" and sE == "not_forced" and s1 == "ok" and inv1 == true and s2 == "gap" and s3 == "not_forced" and inv2 == false)
	end)

	r.section("포즈 = 루트 불변(이동 판정 무관)", function()
		-- 모션은 클라 관절 Transform만 쓴다(PoseRig - 루트 파트 CFrame · 속도를 쓰는 코드 없음). 서버가 보는 루트 위치가 일어나기 · 공격 표시 동안 그대로인지(고정 캐릭터).
		local wasAnchored = root.Anchored
		root.Anchored = true
		local p0 = root.Position
		PlayerState.setLastCombatActionAt(player, os.clock())
		task.wait(1)
		local moved = (root.Position - p0).Magnitude
		root.Anchored = wasAnchored
		r.check(("전투 자세 1초 동안 서버 루트 이동 %.3f stud(0)"):format(moved), moved < 1e-3)
	end)

	local pass, total = r.summary()
	print(("===W1 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
