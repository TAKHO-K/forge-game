-- QUEUE-ALL9C 2-3 첫 화면 가림막(옛 S12 LoadingTip 자리). 접속 즉시 로블록스 기본 로딩 대신 하늘 그라데이션을 띄운다.
--   장소 사진 교차 전환 · 등급 빛줄기 · 메뉴 버튼 · 미리 불러오기 · 로딩 막대 = client/MainMenu.client.lua가 이 ScreenGui(MainMenuGui) 위에 짓는다
--   (사진 id · 등급 색은 Shared 데이터 한 곳 - Shared는 이 스크립트보다 늦게 와서 여기서는 그라데이션만).
--   Attribute BootClock = 이 스크립트 시작 os.clock()(접속 → 메뉴 표시 측정의 0점) · CoverClock = 가림막을 띄운 시각.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local bootClock = os.clock()
local Data = require(script.Parent:WaitForChild("MenuBootData"))
local MenuArtFit = require(script.Parent:WaitForChild("MenuArtFit"))

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "MainMenuGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = Data.displayOrder
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui:SetAttribute("BootClock", bootClock)

local sky = Instance.new("Frame")
sky.Name = "Sky"
sky.Size = UDim2.fromScale(1, 1)
sky.BorderSizePixel = 0
sky.BackgroundColor3 = Color3.new(1, 1, 1)
sky.Parent = gui
local skyGradient = Instance.new("UIGradient")
skyGradient.Rotation = 90
skyGradient.Color = ColorSequence.new(Data.skyTop, Data.skyBottom)
skyGradient.Parent = sky

local ground = Instance.new("Frame")
ground.Name = "Ground"
ground.AnchorPoint = Vector2.new(0, 1)
ground.Position = UDim2.fromScale(0, 1)
ground.Size = UDim2.fromScale(1, 0.28)
ground.BorderSizePixel = 0
ground.BackgroundColor3 = Data.ground
ground.ZIndex = 1
ground.Parent = sky

local shade = Instance.new("Frame")
shade.Name = "Shade"
shade.Size = UDim2.fromScale(1, 1)
shade.BorderSizePixel = 0
shade.BackgroundColor3 = Data.shade
shade.ZIndex = 4 -- 사진(2 · 3) 위
shade.Parent = sky
local shadeGradient = Instance.new("UIGradient")
local shadeKeys = {}
for _, k in ipairs(Data.shadeKeys) do
	table.insert(shadeKeys, NumberSequenceKeypoint.new(k[1], k[2]))
end
shadeGradient.Transparency = NumberSequence.new(shadeKeys)
shadeGradient.Parent = shade

-- 배경 키 아트(MenuBootData.background - 좌우 나눈 장을 원본 픽셀 범위대로 이어 붙인 틀 하나): 화면 꽉 채움(잘라내기) · 가로 가운데 · 세로 focusY
local bg = Data.background
local artParts = {}
local V2 = Data.layoutV2 and Data.v2 or nil -- QUEUE-UI UI-1: 01 spec 배경(오른쪽 붙임 · 왼쪽 페이드 · 남색 바탕)
if V2 then
	skyGradient.Color = ColorSequence.new(V2.skyTop, V2.skyBottom)
	ground.Visible = false
	shade.BackgroundColor3 = V2.shade
	local keys = {}
	for _, k in ipairs(V2.shadeKeys) do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	shadeGradient.Transparency = NumberSequence.new(keys)
end
local art = nil
if bg and #bg.parts > 0 and bg.width > 0 and bg.height > 0 then
	sky.ClipsDescendants = true
	art = Instance.new("Frame")
	art.Name = "KeyArt"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, Data.focusY) -- 그림의 focusY 지점을 화면 같은 높이에(잘라낼 때 위 · 아래 비율)
	art.Position = UDim2.fromScale(0.5, Data.focusY)
	art.ZIndex = 2
	art.Parent = sky
	for i, part in ipairs(bg.parts) do
		local img = Instance.new("ImageLabel")
		img.Name = "Part" .. i
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Stretch
		img.Image = part.image
		img.ImageTransparency = 1
		img.Position = UDim2.fromScale(part.x0 / bg.width, 0)
		img.Size = UDim2.fromScale((part.x1 - part.x0) / bg.width, 1)
		img.ZIndex = 2
		img.Parent = art
		table.insert(artParts, img)
	end
	local function cover()
		local w, h = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
		local aspect = bg.width / bg.height
		if V2 then -- QUEUE-UI2 UI2-3: 01 v3 "키 아트 초점"(MenuArtFit.place · 값 = MenuBootData.v2.keyArt · 창 오른쪽 = 메뉴가 알려 줌)
			local K = V2.keyArt
			local r = MenuArtFit.place(w, h, bg.width, bg.height, K.keep, K.margin, gui:GetAttribute("KeyArtUiRight"), gui:GetAttribute("KeyArtUiRightNarrow"))
			art.AnchorPoint = Vector2.new(0, 0)
			art.Position = UDim2.fromOffset(math.floor(r.x), 0)
			art.Size = UDim2.fromOffset(math.ceil(r.w) + 1, h)
			gui:SetAttribute("KeyArtNarrow", r.narrow)
			gui:SetAttribute("KeyArtKeep", Rect.new(r.keepScreen[1], r.keepScreen[2], r.keepScreen[3], r.keepScreen[4]))
			if r.zoneLeft and w > 0 then -- 어두운 그라데이션 끝 = 빈 구역 왼쪽 − margin(데이터 키의 마지막 불투명 → 투명 구간을 그 자리로 늘이고 줄임)
				local endX = math.clamp((r.zoneLeft - K.margin) / w, 0.05, 1)
				local last = V2.shadeKeys[#V2.shadeKeys - 1][1] -- 투명 1이 되는 자리(0.5)
				local keys = {}
				for _, k in ipairs(V2.shadeKeys) do
					local kx = k[1] >= 1 and 1 or math.min(k[1] * endX / last, 0.999)
					if #keys == 0 or kx > keys[#keys].Time then
						table.insert(keys, NumberSequenceKeypoint.new(kx, k[2]))
					end
				end
				if keys[#keys].Time < 1 then
					table.insert(keys, NumberSequenceKeypoint.new(1, 1))
				end
				shadeGradient.Transparency = NumberSequence.new(keys)
			end
			return
		end
		local width = math.max(w, h * aspect)
		art.Size = UDim2.fromOffset(math.ceil(width), math.ceil(width / aspect))
	end
	if V2 and artParts[1] then -- 그림 왼쪽 artFade(22%) 투명 → 불투명(첫 장 안 비율로)
		local first = bg.parts[1]
		local edge = math.clamp(V2.artFade * bg.width / (first.x1 - first.x0), 0.01, 0.99)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(edge, 0), NumberSequenceKeypoint.new(1, 0) })
		g.Parent = artParts[1]
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(cover)
	gui:GetAttributeChangedSignal("KeyArtUiRight"):Connect(cover) -- 메뉴가 창 오른쪽 화면 px를 알려 주면 다시
	gui:GetAttributeChangedSignal("KeyArtUiRightNarrow"):Connect(cover)
	task.defer(cover)
end

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()
gui:SetAttribute("CoverClock", os.clock())

-- 키 아트 = 미리 불러오기 1번(다른 무엇보다 먼저) → 모든 장이 오면 함께 서서히(반쪽만 보이는 순간 없음)
if #artParts > 0 then
	local ContentProvider = game:GetService("ContentProvider")
	local TweenService = game:GetService("TweenService")
	local ids = {}
	for _, img in ipairs(artParts) do
		table.insert(ids, img.Image)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, ids)
	for _, img in ipairs(artParts) do
		TweenService:Create(img, TweenInfo.new(Data.fadeSeconds, Enum.EasingStyle.Sine), { ImageTransparency = 0 }):Play()
	end
	gui:SetAttribute("KeyArtClock", os.clock())
end
