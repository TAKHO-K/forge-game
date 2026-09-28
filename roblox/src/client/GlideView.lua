-- MV1 활강 모습(그리기만 - 판정 없음): 머리 위 카툰 나뭇잎 글라이더(잎 1장 + 줄기 - 파트 2개 · 새 에셋 없음) + 앞으로 눕는 자세(AirMotion.hold).
--   자기 캐릭터 = GlideController가 켜는 순간 바로 부른다 · 남의 캐릭터 = 서버가 켜 둔 Character Attribute "Gliding"을 보고 부른다(GlideController가 감시).
--   치장 슬롯 gliderSkin(CosmeticSlotData) 자리 = 이 모듈 하나(스킨을 바꾸면 여기서 모양만 고른다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local AirMotion = require(script.Parent.AirMotion)

local GlideView = {}
local LOOK = MovementConfig.glide.look

local function part(name, size, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
	p.Parent = parent
	return p
end

local function weld(a, b, c0)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = a, b, c0
	w.Parent = b
end

function GlideView.show(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or character:FindFirstChild("MV1Glider") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "MV1Glider"
	local leaf = part("Leaf", LOOK.leafSize, LOOK.leafColor, model)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere -- 납작한 타원 = 잎
	mesh.Parent = leaf
	local stem = part("Stem", Vector3.new(0.3, LOOK.aboveHeadStuds + 1.2, 0.3), LOOK.stemColor, model)
	model.Parent = character
	-- 잎은 머리 위 · 앞쪽으로 살짝(눕는 자세에서 등 위에 오도록) · 줄기는 손 높이에서 잎까지
	weld(root, leaf, CFrame.new(0, 2 + LOOK.aboveHeadStuds, -0.6) * CFrame.Angles(math.rad(8), 0, 0))
	weld(root, stem, CFrame.new(0, 1.4 + LOOK.aboveHeadStuds / 2, -0.4))
	AirMotion.hold(character, "glide", LOOK.poseLeanDeg)
	require(script.Parent.WeaponVisual).playOverlay(Players:GetPlayerFromCharacter(character), "glideIn") -- W3b 활강 시작
end

function GlideView.hide(character)
	if not character then
		return
	end
	local model = character:FindFirstChild("MV1Glider")
	if model then
		require(script.Parent.WeaponVisual).playOverlay(Players:GetPlayerFromCharacter(character), "glideOut") -- W3b 활강 끝(착지 준비)
		model:Destroy()
	end
	AirMotion.release(character, "glide")
end

return GlideView
