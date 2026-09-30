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

-- QUEUE-ALL1 P2 v3: 직업 메시(<부위>_<직업>_<외형>)의 색 = 세트 3색(ArtImportData.armorSetColors)
local function colorOfV3(pieceName, zone, grade)
	local Z = Data.armorSetColors[zone] or Data.armorSetColors.tier1
	local main, sub, accent, glow = rgb(Z.main), rgb(Z.sub), rgb(Z.accent), rgb(Data.armorGlow)
	if grade == "transcendent" then
		local T = Data.armorTranscendent
		main, sub, accent, glow = rgb(T.base), rgb(Z.main), rgb(T.grade), rgb(T.glow)
	elseif grade == "primordial" then
		main, accent, glow = rgb(Data.armorPrimordialBase), GradeColor.of(grade), GradeColor.of(grade)
	elseif rank(grade) >= rank("legendary") then
		glow = GradeColor.of(grade) -- 보석 = 등급 색
	end
	local N = Data.armorNeutral[grade] or Data.armorNeutral
	if pieceName:match("_Glow$") then
		return glow, true
	elseif pieceName:match("_Grade$") then
		return accent, false
	elseif pieceName:match("_Trim$") then
		return sub, false
	elseif pieceName:match("_Steel$") then
		return rgb(N.steel), false
	elseif pieceName:match("_Leather$") then
		return rgb(N.leather), false
	end
	return main, false
end

local function lookOf(owner)
	local parts = { tostring(owner:GetAttribute(Data.armorClassAttribute)) }
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

local refresh
local function build(owner, character)
	local retries = worn[owner] and worn[owner].character == character and (worn[owner].retries or 0) or 0
	clear(owner)
	local key = lookOf(owner) .. "|" .. tostring(ArtMeshKit.enabled())
	local w = { key = key, character = character, pieces = {}, retries = retries }
	worn[owner] = w
	task.defer(function()
		if w.missing and worn[owner] == w and retries < 10 then
			task.delay(1, function()
				if worn[owner] == w then
					w.retries = retries + 1
					refresh(owner, character, true)
				end
			end)
		end
	end)
	if not (character and ArtMeshKit.enabled()) then
		return
	end
	for _, part in ipairs(PARTS) do
		local v = owner:GetAttribute(Data.armorLookAttribute .. part)
		local zone, grade
		if type(v) == "string" then
			zone, grade = v:match("^(tier%d)|(%w+)$") -- (`a and f()`는 값 하나로 잘려 grade가 nil이 된다 - 분리)
		end
		local look = Data.armorLookOfGrade[grade] or "normal"
		local modelKey = zone and ("%s_%s_%s"):format(part, zone, look)
		-- QUEUE-ALL1 P2 v3: 지금 직업 모양이 있으면 그것(세트 = 색) · 없으면 옛 구역 모양
		local classId = owner:GetAttribute(Data.armorClassAttribute)
		local classKey = zone and type(classId) == "string" and ("%s_%s_%s"):format(part, classId, look)
		local v3 = classKey and ArtMeshKit.get("armor/" .. classKey) and Wear.pieces[classKey] and true or false
		if v3 then
			modelKey = classKey
		end
		local src = modelKey and ArtMeshKit.get("armor/" .. modelKey)
		local metaPieces = modelKey and Wear.pieces[modelKey]
		if src and metaPieces then
			-- A2-N4 P0-3 A안: 붙는 파트마다 묶어 그 파트 실측 크기에 맞춘다(옛 = 블록형 refSize 배율 0.8 ~ 1.35 자름 → 장갑 · 장화가 손 · 발의 1.7 ~ 2.3배)
			local groups, order = {}, {}
			for _, piece in ipairs(src:GetChildren()) do
				local m = piece:IsA("BasePart") and metaPieces[piece.Name]
				local body = m and character:FindFirstChild(m.attach)
				if m and not body then
					w.missing = true -- 붙을 파트가 아직 안 옴(스트리밍 · 복제 중 - Play: 서버가 만든 더미에서 조각이 무작위로 빠졌다) → 아래에서 다시 입힌다
				end
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
				-- QUEUE-ALL1 P2 v3: 둘레는 묶음에서 가장 큰 껍데기 하나로 맞춘다(후드 · 망토 · 끈까지 묶으면 껍데기가 몸 안으로 줄어 셔츠가 비쳤다 - Play 실측)
				local fitList = groups[body]
				if v3 then
					local big, vol = nil, -1
					for _, g in ipairs(groups[body]) do
						local v = g.piece.Size.X * g.piece.Size.Y * g.piece.Size.Z
						if v > vol then
							big, vol = g, v
						end
					end
					fitList = { big }
				end
				for _, g in ipairs(fitList) do
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
				if v3 then -- 길이 = 파트 길이 비율(기준 체형 대비 - 윗몸통 1.9인 아바타에 1.6 껍데기가 남던 것)
					local refY = fitList[1].m.refSize and fitList[1].m.refSize[2] or body.Size.Y
					s = Vector3.new(s.X, math.clamp(body.Size.Y / refY, F.v3LengthClamp[1], F.v3LengthClamp[2]), s.Z)
				end
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
					local color, neon = (v3 and colorOfV3 or colorOf)(piece.Name, zone, grade)
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

function refresh(owner, character, force)
	local w = worn[owner]
	local key = lookOf(owner) .. "|" .. tostring(ArtMeshKit.enabled())
	if not force and w and w.key == key and w.character == character and #w.pieces > 0 and w.pieces[1].Parent then
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
	player:GetAttributeChangedSignal(Data.armorClassAttribute):Connect(go) -- 직업을 바꾸면 같은 장비도 그 직업 모양
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
		model:GetAttributeChangedSignal(Data.armorClassAttribute):Connect(function()
			refresh(model, model)
		end)
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

-- 캐시 완료 · 아트 스위치 = 강제로 다시 입힌다(QUEUE-ALL1 P2: 캐시가 다 차기 전에 갑옷만 입힌 채 "같은 키"라 장갑 · 신발이 끝내 안 붙었다)
local function refreshAll()
	for _, p in ipairs(Players:GetPlayers()) do
		refresh(p, p.Character, true)
	end
	for owner in pairs(worn) do
		if typeof(owner) == "Instance" and owner:IsA("Model") then
			refresh(owner, owner, true)
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
