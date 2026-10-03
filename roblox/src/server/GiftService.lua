-- QUEUE-B1 B2 선물함(우편함 - P4c 골격). 유저별 받을 선물 목록 = profile.mailbox.gifts(v56) · 접속 때 수령 팝업(GiftPopup) · 받기 = 치장 · 치장 재화만.
--   보내는 길: 관리자 명령 `/ops gift <userId> <kind> <id|개수> [메모]`(OpsServer - 허용 계정 = OpsConfig.userIds · 모든 시도가 운영 기록 저장소에 남는다).
--   대상이 이 서버에 있으면 바로 선물함에, 없으면 DataStore(MonetizationData.gifts.storeName - 검증 무장 중 = _verify)에 쌓고 다음 접속 때 옮긴다.
--   유저 간 로벅스 선물 = 자리(MonetizationData.gifts.userToUser.enabled = false).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local PlayerProfile = require(script.Parent.PlayerProfile)

local GiftService = {}
local GIFTS = MonetizationData.gifts
local popupRemote = nil

local function store()
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(GIFTS.storeName .. (DevToolsConfig.verifyArmed and "_verify" or ""))
	end)
	return ok and s or nil
end
local function queueKey(userId)
	return "u" .. tostring(userId)
end

-- 선물 한 건의 형태 검사(치장 · 치장 재화만). 반환: 정리된 선물 | nil, 이유
function GiftService.normalize(kind, value, note, from)
	local ok, why = Monetization.checkGrant(MonetizationData, { kind = kind }, GIFTS.allowedKinds)
	if not ok then
		return nil, why
	end
	local gift = { id = HttpService:GenerateGUID(false), kind = kind, from = tostring(from or "운영"), note = tostring(note or ""):sub(1, 60), at = os.time() }
	if kind == "sparkleShard" then
		local amount = tonumber(value)
		if not amount or amount ~= math.floor(amount) or amount < 1 or amount > 10000 then
			return nil, "bad_amount"
		end
		gift.amount = amount
	else
		if not Monetization.findCosmetic(CosmeticSlotData, kind, value) then
			return nil, "unknown_cosmetic"
		end
		local blocked = Monetization.tokenBlocked(CosmeticSlotData, kind, value)
		if blocked then
			return nil, blocked -- QUEUE-ALL1 R1: 시즌 한정 · QUEUE-ALL9B 패스 · 출석판 전용 치장은 선물 X(season_only · pass_only · board_only)
		end
		gift.itemId = value
	end
	return gift
end

-- QUEUE-ALL5 A1(v62 · 보안 감사 D1): 받은 선물 id 기록(mailbox.claimedIds - 문자열 배열 · 오래된 것이 앞). 대기열 지우기가 실패해 같은 선물이 다시 옮겨져도 두 번 주지 않는다.
local function claimedSet(s)
	local set = {}
	for _, id in ipairs(s.mailbox.claimedIds) do
		set[id] = true
	end
	return set
end
local function rememberClaimed(s, id)
	table.insert(s.mailbox.claimedIds, id)
	while #s.mailbox.claimedIds > GIFTS.claimedIdsKeep do
		table.remove(s.mailbox.claimedIds, 1)
	end
end

local function pushPopup(player)
	local s = PlayerProfile.getMonetizationState(player)
	if popupRemote and s and #s.mailbox.gifts > 0 and typeof(player) == "Instance" then
		popupRemote:FireClient(player, s.mailbox.gifts)
	end
end

-- 보내기(관리자). 반환: 결과 문자열
function GiftService.send(targetUserId, kind, value, note, fromName)
	local gift, why = GiftService.normalize(kind, value, note, fromName)
	if not gift then
		return "rejected: " .. tostring(why)
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	local s = target and PlayerProfile.getMonetizationState(target)
	if s then
		if #s.mailbox.gifts >= GIFTS.maxPending then
			return "full"
		end
		table.insert(s.mailbox.gifts, gift)
		require(script.Parent.ImmediateSave).flush(target) -- 리뷰 사소: 바로 저장(서버가 곧 죽어도 "delivered"가 거짓이 되지 않게)
		pushPopup(target)
		return "delivered_online " .. gift.id
	end
	local ds = store()
	if not ds then
		return "failed: store"
	end
	local result = "queued " .. gift.id
	local ok, err = pcall(function()
		ds:UpdateAsync(queueKey(targetUserId), function(list)
			list = type(list) == "table" and list or {}
			if #list >= GIFTS.maxPending then
				result = "full"
				return nil -- 쓰지 않음
			end
			table.insert(list, gift)
			return list
		end)
	end)
	return ok and result or ("failed: " .. tostring(err))
end

-- 접속 때: 쌓인 선물을 선물함으로 옮기고(같은 id는 한 번만) 팝업
function GiftService.onLoaded(player)
	task.spawn(function()
		local s = PlayerProfile.getMonetizationState(player)
		local ds = store()
		if s and ds then
			-- 리뷰 중요 1: 대기열은 읽기만 → 선물함에 합침(같은 id 한 번) → **저장이 성공했을 때만** 옮긴 id를 대기열에서 지운다
			-- (로드 실패 · 저장 중단 · 도중 퇴장이면 대기열에 남아 다음 접속 때 다시 옮긴다 - 선물함은 id로 중복을 거른다).
			local okRead, queued = pcall(function()
				return ds:GetAsync(queueKey(player.UserId))
			end)
			queued = okRead and type(queued) == "table" and queued or {}
			if #queued > 0 and player.Parent then
				local have = claimedSet(s) -- QUEUE-ALL5 A1: 이미 받은 id도 다시 넣지 않는다(대기열에서는 지운다)
				for _, g in ipairs(s.mailbox.gifts) do
					have[g.id] = true
				end
				local movedIds, skipped = {}, 0
				for _, g in ipairs(queued) do
					if type(g) == "table" and type(g.id) == "string" then
						movedIds[g.id] = true
						if not have[g.id] then
							have[g.id] = true -- 대기열 안 같은 id 두 줄도 한 번만
							table.insert(s.mailbox.gifts, g)
						else
							skipped += 1
						end
					end
				end
				if skipped > 0 then
					print(("[B2] 선물함: %s - 이미 받았거나 선물함에 있는 선물 %d건 건너뜀(재지급 방지)"):format(player.Name, skipped))
				end
				if require(script.Parent.ImmediateSave).flush(player) then
					pcall(function()
						ds:UpdateAsync(queueKey(player.UserId), function(list)
							local kept = {}
							for _, g in ipairs(type(list) == "table" and list or {}) do
								if type(g) ~= "table" or not movedIds[g.id] then
									table.insert(kept, g) -- 읽은 뒤 새로 쌓인 선물은 남긴다
								end
							end
							return kept
						end)
					end)
					print(("[B2] 선물함: %s - 쌓인 선물 %d건 옮김"):format(player.Name, #queued))
				else
					print(("[B2] 선물함: %s - 저장 실패 · 중단 - 대기열 %d건 그대로 둠(다음 접속)"):format(player.Name, #queued))
				end
			end
		end
		if player.Parent then
			pushPopup(player)
		end
	end)
end

-- 받기(id = 선물 id · "all" = 전부). 반환: 받은 수, 이유
function GiftService.claim(player, id)
	local s = PlayerProfile.getMonetizationState(player)
	if not s then
		return 0, "no_profile"
	end
	local kept, got, claimed = {}, 0, claimedSet(s)
	for _, gift in ipairs(s.mailbox.gifts) do
		if claimed[gift.id] then
			print(("[B2] 선물 받기: %s - 이미 받은 선물 %s 지움(지급 없음)"):format(player.Name, tostring(gift.id))) -- QUEUE-ALL5 A1
		elseif id == "all" or gift.id == id then
			local reward = gift.kind == "sparkleShard" and { sparkleShard = gift.amount } or { [gift.kind] = gift.itemId }
			claimed[gift.id] = true -- 지급 전에 표시(같은 목록에 같은 id가 두 줄이어도 한 번)
			local ok = require(script.Parent.MonetizationService).applyReward(player, reward, "gift")
			if ok then
				got += 1
				rememberClaimed(s, gift.id)
				print(("[B2] 선물 받기: %s - %s %s(%s)"):format(player.Name, gift.kind, tostring(gift.itemId or gift.amount), gift.from))
				require(script.Parent.AuditTrail).note(player, "gift", ("%s %s · %s"):format(gift.kind, tostring(gift.itemId or gift.amount), tostring(gift.from))) -- QUEUE-ALL6 F3 감사
			else
				claimed[gift.id] = nil
				table.insert(kept, gift)
			end
		else
			table.insert(kept, gift)
		end
	end
	s.mailbox.gifts = kept
	if got > 0 then
		require(script.Parent.ImmediateSave).request(player)
	end
	return got
end

function GiftService.start()
	popupRemote = ReplicatedStorage:FindFirstChild("GiftPopup") or Instance.new("RemoteEvent")
	popupRemote.Name = "GiftPopup"
	popupRemote.Parent = ReplicatedStorage
end

return GiftService
