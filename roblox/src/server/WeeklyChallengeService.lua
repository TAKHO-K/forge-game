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

startRemote.OnServerEvent:Connect(function(player)
	local BossEncounter = require(script.Parent.BossEncounter)
	if BossEncounter.getEncounter(player) or player:GetAttribute("TutorialActive") then
		noticeRemote:FireClient(player, "지금은 시작할 수 없어요")
		return
	end
	local e = WeeklyChallenge.entryOf(WeeklyChallenge.weekOf())
	local encounter = BossEncounter.spawnWeeklyFor(player, e.bossId, D.stage, e.mods)
	if not encounter then
		noticeRemote:FireClient(player, "지금은 시작할 수 없어요")
	end
end)

function WeeklyChallengeService.onCleared(player, fightSeconds)
	local r = recordOf(player)
	if not r or type(fightSeconds) ~= "number" or fightSeconds <= 0 then
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

topRemote.OnServerInvoke = function(player)
	local w = WeeklyChallenge.weekOf()
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
	local mine = recordOf(player)
	return { ok = ok, rows = rows, myBest = mine and mine.best, label = workspace:GetAttribute("WeeklyChallengeLabel"), bossId = workspace:GetAttribute("WeeklyChallengeBoss") }
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
	task.spawn(function()
		local rank = nil
		pcall(function()
			local page = board(last):GetSortedAsync(true, D.rankRewards[#D.rankRewards].upTo):GetCurrentPage()
			for i, entry in ipairs(page) do
				if entry.key == tostring(player.UserId) then
					rank = i
					break
				end
			end
		end)
		r.rankClaimedWeek = last
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
