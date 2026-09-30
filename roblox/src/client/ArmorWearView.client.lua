-- A2-N3 방어구 착용 표시(docs/art/armor-wear-spec.md 2안 - 클라 조각 + WeldConstraint · ArtStyleV1 스위치 뒤 · 판정 · 경제 · 저장 무관).
--   대상 = 모든 플레이어 캐릭터(Player Attribute ArmorLook_<부위> = "<구역>|<등급>" - 서버 InventorySync.push) + 검증 더미(모델 Attribute ArmorWearDummy · 같은 ArmorLook_ Attribute).
--   모델 = ArtMeshCache["armor/<부위>_<구역>_<외형>"](외형 = ArtImportData.armorLookOfGrade) · 조각 자리 = MeshMeta.armor_wear.pieces(붙는 R15 파트 · offset · refSize).
--   체형 배율 k = 붙는 파트 Size ÷ refSize(X · Z = 큰 쪽 하나 · Y 따로 · 0.8 ~ 1.35 자름) · 조각 = Massless · 충돌 · 조준 · 터치 끔 · 용접(매 프레임 비용 0). R6 = 표시 안 함.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local Data = require(ReplicatedStorage.Shared.data.ArtImportData)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local Wear = require(ReplicatedStorage.Shared.MeshMeta.armor_wear)

local PARTS = { "armor", "gloves", "shoes" }
local folder = Instance.new("Folder")
folder.Name = "ArmorWear"
folder.Parent = workspace

local worn = {} -- [owner(Player | Model)] = { key = 문자열, pieces = { MeshPart } }

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function rank(grade)
	return table.find(ArmorData.gradeOrder, grade) or 1
end

local function colorOf(pieceName, zone, grade)
	local Z = Data.armorZoneColors[zone] or Data.armorZoneColors.tier1
	local gc = GradeColor.of(grade)
	local base, trim, gradeC, glow = rgb(Z.base), rgb(Z.accent), gc, rgb(Data.armorGlow)
	if rank(grade) >= rank("epic") then
		trim = gc
	end
	if grade == "primordial" then
		base = rgb(Data.armorPrimordialBase)
		glow = gc
	elseif grade == "transcendent" then
		local T = Data.armorTranscendent
		base, trim, gradeC, glow = rgb(T.base), rgb(Z.accent), rgb(T.grade), rgb(T.glow)
	end
	if pieceName:match("_Glow$") then
		return glow, true
	elseif pieceName:match("_Grade$") then
		return gradeC, false
	elseif pieceName:match("_Trim$") then
		return trim, false
	end
	return base, false
end

local function lookOf(owner)
	local parts = {}
	for _, part in ipairs(PARTS) do
		table.insert(parts, tostring(owner:GetAttribute(Data.armorLookAttribute .. part)))
	end
	return table.concat(parts, ",")
end

local function clear(owner)
	local w = worn[owner]
	if w then
		for _, p in ipairs(w.pieces) do
			p:Destroy()
		end
	end
	worn[owner] = nil
end

local function build(owner, character)
	clear(owner)
	local key = lookOf(owner) .. "|" .. tostring(ArtMeshKit.enabled())
	local w = { key = key, character = character, pieces = {} }
	worn[owner] = w
	if not (character and ArtMeshKit.enabled()) then
		return
	end
	for _, part in ipairs(PARTS) do
		local v = owner:GetAttribute(Data.armorLookAttribute .. part)
		local zone, grade
		if type(v) == "string" then
			zone, grade = v:match("^(tier%d)|(%w+)$") -- (`a and f()`는 값 하나로 잘려 grade가 nil이 된다 - 분리)
		end
		local modelKey = zone and ("%s_%s_%s"):format(part, zone, Data.armorLookOfGrade[grade] or "normal")
		local src = modelKey and ArtMeshKit.get("armor/" .. modelKey)
		local metaPieces = modelKey and Wear.pieces[modelKey]
		if src and metaPieces then
			for _, piece in ipairs(src:GetChildren()) do
				local m = piece:IsA("BasePart") and metaPieces[piece.Name]
				local body = m and character:FindFirstChild(m.attach)
				if body and body:IsA("BasePart") then
					local r = m.refSize
					local C = Data.armorScaleClamp
					local kx = math.max(body.Size.X / r[1], body.Size.Z / r[3])
					local k = Vector3.new(math.clamp(kx, C.min, C.max), math.clamp(body.Size.Y / r[2], C.min, C.max), math.clamp(kx, C.min, C.max))
					local p = piece:Clone()
					p.Size = piece.Size * k
					p.CFrame = body.CFrame * CFrame.new(Vector3.new(m.offset[1], m.offset[2], m.offset[3]) * k) * piece.CFrame.Rotation
					local color, neon = colorOf(piece.Name, zone, grade)
					p.Color = color
					p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
					p.Anchored, p.Massless = false, true
					p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
					p.CastShadow = false
					local weld = Instance.new("WeldConstraint")
					weld.Part0, weld.Part1 = body, p
					weld.Parent = p
					p.Parent = folder
					table.insert(w.pieces, p)
				end
			end
		end
	end
end

local function refresh(owner, character)
	local w = worn[owner]
	local key = lookOf(owner) .. "|" .. tostring(ArtMeshKit.enabled())
	if w and w.key == key and w.character == character and #w.pieces > 0 and w.pieces[1].Parent then
		return
	end
	-- R15만(명세 §5): UpperTorso가 없으면 표시 안 함
	if character and not character:FindFirstChild("UpperTorso") then
		character:WaitForChild("UpperTorso", 5)
	end
	build(owner, character)
end

local function bindPlayer(player)
	local function go()
		task.defer(refresh, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		go()
	end)
	for _, part in ipairs(PARTS) do
		player:GetAttributeChangedSignal(Data.armorLookAttribute .. part):Connect(go)
	end
	go()
end

for _, p in ipairs(Players:GetPlayers()) do
	bindPlayer(p)
end
Players.PlayerAdded:Connect(bindPlayer)
Players.PlayerRemoving:Connect(clear)

-- 검증 더미(모델 자체가 주인 · 캐릭터)
local function bindDummy(model)
	if model:IsA("Model") and model:GetAttribute("ArmorWearDummy") then
		task.defer(refresh, model, model)
		for _, part in ipairs(PARTS) do
			model:GetAttributeChangedSignal(Data.armorLookAttribute .. part):Connect(function()
				refresh(model, model)
			end)
		end
		model.AncestryChanged:Connect(function()
			if not model.Parent then
				clear(model)
			end
		end)
	end
end
workspace.ChildAdded:Connect(function(c)
	task.defer(bindDummy, c)
end)

local function refreshAll()
	for _, p in ipairs(Players:GetPlayers()) do
		refresh(p, p.Character)
	end
	for owner in pairs(worn) do
		if typeof(owner) == "Instance" and owner:IsA("Model") then
			refresh(owner, owner)
		end
	end
end
workspace:GetAttributeChangedSignal("ArtStyleV1"):Connect(refreshAll)
task.spawn(function()
	local cache = ReplicatedStorage:WaitForChild(Data.cacheFolder, 120)
	if cache then
		cache:GetAttributeChangedSignal(Data.readyAttribute):Connect(refreshAll)
		if cache:GetAttribute(Data.readyAttribute) then
			refreshAll()
		end
	end
end)
