-- S1 2-8 운영 명령(라이브 · Studio): 채팅 "/ops …" - 허용 계정(OpsConfig.userIds)만 · 서버가 인자를 검증 · 모든 시도를 기록(AuditConfig.opsLogStore).
--   /ops release <userId> <번호|rollId>   격리 해제(원장 확인 뒤 운영 판단 - 그 사람이 이 서버에 있어야 한다)
--   /ops revoke <userId> <번호|rollId>    회수(아이템은 남기되 revoked · 번호 = 결번 · 칭호 다시 판정)
--   /ops lbremove <personal|class_<직업>> <userId>   리더보드 항목 제거
--   /ops versions <userId>                저장 버전 목록(DataStore 30일 보관)
--   /ops restore <userId> <version>        저장 버전 복구(그 사람이 이 서버에 없어야 한다 - 다른 서버 접속은 운영 절차로 확인)
--   /ops review <userId>                  검토 대기 목록(최근)
--   /ops gift <userId> <cosmeticTheme|gliderSkin|sparkleShard> <id|개수> [메모]   선물함에 치장 · 치장 재화 넣기(QUEUE-B1 B2 - 치장만 · 이 서버에 없으면 다음 접속 때)
--   /ops stats [all]                       알파 통계(C1 끌어오기 계측 - 이 서버 메모리 · all = 서버 종료 때 저장된 요약 합 - S1 후속 0-5)
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
function handlers.revoke(args)
	local target, item, why = findItem(tonumber(args[2]) or 0, tostring(args[3]))
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
	replyRemote:FireClient(player, result)
	return result
end

require(script.Parent.AlphaStats).start() -- S1 후속 0-5: 서버 종료 때 알파 통계 요약 저장

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
