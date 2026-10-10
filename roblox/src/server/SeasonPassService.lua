-- QUEUE-B1 B2 시즌 패스(8주 - P4c 골격). 데이터 = shared/data/SeasonPassData · 규칙 = shared/Monetization(seasonTier · canClaim · checkSeasonPass) · 저장 = profile.seasonPass(v56).
--   시즌 번호 = 리더보드와 같은 시계(LeaderboardRules.seasonAt · LeaderboardConfig.seasonLengthDays 56). 경험치 = profile.quests.currencies.passExp(G3 퀘스트 보상 칸 - 일일 · 주간 미션이
--   이미 준다 = 공통 입구 재사용) · 시즌이 바뀌면 경험치 0 · 받은 칸 · 유료를 새로(유료 줄은 시즌마다 다시 산다).
--   보상 지급 = MonetizationService.applyReward(치장 = CosmeticService · 조각 · 알 = QuestService.grant 한 곳).
local print = require(game:GetService("ReplicatedStorage").Shared.Log).info -- SEC-FIX-1 9: 라이브 = WARN(이 파일 print = INFO · 꺼짐) · Studio = 그대로
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)
local SeasonPassData = require(ReplicatedStorage.Shared.data.SeasonPassData)
local LeaderboardRules = require(ReplicatedStorage.Shared.LeaderboardRules)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local Quest = require(ReplicatedStorage.Shared.Quest)
local QuestData = require(ReplicatedStorage.Shared.data.QuestData)
local SeasonBoardData = require(ReplicatedStorage.Shared.data.SeasonBoardData)
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
			local noCountdown = require(ReplicatedStorage.Shared.data.UiV2Flags).rest -- UI-1 7c: 남은 시간 없는 문구(압박 금지)
			notice:FireClient(player, require(ReplicatedStorage.Shared.Text).getFor(player, noCountdown and "ui1.season.weekendBanner" or "season.weekendBanner", { hours = tostring(hours) }))
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
		pass.skipBought = 0 -- QUEUE-ALL9B 4-8 이번 시즌 구매로 오른 칸 수
		pass.skipTiers = {} -- 건너뛰기로 얻은 칸(문자열 키 - 무료 줄 알 · 성장 재화 = 토큰)
		pass.skipDay = -1 -- SEC-FIX-1 8: 하루 1번(새 시즌 = 다시)
		quests.currencies.passExp = 0
		if old ~= 0 then
			print(("[B2] 시즌 패스 넘김: %s - 시즌 %d → %d(경험치 · 받음 · 유료 초기화)"):format(player.Name, old, season))
		end
		return pass, true
	end
	pass.skipBought = tonumber(pass.skipBought) or 0
	pass.skipTiers = type(pass.skipTiers) == "table" and pass.skipTiers or {}
	pass.skipDay = tonumber(pass.skipDay) or -1
	return pass, false
end

-- SEC-FIX-1 8: 이번 시즌 시작 시각(리더보드 · 패스 공통 시계 - 시작일이 안 정해졌으면 nil)
function SeasonPassService.seasonStartUnix(now)
	local start = LeaderboardRules.seasonStartOf(LeaderboardConfig)
	if start <= 0 then
		return nil
	end
	return start + (SeasonPassService.currentSeason(now) - 1) * LeaderboardConfig.seasonLengthDays * 86400
end

-- SEC-FIX-1 8: 매일 출석한 무료 유저가 오늘(UTC 날짜)까지 모으는 패스 경험치 상한 = 시즌 첫날 ~ 오늘 매일(접속 + 그날 일간 전부 + 일일 상자 · 주말 2배) + 시작한 주마다 주간 전부.
--   주간은 주 첫날 끝낸 것으로 친다(가장 빠른 무료 유저 - 사는 사람이 그보다 앞설 수 없게 넉넉한 쪽). 순수(시각을 받는다).
function SeasonPassService.paceExp(seasonStart, now)
	local function mult(source, t)
		return Monetization.passExpMultiplier(source, (Monetization.weekendWindow(t, SeasonPassData.weekend)), SeasonPassData.weekend)
	end
	local weekly = 0
	for _, q in ipairs(QuestData.weekly) do
		weekly += q.reward.passExp or 0
	end
	local exp, seenWeek = 0, {}
	for day = Quest.dayOf(seasonStart), Quest.dayOf(now) do
		local t = math.max(seasonStart, day * 86400 + 12 * 3600)
		local daily = 0
		for _, q in ipairs(Quest.dailyFor(day)) do
			daily += q.reward.passExp or 0
		end
		exp += (QuestData.loginReward.passExp or 0) * mult("login", t) + daily * mult("daily", t) + (QuestData.dailyChest.passExp or 0) * mult("chest", t)
		local week = Quest.weekOf(t)
		if not seenWeek[week] then
			seenWeek[week] = true
			exp += weekly * mult("weekly", t)
		end
	end
	return exp
end

-- SEC-FIX-1 8(사용자 결정 10-11 "못 한 출석 따라잡기로만"): 지금 살 수 있는 칸 수(0 | 1) · 막힌 이유(화면 한 줄 - 압박 문구 없음).
--   이유: "no_date"(시즌 시작일 미정) · "caught_up"(출석을 다 했음 = 따라잡을 칸 0) · "today"(오늘 이미 삼) · "ahead"(매일 출석한 유저의 오늘 칸에 이미 닿음) · "cap"(시즌 상한 · 40칸)
--   출석 = 시즌 출석판 센 칸(quests.board.count - 하루 첫 접속 1칸 · 서버 UTC 날짜) · 출석판을 다 채웠으면(32칸) 놓친 날이 없는 것으로 친다(그 뒤는 셀 수 없음).
function SeasonPassService.catchUp(pass, quests, now)
	now = now or os.time()
	local start = SeasonPassService.seasonStartUnix(now)
	if not start then
		return 0, "no_date"
	end
	local today = Quest.dayOf(now)
	local elapsed = today - Quest.dayOf(start) + 1
	local board = quests.board
	local attended = type(board) == "table" and board.season == SeasonPassService.currentSeason(now) and (tonumber(board.count) or 0) or 0
	if attended >= elapsed or attended >= #SeasonBoardData.cells then
		return 0, "caught_up"
	end
	if pass.skipDay == today then
		return 0, "today"
	end
	local reach = Monetization.seasonReach(quests.currencies.passExp or 0, SeasonPassData.expPerTier)
	if pass.skipBought >= SeasonPassData.skip.capPerSeason or reach >= SeasonPassData.skip.maxTier then
		return 0, "cap"
	end
	local paceReach = Monetization.seasonReach(SeasonPassService.paceExp(start, now), SeasonPassData.expPerTier)
	if reach + 1 > math.min(paceReach, SeasonPassData.skip.maxTier) then
		return 0, "ahead"
	end
	return SeasonPassData.skip.perDay, nil
end

-- QUEUE-ALL9B 4-8 칸 건너뛰기: 지금 더 살 수 있는 칸 수 · SEC-FIX-1 8: = 따라잡기 판정(0 | 1) · 둘째 반환 = 막힌 이유
function SeasonPassService.skipRoom(player, now)
	local pass = SeasonPassService.ensure(player, now)
	local quests = PlayerProfile.getQuestState(player)
	if not pass or not quests then
		return 0, "no_profile"
	end
	return SeasonPassService.catchUp(pass, quests, now)
end
local lastSkipMarked = setmetatable({}, { __mode = "k" }) -- player → 마지막 applySkip이 표시한 칸 키(revertSkip 전용)
-- 칸 n개 올리기(영수증 지급 - 방은 호출부가 먼저 확인). 오른 칸 = 건너뛴 칸 표시. 반환: ok, 이유
function SeasonPassService.applySkip(player, n)
	local pass = SeasonPassService.ensure(player)
	local quests = PlayerProfile.getQuestState(player)
	if not pass or not quests then
		return false, "no_profile"
	end
	if type(n) ~= "number" or n < 1 or n ~= math.floor(n) or SeasonPassService.skipRoom(player) < n then
		return false, "skip_cap"
	end
	local per = SeasonPassData.expPerTier
	local exp = quests.currencies.passExp or 0
	local reach = Monetization.seasonReach(exp, per)
	local marked = {}
	for i = 1, n do
		pass.skipTiers[tostring(reach + i)] = true
		table.insert(marked, tostring(reach + i))
	end
	marked.prevSkipDay = pass.skipDay -- SEC-FIX-1 8: 되돌리기(저장 실패)가 하루 1번 표시도 되돌린다
	lastSkipMarked[player] = marked -- 리뷰: 저장 대기 중 경험치가 늘어도 되돌리기가 이 칸들만 지운다
	quests.currencies.passExp = exp + n * per
	pass.skipBought += n
	pass.skipDay = Quest.dayOf(os.time())
	return true, marked -- QUEUE-ALL10 0-1 리뷰 L1: 영수증 되돌림이 이 표시만 지운다(겹친 두 영수증)
end
-- 되돌리기(저장 실패 - 영수증 재시도가 다시 지급)
function SeasonPassService.revertSkip(player, n, markedArg)
	local pass = SeasonPassService.ensure(player)
	local quests = PlayerProfile.getQuestState(player)
	if not pass or not quests then
		return
	end
	local per = SeasonPassData.expPerTier
	local marked = markedArg or lastSkipMarked[player]
	if lastSkipMarked[player] == marked then
		lastSkipMarked[player] = nil
	end
	if marked then
		for _, key in ipairs(marked) do
			pass.skipTiers[key] = nil
		end
		if marked.prevSkipDay ~= nil then
			pass.skipDay = marked.prevSkipDay
		end
	else
		local reach = Monetization.seasonReach(quests.currencies.passExp or 0, per)
		for i = 0, n - 1 do
			pass.skipTiers[tostring(reach - i)] = nil
		end
	end
	quests.currencies.passExp = math.max(0, (quests.currencies.passExp or 0) - n * per)
	pass.skipBought = math.max(0, pass.skipBought - n)
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
		bonusCap = SeasonPassData.bonusCap, -- QUEUE-ALL9B 보완 5-2(41 ~ 40 + 상한)
		skipRoom = SeasonPassService.skipRoom(player), skipWhy = select(2, SeasonPassService.skipRoom(player)), skipBought = pass.skipBought, skipTiers = table.clone(pass.skipTiers), -- 4-8 · SEC-FIX-1 8 막힌 이유
		saleActive = SeasonPassData.saleActive, premiumKey = Monetization.activePremiumKey(SeasonPassData), -- 4-4
		value = (function() -- 4-7 "가치 약 ×N"
			local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
			local v = Monetization.passValue(MonetizationData, SeasonPassData, require(ReplicatedStorage.Shared.data.CosmeticSlotData), pass.season)
			return { multiple = v.multiple, total = v.total }
		end)(),
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
	local ok, why = Monetization.canClaim(pass, rowName, tier, reached, SeasonPassData.tiers, SeasonPassData.bonus ~= nil, SeasonPassData.bonusCap)
	if not ok then
		return false, why
	end
	local reward = SeasonPassData.rewardAt(pass.season, rowName, tier) -- QUEUE-ALL1 R1 시즌 한정 칸 · ALL9A 보너스 칸
	if rowName == "free" and pass.skipTiers[tostring(tier)] then
		reward = Monetization.skippedFreeReward(SeasonPassData, reward) -- QUEUE-ALL9B 4-8 · 보완 6-2: 건너뛴 칸 = 알 · 성장 재화 → 토큰
	end
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

-- QUEUE-ALL9B 4-6 일괄 받기(중간 구매 소급 · 받기 버튼 한 번): 그 줄의 도달한 안 받은 칸(40칸 + 보너스 상한까지)을 차례로 claim(같은 검사 · 지급 · 기록).
--   알 가방이 가득 차는 등 한 칸이 실패하면 거기서 멈춘다(받은 칸은 기록 - 다음 누름이 이어서). 반환: 받은 칸 수, 마지막 이유
function SeasonPassService.claimAll(player, rowName)
	if rowName ~= "free" and rowName ~= "paid" then
		return 0, "bad_row"
	end
	local quests = PlayerProfile.getQuestState(player)
	if not SeasonPassService.ensure(player) or not quests then
		return 0, "no_profile"
	end
	local reached = math.min(Monetization.seasonReach(quests.currencies.passExp or 0, SeasonPassData.expPerTier), SeasonPassData.tiers + (SeasonPassData.bonusCap or 0))
	local got, last = 0, nil
	for tier = 1, reached do
		local pass = SeasonPassService.ensure(player)
		local claimed = rowName == "free" and pass.claimedFree or pass.claimedPaid
		if not claimed[tostring(tier)] then
			local ok, why = SeasonPassService.claim(player, rowName, tier)
			if not ok then
				last = why
				break
			end
			got += 1
		end
	end
	if got > 0 then
		require(script.Parent.AuditTrail).note(player, "passClaimAll", ("%s %d칸"):format(rowName, got)) -- 6-2 감사
	end
	return got, last
end

return SeasonPassService
