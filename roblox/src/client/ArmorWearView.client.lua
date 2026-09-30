-- A2-N3 방어구 착용 표시(docs/art/armor-wear-spec.md 2안 - 클라 조각 + WeldConstraint · ArtStyleV1 스위치 뒤 · 판정 · 경제 · 저장 무관).
--   대상 = 모든 플레이어 캐릭터(Player Attribute ArmorLook_<부위> = "<구역>|<등급>" - 서버 InventorySync.push) + 검증 더미(모델 Attribute ArmorWearDummy · 같은 ArmorLook_ Attribute).
--   모델 = ArtMeshCache["armor/<부위>_<구역>_<외형>"](외형 = ArtImportData.armorLookOfGrade) · 조각 자리 = MeshMeta.armor_wear.pieces(붙는 R15 파트 · offset · refSize).
--   A2-N4: 크기 = 붙는 R15 파트 실측 맞춤(ArtImportData.armorFit - 손 · 발 +10% · 나머지 껍데기 0.15) · 조각 = Massless · 충돌 · 조준 · 터치 끔 · 용접(매 프레임 비용 0). R6 = 표시 안 함.
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
			-- A2-N4 P0-3 A안: 붙는 파트마다 묶어 그 파트 실측 크기에 맞춘다(옛 = 블록형 refSize 배율 0.8 ~ 1.35 자름 → 장갑 · 장화가 손 · 발의 1.7 ~ 2.3배)
			local groups, order = {}, {}
			for _, piece in ipairs(src:GetChildren()) do
				local m = piece:IsA("BasePart") and metaPieces[piece.Name]
				local body = m and character:FindFirstChild(m.attach)
				if body and body:IsA("BasePart") then
					if not groups[body] then
						groups[body] = {}
						table.insert(order, body)
					end
					table.insert(groups[body], { piece = piece, m = m })
				end
			end
			local F = Data.armorFit
			for _, body in ipairs(order) do
				local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
				for _, g in ipairs(groups[body]) do
					local R = g.piece.CFrame.Rotation
					local h = g.piece.Size / 2
					local ext = Vector3.new(
						math.abs(R.RightVector.X) * h.X + math.abs(R.UpVector.X) * h.Y + math.abs(R.LookVector.X) * h.Z,
						math.abs(R.RightVector.Y) * h.X + math.abs(R.UpVector.Y) * h.Y + math.abs(R.LookVector.Y) * h.Z,
						math.abs(R.RightVector.Z) * h.X + math.abs(R.UpVector.Z) * h.Y + math.abs(R.LookVector.Z) * h.Z)
					local c = Vector3.new(g.m.offset[1], g.m.offset[2], g.m.offset[3])
					lo, hi = lo:Min(c - ext), hi:Max(c + ext)
				end
				local size = hi - lo
				local target = F.handFootParts[body.Name] and body.Size * (1 + F.handFootPad) or body.Size + Vector3.one * (2 * F.shellStuds)
				local s = Vector3.new(target.X / math.max(size.X, 1e-3), math.min(1, target.Y / math.max(size.Y, 1e-3)), target.Z / math.max(size.Z, 1e-3))
				local mid = (lo + hi) / 2
				for _, g in ipairs(groups[body]) do
					local piece, m = g.piece, g.m
					local R = piece.CFrame.Rotation
					-- 몸 축 배율 s → 조각 로컬 축 배율(축 정렬 회전이면 정확)
					local sl = Vector3.new(
						math.abs(R.RightVector.X) * s.X + math.abs(R.RightVector.Y) * s.Y + math.abs(R.RightVector.Z) * s.Z,
						math.abs(R.UpVector.X) * s.X + math.abs(R.UpVector.Y) * s.Y + math.abs(R.UpVector.Z) * s.Z,
						math.abs(R.LookVector.X) * s.X + math.abs(R.LookVector.Y) * s.Y + math.abs(R.LookVector.Z) * s.Z)
					local off = Vector3.new(m.offset[1], m.offset[2], m.offset[3])
					local p = piece:Clone()
					p.Size = piece.Size * sl
					-- 묶음 가운데는 둘레(X · Z)만 파트 가운데로 모으고 높이는 비율대로(어깨판은 어깨 위 · 벨트는 허리 아래 그대로)
					local at = Vector3.new((off.X - mid.X) * s.X, off.Y * s.Y, (off.Z - mid.Z) * s.Z)
					p.CFrame = body.CFrame * CFrame.new(at) * R
					local color, neon = colorOf(piece.Name, zone, grade)
					p.Color = color
					p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
					p.Anchored, p.Massless = false, true
					p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
					p.CastShadow = false
					p:SetAttribute("ArmorFitBody", body.Name)
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
