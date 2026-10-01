-- QUEUE-ALL1 P4 §1 초대 보상 · §2 코드(서버). 수치 · 규칙 = shared/data/SocialRewardData(주석 참고).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local D = require(ReplicatedStorage.Shared.data.SocialRewardData)
local PlayerProfile = require(script.Parent.PlayerProfile)

local SocialRewardService = {}
local I = D.invite
local inviteStore = DataStoreService:GetDataStore(I.storeName .. (RunService:IsStudio() and I.studioSuffix or ""))

local codeRemote = Instance.new("RemoteFunction")
codeRemote.Name = "RedeemCode"
codeRemote.Parent = ReplicatedStorage
local noticeRemote = Instance.new("RemoteEvent")
noticeRemote.Name = "SocialRewardNotice"
noticeRemote.Parent = ReplicatedStorage

local function grant(player, reward)
	return require(script.Parent.QuestService).grant(player, reward)
end

-- 순수: 코드 정리(대소문자 · 공백 무시)
function SocialRewardService.normalize(text)
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", ""):upper()
	if #text < 3 or #text > 24 or text:find("[^%w]") then
		return nil
	end
	return text
end

-- 순수: 코드 찾기 · 기한(UTC 그날 끝까지)
function SocialRewardService.find(code, now)
	for _, c in ipairs(D.codes) do
		if c.code == code and not c.inactive then -- QUEUE-ALL6 A5: inactive = 아직 안 연 단계(없는 코드와 같음)
			local e = c.expires
			local endUnix = os.time({ year = e[1], month = e[2], day = e[3], hour = 23, min = 59, sec = 59 })
			-- os.time(표)는 서버 지역 시간 해석 - 로블록스 서버는 UTC
			return c, (now or os.time()) <= endUnix
		end
	end
	return nil, false
end

local lastTry = {} -- [player] = { at, minuteStart, count }
codeRemote.OnServerInvoke = function(player, text)
	local now = os.clock()
	local t = lastTry[player] or { at = -math.huge, minuteStart = now, count = 0 }
	lastTry[player] = t
	if now - t.minuteStart > 60 then
		t.minuteStart, t.count = now, 0
	end
	if now - t.at < D.codeCooldownSeconds or t.count >= D.codePerMinute then
		return { ok = false, message = D.text.slow }
	end
	t.at, t.count = now, t.count + 1
	local code = SocialRewardService.normalize(text)
	local entry, valid = nil, false
	if code then
		entry, valid = SocialRewardService.find(code)
	end
	local used = PlayerProfile.getRedeemedCodes(player)
	local result
	if not entry then
		result = { ok = false, message = D.text.bad }
	elseif not valid then
		result = { ok = false, message = D.text.expired }
	elseif not used or used[code] then
		result = { ok = false, message = D.text.used }
	else
		used[code] = os.time()
		local summary = grant(player, entry.reward)
		require(script.Parent.ImmediateSave).request(player)
		result = { ok = true, message = D.text.ok:format(summary) }
	end
	print(("[forge-game] 코드 시도: %s '%s' → %s"):format(player.Name, tostring(code), result.ok and "지급" or result.message))
	pcall(function()
		require(script.Parent.Telemetry).economy(player, "code", result.ok and "redeem" or "reject", 1, tostring(code))
	end)
	return result
end

-- 초대받은 첫 접속(저장 없음 = savedAt 0)
function SocialRewardService.onLoaded(player, inviterOverride)
	task.spawn(function()
		local inviterId = inviterOverride
		if not inviterId then
			local ok, join = pcall(function()
				return player:GetJoinData()
			end)
			inviterId = ok and type(join) == "table" and tonumber(join.ReferredByPlayerId) or nil
		end
		if not inviterId or inviterId <= 0 or inviterId == player.UserId then
			return
		end
		if not inviterOverride and not PlayerProfile.isFreshProfile(player) then
			return -- 처음 들어온 사람만
		end
		local pairKey = ("pair_%d_%d"):format(inviterId, player.UserId)
		local first = false
		pcall(function()
			inviteStore:UpdateAsync(pairKey, function(v)
				if v then
					return nil
				end
				first = true
				return os.time()
			end)
		end)
		if not first then
			return
		end
		grant(player, I.inviteeReward)
		require(script.Parent.ImmediateSave).request(player) -- QUEUE-ALL5 D②: pairKey는 이미 써졌다 - 다음 주기 저장 전에 서버가 꺼지면 보상만 사라진다(코드 보상과 같게)
		noticeRemote:FireClient(player, I.text.invitee)
		local oldEnough = (player.AccountAge or 0) >= I.minAccountAgeDays
		local day = math.floor(os.time() / 86400)
		local underCap = false
		if oldEnough then
			pcall(function()
				inviteStore:UpdateAsync(("day_%d_%d"):format(inviterId, day), function(n)
					n = tonumber(n) or 0
					if n >= I.inviterDailyCap then
						return nil
					end
					underCap = true
					return n + 1
				end)
			end)
		end
		print(("[forge-game] 초대 보상: %d → %s(계정 나이 %d일 · 초대자 보상 %s)"):format(inviterId, player.Name, player.AccountAge or 0, tostring(oldEnough and underCap)))
		if not (oldEnough and underCap) then
			return
		end
		local inviter = Players:GetPlayerByUserId(inviterId)
		if inviter and PlayerProfile.getRedeemedCodes(inviter) then
			grant(inviter, I.inviterReward)
			noticeRemote:FireClient(inviter, I.text.inviter)
		else
			require(script.Parent.GiftService).send(inviterId, "sparkleShard", I.inviterReward.sparkleShard, I.text.inviter, "친구 초대")
		end
	end)
end

function SocialRewardService.start()
	Players.PlayerRemoving:Connect(function(p)
		lastTry[p] = nil
	end)
end

return SocialRewardService
