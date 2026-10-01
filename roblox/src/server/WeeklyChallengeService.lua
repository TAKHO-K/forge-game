-- QUEUE-ALL1 P4 §3 주간 도전(서버). 규칙 = shared/WeeklyChallenge · 수치 = shared/data/WeeklyChallengeData.
--   입장 = RemoteEvent WeeklyChallengeStart → 이번 주 보스 · 변형 · 고정 스테이지로 BossEncounter.spawnWeeklyFor(토벌과 같은 규칙: 진도 · 시즌 리더보드 · 첫 클리어 드랍 없음).
--   처치(CombatResolution) → onCleared: 처치 초 → 주간 OrderedDataStore(더 빠를 때만) · 그 주 첫 처치 = 참여 보상.
--   순위 = RemoteFunction WeeklyChallengeTop → 상위 topShown(이름 · 초) · 지난주 순위 보상 = 접속 때 한 번(profile.weeklyChallenge.rankClaimedWeek - SAVE v58).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local D = require(ReplicatedStorage.Shared.data.WeeklyChallengeData)
local WeeklyChallenge = require(ReplicatedStorage.Shared.WeeklyChallenge)
local PlayerProfile = require(script.Parent.PlayerProfile)
local RequestGate = require(script.Parent.RequestGate) -- QUEUE-ALL4 B: 공통 요청 제한
local Text = require(ReplicatedStorage.Shared.Text) -- QUEUE-ALL5 A2: 입장 거절 문구(그 사람 언어)

local WeeklyChallengeService = {}
local suffix = RunService:IsStudio() and D.studioSuffix or ""
local function board(week)
	return DataStoreService:GetOrderedDataStore(D.storeName .. suffix, "w" .. tostring(week))
end

local startRemote = Instance.new("RemoteEvent")
startRemote.Name = "WeeklyChallengeStart"
startRemote.Parent = ReplicatedStorage
local topRemote = Instance.new("RemoteFunction")
topRemote.Name = "WeeklyChallengeTop"
topRemote.Parent = ReplicatedStorage
local noticeRemote = Instance.new("RemoteEvent")
noticeRemote.Name = "WeeklyChallengeNotice" -- 서버 → 클라: 문구
noticeRemote.Parent = ReplicatedStorage

local rankReading = {} -- [player] = 지난주 순위 읽는 중(QUEUE-ALL4 리뷰 1)
local function recordOf(player)
	local r = PlayerProfile.getWeeklyChallenge(player)
	if not r then
		return nil
	end
	local w = WeeklyChallenge.weekOf()
	if r.week ~= w then
		r.week, r.best, r.rewarded = w, nil, false
	end
	return r
end

-- 이번 주 보스 · 변형(클라 표시용 속성)
local function publishWeek()
	local w = WeeklyChallenge.weekOf()
	local e = WeeklyChallenge.entryOf(w)
	workspace:SetAttribute("WeeklyChallengeWeek", w)
	workspace:SetAttribute("WeeklyChallengeBoss", e.bossId)
	workspace:SetAttribute("WeeklyChallengeLabel", e.label)
end

-- QUEUE-ALL5 A2(보안 감사 D2): 입장 조건 = 견습 아님 + 체크포인트 순간이동과 같은 "바쁨" 규칙(Travel.busyReason - 보스전 · 아레나 안 · 전투 중 · 귀환/체크포인트 집중 중).
-- 반환: 이유 코드(TextData srv.weekly.blocked.<이유>) | nil(입장 가능)
function WeeklyChallengeService.entryBlocked(player, now)
	if player:GetAttribute("TutorialActive") then
		return "tutorial"
	end
	return require(script.Parent.Travel).busyReason(player, now)
end

startRemote.OnServerEvent:Connect(function(player)
	if not RequestGate.allow(player, "WeeklyChallengeStart") then
		return -- QUEUE-ALL4 B: 입장 = 아레나 · 보스 스폰(연타 = 서버 비용)
	end
	local why = WeeklyChallengeService.entryBlocked(player)
	if why then
		noticeRemote:FireClient(player, Text.getFor(player, "srv.weekly.blocked." .. why))
		return
	end
	local e = WeeklyChallenge.entryOf(WeeklyChallenge.weekOf())
	local encounter = require(script.Parent.BossEncounter).spawnWeeklyFor(player, e.bossId, D.stage, e.mods)
	if not encounter then
		noticeRemote:FireClient(player, Text.getFor(player, "srv.weekly.blocked.failed"))
	end
end)

function WeeklyChallengeService.onCleared(player, fightSeconds)
	local r = recordOf(player)
	if not r or type(fightSeconds) ~= "number" or fightSeconds ~= fightSeconds or fightSeconds <= 0 or fightSeconds == math.huge then -- QUEUE-ALL4 B: NaN · inf가 순위 저장소에 가지 않게
		return
	end
	local week = r.week
	if not r.rewarded then
		r.rewarded = true
		require(script.Parent.QuestService).grant(player, D.participation)
	end
	if not r.best or fightSeconds < r.best then
		r.best = fightSeconds
	end
	local score = math.floor(fightSeconds * 100 + 0.5)
	task.spawn(function()
		pcall(function()
			board(week):UpdateAsync(tostring(player.UserId), function(old)
				old = tonumber(old)
				if old and old <= score then
					return nil -- 더 느리면 그대로
				end
				return score
			end)
		end)
	end)
	noticeRemote:FireClient(player, D.text.done:format(fightSeconds))
	require(script.Parent.ImmediateSave).request(player)
end

-- QUEUE-ALL4 B(보안 - 읽기 증폭): 순위 표 = 서버 공용 캐시(topCacheSeconds). 읽는 동안 온 요청은 직전 표를 받는다(읽기 1회).
local top = { week = nil, at = -math.huge, ok = false, rows = {} }
local function topRows(w)
	if top.week ~= w then
		top.ok, top.rows = false, {}
	end
	if top.week ~= w or os.clock() - top.at >= D.topCacheSeconds then
		top.week, top.at = w, os.clock()
		local rows = {}
		local ok = pcall(function()
			local page = board(w):GetSortedAsync(true, D.topShown):GetCurrentPage()
			for i, entry in ipairs(page) do
				local name = "?"
				pcall(function()
					name = Players:GetNameFromUserIdAsync(tonumber(entry.key))
				end)
				rows[i] = { rank = i, name = name, seconds = entry.value / 100 }
			end
		end)
		if top.week == w then
			top.ok, top.rows = ok, rows
		end
	end
	return top.ok, top.rows
end
WeeklyChallengeService.debugTop = top -- 하네스 · 검증

topRemote.OnServerInvoke = function(player)
	return RequestGate.invoke(player, "WeeklyChallengeTop", "", function() -- QUEUE-ALL4 B: 공통 요청 제한
		local ok, rows = topRows(WeeklyChallenge.weekOf())
		local mine = recordOf(player)
		return { ok = ok, rows = rows, myBest = mine and mine.best, label = workspace:GetAttribute("WeeklyChallengeLabel"), bossId = workspace:GetAttribute("WeeklyChallengeBoss") }
	end)
end

-- 지난주 순위 보상(접속 때 한 번)
function WeeklyChallengeService.onLoaded(player)
	local r = recordOf(player)
	if not r then
		return
	end
	local last = WeeklyChallenge.weekOf() - 1
	if (r.rankClaimedWeek or 0) >= last then
		return
	end
	if rankReading[player] then
		return -- QUEUE-ALL4 B · 리뷰 1: 읽는 중(yield) 두 번째 호출 = 무시(서버 메모리 표 - 저장되지 않아 읽는 동안 나가도 표시가 남지 않는다)
	end
	rankReading[player] = true
	task.spawn(function()
		local rank = nil
		local okRead = pcall(function()
			local page = board(last):GetSortedAsync(true, D.rankRewards[#D.rankRewards].upTo):GetCurrentPage()
			for i, entry in ipairs(page) do
				if entry.key == tostring(player.UserId) then
					rank = i
					break
				end
			end
		end)
		rankReading[player] = nil
		if not okRead or player.Parent == nil or recordOf(player) ~= r then
			return -- 읽기 실패 · 읽는 동안 나감 = 받은 것으로 치지 않는다(다음 접속에 다시 본다 - 옛 코드는 보상이 사라졌다)
		end
		r.rankClaimedWeek = last -- 성공한 읽기 뒤에만 표시(yield 없이 아래 지급까지 이어진다)
		if not rank then
			return
		end
		for _, rr in ipairs(D.rankRewards) do
			if rank <= rr.upTo then
				require(script.Parent.QuestService).grant(player, rr.reward)
				if rr.title then
					PlayerProfile.grantTitle(player, rr.title)
				end
				noticeRemote:FireClient(player, D.text.reward:format(rank))
				break
			end
		end
		require(script.Parent.ImmediateSave).request(player)
	end)
end

function WeeklyChallengeService.start()
	publishWeek()
	task.spawn(function()
		while true do
			task.wait(60)
			publishWeek()
		end
	end)
end

return WeeklyChallengeService
