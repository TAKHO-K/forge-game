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
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local PlayerState = require(script.Parent.PlayerState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local BossEncounter = require(script.Parent.BossEncounter)

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

		-- 26-2(PRD 20.67 [2] "재생 - 자동회복 회복량 ×(1+x)") - 힐러 치유(SkillServer
		-- castHeal)와 같은 배수(PlayerProfile.getHealingPowerMultiplier).
		local healingMultiplier = PlayerProfile.getHealingPowerMultiplier(player)
		-- 29-3(PRD 20.76 [3]): 보스전 중에는 기본 자동회복(배수의 1)이 빠지고 재생 옵션이 얹는 몫(x)만 남는다 - 재생은
		-- 독립된 회복이 아니라 자동회복의 배수라서, "옵션은 그대로 작동한다"는 곧 "옵션이 더해 주던 양은 그대로"다.
		-- 보스전인가는 BossEncounter의 encounter 하나만 본다(별도 플래그 없음 - 처치·전멸 리셋·이탈·퇴장 어느 경로로
		-- 끝나도 encounter가 사라지는 순간 자동회복이 돌아온다). 견습 보스전은 예외.
		local encounter = BossEncounter.getEncounter(player)
		if encounter and not encounter.isTutorial and not BossData.mechanics.bossFight.baseRegenEnabled then
			healingMultiplier -= 1
		end
		if healingMultiplier <= 0 then
			setRegenerating(player, false)
			continue
		end

		setRegenerating(player, true)
		local newHp = math.min(hp + maxHp * CombatConfig.regenPercentPerSecond * healingMultiplier * dt, maxHp)
		PlayerState.setHp(player, newHp)
		player:SetAttribute("Hp", newHp)
	end
end)
