-- QUEUE-ALL1 P5 도감 v2(서버). 규칙 = shared/CodexRules · 수치 = shared/data/CodexData · 저장 = profile.codex(v59).
--   기록: noteArmor(드랍 줍기 - 자동 판매 · 분해 포함) · notePet(부화) · noteMonster(잡몹 처치 · 반짝이) · noteBoss(보스 처치 - 기여 10% 이상) · noteClass(환생 무기 등급) · 둥지 = nestDex 그대로.
--   완료 순간 = done[칸] = 계정 최고 스테이지(골드 고정) · 줄 완성 = 칭호 즉시 · [받기] = CodexRequest("claim", 칸 id | "all" | "board:<점수>") · 칭호 선택 = ("title", id | "").
--   화면 = CodexUpdate(서버 → 클라 표 - 클라는 계산하지 않는다 · 둥지 id는 안 보낸다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CodexData = require(ReplicatedStorage.Shared.data.CodexData)
local CodexRules = require(ReplicatedStorage.Shared.CodexRules)
local Text = require(ReplicatedStorage.Shared.Text)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local TitleData = require(ReplicatedStorage.Shared.data.TitleData)
local NestData = require(ReplicatedStorage.Shared.data.NestData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local PlayerProfile = require(script.Parent.PlayerProfile)

local CodexService = {}

local requestRemote = Instance.new("RemoteEvent")
requestRemote.Name = "CodexRequest"
requestRemote.Parent = ReplicatedStorage
local updateRemote = Instance.new("RemoteEvent")
updateRemote.Name = "CodexUpdate"
updateRemote.Parent = ReplicatedStorage
local noticeRemote = Instance.new("RemoteEvent")
noticeRemote.Name = "CodexNotice"
noticeRemote.Parent = ReplicatedStorage

local nestsByZone = {}
do
	local m = ServerScriptService:FindFirstChild("SecretNestData", true)
	for _, spec in ipairs(m and require(m) or {}) do
		if spec.track == "C" and spec.sub ~= "village" and CodexData.zoneShort[spec.zone] then
			nestsByZone[spec.zone] = nestsByZone[spec.zone] or {}
			table.insert(nestsByZone[spec.zone], spec.id)
		end
	end
end
local BUILT = CodexRules.build(nestsByZone)
CodexService.built = BUILT

local function goldPerKill(stage)
	return InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, stage)
end

local function rec(player)
	return PlayerProfile.getCodex(player)
end

local function nestDex(player)
	return PlayerProfile.getNestDex(player) or {}
end

-- QUEUE-MENU2 B2: 도감 칸 보상 몰아주기 차단 - 칸 보상(골드 · 재료)은 그 칸을 완료한 캐릭터만 받는다(r.doneBy[칸] = 캐릭터 번호 · 옛 기록 = 없음 = 누구나)
local function currentCharId(player)
	local sess = require(script.Parent.SaveSystem).slotSessionOf(player)
	return sess and sess.charId or nil
end
local function cellMine(player, r, id)
	return CodexRules.cellMine(r, id, currentCharId(player))
end

local pending = {}
local refresh

local function schedule(player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(0.5, function()
		pending[player] = nil
		if player.Parent then
			refresh(player)
		end
	end)
end

-- 점수 · 완료 표시 · 줄 칭호(보너스 줄 제외)
local function scoreOf(r)
	local s = 0
	for id in pairs(r.done) do
		local c = BUILT.byId[id]
		s += c and c.score or 0
	end
	return s
end

local function viewOf(player, r)
	local dex = nestDex(player)
	local cells = {}
	for _, c in ipairs(BUILT.cells) do
		local v = CodexRules.progress(r, dex, c)
		cells[c.id] = { v = v, need = c.need, done = r.done[c.id] ~= nil, claimed = r.claimed[c.id] == true, label = c.label, tab = c.tab, otherChar = r.done[c.id] ~= nil and not cellMine(player, r, c.id) or nil }
	end
	local lines = {}
	for id, l in pairs(BUILT.lines) do
		lines[id] = { tab = l.tab, titleId = l.titleId, titleName = TitleData.titles[l.titleId] and TitleData.titles[l.titleId].name, done = PlayerProfile.hasTitle(player, l.titleId), cells = l.cells }
	end
	local board = {}
	local score = scoreOf(r)
	for _, t in ipairs(CodexData.board) do
		local key = tostring(t)
		table.insert(board, { threshold = t, done = r.boardDone[key] ~= nil, claimed = r.boardClaimed[key] == true })
	end
	local owned = {}
	for id, t in pairs(TitleData.titles) do
		if PlayerProfile.hasTitle(player, id) then
			table.insert(owned, { id = id, name = t.name, grade = t.grade })
		end
	end
	table.sort(owned, function(a, b)
		return a.name < b.name
	end)
	local hiddenIds = {} -- QUEUE-ALL9E1 0-2 히든 칭호: 얻기 전엔 이름 · 조건 없이 "???" 줄만(끝에 · id 순)
	for id, t in pairs(TitleData.titles) do
		if t.hidden and not PlayerProfile.hasTitle(player, id) then
			table.insert(hiddenIds, id)
		end
	end
	table.sort(hiddenIds)
	for i in ipairs(hiddenIds) do
		table.insert(owned, { id = "hidden" .. i, hidden = true }) -- 리뷰: 진짜 id는 보내지 않는다(이름 · 조건 추측 방지)
	end
	return { cells = cells, lines = lines, board = board, score = score, total = BUILT.totalScore, trans = r.trans, titles = owned, selected = r.title }
end

function refresh(player)
	local r = rec(player)
	if not r then
		return
	end
	local dex = nestDex(player)
	local stage = PlayerProfile.getAccountBestStage(player)
	local changed = false
	for _, c in ipairs(BUILT.cells) do
		if not r.done[c.id] then
			local _, complete = CodexRules.progress(r, dex, c)
			if complete then
				r.done[c.id] = stage
				r.doneBy = type(r.doneBy) == "table" and r.doneBy or {}
				r.doneBy[c.id] = currentCharId(player) -- QUEUE-MENU2 B2: 완료한 캐릭터(골드 기준 = 그 캐릭터 스테이지 - stage가 캐릭터 최고)
				changed = true
			end
		end
	end
	for _, l in pairs(BUILT.lines) do
		local all = #l.cells > 0
		for _, id in ipairs(l.cells) do
			if not r.done[id] then
				all = false
				break
			end
		end
		if all and PlayerProfile.grantTitle(player, l.titleId) then
			local lineTokens = CodexData.lineTokens(#l.cells) -- QUEUE-ALL9B 3-6 줄 완성 토큰(칸 수 × linePerCell - 칭호 1회와 같이 1회)
			if lineTokens > 0 then
				require(script.Parent.QuestService).grant(player, { sparkleShard = lineTokens })
			end
			local t = TitleData.titles[l.titleId]
			noticeRemote:FireClient(player, "srv.codex.lineDone", { title = t and t.name or l.titleId, titleId = l.titleId }) -- QUEUE-ALL6R 3: 키 + 인자(칭호 = 클라 CodexRules.titleText - 도감 칭호는 틀 + 이름을 따로 번역)
			changed = true
		end
	end
	local score = scoreOf(r)
	for _, t in ipairs(CodexData.board) do
		local key = tostring(t)
		if score >= t and not r.boardDone[key] then
			r.boardDone[key] = stage
			changed = true
		end
	end
	local claimable = false
	for id in pairs(r.done) do
		if not r.claimed[id] and cellMine(player, r, id) then
			claimable = true
			break
		end
	end
	for key in pairs(r.boardDone) do
		if not r.boardClaimed[key] then
			claimable = true
		end
	end
	player:SetAttribute("CodexClaimable", claimable)
	player:SetAttribute("CodexScore", score)
	if changed then
		require(script.Parent.ImmediateSave).request(player)
	end
	updateRemote:FireClient(player, viewOf(player, r))
end
CodexService.refresh = refresh

-- 지급(골드 · 강화석 · 반짝 조각 · 보석 가루 · 그 구역 알). 알 가방이 가득이면 false(칸은 안 받은 채로 남는다)
local function pay(player, reward)
	if reward.eggZone then
		local pool = EggData.zones[reward.eggZone].pool
		local a = math.random(1, #pool)
		local b = (a % #pool) + 1
		if not PlayerProfile.addEgg(player, { zone = reward.eggZone, grade = "normal", species = { pool[a], pool[b] }, nest = "codex", at = os.time() }, NestData.eggCap) then
			return false, nil
		end
	end
	local parts = {}
	if reward.gold and reward.gold > 0 then
		PlayerProfile.addGold(player, reward.gold)
		table.insert(parts, Text.getFor(player, "srv.reward.gold", { n = ("%d"):format(reward.gold) }))
	end
	if reward.gemDust then
		PlayerProfile.addGemDust(player, reward.gemDust)
		table.insert(parts, Text.getFor(player, "srv.reward.gemDust", { n = ("%d"):format(reward.gemDust) }))
	end
	local q = {}
	for _, k in ipairs({ "enhanceStone", "sparkleShard" }) do
		if reward[k] then
			q[k] = reward[k]
		end
	end
	local s = require(script.Parent.QuestService).grant(player, q)
	if s ~= "" then
		table.insert(parts, s)
	end
	if reward.eggZone then
		table.insert(parts, Text.getFor(player, "srv.reward.egg"))
	end
	return true, table.concat(parts, " · ")
end

local function claimCell(player, r, id)
	local c = BUILT.byId[id]
	if not c or not r.done[id] or r.claimed[id] then
		return nil
	end
	if not cellMine(player, r, id) then
		return nil -- QUEUE-MENU2 B2: 다른 캐릭터가 완료한 칸
	end
	local ok, summary = pay(player, CodexRules.reward(c, r.done[id], goldPerKill))
	if not ok then
		return false
	end
	r.claimed[id] = true
	require(script.Parent.QuestService).note(player, "codexClaim", 1) -- QUEUE-ALL3 Q3 초반 여정(도감 칸 받기)
	return summary
end

local function claimBoard(player, r, key)
	if not r.boardDone[key] or r.boardClaimed[key] then
		return nil
	end
	local ok, summary = pay(player, CodexRules.reward({ kind = "board", threshold = tonumber(key) }, r.boardDone[key], goldPerKill))
	if ok then
		r.boardClaimed[key] = true
	end
	return ok and summary or false
end

local lastReq = {}
requestRemote.OnServerEvent:Connect(function(player, action, arg)
	local now = os.clock()
	if lastReq[player] and now - lastReq[player] < 0.2 then
		return
	end
	lastReq[player] = now
	local r = rec(player)
	if not r then
		return
	end
	if action == "view" then
		refresh(player)
	elseif action == "claim" and type(arg) == "string" then
		local got, eggFull = {}, false
		local function one(summary)
			if summary == false then
				eggFull = true
			elseif summary then
				table.insert(got, summary)
			end
		end
		if arg == "all" then
			for _, c in ipairs(BUILT.cells) do
				if r.done[c.id] and not r.claimed[c.id] and cellMine(player, r, c.id) then
					one(claimCell(player, r, c.id))
				end
			end
			for _, t in ipairs(CodexData.board) do
				one(claimBoard(player, r, tostring(t)))
			end
		elseif arg:sub(1, 6) == "board:" then
			one(claimBoard(player, r, arg:sub(7)))
		else
			if r.done[arg] and not r.claimed[arg] and not cellMine(player, r, arg) then
				noticeRemote:FireClient(player, "srv.codex.otherChar") -- QUEUE-MENU2 B2
			end
			one(claimCell(player, r, arg))
		end
		if #got > 0 then
			print(("[forge-game] 도감 받기: %s %d칸"):format(player.Name, #got))
			noticeRemote:FireClient(player, "srv.codex.got", { summary = #got == 1 and got[1] or Text.getFor(player, "srv.codex.cells", { count = tostring(#got) }) }) -- QUEUE-ALL6R 3: 받은 내용 = 그 플레이어 언어로 만든 조각(Text.getFor)
			require(script.Parent.ImmediateSave).request(player)
		end
		if eggFull then
			noticeRemote:FireClient(player, "srv.codex.eggFull")
		end
		refresh(player)
	elseif action == "title" and type(arg) == "string" then
		if arg == "" or (TitleData.titles[arg] and PlayerProfile.hasTitle(player, arg)) then
			r.title = arg ~= "" and arg or nil
			player:SetAttribute("SelectedTitle", r.title or "")
			refresh(player)
		end
	end
end)

-- QUEUE-ALL6 F4 운영 회수: 그 구역 초월 기록 지우기(가짜 초월 회수 - 그 세트 세로줄 즉시 완료가 풀린다 · 받은 칸 보상은 그대로)
function CodexService.forgetTranscendent(player, zone)
	local r = rec(player)
	if r and r.trans and zone then
		r.trans[zone] = nil
		schedule(player)
	end
end

-- ═══ 기록 ═══
function CodexService.noteArmor(player, item)
	local r = rec(player)
	if not r or type(item) ~= "table" or type(item.source) ~= "table" or item.source.kind == "dev" then
		return
	end
	local zone = item.setZone
	if not (zone and CodexData.zoneShort[zone]) then
		return
	end
	if item.grade == "transcendent" then
		r.trans[zone] = true
	elseif item.grade == "primordial" then
		r.prim[zone] = true
	elseif CodexData.armor.need[item.grade] and item.part then
		local key = ("%s|%s|%s"):format(zone, item.grade, item.part)
		r.armor[key] = (tonumber(r.armor[key]) or 0) + 1
	end
	schedule(player)
end

function CodexService.notePet(player, pet)
	local r = rec(player)
	if r and type(pet) == "table" and pet.species and pet.grade then
		r.pet[pet.species .. "|" .. pet.grade] = true
		schedule(player)
	end
end

function CodexService.noteMonster(player, speciesId, isSparkle)
	local r = rec(player)
	if r and type(speciesId) == "string" then
		r.mkill[speciesId] = (tonumber(r.mkill[speciesId]) or 0) + 1
		if isSparkle then
			r.msparkle[speciesId] = true
		end
		local n = r.mkill[speciesId]
		if n == 1 or n == 10 or n == 100 or n == 1000 or isSparkle then -- 칸 문턱에서만 다시 본다
			schedule(player)
		end
	end
end

function CodexService.noteBoss(player, bossId)
	local r = rec(player)
	if r and type(bossId) == "string" then
		r.boss[bossId] = (tonumber(r.boss[bossId]) or 0) + 1
		schedule(player)
	end
end

function CodexService.noteClass(player, classId, grade)
	local r = rec(player)
	if r and type(classId) == "string" and type(grade) == "number" then
		r.cls[classId] = math.max(tonumber(r.cls[classId]) or 0, grade)
		schedule(player)
	end
end

-- FINAL-1b 결정 6: 그 직업 무기 초월(계승) 달성 = 도감 직업 줄 8번째 칸
function CodexService.noteClassTranscend(player, classId)
	local r = rec(player)
	if r and type(classId) == "string" then
		r.clsT = type(r.clsT) == "table" and r.clsT or {}
		if not r.clsT[classId] then
			r.clsT[classId] = true
			schedule(player)
		end
	end
end

function CodexService.noteNest(player)
	schedule(player)
end

function CodexService.onLoaded(player)
	local r = rec(player)
	if not r then
		return
	end
	local classId = PlayerProfile.getClassId and PlayerProfile.getClassId(player)
	if classId and r.cls[classId] == nil then
		r.cls[classId] = 0 -- 직업을 고른 순간 = 무기 일반
	end
	player:SetAttribute("SelectedTitle", r.title or "")
	schedule(player)
end

Players.PlayerRemoving:Connect(function(p)
	lastReq[p] = nil
	pending[p] = nil
end)

return CodexService
