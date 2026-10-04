-- QUEUE-ALL9E1 LOOK2 보정 1 · 2(사용자 10-04 밤): 갑옷 착용 중 바닥층(게임 전용 2D 옷 = 누빔 상의 + 바지)을 서버가 캐릭터에 입힌다 → 모든 사람에게 같게 보인다.
--   끔(기본 · classes[].showOwnClothes = false): 본인 2D 셔츠 · 바지 템플릿을 바닥층으로 바꾸고 3D 레이어드 옷(WrapLayer 장신구)을 숨김 · 머리 · 얼굴 · 모자 · 머리 장식은 그대로.
--   켬: 본인 옷 전부 + 갑옷 판(겹침 허용 - 본인 선택). 갑옷을 다 벗어도 원래대로.
--   원래 값 = 2D 옷은 캐릭터 안 Attribute(GearOrigTemplate) · 레이어드 옷은 서버 보관 폴더(ServerStorage.GearHiddenClothes)에 두었다가 그대로 돌린다(캐릭터는 계정 아바타 설명으로 만들어지고 부활마다 새로 - 계정 아바타 자체는 건드리지 않음).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearV3Data = require(ReplicatedStorage.Shared.data.GearV3Data)
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)

local BaseLayer = {}

local stash = {} -- [캐릭터] = { 숨긴 레이어드 옷(Accessory) }
local function holder()
	local ServerStorage = game:GetService("ServerStorage")
	local f = ServerStorage:FindFirstChild("GearHiddenClothes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "GearHiddenClothes"
		f.Parent = ServerStorage
	end
	return f
end

local PARTS = { "armor", "gloves", "shoes" }

-- 갑옷 한 부위라도 입었는가(InventorySync가 올리는 Player Attribute ArmorLook_<부위> = "<구역>|<등급>")
function BaseLayer.armorOn(player)
	for _, part in ipairs(PARTS) do
		local v = player:GetAttribute("ArmorLook_" .. part)
		if type(v) == "string" and v:match("^tier%d|%w+$") then
			return true
		end
	end
	return false
end

-- 바닥층을 입히는가: 갑옷을 입었고 본인 옷 보이기가 꺼짐
function BaseLayer.wantBase(armorOn, showOwn)
	return armorOn == true and showOwn ~= true
end

-- 직업 → 바닥층 템플릿(이미지 id) · 없으면 nil(업로드 전 = 아무것도 안 바꿈)
function BaseLayer.templates(classId)
	local color = GearV3Data.baseLayer[classId] or "navy"
	local function image(kind)
		local row = ArtAssetIds[("textures/gear_v3/base_%s_%s"):format(color, kind)]
		return row and row.image and ("rbxassetid://" .. row.image) or nil
	end
	return image("shirt"), image("pants")
end

-- 숨기는 것 = 레이어드 "옷"만(머리카락 · 모자 · 얼굴 · 머리 장식은 레이어드여도 그대로 - 지시 "머리 · 얼굴 · 모자 · 머리 장식은 유지")
local CLOTHING = {
	[Enum.AccessoryType.TShirt] = true, [Enum.AccessoryType.Shirt] = true, [Enum.AccessoryType.Pants] = true, [Enum.AccessoryType.Jacket] = true,
	[Enum.AccessoryType.Sweater] = true, [Enum.AccessoryType.Shorts] = true, [Enum.AccessoryType.DressSkirt] = true,
	[Enum.AccessoryType.LeftShoe] = true, [Enum.AccessoryType.RightShoe] = true,
}
local function isLayered(acc)
	local handle = acc:IsA("Accessory") and CLOTHING[acc.AccessoryType] and acc:FindFirstChild("Handle") or nil
	return handle ~= nil and handle:FindFirstChildOfClass("WrapLayer") ~= nil, handle
end

local function setClothing(character, className, prop, template)
	-- 리뷰: 외형이 늦게 붙으면 아바타 옷과 이 모듈이 만든 옷이 둘 다 생길 수 있다 → 아바타 옷이 있으면 만든 옷은 치우고, 남은 옷 전부에 같은 규칙
	local items, own = {}, false
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA(className) then
			table.insert(items, c)
			own = own or not c:GetAttribute("GearCreated")
		end
	end
	for i = #items, 1, -1 do
		if items[i]:GetAttribute("GearCreated") and (own or not template) then
			items[i]:Destroy() -- 바닥층용으로 이 모듈이 만든 옷(원래 없던 옷)
			table.remove(items, i)
		end
	end
	if template and #items == 0 then
		local item = Instance.new(className)
		item.Name = "GearBase" .. className
		item:SetAttribute("GearCreated", true)
		item[prop] = template
		item.Parent = character
		return
	end
	for _, item in ipairs(items) do
		if template then
			if item:GetAttribute("GearOrigTemplate") == nil and not item:GetAttribute("GearCreated") then
				item:SetAttribute("GearOrigTemplate", item[prop])
			end
			if item[prop] ~= template then
				item[prop] = template
			end
		elseif item:GetAttribute("GearOrigTemplate") ~= nil then
			item[prop] = item:GetAttribute("GearOrigTemplate")
			item:SetAttribute("GearOrigTemplate", nil)
		end
	end
end

-- 캐릭터에 적용(여러 번 불러도 같은 결과 - 멱등). on = 바닥층 입힘 · classId = 바닥층 색
function BaseLayer.apply(character, on, classId)
	if not character then
		return
	end
	local shirt, pants = BaseLayer.templates(classId)
	setClothing(character, "Shirt", "ShirtTemplate", on and shirt or nil)
	setClothing(character, "Pants", "PantsTemplate", on and pants or nil)
	-- 레이어드 옷: 투명하게 하면 몸과 합쳐 그려져 몸까지 사라졌다(Play) → 캐릭터 밖(서버 보관)으로 옮겼다가 Humanoid:AddAccessory로 되돌린다(캐릭터 · 계정 아바타 데이터는 그대로)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if on then
		local list = stash[character]
		for _, acc in ipairs(character:GetChildren()) do
			if isLayered(acc) then
				if not list then
					list = {}
					stash[character] = list
					character.AncestryChanged:Connect(function(_, parent)
						if parent == nil and stash[character] then
							for _, a in ipairs(stash[character]) do
								a:Destroy() -- 캐릭터가 사라짐(부활 · 퇴장) - 보관본도 정리(다음 캐릭터는 계정 아바타로 새로 만들어진다)
							end
							stash[character] = nil
						end
					end)
				end
				table.insert(list, acc)
				acc.Parent = holder()
			end
		end
	elseif stash[character] then
		for _, acc in ipairs(stash[character]) do
			if humanoid then
				humanoid:AddAccessory(acc)
			else
				acc.Parent = character
			end
		end
		stash[character] = nil
	end
	character:SetAttribute("GearBaseLayer", on and true or nil)
end

return BaseLayer
