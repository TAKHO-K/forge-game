-- 클래스 선택 서버 권위 처리(10-3 [2]). 클라이언트는 classId 문자열만 보낸다 - 존재하는
-- 클래스인지는 여기서만 검증한다(클라이언트가 보낸 값을 그대로 믿지 않는다). 자유 변경을
-- 허용한다 - 직업별 저장 분리(19-1)로 각 직업이 자기 레벨·무기·장비·진행도를 따로 갖게
-- 되면서, 전환은 "그 직업이 레벨 1부터 다시 시작"이라는 이미 충분한 페널티를 갖는다(하드
-- 락을 걸면 "잘못 골랐다"는 후회가 이탈로 이어진다는 판단). 클라이언트(ClassSelectUI)가
-- 이미 진행 중인 직업에서 다른 직업으로 바꿀 때만 확인창을 띄운다 - 여긴 서버 검증이라
-- 그 확인을 건너뛴 요청이 와도 존재하는 classId이기만 하면 그대로 받아들인다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)

local classSelectRequest = Instance.new("RemoteEvent")
classSelectRequest.Name = "ClassSelectRequest"
classSelectRequest.Parent = ReplicatedStorage

-- 직업 변경 확인창(19-1)이 "레벨 X · 최고 스테이지 Y로 이어집니다"를 보여주기 위해
-- 4직업 전부의 요약을 요청하는 통로. PlayerProfile.getClassSummaries를 그대로 전달한다.
local classSummaryFetch = Instance.new("RemoteFunction")
classSummaryFetch.Name = "ClassSummaryFetch"
classSummaryFetch.Parent = ReplicatedStorage

classSummaryFetch.OnServerInvoke = function(player)
	return PlayerProfile.getClassSummaries(player)
end

classSelectRequest.OnServerEvent:Connect(function(player, classId)
	if type(classId) ~= "string" or not ClassData.classes[classId] then
		return -- 존재하지 않는 클래스 - 공격 사거리 밖 요청과 같은 취급으로 조용히 무시
	end

	if not PlayerProfile.getProfile(player) then
		return -- 프로필 로드가 아직 안 끝났다
	end

	if PlayerProfile.getClassId(player) == classId then
		return -- 이미 그 직업이다 - 확인창을 건너뛰고 재요청한 경우 등, 할 일이 없다
	end

	PlayerProfile.setClassId(player, classId)
	print(("[forge-game] 클래스 선택: %s -> %s"):format(player.Name, classId))

	-- 클래스 선택도 강화 결과와 같은 "되돌릴 수 없는 사건"이다(10-3 [2] - 10-2의 즉시저장
	-- 경로를 재사용하라는 지시). 클라이언트가 재접속 전까지 골라 둔 클래스로 계속 싸우다가
	-- 서버가 크래시하면 선택이 사라진다 - 그 사이 이미 그 클래스로 벌어들인 결과와 어긋난다.
	ImmediateSave.request(player)
end)
