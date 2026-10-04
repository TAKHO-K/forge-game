-- QUEUE-ALL9E1 LOOK2 보정 2: 바닥층 연결(규칙 = server/BaseLayer). 장비창 토글 = RemoteEvent OwnClothesToggle(참/거짓) → 지금 직업에 저장(v73) + Player Attribute ShowOwnClothes.
--   다시 입히는 때: 갑옷 Attribute(ArmorLook_*) · 직업 전환(ClassId) · 토글 · 부활(CharacterAppearanceLoaded) · 접속(프로필 로드 뒤).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseLayer = require(script.Parent.BaseLayer)
local PlayerProfile = require(script.Parent.PlayerProfile)
local RequestGate = require(script.Parent.RequestGate)

local remote = Instance.new("RemoteEvent")
remote.Name = "OwnClothesToggle"
remote.Parent = ReplicatedStorage

local function refresh(player)
	if not PlayerProfile.getProfile(player) then
		return
	end
	local show = PlayerProfile.getShowOwnClothes(player)
	if player:GetAttribute("ShowOwnClothes") ~= show then
		player:SetAttribute("ShowOwnClothes", show)
	end
	BaseLayer.apply(player.Character, BaseLayer.wantBase(BaseLayer.armorOn(player), show), player:GetAttribute("ClassId"))
end

remote.OnServerEvent:Connect(function(player, on)
	if not RequestGate.allow(player, "OwnClothesToggle") or type(on) ~= "boolean" then
		return
	end
	if PlayerProfile.setShowOwnClothes(player, on) then -- 저장은 다음 자동 저장(되돌릴 수 있는 설정 - 즉시 저장 안 함)
		refresh(player)
	end
end)

local function bind(player)
	for _, attr in ipairs({ "ArmorLook_armor", "ArmorLook_gloves", "ArmorLook_shoes", "ClassId" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			refresh(player)
		end)
	end
	player.CharacterAppearanceLoaded:Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function()
		task.delay(1, refresh, player) -- Studio 시험 계정은 AppearanceLoaded가 늦거나 없다
	end)
	task.spawn(function()
		for _ = 1, 120 do -- 프로필 로드 대기
			if PlayerProfile.getProfile(player) or not player.Parent then
				break
			end
			task.wait(0.5)
		end
		refresh(player)
	end)
end

-- 검증 더미(모델 Attribute ArmorWearDummy · ArmorLook_* · ClassId · ShowOwnClothes - 클라 ArmorWearView와 같은 더미): 같은 규칙(마네킹 · 레이어드 옷 아바타 캡처)
local function bindDummy(model)
	if not (model:IsA("Model") and model:GetAttribute("ArmorWearDummy")) then
		return
	end
	local function go()
		BaseLayer.apply(model, BaseLayer.wantBase(BaseLayer.armorOn(model), model:GetAttribute("ShowOwnClothes") == true), model:GetAttribute("ClassId"))
	end
	for _, attr in ipairs({ "ArmorLook_armor", "ArmorLook_gloves", "ArmorLook_shoes", "ClassId", "ShowOwnClothes" }) do
		model:GetAttributeChangedSignal(attr):Connect(go)
	end
	go()
end
workspace.ChildAdded:Connect(function(c)
	task.defer(bindDummy, c)
end)

Players.PlayerAdded:Connect(bind)
for _, p in ipairs(Players:GetPlayers()) do
	bind(p)
end
