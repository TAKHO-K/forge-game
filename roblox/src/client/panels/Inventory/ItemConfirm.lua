-- 개별 판매 · 분해 · 잠금 해제 확인 창(S21-0 B2 - QUEUE-ALL2 P2에서 DetailSheet 밖으로 옮겼다. 동작은 그대로).
-- 영웅 등급 이상의 판매 · 분해는 되돌릴 수 없어 한 번 더 묻는다(BulkSell.confirmOverlay와 같은 구조 - 창 자식으로 딤 + 패널, ZIndex 22/23). 태초 · 초월 잠금 해제는 두 번 묻는다(D1 ⑦).
-- ItemConfirm.create(content, player) -> { ask(text, color, action), askTwice(first, second, action), item(verb, item, action, isGem) }
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local GemCraft = require(ReplicatedStorage.Shared.GemCraft)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local ItemConfirm = {}

function ItemConfirm.create(content, player)
	local overlay = Instance.new("TextButton")
	overlay.Name = "ItemConfirm"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Visible = false
	overlay.ZIndex = 22
	overlay.Parent = content

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(0.5, 0, 0.5, 0)
	box.Size = UDim2.new(0, 300, 0, 132)
	box.BackgroundColor3 = UIColors.panel
	box.BackgroundTransparency = 0.05
	box.ZIndex = 23
	box.Parent = overlay
	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 10)
	boxCorner.Parent = box
	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = UIColors.rim
	boxStroke.Transparency = UIColors.rimTransparency
	boxStroke.Parent = box

	local text = Instance.new("TextLabel")
	text.Position = UDim2.new(0, 16, 0, 14)
	text.Size = UDim2.new(1, -32, 0, 60)
	text.BackgroundTransparency = 1
	text.ZIndex = 23
	text.Font = Enum.Font.GothamBold
	text.TextSize = Theme.textSize("body")
	text.TextWrapped = true
	text.TextColor3 = UIColors.textPrimary
	text.Text = ""
	text.Parent = box

	local function makeButton(label, x, danger)
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, x, 1, -12)
		button.Size = UDim2.new(0, 44, 0, 44)
		button.BackgroundColor3 = danger and UIColors.danger or UIColors.panel
		button.BackgroundTransparency = danger and 0.55 or UIColors.panelTransparency
		button.Text = label
		button.Font = Enum.Font.GothamBold
		button.TextSize = Theme.textSize("body")
		button.TextColor3 = danger and Color3.fromRGB(255, 200, 200) or UIColors.textPrimary
		button.ZIndex = 23
		button.Parent = box
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button
		return button
	end
	local yes = makeButton(Text.get("gear.confirm.ok"), -12, true) -- 위험 버튼 = 빨강 오른쪽
	local no = makeButton(Text.get("gear.confirm.cancel"), -64, false)

	local pending -- 확인을 누르면 실행할 함수(취소 · 바깥 클릭이면 버린다)
	local function close()
		overlay.Visible = false
		pending = nil
	end
	no.Activated:Connect(close)
	overlay.Activated:Connect(close)
	yes.Activated:Connect(function()
		local action = pending
		close()
		if action then
			action()
		end
	end)

	local self = {}
	function self.ask(message, color, action)
		text.Text = message
		text.TextColor3 = color or UIColors.textPrimary
		pending = action
		overlay.Visible = true
	end

	-- 두 번 묻기(태초 · 초월 잠금 해제): 첫 확인 → 둘째 문구로 다시 → 둘째 확인에서 action
	function self.askTwice(first, second, action)
		self.ask(first, UIColors.textPrimary, function()
			self.ask(second, UIColors.textPrimary, action)
		end)
	end

	-- verb: "판매" | "분해". isGem(P2.5b C): 보석 - 이름은 ItemDescribe.gem · 얻는 골드 / 가루를 같이 적는다.
	function self.item(verb, item, action, isGem)
		local visual = ItemVisualData.gradeVisuals[item.grade]
		local described = isGem and ItemDescribe.gem(item) or ItemDescribe.item(item, player:GetAttribute("ClassId"))
		local args = { name = described.title, grade = ArmorData.grades[item.grade].displayName }
		local key = verb == "판매" and "gear.confirm.sell" or "gear.confirm.dismantle"
		if isGem and verb == "판매" then -- P3c E4
			key = "gear.confirm.sellGem"
			args.gold = NumberFormat.currency(GemCraft.sellPrice(item, player:GetAttribute("AccountBestStage") or 1), Text.languageFor())
		elseif isGem then
			key = "gear.confirm.dismantleGem"
			args.dust = ("%d"):format(GemCraft.dustYield(item))
		end
		local message = Text.get(key, args)
		if not isGem then -- QUEUE-ALL9C 1-10: 분해 · 판매 결과를 나란히(분해 가능한 장비 = 확인 창이 뜨는 장비)
			message ..= "\n" .. ItemConfirm.rewardLine(item)
		end
		self.ask(message, visual and visual.color or UIColors.textPrimary, action) -- G1-1: 태초도 제 색
	end

	return self
end

-- QUEUE-ALL9C 1-10 "분해 시: 보석 · 판매 시: 골드" 한 줄(값 = 서버와 같은 Loot.dismantleReward · Loot.getSellPrice · GemCraft.dustYield)
function ItemConfirm.rewardLine(item)
	local gem = Loot.dismantleReward(item)
	return Text.get("gear.reward.line", { grade = ArmorData.grades[gem.grade] and ArmorData.grades[gem.grade].displayName or gem.grade, level = ("%d"):format(gem.itemLevel or 1),
		dust = ("%d"):format(GemCraft.dustYield(gem)), gold = NumberFormat.currency(Loot.getSellPrice(item), Text.languageFor()) })
end

return ItemConfirm
