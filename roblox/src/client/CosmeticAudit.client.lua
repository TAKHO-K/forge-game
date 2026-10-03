-- QUEUE-ALL9C 1-6R 치장 외형 감사 촬영(Studio 전용 - 구현 변경 없음 · 지금 모습 기록): Player Attribute DebugCosAudit = "all" | "<id>[,<id>…]"
--   치장마다 장면을 돌리며 화면 왼쪽 위에 "<id> · <장면> · t=+초"(연출 시작 뒤 시간)를 띄우고 출력 줄 "[COSAUDIT] SHOT <id> <장면>"을 찍는다
--   → 스크래치패드 PowerShell 감시가 그 줄을 보고 창을 찍어 docs/art/cosmetics-audit/<id>/<장면>.jpg로 저장(캡처 지연 L초를 앞당겨 신호 - 사진 속 t가 실제 시각).
--   장면: 물건형(글라이더 · 무기 · 펫 · 이름표) = 정지 3각도 a1 ~ a3 + 동작 m1 ~ m3(시작 · 중간 · 끝) / 연출형(처치 · 강화 · 귀환 · 이모트) = 한가운데 3각도 + 시작 · 중간 · 끝 /
--   테마 세트 = 대시 한가운데 3각도 + 칸마다(대시 · 점프 · 활강 · 발자국) 시작 · 중간 · 끝. 장착 = 내 Attribute를 로컬에서만 바꾼다(상점 [직접 보기]와 같은 길 · 서버 값 그대로 · 끝나면 되돌림).
--   구성 세기: 장면마다 새로 생긴 인스턴스(workspace · 내 캐릭터 · SoundService) 종류별 수를 "[COSAUDIT] COUNT"로 남긴다(README 표의 원자료).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

if not RunService:IsStudio() then
	return
end

local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local player = Players.LocalPlayer

local LAG = 0.05 -- 신호 → 실제 캡처(첫 시험 실측 약 0.04초 - 사진 속 t로 확인)
local SHOT_GAP = 1.6 -- 신호 뒤 다음 장면까지(캡처 · 저장 시간)
local ANGLES = { a1 = 35, a2 = 110, a3 = 215 }

local running = 0
local label, gui
local t0 -- 연출 시작 시각(라벨 t 기준)
local camCf -- 고정 카메라

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "CosAuditGui"
	gui.DisplayOrder = 300
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.35
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Position = UDim2.fromOffset(300, 64) -- 로블록스 위 단추 줄 아래 · 오른쪽
	label.Size = UDim2.fromOffset(620, 30)
	label.Parent = gui
end

local caption = ""
RunService:BindToRenderStep("CosAuditCam", Enum.RenderPriority.Last.Value + 1, function()
	if running == 0 then
		return
	end
	local cam = workspace.CurrentCamera
	if camCf then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = camCf
	end
	if label then
		label.Text = t0 and ("%s · t=+%.2fs"):format(caption, os.clock() - t0) or caption
	end
end)

-- 치장 id → { kind, entry, slots }
local function resolve(id)
	for _, s in ipairs(CosmeticSlotData.sets) do
		if s.id == id then
			local slots = {}
			for _, slot in ipairs(CosmeticSlotData.setSlots) do
				if s.looks and s.looks[slot] ~= "" then
					table.insert(slots, slot)
				end
			end
			return { kind = "theme", entry = s, slots = slots }
		end
	end
	for _, g in ipairs(CosmeticSlotData.gliderSkins) do
		if g.id == id then
			return { kind = "glider", entry = g, slots = { "gliderSkin" } }
		end
	end
	for _, it in ipairs(CosmeticSlotData.items) do
		if it.id == id then
			return { kind = it.slot, entry = it, slots = { it.slot } }
		end
	end
	if id == "nameplateColor" or id == "nameplateBadge" then
		return { kind = id, entry = { id = id, name = id }, slots = {} }
	end
	return nil
end

local function allIds()
	local ids = {}
	for _, s in ipairs(CosmeticSlotData.sets) do
		table.insert(ids, s.id)
	end
	for _, g in ipairs(CosmeticSlotData.gliderSkins) do
		table.insert(ids, g.id)
	end
	for _, it in ipairs(CosmeticSlotData.items) do
		table.insert(ids, it.id)
	end
	table.insert(ids, "nameplateColor")
	table.insert(ids, "nameplateBadge")
	return ids
end

local ALL_SLOTS = {}
for _, s in ipairs(CosmeticSlotData.slots) do
	table.insert(ALL_SLOTS, s.id)
end

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid"), c
end

local function setCamera(angleDeg, focus, dist, height)
	local r = math.rad(angleDeg)
	camCf = CFrame.lookAt(focus + Vector3.new(math.sin(r) * dist, height, math.cos(r) * dist), focus)
end

-- 구성 세기(장면 동안 새로 생긴 것)
local counting
local function countStart()
	counting = { mesh = 0, part = 0, particle = 0, beam = 0, trail = 0, sound = 0, light = 0 }
	local conns = {}
	local function add(d)
		if d:IsA("MeshPart") or d:IsA("SpecialMesh") then
			counting.mesh += 1
		elseif d:IsA("BasePart") then
			counting.part += 1
		elseif d:IsA("ParticleEmitter") then
			counting.particle += 1
		elseif d:IsA("Beam") then
			counting.beam += 1
		elseif d:IsA("Trail") then
			counting.trail += 1
		elseif d:IsA("Sound") then
			counting.sound += 1
		elseif d:IsA("Light") then
			counting.light += 1
		end
	end
	table.insert(conns, workspace.DescendantAdded:Connect(add))
	table.insert(conns, SoundService.DescendantAdded:Connect(add))
	return function()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		local out = counting
		counting = nil
		return out
	end
end
-- 지금 켜진 트레일 · 빔 · 입자(캐릭터에 미리 달린 것 - 대시 · 활강 트레일)
local function enabledOn(model)
	local n = { trail = 0, beam = 0, particle = 0 }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Trail") and d.Enabled then
			n.trail += 1
		elseif d:IsA("Beam") and d.Enabled then
			n.beam += 1
		elseif d:IsA("ParticleEmitter") and d.Enabled then
			n.particle += 1
		end
	end
	return n
end

local fire = setmetatable({}, { __index = function(_, k) -- 서버 DevTools 끝에서 만든다 - 부를 때 찾는다
	local remote = ReplicatedStorage:WaitForChild("CosAuditFire", 10)
	return function(_, ...)
		return remote and remote[k](remote, ...)
	end
end })

-- 동작 하나 시작 → 길이(초) 반환. start = 이 장면의 시작 자리(카메라 기준)
local glideOn = false
local function stopGlide()
	local _, _, c = root()
	if glideOn and c then
		c:SetAttribute("Gliding", nil)
		pcall(function()
			require(script.Parent.GlideView).hide(c)
		end)
	end
	glideOn = false
end
local function moveRoot(hrp, delta, seconds)
	local from = hrp.CFrame
	local start = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = math.min(1, (os.clock() - start) / seconds)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = from + delta * a
		if a >= 1 then
			conn:Disconnect()
		end
	end)
end
local ACTIONS = {
	dashTrail = function(hrp)
		moveRoot(hrp, hrp.CFrame.LookVector * 18, 0.3) -- 60 stud/s(대시 감지 50 이상)
		return 0.7
	end,
	jumpFx = function(hrp)
		hrp.AssemblyLinearVelocity = Vector3.new(0, 52, 0)
		return 0.9
	end,
	glideTrail = function(hrp, _, c)
		c:SetAttribute("Gliding", true)
		glideOn = true
		hrp.Anchored = true
		moveRoot(hrp, hrp.CFrame.LookVector * 16 + Vector3.new(0, -2, 0), 1.6)
		task.delay(1.7, function()
			hrp.Anchored = false
			stopGlide()
		end)
		return 1.6
	end,
	footstep = function(hrp, hum) -- 기본 ControlModule이 매 프레임 Move를 덮는다 → MoveTo(걷기 그대로)
		hum:MoveTo(hrp.Position + hrp.CFrame.LookVector * 30)
		return 2.2
	end,
	killFx = function(_, _, _, id)
		fire:FireServer("kill:" .. id)
		return 1.4
	end,
	weaponSkin = function()
		require(script.Parent.WeaponVisual).playSwing(false, false, nil)
		return 0.6
	end,
	enhanceFx = function()
		fire:FireServer("enhance")
		return 1.0
	end,
	recallFx = function()
		player:SetAttribute("RecallCastUntil", workspace:GetServerTimeNow() + 2)
		task.delay(2, function()
			player:SetAttribute("RecallCastUntil", nil)
		end)
		return 2.6
	end,
	emote = function()
		fire:FireServer("emote")
		return 1.0
	end,
	petAccessory = function(hrp, hum)
		hum:MoveTo(hrp.Position + hrp.CFrame.LookVector * 22)
		return 1.6
	end,
}
ACTIONS.gliderSkin = function(hrp, hum, c)
	local GlideView = require(script.Parent.GlideView)
	local untilAt = os.clock() + 1.7
	local conn
	conn = RunService.Heartbeat:Connect(function() -- 내 글라이더는 GlideController가 활강 상태가 아니면 걷는다 → 동작 동안 다시 붙인다
		if os.clock() > untilAt then
			conn:Disconnect()
			return
		end
		if not c:FindFirstChild("MV1Glider") then
			pcall(GlideView.show, c)
		end
	end)
	return ACTIONS.glideTrail(hrp, hum, c)
end

local function shot(id, name)
	print(("[COSAUDIT] SHOT %s %s"):format(id, name))
	task.wait(SHOT_GAP)
end

-- 장면 = 동작 slotAction을 새로 걸고 at(0 ~ 1 비율) 순간을 찍는다
local function actionShot(info, id, slotAction, name, at, angle)
	local hrp, hum, c = root()
	if not hrp then
		return
	end
	hrp.Anchored = false
	hum:MoveTo(hrp.Position) -- 앞 장면 걷기 멈춤
	local base = hrp.CFrame
	local focusOffset = (slotAction == "dashTrail" or slotAction == "glideTrail" or slotAction == "gliderSkin" or slotAction == "footstep" or slotAction == "petAccessory") and base.LookVector * 8
		or slotAction == "killFx" and base.LookVector * 9 + Vector3.new(0, 3, 0) -- 감사 더미 자리(서버 CosAuditFire = 앞 9) · 로켓은 위로
		or Vector3.zero
	local dist = (slotAction == "killFx") and 18 or (slotAction == "glideTrail" or slotAction == "gliderSkin") and 16 or 12
	setCamera(angle, base.Position + focusOffset + Vector3.new(0, 1, 0), dist, 5)
	caption = ("%s · %s · %s"):format(id, slotAction, name)
	task.wait(0.3)
	local stop = countStart()
	local duration -- 동작 길이(비율 at의 기준)
	local want
	local before = enabledOn(c)
	t0 = os.clock()
	duration = ACTIONS[slotAction](hrp, hum, c, id)
	want = duration * at
	if want > LAG then
		task.wait(want - LAG)
		print(("[COSAUDIT] SHOT %s %s"):format(id, name))
		task.wait(LAG)
	else
		print(("[COSAUDIT] SHOT %s %s"):format(id, name))
		task.wait(LAG)
	end
	local live = enabledOn(c)
	task.wait(math.max(0, duration - want) + 0.3)
	local n = stop()
	print(("[COSAUDIT] COUNT %s %s %s mesh=%d part=%d particle=%d beam=%d trail=%d sound=%d light=%d onTrail=%d onBeam=%d onParticle=%d"):format(id, name, slotAction,
		n.mesh, n.part, n.particle, n.beam, n.trail, n.sound, n.light, live.trail - before.trail, live.beam - before.beam, live.particle - before.particle))
	t0 = nil
	stopGlide()
	-- 제자리로(다음 장면 같은 배경)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = base
	task.wait(math.max(0.2, SHOT_GAP - LAG - 0.3))
	return info
end

local function staticShots(info, id, prep)
	local hrp, _, c = root()
	if not hrp then
		return
	end
	hrp.Anchored = true
	prep(c)
	task.wait(0.8)
	for _, name in ipairs({ "a1", "a2", "a3" }) do
		local focus = hrp.Position + Vector3.new(0, (info.kind == "nameplateColor" or info.kind == "nameplateBadge") and 2 or 0.5, 0)
		local dist = (info.kind == "glider") and 11 or (info.kind == "petAccessory") and 9 or 7
		setCamera(ANGLES[name], focus, dist, 2.5)
		caption = ("%s · 정지 · %s"):format(id, name)
		task.wait(0.4)
		shot(id, name)
	end
	hrp.Anchored = false
end

local saved = {}
local function equip(info)
	for _, slot in ipairs(ALL_SLOTS) do
		if saved[slot] == nil then
			saved[slot] = { v = player:GetAttribute("Cosmetic_" .. slot) }
		end
		player:SetAttribute("Cosmetic_" .. slot, nil)
	end
	for _, slot in ipairs(info.slots) do
		player:SetAttribute("Cosmetic_" .. slot, info.entry.id)
	end
	if info.kind == "petAccessory" and player:GetAttribute("PetBody") == nil then -- 펫 없는 계정 = 감사 동안만 로컬 펫(개 · 희귀)
		saved.PetBody = { v = nil, attr = true }
		player:SetAttribute("PetBody", "dog")
		player:SetAttribute("PetZone", "tier1")
		player:SetAttribute("PetGrade", "rare")
	end
end
local function restore()
	for slot, v in pairs(saved) do
		if v.attr then
			for _, attr in ipairs({ "PetBody", "PetZone", "PetGrade" }) do
				player:SetAttribute(attr, nil)
			end
		else
			player:SetAttribute("Cosmetic_" .. slot, v.v)
		end
	end
	saved = {}
	player:SetAttribute("NameplateColor", nil)
	player:SetAttribute("NameplateBadge", nil)
end

local function auditOne(id)
	local info = resolve(id)
	if not info then
		print("[COSAUDIT] SKIP " .. tostring(id))
		return
	end
	equip(info)
	task.wait(0.6)
	local k = info.kind
	print(("[COSAUDIT] BEGIN %s kind=%s slots=%s"):format(id, k, table.concat(info.slots, "+")))
	if k == "theme" then
		local first = info.slots[1] or "dashTrail"
		for _, name in ipairs({ "a1", "a2", "a3" }) do -- 대표 칸 한가운데 3각도
			actionShot(info, id, first, name, 0.45, ANGLES[name])
		end
		for _, slot in ipairs(info.slots) do -- 칸마다 시작 · 중간 · 끝
			for i, at in ipairs({ 0.08, 0.45, 0.9 }) do
				actionShot(info, id, slot, ("%s_m%d"):format(slot, i), at, 35)
			end
		end
	elseif k == "glider" or k == "weaponSkin" or k == "petAccessory" then
		staticShots(info, id, function(c)
			if k == "glider" then
				c:SetAttribute("Gliding", true)
				glideOn = true
				pcall(function()
					require(script.Parent.GlideView).show(c)
				end)
				-- 붙은 것 세기
				local n = { mesh = 0, part = 0, particle = 0, beam = 0 }
				local g = c:FindFirstChild("MV1Glider")
				for _, d in ipairs(g and g:GetDescendants() or {}) do
					if d:IsA("MeshPart") then
						n.mesh += 1
					elseif d:IsA("BasePart") then
						n.part += 1
					elseif d:IsA("ParticleEmitter") then
						n.particle += 1
					elseif d:IsA("Beam") or d:IsA("RopeConstraint") then
						n.beam += 1
					end
				end
				print(("[COSAUDIT] COUNT %s static glider mesh=%d part=%d particle=%d beamOrRope=%d"):format(id, n.mesh, n.part, n.particle, n.beam))
			end
		end)
		stopGlide()
		local action = k == "glider" and "gliderSkin" or k
		for i, at in ipairs({ 0.08, 0.45, 0.9 }) do
			actionShot(info, id, action, "m" .. i, at, 35)
		end
	elseif k == "nameplateColor" or k == "nameplateBadge" then
		staticShots(info, id, function()
			if k == "nameplateColor" then
				player:SetAttribute("NameplateColor", "gold")
			else
				player:SetAttribute("NameplateBadge", "star")
			end
		end)
	else -- 연출형: 한가운데 3각도 + 시작 · 중간 · 끝
		for _, name in ipairs({ "a1", "a2", "a3" }) do
			actionShot(info, id, k, name, 0.45, ANGLES[name])
		end
		for i, at in ipairs({ 0.08, 0.45, 0.9 }) do
			actionShot(info, id, k, "m" .. i, at, 35)
		end
	end
	print(("[COSAUDIT] END %s"):format(id))
end

player:GetAttributeChangedSignal("DebugCosAudit"):Connect(function()
	local v = player:GetAttribute("DebugCosAudit")
	if type(v) ~= "string" or v == "" then
		return
	end
	running += 1
	local mine = running
	ensureGui()
	local hidden = {}
	for _, g in ipairs(player.PlayerGui:GetChildren()) do -- 캡처 = 장면만(HUD 숨김 · 끝나면 되돌림)
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	local ids = v == "all" and allIds() or string.split(v, ",")
	print(("[COSAUDIT] START %d"):format(#ids))
	for _, id in ipairs(ids) do
		if running ~= mine then
			break
		end
		auditOne(id)
	end
	restore()
	for _, g in ipairs(hidden) do
		g.Enabled = true
	end
	camCf = nil
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	if gui then
		gui:Destroy()
		gui = nil
	end
	running = 0
	print("[COSAUDIT] DONE")
end)
