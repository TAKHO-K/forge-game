-- QUEUE-ALL3 Q8 몬스터 이름표 · 대상 확인(docs/design/v2/10-ingame-feedback-1001.md §8). 클라 연출만 - 판정 · 서버 값은 하나도 안 바꾼다.
--   가독성 예외: ArtStyleV1 스위치와 무관하게 늘 켠다(맵 색 · 밝기에 따라 이름표가 안 읽힌다는 문제라 스위치 뒤에 두면 해결이 안 된다).
--
--   · 이름표 = 반투명 어두운 알약 + 흰 굵은 글씨(외곽선) + "Lv.n 이름" + 작은 체력바. 서버가 만든 몹 머리 위 NameplateGui(MonsterSpawner)는 이 화면에서만 끈다(Enabled - 로컬 변경은 복제 안 됨).
--     서버 이름표는 그대로 "값 창구"로 읽는다: 이름 = NameLabel.Text(세대 접두사 GenerationView 포함) · 체력 = HpBarFill.Size.X · 채움 색 = HpBarFill 색(잠김 회색 MobLockView · 상자 금색) ·
--     조준 = NameLabel.Visible(AimTarget). 그래서 다른 스크립트는 안 고쳤다.
--   · 레벨 = 내 스테이지(Player Attribute InfiniteStage - C1 잡몹 세기는 보는 사람 스테이지를 따른다 · 몹 자체 레벨 값은 없다).
--   · 풀: 빌보드 MAX_SHOWN_PC(폰 MAX_SHOWN_PHONE)개를 미리 만들어 돌려 쓴다(몹마다 새로 안 만든다). 고르기 · 크기 · 투명도 갱신 = 0.1초마다(10 Hz).
--     우선순위 = 내 대상 → 조준 중 → 파티원 대상 → 반짝이 · 상자 → 가까운 순. 내 캐릭터에서 SHOW_STUDS 밖은 숨김(FADE_FROM_STUDS부터 옅어짐) · 내 대상은 TARGET_SHOW_STUDS까지.
--   · 내 대상 = 마지막으로 내 타격이 들어간 몹(AttackResult · SkillCastResult hits · StuckArrowResult) TARGET_HOLD초 유지:
--     이름표 TARGET_SCALE배 + 흰 테두리 · 발밑 얇은 흰 원(ArtAssetIds icons/ui/target_ring - 없으면 UIStroke 원) · 체력바 잔상(GHOST_DELAY 뒤 GHOST_SECONDS 동안 줄어듦).
--     원은 바닥 전조(빨강 · 채움 · 번짐)와 헷갈리지 않게 흰색 · 얇게 · Neon/발광 없음 · LightInfluence 0(밤에도 같은 흰색).
--   · 반짝이(SparkleMonster 태그) = 분홍 이름 + 마름모 아이콘 · 보물상자(TreasureChest 태그) = 금색 이름 + 상자 아이콘(색 + 모양).
--   · 파티원 대상 = 이름표 오른쪽 위 작은 점(UIColors.partyColors - 같은 PartyId를 UserId 오름차순으로 세운 자리). 출처 = 남의 공격 모션 중계(AttackMotion motionTarget · AttackShotRelay) PARTY_HOLD초.
--     스킬 타격은 남에게 중계되는 이벤트가 없어 점이 안 찍힌다(평타 · 원거리만).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Text = require(ReplicatedStorage.Shared.Text)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local TreasureChestConfig = require(ReplicatedStorage.Shared.data.TreasureChestConfig)
local WorldLabelStyle = require(ReplicatedStorage.Shared.WorldLabelStyle)
local ArtImage = require(script.Parent.ui.ArtImage)
local HudIcons = require(script.Parent.HudIcons)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 표시 상수(연출 전용 - 판정 무관)
local TICK_SECONDS = 0.1
local SHOW_STUDS = 70
local FADE_FROM_STUDS = 50
local FADE_MIN_ALPHA = 0.25
local TARGET_SHOW_STUDS = 110
local SHOWN_BONUS_STUDS = 6 -- 이미 떠 있는 이름표는 이만큼 가깝게 친다(경계에서 깜빡임 방지)
local MAX_SHOWN_PC, MAX_SHOWN_PHONE = 12, 8
local CAM_NEAR, CAM_FAR = 25, 80 -- 카메라 거리 → 크기(가까움 1 · 멂 SCALE_FAR)
local SCALE_FAR = 0.8 -- 글씨 16 × 0.8 = 12.8(실효 12 미만 금지 - COMMON §2)
local TARGET_SCALE = 1.15
local TARGET_HOLD = 3
local PARTY_HOLD = 3
local GHOST_DELAY, GHOST_SECONDS = 0.35, 0.45
local PLATE_W, PLATE_H = 176, 46
local STACK_MAX = 3 -- 겹친 이름표를 위로 올리는 최대 칸
local NAME_SIZE = 16
local PILL_COLOR, PILL_ALPHA = Color3.fromRGB(10, 12, 18), 0.62 -- 알파(1 - 투명도)
local EDGE_COLOR, EDGE_ALPHA = Color3.new(0, 0, 0), 0.55
local TARGET_EDGE_COLOR = Color3.new(1, 1, 1)
local LEVEL_HEX = "C9CFDA"
local SPARKLE_COLOR = Color3.fromRGB(255, 130, 230)
local CHEST_COLOR = TreasureChestConfig.trimColor
local GHOST_COLOR = Color3.fromRGB(255, 238, 205)
local RING_ALPHA = 0.9
local RING_MIN, RING_MAX = 3, 14 -- 발밑 원 지름(스터드) - 몸 가로 × 1.15를 이 사이로
local RING_PATH = "icons/ui/target_ring"

local function isPhone()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1000, 1000)
	return (UserInputService.TouchEnabled and math.min(vp.X, vp.Y) < 500) or (RunService:IsStudio() and player:GetAttribute("ForceTouchLayout") == true)
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0.5, 0)
	c.Parent = parent
	return c
end

local function frame(parent, name, size, pos, anchor, color, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos or UDim2.new()
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

-- 몹 기록 ------------------------------------------------------------------
local recs = {} -- [model] = { head, serverGui, name(서버 NameLabel), fill(서버 HpBarFill), rare = "sparkle" | "chest" | nil }
local skip = setmetatable({}, { __mode = "k" }) -- 대상 아님(보스 · 분신 · 구출 대상 - 바 없음)

local function tryRecord(model)
	if recs[model] or skip[model] or not model:IsA("Model") then
		return recs[model]
	end
	local head = model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("NameplateGui")
	if not gui then
		return nil -- 아직 안 들어왔다(다음 틱에 다시)
	end
	local bg = gui:FindFirstChild("HpBarBackground")
	local fill = bg and bg:FindFirstChild("HpBarFill")
	local name = gui:FindFirstChild("NameLabel")
	if not (fill and name) or model:GetAttribute("IsBoss") or model:GetAttribute("RescueKind") then
		skip[model] = true
		return nil
	end
	local rare = CollectionService:HasTag(model, "SparkleMonster") and "sparkle" or (CollectionService:HasTag(model, "TreasureChest") and "chest" or nil)
	gui.Enabled = false -- 이 화면에서만 끈다(아래 풀 이름표가 대신 그린다)
	local rec = { head = head, serverGui = gui, name = name, fill = fill, rare = rare }
	recs[model] = rec
	return rec
end

-- 이름표 풀 ------------------------------------------------------------------
local slots = {}
local slotOf = {} -- [model] = slot

local function newSlot(i)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Q8MobPlate" .. i
	gui.ResetOnSpawn = false
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Size = UDim2.fromOffset(PLATE_W, PLATE_H)
	WorldLabelStyle.setupNameplateBillboard(gui, nil)
	gui.Parent = playerGui

	local root = frame(gui, "Root", UDim2.fromOffset(PLATE_W, PLATE_H), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	root.BackgroundTransparency = 1
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local pill = frame(root, "Pill", UDim2.new(1, -16, 1, -6), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), PILL_COLOR, 1)
	corner(pill, UDim.new(0, 12))
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = pill

	local row = frame(pill, "Row", UDim2.new(1, -12, 0, 22), UDim2.new(0.5, 0, 0, 3), Vector2.new(0.5, 0), nil, 2)
	row.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row

	local fades = {} -- { inst, prop, alpha } - 거리 투명도를 한 번에 곱한다
	local function fade(inst, prop, alpha)
		table.insert(fades, { inst, prop, alpha })
	end

	-- 반짝이 = 마름모(겉 분홍 · 속 흰 점) · 상자 = 가로 네모 + 어두운 띠
	local icon = frame(row, "RareIcon", UDim2.fromOffset(14, 14), nil, nil, nil, 2)
	icon.BackgroundTransparency = 1
	icon.LayoutOrder = 1
	local diamond = frame(icon, "Sparkle", UDim2.fromOffset(10, 10), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), SPARKLE_COLOR, 3)
	diamond.Rotation = 45
	local diamondCore = frame(diamond, "Core", UDim2.fromOffset(4, 4), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), Color3.new(1, 1, 1), 4)
	local chest = frame(icon, "Chest", UDim2.fromOffset(14, 10), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), CHEST_COLOR, 3)
	corner(chest, UDim.new(0, 2))
	local band = frame(chest, "Band", UDim2.new(1, 0, 0, 2), UDim2.fromScale(0, 0.4), nil, Color3.fromRGB(70, 45, 20), 4)
	fade(diamond, "BackgroundTransparency", 1)
	fade(diamondCore, "BackgroundTransparency", 1)
	fade(chest, "BackgroundTransparency", 1)
	fade(band, "BackgroundTransparency", 1)

	local lock = frame(row, "Lock", UDim2.fromOffset(14, 14), nil, nil, nil, 2)
	lock.BackgroundTransparency = 1
	lock.LayoutOrder = 2
	local glyph = HudIcons.lock(lock, 14, UIColors.mobLockIcon)
	for _, part in ipairs(glyph:GetDescendants()) do
		if part:IsA("GuiObject") then
			part.ZIndex = 3
			fade(part, "BackgroundTransparency", 1)
		end
	end

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.RichText = true
	label.LayoutOrder = 3
	label.ZIndex = 3
	WorldLabelStyle.styleNameplateText(label, NAME_SIZE) -- GothamBold · 검은 외곽선
	label.Parent = row
	fade(label, "TextTransparency", 1)
	fade(label, "TextStrokeTransparency", 1)

	local track = frame(pill, "Track", UDim2.new(1, -26, 0, 6), UDim2.new(0.5, 0, 1, -10), Vector2.new(0.5, 0), UIColors.hpDark, 2)
	corner(track)
	local ghost = frame(track, "Ghost", UDim2.fromScale(1, 1), nil, nil, GHOST_COLOR, 3)
	corner(ghost)
	local fill = frame(track, "Fill", UDim2.fromScale(1, 1), nil, nil, UIColors.hp, 4)
	corner(fill)
	fade(track, "BackgroundTransparency", 0.95)
	fade(ghost, "BackgroundTransparency", 0.9)
	fade(fill, "BackgroundTransparency", 1)

	-- 파티원 점(최대 3 - 나 빼고) = 알약 오른쪽 위 모서리
	local dotsRow = frame(root, "PartyDots", UDim2.fromOffset(40, 10), UDim2.new(1, -4, 0, 0), Vector2.new(1, 0), nil, 5)
	dotsRow.BackgroundTransparency = 1
	local dotsList = Instance.new("UIListLayout")
	dotsList.FillDirection = Enum.FillDirection.Horizontal
	dotsList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	dotsList.Padding = UDim.new(0, 2)
	dotsList.Parent = dotsRow
	local dots = {}
	for d = 1, 3 do
		local dot = frame(dotsRow, "Dot" .. d, UDim2.fromOffset(9, 9), nil, nil, nil, 5)
		corner(dot)
		local ring = Instance.new("UIStroke")
		ring.Thickness = 1.5
		ring.Parent = dot
		dot.Visible = false
		dots[d] = dot
	end

	return {
		gui = gui, scale = scale, pill = pill, edge = edge, icon = icon, diamond = diamond, chest = chest, lock = lock, label = label,
		ghost = ghost, fill = fill, dots = dots, fades = fades, alpha = -1, scaleNow = -1, textKey = nil, targetLook = nil,
	}
end

local function applyAlpha(slot, alpha, isTarget)
	if math.abs(slot.alpha - alpha) < 0.03 and slot.targetLook == isTarget then
		return
	end
	slot.alpha = alpha
	slot.targetLook = isTarget
	for _, f in ipairs(slot.fades) do
		f[1][f[2]] = 1 - f[3] * alpha
	end
	slot.pill.BackgroundTransparency = 1 - (isTarget and 0.78 or PILL_ALPHA) * alpha
	slot.edge.Color = isTarget and TARGET_EDGE_COLOR or EDGE_COLOR
	slot.edge.Thickness = isTarget and 2 or 1
	slot.edge.Transparency = 1 - (isTarget and 1 or EDGE_ALPHA) * alpha
	for _, dot in ipairs(slot.dots) do
		dot.BackgroundTransparency = 1 - alpha
		dot:FindFirstChildOfClass("UIStroke").Transparency = 1 - 0.8 * alpha
	end
end

for i = 1, MAX_SHOWN_PC do
	slots[i] = newSlot(i)
end

-- 내 대상 · 잔상 ------------------------------------------------------------------
local target, targetAt = nil, 0

local function escape(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function syncFill(slot)
	local rec = slot.rec
	local ratio = math.clamp(rec.fill.Size.X.Scale, 0, 1)
	slot.fill.Size = UDim2.fromScale(ratio, 1)
	slot.fill.BackgroundColor3 = rec.fill.BackgroundColor3
	slot.lock.Visible = rec.fill.BackgroundColor3 == UIColors.mobLockedBar
	if slot.ghostTween then
		slot.ghostTween:Cancel()
		slot.ghostTween = nil
	end
	if slot.model == target and ratio < slot.ghost.Size.X.Scale - 0.001 then
		-- 잔상: 방금 깎인 만큼 밝은 띠가 남았다가 늦게 따라 줄어든다(내 대상만)
		slot.ghostTween = TweenService:Create(slot.ghost, TweenInfo.new(GHOST_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, GHOST_DELAY), { Size = UDim2.fromScale(ratio, 1) })
		slot.ghostTween:Play()
	else
		if ratio < slot.ghost.Size.X.Scale - 0.001 then
			slot.lastDrop = { from = slot.ghost.Size.X.Scale, at = os.clock() } -- 체력 복제가 AttackResult보다 먼저 온 첫 타격도 잔상을 남기게(setTarget이 되살린다)
		end
		slot.ghost.Size = UDim2.fromScale(ratio, 1)
	end
end

local function release(slot)
	if slot.model then
		slotOf[slot.model] = nil
	end
	for _, c in ipairs(slot.conns or {}) do
		c:Disconnect()
	end
	if slot.ghostTween then
		slot.ghostTween:Cancel()
		slot.ghostTween = nil
	end
	slot.conns, slot.model, slot.rec, slot.textKey, slot.lastDrop = nil, nil, nil, nil, nil
	slot.gui.Enabled = false
	slot.gui.Adornee = nil
end

local function assign(slot, model, rec)
	slot.model, slot.rec = model, rec
	slotOf[model] = slot
	slot.gui.Adornee = rec.head
	slot.gui.StudsOffset = rec.serverGui.StudsOffset + Vector3.new(0, 0.5, 0)
	local rareColor = rec.rare == "sparkle" and SPARKLE_COLOR or (rec.rare == "chest" and CHEST_COLOR or nil)
	slot.icon.Visible = rareColor ~= nil
	slot.diamond.Visible = rec.rare == "sparkle"
	slot.chest.Visible = rec.rare == "chest"
	slot.label.TextColor3 = rareColor or Color3.new(1, 1, 1)
	slot.ghost.Size = UDim2.fromScale(math.clamp(rec.fill.Size.X.Scale, 0, 1), 1)
	slot.conns = {
		rec.fill:GetPropertyChangedSignal("Size"):Connect(function()
			syncFill(slot)
		end),
		rec.fill:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			syncFill(slot)
		end),
	}
	syncFill(slot)
	slot.alpha = -1
	slot.gui.Enabled = true
end

-- 발밑 원(하나 - 내 대상 전용) ------------------------------------------------------------------
local ringPart = Instance.new("Part")
ringPart.Name = "Q8TargetRing"
ringPart.Anchored, ringPart.CanCollide, ringPart.CanQuery, ringPart.CanTouch, ringPart.CastShadow = true, false, false, false, false
ringPart.Transparency = 1
ringPart.Size = Vector3.new(4, 0.05, 4)
local ringGui = Instance.new("SurfaceGui")
ringGui.Face = Enum.NormalId.Top
ringGui.LightInfluence = 0
ringGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
ringGui.CanvasSize = Vector2.new(256, 256)
ringGui.Enabled = false
ringGui.Parent = ringPart
local ringImage = ArtImage.get(RING_PATH)
local ringVisual
if ringImage then
	ringVisual = Instance.new("ImageLabel")
	ringVisual.Image = ringImage
	ringVisual.ImageColor3 = Color3.new(1, 1, 1)
	ringVisual.ImageTransparency = 1 - RING_ALPHA
	ringVisual.ScaleType = Enum.ScaleType.Fit
	ringVisual.BackgroundTransparency = 1
	ringVisual.Size = UDim2.fromScale(1, 1)
else
	ringVisual = Instance.new("Frame") -- 이미지가 없으면 얇은 흰 테두리 원(채움 · 발광 없음)
	ringVisual.BackgroundTransparency = 1
	ringVisual.AnchorPoint = Vector2.new(0.5, 0.5)
	ringVisual.Position = UDim2.fromScale(0.5, 0.5)
	ringVisual.Size = UDim2.new(1, -8, 1, -8)
	corner(ringVisual)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 6
	stroke.Transparency = 1 - RING_ALPHA
	stroke.Parent = ringVisual
end
ringVisual.Name = "Ring"
ringVisual.Parent = ringGui
ringPart.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local groundY = nil

local function updateGround()
	local rec = target and recs[target]
	local pivot = target and target.PrimaryPart
	if not (rec and pivot) then
		return
	end
	rayParams.FilterDescendantsInstances = { target, ringPart, player.Character }
	local hit = workspace:Raycast(pivot.Position + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), rayParams)
	if hit then
		groundY = hit.Position.Y
	else
		local cf, size = target:GetBoundingBox()
		groundY = cf.Position.Y - size.Y / 2
	end
end

local function setTarget(model)
	if model ~= nil and not (typeof(model) == "Instance" and model.Parent and tryRecord(model)) then
		return
	end
	if model then
		targetAt = os.clock()
	end
	if model == target then
		return
	end
	local old = target
	target = model
	for _, m in ipairs({ old, model }) do
		local slot = m and slotOf[m]
		if slot then
			slot.alpha = -1
			slot.scaleNow = -1
			if m == model and slot.lastDrop and os.clock() - slot.lastDrop.at < 0.3 then
				slot.ghost.Size = UDim2.fromScale(slot.lastDrop.from, 1)
			end
			slot.lastDrop = nil
			syncFill(slot)
		end
	end
	if model then
		local size = model:GetExtentsSize()
		local d = math.clamp(math.max(size.X, size.Z) * 1.15, RING_MIN, RING_MAX)
		ringPart.Size = Vector3.new(d, 0.05, d)
		groundY = nil
		updateGround()
	end
	ringGui.Enabled = model ~= nil and groundY ~= nil
end

-- 파티원 대상 ------------------------------------------------------------------
local partyHits = setmetatable({}, { __mode = "k" }) -- [model] = { [Player] = os.clock() }
local partyColorOf = {} -- [Player] = Color3(틱마다 다시 셈)

local function notePartyHit(who, model)
	if typeof(who) ~= "Instance" or who == player or typeof(model) ~= "Instance" then
		return
	end
	local mine = player:GetAttribute("PartyId")
	if mine == nil or who:GetAttribute("PartyId") ~= mine then
		return
	end
	partyHits[model] = partyHits[model] or {}
	partyHits[model][who] = os.clock()
end

local function refreshPartyColors()
	table.clear(partyColorOf)
	local mine = player:GetAttribute("PartyId")
	if mine == nil then
		return
	end
	local members = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("PartyId") == mine then
			table.insert(members, p)
		end
	end
	table.sort(members, function(a, b)
		return a.UserId < b.UserId
	end)
	for i, p in ipairs(members) do
		partyColorOf[p] = UIColors.partyColors[(i - 1) % #UIColors.partyColors + 1]
	end
end

local function partyColorsFor(model, now)
	local hits = partyHits[model]
	if not hits then
		return nil
	end
	local colors = nil
	for who, at in pairs(hits) do
		if now - at > PARTY_HOLD or not who.Parent then
			hits[who] = nil
		elseif partyColorOf[who] then
			colors = colors or {}
			table.insert(colors, partyColorOf[who])
		end
	end
	if next(hits) == nil then
		partyHits[model] = nil
	end
	return colors
end

-- 고르기 · 갱신(10 Hz) ------------------------------------------------------------------
local candidates = {}

local function refresh()
	local now = os.clock()
	if target and (now - targetAt > TARGET_HOLD or not target.Parent or target:GetAttribute("DiedAt")) then
		setTarget(nil)
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	table.clear(candidates)
	if root and cam then
		refreshPartyColors()
		for _, model in ipairs(CollectionService:GetTagged("Monster")) do
			local rec = recs[model] or tryRecord(model)
			if rec and rec.head.Parent and not model:GetAttribute("DiedAt") then
				local dist = (rec.head.Position - root.Position).Magnitude
				local isTarget = model == target
				if dist <= (isTarget and TARGET_SHOW_STUDS or SHOW_STUDS) then
					local party = partyColorsFor(model, now)
					local rank = isTarget and 0 or (rec.name.Visible and 1 or (party and 2 or (rec.rare and 3 or 4)))
					local score = rank * 1000 + dist - (slotOf[model] and SHOWN_BONUS_STUDS or 0)
					table.insert(candidates, { model = model, rec = rec, dist = dist, score = score, party = party, isTarget = isTarget })
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.score < b.score
	end)
	local limit = math.min(isPhone() and MAX_SHOWN_PHONE or MAX_SHOWN_PC, #candidates)
	local keep = {}
	for i = 1, limit do
		keep[candidates[i].model] = candidates[i]
	end
	for _, slot in ipairs(slots) do
		if slot.model and not keep[slot.model] then
			release(slot)
		end
	end
	local stage = player:GetAttribute("InfiniteStage") or 1
	for i = 1, limit do
		local c = candidates[i]
		local slot = slotOf[c.model]
		if not slot then
			for _, s in ipairs(slots) do
				if not s.model then
					slot = s
					break
				end
			end
			assign(slot, c.model, c.rec)
		end
		-- 글: "Lv.n 이름"(레벨 = 옅은 회색 · 이름 = 흰색 또는 희귀 색)
		local nameText = c.rec.name.Text
		local key = nameText .. "|" .. stage
		if slot.textKey ~= key then
			slot.textKey = key
			slot.label.Text = ('<font color="#%s">%s</font> %s'):format(LEVEL_HEX, escape(Text.get("nameplate.mob.level", { level = tostring(stage) })), escape(nameText))
		end
		-- 크기(카메라 거리) · 투명도(내 캐릭터 거리)
		local camDist = (c.rec.head.Position - cam.CFrame.Position).Magnitude
		local t = math.clamp((camDist - CAM_NEAR) / (CAM_FAR - CAM_NEAR), 0, 1)
		local s = (1 + (SCALE_FAR - 1) * t) * (c.isTarget and TARGET_SCALE or 1)
		if math.abs(slot.scaleNow - s) > 0.02 then
			slot.scaleNow = s
			slot.scale.Scale = s
			slot.gui.Size = UDim2.fromOffset(PLATE_W * s, PLATE_H * s)
		end
		local alpha = 1
		if not c.isTarget and c.dist > FADE_FROM_STUDS then
			alpha = 1 - (1 - FADE_MIN_ALPHA) * math.clamp((c.dist - FADE_FROM_STUDS) / (SHOW_STUDS - FADE_FROM_STUDS), 0, 1)
		end
		applyAlpha(slot, alpha, c.isTarget)
		for d, dot in ipairs(slot.dots) do
			local color = c.party and c.party[d]
			dot.Visible = color ~= nil
			if color then
				dot.BackgroundColor3 = color
			end
		end
	end
	-- 겹침 풀기: 화면에서 앞 순위 이름표와 겹치면 위로 한 칸씩(SizeOffset = 화면 기준 · 최대 STACK_MAX칸 - 사막 몹 무리에서 3장이 겹쳐 안 읽힘 · Play 실측)
	local placed = {}
	for i = 1, limit do
		local slot = slotOf[candidates[i].model]
		local p, onScreen = cam:WorldToViewportPoint(candidates[i].rec.head.Position + slot.gui.StudsOffset)
		local shift = 0
		if onScreen then
			local w, h = slot.gui.Size.X.Offset, slot.gui.Size.Y.Offset
			local function hits(k)
				for _, r in ipairs(placed) do
					if math.abs(p.X - r.x) < (w + r.w) / 2 and math.abs(p.Y - k * h - r.y) < (h + r.h) / 2 then
						return true
					end
				end
				return false
			end
			while shift < STACK_MAX and hits(shift) do
				shift += 1
			end
			table.insert(placed, { x = p.X, y = p.Y - shift * h, w = w, h = h })
		end
		slot.gui.SizeOffset = Vector2.new(0, shift)
	end
	if target then
		updateGround()
		ringGui.Enabled = groundY ~= nil and root ~= nil and (target:GetPivot().Position - root.Position).Magnitude <= TARGET_SHOW_STUDS
	else
		ringGui.Enabled = false
	end
end

RunService.RenderStepped:Connect(function()
	if ringGui.Enabled and target and target.PrimaryPart and groundY then
		local p = target.PrimaryPart.Position
		ringPart.CFrame = CFrame.new(p.X, groundY + 0.06, p.Z)
	end
end)

-- 내 타격(서버 확정) ------------------------------------------------------------------
ReplicatedStorage:WaitForChild("AttackResult").OnClientEvent:Connect(function(model, _damage, _isCrit, died, _isComboHit, missed)
	if missed or typeof(model) ~= "Instance" then
		return
	end
	if died then
		if model == target then
			setTarget(nil)
		end
		return
	end
	setTarget(model)
end)

ReplicatedStorage:WaitForChild("SkillCastResult").OnClientEvent:Connect(function(_slot, data)
	if type(data) ~= "table" or not data.ok or type(data.hits) ~= "table" then
		return
	end
	for _, hit in ipairs(data.hits) do
		if type(hit) == "table" and typeof(hit.target) == "Instance" then
			if hit.isDead then
				if hit.target == target then
					setTarget(nil)
				end
			else
				setTarget(hit.target)
				return
			end
		end
	end
end)

ReplicatedStorage:WaitForChild("StuckArrowResult").OnClientEvent:Connect(function(model, _id, _damage, _isCrit, isDead)
	if typeof(model) ~= "Instance" then
		return
	end
	if isDead then
		if model == target then
			setTarget(nil)
		end
	else
		setTarget(model)
	end
end)

-- 파티원 공격(남의 화면 중계 - 연출용 이벤트를 같이 듣는다)
ReplicatedStorage:WaitForChild("AttackMotion").OnClientEvent:Connect(function(who, _combo, _isHeavy, _isAir, motionTarget)
	notePartyHit(who, motionTarget)
end)
ReplicatedStorage:WaitForChild("AttackShotRelay").OnClientEvent:Connect(function(who, model)
	notePartyHit(who, model)
end)

CollectionService:GetInstanceRemovedSignal("Monster"):Connect(function(model)
	local slot = slotOf[model]
	if slot then
		release(slot)
	end
	recs[model] = nil -- 스트리밍으로 다시 들어오면 새 기록(서버 이름표를 다시 끈다)
	if model == target then
		setTarget(nil)
	end
end)

while true do
	refresh()
	task.wait(TICK_SECONDS)
end
