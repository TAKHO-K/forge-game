-- SEC-FIX-1 5: "이 공격이 이 대상에 들어가도 되는 자리인가" 서버 판정 한 곳(평타 · 스킬 · 덫 · 궁극기가 같이 쓴다).
--   잡몹 = 공격자 위치가 그 몹의 구역 안(ZoneBounds - 옛 계약 그대로) · 보스 = 그 보스전(encounter) 멤버만(옛 = zoneKey가 없어 항상 통과 → 아레나 벽 너머 화살비 · 덫이 맞았다)
--   조준점(덫 · 화살비) = 공격자와 같은 구역 · 아레나여야 한다(옛 = 조준점 기준 필터라 담장 밖에서 안쪽에 깔면 안전 사냥 - AUDIT1 #17 · #18).
--   벽 판정은 레이캐스트 대신 구역 · 아레나 경계로 한다(지형 · 소품 오탐 없음 · 하네스로 재현 가능).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ArenaShape = require(ReplicatedStorage.Shared.ArenaShape)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local MonsterState = require(script.Parent.MonsterState)

local AttackZone = {}

-- 공격자(attackerPosition)가 model을 때려도 되나
function AttackZone.canHit(player, attackerPosition, model)
	local data = MonsterState.getData(model)
	if data and data.isBoss then
		local encounter = require(script.Parent.BossEncounter).getEncounterByModel(model)
		if encounter then
			return table.find(encounter.members, player) ~= nil
		end
		return true -- 보스전 밖 보스(전시 · 검증 스탠드인) = 옛 계약 그대로
	end
	return ZoneBounds.isInside(attackerPosition, MonsterState.getZoneKey(model))
end

-- 두 점이 같은 구역 · 아레나 묶음에 있나(모양이 있는 구역마다 "안/밖"이 같아야 함 - 둘 다 어느 구역에도 없는 들판도 같음으로 친다)
function AttackZone.sameArea(a, b)
	for _, zone in pairs(WorldConfig.zones) do
		if zone.center and (zone.radius or zone.halfSize) then
			if ArenaShape.contains(zone, a) ~= ArenaShape.contains(zone, b) then
				return false
			end
		end
	end
	return true
end

-- 후보 중 공격자가 때릴 수 있는 것만
function AttackZone.filter(player, attackerPosition, candidates)
	local out = {}
	for _, model in ipairs(candidates) do
		if AttackZone.canHit(player, attackerPosition, model) then
			table.insert(out, model)
		end
	end
	return out
end

return AttackZone
