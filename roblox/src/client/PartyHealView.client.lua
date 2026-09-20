-- 힐러가 내 체력을 회복시켜 줬을 때(S13 · PRD 20.81 [B-3]) 내 캐릭터 위에 자기 힐과 같은 녹색 "+숫자"를 띄운다.
-- 서버(HealCast)가 파티원마다 PartyHealReceived(amount, isCrit)를 쏜다 - 회복 계산과 HP 변경은 전부 서버가 한다. 여기는 그리기만.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DamageNumbers = require(script.Parent.DamageNumbers)

local player = Players.LocalPlayer
local partyHealReceived = ReplicatedStorage:WaitForChild("PartyHealReceived")

partyHealReceived.OnClientEvent:Connect(function(amount, isCrit)
	if type(amount) ~= "number" then
		return
	end
	if RunService:IsStudio() then
		print(("[S13][UI] 파티 회복 수신: +%.1f%s · 캐릭터 머리 있음 %s"):format(amount, isCrit and "(치명)" or "", tostring(player.Character ~= nil and player.Character:FindFirstChild("Head") ~= nil)))
	end
	DamageNumbers.show(player.Character, amount, isCrit == true, true)
end)
