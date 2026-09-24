-- 보스 아레나 구조물이 부서질 때의 파편(P3a C - 사용자 지시 "깨지면 파편 이펙트"). 서버(BossArenaMap)가 BossArenaObstacleBreak로 자리 · 크기 · 색을 보내면
-- 이 클라가 파편 조각을 튀겨 흩고 지운다 - 판정은 없다(겉모습만). 새 파티클 · 에셋 없이 파트 + Tween(보스 패턴 연출과 같은 계열).
-- 위에 서 있던 사람의 튕김은 서버가 보스 패턴의 launch로 따로 보낸다(BossStormView) - 여기는 그림만 그린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local breakEvent = ReplicatedStorage:WaitForChild("BossArenaObstacleBreak")

local PIECES = 10
local FLY_SECONDS = 0.7

local rng = Random.new()

breakEvent.OnClientEvent:Connect(function(data)
	local radius = data.radius or 4
	for index = 1, PIECES do
		local angle = (index / PIECES) * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local size = rng:NextNumber(0.35, 0.7) * radius
		local piece = Instance.new("Part")
		piece.Name = "ObstacleDebris"
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.Material = Enum.Material.SmoothPlastic
		piece.Color = (data.color or Color3.new(0.5, 0.5, 0.5)):Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25))
		piece.Size = Vector3.new(size, size * 0.7, size * 0.8)
		local start = data.position + dir * radius * 0.4
		piece.CFrame = CFrame.new(start) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		piece.Parent = Workspace
		-- 바깥으로 튀어 오르며 돌고(첫 절반), 떨어지며 사라진다(둘째 절반).
		local peak = start + dir * radius * 1.4 + Vector3.new(0, rng:NextNumber(3, 6), 0)
		local land = start + dir * radius * 2.4 + Vector3.new(0, -(data.height or 4) / 2, 0)
		TweenService:Create(piece, TweenInfo.new(FLY_SECONDS / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(peak) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
		}):Play()
		task.delay(FLY_SECONDS / 2, function()
			TweenService:Create(piece, TweenInfo.new(FLY_SECONDS / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(land) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
				Transparency = 1,
			}):Play()
		end)
		task.delay(FLY_SECONDS + 0.05, function()
			piece:Destroy()
		end)
	end
end)
