-- 무한 모드 스테이지 이동 서버 권위 처리(11-1 [2]). 클라이언트는 가고 싶은 스테이지
-- 번호(targetStage) 하나만 보낸다 - 그게 규칙(아래/자유, 위/최고+1까지)을 지키는지는
-- 여기서만 검증한다. 위로 최고 도달 단계+1을 넘는 요청은 UI가 평소엔 안 만들지만
-- (버튼은 항상 ±1), 클라이언트가 임의의 숫자를 보내는 경우까지 서버가 직접 막아야
-- 한다 - 클라이언트가 보낸 값을 그대로 믿지 않는다는 이 프로젝트의 원칙 그대로다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRules = require(ReplicatedStorage.Shared.BossRules)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)
local BossEncounter = require(script.Parent.BossEncounter)

local stageMoveRequest = Instance.new("RemoteEvent")
stageMoveRequest.Name = "StageMoveRequest"
stageMoveRequest.Parent = ReplicatedStorage

local stageMoveResult = Instance.new("RemoteEvent")
stageMoveResult.Name = "StageMoveResult"
stageMoveResult.Parent = ReplicatedStorage

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
		stageMoveResult:FireClient(player, {
			result = "rejected",
			reason = "range",
			stage = PlayerProfile.getInfiniteStage(player),
			best = best,
		})
		return
	end

	-- 보스 게이트(15-1, 지시 [1] "보스를 못 잡으면 다음 스테이지로 못 가는가"): targetStage
	-- 바로 아래의 보스 스테이지를 아직 못 깼으면 그 이상으로 못 간다. 보스 스테이지
	-- 자신으로 가는 것(그 보스와 싸우러 가는 것)은 항상 허용한다 - getBossStageBelow는
	-- "그보다 낮은" 보스만 본다. 못 갔을 때는 PRD-forge-game-roblox.md 20.22 "막히면
	-- 아래에서 파밍한다" 그대로 - 아래로 내려가는 길은 이 검사와 무관하게 항상 열려 있다.
	local requiredBossStage = BossRules.getBossStageBelow(targetStage)
	if requiredBossStage > 0 and requiredBossStage > PlayerProfile.getBestBossCleared(player) then
		stageMoveResult:FireClient(player, {
			result = "rejected",
			reason = "boss_locked",
			requiredBossStage = requiredBossStage,
			stage = PlayerProfile.getInfiniteStage(player),
			best = best,
		})
		return
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
		BossEncounter.spawnFor(player, targetStage)
	elseif BossRules.isBossStage(previousStage) then
		BossEncounter.despawnFor(player)
	end

	if isNewBest then
		ImmediateSave.request(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	BossEncounter.despawnFor(player)
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
