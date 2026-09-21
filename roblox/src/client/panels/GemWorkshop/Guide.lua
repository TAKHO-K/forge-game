-- [위치 안내](S20e) - 보석상인 위에 마커를 띄우고 캐릭터에서 그쪽으로 선(Beam)을 긋는다. 서버 호출 없이 클라만 하는 표시다(판정이 아니다).
--   Guide.show() = WorldConfig.gemMerchant.guideSeconds(10초) 동안 표시(다시 부르면 처음부터) · Guide.hide() = 바로 끈다 · Guide.isShowing() · Guide.merchantPosition() = 보석상인 자리(월드 좌표).
-- 자리는 서버 모델(HuntingGround.createGemMerchant)과 같은 식으로 WorldConfig에서 계산한다 - StreamingEnabled라 멀리 있으면 모델이 클라에 없으므로 모델을 찾지 않는다.
-- 표시 = 보이지 않는 앵커 파트(클라에만 있다) 위 BillboardGui("▼ 보석상인" + 거리) + 캐릭터 루트 → 앵커 Beam. 색은 기존 UIColors만 쓴다(새 색 · 새 에셋 · 새 파티클 없음).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local Guide = {}

local ANCHOR_HEIGHT = 9 -- 마커가 모델 위에 뜨는 높이(stud)
local active = nil -- { anchor, attachment, connection, distanceLabel, token }
local tokenCounter = 0

function Guide.merchantPosition()
	return WorldConfig.huntingGround.center + WorldConfig.zones.community.center + WorldConfig.gemMerchant.offsetFromCommunity
end

function Guide.isShowing()
	return active ~= nil
end

function Guide.hide()
	if not active then
		return
	end
	local current = active
	active = nil
	if current.connection then
		current.connection:Disconnect()
	end
	if current.attachment then
		current.attachment:Destroy()
	end
	if current.anchor then
		current.anchor:Destroy() -- 마커 · Beam이 붙은 앵커째 지운다
	end
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Guide.show()
	Guide.hide()
	local player = Players.LocalPlayer
	local root = rootOf(player)
	if not root then
		return false
	end

	local anchor = Instance.new("Part")
	anchor.Name = "GemMerchantGuideAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = Guide.merchantPosition() + Vector3.new(0, ANCHOR_HEIGHT, 0)
	anchor.Parent = Workspace

	local marker = Instance.new("BillboardGui")
	marker.Name = "GemMerchantGuideMarker"
	marker.Size = UDim2.new(0, 180, 0, 84)
	marker.AlwaysOnTop = true
	marker.MaxDistance = math.huge
	marker.Adornee = anchor
	marker.Parent = anchor

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.Text = WorldConfig.gemMerchant.objectText -- "▼" 같은 도형 글리프는 폰트에 없어 네모로 나온다 - 아래 핀은 회전한 프레임으로 그린다
	title.TextColor3 = UIColors.gold
	title.TextStrokeTransparency = 0.3
	title.Parent = marker

	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Position = UDim2.new(0, 0, 0, 32)
	distanceLabel.Size = UDim2.new(1, 0, 0, 24)
	distanceLabel.Font = Enum.Font.Gotham
	distanceLabel.TextSize = Theme.text.body
	distanceLabel.Text = ""
	distanceLabel.TextColor3 = UIColors.textPrimary
	distanceLabel.TextStrokeTransparency = 0.3
	distanceLabel.Parent = marker

	local pin = Instance.new("Frame") -- 아래쪽을 가리키는 핀(회전한 정사각형)
	pin.AnchorPoint = Vector2.new(0.5, 0.5)
	pin.Position = UDim2.new(0.5, 0, 0, 70)
	pin.Size = UDim2.new(0, 14, 0, 14)
	pin.Rotation = 45
	pin.BackgroundColor3 = UIColors.gold
	pin.BorderSizePixel = 0
	pin.Parent = marker

	-- 캐릭터에서 보석상인 쪽으로 긋는 선(방향 표시). 시작 Attachment는 이 클라의 캐릭터 루트에 잠깐 붙는다.
	local fromAttachment = Instance.new("Attachment")
	fromAttachment.Name = "GemMerchantGuideFrom"
	fromAttachment.Parent = root
	local toAttachment = Instance.new("Attachment")
	toAttachment.Name = "GemMerchantGuideTo"
	toAttachment.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = fromAttachment
	beam.Attachment1 = toAttachment
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(UIColors.gold)
	beam.Transparency = NumberSequence.new(0.25)
	beam.LightEmission = 1
	beam.Parent = anchor

	tokenCounter += 1
	local token = tokenCounter
	local endsAt = os.clock() + WorldConfig.gemMerchant.guideSeconds
	active = { anchor = anchor, attachment = fromAttachment, distanceLabel = distanceLabel, token = token }
	active.connection = RunService.Heartbeat:Connect(function()
		local currentRoot = rootOf(player)
		if not active or active.token ~= token or not currentRoot or os.clock() >= endsAt then
			Guide.hide()
			return
		end
		local distance = (currentRoot.Position - Guide.merchantPosition()).Magnitude
		distanceLabel.Text = ("%d stud"):format(math.floor(distance + 0.5))
	end)
	return true
end

return Guide
