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
local Text = require(ReplicatedStorage.Shared.Text)
local PlayerProfile = require(script.Parent.PlayerProfile)

local QuestService = {}

local updateRemote
local lastRequest = {}

local function questNames(player, list, progress)
	local rows = {}
	for _, q in ipairs(list) do
		local p = progress[q.id]
		table.insert(rows, { id = q.id, name = Quest.nameOf(q, Text.nameFor(player, q.name)), n = p and p.n or 0, target = q.target, claimed = p and p.claimed == true, reward = q.reward })
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
		daily = questNames(player, Quest.dailyFor(state.day), state.daily), -- QUEUE-ALL6 A4: 이름 = 그 플레이어 언어(틀을 바꾼 뒤 {n} 채움)
		weekly = questNames(player, QuestData.weekly, state.weekly),
		loginReady = state.loginDay ~= state.day,
		chestReady = chestReady and state.chestDay ~= state.day,
		chestClaimed = state.chestDay == state.day, -- Play C: 받은 뒤 버튼 글 = 받음
		main = step and (function()
			local n, need = Quest.mainProgress(step, facts, state)
			return { index = state.main, total = #QuestData.main, id = step.id, name = Quest.nameOf(step, Text.nameFor(player, step.name)), unlock = step.unlock, done = Quest.mainDone(step, facts, state), reward = step.reward,
				n = n, target = need, guide = step.guide } -- QUEUE-ALL3 Q3: 진행 · [길 안내] 목적지
		end)() or nil,
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

-- QUEUE-ALL1 01 A-4 퀘스트 아이콘 빨간 점: 지금 받을 보상이 하나라도 있나(창을 안 열어도 - Player Attribute QuestClaimable). 견습 중엔 메인만 받는다(claim 규칙과 같다).
local function claimableOf(player, v)
	if not v then
		return false
	end
	if v.main and v.main.done then
		return true
	end
	if not PlayerProfile.getTutorialCompleted(player) then
		return false
	end
	if v.loginReady or v.chestReady then
		return true
	end
	for _, list in ipairs({ v.daily or {}, v.weekly or {} }) do
		for _, q in ipairs(list) do
			if q.n >= q.target and not q.claimed then
				return true
			end
		end
	end
	if v.attendance then
		for _, entry in ipairs(v.attendance.rewards) do
			if entry.day <= v.attendance.count and v.attendance.claimed[tostring(entry.day)] ~= true then
				return true
			end
		end
	end
	return false
end
QuestService.claimableOf = claimableOf

local function push(player)
	QuestService.syncWallet(player)
	local v = QuestService.view(player)
	if updateRemote and typeof(player) == "Instance" and player.Parent then
		updateRemote:FireClient(player, v)
	end
	local state = PlayerProfile.getQuestState(player)
	if state and typeof(player) == "Instance" then -- HUD 칩(메인 퀘스트 단계 · 받을 것 있음) - 클라 길 안내 · 점
		player:SetAttribute("MainQuestStep", state.main)
		player:SetAttribute("QuestClaimable", claimableOf(player, v))
	end
end
QuestService.push = push

-- QUEUE-ALL6 C: 지갑 Attribute(보상 칸 펼쳐 보기의 "가진 것" - 클라 ItemInfoData.owned.attr). 반짝 조각 · 환생 무료권 · 시즌 경험치(나머지 재화는 PlayerProfile이 이미 내린다)
function QuestService.syncWallet(player)
	local state = PlayerProfile.getQuestState(player)
	if state and state.currencies and typeof(player) == "Instance" then
		player:SetAttribute("SparkleShard", state.currencies.sparkleShard or 0)
		player:SetAttribute("RebirthTicket", state.currencies.rebirthTicket or 0)
		player:SetAttribute("PassExp", state.currencies.passExp or 0)
	end
end

-- 보상 지급(한 곳). 반환 = 지급 요약 문자열(로그)
function QuestService.grant(player, reward)
	local parts = {}
	if not reward then
		return ""
	end
	local state = PlayerProfile.getQuestState(player)
	if reward.gold then
		local gold = GoldCost.rewardGold(MonsterData.tier1.goldDrop, reward.gold, PlayerProfile.getAccountBestStage(player)) -- QUEUE-ALL6 D: 보기 좋은 숫자(지급 = 표시)
		PlayerProfile.addGold(player, gold)
		table.insert(parts, Text.getFor(player, "srv.reward.gold", { n = ("%d"):format(gold) }))
	end
	if reward.enhanceStone then
		PlayerProfile.addMaterial(player, "enhanceStone", reward.enhanceStone)
		table.insert(parts, Text.getFor(player, "srv.reward.enhanceStone", { n = ("%d"):format(reward.enhanceStone) }))
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
		table.insert(parts, Text.getFor(player, ok and "srv.reward.egg" or "srv.reward.eggFull"))
	end
	if state and reward.sparkleShard then
		state.currencies.sparkleShard = (state.currencies.sparkleShard or 0) + reward.sparkleShard
		require(script.Parent.Telemetry).economy(player, "sparkleShard", "source", reward.sparkleShard, "TimedReward")
		table.insert(parts, Text.getFor(player, "srv.reward.sparkleShard", { n = ("%d"):format(reward.sparkleShard) }))
	end
	if state and reward.rebirthTicket then -- Q12 7일 출석 2일차(자리 - 지금 환생은 비용이 없어 쓰는 곳 없음)
		state.currencies.rebirthTicket = (state.currencies.rebirthTicket or 0) + reward.rebirthTicket
		table.insert(parts, Text.getFor(player, "srv.reward.rebirthTicket", { n = ("%d"):format(reward.rebirthTicket) }))
	end
	if reward.gemDust then -- QUEUE-ALL3 Q3: 보석 첫 장착 = 보석 가루(기존 재화)
		PlayerProfile.addGemDust(player, reward.gemDust)
		table.insert(parts, Text.getFor(player, "srv.reward.gemDust", { n = ("%d"):format(reward.gemDust) }))
	end
	if reward.protectDrop then -- QUEUE-ALL3 Q3: 하락 구간 앞 = 하락 방지권(기존 재화)
		PlayerProfile.addProtectionTicket(player, "drop", reward.protectDrop)
		table.insert(parts, Text.getFor(player, "srv.reward.protectDrop", { n = ("%d"):format(reward.protectDrop) }))
	end
	if state and reward.passExp then
		state.currencies.passExp = (state.currencies.passExp or 0) + reward.passExp
		table.insert(parts, Text.getFor(player, "srv.reward.passExp", { n = ("%d"):format(reward.passExp) }))
	end
	QuestService.syncWallet(player)
	return table.concat(parts, " · ")
end

-- 서버 이벤트 → 진행
local usedEvents = {} -- 리뷰: 일간 · 주간 · 이정표 어디에도 없는 이벤트는 바로 돌아간다(스킬 · 줍기는 자주 온다)
for _, list in ipairs({ QuestData.dailyPool, QuestData.weekly, QuestData.ftue, QuestData.main }) do
	for _, q in ipairs(list) do
		if q.event then
			usedEvents[q.event] = true
		end
	end
end

function QuestService.note(player, event, amount)
	local state = PlayerProfile.getQuestState(player)
	if not state or not usedEvents[event] then
		return
	end
	local mainStep = QuestData.main[state.main]
	if not state.guide and (event == "skill" or event == "ult" or event == "pickup" or event == "equip") and not (mainStep and mainStep.event == event) then
		return -- 이정표를 마쳤으면 이 넷은 일간 · 주간에 없다(위 표) - dailyFor 셔플을 매번 돌지 않게(메인 단계가 세는 이벤트면 센다)
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
	require(script.Parent.Telemetry).funnel(player, step) -- Q15: 퍼널 = Telemetry(Studio = 드라이런 로그)
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

-- QUEUE-ALL3 Q3 탐험 단계: 2초마다 위치 → "zone:<구역>"(구역 원 안) · "ground"(사냥 지대 원 안 - 곳마다 접속 동안 1번) · "lookout"(큰 나무 전망대 높이). 판정 = 서버(클라 보고 없음)
local visitedGrounds = {}
local function scanPlaces()
	local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
	local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
	local deck = WorldMapData.hub.tree.course and WorldMapData.hub.tree.course.deck
	for _, player in ipairs(Players:GetPlayers()) do
		local state = PlayerProfile.getQuestState(player)
		local step = state and QuestData.main[state.main]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if step and step.cond == "event" and root then
			local pos = root.Position
			if step.event:sub(1, 5) == "zone:" then
				local zone = WorldMapLayout.zoneAt(pos)
				if zone and "zone:" .. zone.key == step.event then
					QuestService.note(player, step.event, 1)
				end
			elseif step.event == "ground" then
				local zone = WorldMapLayout.zoneAt(pos)
				for _, g in ipairs(zone and WorldMapLayout.grounds(zone) or {}) do
					local key = zone.key .. g.index
					visitedGrounds[player] = visitedGrounds[player] or {}
					if not visitedGrounds[player][key] and Vector3.new(pos.X - g.center.X, 0, pos.Z - g.center.Z).Magnitude <= g.radius then
						visitedGrounds[player][key] = true
						QuestService.note(player, "ground", 1)
					end
				end
			elseif step.event == "lookout" and deck and pos.Y >= WorldMapData.floorTopY + deck.y - 12 and Vector3.new(pos.X, 0, pos.Z).Magnitude <= 120 then
				QuestService.note(player, "lookout", 1)
			end
		end
	end
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
	local QUEST_ACTIONS = { view = true, claim = true, train = true }
	remote.OnServerEvent:Connect(function(player, action, a, b)
		if type(action) ~= "string" or not QUEST_ACTIONS[action] then -- QUEUE-6h-b R3 F5(보안): 허용 동작만 제한 표에(임의 문자열로 표가 커지지 않게)
			return
		end
		local now = os.clock()
		local key = action -- 리뷰 4: 요청 제한을 동작별로(창 열 때 view 직후의 [받기]가 버려지지 않게)
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
		visitedGrounds[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			local ok, err = pcall(scanPlaces)
			if not ok then
				warn("[Q3] 탐험 단계 판정 오류: " .. tostring(err))
			end
		end
	end)
end

return QuestService
