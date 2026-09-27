-- C2 전투력 동기화: 1초마다 플레이어마다 전투력(PlayerProfile.getCombatPower)을 Player Attribute "CombatPower"에 쓴다.
--   읽는 곳 = MonsterState.applyDamage(주는 피해 배율 - 서버) · 권장 전투력 표시(클라 StageSelect · 구역 입구). 장비 · 강화가 바뀐 뒤 최대 1초 늦는다(판정 영향 = 그 1초의 배율만).
local Players = game:GetService("Players")

local PlayerProfile = require(script.Parent.PlayerProfile)

local INTERVAL_SECONDS = 1

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, power = pcall(PlayerProfile.getCombatPower, player)
			if ok and type(power) == "number" and power == power then
				if player:GetAttribute("CombatPower") ~= power then
					player:SetAttribute("CombatPower", power)
				end
			end
		end
		task.wait(INTERVAL_SECONDS)
	end
end)
