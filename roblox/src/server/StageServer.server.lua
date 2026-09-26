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
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)
local BossEncounter = require(script.Parent.BossEncounter)
local PartyState = require(script.Parent.PartyState)
local PartyVote = require(script.Parent.PartyVote)
local BossGate = require(script.Parent.BossGate)

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

local function onStageMove(player, targetStage)
	if type(targetStage) ~= "number" then
		return
	end
	targetStage = math.floor(targetStage)

	if not PlayerProfile.getProfile(player) then
		return -- 프로필 로드가 아직 안 끝났다
	end

	-- G1-5(D0 결정 5): 보스가 살아 있는 동안은 이동하지 않는다 - 거절(boss_alive)하면 클라가 "포기하고 한 스테이지 아래 마을로" 확인창을 띄운다(BossGiveUp).
	-- 잔류 중(보스를 잡은 뒤)은 보스 모델이 없어 여기 안 걸린다.
	if BossEncounter.getActive(player) ~= nil then
		local encounter = BossEncounter.getEncounter(player)
		reject(player, "boss_alive", { bossStage = encounter and encounter.stage, isParty = encounter ~= nil and encounter.party ~= nil })
		return
	end

	-- 이동 규칙(11-1 [0]): 아래로는 자유(파밍 유도의 전제), 위로는 최고 도달 단계+1까지만
	-- (건너뛰기 없음). 두 조건을 하나의 범위 검사로 표현한다.
	local best = PlayerProfile.getInfiniteStageBest(player)
	if targetStage < 1 or targetStage > best + 1 then
		reject(player, "range")
		return
	end

	-- S21-0 A4: 임시 안전 상한(InfiniteStageConfig.safeStageCap 주석 참고) - 정상 진행(이
	-- 요청 경로)만 막는다. `/gg stage`(DevTools.server.lua)는 이 검사를 거치지 않는다.
	if targetStage > InfiniteStageConfig.safeStageCap then
		reject(player, "safe_cap")
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
	-- M1 관문 모드: 보스 스테이지를 골라도 스테이지만 옮기고 관문까지 안내한다 - 리더 · 멤버 검사 · 투표는 관문에서(BossGate.enter).
	--   관문 구역이 없는 보스(새 보스가 구역 없이 들어온 경우)는 옛 즉시 입장.
	--   M1-3 관문 등록: 그 관문이 등록돼 있으면(본인 또는 파티 멤버 한 명이라도) 원격 입장 = 옛 즉시 입장 경로(파티 검사 · 투표 그대로) · 복귀 = 각자 서 있던 자리.
	local gateOf = BossGate.enabled() and BossRules.isBossStage(targetStage) and BossGate.gateForStage(targetStage) or nil
	local remote = gateOf ~= nil and BossGate.usableFor(player, gateOf.bossId)
	local viaGate = gateOf ~= nil and not remote
	if party and viaGate and not PartyState.isLeader(player) then
		reject(player, "party_not_leader")
		PartyState.notify(player, "보스 스테이지는 파티 리더만 열 수 있습니다")
		return
	end
	if party and BossRules.isBossStage(targetStage) and not BossEncounter.getActive(player) and not viaGate then
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

	-- 실제 이동(스테이지 갱신 + 보스 스폰/despawn + 즉시저장) - 파티 보스면 아래 투표를
	-- 통과한 뒤에만, 그 외에는 지금 바로 실행한다.
	local function performMove()
		-- G1-4: 보스맵 잔류 중에 스테이지 선택 창으로 옮기면 그 사람만 잔류에서 빠진다(같이 남은 파티원의 잔류는 그대로).
		if BossEncounter.isLingering(player) then
			BossEncounter.leaveFor(player)
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
		if viaGate then
			-- 관문 모드: 보스는 관문에서 - 지금 보스전에 속해 있으면(잔류 등) 먼저 빠진다
			if BossEncounter.getEncounter(player) then
				BossEncounter.leaveFor(player)
			end
		elseif BossRules.isBossStage(targetStage) then
			if remote then
				BossGate.setRemoteReturnPoints(isPartyBoss and BossEncounter.getEntryMembers(party) or { player })
				print(("[forge-game] 원격 입장: %s → 스테이지 %d(%s)"):format(player.Name, targetStage, isPartyBoss and "파티" or "솔로"))
			end
			if isPartyBoss then
				BossEncounter.spawnForParty(party, player, targetStage)
			else
				BossEncounter.spawnFor(player, targetStage)
			end
		elseif BossRules.isBossStage(previousStage) or BossEncounter.getEncounter(player) then
			-- 24-1: 리더(또는 솔로)면 보스전 전체 종료, 파티원이면 자기만 빠진다.
			-- G1-1(D0 (d) 버그): 파티원은 자기 스테이지가 보스 스테이지가 아닌 채 아레나에 끌려 들어가므로(리더가 연다) "이전 스테이지"만 보면
			-- 일반 → 일반 이동이 어느 분기도 안 타 아레나에 남았다 - 지금 보스전에 속해 있으면 빠진다.
			-- G1-1 리뷰 2: 이전 스테이지가 보스가 아닌 채 보스전에 속한 사람(파티원 · 리더 승계를 받은 파티원)은 자기만 빠진다 - 전체 종료는 보스 스테이지에서 떠나는 리더 · 솔로만.
			if (party and not PartyState.isLeader(player)) or not BossRules.isBossStage(previousStage) then
				BossEncounter.leaveFor(player)
			else
				BossEncounter.despawnFor(player)
			end
		end

		BossGate.refreshGuide(player) -- M1: 보스 스테이지면 그 관문까지 길 안내
		if isNewBest then
			ImmediateSave.request(player)
		end
	end

	-- 25-3(PRD 20.47 [6](라) "입장 수락 팝업" 대체) - 파티 보스 진입만 투표를 거친다.
	-- PartyVote.start는 다른 멤버가 없으면 투표 없이 바로 performMove를 부른다. 이미 진행
	-- 중인 투표가 있으면(경합) 그 자리에서 거절한다 - "지금은 안 된다"는 보스전 중 합류
	-- 차단과 같은 계통.
	if isPartyBoss then
		local started = PartyVote.start(party, player, targetStage, function(passed)
			if passed then
				performMove()
			end
		end)
		if not started then
			reject(player, "vote_pending")
			PartyState.notify(player, "이미 진행 중인 투표가 있습니다")
		end
		return
	end

	performMove()
end
stageMoveRequest.OnServerEvent:Connect(onStageMove)
-- M1-3 검증(Studio 전용): 서버 검증 블록이 클라 요청과 같은 핸들러를 부른다(관문 등록 전 · 뒤 원격 입장 · 파티) - 라이브에는 없다.
if game:GetService("RunService"):IsStudio() then
	local hook = Instance.new("BindableEvent")
	hook.Name = "StageMoveHook"
	hook.Parent = game:GetService("ServerStorage")
	hook.Event:Connect(onStageMove)
end

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
	-- G1-5(D0 결정 5 · 사용자 확정): 재접속은 보스를 다시 세우지 않는다 - 보스 스테이지에서 나갔으면 한 스테이지 아래 마을에서 시작한다
	-- (이동 제한과 합쳐지면 못 이기는 보스에 갇힌다 - 포기 · 탈퇴와 같은 −1 규칙).
	local stage = PlayerProfile.getInfiniteStage(player)
	if BossRules.isBossStage(stage) and PlayerProfile.getBestBossCleared(player) < stage then -- 리뷰 5: 이미 깬 보스 스테이지(잔류에서 [마을])면 그대로
		PlayerProfile.setInfiniteStage(player, math.max(1, stage - 1))
		print(("[forge-game] 재접속: 보스 스테이지 %d → %d(마을)"):format(stage, math.max(1, stage - 1)))
	end
end)
