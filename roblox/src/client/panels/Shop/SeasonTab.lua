-- 상점 [시즌] 탭(QUEUE-B1 B2 UI) - 시즌 패스 8주. 화면 = ShopSync 표의 season(SeasonPassService.view) 그대로 · 받기 = ShopRequest("seasonClaim", "free"|"paid", 칸).
--   머리: 시즌 번호 · 남은 날 · 경험치 막대(지금 칸 안 진행) · 유료 줄 잠금이면 [유료 줄 열기](로벅스 상품 season_premium) · 알(랜덤) 표시 안내.
--   본문: 40칸 × (무료 | 유료) 두 칸 - 세로 스크롤(폰에서 가로 스크롤보다 엄지로 넘기기 쉽다). 칸마다 보상 글 + [받기](받음 · 미도달 · 유료 잠김 = 회색).
--   받을 수 있나 판정은 서버 Monetization.canClaim과 같은 조건(도달 · 안 받음 · 유료 줄은 premium)을 화면 표시에만 쓴다 - 서버가 다시 잰다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Layout = require(script.Parent.Layout)
local CosmeticTab = require(script.Parent.CosmeticTab)
local RewardDetail = require(script.Parent.Parent.Parent.ui.RewardDetail)

local SeasonTab = {}

local TIER_COL = 44 -- 칸 번호 열 폭
local DAY = 86400

-- 보상 표 → 한 문장(키 하나 = 한 조합 - 조각 이어붙이기 대신 조합마다 템플릿). egg가 있으면 랜덤 표시.
function SeasonTab.rewardText(reward)
	if type(reward) ~= "table" then
		return ""
	end
	if reward.cosmeticTheme then
		return Text.get("season.reward.theme", { name = CosmeticTab.nameOf("cosmeticTheme", reward.cosmeticTheme) })
	elseif reward.gliderSkin then
		return Text.get("season.reward.glider", { name = CosmeticTab.nameOf("gliderSkin", reward.gliderSkin) })
	elseif reward.sparkleShard and reward.egg then
		return Text.get("season.reward.shardEgg", { shard = tostring(reward.sparkleShard), egg = tostring(reward.egg) })
	elseif reward.egg then
		return Text.get("season.reward.egg", { egg = tostring(reward.egg) })
	elseif reward.sparkleShard then
		return Text.get("season.reward.shard", { shard = tostring(reward.sparkleShard) })
	end
	return ""
end

-- 칸 하나의 버튼 상태: "claimed" | "ready" | "locked"(유료 줄 잠김) | "notReached"
function SeasonTab.cellState(season, rowName, tier)
	local claimed = rowName == "free" and season.claimedFree or season.claimedPaid
	if claimed and claimed[tostring(tier)] then
		return "claimed"
	end
	if rowName == "paid" and not season.premium then
		return "locked"
	end
	if tier > (season.tier or 0) then
		return "notReached"
	end
	return "ready"
end

local BUTTON_TEXT = { claimed = "season.claimed", ready = "season.claim", locked = "season.locked", notReached = "season.claim" }

-- 칸 한 줄(칸 번호 | 무료 칸 | 유료 칸)
local function tierRow(ctx, env, season, tier)
	local L = ctx.L
	local row = Instance.new("Frame")
	row.Name = "Tier_" .. tier
	row.LayoutOrder = ctx.nextOrder()
	row.Size = UDim2.new(0, L.rowW, 0, L.rowH)
	row.BackgroundColor3 = Theme.colors.slot
	row.BackgroundTransparency = Theme.colors.slotTransparency
	row.Parent = ctx.scroll
	Theme.corner(row, Theme.corner.chip)
	local current = tier == math.min((season.tier or 0) + 1, season.tiers)
	Theme.stroke(row, current and "rimHi" or nil, current and Theme.colors.rimHiTransparency or nil)

	local number = Theme.label(row, tostring(tier), "body", tier <= (season.tier or 0) and "xp" or "textSecondary")
	number.Name = "Number"
	number.Font = Theme.font
	number.TextXAlignment = Enum.TextXAlignment.Center
	number.Size = UDim2.new(0, TIER_COL, 1, 0)

	local cellW = math.floor((L.rowW - TIER_COL - Layout.gap - 8) / 2)
	for index, rowName in ipairs({ "free", "paid" }) do
		local reward = season.rows[rowName][tier] or season.rows[rowName][tostring(tier)]
		local x = TIER_COL + (index - 1) * (cellW + Layout.gap)
		local cell = Instance.new("Frame")
		cell.Name = rowName == "free" and "Free" or "Paid"
		cell.BackgroundTransparency = 1
		cell.Position = UDim2.new(0, x, 0, 0)
		cell.Size = UDim2.new(0, cellW, 1, 0)
		cell.Parent = row
		local isEgg = type(reward) == "table" and reward.egg ~= nil
		local text = Theme.label(cell, SeasonTab.rewardText(reward), "caption", isEgg and "gold" or "textPrimary")
		text.Name = "Reward"
		text.TextWrapped = true
		text.Position = UDim2.new(0, 4, 0, 2)
		text.Size = UDim2.new(1, -(88 + 12), 1, -4)
		-- QUEUE-ALL6 C: 재화 칸(반짝 조각 · 알)은 글자 칸을 누르면 상세 카드(RewardDetail - 다른 보상 칸과 같은 문구)
		local detailKey = type(reward) == "table" and ((reward.sparkleShard and "sparkleShard") or (reward.egg and "egg")) or nil
		if detailKey then
			local hit = Instance.new("TextButton")
			hit.Name = "DetailHit"
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.AutoButtonColor = false
			hit.Position, hit.Size = text.Position, text.Size
			hit.Parent = cell
			RewardDetail.attach(hit, detailKey, "×" .. tostring(reward[detailKey]))
		end
		local state = SeasonTab.cellState(season, rowName, tier)
		ctx.button(cell, {
			name = ("Claim_%s_%d"):format(rowName, tier),
			text = Text.get(BUTTON_TEXT[state]),
			kind = state == "ready" and "primary" or "secondary",
			enabled = state == "ready" and not env.busy(),
			onActivated = function()
				env.send("seasonClaim", rowName, tier)
			end,
		}, UDim2.new(1, -4, 0.5, 0), Vector2.new(1, 0.5))
	end
end

-- QUEUE-ALL9A 1-3: 40칸 뒤 반복 보너스 칸 - 도달 횟수 · 줄마다 다음 안 받은 칸(41 · 42 …) 하나씩 받기(서버가 다시 잰다)
function SeasonTab.bonusState(season, rowName)
	local reached = math.max(0, (season.reach or 0) - season.tiers)
	local claimed = rowName == "free" and season.claimedFree or season.claimedPaid
	local nextTier, pending = nil, 0
	for tier = season.tiers + 1, season.tiers + reached do
		if not (claimed and claimed[tostring(tier)]) then
			nextTier = nextTier or tier
			pending += 1
		end
	end
	return reached, nextTier, pending
end

local function bonusRow(ctx, env, season)
	if not season.bonus then
		return
	end
	local reached = SeasonTab.bonusState(season, "free")
	local buttons = {}
	for _, rowName in ipairs({ "free", "paid" }) do
		local _, nextTier, pending = SeasonTab.bonusState(season, rowName)
		local locked = rowName == "paid" and not season.premium
		table.insert(buttons, {
			name = rowName == "free" and "BonusFree" or "BonusPaid",
			text = locked and Text.get("season.locked") or Text.get("season.bonusClaim", { n = tostring(pending) }),
			kind = (pending > 0 and not locked) and "primary" or "secondary",
			enabled = pending > 0 and not locked and not env.busy(),
			onActivated = function()
				env.send("seasonClaim", rowName, nextTier)
			end,
		})
	end
	ctx.row({ name = "Bonus", title = Text.get("season.bonusTitle", { n = tostring(reached) }),
		subtitle = Text.get("season.bonusSub", { per = tostring(season.expPerTier), free = tostring(season.bonus.free.sparkleShard or 0), paid = tostring(season.bonus.paid.sparkleShard or 0) }),
		highlight = reached > 0, buttons = buttons })
end

-- QUEUE-ALL2 P2: 받을 수 있는 칸 수(왼쪽 메뉴 상점 빨간 점) - cellState와 같은 판정(표시용 · 서버가 다시 잰다)
function SeasonTab.claimableCount(season)
	local n = 0
	for tier = 1, math.min(season.tier or 0, 200) do
		for _, rowName in ipairs({ "free", "paid" }) do
			if SeasonTab.cellState(season, rowName, tier) == "ready" then
				n += 1
			end
		end
	end
	if season.bonus then -- QUEUE-ALL9A 1-3 보너스 칸(유료 줄은 premium만)
		n += select(3, SeasonTab.bonusState(season, "free"))
		if season.premium then
			n += select(3, SeasonTab.bonusState(season, "paid"))
		end
	end
	return n
end

function SeasonTab.render(ctx, env)
	local view = env.state.view
	local season = view and view.season
	if not season then
		ctx.line(Text.get(view and "season.off" or "shop.loading"), "textSecondary", 1, "Loading")
		return
	end
	local days = math.max(0, math.ceil(((season.endsAt or 0) - os.time()) / DAY))
	ctx.line(Text.get("season.header", { season = tostring(season.season), days = tostring(days) }), "textPrimary", 1, "SeasonHeader")
	local maxed = (season.tier or 0) >= season.tiers
	local inTier = maxed and season.expPerTier or ((season.exp or 0) % season.expPerTier)
	ctx.gauge("SeasonExp", inTier / season.expPerTier, Text.get("season.exp", { tier = tostring(season.tier or 0), tiers = tostring(season.tiers),
		n = tostring(inTier), per = tostring(season.expPerTier) }), "xp")
	if season.weekend and season.weekend.active then -- QUEUE-ALL9A 1-2: 남은 시간 = 서버 시각(GetServerTimeNow) 기준 - 클라 시계 · 시간대 안 씀
		local left = math.max(0, (season.weekend.endsAt or 0) - workspace:GetServerTimeNow())
		local time = Text.get("season.weekendTime", { h = tostring(math.floor(left / 3600)), m = tostring(math.floor(left % 3600 / 60)) })
		ctx.line(Text.get("season.weekendOn", { time = time }), "gold", 1, "WeekendBoost")
	end
	if season.premium then
		ctx.line(Text.get("season.premiumOn"), "success", 1, "PremiumOn")
	else
		local button = env.robuxButton("season_premium", "PremiumBuy")
		ctx.row({ name = "Premium", title = Text.get("season.premiumTitle"), subtitle = Text.get("season.premiumSub"), highlight = true, buttons = { button } })
	end
	ctx.line(Text.get("season.eggNote"), "gold", 1, "EggNote")
	-- 열 제목(칸 | 무료 | 유료)
	local L = ctx.L
	local head = Instance.new("Frame")
	head.Name = "ColumnHead"
	head.LayoutOrder = ctx.nextOrder()
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(0, L.rowW, 0, Theme.textSize("caption") + 8)
	head.Parent = ctx.scroll
	local cellW = math.floor((L.rowW - TIER_COL - Layout.gap - 8) / 2)
	for index, key in ipairs({ "season.colTier", "season.colFree", "season.colPaid" }) do
		local label = Theme.label(head, Text.get(key), "caption", "textSecondary")
		label.Name = "Col" .. index
		label.Position = UDim2.new(0, index == 1 and 0 or TIER_COL + (index - 2) * (cellW + Layout.gap) + 4, 0, 0)
		label.Size = UDim2.new(0, index == 1 and TIER_COL or cellW, 1, 0)
		label.TextXAlignment = index == 1 and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
	end
	for tier = 1, season.tiers do
		tierRow(ctx, env, season, tier)
	end
	bonusRow(ctx, env, season)
end

return SeasonTab
