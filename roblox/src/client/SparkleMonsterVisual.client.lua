-- 반짝이 몬스터 무지개색 순환(19-4 [6], PRD 8.0-5 "무지개빛 반짝임"). 서버가 색을 매
-- 프레임 바꿔 복제하면 그 값이 모든 클라이언트로 매번 네트워크를 타야 한다 - 순수 시각
-- 효과라 서버 권위가 필요 없으므로(SparkleGlow.Color는 판정에 쓰이지 않는다) 클라이언트가
-- 각자 로컬로 순환시킨다. 반짝이 자체가 드물어(스폰 확률 0.5%) 동시에 여러 마리를
-- 순환시켜도 부담이 없다.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local HUE_CYCLE_SECONDS = 2 -- 웹 draw Monster의 (gameTime*180)%360과 비슷한 체감 속도(2초에 한 바퀴)

local trackedGlows = {} -- [PointLight] = true

local function trackModel(model)
	local body = model:FindFirstChild("Body")
	local glow = body and body:FindFirstChild("SparkleGlow")
	if glow then
		trackedGlows[glow] = true
		glow.AncestryChanged:Connect(function(_, parent)
			if not parent then
				trackedGlows[glow] = nil
			end
		end)
	end
end

for _, model in ipairs(CollectionService:GetTagged("SparkleMonster")) do
	trackModel(model)
end
CollectionService:GetInstanceAddedSignal("SparkleMonster"):Connect(trackModel)

RunService.RenderStepped:Connect(function()
	local hue = (os.clock() % HUE_CYCLE_SECONDS) / HUE_CYCLE_SECONDS
	local color = Color3.fromHSV(hue, 1, 1)
	for glow in pairs(trackedGlows) do
		glow.Color = color
	end
end)
