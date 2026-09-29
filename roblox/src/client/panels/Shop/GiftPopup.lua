-- 선물함 팝업(QUEUE-B1 B2 UI - overlay). 서버 GiftService가 접속 때(받을 선물이 있으면) GiftPopup(선물 목록)을 보낸다 → 목록(종류 · 이름 · 보낸 이 · 메모) + [모두 받기] · [나중에].
--   받기 = ShopRequest("giftClaim", "all") - 지급 · 판정은 서버. [나중에] = 닫기만(선물은 서버 우편함에 남는다 - 상점 [치장] 탭 위 "받을 선물 n개" 줄에서 다시 받는다).
--   크기 = GiftPopup.sizeFor(화면) 순수 함수(폰 667 × 317에서도 화면 안 · 버튼 44).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local Button = require(script.Parent.Parent.Parent.ui.kit.Button)
local Panel = require(script.Parent.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.Parent.UIManager)
local CosmeticTab = require(script.Parent.CosmeticTab)
local Layout = require(script.Parent.Layout)

local GiftPopup = {}

GiftPopup.id = "giftPopup"
local MAX_W, MAX_H = 440, 300
local PAD = 12

local built -- { panel, list, claim, later, size }
local sendRequest -- init이 넘겨 준 ShopRequest 보내기
local lastGifts = {}

-- 화면(ScreenGui 폭 · 높이) → 팝업 크기 · 버튼 높이. touch = 터치 기기(버튼 44).
function GiftPopup.sizeFor(screenW, screenH, touch)
	local phone = require(script.Parent.Parent.Inventory.Layout).isPhone(screenW, screenH)
	local buttonH = (phone or touch) and 44 or 32
	return Vector2.new(math.min(MAX_W, screenW - 2 * Layout.margin), math.min(MAX_H, screenH - 2 * Layout.margin)), buttonH
end

local function screenSize()
	local camera = workspace.CurrentCamera
	local inset = GuiService:GetGuiInset()
	return camera.ViewportSize.X, camera.ViewportSize.Y - inset.Y
end

-- 선물 한 건 → 제목 · 부제
function GiftPopup.describe(gift)
	local kindText = Text.get("gift.kind." .. tostring(gift.kind))
	local name
	if gift.kind == "sparkleShard" then
		name = Text.get("gift.shardAmount", { n = tostring(gift.amount or 0) })
	else
		name = CosmeticTab.nameOf(gift.kind, gift.itemId)
	end
	local title = Text.get("gift.row", { kind = kindText, name = name })
	local note = tostring(gift.note or "")
	local subtitle = note ~= "" and Text.get("gift.fromNote", { from = tostring(gift.from or ""), note = note }) or Text.get("gift.from", { from = tostring(gift.from or "") })
	return title, subtitle
end

local function destroy()
	if built then
		UIManager.unregister(GiftPopup.id)
		built.panel.screenGui:Destroy()
		built = nil
	end
end

local function build(size, buttonH)
	local panel = Panel.create({ id = GiftPopup.id, kind = "overlay", title = Text.get("gift.title"), size = size })
	local content = panel.content
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, PAD, 0, 8)
	list.Size = UDim2.new(1, -2 * PAD, 1, -(8 + buttonH + PAD * 2))
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list

	local claim = Button.build({ parent = content, name = "ClaimAll", kind = "primary", text = Text.get("gift.claimAll"), width = 120, height = buttonH,
		anchorPoint = Vector2.new(1, 1), position = UDim2.new(1, -PAD, 1, -PAD), onActivated = function()
			if sendRequest then
				sendRequest("giftClaim", "all")
			end
			UIManager.close(GiftPopup.id)
		end })
	local later = Button.build({ parent = content, name = "Later", kind = "secondary", text = Text.get("gift.later"), width = 120, height = buttonH,
		anchorPoint = Vector2.new(1, 1), position = UDim2.new(1, -(PAD + 120 + 8), 1, -PAD), onActivated = function()
			UIManager.close(GiftPopup.id)
		end })
	built = { panel = panel, list = list, claim = claim, later = later, size = size, buttonH = buttonH, mobile = Theme.isMobile }
end

local function fill(gifts)
	for _, child in ipairs(built.list:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local rowW = built.size.X - 2 * PAD - 6
	local titleSize, captionSize = Theme.textSize("body"), Theme.textSize("caption")
	for index, gift in ipairs(gifts) do
		local title, subtitle = GiftPopup.describe(gift)
		local row = Instance.new("Frame")
		row.Name = "Gift_" .. index
		row.LayoutOrder = index
		row.Size = UDim2.new(0, rowW, 0, titleSize + captionSize + 20)
		row.BackgroundColor3 = Theme.colors.slot
		row.BackgroundTransparency = Theme.colors.slotTransparency
		row.Parent = built.list
		Theme.corner(row, Theme.corner.chip)
		Theme.stroke(row)
		local titleLabel = Theme.label(row, title, "body", "textPrimary")
		titleLabel.Name = "Title"
		titleLabel.Position = UDim2.new(0, 10, 0, 6)
		titleLabel.Size = UDim2.new(1, -20, 0, titleSize + 4)
		local subtitleLabel = Theme.label(row, subtitle, "caption", "textSecondary")
		subtitleLabel.Name = "Subtitle"
		subtitleLabel.Position = UDim2.new(0, 10, 0, 10 + titleSize)
		subtitleLabel.Size = UDim2.new(1, -20, 0, captionSize + 4)
	end
end

-- 목록을 받아 연다(서버 GiftPopup · 점검 · 스크린샷 공통). 반환: 열렸는가
function GiftPopup.show(gifts)
	if type(gifts) ~= "table" or #gifts == 0 then
		return false
	end
	lastGifts = gifts
	Theme.recompute()
	local w, h = screenSize()
	local size, buttonH = GiftPopup.sizeFor(w, h, Theme.isMobile)
	if built and (built.size ~= size or built.buttonH ~= buttonH or built.mobile ~= Theme.isMobile) then
		destroy()
	end
	if not built then
		build(size, buttonH)
	end
	fill(gifts)
	built.panel.titleLabel.Text = Text.get("gift.titleCount", { n = tostring(#gifts) })
	if UIManager.isOpen(GiftPopup.id) then
		return true
	end
	return UIManager.open(GiftPopup.id)
end

function GiftPopup.lastGifts()
	return lastGifts
end

function GiftPopup.debugBuilt()
	return built
end

function GiftPopup.start(send)
	sendRequest = send
	local remote = ReplicatedStorage:WaitForChild("GiftPopup")
	remote.OnClientEvent:Connect(function(gifts)
		-- 접속 직후 다른 창(직업 선택 등)이 뜨는 중일 수 있다 - 한 박자 뒤에 연다
		task.delay(1, function()
			if Players.LocalPlayer.Parent then
				GiftPopup.show(gifts)
			end
		end)
	end)
end

return GiftPopup
