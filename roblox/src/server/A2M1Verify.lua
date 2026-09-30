-- A2-M1 자동 검증(보스 퀄리티 · 모션 공용 보강).
--   (가) 순수: 이징 시작 · 끝 속도(strike · settle · sine = 0) · 전 보스 전 스킬 "보이는 접촉 = 판정 순간"(전조 있는 동작 차이 0) · 사망 연출 ≤ 3초 · 등장 시간(첫 조우 3초 · 짧은 판 1.2초) ·
--        디테일 파트 예산(두 발 ≤ 80 · 전갈 ≤ 110 · 폰에서 보이는 수) · 정면 판정 함수 · 덩치 몸 반경 증가분(배율 1 = 0) · 접지(발바닥 = 루트 − 1.5).
--   (나) 실제: 구간 수호자 스폰(첫 조우 기록 지움 → 3초 · 다시 → 1.2초) · 발 = 바닥 · BodyRadius · 기록 시작 = 연출 끝 · 연출 중 피해 0 · 검증이 만든 보스 0.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local BossMotionData = require(ReplicatedStorage.Shared.data.BossMotionData)
local BossMotion = require(ReplicatedStorage.Shared.BossMotion)
local BossRig = require(ReplicatedStorage.Shared.BossRig)
local Easing = require(ReplicatedStorage.Shared.Easing)
local Reach = require(ReplicatedStorage.Shared.Reach)

local V = {}
local ALL = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }
V.partCaps = { biped = 80, scorpion = 110 } -- A2-M1 파트 예산(사용자 지시 "상한 해제 · 폰 4인 렉 없이 적당히" - art-direction §6)

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[A2-M1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

-- 보스 한 종의 디테일 켬 파트 수(루트 + 관절 부위 + 장식) · 세밀(lod 2) 수
function V.partCount(id)
	local rig = BossRigSpec.rigs[id]
	local n = 1 + #rig.joints
	local lod2 = 0
	for _, d in ipairs(rig.deco or {}) do
		n += 1
		lod2 += d.lod == 2 and 1 or 0
	end
	return n, lod2
end

function V.runPure()
	print("===A2-M1 검증 시작(가)===")
	local r = newRecorder("가")
	r.section("이징", function()
		local rows, ok = {}, true
		for _, k in ipairs({ "strike", "settle", "sine", "inout" }) do
			local p = Easing.profile(k, 400)
			table.insert(rows, ("%s 시작 %.2f · 끝 %.2f · 넘침 %.3f"):format(k, p.v0, p.v1, p.overshoot))
			ok = ok and math.abs(p.v0) < 0.1 and math.abs(p.v1) < 0.1 and math.abs(Easing.get(k, 1) - 1) < 1e-6
		end
		r.check("이징 시작 · 끝 속도 0(한 프레임 튐 없음): " .. table.concat(rows, " · "), ok)
	end)
	r.section("보이는 접촉 = 판정 순간", function()
		local worst, n, bad = 0, 0, {}
		for _, id in ipairs(ALL) do
			local rig = BossRigSpec.rigs[id]
			local data = BossData.bosses[id]
			for sid, skill in pairs(data.skills) do
				if skill.primitive ~= "grab" then
					local clip = BossMotion.clip(id, rig, BossMotion.clipNameForSkill(id, rig, sid, skill) or "")
					local hit = (skill.primitive ~= "gimmick" and skill.telegraphSeconds) or 1.5
					if clip and clip.pre and #clip.pre > 0 and clip.post and hit >= 0.3 then
						n += 1
						local off = BossMotion.contactTime(clip, hit) - hit
						worst = math.max(worst, math.abs(off))
						if math.abs(off) > 1e-6 then
							table.insert(bad, id .. "." .. sid)
						end
					end
				end
			end
		end
		r.check(("전조 있는 스킬 동작 %d개 · 접촉 − 판정 최대 %.4f초(기대 0 - 옛 0.07 ~ 0.12초 늦음)%s"):format(n, worst, #bad > 0 and (" · " .. table.concat(bad, ",")) or ""), n > 0 and #bad == 0)
	end)
	r.section("사망 · 등장 시간", function()
		local rows, ok = {}, true
		for _, plan in ipairs({ "biped", "scorpion" }) do
			local Dd = BossMotionData[plan].death
			-- 화면 시각(슬로모션 뒤 실시간) = 사라짐 끝
			local animEnd = Dd.fadeFrom + Dd.fadeSeconds
			local real = Dd.slowSeconds and (animEnd <= Dd.slowSeconds * Dd.slowRate and animEnd / Dd.slowRate or Dd.slowSeconds + (animEnd - Dd.slowSeconds * Dd.slowRate)) or animEnd
			table.insert(rows, ("%s 사망 %.2f초"):format(plan, real))
			ok = ok and real <= 3.0 + 1e-6
		end
		local I = BossData.mechanics.intro
		table.insert(rows, ("등장 첫 조우 %.1f초 · 짧은 판 %.1f초"):format(I.firstSeconds, I.shortSeconds))
		ok = ok and I.firstSeconds <= 3.0 and I.shortSeconds <= 1.2
		r.check("사망 ≤ 3초 · 등장 ≤ 3 / 1.2초: " .. table.concat(rows, " · "), ok)
	end)
	r.section("디테일 파트 예산", function()
		local rows, ok = {}, true
		for _, id in ipairs(ALL) do
			local rig = BossRigSpec.rigs[id]
			local n, lod2 = V.partCount(id)
			local cap = V.partCaps[rig.plan] or 80
			table.insert(rows, ("%s %d(세밀 %d · 폰 %d) ≤ %d"):format(id, n, lod2, n - lod2, cap))
			ok = ok and n <= cap
		end
		r.check("보스 파트(디테일 켬): " .. table.concat(rows, " · "), ok)
	end)
	r.section("정면 판정 · 몸 반경 · 접지", function()
		local cf = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))
		local a = Reach.inFront(cf, Vector3.new(0, 0, -10), 60, 30)
		local b = Reach.inFront(cf, Vector3.new(10, 0, -10), 60, 30) -- 45°
		local c = Reach.inFront(cf, Vector3.new(10, 0, 0), 60, 30) -- 90°
		local d = Reach.inFront(cf, Vector3.new(0, 0, 10), 60, 30) -- 뒤
		local e = Reach.inFront(cf, Vector3.new(0, 0, -40), 60, 30) -- 너무 멂
		r.check(("정면 ±60° · 30 안: 정면 %s · 45° %s · 옆 %s · 뒤 %s · 멂 %s"):format(tostring(a), tostring(b), tostring(c), tostring(d), tostring(e)), a and b and not c and not d and not e)
		local rows, ok = {}, true
		for _, id in ipairs(ALL) do
			local rig = BossRigSpec.rigs[id]
			local data = BossData.bosses[id]
			local S = data.visualScale or data.sizeScale
			local frames = BossRig.solve(rig, CFrame.identity, S, {})
			local minY = math.huge
			for _, f in ipairs(rig.feet) do
				minY = math.min(minY, (frames[f.part] * CFrame.new(f.at * S)).Position.Y)
			end
			local body
			for _, j in ipairs(rig.joints) do
				if j.part == "Body" then
					body = j
				end
			end
			local extra = body and body.size.X / 2 * (S - data.sizeScale) or 0
			-- 클라 접지 보정(BossAnimator - 발 기준 루트 − 1.5 · 한도 ±0.6 × 크기) 뒤 남는 차
			local diff = -1.5 - minY
			local left = math.max(math.abs(diff) - 0.6 * S, 0)
			table.insert(rows, ("%s 배율 %.2f · 발 %.2f(보정 뒤 %.2f) · 몸 반경 +%.2f"):format(id, S / data.sizeScale, minY, left, extra))
			ok = ok and left < 0.05 and (S > data.sizeScale + 1e-6 or extra == 0)
		end
		r.check("접지(발바닥 = 루트 − 1.5 · 기준 자세 + 클라 보정) · 덩치 몸 반경 증가분(배율 1 = 0): " .. table.concat(rows, " · "), ok)
	end)
	r.section("캐릭터 R · T 모션 · 관성 섞기", function()
		local PlayerMotionData = require(ReplicatedStorage.Shared.data.PlayerMotionData)
		local rows, ok = {}, true
		for _, classId in ipairs({ "greatsword", "dualblade", "bow", "healer" }) do
			local set = PlayerMotionData.skills[classId] or {}
			for _, slot in ipairs({ "Q", "E", "R", "T" }) do
				local c = set[slot]
				local good = c ~= nil and c.cocked ~= nil and c.contact ~= nil and c.settle ~= nil and (c.ant + c.act + c.rec) <= 1.2
				ok = ok and good
				if not good then
					table.insert(rows, classId .. "." .. slot)
				end
			end
		end
		local I = PlayerMotionData.inertia
		ok = ok and I ~= nil and I.decay > 0
		r.check(("4직업 Q · E · R · T 모션(전조 + 동작 + 회복 ≤ 1.2초) · 관성 섞기 decay %s%s"):format(tostring(I and I.decay), #rows > 0 and (" · 빠짐 " .. table.concat(rows, ",")) or ""), ok)
	end)
	local pass, total = r.summary()
	print(("===A2-M1 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===A2-M1 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local MonsterState = require(script.Parent.MonsterState)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	r.section("수호자 등장 · 접지 · 몸 반경 · 기록 시작", function()
		local FLOOR = BossArenaMap.floorTopY()
		local rows = {}
		local ok = true
		for round = 1, 2 do
			BossEncounter.despawnFor(player)
			env.applyStage(player, 15)
			if round == 1 then
				PlayerProfile.debugClearBossIntroSeen(player, "section_guardian")
			end
			BossEncounter.setDebugForcedBoss(player, "section_guardian")
			local t0 = os.clock()
			BossEncounter.spawnFor(player, 15)
			local model = BossEncounter.getActive(player)
			local encounter = BossEncounter.getEncounter(player)
			assert(model and encounter, "보스 스폰 실패")
			local seconds = (model:GetAttribute("BossIntroUntil") or 0) - (model:GetAttribute("BossIntroAt") or 0)
			local full = model:GetAttribute("BossIntroFull") == true
			local _, maxHp = MonsterState.getBossHp(model)
			local _, dealt = MonsterState.applyDamage(model, maxHp * 0.1, 15, player)
			local minFoot = math.huge
			for _, n in ipairs({ "Foot_L", "Foot_R" }) do
				local f = model:FindFirstChild(n)
				if f then
					minFoot = math.min(minFoot, f.Position.Y - f.Size.Y / 2)
				end
			end
			local bodyRadius = model:GetAttribute("BodyRadius") or 0
			local recordShift = encounter.startedAt - t0
			table.insert(rows, ("%d회차 %s %.2f초 · 연출 중 피해 %.1f · 발 − 바닥 %.2f · 몸 반경 +%.2f · 기록 시작 +%.2f"):format(round, full and "첫 조우" or "짧은 판", seconds, dealt or 0, minFoot - FLOOR, bodyRadius, recordShift))
			local want = round == 1 and 3.0 or 1.2
			ok = ok and full == (round == 1) and math.abs(seconds - want) < 0.05 and (dealt or 0) == 0 and math.abs(minFoot - FLOOR) < 0.4 and recordShift >= seconds - 0.1
			ok = ok and (BossData.bodyScaleLive.section_guardian and bodyRadius > 0 or bodyRadius == 0)
		end
		BossEncounter.despawnFor(player)
		r.check("수호자: " .. table.concat(rows, " · "), ok)
	end)
	local leftovers = 0
	for _, m in ipairs(Workspace:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("BossRig") and not m:GetAttribute("BossEncounterId") and m.Name ~= "BossDeathClone" then
			leftovers += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d(기대 0)"):format(leftovers), leftovers == 0)
	local pass, total = r.summary()
	print(("===A2-M1 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
