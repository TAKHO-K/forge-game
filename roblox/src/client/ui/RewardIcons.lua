-- QUEUE-ALL3 Q1 · Q3 공용: 보상 표({ gold = n, enhanceStone = n, … }) → 그림 + 수량 줄(글자 설명 없음 - 10 문서 "보상 그림 + 수량"). 그림 = icons/reward/<id>(업로드 - ArtImage) · 없으면 짧은 글자.
--   gold 값 = "몇 마리분" → 화면 수량 = 서버 QuestService.grant와 같은 식(GoldCost "quest" × 계정 최고 스테이지 Attribute AccountBestStage) · 짧은 수(NumberFormat).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.kit.Theme)
local ArtImage = require(script.Parent.ArtImage)
local RewardDetail = require(script.Parent.RewardDetail)

local RewardIcons = {}

-- 보상 키 → 아이콘 id(icons/reward/_map.json과 같은 이름) · 순서
RewardIcons.order = { "gold", "goldKills", "enhanceStone", "highEnhanceStone", "egg", "gemDust", "sparkleShard", "protectDrop", "protectReset", "rerollTicket", "rebirthTicket", "passExp", "title", "cosmeticItem" }
RewardIcons.icon = { gold = "gold", goldKills = "gold", enhanceStone = "enhanceStone", highEnhanceStone = "highEnhanceStone", egg = "egg", eggZone = "egg", gemDust = "gemDust",
	sparkleShard = "sparkleShard", protectDrop = "protectDrop", protectReset = "protectReset", rerollTicket = "rerollTicket", rebirthTicket = "rebirthTicket", passExp = "passExp", title = "title", cosmeticItem = "cosmeticTheme" } -- QUEUE-ALL9B 5 출석판 소품(치장 그림 · 개수 없음)
local NO_QTY = { title = true, cosmeticItem = true }
local SHORT = { gold = "G", goldKills = "G", passExp = "EXP" }
local SHORT_KEY = { enhanceStone = "ui.reward.short.enhanceStone", egg = "ui.reward.short.egg", gemDust = "ui.reward.short.gemDust", sparkleShard = "ui.reward.short.sparkleShard", protectDrop = "ui.reward.short.protectDrop", title = "ui.reward.short.title", rebirthTicket = "ui.reward.short.rebirthTicket" }

-- 몇 마리분 → 실제 골드 글자(서버 grant와 같은 식)
function RewardIcons.goldText(kills)
	local best = Players.LocalPlayer:GetAttribute("AccountBestStage") or 1
	return NumberFormat.format(GoldCost.rewardGold(MonsterData.tier1.goldDrop, kills, best)) -- QUEUE-ALL6 D: 서버 지급과 같은 값
end

-- parent 안에 가로 줄(UIListLayout)로 그린다. size = 아이콘 한 변(px). 반환 = 줄 Frame
--   QUEUE-ALL6 C: 칸 = 투명 버튼 - 누르면 상세 카드(RewardDetail - 이름 · 한 줄 설명 · 가진 개수) · PC 마우스 올림도 같은 카드. opts.noDetail = 끔.
function RewardIcons.row(parent, reward, size, opts)
	opts = opts or {}
	size = size or 28
	local row = Instance.new("Frame")
	row.Name = opts.name or "RewardRow"
	row.BackgroundTransparency = 1
	row.Size = opts.frameSize or UDim2.new(1, 0, 0, size)
	row.Position = opts.position or UDim2.new()
	row.AnchorPoint = opts.anchorPoint or Vector2.zero
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = opts.align or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for i, key in ipairs(RewardIcons.order) do
		local v = reward and reward[key]
		if v and v ~= 0 then
			local cell = Instance.new(opts.noDetail and "Frame" or "TextButton")
			cell.Name = "R_" .. key
			cell.LayoutOrder = i
			cell.BackgroundTransparency = 1
			if cell:IsA("TextButton") then
				cell.Text = ""
				cell.AutoButtonColor = false
			end
			cell.Size = UDim2.fromOffset(NO_QTY[key] and size or size + 34, size)
			cell.Parent = row
			local img = ArtImage.label(cell, "icons/reward/" .. (RewardIcons.icon[key] or key), UDim2.fromOffset(size, size), SHORT[key] or (SHORT_KEY[key] and Text.get(SHORT_KEY[key])) or "?")
			img.Name = "Icon"
			if not NO_QTY[key] then
				local qty = Instance.new("TextLabel")
				qty.Name = "Qty"
				qty.BackgroundTransparency = 1
				qty.Position = UDim2.fromOffset(size + 2, 0)
				qty.Size = UDim2.new(0, 32, 1, 0)
				qty.Font = Theme.font
				qty.TextSize = math.max(12, math.floor(size * 0.5))
				qty.TextColor3 = Theme.color("textPrimary")
				qty.TextStrokeTransparency = 0.4
				qty.TextXAlignment = Enum.TextXAlignment.Left
				qty.Text = (key == "gold" or key == "goldKills") and (opts.goldText or RewardIcons.goldText(v)) or ("×" .. tostring(v))
				qty.Parent = cell
			end
			if not opts.noDetail then
				local qtyText = not NO_QTY[key] and ((key == "gold" or key == "goldKills") and (opts.goldText or RewardIcons.goldText(v)) or ("×" .. tostring(v))) or nil
				RewardDetail.attach(cell, key, qtyText)
			end
		end
	end
	return row
end

return RewardIcons
