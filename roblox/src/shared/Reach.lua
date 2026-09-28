-- 거리 판정의 단일 출처(22-4). "XZ 수평 거리 ≤ 사거리" AND "|ΔY| ≤ 높이차 상한"이 이 게임의
-- 모든 도달 판정이다 - 어그로·평타(MonsterAI), 조준(AimPicker), 스킬(SkillCombat·SkillServer),
-- 보스 패턴(BossPatterns), 줍기(ItemDropServer)가 전부 이 함수를 쓴다. 3D Magnitude를 쓰지
-- 않는 이유: 높이차만큼 사거리가 실질 축소돼 언덕 위 몬스터가 갑자기 안 맞고, 20-4에서
-- 절대값으로 고정한 격자 64 / 어그로 25.6 / 리쉬 38.4 사슬이 경사에서 어긋난다. 수평 거리는
-- 그 사슬을 그대로 보존하고, 높이는 별도 상한(TerrainConfig.heightToleranceStuds)으로만 자른다.
-- 클라이언트(AimTarget.lua)와 서버가 같은 판정을 봐야 "보이는 조준 대상 = 맞는 대상"이 유지된다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)

local Reach = {}

function Reach.horizontalDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- 같은 "층"인가. toleranceStuds를 안 주면 공통 상한(8).
function Reach.sameLayer(a, b, toleranceStuds)
	return math.abs(a.Y - b.Y) <= (toleranceStuds or TerrainConfig.heightToleranceStuds)
end

function Reach.within(a, b, rangeStuds, toleranceStuds)
	return Reach.horizontalDistance(a, b) <= rangeStuds and Reach.sameLayer(a, b, toleranceStuds)
end

-- Q1 리뷰: 큰 몸 몬스터(드래곤 - 모델 Attribute BodyRadius · 서버 MonsterSpawner가 종 hitbox에서 붙인다)는 루트가 몸 한가운데라
-- 공격 쪽 도달 판정(조준 · 평타 · 스킬 원 · 선 · 채널 틱 · 화살 경로)을 몸 반경만큼 넓힌다. 몬스터 → 플레이어 판정(몹 평타 · 어그로)은 그대로.
function Reach.bodyRadius(model)
	return (typeof(model) == "Instance" and model:GetAttribute("BodyRadius")) or 0
end

function Reach.withinModel(model, targetPosition, originPosition, rangeStuds, toleranceStuds)
	return Reach.within(targetPosition, originPosition, rangeStuds + Reach.bodyRadius(model), toleranceStuds)
end

return Reach
