-- QUEUE-ALL6 H #86 하이파이브 이모트(꾸미기 소품 - 겉모습만): 요청 → 가장 가까운 파티원(rangeStuds 안)에게 제안 → 상대가 수락하면 둘이 하이파이브(모두에게 재생).
--   요청 = 이모트 칸에 highFive를 장착한 사람만 · 수락 = 제안을 받은 사람만 · 제안 유효 offerSeconds · 공통 요청 제한(RequestGate) · 보스전 · 영혼 중 불가.
--   Remote EmoteRequest(클라 → 서버: "request" | "accept", fromUserId) · EmoteEvent(서버 → 클라: "offer", fromUserId · "play", aUserId, bUserId · "fail", 이유).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RequestGate = require(script.Parent.RequestGate)
local PartyState = require(script.Parent.PartyState)

local CONFIG = { rangeStuds = 14, offerSeconds = 8 }

local request = Instance.new("RemoteEvent")
request.Name = "EmoteRequest"
request.Parent = ReplicatedStorage
local event = Instance.new("RemoteEvent")
event.Name = "EmoteEvent"
event.Parent = ReplicatedStorage

local offers = {} -- [수락할 Player] = { from = Player, at = os.clock() }

local function rootOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function busy(p)
	return p:GetAttribute("BossEncounterId") ~= nil or require(script.Parent.SoulService).isSoul(p)
end

request.OnServerEvent:Connect(function(player, action, fromUserId)
	if not RequestGate.allow(player, "EmoteRequest") or type(action) ~= "string" then
		return
	end
	if action == "request" then
		if player:GetAttribute("Cosmetic_emote") ~= "highFive" or busy(player) then
			event:FireClient(player, "fail", "not_ready")
			return
		end
		local party = PartyState.getParty(player)
		local me = rootOf(player)
		local best, bestD = nil, CONFIG.rangeStuds
		for _, other in ipairs(party and PartyState.getMemberPlayers(party) or {}) do
			local r = other ~= player and rootOf(other)
			if r and me and not busy(other) then
				local d = (r.Position - me.Position).Magnitude
				if d <= bestD then
					best, bestD = other, d
				end
			end
		end
		if not best then
			event:FireClient(player, "fail", "no_partner")
			return
		end
		offers[best] = { from = player, at = os.clock() }
		event:FireClient(best, "offer", player.UserId)
	elseif action == "accept" then
		local offer = offers[player]
		offers[player] = nil
		if not offer or offer.from.UserId ~= tonumber(fromUserId) or os.clock() - offer.at > CONFIG.offerSeconds or not offer.from.Parent then
			return
		end
		local a, b = rootOf(offer.from), rootOf(player)
		if not (a and b) or (a.Position - b.Position).Magnitude > CONFIG.rangeStuds + 4 then
			event:FireClient(player, "fail", "too_far")
			return
		end
		event:FireAllClients("play", offer.from.UserId, player.UserId)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	offers[p] = nil
end)
