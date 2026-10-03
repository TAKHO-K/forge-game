-- QUEUE-ALL9C 2-4 직업 변신 연출(이 클라만 - 판정 · 저장 무관). 값 = shared/data/ClassTransformData · 직업별 한 박자 = ClassData.cards[].transform.
--   ClassTransform.play(classId): 직업 선택 창에서 고른 직업으로 서버가 ClassId를 바꾼 뒤 부른다(ClassSelectUI).
--   연기 펑 → 방어구 v3 조각이 날아와 붙음(ArmorWearView가 입힌 조각을 잠깐 떼어 날려 보냄 · 없는 부위는 그 직업 기본 모양을 연출 동안만) →
--   무기 사본이 떨어져 손에 받힘(진짜 무기는 잠깐 숨김) → 한 박자(heavy 휘청 · juggle 저글링 · apple 사과에 화살 · flowers 지팡이 꽃) → 포즈(작은 점프 + 반짝).
--   누르면(클릭 · 터치 · 키) 즉시 완성 상태. 단순 버전(체형 극단 · 레이어드 옷 · 큰 액세서리 · 연출 끔) = 연기 펑 → 포즈.
--   끝(건너뛰기 포함)에는 항상: 조각 용접 복구 · 무기 다시 보임 · 미리보기 조각 정리 · 캐릭터 고정 풀기 · 카메라 원래대로.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Data = require(ReplicatedStorage.Shared.data.ClassTransformData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)
local Text = require(ReplicatedStorage.Shared.Text)
local SoundSheet = require(script.Parent.SoundSheet)
local WeaponVisual = require(script.Parent.WeaponVisual)

local player = Players.LocalPlayer
local ClassTransform = {}
local playing = false
local ARMOR_PARTS = { "armor", "gloves", "shoes" }

local function rand(range)
	return range[1] + math.random() * (range[2] - range[1])
end

local function sound(key)
	pcall(SoundSheet.play, Data.sounds[key])
end

-- 단순 버전 판정: 체형 배율이 범위 밖 · 레이어드 옷(WrapLayer) · 손잡이가 큰 액세서리
function ClassTransform.isSimple(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return true
	end
	for _, name in ipairs({ "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }) do
		local v = humanoid:FindFirstChild(name)
		if v and v:IsA("NumberValue") and (v.Value < Data.simple.minScale or v.Value > Data.simple.maxScale) then
			return true, "scale"
		end
	end
	if character:FindFirstChildWhichIsA("WrapLayer", true) then
		return true, "layered"
	end
	for _, acc in ipairs(character:GetChildren()) do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") and math.max(handle.Size.X, handle.Size.Y, handle.Size.Z) > Data.simple.accessoryMaxStuds then
			return true, "accessory"
		end
	end
	return false
end

-- 내 캐릭터에 붙은 방어구 조각(ArmorWearView - workspace.ArmorWear · 용접 Part0 = 내 몸 파트)
local function myArmorPieces(character)
	local out = {}
	local folder = workspace:FindFirstChild("ArmorWear")
	for _, p in ipairs(folder and folder:GetChildren() or {}) do
		local weld = p:FindFirstChildOfClass("WeldConstraint")
		if weld and weld.Part0 and weld.Part0:IsDescendantOf(character) then
			table.insert(out, { part = p, weld = weld, body = weld.Part0 })
		end
	end
	return out
end

local function puff(fx, position, color, size, seconds, velocity)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.one * size * 0.4
	p.Position = position
	p.Transparency = 0.15
	p.Parent = fx
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad), {
		Size = Vector3.one * size,
		Position = position + (velocity or Vector3.zero),
		Transparency = 1,
	}):Play()
	return p
end

local function smoke(fx, center)
	local S = Data.smoke
	for i = 1, S.puffs do
		local a = (i / S.puffs) * math.pi * 2
		local off = Vector3.new(math.cos(a) * 1.4, (i % 3) * 0.8 - 0.6, math.sin(a) * 1.4)
		puff(fx, center + off, S.color, rand(S.size), S.seconds, off * 0.8 + Vector3.new(0, 1, 0))
	end
end

local function sparkle(fx, center, count)
	local S = Data.sparkle
	for i = 1, count or S.count do
		local a = (i / (count or S.count)) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0.6 + (i % 2) * 0.5, math.sin(a))
		local p = puff(fx, center, S.color, S.size, S.seconds, dir * 2.2)
		p.Material = Enum.Material.Neon
	end
end

-- 진짜 무기를 숨기고 같은 모양의 고정 사본을 돌려준다(사본 = 지금 자리 그대로 · 나중에 움직인다)
local function weaponCopy(fx)
	local folder = WeaponVisual.getLocalWeaponFolder()
	if not folder then
		return nil
	end
	local copy = { parts = {}, hidden = {} }
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(copy.hidden, d)
			local c = d:Clone()
			for _, k in ipairs(c:GetChildren()) do
				if k:IsA("JointInstance") or k:IsA("Constraint") or k:IsA("WeldConstraint") or k:IsA("Trail") or k:IsA("Attachment") then
					k:Destroy()
				end
			end
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
			c.Parent = fx
			table.insert(copy.parts, { part = c, final = d })
			d.LocalTransparencyModifier = 1
		end
	end
	return copy
end

local function showWeapon(copy)
	if not copy then
		return
	end
	for _, d in ipairs(copy.hidden) do
		if d.Parent then
			d.LocalTransparencyModifier = 0
		end
	end
	for _, c in ipairs(copy.parts) do
		c.part:Destroy()
	end
end

-- 사본 묶음을 (진짜 무기 지금 자리 + offset)에 놓는다 · spin = 묶음 가운데 기준 회전(칼날 · 손잡이가 따로 돌지 않게)
local function placeWeapon(copy, offset, spin)
	local sum, n = Vector3.zero, 0
	for _, c in ipairs(copy.parts) do
		if c.final.Parent then
			sum += c.final.Position
			n += 1
		end
	end
	if n == 0 then
		return
	end
	local center = sum / n
	local around = CFrame.new(center + offset) * CFrame.Angles(0, spin, 0) * CFrame.new(-center)
	for _, c in ipairs(copy.parts) do
		if c.final.Parent then
			c.part.CFrame = around * c.final.CFrame
		end
	end
end

-- ── 직업별 한 박자 ─────────────────────────────────────────────
local BEATS = {}

BEATS.heavy = function(ctx) -- 검사: 너무 무거워 휘청(좌우로 기우뚱 + 발밑 먼지)
	sound("heavy")
	local P = Data.props
	for i = 1, 5 do
		puff(ctx.fx, ctx.base.Position - Vector3.new(0, 2.6, 0) + Vector3.new((i - 3) * 0.7, 0, 0), P.dustColor, 1.4, 0.5, Vector3.new((i - 3) * 0.6, 0.6, 0))
	end
	local tilts = { 0.22, -0.16, 0.1, -0.05, 0 }
	local step = Data.seconds.beat / #tilts
	for _, z in ipairs(tilts) do
		ctx.tween(ctx.hrp, step, { CFrame = ctx.base * CFrame.new(0, -math.abs(z) * 1.2, 0) * CFrame.Angles(0, 0, z) })
		if ctx.wait(step) then
			return
		end
	end
end

BEATS.juggle = function(ctx) -- 도적: 단검 두 자루를 머리 위로 저글링하다 잡음
	local P = Data.props
	local daggers = {}
	for i = 1, 2 do
		local d = Instance.new("Part")
		d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		d.Size = Vector3.new(0.25, 1.6, 0.12)
		d.Color = P.daggerColor
		d.Material = Enum.Material.Metal
		d.Parent = ctx.fx
		daggers[i] = d
	end
	local copy = ctx.getWeapon()
	local saved = {}
	for _, c in ipairs(copy and copy.parts or {}) do
		saved[c.part] = c.part.Transparency
		c.part.Transparency = 1 -- 저글링 동안 손의 무기는 숨김(공중 단검 둘이 대신)
	end
	local t0 = os.clock()
	local loops = 2
	sound("juggle")
	while os.clock() - t0 < Data.seconds.beat do
		local t = (os.clock() - t0) / Data.seconds.beat
		for i, d in ipairs(daggers) do
			local a = t * loops * math.pi * 2 + (i - 1) * math.pi
			local head = ctx.base.Position + Vector3.new(0, 2.2, 0)
			d.CFrame = CFrame.new(head + ctx.base.RightVector * math.cos(a) * 1.1 + Vector3.new(0, P.juggleHeight * math.abs(math.sin(a)), 0)) * CFrame.Angles(0, 0, a * 2)
		end
		if ctx.wait(0) then
			break
		end
	end
	for _, d in ipairs(daggers) do
		d:Destroy()
	end
	for part, t in pairs(saved) do
		part.Transparency = t
	end
	sound("catch")
end

BEATS.apple = function(ctx) -- 궁수: 머리 위 사과에 화살이 톡 꽂힘(몸에는 아무것도 안 닿음)
	local P = Data.props
	local head = ctx.character:FindFirstChild("Head")
	local top = (head and head.Position or ctx.base.Position + Vector3.new(0, 2, 0)) + Vector3.new(0, (head and head.Size.Y / 2 or 0.6) + 0.45, 0)
	local apple = Instance.new("Part")
	apple.Shape = Enum.PartType.Ball
	apple.Anchored, apple.CanCollide, apple.CanQuery, apple.CanTouch = true, false, false, false
	apple.Size = Vector3.one * 0.9
	apple.Color = P.appleColor
	apple.Position = top
	apple.Parent = ctx.fx
	local leaf = Instance.new("Part")
	leaf.Anchored, leaf.CanCollide, leaf.CanQuery, leaf.CanTouch = true, false, false, false
	leaf.Size = Vector3.new(0.35, 0.08, 0.2)
	leaf.Color = P.leafColor
	leaf.CFrame = CFrame.new(top + Vector3.new(0.12, 0.5, 0)) * CFrame.Angles(0, 0, 0.5)
	leaf.Parent = ctx.fx
	if ctx.wait(0.2) then
		return
	end
	local arrow = Instance.new("Part")
	arrow.Anchored, arrow.CanCollide, arrow.CanQuery, arrow.CanTouch = true, false, false, false
	arrow.Size = Vector3.new(0.1, 0.1, 2.2)
	arrow.Color = P.arrowColor
	local from = top + ctx.base.RightVector * P.arrowFrom + Vector3.new(0, 1.5, 0)
	local stuck = top + ctx.base.RightVector * 1.25
	arrow.CFrame = CFrame.lookAt(from, stuck)
	arrow.Parent = ctx.fx
	ctx.tween(arrow, 0.3, { CFrame = CFrame.lookAt(stuck, stuck - (from - stuck).Unit) }, Enum.EasingStyle.Linear)
	if ctx.wait(0.3) then
		return
	end
	sound("apple")
	ctx.tween(apple, 0.12, { Position = top + Vector3.new(0, 0.15, 0) })
	ctx.tween(ctx.hrp, 0.2, { CFrame = ctx.base * CFrame.new(0, 0.6, 0) })
	if ctx.wait(0.2) then
		return
	end
	ctx.tween(ctx.hrp, 0.2, { CFrame = ctx.base })
	ctx.wait(Data.seconds.beat - 0.7)
end

BEATS.flowers = function(ctx) -- 치유사: 지팡이 끝에서 꽃이 펑
	local P = Data.props
	local tip = ctx.base.Position + Vector3.new(0, 2.5, 0)
	local folder = WeaponVisual.getLocalWeaponFolder()
	if folder then
		local best = -math.huge
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") and d.Position.Y > best then
				best, tip = d.Position.Y, d.Position
			end
		end
	end
	sound("flowers")
	for i = 1, P.flowers do
		local a = (i / P.flowers) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0.8, math.sin(a))
		local f = puff(ctx.fx, tip, P.flowerColors[(i - 1) % #P.flowerColors + 1], 0.9, Data.seconds.beat, dir * 2.5)
		f.Transparency = 0
	end
	ctx.wait(Data.seconds.beat)
end

-- ── 본편 ──────────────────────────────────────────────────────
function ClassTransform.play(classId)
	if not Data.enabled or playing then -- 사용자 10-03: 아바타 변신 끔(ClassTransformData.enabled) - 직업 선택 무대가 대신
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	playing = true
	local card = ClassData.cards and ClassData.cards[classId]
	local fx = Instance.new("Folder")
	fx.Name = "ClassTransformFx"
	fx.Parent = workspace
	local skipped = false
	local inputConn = UserInputService.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.Gamepad1 then
			skipped = true
		end
	end)
	local tweens = {}
	local ctx = { fx = fx, character = character, hrp = hrp, base = hrp.CFrame }
	function ctx.wait(seconds)
		local untilT = os.clock() + seconds
		repeat
			RunService.Heartbeat:Wait()
		until skipped or os.clock() >= untilT
		return skipped
	end
	function ctx.tween(inst, seconds, goal, style)
		local tw = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		table.insert(tweens, tw)
		tw:Play()
		return tw
	end

	-- 고정 · 카메라 · 건너뛰기 안내
	local wasAnchored = hrp.Anchored
	hrp.Anchored = true
	local camera = workspace.CurrentCamera
	local prevType, prevFov = camera.CameraType, camera.FieldOfView
	local C = Data.camera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = C.fov
	local look = Vector3.new(ctx.base.LookVector.X, 0, ctx.base.LookVector.Z)
	look = look.Magnitude > 0 and look.Unit or Vector3.new(0, 0, -1)
	camera.CFrame = CFrame.lookAt(ctx.base.Position + look * C.distance + Vector3.new(0, C.height, 0), ctx.base.Position + Vector3.new(0, C.lookHeight, 0))
	local hintGui = Instance.new("ScreenGui")
	hintGui.Name = "ClassTransformHint"
	hintGui.DisplayOrder = 400
	hintGui.ResetOnSpawn = false
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -24)
	hint.Size = UDim2.new(1, -32, 0, 24)
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 16
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextStrokeTransparency = 0.4
	hint.Text = Text.get("class.transform.skip")
	hint.Parent = hintGui
	hintGui.Parent = player:WaitForChild("PlayerGui")

	local simple = ClassTransform.isSimple(character)
	simple = simple or player:GetAttribute("FxLevel") == "off"

	-- 미리보기 방어구(입은 게 없는 부위)
	local preview = {}
	if not simple then
		for _, part in ipairs(ARMOR_PARTS) do
			local attr = ArtImportData.armorLookAttribute .. part
			if player:GetAttribute(attr) == nil then
				player:SetAttribute(attr, Data.previewLook)
				table.insert(preview, attr)
			end
		end
	end

	local armor = {}
	local weapon = nil
	function ctx.getWeapon()
		return weapon
	end
	local ok, err = pcall(function()
		-- 1 연기 펑
		smoke(fx, ctx.base.Position)
		sound("smoke")
		if ctx.wait(Data.seconds.smoke) or simple then
			return
		end
		-- 2 방어구 조각이 날아와 붙음(ArmorWearView가 직업 모양을 입힐 때까지 잠깐 기다림)
		local waitUntil = os.clock() + 1
		repeat
			armor = myArmorPieces(character)
			RunService.Heartbeat:Wait()
		until #armor > 0 and #myArmorPieces(character) == #armor or os.clock() > waitUntil
		armor = myArmorPieces(character)
		for i, a in ipairs(armor) do
			a.rel = a.body.CFrame:ToObjectSpace(a.part.CFrame)
			a.weld.Enabled = false
			a.part.Anchored = true
			local ang = (i / math.max(1, #armor)) * math.pi * 2
			local away = Vector3.new(math.cos(ang), 0, math.sin(ang)) * rand(Data.armorFly.distance) + Vector3.new(0, Data.armorFly.up, 0)
			a.part.CFrame = a.body.CFrame * a.rel + away
			a.part.LocalTransparencyModifier = 1
		end
		for i, a in ipairs(armor) do
			task.delay((i - 1) * Data.armorStagger, function()
				if skipped or not a.part.Parent then
					return
				end
				a.part.LocalTransparencyModifier = 0
				ctx.tween(a.part, Data.seconds.armor - (i - 1) * Data.armorStagger * 0.5, { CFrame = a.body.CFrame * a.rel }, Enum.EasingStyle.Back)
			end)
		end
		if #armor > 0 then
			task.delay(Data.seconds.armor * 0.8, function()
				if not skipped then
					sound("clank")
				end
			end)
		end
		if ctx.wait(Data.seconds.armor) then
			return
		end
		-- 3 무기가 떨어져 손에 받힘
		weapon = weaponCopy(fx)
		if weapon then
			local t0 = os.clock()
			local up = Data.weaponDropHeight
			while os.clock() - t0 < Data.seconds.weapon do
				local t = (os.clock() - t0) / Data.seconds.weapon
				placeWeapon(weapon, Vector3.new(0, up * (1 - t * t), 0), (1 - t) * math.pi * 3)
				if ctx.wait(0) then
					return
				end
			end
			placeWeapon(weapon, Vector3.zero, 0)
			sound("catch")
		end
		-- 4 직업별 한 박자
		local beat = card and BEATS[card.transform]
		if beat then
			beat(ctx)
			if skipped then
				return
			end
		end
	end)
	if not ok then
		warn("[CLASS] 변신 연출 오류(완성 상태로): " .. tostring(err))
	end

	-- 5 포즈(건너뛰면 바로 완성 상태)
	for _, tw in ipairs(tweens) do
		tw:Cancel()
	end
	for _, a in ipairs(armor) do
		if a.part.Parent and a.body.Parent and a.rel then
			a.part.CFrame = a.body.CFrame * a.rel
			a.part.LocalTransparencyModifier = 0
			a.part.Anchored = false
			a.weld.Enabled = true
		end
	end
	if weapon then
		showWeapon(weapon)
	end
	hrp.CFrame = ctx.base
	if not skipped then
		sound("pose")
		sparkle(fx, ctx.base.Position + Vector3.new(0, 1, 0))
		local jump = TweenService:Create(hrp, TweenInfo.new(Data.seconds.pose / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { CFrame = ctx.base * CFrame.new(0, 1, 0) })
		jump:Play()
		ctx.wait(Data.seconds.pose)
		jump:Cancel()
		hrp.CFrame = ctx.base
	end
	-- 미리보기 방어구 = 서서히 사라짐 → 원래(없음)
	if #preview > 0 then
		local fade = {}
		for _, a in ipairs(myArmorPieces(character)) do
			local partOf = Data.bodyPart[a.body.Name] or "armor" -- 이 조각이 붙은 몸 파트 → 부위
			if table.find(preview, ArtImportData.armorLookAttribute .. partOf) then
				table.insert(fade, a.part) -- 미리보기 부위만(진짜 입은 부위는 그대로)
			end
		end
		if not skipped then
			for _, p in ipairs(fade) do
				TweenService:Create(p, TweenInfo.new(Data.previewFadeSeconds), { Transparency = 1 }):Play()
			end
			task.wait(Data.previewFadeSeconds)
		end
		for _, attr in ipairs(preview) do
			player:SetAttribute(attr, nil)
		end
	end
	inputConn:Disconnect()
	hintGui:Destroy()
	task.delay(1, function()
		fx:Destroy()
	end)
	hrp.Anchored = wasAnchored
	camera.CameraType = prevType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or prevType
	camera.FieldOfView = prevFov
	playing = false
end

function ClassTransform.isPlaying()
	return playing
end

return ClassTransform
