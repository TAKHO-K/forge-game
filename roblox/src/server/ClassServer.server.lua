-- 클래스 선택 서버 권위 처리(10-3 [2]). 클라이언트는 classId 문자열만 보낸다 - 존재하는
-- 클래스인지는 여기서만 검증한다(클라이언트가 보낸 값을 그대로 믿지 않는다). 지금은 자유
-- 변경을 허용한다 - 장비가 무기 하나뿐이라 변경해도 밸런스가 안 깨지고, 클래스별 배율을
-- 비교해 보는 개발 중 테스트에도 편하다. 나중에 장비가 늘어나면 이대로 둘지, 쿨다운을 둘지,
-- 유료 변경권으로 팔지를 다시 판단해야 한다(PRD-forge-game-roblox.md 10-3 절, 미결 항목).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)

local classSelectRequest = Instance.new("RemoteEvent")
classSelectRequest.Name = "ClassSelectRequest"
classSelectRequest.Parent = ReplicatedStorage

classSelectRequest.OnServerEvent:Connect(function(player, classId)
	if type(classId) ~= "string" or not ClassData.classes[classId] then
		return -- 존재하지 않는 클래스 - 공격 사거리 밖 요청과 같은 취급으로 조용히 무시
	end

	if not PlayerProfile.getProfile(player) then
		return -- 프로필 로드가 아직 안 끝났다
	end

	PlayerProfile.setClassId(player, classId)
	print(("[forge-game] 클래스 선택: %s -> %s"):format(player.Name, classId))

	-- 클래스 선택도 강화 결과와 같은 "되돌릴 수 없는 사건"이다(10-3 [2] - 10-2의 즉시저장
	-- 경로를 재사용하라는 지시). 클라이언트가 재접속 전까지 골라 둔 클래스로 계속 싸우다가
	-- 서버가 크래시하면 선택이 사라진다 - 그 사이 이미 그 클래스로 벌어들인 결과와 어긋난다.
	ImmediateSave.request(player)
end)
