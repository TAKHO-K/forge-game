-- A2-N4 §3-3(A2-N3 결정 ⑧): 보스 관문 틀 메시(props/boss_gate) + 보스별 관문 장식(extras/gate_decor/<보스 id>) 연결 - ArtStyleV1 뒤 · 겉모습만.
--   관문 모델 = 월드 "BossGate_<보스 id>"(shared/BossGateKit 공통 틀). 메시는 틀의 절반 크기(폭 20.48 = WorldMapData.bossGate.width 40)로 만들어졌다 → 배율 = width ÷ meshWidth.
--   틀 메시 조각 이름 = 코드 도형 이름 + _L · _R · _n(BossGatePost_L ↔ BossGatePost) → 같은 이름 도형 중 가장 가까운 것의 색 · 재질을 받고, 그 도형은 투명(충돌 · 판정 그대로).
--   문양 · 빛 막 · 발판 · 프롬프트 · 빛 테는 메시에 없어 코드 그대로(등록 표시가 여기 묶여 있다). 장식 = 관문 바닥 가운데(−Z = 바깥) 같은 공간에 얹는다(충돌 · 조준 없음).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local BossGateArt = {}

local function baseName(name)
	return (name:gsub("_[LR]$", ""):gsub("_%d+$", ""))
end

-- 관문 바닥 가운데 프레임: 아래 계단(GateStep - cf * (0, 0.1, 0)) 중 가장 넓은 것
local function gateFrame(model)
	local best
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "GateStep" and (not best or d.Size.X > best.Size.X) then
			best = d
		end
	end
	return best and (best.CFrame * CFrame.new(0, -0.1, 0)) or nil
end

local function place(src, frame, scale, parent, colorFor)
	local n = 0
	for _, p in ipairs(src:GetChildren()) do
		if p:IsA("BasePart") then
			local m = p:Clone()
			m.Size = p.Size * scale
			m.CFrame = frame * (CFrame.new(p.Position * scale) * p.CFrame.Rotation)
			m.Anchored, m.CanCollide, m.CanTouch, m.CanQuery = true, false, false, false
			if colorFor then
				colorFor(m, p)
			end
			m.Name = p.Name .. "_Mesh"
			m.Parent = parent
			n += 1
		end
	end
	return n
end

function BossGateArt.apply()
	if not ArtMeshKit.enabled() then
		return 0, 0
	end
	local frameSrc = ArtMeshKit.get("props/boss_gate")
	local scale = WorldMapData.bossGate.width / ArtImportData.gateMeshWidth
	local frames, decors = 0, 0
	for _, model in ipairs(Workspace:GetDescendants()) do
		if model:IsA("Model") and model.Name:sub(1, 9) == "BossGate_" and not model:GetAttribute("ArtMesh") then
			local cf = gateFrame(model)
			if cf then
				model:SetAttribute("ArtMesh", "boss_gate")
				if frameSrc then
					local kitParts = {}
					for _, d in ipairs(model:GetDescendants()) do
						if d:IsA("BasePart") then
							kitParts[d.Name] = kitParts[d.Name] or {}
							table.insert(kitParts[d.Name], d)
						end
					end
					frames += place(frameSrc, cf, scale, model, function(m, p)
						local list = kitParts[baseName(p.Name)]
						local best, bestD = nil, math.huge
						for _, k in ipairs(list or {}) do
							local dist = (k.Position - m.Position).Magnitude
							if dist < bestD then
								best, bestD = k, dist
							end
						end
						if best then
							m.Color, m.Material = best.Color, best.Material
							best.Transparency = 1 -- 충돌 · 판정은 그대로
						end
					end)
				end
				local bossId = model.Name:sub(10)
				local decor = ArtMeshKit.get("extras/gate_decor/" .. bossId)
				if decor then
					decors += place(decor, cf, scale, model)
				end
			end
		end
	end
	return frames, decors
end

return BossGateArt
