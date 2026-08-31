-- 골드 표시(10-1). 두 부분:
--   [1] 상시 카운터 - 화면 우상단, 작게. 체력바(상단 중앙)·공격 버튼(우하단)과 안 겹치는
--       빈 자리다. 서버 Attribute("Gold")만 읽는다 - PlayerProfile이 유일한 소스.
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

local goldGained = ReplicatedStorage:WaitForChild("GoldGained")

local GOLD_COLOR = Color3.fromRGB(255, 200, 60)

-- 팝업이 화면에 떠 있는 시간. 데미지 숫자(CombatConfig.damageNumberLifetimeSeconds)와
-- 다른 값이어도 되는 순수 연출 타이밍이라(9-5 개정 스택 오프셋처럼 이 파일에 로컬로 둔
-- 전례를 따른다) shared/data로 안 뺐다.
local POPUP_LIFETIME_SECONDS = 1.0

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GoldHudGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 동그란 골드 아이콘 하나 만든다. parent만 다르게 재사용(카운터/팝업 둘 다 같은 모양).
local function createCoinIcon(sizePixels)
	local icon = Instance.new("Frame")
	icon.Name = "CoinIcon"
	icon.BackgroundColor3 = GOLD_COLOR
	icon.BorderSizePixel = 0
	icon.Size = UDim2.new(0, sizePixels, 0, sizePixels)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = icon
	return icon
end

local counter = Instance.new("Frame")
counter.Name = "GoldCounter"
counter.AnchorPoint = Vector2.new(1, 0)
counter.Position = UDim2.new(1, -16, 0, 16)
counter.Size = UDim2.new(0, 110, 0, 32)
counter.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
counter.BackgroundTransparency = 0.2
counter.BorderSizePixel = 0
counter.Parent = screenGui

local counterCorner = Instance.new("UICorner")
counterCorner.CornerRadius = UDim.new(0, 6)
counterCorner.Parent = counter

local counterLayout = Instance.new("UIListLayout")
counterLayout.FillDirection = Enum.FillDirection.Horizontal
counterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
counterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
counterLayout.Padding = UDim.new(0, 8)
counterLayout.Parent = counter

local counterCoin = createCoinIcon(16)
counterCoin.LayoutOrder = 1
counterCoin.Parent = counter

local counterLabel = Instance.new("TextLabel")
counterLabel.Name = "GoldLabel"
counterLabel.LayoutOrder = 2
counterLabel.BackgroundTransparency = 1
counterLabel.Size = UDim2.new(0, 70, 1, 0)
counterLabel.TextXAlignment = Enum.TextXAlignment.Left
counterLabel.Font = Enum.Font.GothamBold
counterLabel.TextSize = 18
counterLabel.TextColor3 = GOLD_COLOR
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
