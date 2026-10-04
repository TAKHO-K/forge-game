-- QUEUE-ALL9E1 LOOK2 보정 1 · 2(사용자 10-04 밤): 갑옷 착용 중 바닥층(게임 전용 2D 옷 = 누빔 상의 + 바지)을 서버가 캐릭터에 입힌다 → 모든 사람에게 같게 보인다.
--   끔(기본 · classes[].showOwnClothes = false): 본인 2D 셔츠 · 바지 템플릿을 바닥층으로 바꾸고 3D 레이어드 옷(WrapLayer 장신구)을 숨김 · 머리 · 얼굴 · 모자 · 머리 장식은 그대로.
--   켬: 본인 옷 전부 + 갑옷 판(겹침 허용 - 본인 선택). 갑옷을 다 벗어도 원래대로.
--   원래 값 = 캐릭터 안 Attribute(GearOrigTemplate · GearOrigTransparency)에 적어 두고 그대로 돌린다(캐릭터는 계정 아바타 설명으로 만들어지고 부활마다 새로 - 계정 아바타 자체는 건드리지 않음).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearV3Data = require(ReplicatedStorage.Shared.data.GearV3Data)
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)

local BaseLayer = {}

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

local function isLayered(acc)
	local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle") or nil
	return handle ~= nil and handle:FindFirstChildOfClass("WrapLayer") ~= nil, handle
end

local function setClothing(character, className, prop, template)
	local item = character:FindFirstChildOfClass(className)
	if template then
		if not item then
			item = Instance.new(className)
			item.Name = "GearBase" .. className
			item:SetAttribute("GearCreated", true)
			item.Parent = character
		elseif item:GetAttribute("GearOrigTemplate") == nil and not item:GetAttribute("GearCreated") then
			item:SetAttribute("GearOrigTemplate", item[prop])
		end
		if item[prop] ~= template then
			item[prop] = template
		end
	elseif item then
		if item:GetAttribute("GearCreated") then
			item:Destroy() -- 바닥층용으로 이 모듈이 만든 옷(원래 없던 옷)
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
	for _, acc in ipairs(character:GetChildren()) do
		local layered, handle = isLayered(acc)
		if layered then
			if on then
				if handle:GetAttribute("GearOrigTransparency") == nil then
					handle:SetAttribute("GearOrigTransparency", handle.Transparency)
				end
				handle.Transparency = 1
			elseif handle:GetAttribute("GearOrigTransparency") ~= nil then
				handle.Transparency = handle:GetAttribute("GearOrigTransparency")
				handle:SetAttribute("GearOrigTransparency", nil)
			end
		end
	end
	character:SetAttribute("GearBaseLayer", on and true or nil)
end

return BaseLayer
