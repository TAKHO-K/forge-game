-- BOSS-NIGHT-2 3 발생 지점(사용자: 파동 · 투사체가 보스 몸 중심이 아니라 실제로 땅에 닿는 · 쏘는 부위에서): data/BossOriginData(오프라인 FK - 접촉 프레임) → 월드 자리.
--   point(model, data, skillId, bossPos, aimAt, floorY) → 자리(Vector3) · 표 항목(없으면 nil = 몸 중심 그대로 - 예외 스킬)
--   ground = 그 부위 아래 바닥(y = floorY) · launch = 부위 높이(floorY + y × 크기). 방향 = 보스 → 대상(클라 보스도 서 있으면 대상을 본다) · 크기 = sizeScale × rig.scale(크기가 바뀌어도 자동).
--   폼 = 체력 50% 이하면 after(2폼 세트가 있는 보스) - 클라 겉모습 변신과 같은 기준.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.data.BossOriginData)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)

local BossOrigin = {}

function BossOrigin.entry(rigKey, skillId)
	local t = rigKey and Data[rigKey]
	return t and t[skillId] or nil
end

-- sideIndex(선택 · BOSS-NIGHT-3 1-④): 표에 sides가 있으면 그 부위(1 = 첫 부위 · 번갈아)의 자리 - 매머드 상아 쏘기 = 1발 왼 상아 · 2발 오른 상아
function BossOrigin.point(rigKey, sizeScale, hpRatio, skillId, bossPos, aimAt, floorY, sideIndex)
	local e = BossOrigin.entry(rigKey, skillId)
	local rig = rigKey and BossRigSpec.rigs[rigKey]
	if not (e and rig) then
		return nil
	end
	local src = e
	if sideIndex and e.sides and #e.sides > 0 then
		src = e.sides[(sideIndex - 1) % #e.sides + 1]
	end
	local o = ((hpRatio or 1) <= 0.5 and src.after) or src.before or src.after
	if not o then
		return nil
	end
	local k = (sizeScale or 1) * (rig.scale or 1)
	local flat = aimAt and Vector3.new(aimAt.X - bossPos.X, 0, aimAt.Z - bossPos.Z) or Vector3.zero
	local face = flat.Magnitude > 1e-3 and CFrame.lookAt(Vector3.zero, flat) or CFrame.identity
	local off = face:VectorToWorldSpace(Vector3.new(o[1], 0, o[3]) * k)
	local y = e.kind == "ground" and floorY or (floorY + math.max(o[2], 0.5) * k)
	return Vector3.new(bossPos.X + off.X, y, bossPos.Z + off.Z), e
end

return BossOrigin
