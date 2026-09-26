-- C1 마무리: 잠긴 몹 표시(다른 유저가 사냥 중 - 내가 치면 막힌다).
--   · 잠김 판정 = 서버가 모델 Attribute MobHunters로 내린 잡는 사람 목록 + 내 스테이지 · 레벨 · 환생 → MobShare.lockedFor(서버 isBlocked와 같은 canShare).
--     잠김 = 머리 위 체력바 회색(UIColors.mobLockedBar) + 왼쪽 자물쇠(HudIcons.lock). 이 클라에서만 바꾼다(LocalScript 변경은 복제 안 됨 - 사람마다 다르게 보인다).
--   · 서버 OwnedMobBlocked(model, showHint) = 방금 내 타격이 막힘 → 반사 연출(보호막 물결 + 공격 반대 방향 조각 - 연출만 · 소리 없음 · 같은 몹 0.3초 1번).
--     showHint = 계정 첫 1회(서버가 hints.stealLockSeen에 적음) → 말풍선 "다른 유저가 사냥중이에요".
-- 수치 · 색 = CombatConfig.stealReflectFx · stealReflectCooldownSeconds · stealLockHintSeconds · UIColors · 글 = TextData combat.stealLockHint.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MobShare = require(ReplicatedStorage.Shared.MobShare)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local WorldLabelStyle = require(ReplicatedStorage.Shared.WorldLabelStyle)
local HudIcons = require(script.Parent.HudIcons)

local player = Players.LocalPlayer
local TICK_SECONDS = 0.25
local LOCK_ICON_PX = 22

local watched = {} -- [model] = true(MobHunters가 있는 몹)
local shown = {} -- [model] = { fill, originalColor, icon }
local lastReflectAt = setmetatable({}, { __mode = "k" })

local function barFillOf(model)
	local head = model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("NameplateGui")
	local bg = gui and gui:FindFirstChild("HpBarBackground")
	return bg and bg:FindFirstChild("HpBarFill"), bg
end

local function setLocked(model, locked)
	local state = shown[model]
	if locked and not state then
		local fill, bg = barFillOf(model)
		if not fill then
			return
		end
		-- 자물쇠 = 바 왼쪽 끝 위에 겹침(빌보드 밖은 잘린다) · 어두운 원 받침(풀밭 · 하늘 위에서도 읽히게)
		local icon = Instance.new("Frame")
		icon.Name = "MobLockIcon"
		icon.Size = UDim2.new(0, LOCK_ICON_PX, 0, LOCK_ICON_PX)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 0, 0.5, 0)
		icon.BackgroundColor3 = UIColors.panel
		icon.BackgroundTransparency = UIColors.panelTransparency
		icon.ZIndex = 3
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = icon
		local glyph = HudIcons.lock(icon, LOCK_ICON_PX * 0.8, UIColors.mobLockIcon)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.new(0.5, 0, 0.5, 0)
		for _, part in ipairs(glyph:GetDescendants()) do
			if part:IsA("GuiObject") then
				part.ZIndex = 4
			end
		end
		icon.Parent = bg
		shown[model] = { fill = fill, originalColor = fill.BackgroundColor3, icon = icon }
		fill.BackgroundColor3 = UIColors.mobLockedBar
	elseif not locked and state then
		shown[model] = nil
		if state.fill.Parent then
			state.fill.BackgroundColor3 = state.originalColor
		end
		state.icon:Destroy()
	end
end

local function myProfile()
	return {
		userId = player.UserId,
		stage = player:GetAttribute("InfiniteStage") or 1,
		level = player:GetAttribute("CharacterLevel") or 1,
		rebirth = player:GetAttribute("RebirthCount") or 0,
		party = player:GetAttribute("PartyId"), -- D1-2: 같은 파티 = 잠금 없음(MobShare.sameParty)
	}
end

local function refresh()
	local me = myProfile()
	local now = workspace:GetServerTimeNow()
	for model in pairs(watched) do
		if model.Parent then
			setLocked(model, MobShare.lockedFor(model:GetAttribute("MobHunters"), me, now))
		else
			setLocked(model, false)
			watched[model] = nil
		end
	end
	for model in pairs(shown) do
		if not watched[model] then
			setLocked(model, false)
		end
	end
end

local connections = {} -- [model] = 연결(스트리밍으로 빠졌다 다시 들어오면 새로 건다 - 리뷰 6)

local function watch(model)
	local function update()
		watched[model] = model:GetAttribute("MobHunters") ~= nil or nil
	end
	update()
	if connections[model] then
		connections[model]:Disconnect()
	end
	connections[model] = model:GetAttributeChangedSignal("MobHunters"):Connect(update)
end

local function unwatch(model)
	setLocked(model, false) -- 스트리밍 아웃 = 부모 해제(Destroy 아님) - 회색 · 자물쇠를 되돌려 둔다
	watched[model] = nil
	if connections[model] then
		connections[model]:Disconnect()
		connections[model] = nil
	end
end

for _, model in ipairs(CollectionService:GetTagged("Monster")) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal("Monster"):Connect(watch)
CollectionService:GetInstanceRemovedSignal("Monster"):Connect(unwatch)

-- 반사 연출: 보호막 1 + 조각 fragmentCount(합 ≤ 6). 전부 이 클라 로컬 파트 · 충돌 · 조준 · 그림자 없음.
local function newFxPart(shape, size, cf, material)
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Color = UIColors.stealShield
	part.Parent = workspace
	return part
end

local function playReflect(model)
	local fx = CombatConfig.stealReflectFx
	local center, extents = model:GetBoundingBox()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local toMe = root and (root.Position - center.Position) * Vector3.new(1, 0, 1)
	toMe = (toMe and toMe.Magnitude > 0.01) and toMe.Unit or -center.LookVector
	local radius = math.max(extents.X, extents.Z) * 0.5
	local tweenInfo = TweenInfo.new(fx.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local shieldSize = math.max(extents.X, extents.Y, extents.Z) * 1.05
	local shield = newFxPart(Enum.PartType.Ball, Vector3.one * shieldSize, center, Enum.Material.ForceField)
	shield.Transparency = fx.shieldStartTransparency
	TweenService:Create(shield, tweenInfo, { Size = Vector3.one * shieldSize * fx.shieldGrow, Transparency = 1 }):Play()

	local hitPoint = center.Position + toMe * radius
	local rng = Random.new()
	local parts = { shield }
	for i = 1, fx.fragmentCount do
		local spread = math.rad(fx.fragmentSpreadDeg) * ((i - 0.5) / fx.fragmentCount * 2 - 1)
		local dir = (CFrame.Angles(0, spread, 0) * CFrame.new(Vector3.zero, toMe)).LookVector + Vector3.new(0, rng:NextNumber(0.2, 0.7), 0)
		local size = Vector3.one * fx.fragmentSize * rng:NextNumber(0.7, 1.2)
		local shard = newFxPart(Enum.PartType.Block, size, CFrame.new(hitPoint) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Enum.Material.Neon)
		shard.Transparency = 0.1
		local goal = CFrame.new(hitPoint + dir.Unit * fx.fragmentFlyStuds) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		TweenService:Create(shard, tweenInfo, { CFrame = goal, Transparency = 1, Size = size * 0.4 }):Play()
		table.insert(parts, shard)
	end
	task.delay(fx.seconds + 0.05, function()
		for _, part in ipairs(parts) do
			part:Destroy()
		end
	end)
end

local function showHint(model)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "StealLockHint"
	gui.Size = UDim2.new(0, 220, 0, 36)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	WorldLabelStyle.setupNameplateBillboard(gui, 150)
	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.new(1, 0, 1, 0)
	bubble.BackgroundColor3 = UIColors.panel
	bubble.BackgroundTransparency = UIColors.panelTransparency
	bubble.Text = Text.get("combat.stealLockHint")
	bubble.TextColor3 = UIColors.rimHi
	WorldLabelStyle.styleNameplateText(bubble, 16)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = bubble
	bubble.Parent = gui
	gui.Parent = head
	task.delay(CombatConfig.stealLockHintSeconds, function()
		gui:Destroy()
	end)
end

ReplicatedStorage:WaitForChild("OwnedMobBlocked").OnClientEvent:Connect(function(model, firstTime)
	if typeof(model) ~= "Instance" or not model.Parent then
		return
	end
	local now = os.clock()
	if not lastReflectAt[model] or now - lastReflectAt[model] >= CombatConfig.stealReflectCooldownSeconds then
		lastReflectAt[model] = now
		playReflect(model)
	end
	if firstTime == true then
		showHint(model)
	end
	refresh()
end)

while true do
	refresh()
	task.wait(TICK_SECONDS)
end
