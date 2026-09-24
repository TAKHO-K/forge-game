-- 보스 아레나 구조물이 부서질 때의 파편(P3a C - 사용자 지시 "깨지면 파편 이펙트"). 서버(BossArenaMap)가 BossArenaObstacleBreak로 자리 · 크기 · 색을 보내면
-- 이 클라가 파편 조각을 튀겨 흩고 지운다 - 판정은 없다(겉모습만). 새 파티클 · 에셋 없이 파트(보스 패턴 연출과 같은 계열).
-- 위에 서 있던 사람의 튕김은 서버가 보스 패턴의 launch로 따로 보낸다(BossStormView) - 여기는 그림만 그린다.
-- P3d: 조각은 BossFx 풀에서 꺼낸다(A5 - 동시 상한). cause별 모양:
--   hits · charge(옛 그대로) = 바깥으로 튀어 오르는 파편
--   wave(단상이 지진파 두 번에 무너짐 - C2) · pit(모래 구덩이에 달그락거리다 부서짐 - E2) = 제자리로 주저앉는 낮은 파편 + 바닥 먼지 고리(위에 있던 사람은 그냥 떨어진다)
--   stage = "crack"(단상 첫 지진파 - C2) = 윗면 둘레 먼지 + 작은 조각이 튄다(금 자체는 서버 파트)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
local BossFx = require(script.Parent.BossFx)

local breakEvent = ReplicatedStorage:WaitForChild("BossArenaObstacleBreak")

local PIECES = 10
local FLY_SECONDS = 0.7
local DUST_COLOR = Color3.fromRGB(235, 228, 214) -- 흙먼지(먼지 공통 - BossPatternVisuals와 같은 값)

local rng = Random.new()

local function dustColor(color)
	return (color or DUST_COLOR):Lerp(DUST_COLOR, 0.6)
end

local function burst(data)
	local radius = data.radius or 4
	for index = 1, PIECES do
		local angle = (index / PIECES) * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local size = rng:NextNumber(0.35, 0.7) * radius
		local start = data.position + dir * radius * 0.4
		-- 바깥으로 radius × 2.4 · 위로 3 ~ 6(옛 모양) - 속도 = 거리 ÷ 시간, 중력으로 떨어진다.
		local velocity = dir * radius * 2.4 / FLY_SECONDS + Vector3.new(0, rng:NextNumber(25, 32), 0) -- 꼭대기 3 ~ 5(중력 × 0.5)
		BossFx.chunk(start, velocity, size * 0.55, (data.color or Color3.new(0.5, 0.5, 0.5)):Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25)), FLY_SECONDS)
	end
end

local function crumble(data)
	local radius = data.radius or 4
	local count = BossFxData.dais.crumbleChunks
	local floorY = data.position.Y - (data.height or 4) / 2
	for index = 1, count do
		local angle = (index / count) * 2 * math.pi + rng:NextNumber(-0.25, 0.25)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local start = Vector3.new(data.position.X, floorY + (data.height or 4) * rng:NextNumber(0.4, 1), data.position.Z) + dir * radius * rng:NextNumber(0.2, 0.8)
		-- 주저앉는다: 위로 거의 안 튀고(1 ~ 4) 바깥으로 조금 - 무너지는 모션
		BossFx.chunk(start, dir * rng:NextNumber(2, 6) + Vector3.new(0, rng:NextNumber(1, 4), 0), rng:NextNumber(0.25, 0.45) * radius, (data.color or Color3.new(0.5, 0.5, 0.5)):Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.3)), 0.6)
	end
	for index = 1, 10 do
		local angle = (index / 10) * 2 * math.pi
		local at = Vector3.new(data.position.X, floorY + 0.8, data.position.Z) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		BossFx.puff(at, rng:NextNumber(2, 3.2), dustColor(data.color), 0.7, Vector3.new(math.cos(angle), 0.3, math.sin(angle)) * 5)
	end
	BossFx.ring(Vector3.new(data.position.X, floorY + 0.1, data.position.Z), radius * 0.6, radius * 1.8, Color3.new(1, 1, 1), 0.35, 0.3)
end

local function crack(data)
	local radius = data.radius or 4
	local topY = data.position.Y
	for index = 1, BossFxData.dais.crackDust do
		local angle = (index / BossFxData.dais.crackDust) * 2 * math.pi + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		BossFx.puff(Vector3.new(data.position.X, topY, data.position.Z) + dir * radius * 0.9, rng:NextNumber(1.2, 2), dustColor(data.color), 0.5, dir * 3 + Vector3.new(0, 2, 0))
		if index % 2 == 0 then
			BossFx.chunk(Vector3.new(data.position.X, topY + 0.3, data.position.Z) + dir * radius * 0.7, dir * 4 + Vector3.new(0, 9, 0), 0.5, data.color or Color3.new(0.5, 0.5, 0.5), 0.45)
		end
	end
end

breakEvent.OnClientEvent:Connect(function(data)
	if data.stage == "crack" then
		crack(data)
	elseif data.cause == "wave" or data.cause == "pit" then
		crumble(data)
	else
		burst(data)
	end
end)
