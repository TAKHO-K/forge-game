-- QUEUE-ALL6 F3 감사 기록(복구의 근거): 중요한 변화만 짧게 - 태초/초월 획득(세계 번호 · 출처) · 강화 +20 이상 · 큰 골드 변화 · 상점 구매 · 코드/초대/선물 지급 · 운영 명령.
--   저장 = DataStore SecurityOpsConfig.trail.storeName 키 u<userId> = { { k = 종류, d = 짧은 글, at = unix }, … } 최근 keep개 · maxAgeDays 지난 줄은 버림.
--   쓰기 = 사람별로 모았다가 flushSeconds마다 · 퇴장 · 서버 종료 때 UpdateAsync 1번(DataStore 예산). Studio = 시험 접두사 · 검증 무장 = _verify 이름.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local C = require(ReplicatedStorage.Shared.data.SecurityOpsConfig).trail
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)

local AuditTrail = {}
AuditTrail.debugNoStore = false -- 하네스 · 검증(메모리만)
AuditTrail.pending = {} -- [userId] = { 줄 … }
AuditTrail.memory = {} -- [userId] = 이 서버가 쓴 최근 줄(inspect가 저장 읽기 실패 때 보여 준다)

local isStudio = RunService:IsStudio()
local store
local function getStore()
	if store == nil then
		local ok, s = pcall(function()
			return DataStoreService:GetDataStore(C.storeName .. (DevToolsConfig.verifyArmed and "_verify" or ""))
		end)
		store = ok and s or false
	end
	return store or nil
end
local function keyOf(userId)
	return (isStudio and "studio_" or "") .. "u" .. tostring(userId)
end
AuditTrail.keyOf = keyOf

-- 순수: 옛 목록 + 새 줄 → 앞에 새 줄 · 나이 · 개수 상한
function AuditTrail.merge(list, entries, now)
	list = type(list) == "table" and list or {}
	for _, e in ipairs(entries) do
		table.insert(list, 1, e)
	end
	local cutoff = now - C.maxAgeDays * 86400
	local out = {}
	for _, e in ipairs(list) do
		if type(e) == "table" and type(e.at) == "number" and e.at >= cutoff and #out < C.keep then
			table.insert(out, e)
		end
	end
	return out
end

-- 기록 하나(player = Player 또는 userId 숫자)
function AuditTrail.note(player, kind, detail)
	local userId = typeof(player) == "Instance" and player.UserId or tonumber(player)
	if not userId or userId <= 0 then
		return
	end
	local e = { k = tostring(kind), d = tostring(detail or ""):sub(1, 120), at = os.time() }
	AuditTrail.pending[userId] = AuditTrail.pending[userId] or {}
	table.insert(AuditTrail.pending[userId], e)
	AuditTrail.memory[userId] = AuditTrail.memory[userId] or {}
	table.insert(AuditTrail.memory[userId], 1, e)
	while #AuditTrail.memory[userId] > 30 do
		table.remove(AuditTrail.memory[userId])
	end
end

function AuditTrail.flush(userId)
	local entries = AuditTrail.pending[userId]
	if not entries or #entries == 0 then
		return true
	end
	AuditTrail.pending[userId] = nil
	if AuditTrail.debugNoStore then
		return true
	end
	local s = getStore()
	if not s then
		return false
	end
	local ok = pcall(function()
		s:UpdateAsync(keyOf(userId), function(list)
			return AuditTrail.merge(list, entries, os.time())
		end)
	end)
	if not ok then -- 실패 = 다음 번에 다시(앞에 다시 넣는다)
		local again = AuditTrail.pending[userId] or {}
		for i = #entries, 1, -1 do
			table.insert(again, 1, entries[i])
		end
		AuditTrail.pending[userId] = again
	end
	return ok
end

function AuditTrail.flushAll()
	for userId in pairs(AuditTrail.pending) do
		AuditTrail.flush(userId)
	end
end

-- 읽기(/ops inspect): 저장 + 아직 안 쓴 줄
function AuditTrail.read(userId)
	local list = {}
	local s = not AuditTrail.debugNoStore and getStore()
	if s then
		local ok, data = pcall(function()
			return s:GetAsync(keyOf(userId))
		end)
		list = ok and type(data) == "table" and data or {}
	end
	return AuditTrail.merge(list, AuditTrail.pending[userId] or {}, os.time())
end

function AuditTrail.start()
	task.spawn(function()
		while true do
			task.wait(C.flushSeconds)
			AuditTrail.flushAll()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(AuditTrail.flush, player.UserId)
	end)
	game:BindToClose(function()
		AuditTrail.flushAll()
	end)
end

return AuditTrail
