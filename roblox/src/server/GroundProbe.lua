-- 지면 Raycast의 단일 출처(22-4). "이 XZ 아래 지면 윗면 Y는 얼마인가"를 묻는 곳 - 몬스터 지면
-- 추적(MonsterAI), 스폰 Y(HuntingGround), 드랍 스냅(ItemDropSpawner), 대시 지면 추종
-- (DashEndpoint), 보스 돌진·낙석(BossPatterns) - 전부 여기를 거친다.
--
-- 지면 = Workspace.Ground 폴더 아래 파트만이다(Include 필터). 몬스터·플레이어·드랍·이펙트·
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
	params.FilterDescendantsInstances = { folder }
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

function GroundProbe.stats()
	return probeCount, probeSeconds
end

return GroundProbe
