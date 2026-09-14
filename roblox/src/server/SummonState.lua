-- 소환체(그림자분신 등) 생명주기의 단일 관리 통로(20-6 [1] - BuffState.lua가 세운
-- "지속 상태를 한 곳에서만 관리한다" 패턴을 그대로 재사용한다. 버프는 숫자/문자열
-- config뿐이지만 소환체는 실제 Instance(Model)를 들고 있다는 점만 다르다 - 그래서 만료·
-- 정리 시점에 값을 지우는 대신 Model:Destroy()까지 이 모듈이 책임진다.
--
-- 서버가 유일한 소유자다(지시 [1] "소환체는 서버가 소유한다. 클라는 표시만 한다") -
-- Model은 SkillServer.server.lua가 만들어 Workspace에 Parent하면 자동으로 모든 클라에
-- 복제된다. 클라는 이 모듈을 아예 모른다.
--
-- 정리 규칙(지시 [1] "정리를 최우선으로 짜라"): 지속시간 만료 / 시전자 사망(재)스폰 /
-- 직업 변경 / 퇴장 4가지 전부 BuffState.clearAll과 똑같은 지점에서 SummonState.clearAll을
-- 부르면 끝나도록, 이 모듈이 PlayerAdded/CharacterAdded/PlayerRemoving을 자체적으로
-- 구독한다(호출부가 매번 훅을 새로 달 필요가 없다) - 직업 변경만 시점이 달라(캐릭터가
-- 리스폰하지 않는다) ClassServer.server.lua가 명시적으로 한 번 더 불러야 한다(BuffState.
-- clearAll이 이미 그 자리에서 그렇게 쓰이고 있다).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SummonState = {}

-- [Player][summonId] = { model, expiresAt(os.clock() 기준) }
local summons = {}

-- 같은 summonId로 다시 spawn하면 이전 것을 먼저 지운다(v1은 플레이어당 종류별 1개 -
-- 지시 [1]의 "소환→지속→소멸" 생명주기에 "동시에 여러 개"는 없다, 나중에 필요해지면
-- 여기 테이블 구조만 리스트로 바꾸면 된다).
function SummonState.spawn(player, summonId, model, durationSeconds)
	SummonState.despawn(player, summonId)
	summons[player] = summons[player] or {}
	summons[player][summonId] = {
		model = model,
		expiresAt = os.clock() + durationSeconds,
	}
end

-- 살아있는 소환체 레코드를 돌려준다(만료됐거나 Model이 이미 사라졌으면 정리하고 nil -
-- BuffState.get의 "읽을 때 만료를 감지한다" 원칙과 같다). MonsterAI.server.lua가 매
-- Heartbeat마다 이 함수로 "지금 이 플레이어의 분신이 살아있는가"를 묻는다.
function SummonState.get(player, summonId)
	local playerSummons = summons[player]
	local entry = playerSummons and playerSummons[summonId]
	if not entry then
		return nil
	end
	if os.clock() >= entry.expiresAt or not entry.model.Parent then
		SummonState.despawn(player, summonId)
		return nil
	end
	return entry
end

-- 위치 판정(몬스터가 쫓아갈 좌표)만 필요한 호출부를 위한 편의 함수 - PrimaryPart가 없는
-- 비정상 상태면 nil(안전하게 무시된다).
function SummonState.getPosition(player, summonId)
	local entry = SummonState.get(player, summonId)
	local primaryPart = entry and entry.model.PrimaryPart
	return primaryPart and primaryPart.Position
end

function SummonState.despawn(player, summonId)
	local playerSummons = summons[player]
	local entry = playerSummons and playerSummons[summonId]
	if not entry then
		return
	end
	playerSummons[summonId] = nil
	if entry.model.Parent then
		entry.model:Destroy()
	end
end

-- 사망(리스폰)·직업 변경·퇴장 전부 이 함수 하나로 정리한다(BuffState.clearAll과 같은 자리,
-- 같은 이유 - 19-4가 겪은 유령 상태 문제를 반복하지 않는다).
function SummonState.clearAll(player)
	local playerSummons = summons[player]
	if not playerSummons then
		return
	end
	for _, entry in pairs(playerSummons) do
		if entry.model.Parent then
			entry.model:Destroy()
		end
	end
	summons[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		SummonState.clearAll(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	SummonState.clearAll(player)
end)

-- 시간 기반 정리를 "누군가 읽을 때"에만 맡기면, 아무도 안 읽는 동안(예: 근처에 몬스터가
-- 없어 MonsterAI가 이 플레이어의 소환체를 한 번도 조회하지 않는 경우) 만료된 Model이 화면에
-- 계속 남는다 - BuffState.lua의 같은 문제·같은 해법(0.5초 스윕)을 그대로 재사용한다.
local SWEEP_INTERVAL_SECONDS = 0.5
local sweepAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	sweepAccumulator += dt
	if sweepAccumulator < SWEEP_INTERVAL_SECONDS then
		return
	end
	sweepAccumulator = 0

	for player, playerSummons in pairs(summons) do
		for summonId in pairs(playerSummons) do
			SummonState.get(player, summonId)
		end
	end
end)

return SummonState
