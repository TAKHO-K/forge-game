-- A2-M1 측정기(Studio 전용 - 라이브에서는 아무것도 안 한다). 판정 · 게임 상태를 바꾸지 않는다. 명령 = LocalPlayer Attribute(클라 execute_luau로 준다):
--   MotionProbeStart = "이름|초|대상"  대상 = boss(가장 가까운 보스 리그 · 전시 리그 포함) · self(내 캐릭터 - 루트 기준 상대 회전) · 모델 이름
--     → 매 프레임(렌더 직전 마지막) 부위 CFrame → 각속도 벡터(도/초)의 프레임 사이 변화가 angJump를 넘거나 몸 이동(보스 Hips) 속도 변화가 linJump × 크기를 넘으면 "튐".
--       모델 Attribute ClientImpacts("시작,끝;…" 서버 시각 - 클라 BossAnimator · WeaponVisual이 적는 의도된 타격 창)는 뺀다. 동작 이름 = LocalPlayer BossAnimAction(전시 리그) · 모델 BossAct · 없으면 idle/move.
--     결과 = LocalPlayer Attribute MotionProbeResult(줄마다 "이름;동작;프레임;튐;최악 점수;부위") + 출력 [MotionProbe] 줄. 기준 = 오프라인 하네스(roblox/tools/harness/boss_motion_test.luau)와 같다.
--   PerfProbeStart = "이름|초" → 프레임(평균 · 하위 5%) · 보스 모션 μs · 화면 안 파트 · 추정 삼각형 · 입자(방출 중 · 초당) · Highlight · Beam · Trail → PerfProbeResult + [ArenaPerf] 줄.
--   FakeParty = n → 내 캐릭터 복제 n개(이 클라에만 · 고정 · 충돌 없음)를 가장 가까운 보스 둘레에 세운다(4인 가정 화면 부하) · 0 = 치움.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Stats = game:GetService("Stats")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
local ANG_JUMP, LIN_JUMP = 450, 4.0

local function serverNow()
	return Workspace:GetServerTimeNow()
end

local function nearestBoss()
	local cam = Workspace.CurrentCamera
	local from = cam and cam.CFrame.Position or Vector3.zero
	local best, bestD = nil, math.huge
	for _, m in ipairs(Workspace:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("BossRig") and m.Name ~= "BossDeathClone" then
			local root = m:FindFirstChild("HumanoidRootPart")
			if root then
				local d = (root.Position - from).Magnitude
				if d < bestD then
					best, bestD = m, d
				end
			end
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("Monster")) do
		if m:GetAttribute("BossRig") then
			local root = m:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - from).Magnitude < bestD then
				best, bestD = m, (root.Position - from).Magnitude
			end
		end
	end
	return best
end

local function impactWindows(model)
	local out = {}
	local s = model and model:GetAttribute("ClientImpacts")
	if type(s) == "string" then
		for a, b in s:gmatch("([%d%.%-]+),([%d%.%-]+)") do
			table.insert(out, { tonumber(a), tonumber(b) })
		end
	end
	return out
end

local function inWindow(list, t)
	for _, w in ipairs(list) do
		if t >= w[1] and t <= w[2] then
			return true
		end
	end
	return false
end

-- 회전 차이 → 월드 각속도 벡터(도 · 축 × 각)
local function axisAngle(a, b)
	local rel = b * a:Inverse()
	local axis, angle = rel:ToAxisAngle()
	return axis * math.deg(angle)
end

local motionRun = nil
local function startMotion(spec)
	local name, seconds, target = spec:match("^([^|]*)|([^|]*)|?(.*)$")
	seconds = tonumber(seconds) or 10
	target = (target == nil or target == "") and "boss" or target
	local model
	if target == "self" then
		model = player.Character
	elseif target == "boss" then
		model = nearestBoss()
	else
		model = Workspace:FindFirstChild(target, true)
	end
	if not model then
		player:SetAttribute("MotionProbeResult", "대상 없음: " .. tostring(target))
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local S = (target ~= "self" and root) and root.Size.X / 2 or 1
	motionRun = { name = name, model = model, root = root, rel = target == "self", S = S, untilT = os.clock() + seconds, prev = {}, stats = {}, frames = 0, flagged = false }
	print(("[MotionProbe] 시작 %s · %s · %.0f초"):format(name, model.Name, seconds))
end

local function actionLabel(r)
	local a = player:GetAttribute("BossAnimAction")
	if r.model.Name == "BossAnimPreview" and a then
		return a
	end
	local act = r.model:GetAttribute("BossAct")
	if act then
		return "skill:" .. act
	end
	if r.rel then
		return player:GetAttribute("MotionProbeLabel") or "self"
	end
	return "base"
end

local function finishMotion(r)
	local lines = {}
	local total = 0
	local keys = {}
	for k in pairs(r.stats) do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local s = r.stats[k]
		total += s.jumps
		table.insert(lines, ("%s;%s;%d;%d;%.2f;%s"):format(r.name, k, s.frames, s.jumps, s.worst, tostring(s.worstPart)))
		print(("[MotionProbe] %s · %s · 프레임 %d · 튐 %d · 최악 %.2f(%s)"):format(r.name, k, s.frames, s.jumps, s.worst, tostring(s.worstPart)))
	end
	print(("[MotionProbe] 끝 %s · 튐 합계 %d · 프레임 %d"):format(r.name, total, r.frames))
	player:SetAttribute("MotionProbeResult", table.concat(lines, "\n"))
end

local function stepMotion(dt)
	local r = motionRun
	if not r then
		return
	end
	if os.clock() > r.untilT or not r.model.Parent then
		motionRun = nil
		finishMotion(r)
		return
	end
	if dt <= 0 then
		return
	end
	r.frames += 1
	local label = actionLabel(r)
	local s = r.stats[label]
	if not s then
		s = { frames = 0, jumps = 0, worst = 0, worstPart = nil }
		r.stats[label] = s
	end
	s.frames += 1
	local excluded = inWindow(impactWindows(r.model), serverNow())
	local rootCf = r.root and r.root.CFrame or CFrame.identity
	local bad = false
	for _, part in ipairs(r.model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Hitbox" and part.Transparency < 1 then
			local cf = r.rel and rootCf:ToObjectSpace(part.CFrame) or part.CFrame
			local p = r.prev[part]
			if p then
				local w = axisAngle(p.cf, cf) / dt
				local v = (cf.Position - p.cf.Position) / dt
				if p.w and not excluded then
					local dw = (w - p.w).Magnitude
					local dv = (v - p.v).Magnitude
					local score = math.max(dw / ANG_JUMP, (part.Name == "Hips" and not r.rel) and dv / (LIN_JUMP * r.S) or 0)
					if score > 1 then
						bad = true
					end
					if score > s.worst then
						s.worst, s.worstPart = score, part.Name
					end
				end
				p.cf, p.w, p.v = cf, w, v
			else
				r.prev[part] = { cf = cf }
			end
		end
	end
	if bad and not r.flagged then
		s.jumps += 1
	end
	r.flagged = bad
end

-- ─────────────────────────── 성능 ───────────────────────────
local TRI = { Block = 12, Wedge = 8, CornerWedge = 6, Ball = 224, Cylinder = 92 } -- 기본 도형 추정 삼각형(엔진 메시 대략값 - 보고서에 "추정"으로 적는다)
local perfRun = nil
local function startPerf(spec)
	local name, seconds = spec:match("^([^|]*)|?(.*)$")
	perfRun = { name = name, untilT = os.clock() + (tonumber(seconds) or 8), dts = {}, anim = {} }
	print("[ArenaPerf] 시작 " .. name)
end

local function statOf(key)
	local ok, v = pcall(function()
		return Stats[key]
	end)
	return ok and v or nil
end

local function finishPerf(r)
	table.sort(r.dts)
	local n = #r.dts
	local sum = 0
	for _, d in ipairs(r.dts) do
		sum += d
	end
	local fpsAvg = n > 0 and n / sum or 0
	local p95 = n > 0 and r.dts[math.max(1, math.floor(n * 0.95))] or 0
	local animUs = 0
	for _, u in ipairs(r.anim) do
		animUs += u
	end
	animUs = #r.anim > 0 and animUs / #r.anim or 0
	-- 화면 안(카메라 앞 · 250 이내 · 뷰포트 안) 파트 · 추정 삼각형 · 효과
	local cam = Workspace.CurrentCamera
	local parts, tris, meshTris, emitters, emitRate, highlights, beams, trails = 0, 0, 0, 0, 0, 0, 0, 0
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Transparency < 1 and (d.Position - cam.CFrame.Position).Magnitude < 250 then
				local sp, on = cam:WorldToViewportPoint(d.Position)
				if on and sp.Z > 0 then
					parts += 1
					if d:IsA("MeshPart") then
						meshTris += 500 -- MeshPart 삼각형은 API로 못 읽는다(자리 표시)
					elseif d:IsA("Part") then
						tris += TRI[d.Shape.Name] or 12
					else
						tris += 12
					end
				end
			end
		elseif d:IsA("ParticleEmitter") and d.Enabled then
			emitters += 1
			emitRate += d.Rate
		elseif d:IsA("Highlight") and d.Enabled then
			highlights += 1
		elseif d:IsA("Beam") and d.Enabled then
			beams += 1
		elseif d:IsA("Trail") and d.Enabled then
			trails += 1
		end
	end
	for _, d in ipairs(player.PlayerGui:GetDescendants()) do
		if d:IsA("Highlight") and d.Enabled then
			highlights += 1
		end
	end
	local line = ("%s;fps=%.1f;p95ms=%.1f;bossAnimUs=%.0f;hbMs=%s;renderCpuMs=%s;gpuMs=%s;parts=%d;trisEst=%d;meshParts~=%d;emitters=%d;rate=%.0f;highlights=%d;beams=%d;trails=%d;memMb=%.0f"):format(
		r.name, fpsAvg, p95 * 1000, animUs, tostring(statOf("HeartbeatTimeMs") and ("%.2f"):format(statOf("HeartbeatTimeMs")) or "-"),
		tostring(statOf("RenderCPUFrameTime") or "-"), tostring(statOf("RenderGPUFrameTime") or "-"), parts, tris, meshTris / 500, emitters, emitRate, highlights, beams, trails, Stats:GetTotalMemoryUsageMb())
	print("[ArenaPerf] " .. line)
	player:SetAttribute("PerfProbeResult", line)
end

local function stepPerf(dt)
	local r = perfRun
	if not r then
		return
	end
	table.insert(r.dts, dt)
	table.insert(r.anim, player:GetAttribute("BossAnimCostUs") or 0)
	if os.clock() > r.untilT then
		perfRun = nil
		finishPerf(r)
	end
end

-- ─────────────────────────── 가짜 참가자 ───────────────────────────
local fakes = {}
local function setFakeParty(n)
	for _, f in ipairs(fakes) do
		f:Destroy()
	end
	fakes = {}
	local char = player.Character
	local boss = nearestBoss()
	if not char or n <= 0 then
		return
	end
	char.Archivable = true
	local center = boss and boss:FindFirstChild("HumanoidRootPart") and boss.HumanoidRootPart.Position or char:GetPivot().Position
	local ground = char:GetPivot().Position.Y
	for i = 1, n do
		local ok, clone = pcall(function()
			return char:Clone()
		end)
		if ok and clone then
			clone.Name = "FakeMember" .. i
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = d.Name == "HumanoidRootPart"
					d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				elseif d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			local a = (i / n) * math.pi * 2
			local pos = Vector3.new(center.X + math.cos(a) * 16, ground, center.Z + math.sin(a) * 16)
			clone:PivotTo(CFrame.lookAt(pos, Vector3.new(center.X, ground, center.Z)))
			clone.Parent = Workspace
			table.insert(fakes, clone)
		end
	end
	print(("[ArenaPerf] 가짜 참가자 %d"):format(#fakes))
end

player:GetAttributeChangedSignal("MotionProbeStart"):Connect(function()
	local v = player:GetAttribute("MotionProbeStart")
	if type(v) == "string" and v ~= "" then
		startMotion(v)
	end
end)
player:GetAttributeChangedSignal("PerfProbeStart"):Connect(function()
	local v = player:GetAttribute("PerfProbeStart")
	if type(v) == "string" and v ~= "" then
		startPerf(v)
	end
end)
player:GetAttributeChangedSignal("FakeParty"):Connect(function()
	setFakeParty(tonumber(player:GetAttribute("FakeParty")) or 0)
end)

RunService:BindToRenderStep("A2M1Probe", Enum.RenderPriority.Last.Value + 5, function(dt)
	stepMotion(dt)
	stepPerf(dt)
end)
