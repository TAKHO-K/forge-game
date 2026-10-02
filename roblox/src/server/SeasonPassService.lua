-- QUEUE-B1 B2 시즌 패스(8주 - P4c 골격). 데이터 = shared/data/SeasonPassData · 규칙 = shared/Monetization(seasonTier · canClaim · checkSeasonPass) · 저장 = profile.seasonPass(v56).
--   시즌 번호 = 리더보드와 같은 시계(LeaderboardRules.seasonAt · LeaderboardConfig.seasonLengthDays 56). 경험치 = profile.quests.currencies.passExp(G3 퀘스트 보상 칸 - 일일 · 주간 미션이
--   이미 준다 = 공통 입구 재사용) · 시즌이 바뀌면 경험치 0 · 받은 칸 · 유료를 새로(유료 줄은 시즌마다 다시 산다).
--   보상 지급 = MonetizationService.applyReward(치장 = CosmeticService · 조각 · 알 = QuestService.grant 한 곳).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)
local SeasonPassData = require(ReplicatedStorage.Shared.data.SeasonPassData)
local LeaderboardRules = require(ReplicatedStorage.Shared.LeaderboardRules)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local PlayerProfile = require(script.Parent.PlayerProfile)

local SeasonPassService = {}

-- QUEUE-ALL9A 1-2 주말 2배. 시각 = 서버 os.time()(UTC)만. 개발 덮어쓰기(/gg weekend on|off|auto) = Studio에서만 받고 읽는다(출시 서버 = 무시).
local weekendOverride = nil -- nil(auto) | true(on) | false(off)
local function isStudio()
	return game:GetService("RunService"):IsStudio()
end
function SeasonPassService.setWeekendOverride(mode)
	if not isStudio() then
		return false
	end
	if mode == "on" then
		weekendOverride = true
	elseif mode == "off" then
		weekendOverride = false
	elseif mode == "auto" then
		weekendOverride = nil
	else
		return false
	end
	return true
end
-- 반환: 창 안인가, 창 시작 · 끝(꺼져 있으면 다음 창)
function SeasonPassService.weekend(now)
	now = now or os.time()
	local active, startAt, endAt = Monetization.weekendWindow(now, SeasonPassData.weekend)
	if weekendOverride ~= nil and isStudio() then
		active = weekendOverride
	end
	return active, startAt, endAt
end
function SeasonPassService.passExpMultiplier(source, now)
	return Monetization.passExpMultiplier(source, (SeasonPassService.weekend(now)), SeasonPassData.weekend)
end

-- 주말 창 시작 뒤 첫 접속에 배너 1회(설정 weekendBannerAt = 본 창의 시작 시각 - 같은 창에서는 다시 안 띄움)
function SeasonPassService.weekendBanner(player)
	local active, startAt, endAt = SeasonPassService.weekend()
	local settings = PlayerProfile.getSettings(player)
	if not active or not settings or settings.weekendBannerAt == startAt then
		return false
	end
	if weekendOverride == nil then -- 리뷰: 개발 덮어쓰기(/gg weekend on)로 띄운 배너는 도장을 안 남긴다(창 밖이면 startAt = 다음 창 - 실제 다음 주말 배너가 안 뜸)
		require(script.Parent.SettingsService).set(player, "weekendBannerAt", startAt)
	end
	local hours = math.max(1, math.ceil((endAt - os.time()) / 3600))
	task.spawn(function()
		local notice = ReplicatedStorage:WaitForChild("SystemNotice", 10)
		if notice and player.Parent then
			notice:FireClient(player, require(ReplicatedStorage.Shared.Text).getFor(player, "season.weekendBanner", { hours = tostring(hours) }))
		end
	end)
	print(("[ALL9A] 주말 패스 2배 배너: %s - 창 %d · 남은 %d시간"):format(player.Name, startAt, hours))
	return true
end

function SeasonPassService.currentSeason(now)
	return LeaderboardRules.seasonAt(now or os.time(), LeaderboardConfig)
end

-- 시즌 넘김(접속 · 요청 때). 반환: 이번 시즌 상태(살아 있는 표) · 넘겼나
function SeasonPassService.ensure(player, now)
	local s = PlayerProfile.getMonetizationState(player)
	local quests = PlayerProfile.getQuestState(player)
	if not s or not quests then
		return nil, false
	end
	local season = SeasonPassService.currentSeason(now)
	local pass = s.seasonPass
	if pass.season ~= season then
		local old = pass.season
		pass.season = season
		pass.premium = false
		pass.claimedFree = {}
		pass.claimedPaid = {}
		quests.currencies.passExp = 0
		if old ~= 0 then
			print(("[B2] 시즌 패스 넘김: %s - 시즌 %d → %d(경험치 · 받음 · 유료 초기화)"):format(player.Name, old, season))
		end
		return pass, true
	end
	return pass, false
end

function SeasonPassService.view(player)
	local pass = SeasonPassService.ensure(player)
	local quests = PlayerProfile.getQuestState(player)
	if not pass or not quests then
		return nil
	end
	local exp = quests.currencies.passExp or 0
	local reach = Monetization.seasonReach(exp, SeasonPassData.expPerTier)
	local weekendOn, _, weekendEnds = SeasonPassService.weekend()
	return {
		enabled = SeasonPassData.enabled,
		season = pass.season,
		endsAt = LeaderboardRules.seasonEndsAt(pass.season, LeaderboardConfig),
		exp = exp,
		expPerTier = SeasonPassData.expPerTier,
		tier = Monetization.seasonTier(exp, SeasonPassData.expPerTier, SeasonPassData.tiers),
		tiers = SeasonPassData.tiers,
		premium = pass.premium,
		claimedFree = table.clone(pass.claimedFree),
		claimedPaid = table.clone(pass.claimedPaid),
		rows = SeasonPassData.rowsFor(pass.season), -- QUEUE-ALL1 R1 시즌 한정 칸
		bonus = SeasonPassData.bonus, -- QUEUE-ALL9A 1-3 반복 보너스 칸(41칸부터 - 도달 = reach)
		reach = reach,
		weekend = { active = weekendOn, endsAt = weekendEnds, mult = SeasonPassData.weekend.mult }, -- QUEUE-ALL9A 1-2(남은 시간 = 클라가 서버 시각 GetServerTimeNow로)
	}
end

-- 유료 줄 켜기(MonetizationService grant "seasonPremium" - 멱등)
function SeasonPassService.setPremium(player)
	local pass = SeasonPassService.ensure(player)
	if not pass then
		return false, "no_profile"
	end
	if pass.premium then
		return false, "owned"
	end
	pass.premium = true
	return true
end

-- 칸 받기. 반환: ok, 이유 또는 지급 요약
function SeasonPassService.claim(player, rowName, tier)
	if not SeasonPassData.enabled then
		return false, "disabled"
	end
	local pass = SeasonPassService.ensure(player)
	local quests = PlayerProfile.getQuestState(player)
	if not pass or not quests then
		return false, "no_profile"
	end
	local reached = Monetization.seasonReach(quests.currencies.passExp or 0, SeasonPassData.expPerTier) -- QUEUE-ALL9A 1-3: 상한 없음(41칸부터 보너스)
	local ok, why = Monetization.canClaim(pass, rowName, tier, reached, SeasonPassData.tiers, SeasonPassData.bonus ~= nil)
	if not ok then
		return false, why
	end
	local reward = SeasonPassData.rewardAt(pass.season, rowName, tier) -- QUEUE-ALL1 R1 시즌 한정 칸 · ALL9A 보너스 칸
	local okReward, summary = require(script.Parent.MonetizationService).applyReward(player, reward, rowName == "paid" and "seasonPaid" or "season")
	if not okReward then
		return false, summary
	end
	local claimed = rowName == "free" and pass.claimedFree or pass.claimedPaid
	claimed[tostring(tier)] = true -- 문자열 키(DataStore 왕복)
	require(script.Parent.ImmediateSave).request(player)
	print(("[B2] 시즌 패스 받기: %s - 시즌 %d %s %d칸 → %s"):format(player.Name, pass.season, rowName, tier, summary))
	return true, summary
end

return SeasonPassService
