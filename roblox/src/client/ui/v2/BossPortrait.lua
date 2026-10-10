-- UI-1 3단계 보스 초상 판(08 v5-auto-boss §5): 판 = UI(대표 색 UIGradient 가운데 → 바깥 진한 색 + UIStroke 대표 색 + UICorner) · 그림 = BossPortraitData(512 투명 · 테 없음).
--   BossPortrait.make(parent, bossId, sizePx, { form2 = bool, corner = px | nil(원), stroke = px }) → Frame(이미지 = .Portrait) · 진입 카드 · 첫 만남 · 2폼 · 잔류 · 도감이 같이 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.BossPortraitData)
local ArtImage = require(script.Parent.Parent.ArtImage)

local BossPortrait = {}

function BossPortrait.entry(bossId, form2)
	local e = Data.bosses[bossId]
	if e and form2 and e.form2 then
		return e.form2
	end
	return e
end

function BossPortrait.color(bossId, form2)
	local e = BossPortrait.entry(bossId, form2)
	return Color3.fromHex(e and e.color or Data.fallbackColor)
end

function BossPortrait.make(parent, bossId, sizePx, opts)
	opts = opts or {}
	local e = BossPortrait.entry(bossId, opts.form2)
	local c = BossPortrait.color(bossId, opts.form2)
	local dark = Color3.new(c.R * Data.dark, c.G * Data.dark, c.B * Data.dark)
	local f = Instance.new("Frame")
	f.Name = "BossPortrait"
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Size = UDim2.fromOffset(sizePx, sizePx)
	f.ClipsDescendants = true
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, dark), ColorSequenceKeypoint.new(0.5, c), ColorSequenceKeypoint.new(1, dark) })
	g.Rotation = 90
	g.Parent = f
	local corner = Instance.new("UICorner")
	corner.CornerRadius = opts.corner and UDim.new(0, opts.corner) or UDim.new(0.5, 0)
	corner.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = c
	s.Thickness = opts.stroke or math.max(2, math.floor(sizePx / 40))
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	local img = Instance.new("ImageLabel")
	img.Name = "Portrait"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.ScaleType = Enum.ScaleType.Crop
	img.Image = e and ArtImage.get(e.image) or ""
	img.Parent = f
	f.Parent = parent
	return f
end

-- 그 보스 초상 그림 미리 받기(진입 카드가 그림보다 먼저 뜨지 않게 · 3단계 코드 ⑥)
function BossPortrait.preload(bossId)
	local list = {}
	for _, form2 in ipairs({ false, true }) do
		local e = BossPortrait.entry(bossId, form2)
		local img = e and ArtImage.get(e.image)
		if img then
			table.insert(list, img)
		end
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
	end)
end

return BossPortrait
