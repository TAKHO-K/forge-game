-- 위치 하나가 특정 tier 구역 안에 있는지 판정하는 단일 출처(19-4). MonsterAI.server.lua의
-- 리쉬 판정(구역 이탈 시 추격 포기)과 AttackServer.server.lua의 "구역 밖에서는 공격이 안
-- 들어간다" 판정이 같은 식을 쓴다 - 두 곳에 따로 복사해 두면 나중에 구역 모양이 바뀔 때
-- 하나만 고치고 잊어버릴 위험이 있다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ArenaShape = require(ReplicatedStorage.Shared.ArenaShape) -- P3a C: 보스 아레나는 원이다

local ZoneBounds = {}

-- zoneKey가 없으면(보스 등 구역 밖 개인 인스턴스) 항상 true - 그 몬스터는 이 판정 대상이
-- 아니라는 뜻이다(MonsterAI.server.lua의 기존 isOutsideZoneBounds와 같은 계약).
function ZoneBounds.isInside(position, zoneKey)
	local zone = zoneKey and WorldConfig.zones[zoneKey]
	if not zone then
		return true
	end
	return ArenaShape.contains(zone, position)
end

return ZoneBounds
