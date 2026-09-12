-- 자동 체력회복(17-1, 19-1에서 조건 확장). 마지막 전투 행위(피격 또는 공격 시도) 후
-- CombatConfig.regenDelaySeconds가 지나면 초당 최대체력의 regenPercentPerSecond만큼
-- 회복한다 - "쉬고 있을 때"의 보상이지 "싸우는 중"에 주는 보상이 아니다(힐러의 딜링모드
-- 자원 소모가 이 회복에 압도당해 사실상 상시 가동되던 문제, PRD-forge-game-roblox.md
-- 20.36 참고 - 다른 3직업에도 동일하게 적용되어 규칙이 하나로 통일된다). PlayerState가
-- HP의 유일한 소스라는 원칙대로
-- (PlayerState.lua 참고) HP를 바꾸는 이 지점에서도 Attribute(Hp) 동기화를 직접 한다
-- (MonsterAI.server.lua의 syncHud와 같은 패턴 - 이 스크립트 전용 루프라 함수를 공유하지
-- 않는다). Regenerating Attribute는 클라이언트(PlayerHealthBar.client.lua)가 체력바 색을
-- 바꾸는 데 쓴다 - 상태가 바뀔 때만 SetAttribute를 불러 불필요한 리플리케이션을 줄인다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerState = require(script.Parent.PlayerState)

local function setRegenerating(player, value)
	if player:GetAttribute("Regenerating") ~= value then
		player:SetAttribute("Regenerating", value)
	end
end

RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local hp = PlayerState.getHp(player)
		local maxHp = PlayerState.getMaxHp(player)
		if not hp or not maxHp or hp <= 0 or hp >= maxHp then
			setRegenerating(player, false)
			continue
		end

		local lastCombatActionAt = PlayerState.getLastCombatActionAt(player)
		if lastCombatActionAt and os.clock() - lastCombatActionAt < CombatConfig.regenDelaySeconds then
			setRegenerating(player, false)
			continue
		end

		setRegenerating(player, true)
		local newHp = math.min(hp + maxHp * CombatConfig.regenPercentPerSecond * dt, maxHp)
		PlayerState.setHp(player, newHp)
		player:SetAttribute("Hp", newHp)
	end
end)
