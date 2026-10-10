-- C2 전투력 동기화: 1초마다 플레이어마다 전투력(PlayerProfile.getCombatPower)을 Player Attribute "CombatPower"에 쓴다.
--   읽는 곳 = MonsterState.applyDamage(주는 피해 배율 - 서버) · 권장 전투력 표시(클라 StageSelect · 구역 입구). 장비 · 강화가 바뀐 뒤 최대 1초 늦는다(판정 영향 = 그 1초의 배율만).
local Players = game:GetService("Players")

local PlayerProfile = require(script.Parent.PlayerProfile)
local TranscendentService = require(script.Parent.TranscendentService) -- C5-7

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
			pcall(TranscendentService.syncAura, player) -- C5-7 보스전 흑금 오라(TranscendentParts) · C5-7b 환영 표시 · 광폭 만료
			local okOver, info = pcall(PlayerProfile.getOverflowInfo, player) -- PROG-2B-1 4: 공속 상한 넘침이 위력에 들어간 몫(장비 툴팁 "상한 도달 · 위력으로 전환 +n%")
			if okOver and type(info) == "table" and player:GetAttribute("SpeedOverflowPower") ~= info.speedConv then
				player:SetAttribute("SpeedOverflowPower", info.speedConv)
			end
			local okLevel, best = pcall(PlayerProfile.getDealItemLevelBest, player) -- C5-1 뒤처짐 신호(MonsterState가 읽는다)
			if okLevel and player:GetAttribute("DealItemLevel") ~= best then
				player:SetAttribute("DealItemLevel", best)
			end
		end
		task.wait(INTERVAL_SECONDS)
	end
end)
