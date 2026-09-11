-- 골드 표시(10-1 신설 → 16-2에서 목업 재정렬). 두 부분:
--   [1] 상시 카운터 - 16-2부터 상단 중앙 칩 행(TopChipsRow, StageUI.client.lua가 만든다)의
--       첫 칩. 목업 .chip.gold(색 점 + 숫자) 그대로. 서버 Attribute("Gold")만 읽는다 -
--       PlayerProfile이 유일한 소스.
--   [2] 처치 팝업 - 몬스터를 잡을 때마다 캐릭터 머리 위에 짧게 뜨는 "●골드 +N". 다른 UI를
--       가리지 않게 화면 고정이 아니라 캐릭터에 붙는 BillboardGui로 만들었다.
-- 골드 아이콘은 유니코드 이모지(🪙) 대신 동그란 색 Frame으로 그린다 - 로블록스 TextLabel은
-- 컬러 이모지 글리프를 기본 폰트로 지원하지 않아 실기(Studio 플레이테스트)에서 빈 사각형
-- (tofu)으로만 보였다(직접 스크린샷으로 확인). 이 프로젝트가 몬스터 등에 이미 쓰고 있는
-- "도형으로 표현" 방식과도 맞다.
-- 축약 표기는 체력 숫자·몬스터 이름표와 같은 NumberFormat 규칙을 그대로 쓴다(성장 체감 통일).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local HudChip = require(script.Parent.HudChip)

local goldGained = ReplicatedStorage:WaitForChild("GoldGained")

-- 16-2: 팔레트가 재화·경험치·강조 색을 분리하면서(UIColors 16-2 개정 참고) 골드 전용
-- "gold" 토큰이 생겼다 - 16-1까지 쓰던 "accent"는 이제 없다.
local GOLD_COLOR = UIColors.gold

-- 팝업이 화면에 떠 있는 시간. 데미지 숫자(CombatConfig.damageNumberLifetimeSeconds)와
-- 다른 값이어도 되는 순수 연출 타이밍이라(9-5 개정 스택 오프셋처럼 이 파일에 로컬로 둔
-- 전례를 따른다) shared/data로 안 뺐다.
local POPUP_LIFETIME_SECONDS = 1.0

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 동그란 골드 아이콘 하나 만든다. parent만 다르게 재사용(카운터/팝업 둘 다 같은 모양).
local function createCoinIcon(sizePixels, glow)
	local icon = Instance.new("Frame")
	icon.Name = "CoinIcon"
	icon.BackgroundColor3 = GOLD_COLOR
	icon.BorderSizePixel = 0
	icon.Size = UDim2.new(0, sizePixels, 0, sizePixels)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = icon
	if glow then
		-- 목업 .chip.gold .dot의 box-shadow 0 0 8px var(--gold) - Roblox엔 도형 자체의
		-- 발광이 없어 UIStroke를 두껍고 흐리게(반투명) 둘러 은은한 번짐만 흉내 낸다.
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD_COLOR
		stroke.Thickness = 3
		stroke.Transparency = 0.7
		stroke.Parent = icon
	end
	return icon
end

-- 16-2: 단독 카운터 패널 대신 상단 칩 행의 첫 칩(LayoutOrder=1, StageUI.client.lua 3번 참고).
local topChipsRow = playerGui:WaitForChild("TopChipsGui"):WaitForChild("TopChipsRow")
local counter = HudChip.new(topChipsRow, 1)
counter.Name = "GoldChip"

local counterCoin = createCoinIcon(7, true)
counterCoin.LayoutOrder = 1
counterCoin.Parent = counter

local counterLabel = Instance.new("TextLabel")
counterLabel.Name = "GoldLabel"
counterLabel.LayoutOrder = 2
counterLabel.BackgroundTransparency = 1
counterLabel.AutomaticSize = Enum.AutomaticSize.X
counterLabel.Size = UDim2.new(0, 0, 1, 0)
counterLabel.TextXAlignment = Enum.TextXAlignment.Left
counterLabel.Font = Enum.Font.GothamBold
counterLabel.TextSize = 13
counterLabel.TextColor3 = UIColors.textPrimary
counterLabel.Text = "0"
counterLabel.Parent = counter

local function updateCounter()
	local gold = player:GetAttribute("Gold") or 0
	counterLabel.Text = NumberFormat.format(gold)
end

player:GetAttributeChangedSignal("Gold"):Connect(updateCounter)
updateCounter()

local function getHead()
	local character = player.Character
	return character and character:FindFirstChild("Head")
end

local function showGoldPopup(amount)
	local head = getHead()
	if not head then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "GoldPopupGui"
	gui.Size = UDim2.new(3, 0, 0.9, 0)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.Parent = head

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 1, 0)
	row.Parent = gui

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.Parent = row

	local coin = createCoinIcon(22)
	coin.LayoutOrder = 1
	coin.Parent = row

	local label = Instance.new("TextLabel")
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 110, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "+" .. NumberFormat.format(amount)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = GOLD_COLOR
	label.TextScaled = true
	label.Parent = row

	-- 위로 살짝 떠오르며 사라진다(데미지 숫자와 같은 연출 방향, 몬스터 쪽이 아니라
	-- 내 캐릭터 위에 뜨니 화면에서 겹칠 일은 없다).
	TweenService:Create(gui, TweenInfo.new(POPUP_LIFETIME_SECONDS), {
		StudsOffset = Vector3.new(0, 4.2, 0),
	}):Play()
	TweenService:Create(coin, TweenInfo.new(POPUP_LIFETIME_SECONDS), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(label, TweenInfo.new(POPUP_LIFETIME_SECONDS), {
		TextTransparency = 1,
	}):Play()

	task.delay(POPUP_LIFETIME_SECONDS, function()
		gui:Destroy()
	end)
end

goldGained.OnClientEvent:Connect(showGoldPopup)
