-- MV1 낙하(사용자 결정 - 불꽃과 낙사). 판정 = 착지 순간 수직 속도(MoveRules.fallOutcome) · 수치 = MovementConfig.fall.
--   착지 속도는 캐릭터 물리를 가진 클라가 잰다(FallLanded RemoteEvent - 속도 · 물 · 사다리 표시). 서버는 제외(MoveRules.fallExcluded)를 스스로 판정한다:
--     보스전(BossEncounterId) · 나무 둘레(WorldMapData.progress.treeRadius) · 강제 체공(HeightGuard 발사 허가 · 예외가 permitGraceSeconds 안) · 사다리에서 떨어짐(서버 체공 세션 fromLadder 또는 클라 표시) · 물.
--   보고를 안 보내는 부정은 제 피해만 피한다(보상 이득 없음) - S1에서 서버 궤적 추정과 대조할 자리(MV1 보고서).
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
		fromLadder = flags.ladder == true or (session ~= nil and session.fromLadder == true),
		inWater = flags.water == true,
	}
end

local function stand(player, position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.Anchored = false
	if position then
		require(script.Parent.Travel).teleport(player, position + Vector3.new(0, 3, 0), "낙하 쓰러짐 → 마지막 안전 지점")
		AirState.reset(player, position)
	end
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	PlayerDamage.syncHud(player)
	character:SetAttribute("FallKnockdown", nil)
end

-- 쓰러짐: 그 자리에 고정 · 무적 → knockdownSeconds 뒤 안전 지점에서 일어남.
function FallServer.knockdown(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or character:GetAttribute("FallKnockdown") then
		return false
	end
	local safe = AirState.safePosition(player)
	PlayerState.setInvulnerableUntil(player, F.knockdownSeconds + 0.5, "fallKnockdown")
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	character:SetAttribute("FallKnockdown", true)
	character:SetAttribute("CharredUntil", Workspace:GetServerTimeNow() + F.knockdownSeconds + F.charredSeconds)
	print(("[forge-game] 낙하 쓰러짐: %s → %.1f초 뒤 안전 지점 %s"):format(player.Name, F.knockdownSeconds, tostring(safe)))
	task.delay(F.knockdownSeconds, function()
		if player.Parent and player.Character == character then
			stand(player, safe)
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
	local out = MoveRules.fallOutcome(speed)
	local entry = { player = player, speed = speed, kind = out.kind, fraction = out.fraction }
	FallServer.log = entry
	if out.kind == "none" then
		return "none"
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
		FallServer.knockdown(player)
		return "knockdown"
	end
	PlayerDamage.takeDamage(player, damage, { label = ("낙하 %.0f"):format(speed), ignoresShield = true })
	return "damage"
end

function FallServer.start()
	local landed = Instance.new("RemoteEvent")
	landed.Name = "FallLanded"
	landed.Parent = ReplicatedStorage
	landed.OnServerEvent:Connect(function(player, speed, flags)
		FallServer.onLanded(player, speed, flags)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastReportAt[player] = nil
	end)
end

return FallServer
