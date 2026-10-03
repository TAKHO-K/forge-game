-- 상점 [추천] 탭(QUEUE-ALL9C 1-6R · 사용자 10-03 - 왼쪽 메뉴 금색 상점 버튼이 여는 첫 탭):
--   ① 받을 선물(있을 때) ② 맨 위 큰 배너 1개 = 스타터 팩(노출 조건 안 · 안 산 사람) · 아니면 시즌 패스 유료 줄(안 산 사람)
--   ③ "이번 주 추천" 카드 4개(UTC 월요일 00:00 교체 · MonetizationData.weeklyFeatured 후보 표 · 다음 교체까지 남은 시간만 - 깜빡임 · 압박 문구 없음) ④ 시즌 패스 카드.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local Text = require(ReplicatedStorage.Shared.Text)
local Catalog = require(script.Parent.Catalog)
local StarterTab = require(script.Parent.StarterTab)

local RecommendTab = {}

-- 이번 주 추천 키(공개 · 판매 중 치장만) · 다음 교체 UTC
function RecommendTab.weekly(view, unixNow)
	return Monetization.weeklyFeatured(MonetizationData, unixNow, function(key)
		if not Catalog.productVisible(view, key) then
			return false
		end
		local kind, entry = Catalog.firstGrant(key)
		return entry ~= nil and Monetization.onSale(CosmeticSlotData, kind, entry.id)
	end)
end

function RecommendTab.render(ctx, env)
	local view = env.state.view
	if (view.gifts or 0) > 0 then
		ctx.row({
			name = "Gifts",
			title = Text.get("gift.pending", { n = tostring(view.gifts) }),
			highlight = true,
			buttons = { { name = "GiftsClaim", text = Text.get("gift.claimAll"), kind = "primary", width = 110, enabled = not env.busy(), onActivated = function()
				env.send("giftClaim", "all")
			end } },
		})
	end
	-- ② 배너
	if StarterTab.visible(view) and not (view.starter and view.starter.owned) then
		StarterTab.banner(ctx, env)
	elseif view.season and not view.season.premium then
		local spec = env.robuxSpec("season_premium")
		ctx.banner({ name = "BannerSeason", title = Text.get("season.premiumTitle"), body = Text.get("season.premiumSub"), button = spec,
			picture = Catalog.iconPicture("icons/reward/passExp", "★"), onOpen = function()
				env.selectTab("season")
			end })
	end
	-- ③ 이번 주 추천
	local unixNow = workspace:GetServerTimeNow()
	local keys, nextSwap = RecommendTab.weekly(view, unixNow)
	if #keys > 0 then
		ctx.section(Text.get("shop.weekly.title"), "WeeklyTitle")
		local left = math.max(0, nextSwap - unixNow)
		ctx.line(Text.get("shop.weekly.next", { d = tostring(math.floor(left / 86400)), h = tostring(math.floor(left % 86400 / 3600)) }), "textSecondary", 1, "WeeklyNext")
		local specs = {}
		for _, key in ipairs(keys) do
			table.insert(specs, Catalog.productCard(env, key))
		end
		ctx.cards("WeeklyCards", specs)
	end
	-- ④ 시즌 패스 카드
	if view.season then
		ctx.section(Text.get("shop.tab.season"), "SeasonCardTitle")
		ctx.cards("SeasonCards", { Catalog.seasonCard(env, env.robuxSpec("season_premium")) })
	end
end

return RecommendTab
