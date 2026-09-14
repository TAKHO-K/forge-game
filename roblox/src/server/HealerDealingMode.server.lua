-- 힐러 딜링모드(E, 20-6 [6]) 지속 체력 소모 - PlayerRegen.server.lua(회복)와 대칭되는 자리.
-- "dealingMode" 버프(BuffState, SkillServer.server.lua가 토글)가 켜져 있는 플레이어만 매
-- Heartbeat 최대체력의 SkillData.healer.E.drainPercentPerSecond만큼 깎는다. 평타 배율
-- 적용은 여기서 하지 않는다(AttackServer.server.lua가 attackMultiplier를 직접 읽는다) -
-- 이 스크립트는 소모 한 가지만 책임진다.
--
-- 19-1/PlayerRegen.server.lua가 이미 확정한 규칙 그대로 - 소모 중에도 "전투 행위" 취급해
-- setLastCombatActionAt을 계속 찍는다. 안 찍으면 딜링모드를 켠 채로 5초 넘게 가만히 있을 때
-- 자동회복이 동시에 돌아 소모를 상쇄해버린다(PlayerRegen.server.lua 주석이 명시적으로 경고한
-- 바로 그 문제 - "자동회복이 소모를 압도해서 딜링모드가 사실상 상시 가동이었다").
--
-- 체력이 0에 닿으면 다른 사망 경로(MonsterAI.server.lua의 applyHitToPlayer)와 같은 신호
-- (Humanoid.Health=0)로 리스폰을 트리거한다 - 자원을 다 쓰면 죽을 수 있다는 게 이 스킬의
-- "변칙 딜러" 정체성이다(PRD 4.1-1).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local BuffState = require(script.Parent.BuffState)
local PlayerState = require(script.Parent.PlayerState)

RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local buff = BuffState.get(player, "dealingMode")
		if not buff then
			continue
		end

		local def = SkillData.healer and SkillData.healer.E
		if not def then
			continue -- 방어적 가드 - 이 버프는 힐러만 걸 수 있으므로 실제로는 항상 있다.
		end

		local maxHp = PlayerState.getMaxHp(player)
		local hp = PlayerState.getHp(player)
		if not maxHp or not hp then
			continue -- 캐릭터 로드 전/퇴장 중 - 다음 틱에 다시 시도.
		end

		PlayerState.setLastCombatActionAt(player, os.clock())

		local newHp = hp - maxHp * def.drainPercentPerSecond * dt
		if newHp <= 0 then
			newHp = 0
			BuffState.clear(player, "dealingMode")
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end
		PlayerState.setHp(player, newHp)
		player:SetAttribute("Hp", newHp)
	end
end)

print("[forge-game] HealerDealingMode 로드됨 - 딜링모드 체력 소모 루프 활성")
