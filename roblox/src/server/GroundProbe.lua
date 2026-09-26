-- 지면 Raycast의 단일 출처(22-4). "이 XZ 아래 지면 윗면 Y는 얼마인가"를 묻는 곳 - 몬스터 지면
-- 추적(MonsterAI), 스폰 Y(HuntingGround), 드랍 스냅(ItemDropSpawner), 대시 지면 추종
-- (DashEndpoint), 보스 돌진·낙석(BossPatterns) - 전부 여기를 거친다.
--
-- 지면 = Workspace.Ground 폴더 아래 파트 + Workspace.Terrain(M1-3 굽기)이다(Include 필터). 몬스터·플레이어·드랍·이펙트·
-- 담장은 지면이 아니므로 Exclude 목록을 매번 만들 필요가 없다(DashEndpoint가 살아있는
-- 몬스터 전원을 Exclude에 넣는 것과 대비 - 이 프로브는 초당 수백 번 불리므로 필터가 상수
-- 크기여야 한다). 바닥을 만드는 쪽(HuntingGround·BossEncounter·DevTools 테스트 지형·앞으로의
-- 구역 지형)은 반드시 이 폴더에 Parent한다 - 폴더 밖 바닥은 "지면 없음"으로 읽혀 몬스터가
-- 그 위로 안 간다.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)

local GroundProbe = {}

local folder = nil
local params = nil

-- 부하 실측용 누적(DevTools "/gg terrain cost"가 두 시점의 차로 초당 횟수·ms를 낸다).
local probeCount = 0
local probeSeconds = 0

function GroundProbe.folder()
	if folder and folder.Parent then
		return folder
	end
	folder = Workspace:FindFirstChild("Ground")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Ground"
		folder.Parent = Workspace
	end
	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder, Workspace.Terrain } -- M1-3: 바닥 = Terrain(굽기) + Ground 폴더 파트
	params.IgnoreWater = true -- 물 = 지면 아님(몬스터 · 드랍은 물 위에 서지 않는다 - 스폰 지점은 물을 피한다)
	return folder
end

-- (x, z) 아래 지면 윗면 Y. referenceY 기준 위로 upStuds, 아래로 downStuds 창 안에서만 찾는다 -
-- 창 밖(절벽·심연)은 nil. up/down을 안 주면 TerrainConfig의 몬스터 프로브 창(4/4).
function GroundProbe.groundY(x, z, referenceY, upStuds, downStuds)
	GroundProbe.folder()
	local up = upStuds or TerrainConfig.probeUpStuds
	local down = downStuds or TerrainConfig.probeDownStuds
	local started = os.clock()
	local hit = Workspace:Raycast(Vector3.new(x, referenceY + up, z), Vector3.new(0, -(up + down), 0), params)
	probeSeconds += os.clock() - started
	probeCount += 1
	return hit and hit.Position.Y or nil
end

-- 스폰·드랍처럼 "어느 높이든 가장 위의 지면"이 필요한 곳. 위 60 ~ 아래 60 창.
function GroundProbe.surfaceY(x, z, referenceY)
	return GroundProbe.groundY(x, z, referenceY, 60, 60)
end

-- 몬스터와 추격 대상이 같은 "층"인가(MonsterAI의 네 번째 출구 - 절벽 위아래로 갈라졌는가, 29-4).
-- 루트 중심끼리의 높이차(Reach.sameLayer)가 상한 안이면 그대로 참이다(Raycast 0회 - 평소의 길). 상한을 넘을 때만
-- 대상의 **발밑 지면**을 찾아 몬스터의 발 높이와 다시 비교한다 - 층은 지형의 성질이지 공중에 뜬 몸의 성질이 아니다.
-- 왜 필요한가: 몬스터 루트는 지면 + monsterFootOffsetStuds(1.5), 플레이어 루트는 지면 + 3(HipHeight 2 + 루트 반높이 1)이라
-- 같은 바닥에 서 있기만 해도 높이차가 1.5다. 상한 8은 "점프 7.2 + 여유 0.8"로 잡혔으므로 곁에서 점프하면 꼭대기
-- 0.17초 동안 8.7 > 8이 되어 추격을 포기(= 보스 스킬 중단)할 수 있었다. 띄우기(회오리)·넉백·단 위 점프도 같은 경우다.
-- 발밑에 지면이 없으면(심연 위) 루트 비교의 결과(거짓)를 그대로 둔다.
function GroundProbe.sameGroundLayer(monsterPosition, targetPosition)
	local tolerance = TerrainConfig.heightToleranceStuds
	if math.abs(monsterPosition.Y - targetPosition.Y) <= tolerance then
		return true
	end
	local groundY = GroundProbe.groundY(targetPosition.X, targetPosition.Z, targetPosition.Y, 0, TerrainConfig.airborneProbeDownStuds)
	return groundY ~= nil and math.abs(groundY - (monsterPosition.Y - TerrainConfig.monsterFootOffsetStuds)) <= tolerance
end

function GroundProbe.stats()
	return probeCount, probeSeconds
end

return GroundProbe
