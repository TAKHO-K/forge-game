-- QUEUE-ALL9C 1-6R 가격 버튼 중앙 자동 검사(Studio 전용): Player Attribute DebugPriceButtonCheck = "pc" | "phone"을 켜면
--   자릿수 2 · 3 · 4 · 5 × 로벅스 · 토큰 · 골드(+ 상태 버튼 보유 중 · 착용 · 앞 글 붙은 구매 확인 · 강화 모양)를 kit/PriceButton으로 실제로 만들고
--   "묶음 가운데 − 버튼 가운데"(AbsolutePosition · AbsoluteSize - x · y 중 큰 쪽)를 잰다. 결과 = 출력 줄 "[PRICEBTN]" + Attribute PriceButtonCheckResult("통과 n/m · 최대 오차 x px").
--   폰 = ForceTouchLayout을 잠깐 켜 Theme(버튼 44 · 글씨 ×1.15)을 다시 계산한다(끝나면 원래 값). 화면은 지우지 않고 남겨 둔다(캡처용 - Attribute를 끄면 지운다).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
local PriceButton = require(script.Parent.ui.kit.PriceButton)
local Theme = require(script.Parent.ui.kit.Theme)
local Text = require(game:GetService("ReplicatedStorage").Shared.Text)

local AMOUNTS = { 49, 199, 4999, 12345 } -- 2 · 3 · 4 · 5자리(49 = 2자리)
local CURRENCIES = { "robux", "token", "gold" }
local gui

local function run(mode)
	if gui then
		gui:Destroy()
	end
	local forced = player:GetAttribute("ForceTouchLayout")
	player:SetAttribute("ForceTouchLayout", mode == "phone")
	Theme.recompute()
	gui = Instance.new("ScreenGui")
	gui.Name = "PriceButtonCheckGui"
	gui.DisplayOrder = 200
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	back.Position = UDim2.fromOffset(80, 20)
	back.Size = UDim2.fromOffset(4 * 140 + 40, 6 * (Theme.buttonHeight + 12) + 40)
	back.Parent = gui
	local list = {}
	local width = mode == "phone" and 130 or 120 -- 카드 버튼 폭에 가까운 값
	for row, currency in ipairs(CURRENCIES) do
		for col, amount in ipairs(AMOUNTS) do
			local b = PriceButton.build({ parent = back, name = ("%s_%d"):format(currency, amount), currency = currency, amount = amount, width = width,
				position = UDim2.fromOffset(20 + (col - 1) * 140, 20 + (row - 1) * (Theme.buttonHeight + 12)) })
			table.insert(list, { label = ("%s %d"):format(currency, amount), refs = b })
		end
	end
	local extras = {
		{ label = "owned", spec = { text = Text.get("shop.ownedCheck"), kind = "secondary" } },
		{ label = "equip", spec = { text = Text.get("shop.card.equip"), kind = "secondary" } },
		{ label = "equipped", spec = { text = Text.get("shop.card.equipped"), kind = "secondary" } },
		{ label = "confirm", spec = { label = Text.get("shop.confirm.buyLabel"), currency = "robux", amount = 199 } },
		{ label = "enhance", spec = { label = Text.get("forge.enhance.button"), currency = "gold", amount = 123456 } },
	}
	for i, e in ipairs(extras) do
		local spec = table.clone(e.spec)
		spec.parent, spec.name, spec.width = back, "Extra_" .. e.label, i >= 4 and 200 or width
		local row, col = 3 + math.floor((i - 1) / 3), (i - 1) % 3
		spec.position = UDim2.fromOffset(20 + col * 210, 20 + row * (Theme.buttonHeight + 12))
		table.insert(list, { label = e.label, refs = PriceButton.build(spec) })
	end
	task.wait(0.3) -- 배치(AutomaticSize · UIListLayout) 반영
	local pass, worst = 0, 0
	for _, item in ipairs(list) do
		local err = PriceButton.centerError(item.refs)
		worst = math.max(worst, err)
		local ok = err <= 1
		pass += ok and 1 or 0
		print(("[PRICEBTN] %s %s 오차 %.2fpx 묶음 %s %s"):format(mode, item.label, err, tostring(item.refs.bundle.AbsoluteSize), ok and "O" or "X"))
	end
	local result = ("%s 통과 %d/%d · 최대 오차 %.2fpx"):format(mode, pass, #list, worst)
	print("[PRICEBTN] " .. result)
	player:SetAttribute("PriceButtonCheckResult", result)
	player:SetAttribute("ForceTouchLayout", forced)
	Theme.recompute()
end

player:GetAttributeChangedSignal("DebugPriceButtonCheck"):Connect(function()
	local mode = player:GetAttribute("DebugPriceButtonCheck")
	if mode == "pc" or mode == "phone" then
		run(mode)
	elseif gui then
		gui:Destroy()
		gui = nil
	end
end)
