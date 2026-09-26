-- M1 보스 관문 입장 + M1-3 관문 등록(사용자 규칙 - 신규 보스에도 같은 규칙).
--   관문 목록 = BossData 보스마다 gate 칸(WorldMapLayout.bossGates) - 새 보스는 그 칸 한 줄로 아래 규칙이 전부 붙는다.
--   등록: 관문 앞 상호작용(ProximityPrompt - F 짧게 · 폰 = 상호작용 버튼) 또는 보스 스테이지에서 발판을 밟아 입장 = 그 보스 등록(계정 저장 world.bossGates). 구역 초입이 아니라 관문(구역을 한 번은 가로지르게).
--   원격 입장: 등록된 보스는 스테이지 선택 창에서 바로 입장(StageServer - 진행 보스. 토벌 = BR2에서 같은 기록을 쓴다). 파티 = 멤버 중 한 명이라도 등록돼 있으면 전원(투표 흐름 그대로) ·
--     따라간 사람은 등록되지 않는다(등록은 관문 상호작용뿐).
--   등록 전: 보스 스테이지에 도달하면 관문까지 길 안내(Player Attribute BossGateId · BossGateZone) + 클라 "다음 목표" 추적. 등록 뒤에는 길 안내가 켜지지 않는다.
--   관문 발판을 밟으면(TravelServer 거리 폴링) 그 자리에서 입장도 된다: 솔로 = 바로 · 파티 = 리더만 · 멤버 전원 검사 · 입장 투표 → 파티 보스.
-- 입장한 사람의 복귀 자리 = 관문 앞(발판 입장) · 원격 입장이면 각자 서 있던 자리(BossEncounter.setReturnPoint - [마을]은 허브).
-- WorldMapData.boss.entry = "direct"면 옛 즉시 입장(StageServer가 바로 스폰).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local PlayerProfile = require(script.Parent.PlayerProfile)
local BossEncounter = require(script.Parent.BossEncounter)
local PartyState = require(script.Parent.PartyState)
local PartyVote = require(script.Parent.PartyVote)
local ImmediateSave = require(script.Parent.ImmediateSave)

local BossGate = {}

local registeredEvent = nil -- RemoteEvent BossGateRegistered(첫 등록 연출 · 알림 - 등록한 사람에게만)

function BossGate.enabled()
	return WorldMapData.boss.entry == "gate"
end

-- 이 스테이지 보스의 관문(없으면 nil - 관문 없는 보스는 즉시 입장)
function BossGate.gateForStage(stage)
	return WorldMapLayout.bossGate(BossRules.bossIdForStage(stage))
end

-- 옛 이름(구역 관문 키) - 검증 · 길 안내 호환
function BossGate.zoneKeyForStage(stage)
	local g = BossGate.gateForStage(stage)
	return g and g.zoneKey or nil
end

-- 관문 앞 복귀 자리(발판에서 허브 쪽으로 한 걸음 - 다시 밟지 않게)
function BossGate.returnPointForBoss(bossId)
	local g = WorldMapLayout.bossGate(bossId)
	return g.position - g.dir * (WorldMapData.layout.gate.radius + 12) + Vector3.new(0, 3, 0)
end
function BossGate.returnPoint(zoneKey)
	for _, g in ipairs(WorldMapLayout.bossGates()) do
		if g.zoneKey == zoneKey then
			return BossGate.returnPointForBoss(g.bossId)
		end
	end
	return nil
end

function BossGate.isRegistered(player, bossId)
	return PlayerProfile.isBossGateRegistered(player, bossId)
end

-- 순수(검증): 본인 등록 여부 + 다른 파티 멤버들의 등록 여부 목록 → 원격 입장 가능한가(한 명이라도)
function BossGate.usableFromFlags(selfRegistered, memberFlags)
	if selfRegistered then
		return true
	end
	for _, flag in ipairs(memberFlags) do
		if flag then
			return true
		end
	end
	return false
end

-- 원격 입장 가능: 본인 등록 또는 파티 멤버 중 한 명이라도 등록
function BossGate.usableFor(player, bossId)
	local flags = {}
	local party = PartyState.getParty(player)
	for _, member in ipairs(party and PartyState.getMemberPlayers(party) or {}) do
		if member ~= player then
			table.insert(flags, BossGate.isRegistered(member, bossId))
		end
	end
	return BossGate.usableFromFlags(BossGate.isRegistered(player, bossId), flags)
end

-- 첫 등록(관문 상호작용). 반환: 새로 등록했는가
function BossGate.register(player, bossId)
	if not WorldMapLayout.bossGate(bossId) or not PlayerProfile.registerBossGate(player, bossId) then
		return false
	end
	BossGate.refreshAttributes(player)
	BossGate.refreshGuide(player)
	ImmediateSave.request(player)
	if registeredEvent then
		registeredEvent:FireClient(player, bossId)
	end
	print(("[forge-game] 관문 등록: %s → %s"):format(player.Name, bossId))
	return true
end

-- 클라 표시용 Attribute: BossGatesRegistered(본인 - 관문 색 · 프롬프트) · BossGatesUsable(파티 포함 - 원격 입장 버튼). 쉼표 목록.
function BossGate.refreshAttributes(player)
	local own = PlayerProfile.getRegisteredBossGates(player)
	local usable = {}
	for _, g in ipairs(WorldMapLayout.bossGates()) do
		if BossGate.usableFor(player, g.bossId) then
			table.insert(usable, g.bossId)
		end
	end
	local a, b = table.concat(own, ","), table.concat(usable, ",")
	if player:GetAttribute("BossGatesRegistered") ~= a then
		player:SetAttribute("BossGatesRegistered", a)
	end
	if player:GetAttribute("BossGatesUsable") ~= b then
		player:SetAttribute("BossGatesUsable", b)
	end
end

-- 길 안내 대상: 보스 스테이지 + 본인이 그 관문을 아직 등록하지 않았을 때만 그 관문(등록 전에만 - 사용자). 아니면 끔.
function BossGate.refreshGuide(player)
	local stage = PlayerProfile.getInfiniteStage(player)
	local g = stage and BossRules.isBossStage(stage) and BossGate.gateForStage(stage) or nil
	if g and BossGate.isRegistered(player, g.bossId) then
		g = nil
	end
	if player:GetAttribute("BossGateId") ~= (g and g.bossId or nil) then
		player:SetAttribute("BossGateId", g and g.bossId or nil)
	end
	if player:GetAttribute("BossGateZone") ~= (g and g.zoneKey or nil) then
		player:SetAttribute("BossGateZone", g and g.zoneKey or nil)
	end
	player:SetAttribute("BossGateStage", g and stage or nil)
end

-- 원격 입장 전: 멤버마다 지금 서 있는 자리를 복귀 자리로(필드에 있을 때만 - 아니면 허브)
function BossGate.setRemoteReturnPoints(members)
	for _, member in ipairs(members) do
		local root = member.Character and member.Character:FindFirstChild("HumanoidRootPart")
		if root and not BossEncounter.getEncounter(member) then
			BossEncounter.setReturnPoint(member, root.Position + Vector3.new(0, 1, 0))
		end
	end
end

-- 관문 발판을 밟았다(key = 발판의 BossId). 반환: 처리 결과 코드(로그 · 검증).
function BossGate.enter(player, bossId)
	local stage = PlayerProfile.getInfiniteStage(player)
	if not stage or not BossRules.isBossStage(stage) then
		return "not_boss_stage"
	end
	if BossEncounter.getEncounter(player) then
		return "in_encounter"
	end
	local g = BossGate.gateForStage(stage)
	if not g or g.bossId ~= bossId then
		return "wrong_gate"
	end
	BossGate.register(player, bossId) -- 관문을 직접 밟았다 = 방문(등록 - 따라간 파티원은 아니다: 밟은 사람만)
	local party = PartyState.getParty(player)
	local back = BossGate.returnPointForBoss(bossId)
	if party then
		if not PartyState.isLeader(player) then
			PartyState.notify(player, "보스 관문은 파티 리더가 연다")
			return "party_not_leader"
		end
		local blocked = BossEncounter.checkPartyEntry(party, stage)
		if #blocked > 0 then
			local names = {}
			for _, entry in ipairs(blocked) do
				table.insert(names, ("%s:%s"):format(entry.player.Name, entry.reason))
			end
			PartyState.notify(player, "파티 보스 입장 불가 - " .. table.concat(names, ", "))
			return "party_blocked"
		end
		local started = PartyVote.start(party, player, stage, function(passed)
			if passed and not BossEncounter.getEncounter(player) then
				for _, member in ipairs(BossEncounter.getEntryMembers(party)) do
					BossEncounter.setReturnPoint(member, back)
				end
				BossEncounter.spawnForParty(party, player, stage)
			end
		end)
		if not started then
			PartyState.notify(player, "이미 진행 중인 투표가 있습니다")
			return "vote_pending"
		end
		return "vote"
	end
	BossEncounter.setReturnPoint(player, back)
	BossEncounter.spawnFor(player, stage)
	return "entered"
end

-- 관문 등록 상호작용(ProximityPrompt)을 붙인다 - 맵을 지은 뒤 한 번(TravelServer). 프롬프트는 모두에게 같은 인스턴스라 등록한 사람 화면에서는 클라가 끈다(Enabled 로컬).
function BossGate.setupPrompts(groundFolder)
	registeredEvent = ReplicatedStorage:FindFirstChild("BossGateRegistered") or Instance.new("RemoteEvent")
	registeredEvent.Name = "BossGateRegistered"
	registeredEvent.Parent = ReplicatedStorage
	local G = WorldMapData.bossGate
	local count = 0
	for _, part in ipairs(groundFolder:GetDescendants()) do
		local bossId = part:IsA("BasePart") and part:GetAttribute("GatePrompt")
		if bossId then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "GateRegisterPrompt"
			prompt.ActionText = "관문 등록"
			prompt.ObjectText = (BossData.bosses[bossId] and BossData.bosses[bossId].displayName or bossId) .. " 관문"
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = G.promptDistance
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(function(player)
				BossGate.register(player, bossId)
			end)
			count += 1
		end
	end
	print(("[forge-game] 관문 등록 프롬프트 %d곳(F · 폰 버튼)"):format(count))
	return count
end

return BossGate
