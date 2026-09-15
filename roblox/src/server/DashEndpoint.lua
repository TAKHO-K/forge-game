-- 돌진형 이동의 도착점 계산(21-2 [2]에서 SkillServer.server.lua의 로컬 함수를 모듈로
-- 뽑았다 - 대검 관통돌진·활 백스텝샷·대시(DashServer) 세 곳이 같은 판정을 써야 담장을
-- 뚫는 예외가 어느 한 곳에서도 생기지 않는다). 담장에 막히는지 Raycast로 확인해 최종
-- 도착점을 정한다 - 몬스터 Body/Head는 기본 CanQuery=true라 그냥 두면 Raycast가 "몬스터에
-- 막혔다"고 오판한다(몬스터는 담장이 아니다) - 캐릭터 자신 + 살아있는 몬스터 전원을
-- 제외해 담장에만 막히게 한다. 19-4 [4]-가 구역 담장(ZoneWall, CanCollide=true)이
-- 이 Raycast의 실제 차단 대상이다.
--
-- 22-4 지면 추종: 지면(Workspace.Ground)은 벽 Raycast에서 제외한다 - 완만한 오름 경사가
-- "벽"으로 읽혀 대시가 비탈 발치에서 끊기는 것을 막는다. 대신 경로를 dashGroundSample(4stud)
-- 간격으로 표본해 지면 Y를 따라간다: 표본 사이 오름이 경사 한계(tan45×4=4)를 넘으면 그
-- 직전 표본에서 멈추고(절벽 = 벽), 지면이 없는 표본(심연)은 그대로 지나간다 - 절벽 밖으로
-- 대시하면 떨어진다(낙하 피해 없음, PRD 20.50 [4]). 도착점 Y = 마지막 지면 Y + 시작 시
-- 루트-지면 간격. 시작점 아래에 지면이 없으면(공중 대시, 21-3) 지면 추종 없이 옛 판정 그대로.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local MonsterState = require(script.Parent.MonsterState)
local GroundProbe = require(script.Parent.GroundProbe)

local DashEndpoint = {}

function DashEndpoint.compute(player, startPos, direction, rangeStuds)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { player.Character, GroundProbe.folder() }
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

	-- 지면 추종(22-4). 시작 발밑 지면을 기준으로 루트-지면 간격을 재고, 표본마다 갱신한다.
	local startGroundY = GroundProbe.groundY(startPos.X, startPos.Z, startPos.Y, 2, TerrainConfig.heightToleranceStuds)
	if not startGroundY then
		return startPos + direction * finalDistance
	end
	local rootAboveGround = startPos.Y - startGroundY
	local sampleStep = TerrainConfig.dashGroundSampleStuds
	local maxRisePerSample = sampleStep * TerrainConfig.maxSlopeTangent
	local lastGroundY = startGroundY
	local reached = 0
	while reached < finalDistance do
		local nextDistance = math.min(reached + sampleStep, finalDistance)
		local samplePos = startPos + direction * nextDistance
		local groundY = GroundProbe.groundY(samplePos.X, samplePos.Z, lastGroundY, TerrainConfig.heightToleranceStuds, TerrainConfig.heightToleranceStuds)
		if groundY and groundY - lastGroundY > maxRisePerSample * ((nextDistance - reached) / sampleStep) then
			break -- 경사 한계를 넘는 오름 = 벽. 직전 표본에서 멈춘다.
		end
		if groundY then
			lastGroundY = groundY
		end
		reached = nextDistance
	end
	local endPos = startPos + direction * reached
	return Vector3.new(endPos.X, lastGroundY + rootAboveGround, endPos.Z)
end

return DashEndpoint
