-- 무한 모드 스테이지 이동 서버 권위 처리(11-1 [2]). 클라이언트는 가고 싶은 스테이지
-- 번호(targetStage) 하나만 보낸다 - 그게 규칙(아래/자유, 위/최고+1까지)을 지키는지는
-- 여기서만 검증한다. 위로 최고 도달 단계+1을 넘는 요청은 UI가 평소엔 안 만들지만
-- (버튼은 항상 ±1), 클라이언트가 임의의 숫자를 보내는 경우까지 서버가 직접 막아야
-- 한다 - 클라이언트가 보낸 값을 그대로 믿지 않는다는 이 프로젝트의 원칙 그대로다.
--
-- 24-1 파티(PRD 20.47 [6](라) "보스는 하나라 스테이지도 하나 - 리더가 고른 보스 스테이지"):
--   · 파티 리더가 보스 스테이지로 이동하면 멤버 전원 검사(BossEncounter.checkPartyEntry) 뒤
--     파티 보스가 뜬다(전원 같은 아레나로 텔레포트). 한 명이라도 막히면 이동 자체가 거절되고
--     누가 왜 막혔는지 리더에게 알린다.
--   · 파티원(리더 아님)은 보스 스테이지로 못 간다(party_not_leader) - 파티원의 보스전은 리더가
--     시작하는 파티 보스뿐이다. 잡몹 스테이지 이동은 자유(공유 잡몹은 각자 stage 기준이라 파티와 무관).
--   · 리더가 보스 스테이지를 떠나면 파티 보스전이 끝난다(전원 사냥터로). 파티원이 떠나면 그
--     사람만 빠진다(N·HP 배수 고정 - 이탈의 대가는 파티가 진다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRules = require(ReplicatedStorage.Shared.BossRules)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)
local BossEncounter = require(script.Parent.BossEncounter)
local PartyState = require(script.Parent.PartyState)

local stageMoveRequest = Instance.new("RemoteEvent")
stageMoveRequest.Name = "StageMoveRequest"
stageMoveRequest.Parent = ReplicatedStorage

local stageMoveResult = Instance.new("RemoteEvent")
stageMoveResult.Name = "StageMoveResult"
stageMoveResult.Parent = ReplicatedStorage

local function reject(player, reason, extra)
	local payload = extra or {}
	payload.result = "rejected"
	payload.reason = reason
	payload.stage = PlayerProfile.getInfiniteStage(player)
	payload.best = PlayerProfile.getInfiniteStageBest(player)
	stageMoveResult:FireClient(player, payload)
end

stageMoveRequest.OnServerEvent:Connect(function(player, targetStage)
	if type(targetStage) ~= "number" then
		return
	end
	targetStage = math.floor(targetStage)

	if not PlayerProfile.getProfile(player) then
		return -- 프로필 로드가 아직 안 끝났다
	end

	-- 이동 규칙(11-1 [0]): 아래로는 자유(파밍 유도의 전제), 위로는 최고 도달 단계+1까지만
	-- (건너뛰기 없음). 두 조건을 하나의 범위 검사로 표현한다.
	local best = PlayerProfile.getInfiniteStageBest(player)
	if targetStage < 1 or targetStage > best + 1 then
		reject(player, "range")
		return
	end

	-- 보스 게이트(15-1, 지시 [1] "보스를 못 잡으면 다음 스테이지로 못 가는가"): targetStage
	-- 바로 아래의 보스 스테이지를 아직 못 깼으면 그 이상으로 못 간다. 보스 스테이지
	-- 자신으로 가는 것(그 보스와 싸우러 가는 것)은 항상 허용한다 - getBossStageBelow는
	-- "그보다 낮은" 보스만 본다. 못 갔을 때는 PRD-forge-game-roblox.md 20.22 "막히면
	-- 아래에서 파밍한다" 그대로 - 아래로 내려가는 길은 이 검사와 무관하게 항상 열려 있다.
	local requiredBossStage = BossRules.getBossStageBelow(targetStage)
	if requiredBossStage > 0 and requiredBossStage > PlayerProfile.getBestBossCleared(player) then
		reject(player, "boss_locked", { requiredBossStage = requiredBossStage })
		return
	end

	-- 24-1 파티 검사 - 보스 스테이지로 갈 때만. 리더가 아니면 거절, 리더면 멤버 전원 검사.
	local party = PartyState.getParty(player)
	local isPartyBoss = false
	if party and BossRules.isBossStage(targetStage) and not BossEncounter.getActive(player) then
		if not PartyState.isLeader(player) then
			reject(player, "party_not_leader")
			PartyState.notify(player, "보스 스테이지는 파티 리더만 열 수 있습니다")
			return
		end
		local blocked = BossEncounter.checkPartyEntry(party, targetStage)
		if #blocked > 0 then
			local names = {}
			for _, entry in ipairs(blocked) do
				table.insert(names, ("%s:%s"):format(entry.player.Name, entry.reason))
			end
			reject(player, "party_blocked", { blocked = names })
			PartyState.notify(player, "파티 보스 입장 불가 - " .. table.concat(names, ", "))
			return
		end
		isPartyBoss = true
	end

	local previousStage = PlayerProfile.getInfiniteStage(player)
	local isNewBest = PlayerProfile.setInfiniteStage(player, targetStage)
	stageMoveResult:FireClient(player, {
		result = "ok",
		stage = targetStage,
		best = PlayerProfile.getInfiniteStageBest(player),
	})

	-- 보스 스테이지 진입/퇴장(15-1). 잡몹은 격자 스폰이 항상 그대로 있으니(HuntingGround)
	-- 손댈 게 없다 - 보스만 이 전환에 맞춰 등장·퇴장한다.
	if BossRules.isBossStage(targetStage) then
		if isPartyBoss then
			BossEncounter.spawnForParty(party, player, targetStage)
		else
			BossEncounter.spawnFor(player, targetStage)
		end
	elseif BossRules.isBossStage(previousStage) then
		-- 24-1: 리더(또는 솔로)면 보스전 전체 종료, 파티원이면 자기만 빠진다.
		if party and not PartyState.isLeader(player) then
			BossEncounter.leaveFor(player)
		else
			BossEncounter.despawnFor(player)
		end
	end

	if isNewBest then
		ImmediateSave.request(player)
	end
end)

-- 퇴장 - 자기 보스전에서만 빠진다(파티 보스전은 남은 멤버가 이어간다, BossEncounter.leaveFor).
Players.PlayerRemoving:Connect(function(player)
	BossEncounter.leaveFor(player)
end)

-- 재접속 시 보스 스테이지 복원(15-1). 접속을 끊었던 시점의 저장된 stageProgress.infinite가
-- 이미 보스 스테이지일 수 있다(예: 보스 스테이지에 서 있다가 나감) - 그때는 스테이지
-- "이동"이 일어나지 않으므로 위 OnServerEvent 핸들러가 보스를 스폰할 계기 자체가 없다.
-- 프로필 로드(SaveServer.server.lua)가 언제 끝나는지는 이 스크립트가 모르므로, 로드가
-- 끝날 때까지 기다렸다가 한 번만 확인한다.
Players.PlayerAdded:Connect(function(player)
	while player.Parent and not PlayerProfile.getProfile(player) do
		task.wait()
	end
	if not player.Parent then
		return
	end
	local stage = PlayerProfile.getInfiniteStage(player)
	if BossRules.isBossStage(stage) then
		BossEncounter.spawnFor(player, stage)
	end
end)
