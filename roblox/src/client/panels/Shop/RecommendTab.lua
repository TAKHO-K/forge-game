-- 상점 [추천] 탭(QUEUE-ALL2 P2 B-4 ① - 왼쪽 메뉴 금색 상점 버튼이 여는 첫 탭): 시즌 패스 유료 줄(안 샀으면) · 아직 안 산 치장 테마 1 · 글라이더 1 · 편의 패스 2.
--   새 상품 없음 - 다른 탭의 행 그리기(CosmeticTab.saleRow · ConvenienceTab.render)를 그대로 쓴다. 규칙 = monetization-p4c(돈으로 강해지지 않음 · 유료 랜덤 없음 · checkCatalog).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local Text = require(ReplicatedStorage.Shared.Text)
local CosmeticTab = require(script.Parent.CosmeticTab)
local ConvenienceTab = require(script.Parent.ConvenienceTab)

local RecommendTab = {}

RecommendTab.passes = { "recallCooldown", "bagExpand" }

local function firstUnowned(list, ownedMap)
	for _, entry in ipairs(list) do
		if not entry.seasonOnly and not (ownedMap and ownedMap[entry.id]) then
			return entry
		end
	end
	return nil
end

function RecommendTab.render(ctx, env)
	local view = env.state.view
	if not view then
		ctx.line(Text.get("shop.loading"), "textSecondary", 1, "Loading")
		return
	end
	ctx.line(Text.get("shop.recommend.note"), "textSecondary", 1, "RecommendNote")
	if view.season and not view.season.premium then
		ctx.row({ name = "Premium", title = Text.get("season.premiumTitle"), subtitle = Text.get("season.premiumSub"), highlight = true,
			buttons = { env.robuxButton("season_premium", "PremiumBuy") } })
	end
	local theme = firstUnowned(CosmeticSlotData.sets, view.themes)
	if theme then
		CosmeticTab.saleRow(ctx, env, view, "cosmeticTheme", theme, false, (view.productTokens or {})["theme_" .. theme.id], "theme_" .. theme.id, "shop.cos.themeSub")
	end
	local skin = firstUnowned(CosmeticSlotData.gliderSkins, view.gliderSkins)
	if skin then
		CosmeticTab.saleRow(ctx, env, view, "gliderSkin", skin, false, (view.productTokens or {})["glider_" .. skin.id], "glider_" .. skin.id, "shop.cos.gliderSub")
	end
	ConvenienceTab.render(ctx, env, RecommendTab.passes)
end

return RecommendTab
