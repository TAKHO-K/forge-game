-- QUEUE-10h Q6 G3 퀘스트 · 수련 서버(판정 · 지급 = 서버 · 화면 = 클라). 규칙 = shared/Quest.lua · shared/Training.lua · 데이터 = QuestData · TrainingData.
--   Remote: QuestRequest(action, a, b) - "view" · "claim"(kind, id) · "train"(kind = "stat" | "ability", id) / QuestUpdate(서버 → 클라: 화면 표)
--   이벤트(note)는 서버 경로가 부른다: CombatResolution(kill · sparkle · bossClear · raidClear) · 강화 · 보석 · 둥지 · 수련. 클라가 진행을 보고하는 길은 없다.
--   보상 지급 = 이 모듈 한 곳(골드 = GoldCost "quest" × 계정 최고 스테이지 · 강화석 = 재료 · 알 = 가방 · 반짝 조각 · 시즌 패스 경험치 = quests.currencies).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Quest = require(ReplicatedStorage.Shared.Quest)
local QuestData = require(ReplicatedStorage.Shared.data.QuestData)
local Training = require(ReplicatedStorage.Shared.Training)
local TrainingData = require(ReplicatedStorage.Shared.data.TrainingData)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)
local NestData = require(ReplicatedStorage.Shared.data.NestData)
local PlayerProfile = require(script.Parent.PlayerProfile)

local QuestService = {}

local updateRemote
local lastRequest = {}

local function questNames(list, progress)
	local rows = {}
	for _, q in ipairs(list) do
		local p = progress[q.id]
		table.insert(rows, { id = q.id, name = Quest.nameOf(q), n = p and p.n or 0, target = q.target, claimed = p and p.claimed == true, reward = q.reward })
	end
	return rows
end

-- 화면 표(클라 퀘스트 · 수련 창 - U1): 일간 · 주간 · 접속 · 상자 · 메인 · 수련 · 직업 능력(단계 · 상한 · 다음 가격)
function QuestService.view(player)
	local state = PlayerProfile.getQuestState(player)
	if not state then
		return nil
	end
	Quest.roll(state, os.time())
	local facts = PlayerProfile.getQuestFacts(player)
	local step = QuestData.main[state.main]
	local tv = PlayerProfile.getTrainingView(player)
	local function trainRows(defs, levels, kind)
		local rows = {}
		for _, def in ipairs(defs or {}) do
			local level = tonumber(levels and levels[def.id]) or 0
			table.insert(rows, { kind = kind, id = def.id, name = def.name, level = level, cap = Training.capFor(def, tv and tv.bestStage), cost = Training.costFor(def, level, tv and tv.bestStage), perLevel = def.perLevel })
		end
		return rows
	end
	local chestReady = true
	for _, q in ipairs(Quest.dailyFor(state.day)) do
		local p = state.daily[q.id]
		chestReady = chestReady and p ~= nil and p.n >= q.target
	end
	return {
		daily = questNames(Quest.dailyFor(state.day), state.daily),
		weekly = questNames(QuestData.weekly, state.weekly),
		loginReady = state.loginDay ~= state.day,
		chestReady = chestReady and state.chestDay ~= state.day,
		chestClaimed = state.chestDay == state.day, -- Play C: 받은 뒤 버튼 글 = 받음
		main = step and { index = state.main, total = #QuestData.main, id = step.id, name = step.name, unlock = step.unlock, done = Quest.mainDone(step, facts), reward = step.reward } or nil,
		currencies = state.currencies,
		guide = state.guide and QuestData.ftue[state.guide] and { index = state.guide, total = #QuestData.ftue, id = QuestData.ftue[state.guide].id, text = QuestData.ftue[state.guide].text, card = QuestData.ftue[state.guide].card } or nil, -- Q12
		attendance = (function() -- Q12 · 리뷰: 7칸 다 받으면 창에서 숨김
			local att = state.attendance
			if type(att) ~= "table" then
				return nil
			end
			local all = true
			for _, entry in ipairs(QuestData.attendance) do
				all = all and att.claimed[tostring(entry.day)] == true
			end
			return not all and { count = att.count, claimed = att.claimed, rewards = QuestData.attendance } or nil
		end)(),
		training = tv and trainRows(TrainingData.stats, tv.training, "stat") or {},
		abilities = tv and trainRows(TrainingData.classAbilities[tv.classId], tv.abilities, "ability") or {},
	}
end

local function push(player)
	if updateRemote and typeof(player) == "Instance" and player.Parent then
		updateRemote:FireClient(player, QuestService.view(player))
	end
	local state = PlayerProfile.getQuestState(player)
	if state and typeof(player) == "Instance" then -- HUD 칩(메인 퀘스트 단계 · 받을 것 있음) - 클라 길 안내 · 점
		player:SetAttribute("MainQuestStep", state.main)
	end
end
QuestService.push = push

-- 보상 지급(한 곳). 반환 = 지급 요약 문자열(로그)
function QuestService.grant(player, reward)
	local parts = {}
	if not reward then
		return ""
	end
	local state = PlayerProfile.getQuestState(player)
	if reward.gold then
		local gold = GoldCost.cost(MonsterData.tier1.goldDrop * reward.gold, PlayerProfile.getAccountBestStage(player), "quest")
		PlayerProfile.addGold(player, gold)
		table.insert(parts, ("골드 %d"):format(gold))
	end
	if reward.enhanceStone then
		PlayerProfile.addMaterial(player, "enhanceStone", reward.enhanceStone)
		table.insert(parts, ("강화석 %d"):format(reward.enhanceStone))
	end
	for _ = 1, reward.egg or 0 do
		local zones = {}
		for key in pairs(EggData.zones) do
			table.insert(zones, key)
		end
		table.sort(zones)
		local zoneKey = zones[1]
		local pool = EggData.zones[zoneKey].pool
		local a = math.random(1, #pool)
		local b = (a % #pool) + 1
		local ok = PlayerProfile.addEgg(player, { zone = zoneKey, grade = "normal", species = { pool[a], pool[b] }, nest = "quest", at = os.time() }, NestData.eggCap)
		table.insert(parts, ok and "알 1" or "알(가방 가득 - 못 받음)")
	end
	if state and reward.sparkleShard then
		state.currencies.sparkleShard = (state.currencies.sparkleShard or 0) + reward.sparkleShard
		table.insert(parts, ("반짝 조각 %d"):format(reward.sparkleShard))
	end
	if state and reward.rebirthTicket then -- Q12 7일 출석 2일차(자리 - 지금 환생은 비용이 없어 쓰는 곳 없음)
		state.currencies.rebirthTicket = (state.currencies.rebirthTicket or 0) + reward.rebirthTicket
		table.insert(parts, ("환생 무료권 %d"):format(reward.rebirthTicket))
	end
	if state and reward.passExp then
		state.currencies.passExp = (state.currencies.passExp or 0) + reward.passExp
		table.insert(parts, ("패스 경험치 %d"):format(reward.passExp))
	end
	return table.concat(parts, " · ")
end

-- 서버 이벤트 → 진행
local usedEvents = {} -- 리뷰: 일간 · 주간 · 이정표 어디에도 없는 이벤트는 바로 돌아간다(스킬 · 줍기는 자주 온다)
for _, list in ipairs({ QuestData.dailyPool, QuestData.weekly, QuestData.ftue }) do
	for _, q in ipairs(list) do
		usedEvents[q.event] = true
	end
end

function QuestService.note(player, event, amount)
	local state = PlayerProfile.getQuestState(player)
	if not state or not usedEvents[event] then
		return
	end
	if not state.guide and (event == "skill" or event == "ult" or event == "pickup" or event == "equip") then
		return -- 이정표를 마쳤으면 이 넷은 일간 · 주간에 없다(위 표) - dailyFor 셔플을 매번 돌지 않게
	end
	local reached, advanced = Quest.note(state, event, amount or 1, os.time())
	if #reached > 0 then
		print(("[Q6] 퀘스트 목표 도달: %s - %s"):format(player.Name, table.concat(reached, ",")))
	end
	if advanced then -- Q12 첫 5분 이정표
		QuestService.funnel(player, advanced.funnel)
		local nextStep = state.guide and QuestData.ftue[state.guide]
		if nextStep and nextStep.fillUlt then -- 궁극기 맛보기: 이 단계에 들어서면 게이지 한 번 가득
			local UltimateData = require(ReplicatedStorage.Shared.data.UltimateData)
			require(script.Parent.UltimateService).set(player, UltimateData.max)
		end
		print(("[Q12] 이정표: %s - %s 끝 → %s"):format(player.Name, advanced.id, nextStep and nextStep.id or "완료"))
	end
	if #reached > 0 or advanced then
		push(player)
	end
end

-- Q12 온보딩 퍼널 자리(Q15 Telemetry가 받는다 - 지금은 로그만)
function QuestService.funnel(player, step)
	local ok, Telemetry = pcall(require, script.Parent:FindFirstChild("Telemetry"))
	if ok and type(Telemetry) == "table" and Telemetry.funnel then
		Telemetry.funnel(player, step)
	else
		print(("[Q12][퍼널] %s %s"):format(player.Name, tostring(step)))
	end
end

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = deepCopy(x)
	end
	return out
end

function QuestService.claim(player, kind, id)
	local state = PlayerProfile.getQuestState(player)
	if not state then
		return false, "no_profile"
	end
	if kind ~= "main" and not PlayerProfile.getTutorialCompleted(player) then -- 리뷰 4: 견습 중에는 접속 · 일간 · 주간 · 상자 보상 없음(메인 1단계 = 견습 마치기만)
		return false, "tutorial"
	end
	local now, facts = os.time(), PlayerProfile.getQuestFacts(player)
	local probeReward = Quest.claim(deepCopy(state), kind, id, now, facts) -- 리뷰 4: 알 보상은 가방에 자리가 있을 때만(받은 표시를 먼저 확정하고 알이 사라지던 문제)
	if probeReward and (probeReward.egg or 0) > 0 and #PlayerProfile.getEggs(player) + probeReward.egg > NestData.eggCap then
		return false, "egg_full"
	end
	local reward, why = Quest.claim(state, kind, id, now, facts)
	if not reward then
		return false, why
	end
	local summary = QuestService.grant(player, reward)
	print(("[Q6] 퀘스트 보상: %s %s %s → %s"):format(player.Name, tostring(kind), tostring(id), summary))
	require(script.Parent.ImmediateSave).request(player)
	push(player)
	return true, summary
end

function QuestService.train(player, kind, id)
	if not PlayerProfile.getTutorialCompleted(player) then -- 리뷰 4: 견습 중 수련 없음
		return false, "tutorial"
	end
	local ok, levelOrWhy, cost = PlayerProfile.buyTraining(player, kind, id)
	if ok then
		print(("[Q6] 수련: %s %s %s → 단계 %d(골드 %d)"):format(player.Name, kind, tostring(id), levelOrWhy, cost))
		QuestService.note(player, "train", 1)
		push(player)
	end
	return ok, levelOrWhy
end

function QuestService.onLoaded(player)
	local state = PlayerProfile.getQuestState(player)
	if state then
		Quest.roll(state, os.time())
		push(player)
	end
end

function QuestService.start()
	local remote = ReplicatedStorage:FindFirstChild("QuestRequest") or Instance.new("RemoteEvent")
	remote.Name = "QuestRequest"
	remote.Parent = ReplicatedStorage
	updateRemote = ReplicatedStorage:FindFirstChild("QuestUpdate") or Instance.new("RemoteEvent")
	updateRemote.Name = "QuestUpdate"
	updateRemote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player, action, a, b)
		local now = os.clock()
		local key = tostring(action) -- 리뷰 4: 요청 제한을 동작별로(창 열 때 view 직후의 [받기]가 버려지지 않게)
		lastRequest[player] = lastRequest[player] or {}
		if lastRequest[player][key] and now - lastRequest[player][key] < 0.2 then
			return
		end
		lastRequest[player][key] = now
		if action == "view" then
			push(player)
		elseif action == "claim" and type(a) == "string" and (b == nil or type(b) == "string") then
			QuestService.claim(player, a, b)
		elseif action == "train" and (a == "stat" or a == "ability") and type(b) == "string" then
			QuestService.train(player, a, b)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return QuestService
