-- S15 1단계 진단(PRD 20.96 [9] ③ · S04(나) Studio 멈춤 재조사) - 임시 계측 모듈. 조사가 끝나면 지운다.
-- S04(나)의 처치 루프(EnhanceVerify.killMobs)가 10회마다 sample()을 부른다. 계속 늘어나는 값을 찾는 것이 목적이다.
-- 판정 · 검증 결과에는 영향이 없다(읽기만 한다).

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local MonsterState = require(script.Parent.MonsterState)
local ItemDropState = require(script.Parent.ItemDropState)

local FreezeProbe = {}

local SAMPLE_EVERY = 10

local connection = nil
local hbCount, hbSum, hbMax = 0, 0, 0
local kills = 0
local windowClock = os.clock()
local resolveSum, resolveMax = 0, 0

function FreezeProbe.start()
	kills = 0
	windowClock = os.clock()
	resolveSum, resolveMax = 0, 0
	hbCount, hbSum, hbMax = 0, 0, 0
	if not connection then
		connection = RunService.Heartbeat:Connect(function(dt)
			hbCount += 1
			hbSum += dt
			if dt > hbMax then
				hbMax = dt
			end
		end)
	end
end

function FreezeProbe.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

local function tagMb(tag)
	local ok, value = pcall(function()
		return Stats:GetMemoryUsageMbForTag(tag)
	end)
	return ok and value or -1
end

-- 한 줄 표본. label = 어느 국면인가.
function FreezeProbe.sample(label)
	local descendants = Workspace:GetDescendants()
	local billboards, parts, tweenLike = 0, 0, 0
	for _, inst in ipairs(descendants) do
		if inst:IsA("BillboardGui") then
			billboards += 1
		elseif inst:IsA("BasePart") then
			parts += 1
		elseif inst:IsA("PointLight") then
			tweenLike += 1
		end
	end
	local now = os.clock()
	local windowMs = (now - windowClock) * 1000
	windowClock = now
	print(("[PROBE] %s 처치=%d 창=%.0fms 몬스터=%d 드랍=%d 후손=%d(빌보드 %d · 파트 %d · 라이트 %d) 총메모리=%.1fMB Lua힙=%.1fMB 인스턴스태그=%.1f 시그널태그=%.2f 하트비트 %d회 평균 %.1fms 최대 %.1fms resolve 평균 %.2fms 최대 %.1fms"):format(
		label, kills, windowMs, #MonsterState.getAllModels(), #ItemDropState.getAllModels(), #descendants, billboards, parts, tweenLike,
		Stats:GetTotalMemoryUsageMb(), collectgarbage("count") / 1024, tagMb(Enum.DeveloperMemoryTag.Instances), tagMb(Enum.DeveloperMemoryTag.Signals),
		hbCount, hbCount > 0 and hbSum / hbCount * 1000 or 0, hbMax * 1000, kills > 0 and resolveSum / math.max(1, SAMPLE_EVERY) * 1000 or 0, resolveMax * 1000))
	hbCount, hbSum, hbMax = 0, 0, 0
	resolveSum, resolveMax = 0, 0
end

-- 처치 한 번이 끝날 때마다 부른다. resolveSeconds = resolveHit 한 번이 걸린 시간.
function FreezeProbe.afterKill(resolveSeconds)
	kills += 1
	resolveSum += resolveSeconds
	if resolveSeconds > resolveMax then
		resolveMax = resolveSeconds
	end
	if kills % SAMPLE_EVERY == 0 then
		FreezeProbe.sample("처치")
	end
end

return FreezeProbe
