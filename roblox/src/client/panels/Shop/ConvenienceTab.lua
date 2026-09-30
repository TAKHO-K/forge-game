-- 상점 [편의] 탭(QUEUE-B1 B2 UI) - 게임패스 4(편의만 - 전투력 · 획득량 없음): 설명 · 가격 · 보유 · 구매 버튼. 요청 = ShopRequest("buyPass", key) → 서버가 Roblox 구매 창을 연다.
--   효과 수치는 MonetizationData.gamePasses를 읽어 문장 인자로 넘긴다(여기에 숫자 없음). 가격 = view.passes[key].robux(자리값 - Creator Hub 값이 우선).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
local Text = require(ReplicatedStorage.Shared.Text)

local ConvenienceTab = {}

ConvenienceTab.order = { "bagExpand", "pickupRadius", "recallCooldown", "nameplateColor", "nameplateBadge" }

local function describeArgs(key)
	local pass = MonetizationData.gamePasses[key]
	return {
		slots = tostring(pass.bonusSlots or 0),
		mult = ("%g"):format(pass.radiusMultiplier or pass.cooldownMultiplier or 1),
		count = tostring((pass.colors and #pass.colors) or (pass.badges and #pass.badges) or 0),
	}
end

function ConvenienceTab.render(ctx, env)
	local view = env.state.view
	if not view then
		ctx.line(Text.get("shop.loading"), "textSecondary", 1, "Loading")
		return
	end
	ctx.line(Text.get("shop.pass.note"), "textSecondary", 2, "PassNote")
	for _, key in ipairs(ConvenienceTab.order) do
		local pass = view.passes and view.passes[key]
		if pass then
			local button
			if pass.owned then
				button = { name = "Pass_" .. key, text = Text.get("shop.owned"), enabled = false }
			elseif not pass.ready then
				button = { name = "Pass_" .. key, text = Text.get("shop.notReady"), enabled = false, width = 104 }
			else
				button = { name = "Pass_" .. key, text = Text.get("shop.robuxPrice", { n = tostring(pass.robux) }), kind = "primary", width = 104, enabled = not env.busy(),
					onActivated = function()
						env.send("buyPass", key)
					end }
			end
			ctx.row({
				name = "PassRow_" .. key,
				title = Text.get("shop.pass." .. key .. ".name"),
				titleColor = pass.owned and "success" or nil,
				subtitle = Text.get("shop.pass." .. key .. ".desc", describeArgs(key)),
				buttons = { button },
			})
		end
	end
end

return ConvenienceTab
