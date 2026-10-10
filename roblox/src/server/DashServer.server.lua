-- 대시 서버 판정(21-2 [2]). SkillServer.server.lua의 돌진형(관통돌진·백스텝샷)과 같은 신뢰
-- 모델이다 - 클라는 "대시하겠다"만 보내고, 쿨다운·방향·도착점(담장 차단)·피해 감소는 전부
-- 여기서 정한다. 실제 이동은 결과를 받은 클라(DashInput.client.lua)가 자기 캐릭터를
-- 트윈한다(그 클라가 캐릭터의 네트워크 소유자라 서버가 CFrame을 밀어넣으면 위치가 튄다 -
-- SkillServer 상단 주석과 같은 이유).
--
-- 방향: 조이스틱/WASD 이동 방향(Humanoid.MoveDirection, 소유 클라에서 복제된다)이 있으면
-- 그쪽, 서 있으면 바라보는 방향. 클라가 방향 벡터를 따로 보내지 않는다 - 서버가 이미
-- 갖고 있는 값을 쓴다(AimPoint처럼 "클라가 보낸 방향을 그대로 믿지 않는다").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local DashEndpoint = require(script.Parent.DashEndpoint)
local AirState = require(script.Parent.AirState)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local DashModes = require(ReplicatedStorage.Shared.DashModes) -- FINAL-1 3: 긴 · 짧은 · 기울기 대시
local DashWindow = require(script.Parent.DashWindow)

local dashRequest = Instance.new("RemoteEvent")
dashRequest.Name = "DashRequest"
dashRequest.Parent = ReplicatedStorage

-- { ok=true, cooldownSeconds, startPosition, endPosition, durationSeconds } 또는
-- { ok=false, reason } - SkillCastResult의 kind="dash"와 같은 모양이라 클라 재생 코드가
-- 같은 형태를 쓴다. SkillSlots.client.lua도 이 이벤트로 대시 슬롯 링을 서버 상태에 맞춘다.
local dashResult = Instance.new("RemoteEvent")
dashResult.Name = "DashResult"
dashResult.Parent = ReplicatedStorage

local dashStates = {} -- [Player] = MoveRules.newDashState() - MV1 태초 신발 2단 대시(연속 충전 · 쿨다운은 두 번째 뒤)

-- FINAL-1 3: mode = "long" | "short" | "analog"(모르는 값 = long) · tilt = 0 ~ 1(analog) · dir = 클라가 고른 카메라 기준 평면 방향(8방향 · 짧은 대시 키 방향 - 없으면 옛 규칙)
local function handleDash(player, mode, tilt, dir)
	if not PlayerProfile.getClassId(player) then
		return -- 직업 미선택·로드 전 - 헛동작(AttackServer와 같은 원칙)
	end
	-- 29-1(PRD 20.73 [2-8] A-2): 잡힌 동안엔 대시도 못 쓴다.
	if PlayerState.isTrapped(player) then
		dashResult:FireClient(player, { ok = false, reason = "trapped" })
		return
	end
	-- BOSS-NIGHT-3 2단계(VERIFY-2 정정 3 · 5): 기절 중 = 대시 거절(옛 = 쿨만 쓰고 보호 창이 열렸다) · 띄워진 직후(airborne.dashAfterSeconds 전) = 거절 - 띄움 회복은 그 뒤 공중 대시로만. 클라 DashInput도 같은 조건.
	local ccReason = require(script.Parent.PlayerCC).dashBlockedReason(player)
	if ccReason then
		dashResult:FireClient(player, { ok = false, reason = ccReason })
		return ccReason
	end

	local now = os.clock()
	local charges = PlayerProfile.getDashCharges(player)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or (PlayerState.getHp(player) or 0) <= 0 then
		return
	end

	-- M1-3: 물속 대시 불가(MovementConfig.water.dashInWater) - 쿨다운을 쓰지 않는다
	if not require(ReplicatedStorage.Shared.data.MovementConfig).water.dashInWater and require(script.Parent.WorldHazards).inWater(rootPart.Position) then
		dashResult:FireClient(player, { ok = false, reason = "water" })
		return
	end

	local move = humanoid.MoveDirection
	local flat = Vector3.new(move.X, 0, move.Z)
	if typeof(dir) == "Vector3" and dir == dir and Vector3.new(dir.X, 0, dir.Z).Magnitude > 0.5 then -- NaN · 0 거름(방향은 어느 쪽이든 합법 - 거리 · 쿨다운은 서버가 정한다)
		flat = Vector3.new(dir.X, 0, dir.Z)
	end
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	end
	if flat.Magnitude < 1e-3 then
		return
	end
	local direction = flat.Unit

	-- MV1: 공중 대시 = 한 체공 MoveRules.airDashesAllowed회(서버 세션으로 센다 - 옛 규칙은 클라만 셌다). 쿨다운은 지상과 같은 것을 쓴다(아래 MoveRules.tryDash - FINAL-1b 주석 바로잡음: 옛 "쿨다운을 쓰지 않는다"는 틀림).
	local session = AirState.session(player)
	if session and session.airDashes >= MoveRules.airDashesAllowed(charges >= 2) then
		dashResult:FireClient(player, { ok = false, reason = "air_used" })
		return "air_used"
	end
	local st = dashStates[player] or MoveRules.newDashState()
	dashStates[player] = st
	local cooldownScale = require(script.Parent.TranscendentService).dashCooldownScale(player) -- C5-7b 광폭(전투 중 × 0.8)
	local ok, reason, second = MoveRules.tryDash(st, now, charges, cooldownScale)
	if not ok then
		dashResult:FireClient(player, { ok = false, reason = reason })
		return reason
	end
	if session then
		session.airDashes += 1
	end

	-- MV1 거리 = 기본 × 장비 걷기 배율(1 ~ speedScaleMax) × 공중이면 환생 4 공중 대시 강화
	local tier = MoveRules.tierOf(player)
	mode = (mode == "short" or mode == "analog") and mode or "long"
	local baseStuds, durationSeconds = DashModes.base(mode, type(tilt) == "number" and tilt or 1)
	local range = JumpMath.dashRangeStuds(JumpMath.moveSpeedMultiplier(PlayerProfile.getSpeedPercentBonus(player)), session and tier.airDashRangeMultiplier or 1, baseStuds)
	local startPos = rootPart.Position
	if session and session.peakY then
		-- BR1-4b 파트 0-4: 공중 대시는 낙하 속도를 0으로 끊는다(클라 DashInput) = 낙법 → 서버 낙하 궤적 최고점도 대시 자리부터 다시 잰다(서버가 본 자리 - 지연만큼 높게 = 보수적).
		session.peakY = math.min(session.peakY, startPos.Y)
		session.lowY = session.peakY
	end
	local endPos = DashEndpoint.compute(player, startPos, direction, range)
	require(script.Parent.HeightGuard).grantDash(player, range) -- S1: 서버가 준 대시 거리 = 합법 수평 이동

	-- PRD 5.4 "대시 중 피격 데미지 50% 감소" - 대검 회전베기와 같은 통로(PlayerState).
	DashWindow.begin(player, DashModes.protectSeconds(durationSeconds)) -- FINAL-1 3: 대시 회피 창 한 곳(피해 감소 · 통과 판정) · FINAL-1b 결정 3: 창 = max(이동 시간, 0.3)

	dashResult:FireClient(player, {
		ok = true,
		cooldownSeconds = DashConfig.cooldownSeconds * cooldownScale,
		-- MV1 2단 대시: 첫 대시 뒤 두 번째 창이 열려 있으면 그 끝까지 남은 초(클라 쿨 링 · 충전 표시) · second = 이번이 두 번째였나
		chainSeconds = (charges >= 2 and not second) and DashConfig.primordialShoes.chainWindowSeconds or nil,
		second = second,
		rangeStuds = range,
		startPosition = startPos,
		endPosition = endPos,
		durationSeconds = durationSeconds,
		mode = mode,
	})
	return "ok", range, endPos, startPos, second
end
dashRequest.OnServerEvent:Connect(handleDash)
if game:GetService("RunService"):IsStudio() then -- 검증 훅(MV1(나)): 실제 요청과 같은 판정 · 결과(클라에도 DashResult가 간다)
	local hook = Instance.new("BindableFunction")
	hook.Name = "DashHook"
	hook.OnInvoke = function(player, resetCooldown, mode, tilt, dir)
		if resetCooldown then
			dashStates[player] = nil -- 검증: 쿨다운 없이 다음 대시를 잰다
		end
		return handleDash(player, mode, tilt, dir)
	end
	hook.Parent = game:GetService("ServerStorage")
end

-- BOSS-NIGHT-3 addendum-2 17: 보스 입장 · 다시 도전 = 대시 쿨 초기화(거절 결과 = 클라 쿨 상태 · 쿨 링도 비운다 - DashInput · SkillSlots)
require(script.Parent.BossEncounter).onMemberRefreshed(function(player)
	dashStates[player] = nil
	dashResult:FireClient(player, { ok = false, reason = "reset" })
end)

Players.PlayerRemoving:Connect(function(player)
	dashStates[player] = nil
end)

print("[forge-game] DashServer 로드됨 - 대시(LeftShift/모바일 버튼) 판정 활성")
