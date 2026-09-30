-- QUEUE-ALL2 공통: 업로드한 PNG(roblox/art 기준 경로 - 확장자 뺌) → ImageLabel.Image 문자열. 이미지 id(Decal 속 이미지)가 아직 없으면 nil(부르는 쪽이 글자 · 도형으로 대신한다).
--   원본 = shared/data/ArtAssetIds.lua(upload.py가 만든다 · image = Studio LoadAsset로 읽은 Decal 이미지 id).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)

local ArtImage = {}

function ArtImage.get(path)
	local e = ArtAssetIds[path]
	return e and e.image and ("rbxassetid://" .. tostring(e.image)) or nil
end

-- ImageLabel 하나(투명 바탕 · 비율 유지). 이미지가 없으면 fallbackText 글자 칸
function ArtImage.label(parent, path, size, fallbackText)
	local img = ArtImage.get(path)
	local inst
	if img then
		inst = Instance.new("ImageLabel")
		inst.Image = img
		inst.ScaleType = Enum.ScaleType.Fit
	else
		inst = Instance.new("TextLabel")
		inst.Text = fallbackText or ""
		inst.Font = Enum.Font.GothamBold
		inst.TextScaled = false
		inst.TextSize = 14
		inst.TextColor3 = Color3.fromRGB(235, 235, 245)
		inst.TextWrapped = true
	end
	inst.Name = "Art"
	inst.BackgroundTransparency = 1
	inst.Size = size or UDim2.fromScale(1, 1)
	inst.Parent = parent
	return inst
end

return ArtImage
