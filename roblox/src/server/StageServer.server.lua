-- 무한 모드 스테이지 이동 서버 권위 처리(11-1 [2]). 클라이언트는 가고 싶은 스테이지
-- 번호(targetStage) 하나만 보낸다 - 그게 규칙(아래/자유, 위/최고+1까지)을 지키는지는
-- 여기서만 검증한다. 위로 최고 도달 단계+1을 넘는 요청은 UI가 평소엔 안 만들지만
-- (버튼은 항상 ±1), 클라이언트가 임의의 숫자를 보내는 경우까지 서버가 직접 막아야
-- 한다 - 클라이언트가 보낸 값을 그대로 믿지 않는다는 이 프로젝트의 원칙 그대로다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)

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
			stage = PlayerProfile.getInfiniteStage(player),
			best = best,
		})
		return
	end

	local isNewBest = PlayerProfile.setInfiniteStage(player, targetStage)
	stageMoveResult:FireClient(player, {
		result = "ok",
		stage = targetStage,
		best = PlayerProfile.getInfiniteStageBest(player),
	})

	if isNewBest then
		ImmediateSave.request(player)
	end
end)
