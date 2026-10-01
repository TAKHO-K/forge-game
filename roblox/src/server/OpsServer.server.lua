-- S1 2-8 운영 명령(라이브 · Studio): 채팅 "/ops …" - 허용 계정(OpsConfig.userIds)만 · 서버가 인자를 검증 · 모든 시도를 기록(AuditConfig.opsLogStore).
--   /ops release <userId> <번호|rollId>   격리 해제(원장 확인 뒤 운영 판단 - 그 사람이 이 서버에 있어야 한다)
--   /ops revoke <userId> <번호|rollId>    회수(아이템은 남기되 revoked · 번호 = 결번 · 칭호 다시 판정)
--   /ops lbremove <personal|class_<직업>> <userId>   리더보드 항목 제거
--   /ops versions <userId>                저장 버전 목록(DataStore 30일 보관)
--   /ops restore <userId> <version>        저장 버전 복구(그 사람이 이 서버에 없어야 한다 - 다른 서버 접속은 운영 절차로 확인)
--   /ops review <userId>                  검토 대기 목록(최근)
--   /ops gift <userId> <cosmeticTheme|gliderSkin|sparkleShard> <id|개수> [메모]   선물함에 치장 · 치장 재화 넣기(QUEUE-B1 B2 - 치장만 · 이 서버에 없으면 다음 접속 때)
--   /ops stats [all]                       알파 통계(C1 끌어오기 계측 - 이 서버 메모리 · all = 서버 종료 때 저장된 요약 합 - S1 후속 0-5)
--   QUEUE-ALL6 F(절차 = docs/phase/security-runbook.md · 기준값 = shared/data/SecurityOpsConfig):
--   /ops inspect <userId>                   프로필 요약 · 최근 의심 기록 · 감사 기록
--   /ops rollback <userId> <버전|UTC 시각>   미리보기 + 확인 번호 → /ops rollback confirm <번호> = 실행(접속 중이면 내보냄 · 다른 서버가 저장을 쥐고 있으면 MessagingService로 그 서버에서 내보내고 놓을 때까지 대기 · 지금 저장본 백업 · 그 사람만)
--   /ops revoke <userId> t<번호>            가짜 초월 회수 미리보기 + 확인 번호 → /ops revoke confirm <번호> = 실행(아이템 삭제 · 세계 번호 결번 · 초월자 칭호 · 도감 초월 줄 - QUEUE-ALL6R)
--   /ops revoke <userId> <재화> <수량>       재화 회수(0 아래로 안 내려감)
--   /ops leaderboard remove <userId>        개인 · 직업 순위 + 이번 주 주간 도전 기록 제거
--   /ops ban <userId> <1d|3d|7d|30d|perm> <사유>  ·  /ops unban <userId>   로블록스 기본 차단(Players:BanAsync · 경험 전체 · 부계정 포함) · perm = 미리보기 + /ops ban confirm <번호>(QUEUE-ALL6R)
-- 결과는 명령한 사람 채팅 줄(시스템 메시지)로 돌려준다. 자동 제재는 없다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local TextChatService = game:GetService("TextChatService")

local AuditConfig = require(ReplicatedStorage.Shared.data.AuditConfig)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local OpsConfig = require(script.Parent.OpsConfig)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveSystem = require(script.Parent.SaveSystem)
local Leaderboard = require(script.Parent.Leaderboard)
local AcquisitionAudit = require(script.Parent.AcquisitionAudit)

local isStudio = RunService:IsStudio()
local replyRemote = Instance.new("RemoteEvent")
replyRemote.Name = "OpsReply"
replyRemote.Parent = ReplicatedStorage

local Ops = {}
Ops.lastLog = nil -- 검증 훅

local function allowed(player)
	return typeof(player) == "Instance" and table.find(OpsConfig.userIds, player.UserId) ~= nil
end

local function logOps(player, text, result)
	local entry = { by = player.UserId, name = player.Name, text = text, result = result, at = os.time(), jobId = game.JobId }
	Ops.lastLog = entry
	print(("[forge-game] 운영 명령: %s \"%s\" → %s"):format(player.Name, text, tostring(result)))
	task.spawn(function()
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore(AuditConfig.opsLogStore)
		end)
		if ok and store then
			pcall(function()
				store:UpdateAsync((isStudio and AuditConfig.testKeyPrefix or "") .. "log", function(list)
					list = type(list) == "table" and list or {}
					table.insert(list, 1, entry)
					while #list > AuditConfig.opsLogKeep do
						table.remove(list)
					end
					return list
				end)
			end)
		end
	end)
end

local function findItem(userId, ref)
	local target = Players:GetPlayerByUserId(userId)
	local profile = target and PlayerProfile.getProfile(target)
	if not profile then
		return nil, nil, "not_online"
	end
	for _, item in ipairs(AcquisitionAudit.primordialItems(profile)) do
		local stamp = item.primordial
		if type(stamp) == "table" and (tostring(stamp.no) == ref or stamp.rollId == ref) then
			return target, item
		end
	end
	return target, nil, "no_item"
end

local handlers = {}
function handlers.release(args)
	local target, item, why = findItem(tonumber(args[2]) or 0, tostring(args[3]))
	if not item then
		return why
	end
	item.primordial.quarantined = nil
	item.primordial.releasedByOps = os.time()
	AcquisitionAudit.includeNumber(item.primordial.no) -- 리뷰 2: 결번 목록에서도 뺀다
	PlayerProfile.pushInventory(target)
	require(script.Parent.ImmediateSave).request(target)
	return "released"
end
local SecurityOps = require(ReplicatedStorage.Shared.data.SecurityOpsConfig)
local AuditTrail = require(script.Parent.AuditTrail)
local OpsRollback = require(script.Parent.OpsRollback)

-- 확인 번호(되돌리기 · 영구 차단 · 초월 회수 - 같은 표): [번호] = { kind, userId, at, by, … }
local pendingConfirm = {}
local function issueToken(entry)
	local token
	repeat
		token = tostring(math.random(100000, 999999))
	until not pendingConfirm[token]
	entry.at = os.time()
	pendingConfirm[token] = entry
	return token
end
local function takeToken(kind, token, player)
	local p = pendingConfirm[tostring(token or "")]
	if not p or p.kind ~= kind or p.by ~= player.UserId then -- 리뷰: 남의 번호는 지우지 않는다(다른 운영자가 잘못 넣어도 그대로)
		return nil
	end
	pendingConfirm[tostring(token)] = nil
	if os.time() - p.at > SecurityOps.rollback.confirmSeconds then
		return nil
	end
	return p
end


-- QUEUE-ALL6 F: 가짜 초월 회수(t<번호>) · 재화 회수
local function revokeTranscendent(userId, no)
	local target = Players:GetPlayerByUserId(userId)
	local profile = target and PlayerProfile.getProfile(target)
	if not profile then
		return "not_online"
	end
	local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData)
	local function matches(item)
		return type(item) == "table" and item.grade == TranscendentData.gradeId and type(item.primordial) == "table" and tostring(item.primordial.no) == no
	end
	local zone
	for i = #profile.inventory, 1, -1 do
		if matches(profile.inventory[i]) then
			zone = profile.inventory[i].setZone or zone or "?"
			table.remove(profile.inventory, i)
		end
	end
	for _, cs in pairs(profile.classes or {}) do
		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			if cs.equipment and matches(cs.equipment[part]) then
				zone = cs.equipment[part].setZone or zone or "?"
				cs.equipment[part] = nil
			end
		end
	end
	if not zone then
		return "no_item"
	end
	AcquisitionAudit.excludeNumber("t" .. no, "revoked") -- 명예의 전당(초월 번호 = 별도 카운터 → "t" 접두사로 결번)
	-- 초월자 칭호 · 도감 초월 줄: 남은 초월이 없을 때만(같은 구역 초월이 남았으면 그 줄은 그대로)
	local left, leftZone = 0, false
	for _, item in ipairs(AcquisitionAudit.primordialItems(profile)) do
		if item.grade == TranscendentData.gradeId then
			left += 1
			leftZone = leftZone or item.setZone == zone
		end
	end
	if left == 0 then
		PlayerProfile.revokeTitle(target, "transcendentOne")
	end
	if not leftZone then
		require(script.Parent.CodexService).forgetTranscendent(target, zone)
	end
	PlayerProfile.pushInventory(target)
	require(script.Parent.ImmediateSave).request(target)
	return "revoked_transcendent"
end
Ops.revokeTranscendent = revokeTranscendent -- 검증 훅

local function revokeCurrency(userId, kind, amount)
	if not SecurityOps.revokeCurrencies[kind] or not amount or amount <= 0 or amount ~= amount then
		return "bad_args"
	end
	local target = Players:GetPlayerByUserId(userId)
	local profile = target and PlayerProfile.getProfile(target)
	if not profile then
		return "not_online"
	end
	local before
	if kind == "gold" then
		before = profile.gold
		profile.gold = math.max(0, profile.gold - amount)
		target:SetAttribute("Gold", profile.gold)
	elseif kind == "gemDust" then
		before = PlayerProfile.getGemDust(target)
		PlayerProfile.addGemDust(target, -math.min(amount, before))
	elseif kind == "sparkleShard" then
		local q = PlayerProfile.getQuestState(target)
		before = q and q.currencies.sparkleShard or 0
		if q then
			q.currencies.sparkleShard = math.max(0, before - amount)
			target:SetAttribute("SparkleShard", q.currencies.sparkleShard)
		end
	else
		before = PlayerProfile.getMaterial(target, kind)
		PlayerProfile.addMaterial(target, kind, -math.min(amount, before))
	end
	require(script.Parent.ImmediateSave).request(target)
	return ("revoked %s %d → %d"):format(kind, before or 0, math.max(0, (before or 0) - amount))
end

-- QUEUE-ALL6R 결정 8: 초월 회수 미리보기(지우지 않고 찾기만) - 있으면 몇 개 · 어느 구역
local function previewTranscendent(userId, no)
	local target = Players:GetPlayerByUserId(userId)
	local profile = target and PlayerProfile.getProfile(target)
	if not profile then
		return nil, "not_online"
	end
	local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData)
	for _, item in ipairs(AcquisitionAudit.primordialItems(profile)) do
		if item.grade == TranscendentData.gradeId and type(item.primordial) == "table" and tostring(item.primordial.no) == no then
			return item
		end
	end
	return nil, "no_item"
end

function handlers.revoke(args, player)
	local userId = tonumber(args[2]) or 0
	local ref = tostring(args[3])
	if args[2] == "confirm" then
		local p = takeToken("revokeTranscendent", args[3], player)
		if not p then
			return "no_pending(확인 번호가 없거나 시간이 지났다)"
		end
		local result = revokeTranscendent(p.userId, p.no)
		AuditTrail.note(p.userId, "ops_revoke", ("t%s → %s(%s)"):format(tostring(p.no), tostring(result), player.Name)) -- 리뷰: 확인 실행 줄은 대상 칸이 "confirm"이라 아래 공통 기록에 안 잡힌다
		return result
	end
	if ref:match("^t%d+$") then
		if not SecurityOps.confirm.revokeTranscendent then
			return revokeTranscendent(userId, ref:sub(2))
		end
		local item, why = previewTranscendent(userId, ref:sub(2))
		if not item then
			return why
		end
		local token = issueToken({ kind = "revokeTranscendent", userId = userId, no = ref:sub(2), by = player.UserId })
		return ("미리보기: %d의 초월 %s(%s · %s) 삭제 · 세계 번호 결번 · 칭호 · 도감 줄 다시 판정 | 실행 = /ops revoke confirm %s(%d초 안)"):format(userId, ref, tostring(item.setZone), tostring(item.part), token, SecurityOps.rollback.confirmSeconds)
	end
	if SecurityOps.revokeCurrencies[ref] then
		return revokeCurrency(userId, ref, tonumber(args[4]))
	end
	local target, item, why = findItem(userId, ref)
	if not item then
		return why
	end
	item.primordial.revoked = os.time()
	AcquisitionAudit.excludeNumber(item.primordial.no, "revoked")
	if not AcquisitionAudit.titleStillEarned(PlayerProfile.getProfile(target)) then -- 리뷰 9: 자동 격리와 같은 칭호 규칙
		PlayerProfile.revokeTitle(target, PrimordialData.titleId)
	end
	PlayerProfile.pushInventory(target)
	require(script.Parent.ImmediateSave).request(target)
	return "revoked"
end
function handlers.lbremove(args)
	local kind, userId = tostring(args[2]), tonumber(args[3])
	if not userId or not (kind == "personal" or kind:match("^class_%w+$")) then
		return "bad_args"
	end
	return Leaderboard.removeEntry(kind, userId) and "removed" or "failed"
end
function handlers.versions(args)
	local list, err = SaveSystem.opsListVersions(tonumber(args[2]) or 0, 10)
	if not list then
		return "failed: " .. tostring(err)
	end
	local rows = {}
	for _, v in ipairs(list) do
		table.insert(rows, ("%s@%s"):format(v.version, os.date("!%m-%d %H:%M", math.floor(v.createdTime / 1000))))
	end
	return #rows > 0 and table.concat(rows, " · ") or "none"
end
function handlers.restore(args)
	local userId, version = tonumber(args[2]), tostring(args[3] or "")
	if not userId or version == "" then
		return "bad_args"
	end
	if Players:GetPlayerByUserId(userId) then
		return "online_here" -- 메모리 상태가 곧 덮어쓴다 - 먼저 나가게 한 뒤
	end
	local ok, why = SaveSystem.opsRestoreVersion(userId, version)
	return ok and "restored" or ("failed: " .. tostring(why))
end
function handlers.review(args)
	local userId = tonumber(args[2]) or 0
	local rows = {}
	for _, e in ipairs(AcquisitionAudit.log) do
		if e.userId == userId then
			table.insert(rows, ("%s(%s)"):format(e.kind, tostring(e.detail)))
		end
	end
	return #rows > 0 and table.concat(rows, " / ") or "none(이 서버 기록)"
end

-- QUEUE-ALL6 F: inspect · rollback · leaderboard remove · ban · unban
function handlers.inspect(args)
	local userId = tonumber(args[2])
	if not userId then
		return "bad_args"
	end
	local target = Players:GetPlayerByUserId(userId)
	local data = target and PlayerProfile.getProfile(target) or SaveSystem.opsReadCurrent(userId)
	local rows = { "프로필: " .. OpsRollback.describe(OpsRollback.summary(data)) .. (target and "(접속 중)" or "") }
	local flags = {}
	for _, e in ipairs(AcquisitionAudit.log) do
		if e.userId == userId then
			table.insert(flags, ("%s(%s)"):format(e.kind, tostring(e.detail)))
		end
	end
	table.insert(rows, "의심(이 서버): " .. (#flags > 0 and table.concat(flags, " / ", math.max(1, #flags - 4)) or "없음"))
	local trail = AuditTrail.read(userId)
	local t = {}
	for i = 1, math.min(6, #trail) do
		table.insert(t, ("%s %s %s"):format(os.date("!%m-%d %H:%M", trail[i].at), trail[i].k, trail[i].d))
	end
	table.insert(rows, "감사: " .. (#t > 0 and table.concat(t, " / ") or "없음"))
	return table.concat(rows, " | ")
end

-- QUEUE-ALL6R 결정 8: 다른 서버 접속 중인 대상 = MessagingService로 그 서버에 내보내기 부탁(모든 서버가 듣는다 - 그 사람이 있는 서버만 Kick)
local KICK_MESSAGE = "운영 점검으로 잠시 연결을 끊었어요. 다시 들어와 주세요."
local kickTopic = SecurityOps.rollback.kickTopic .. (require(ReplicatedStorage.Shared.data.DevToolsConfig).verifyArmed and "_verify" or "")
Ops.kickTopic = kickTopic -- 검증 훅
local function onKickMessage(data)
	local userId = type(data) == "table" and tonumber(data.userId)
	local target = userId and Players:GetPlayerByUserId(userId)
	print(("[forge-game] 운영 내보내기 요청 받음: userId %s · 이 서버 접속 %s"):format(tostring(userId), tostring(target ~= nil)))
	if target then
		target:Kick(KICK_MESSAGE)
	end
	return target ~= nil
end
Ops.onKickMessage = onKickMessage -- 검증 훅
task.spawn(function()
	pcall(function()
		game:GetService("MessagingService"):SubscribeAsync(kickTopic, function(message)
			onKickMessage(message.Data)
		end)
	end)
end)

function handlers.rollback(args, player)
	if args[2] == "confirm" then
		local p = takeToken("rollback", args[3], player)
		if not p then
			return "no_pending(확인 번호가 없거나 시간이 지났다)"
		end
		local online = Players:GetPlayerByUserId(p.userId)
		if online then -- 먼저 내보내고 그 사람의 마지막 저장(놓기)이 끝난 뒤에 덮는다
			online:Kick(KICK_MESSAGE)
			task.wait(6)
		else -- QUEUE-ALL6R 결정 8: 다른 서버가 저장을 쥐고 있으면 거기서 내보내고 놓을 때까지 기다린다(안 놓으면 덮지 않는다 - 늦게 온 그 서버 저장이 되돌리기를 덮어쓴다)
			local released, why = OpsRollback.awaitRelease(p.userId, {
				read = SaveSystem.opsReadCurrent,
				held = function(raw)
					return SaveSystem.heldElsewhere(raw, os.time())
				end,
				publish = function(userId)
					pcall(function()
						game:GetService("MessagingService"):PublishAsync(kickTopic, { userId = userId })
					end)
				end,
				wait = task.wait,
			})
			if not released then
				AuditTrail.note(p.userId, "ops_rollback", ("중단: 다른 서버가 저장을 놓지 않음(%s · %s)"):format(tostring(why), player.Name))
				return "failed: " .. tostring(why) .. "(다른 서버 접속 중 - 내보내기 요청 뒤에도 저장 잠금이 안 풀렸다. 잠시 뒤 다시)"
			end
		end
		local backup = DataStoreService:GetDataStore(SecurityOps.rollback.backupStore .. (require(ReplicatedStorage.Shared.data.DevToolsConfig).verifyArmed and "_verify" or ""))
		local ok, why, backupKey = OpsRollback.execute({
			readCurrent = SaveSystem.opsReadCurrent,
			readVersion = SaveSystem.opsReadVersion,
			writeBackup = function(key, value)
				return (pcall(function()
					backup:SetAsync((isStudio and AuditConfig.testKeyPrefix or "") .. key, value)
				end))
			end,
			writeProfile = SaveSystem.opsWriteProfile,
			now = os.time(),
		}, p.userId, p.version)
		AuditTrail.note(p.userId, "ops_rollback", ("%s → %s(백업 %s · %s)"):format(tostring(ok), p.version, tostring(backupKey), player.Name))
		return ok and ("rolled_back(백업 " .. tostring(backupKey) .. ")") or ("failed: " .. tostring(why))
	end
	local userId = tonumber(args[2])
	local target = tostring(args[3] or "")
	if not userId or target == "" then
		return "bad_args"
	end
	local list, err = SaveSystem.opsListVersions(userId, SecurityOps.rollback.listVersions)
	if not list then
		return "failed: " .. tostring(err)
	end
	local pick = OpsRollback.pick(list, OpsRollback.parseTime(target) or target)
	if not pick then
		return "no_version"
	end
	local now = OpsRollback.summary((SaveSystem.opsReadCurrent(userId)))
	local old = OpsRollback.summary(SaveSystem.opsReadVersion(userId, pick.version))
	local token = issueToken({ kind = "rollback", userId = userId, version = pick.version, by = player.UserId })
	return ("미리보기 %s@%s | 지금: %s | 그때: %s | 실행 = /ops rollback confirm %s(%d초 안)"):format(pick.version, os.date("!%m-%d %H:%M", math.floor(pick.createdTime / 1000)),
		OpsRollback.describe(now), OpsRollback.describe(old), token, SecurityOps.rollback.confirmSeconds)
end

function handlers.leaderboard(args)
	local userId = tonumber(args[3])
	if args[2] ~= "remove" or not userId then
		return "bad_args"
	end
	local done = {}
	if Leaderboard.removeEntry("personal", userId) then
		table.insert(done, "personal")
	end
	for _, classId in ipairs(require(ReplicatedStorage.Shared.data.ClassData).order) do
		if Leaderboard.removeEntry("class_" .. classId, userId) then
			table.insert(done, classId)
		end
	end
	if require(script.Parent.WeeklyChallengeService).removeEntry(userId) then
		table.insert(done, "weekly")
	end
	return "removed: " .. table.concat(done, ",")
end

function handlers.ban(args, player)
	local config, why, label
	if args[2] == "confirm" then -- QUEUE-ALL6R 결정 8: 영구 차단 실행
		local p = takeToken("ban", args[3], player)
		if not p then
			return "no_pending(확인 번호가 없거나 시간이 지났다)"
		end
		config, label = p.config, p.label
	else
		config, why = OpsRollback.banConfig(tonumber(args[2]), args[3], table.concat(args, " ", 4))
		if not config then
			return why
		end
		label = tostring(args[3])
		if SecurityOps.confirm.banDurations[label] then
			local token = issueToken({ kind = "ban", userId = config.UserIds[1], config = config, label = label, by = player.UserId })
			return ("미리보기: %d 영구 차단(경험 전체 · 부계정 포함) · 사유 \"%s\" | 실행 = /ops ban confirm %s(%d초 안)"):format(config.UserIds[1], config.DisplayReason, token, SecurityOps.rollback.confirmSeconds)
		end
	end
	local ok, err = pcall(function()
		Players:BanAsync(config)
	end)
	if args[2] == "confirm" then -- 리뷰: 확인 실행 = 대상 감사 기록에 직접(공통 기록은 "confirm"에서 대상을 못 찾는다)
		AuditTrail.note(config.UserIds[1], "ops_ban", ("%s → %s(%s)"):format(label, ok and "banned" or tostring(err), player.Name))
	end
	return ok and ("banned " .. label) or ("failed: " .. tostring(err))
end
function handlers.unban(args)
	local userId = tonumber(args[2])
	if not userId then
		return "bad_args"
	end
	local ok, err = pcall(function()
		Players:UnbanAsync({ UserIds = { userId }, ApplyToUniverse = true })
	end)
	return ok and "unbanned" or ("failed: " .. tostring(err))
end

function handlers.gift(args, player)
	local userId, kind, value = tonumber(args[2]), tostring(args[3] or ""), args[4]
	if not userId or kind == "" or value == nil then
		return "bad_args"
	end
	local note = table.concat(args, " ", 5)
	return require(script.Parent.GiftService).send(userId, kind, value, note, player and player.Name)
end

function handlers.stats(args)
	local AlphaStats = require(script.Parent.AlphaStats)
	if args[2] == "all" then
		local total, servers, uptime = AlphaStats.loadTotals()
		if not total then
			return "failed: 저장소 읽기"
		end
		return ("저장된 서버 %d개 · 가동 %.1f시간 · %s"):format(servers, uptime / 3600, AlphaStats.describe(total))
	end
	return "이 서버: " .. AlphaStats.describe(AlphaStats.snapshot())
end

-- 반환: 결과 문자열(허용 밖 = nil - 조용히 무시).
function Ops.handle(player, text)
	if not allowed(player) then
		return nil
	end
	local args = {}
	for word in tostring(text):gmatch("%S+") do
		table.insert(args, word)
	end
	table.remove(args, 1) -- "/ops"
	local fn = handlers[args[1] or ""]
	local ok, result = pcall(function()
		return fn and fn(args, player) or "unknown"
	end)
	result = ok and result or ("error: " .. tostring(result))
	logOps(player, text, result)
	local targetId = nil -- QUEUE-ALL6 I 리뷰: 대상 = 인자 중 첫 숫자(leaderboard remove <userId>처럼 둘째 칸이 아닌 명령도)
	for i = 2, #args do
		if args[i] == "confirm" then -- rollback confirm <확인 번호> = 숫자가 userId 아님(실행 줄은 rollback 미리보기 때 대상에 남는다)
			break
		end
		if tonumber(args[i]) then
			targetId = tonumber(args[i])
			break
		end
	end
	if targetId then -- QUEUE-ALL6 F3: 대상의 감사 기록에도 운영 명령 한 줄
		AuditTrail.note(targetId, "ops", ("%s: %s → %s"):format(player.Name, AuditTrail.clip(text, 60), AuditTrail.clip(result, 40)))
	end
	replyRemote:FireClient(player, result)
	return result
end

require(script.Parent.AlphaStats).start() -- S1 후속 0-5: 서버 종료 때 알파 통계 요약 저장
require(script.Parent.SuspicionMonitor).start() -- QUEUE-ALL6 F2: 분 단위 의심 기록(자동 처벌 없음)
AuditTrail.start() -- QUEUE-ALL6 F3: 감사 기록 모아 쓰기

local command = Instance.new("TextChatCommand")
command.Name = "ForgeOps"
command.PrimaryAlias = "/ops"
command.Parent = TextChatService
command.Triggered:Connect(function(textSource, text)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if player then
		Ops.handle(player, text)
	end
end)

if isStudio then -- 검증 훅(S1(나)): 서버 execute_luau → ServerStorage.OpsHook:Invoke(player, "/ops …") = 결과 문자열
	local hook = Instance.new("BindableFunction")
	hook.Name = "OpsHook"
	hook.OnInvoke = function(player, text)
		return Ops.handle(player, text), Ops.lastLog
	end
	hook.Parent = game:GetService("ServerStorage")
end
