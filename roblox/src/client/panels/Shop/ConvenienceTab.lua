-- 상점 [편의] 탭(QUEUE-B1 B2 UI · QUEUE-ALL9C 1-6R 카드): 게임패스(편의만 - 전투력 · 획득량 없음) = 가방 · 줍기 · 귀환 · 이름표 색/배지(이름표 세트 = 둘 다 없는 사람에게만).
--   요청 = ShopRequest("buyPass", key) → 서버가 Roblox 구매 창을 연다. 효과 수치는 MonetizationData.gamePasses를 읽어 문장 인자로 넘긴다(여기에 숫자 없음).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat) -- MULT-PCT 배율 표시

local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
local Text = require(ReplicatedStorage.Shared.Text)
local Catalog = require(script.Parent.Catalog)

local ConvenienceTab = {}

ConvenienceTab.order = { "bagExpand", "pickupRadius", "recallCooldown", "nameplateColor", "nameplateBadge", "nameplateSet" }

local function describeArgs(key)
	local pass = MonetizationData.gamePasses[key]
	return {
		slots = tostring(pass.bonusSlots or 0),
		mult = NumberFormat.multiplier(pass.radiusMultiplier or pass.cooldownMultiplier or 1), -- MULT-PCT
		count = tostring((pass.colors and #pass.colors) or (pass.badges and #pass.badges) or 0),
	}
end

-- 게임패스 카드 하나(치장 탭 이름표 칩도 쓴다) · 가방 = 지금 칸 → 산 뒤 칸(서버 capacity 값)
function ConvenienceTab.passCard(env, key)
	local view = env.state.view
	local pass = view.passes[key]
	local title, subtitle = Text.get("shop.pass." .. key .. ".name"), Text.get("shop.pass." .. key .. ".desc", describeArgs(key))
	if key == "bagExpand" and view.bag then
		subtitle = pass.owned and Text.get("shop.bag.ownedLine", { n = tostring(view.bag.slots), max = tostring(view.bag.max) })
			or Text.get("shop.bag.line", { n = tostring(view.bag.slots), m = tostring(math.min(view.bag.slots + view.bag.passSlots, view.bag.max)), max = tostring(view.bag.max) })
	end
	return Catalog.passCard(env, key, title, subtitle)
end

-- keys(선택) = 이 게임패스만 · 없으면 편의 탭 전부 + 안내 줄
function ConvenienceTab.render(ctx, env, keys)
	local view = env.state.view
	if not keys then
		ctx.line(Text.get("shop.pass.note"), "textSecondary", 2, "PassNote")
	end
	local specs = {}
	for _, key in ipairs(keys or ConvenienceTab.order) do
		if Catalog.passVisible(view, key) then
			table.insert(specs, ConvenienceTab.passCard(env, key))
		end
	end
	ctx.cards("PassCards", specs)
end

return ConvenienceTab
