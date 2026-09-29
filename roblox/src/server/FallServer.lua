-- MV1 낙하(사용자 결정 - 불꽃과 낙사). 판정 = 착지 순간 수직 속도(MoveRules.fallOutcome) · 수치 = MovementConfig.fall.
--   착지 속도는 캐릭터 물리를 가진 클라가 잰다(FallLanded RemoteEvent - 속도 · 물 · 사다리 표시). 서버는 제외(MoveRules.fallExcluded)를 스스로 판정한다:
--     보스전(BossEncounterId) · 나무 둘레(WorldMapData.progress.treeRadius) · 강제 체공(HeightGuard 발사 허가 · 예외가 permitGraceSeconds 안) · 사다리에서 떨어짐(서버 체공 세션 fromLadder 또는 클라 표시) · 물.
--   S1: 피해 속도 = 서버가 본 궤적(AirState 세션 최고점 − 착지 → 자유 낙하 속도)이다. 클라가 보낸 속도는 로그 대조만(달라도 서버 값) ·
--   클라가 보고를 안 보내도 서버 착지 뒤 reportWindowSeconds가 지나면 서버가 스스로 처리한다(물 = 서버 판정 · 사다리 = 세션 fromLadder).
--   피해 = 최대 체력 비율(보호막 무시 · 받는 피해 배율 없음 - 판정형 피해). 체력이 0이 되거나 치명 속도면 쓰러짐:
--     "쿵!" + 그을림(Character Attribute FallKnockdown · CharredUntil - 클라 FallFx가 그린다) · 루트 고정 knockdownSeconds → 마지막 안전 지점(이번 체공을 시작한 땅)에서 체력 가득 · 아이템 손실 없음.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local HeightGuard = require(script.Parent.HeightGuard)
local AirState = require(script.Parent.AirState)
local PlayerState = require(script.Parent.PlayerState)
local PlayerDamage = require(script.Parent.PlayerDamage)

local FallServer = {}
local F = MovementConfig.fall

local lastReportAt = {} -- [Player] = os.clock()
FallServer.log = {} -- 검증 · 계측: 마지막 결과 { player, speed, kind, fraction, excluded }

-- 제외 문맥(서버가 본 것 + 클라 표시 flags = { water, ladder }).
function FallServer.context(player, flags, now)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local session = AirState.currentOrLastSession(player)
	flags = type(flags) == "table" and flags or {}
	return {
		inBoss = player:GetAttribute("BossEncounterId") ~= nil,
		inTree = root ~= nil and Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude <= WorldMapData.progress.treeRadius,
		permitRecent = HeightGuard.recentlyForced(player, F.permitGraceSeconds, now),
		exemptRecent = false, -- recentlyForced가 예외까지 본다
		fromLadder = session ~= nil and session.fromLadder == true, -- 리뷰 5: 사다리 = 서버 체공 세션 표시만
		inWater = (flags.server and flags.water == true) or (root ~= nil and require(script.Parent.WorldHazards).inWater(root.Position)), -- 리뷰 5: 물 = 서버 판정(클라 표시 안 믿음)
	}
end

local function stand(player, position, reviveHp)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or not character:GetAttribute("FallKnockdown") then
		return -- 리뷰 6: 쓰러짐 중에 죽었으면(리스폰 대기) 시체를 옮기거나 체력을 채우지 않는다
	end
	root.Anchored = false
	if position then
		require(script.Parent.Travel).teleport(player, position + Vector3.new(0, 3, 0), "낙하 쓰러짐 → 마지막 안전 지점")
		AirState.reset(player, position)
	end
	PlayerState.setHp(player, reviveHp)
	PlayerDamage.syncHud(player)
	character:SetAttribute("FallKnockdown", nil)
end

-- 쓰러짐: 그 자리에 고정 · 무적 → knockdownSeconds 뒤 안전 지점에서 일어남.
function FallServer.knockdown(player, hpBefore)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or character:GetAttribute("FallKnockdown") then
		return false
	end
	local safe = AirState.safePosition(player)
	local maxHp = PlayerState.getMaxHp(player)
	local reviveHp = math.max(1, math.min(hpBefore or maxHp, maxHp * F.reviveHpCapFraction)) -- 리뷰 1: 일부러 떨어져 회복하는 길을 막는다
	PlayerState.setInvulnerableUntil(player, F.knockdownSeconds + 0.5, "fallKnockdown")
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	character:SetAttribute("FallKnockdown", true)
	character:SetAttribute("CharredUntil", Workspace:GetServerTimeNow() + F.knockdownSeconds + F.charredSeconds)
	print(("[forge-game] 낙하 쓰러짐: %s → %.1f초 뒤 안전 지점 %s"):format(player.Name, F.knockdownSeconds, tostring(safe)))
	task.delay(F.knockdownSeconds, function()
		if player.Parent and player.Character == character then
			stand(player, safe, reviveHp)
		end
	end)
	return true
end

-- 착지 보고 한 건 처리. 반환 = 결과 kind("none" | "damage" | "knockdown" | "excluded:<사유>" | "throttled").
function FallServer.onLanded(player, speed, flags)
	local now = os.clock()
	if now - (lastReportAt[player] or -math.huge) < F.reportMinGapSeconds then
		return "throttled"
	end
	lastReportAt[player] = now
	if type(speed) ~= "number" or speed ~= speed then
		return "none"
	end
	-- 리뷰 1(보안): 서버가 본 체공과 맞는 보고만 - 체공 세션이 진행 중이거나 막 끝났고, 체공 시간 ≥ 보고 속도의 자유 낙하 시간 × 여유
	local session = AirState.currentOrLastSession(player)
	if session and not session.endedAt and session.peakY and not (flags and flags.server) then
		-- 리뷰 5: 서버가 아직 착지를 못 봤다(지연) - 신고는 대조용으로만 적고, 서버 착지 때(onServerLanded) 서버 landY로 처리한다(정점에서 신고해 면제받는 길 차단)
		session.clientReport = speed
		return "pending"
	end
	if not session or (session.endedAt and now - session.endedAt > F.reportWindowSeconds) or session.fallHandled then
		FallServer.log = { player = player, speed = speed, kind = "none", excluded = "no_air" }
		return "excluded:no_air"
	end
	-- S1: 속도 = 서버 궤적 값(궤적이 있으면). 클라 값은 대조 로그만.
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local serverSpeed = AirState.fallSpeedOf(session, root and root.Position.Y)
	local clientSpeed = speed
	if serverSpeed then
		if math.abs(serverSpeed - speed) > math.max(20, serverSpeed * 0.25) then
			FallServer.mismatches = (FallServer.mismatches or 0) + 1
		end
		speed = serverSpeed
	end
	session.fallHandled = true
	local out = MoveRules.fallOutcome(speed, player)
	local entry = { player = player, speed = speed, clientSpeed = clientSpeed, server = serverSpeed ~= nil, kind = out.kind, fraction = out.fraction }
	FallServer.log = entry
	if out.kind == "none" then
		return "none"
	end
	local airtime = (session.endedAt or now) - session.since
	if airtime < speed / MovementConfig.gravity * F.airtimeSlack then
		entry.excluded = "short_air"
		return "excluded:short_air"
	end
	local why = MoveRules.fallExcluded(FallServer.context(player, flags, now))
	if why then
		entry.excluded = why
		return "excluded:" .. why
	end
	if (PlayerState.getHp(player) or 0) <= 0 or PlayerState.isInvulnerable(player) then
		return "none"
	end
	local hp = PlayerState.getHp(player)
	local damage = PlayerState.getMaxHp(player) * out.fraction
	if out.kind == "knockdown" or hp - damage <= 0 then
		entry.kind = "knockdown"
		FallServer.knockdown(player, hp)
		return "knockdown"
	end
	PlayerDamage.takeDamage(player, damage, { label = ("낙하 %.0f"):format(speed), ignoresShield = true })
	return "damage"
end

-- S1: 서버가 본 착지(AirState) - 클라 보고가 reportWindowSeconds 안에 없으면 서버 궤적만으로 처리(보고를 안 보내는 부정 차단).
local function onServerLanded(st, session)
	local player = st.player
	if not player or not session.peakY then
		return
	end
	task.delay(0.05, function() -- 리뷰 5: 서버 착지를 보면 바로(클라 신고는 대조용 - pending)
		if session.fallHandled or not player.Parent then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local speed = AirState.fallSpeedOf(session)
		if not root or not speed or MoveRules.fallOutcome(speed, player).kind == "none" then
			return
		end
		local inWater = require(script.Parent.WorldHazards).inWater(root.Position)
		lastReportAt[player] = nil
		local result = FallServer.onLanded(player, speed, { water = inWater, server = true })
		FallServer.serverResolved = (FallServer.serverResolved or 0) + 1
		print(("[forge-game] 낙하(서버 궤적): %s 높이 %.0f → %s"):format(player.Name, (session.peakY - (session.landY or 0)), tostring(result)))
	end)
end

function FallServer.start()
	AirState.onLanded = onServerLanded
	local landed = Instance.new("RemoteEvent")
	landed.Name = "FallLanded"
	landed.Parent = ReplicatedStorage
	landed.OnServerEvent:Connect(function(player, speed, flags)
		-- QUEUE-6h-b R3 F1(보안): 클라 flags는 표시(water · ladder)만 새 표로 옮긴다 - server 표시는 서버 내부 호출(onServerLanded)만 쓴다(위조하면 낙하 피해 면제였다)
		local clean = type(flags) == "table" and { water = flags.water == true, ladder = flags.ladder == true } or {}
		FallServer.onLanded(player, speed, clean)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastReportAt[player] = nil
	end)
end

return FallServer
