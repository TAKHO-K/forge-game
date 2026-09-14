-- 돌진형 이동의 도착점 계산(21-2 [2]에서 SkillServer.server.lua의 로컬 함수를 모듈로
-- 뽑았다 - 대검 관통돌진·활 백스텝샷·대시(DashServer) 세 곳이 같은 판정을 써야 담장을
-- 뚫는 예외가 어느 한 곳에서도 생기지 않는다). 담장에 막히는지 Raycast로 확인해 최종
-- 도착점을 정한다 - 몬스터 Body/Head는 기본 CanQuery=true라 그냥 두면 Raycast가 "몬스터에
-- 막혔다"고 오판한다(몬스터는 담장이 아니다) - 캐릭터 자신 + 살아있는 몬스터 전원을
-- 제외해 담장·지형에만 막히게 한다. 19-4 [4]-가 구역 담장(ZoneWall, CanCollide=true)이
-- 이 Raycast의 실제 차단 대상이다.

local Workspace = game:GetService("Workspace")

local MonsterState = require(script.Parent.MonsterState)

local DashEndpoint = {}

function DashEndpoint.compute(player, startPos, direction, rangeStuds)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { player.Character }
	for _, model in ipairs(MonsterState.getAllModels()) do
		table.insert(excluded, model)
	end
	raycastParams.FilterDescendantsInstances = excluded
	local rayResult = Workspace:Raycast(startPos, direction * rangeStuds, raycastParams)

	-- 벽에 막히면 그 앞에서 멈춘다(19-4 구역 담장을 뚫지 않는다). 1stud 여유를 둬 캐릭터가
	-- 벽에 파묻히지 않게 한다.
	local finalDistance = rangeStuds
	if rayResult then
		finalDistance = math.max(rayResult.Distance - 1, 0)
	end
	return startPos + direction * finalDistance
end

return DashEndpoint
