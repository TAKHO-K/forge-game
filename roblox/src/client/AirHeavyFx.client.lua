-- MV1 공중 3타 강공격 반짝임(그리기만 - 서버 AttackServer가 공중 3타 강공격이 나간 순간 곁의 사람에게 AirHeavyFx(때린 사람)을 보낸다).
--   모양 = 무기 손(오른손) 자리에서 흰 · 노란 별 조각 STARS개가 사방으로 튀었다가 LIFE초 안에 사라진다(파티클 없이 파트 - art-spec 7장 타격 입자 예산 ≤ 6).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local STARS, LIFE, SPREAD, SIZE = 6, 0.35, 4.5, 1.1 -- 0.5 · 3.2는 화면에서 거의 안 보였다(MV1 스크린샷)

ReplicatedStorage:WaitForChild("AirHeavyFx").OnClientEvent:Connect(function(who)
	local character = typeof(who) == "Instance" and who.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("HumanoidRootPart"))
	if not hand then
		return
	end
	local origin = hand.Position
	for i = 1, STARS do
		local star = Instance.new("Part")
		star.Name = "MV1AirHeavyStar"
		star.Shape = Enum.PartType.Ball
		star.Size = Vector3.new(SIZE, SIZE, SIZE)
		star.Material = Enum.Material.Neon
		star.Color = i % 2 == 0 and UIColors.xp or UIColors.textPrimary
		star.Anchored, star.CanCollide, star.CanQuery, star.CanTouch, star.CastShadow = true, false, false, false, false
		star.Position = origin
		star.Parent = Workspace
		local a = (i / STARS) * math.pi * 2
		local goal = origin + Vector3.new(math.cos(a) * SPREAD, 0.8 + (i % 3) * 0.6, math.sin(a) * SPREAD)
		TweenService:Create(star, TweenInfo.new(LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = goal, Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 }):Play()
		task.delay(LIFE + 0.05, function()
			star:Destroy()
		end)
	end
	if who == Players.LocalPlayer then
		character:SetAttribute("MV1AirHeavyCount", (character:GetAttribute("MV1AirHeavyCount") or 0) + 1) -- 계측(검증)
	end
end)
