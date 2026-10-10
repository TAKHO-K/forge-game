-- UI-1 7b단계 설정 "단축키 표시"(06 v3 · 08 v7 §5 · 기본 켬): 끄면 메뉴 키 칩(KeyChip) · 스킬 칸 키 판(KeyV2)을 숨긴다(폰 = 키보드 연결 때만 의미).
--   HUD 모듈을 고치지 않고 이름으로 찾는다(새로 지어지는 칸도) · 스위치 = UiV2Flags.map.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not require(ReplicatedStorage.Shared.data.UiV2Flags).map then
	return
end
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NAMES = { KeyChip = true, KeyV2 = true }
local hiddenByUs = {} -- 우리가 숨긴 것만 되돌린다(모듈이 원래 숨긴 칩은 그대로)

local function apply(obj)
	if not (NAMES[obj.Name] and obj:IsA("GuiObject")) then
		return
	end
	local off = player:GetAttribute("SettingShowKeys") == false
	if off and obj.Visible then
		hiddenByUs[obj] = true
		obj.Visible = false
	elseif not off and hiddenByUs[obj] then
		hiddenByUs[obj] = nil
		obj.Visible = true
	end
end

local function all()
	for _, d in ipairs(playerGui:GetDescendants()) do
		apply(d)
	end
end
player:GetAttributeChangedSignal("SettingShowKeys"):Connect(all)
playerGui.DescendantAdded:Connect(function(d)
	if NAMES[d.Name] then
		task.defer(apply, d)
	end
end)
all()
