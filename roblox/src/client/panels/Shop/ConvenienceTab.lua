-- 상점 [편의] 탭(QUEUE-B1 B2 UI) - 게임패스 4(편의만 - 전투력 · 획득량 없음): 설명 · 가격 · 보유 · 구매 버튼. 요청 = ShopRequest("buyPass", key) → 서버가 Roblox 구매 창을 연다.
--   효과 수치는 MonetizationData.gamePasses를 읽어 문장 인자로 넘긴다(여기에 숫자 없음). 가격 = view.passes[key].robux(자리값 - Creator Hub 값이 우선).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
local Text = require(ReplicatedStorage.Shared.Text)

local ConvenienceTab = {}

ConvenienceTab.order = { "bagExpand", "pickupRadius", "recallCooldown", "nameplateColor", "nameplateBadge", "nameplateSet" }

local function describeArgs(key)
	local pass = MonetizationData.gamePasses[key]
	return {
		slots = tostring(pass.bonusSlots or 0),
		mult = ("%g"):format(pass.radiusMultiplier or pass.cooldownMultiplier or 1),
		count = tostring((pass.colors and #pass.colors) or (pass.badges and #pass.badges) or 0),
	}
end

-- keys(선택) = 이 게임패스만(추천 탭) · 없으면 전부 + 안내 줄
function ConvenienceTab.render(ctx, env, keys)
	local view = env.state.view
	if not view then
		ctx.line(Text.get("shop.loading"), "textSecondary", 1, "Loading")
		return
	end
	if not keys then
		ctx.line(Text.get("shop.pass.note"), "textSecondary", 2, "PassNote")
	end
	for _, key in ipairs(keys or ConvenienceTab.order) do
		local pass = view.passes and view.passes[key]
		local def = MonetizationData.gamePasses[key]
		local hiddenBySet = false -- QUEUE-ALL9C 1-6 이름표 세트 = 색 · 배지 둘 다 없는 사람에게만
		for _, other in ipairs(def and def.onlyWithout or {}) do
			hiddenBySet = hiddenBySet or (view.passes[other] and view.passes[other].owned == true)
		end
		if pass and pass.released ~= false and not hiddenBySet then
			local button
			local title, subtitle = Text.get("shop.pass." .. key .. ".name"), Text.get("shop.pass." .. key .. ".desc", describeArgs(key))
			if key == "bagExpand" and view.bag then -- QUEUE-ALL9C 1-6 가방: 지금 칸 → 산 뒤 칸(서버 capacity 값) · 둘 중 어느 쪽을 먼저 사도 손해 없음
				subtitle = pass.owned and Text.get("shop.bag.ownedLine", { n = tostring(view.bag.slots), max = tostring(view.bag.max) })
					or Text.get("shop.bag.line", { n = tostring(view.bag.slots), m = tostring(math.min(view.bag.slots + view.bag.passSlots, view.bag.max)), max = tostring(view.bag.max) })
			end
			if pass.owned then
				button = { name = "Pass_" .. key, text = Text.get("shop.ownedCheck"), enabled = false, width = 104 }
			elseif not pass.ready then
				button = { name = "Pass_" .. key, text = Text.get("shop.notReady"), enabled = false, width = 104 }
			else
				local price = env.passPrice(key) or pass.robux
				button = { name = "Pass_" .. key, text = Text.get("shop.priceNumber", { n = tostring(price) }), icon = "robux", kind = "primary", width = 104, enabled = not env.busy(),
					onActivated = function()
						env.confirmRobux({ title = title, body = subtitle }, price, function()
							env.send("buyPass", key)
						end)
					end }
			end
			ctx.row({
				name = "PassRow_" .. key,
				title = title,
				titleColor = pass.owned and "success" or nil,
				subtitle = subtitle,
				buttons = { button },
			})
		end
	end
end

return ConvenienceTab
