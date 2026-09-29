-- 상점 [골드] 탭(QUEUE-B1 B2 UI) - 기존 골드 소모처를 한곳에 모은 입구. 새 Remote · 새 가격 0(서버 규칙 · 가격 · 근접 확인은 그대로):
--   ① 방지권 하락 · 초기화 = 강화 패널과 같은 입구(panels/Enhance/Controller.requestBuy - 가격 조회 ProtectionTicketPriceRequest → 확인창 → ProtectionTicketBuyRequest)
--   ② 변환권 고대 · 태초 = 보석 공방과 같은 요청(BuyRerollTicketRequest - 결과 GemWorkshopResult) · 가격 식은 보석 공방(GemWorkshop.ticketPrice)과 같은 GoldCost
--   ③ [보석 도구] = 기존 보석 공방 창(panels/GemWorkshop)을 연다(같은 station 자리라 상점은 닫힌다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local GemCraft = require(ReplicatedStorage.Shared.GemCraft)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)

local GoldTab = {}

local player = Players.LocalPlayer
local PROTECTION_KINDS = { "drop", "reset" }
local REROLL_GRADES = { "ancient", "primordial" }

-- 변환권 골드 가격(서버 GemServer.rerollTicketPrice · 보석 공방 ticketPrice와 같은 식 - 기준 = 계정 최고 스테이지 Attribute)
function GoldTab.rerollTicketPrice()
	local stage = player:GetAttribute("AccountBestStage") or 1
	return GoldCost.cost(MonsterData.tier1.goldDrop, stage, "rerollTicket") * GemData.rerollTicketGoldMultiplier
end

local function protectionCount(kind)
	return player:GetAttribute("Protection" .. kind:sub(1, 1):upper() .. kind:sub(2)) or 0
end

-- ctx = Rows ctx · env = init의 환경(state · send · requestProtection · buyReroll · openGemTools · busy)
function GoldTab.render(ctx, env)
	ctx.section(Text.get("shop.gold.protectionSection"), "ProtectionSection")
	for _, kind in ipairs(PROTECTION_KINDS) do
		local config = EnhanceConfig.protection[kind]
		ctx.row({
			name = "Protection_" .. kind,
			title = Text.get("shop.gold.protectionRow", { name = config.displayName, count = tostring(protectionCount(kind)) }),
			subtitle = Text.get("shop.gold.protectionSub"),
			buttons = { { name = "Buy_protection_" .. kind, text = Text.get("shop.buy"), kind = "primary", enabled = not env.busy(), onActivated = function()
				env.requestProtection(kind)
			end } },
		})
	end

	local gold = player:GetAttribute("Gold") or 0
	local dustOwned = player:GetAttribute("GemDust") or 0
	local price = GoldTab.rerollTicketPrice()
	ctx.section(Text.get("shop.gold.rerollSection", { dust = NumberFormat.format(dustOwned) }), "RerollSection")
	for _, gradeId in ipairs(REROLL_GRADES) do
		local grade = ArmorData.grades[gradeId]
		local dustPrice = GemCraft.ticketDust(gradeId)
		local affordable = gold >= price and dustOwned >= dustPrice
		ctx.row({
			name = "Reroll_" .. gradeId,
			title = Text.get("shop.gold.rerollRow", { grade = grade and grade.displayName or gradeId, count = tostring(env.state.rerollTickets[gradeId] or 0) }),
			subtitle = Text.get(affordable and "shop.gold.rerollPrice" or "shop.gold.rerollPriceShort", { gold = NumberFormat.format(price), dust = tostring(dustPrice) }),
			buttons = { { name = "Buy_reroll_" .. gradeId, text = Text.get("shop.buy"), kind = "primary", enabled = affordable and not env.busy(), onActivated = function()
				env.buyReroll(gradeId)
			end } },
		})
	end

	ctx.section(Text.get("shop.gold.toolsSection"), "ToolsSection")
	ctx.row({
		name = "GemTools",
		title = Text.get("shop.gold.gemTools"),
		subtitle = Text.get("shop.gold.gemToolsSub"),
		buttons = { { name = "OpenGemTools", text = Text.get("shop.open"), onActivated = env.openGemTools } },
	})
end

return GoldTab
