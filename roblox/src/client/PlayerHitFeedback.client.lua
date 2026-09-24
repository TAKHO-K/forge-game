-- P3a D4: 내가 맞은 순간의 표시(서버 PlayerDamage.takeDamage → PlayerHitFeedback). 체력바만 줄던 옛 표시로는 신규 보호로 작아진 피해 · 쉴드가 다 막은 피격이
-- "안 맞은 것처럼" 보였다 - 판정이 있었다는 것을 머리 위 숫자로 알린다(빨강 = 들어간 피해, 테두리색 = 쉴드가 막은 몫). 판정에는 영향이 없다(그리기만).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamageNumbers = require(script.Parent.DamageNumbers)

local feedback = ReplicatedStorage:WaitForChild("PlayerHitFeedback")
local player = Players.LocalPlayer

feedback.OnClientEvent:Connect(function(damage, absorbed)
	if (damage or 0) <= 0 and (absorbed or 0) <= 0 then
		return
	end
	DamageNumbers.showTaken(player.Character, damage or 0, absorbed or 0)
end)
