-- 상점 [스타터] 구역(QUEUE-ALL9C 1-6 - monetization 확정안): 모험가 스타터 팩 199(가방 +20 · 스타터 외형 2종 · 계정당 1회).
--   보이는 때 = 서버 view.starter.visible(첫 보스 처치 또는 상점 두 번째 방문 - 안 산 사람) 또는 이미 산 사람(보유 중 ✓). 타이머 · 깜빡임 · 압박 문구 없음.
--   가방 줄 = 서버 capacity 값(view.bag): "가방 n칸 → 구매 후 n+20칸 (최대 75칸)" - 가방 확장 패스 줄도 같은 형식(어느 쪽을 먼저 사도 손해 없음).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)

local StarterTab = {}

function StarterTab.visible(view)
	local s = type(view) == "table" and view.starter
	local p = view and view.products and view.products.starter_pack
	return s ~= nil and p ~= nil and p.released ~= false and (s.visible == true or s.owned == true)
end

function StarterTab.render(ctx, env)
	local view = env.state.view
	local bag = view.bag or { slots = 0, max = 75, starterSlots = 20 }
	local owned = view.starter and view.starter.owned
	ctx.line(Text.get("shop.starter.desc"), "textSecondary", 3, "StarterDesc")
	local bagLine = owned and Text.get("shop.bag.ownedLine", { n = tostring(bag.slots), max = tostring(bag.max) })
		or Text.get("shop.bag.line", { n = tostring(bag.slots), m = tostring(math.min(bag.slots + bag.starterSlots, bag.max)), max = tostring(bag.max) })
	local button = owned and { name = "StarterOwned", text = Text.get("shop.ownedCheck"), width = 104, enabled = false }
		or env.robuxButton("starter_pack", "StarterBuy", { title = Text.get("shop.starter.name"), body = Text.get("shop.starter.desc") .. "\n" .. bagLine })
	ctx.row({
		name = "Starter",
		title = Text.get("shop.starter.name"),
		titleColor = owned and "success" or nil,
		subtitle = bagLine,
		highlight = not owned,
		buttons = { button },
	})
end

return StarterTab
