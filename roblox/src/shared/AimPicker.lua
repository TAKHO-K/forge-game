-- 조준점 기준 대상 선정(16-7). 클라이언트(AimTarget.lua, 표시용)와 서버
-- (AttackServer.server.lua, 판정용)가 같은 함수를 써야 "화면에 보이는 조준 대상"과 "실제로
-- 맞는 대상"이 어긋나지 않는다.
--
-- 사거리 안 후보 중 조준 방향(원점->조준점)에 가장 가까운 것을 고른다. 화면 픽셀 클릭
-- 판정이 아니라 방향 기반이다 - 작은 몬스터를 정확히 클릭하기 어렵고, 탑다운 게임이라
-- 방향 기반이 더 자연스럽다. 방향과 맞는(dot>0) 후보가 하나도 없으면(뒤쪽만 있거나
-- aimPoint가 없으면) 사거리 안 최근접으로 대체한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Reach = require(ReplicatedStorage.Shared.Reach)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)

local AimPicker = {}

-- 22-4: 사거리는 XZ 수평 그대로, 높이차 상한(Reach.sameLayer)만 추가 - 절벽 위아래 몬스터는
-- 후보에서 빠진다. 클라(AimTarget)와 서버(AttackServer)가 같은 함수라 조준 표시도 같이 빠진다.
-- MV1: layerTolerance(선택) = 높이차 상한(공중 공격 - CombatConfig.airAttack · 없으면 공통 8).
function AimPicker.pick(originPosition, aimPoint, rangeStuds, candidates, layerTolerance)
	local direction = nil
	if aimPoint then
		local flat = Vector3.new(aimPoint.X - originPosition.X, 0, aimPoint.Z - originPosition.Z)
		if flat.Magnitude > 1e-3 then
			direction = flat.Unit
		end
	end

	local aligned, alignedScore = nil, math.huge
	local nearest, nearestDist = nil, math.huge

	for _, model in ipairs(candidates) do
		local root = model.PrimaryPart
		if root and model.Parent then
			local offset = root.Position - originPosition
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local dist = flat.Magnitude
			if dist <= rangeStuds and Reach.sameLayer(root.Position, originPosition, layerTolerance) then
				if dist < nearestDist then
					nearest, nearestDist = model, dist
				end
				if direction and dist > 1e-3 then
					local dot = flat.Unit:Dot(direction)
					if dot > 0 then
						local perp = dist * math.sqrt(math.max(1 - dot * dot, 0))
						if perp < alignedScore then
							aligned, alignedScore = model, perp
						end
					end
				end
			end
		end
	end

	return aligned or nearest
end

-- C3-4 원거리 = 클릭 지점으로 발사(마크 활처럼). 원점(쏘는 사람) → 조준점 직선(3D)을 사거리까지 = 화살 경로. 반환: 맞는 몹 목록(경로를 따라 가까운 순 - 관통이면 앞에서부터 여러 명), 경로 끝점.
--   경로 위 몹 = 몸 중심이 경로에서 CombatConfig.rangedAim.bodyRadiusStuds 안(선분 끝 = min(조준점까지, 사거리) + 같은 여유 - 조준점이 몸 표면이면 몸 중심이 조금 뒤다).
--   경로 위에 없으면 조준 보정 = 조준점에서 assistRadiusStuds 안 · 사거리 안 몹 중 조준점에 가장 가까운 1명(옛 "조준 방향에 가장 가까운 몹" 대체 - 자연 슬라임이 먼저 잡히던 문제).
--   조준점이 없거나 원점과 겹치면 fallbackDir(바라보는 방향) 쪽으로 사거리 끝까지. 클라(조준 표시)와 서버(판정)가 같은 함수.
function AimPicker.pickPath(originPosition, aimPoint, rangeStuds, candidates, fallbackDir, maxHits, assistExtra)
	local A = CombatConfig.rangedAim
	local offset = aimPoint and (aimPoint - originPosition) or nil
	local dir, length
	if offset and offset.Magnitude > 0.5 and offset.Magnitude == offset.Magnitude then
		dir = offset.Unit
		length = math.min(offset.Magnitude + A.bodyRadiusStuds, rangeStuds)
	else
		local f = fallbackDir and Vector3.new(fallbackDir.X, 0, fallbackDir.Z) or Vector3.new(0, 0, -1)
		dir = f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
		length = rangeStuds
	end
	local onPath = {}
	for _, model in ipairs(candidates) do
		local root = model.PrimaryPart
		if root and model.Parent then
			local rel = root.Position - originPosition
			local t = rel:Dot(dir)
			if t > 0 and t <= length then
				local perp = (rel - dir * t).Magnitude
				if perp <= A.bodyRadiusStuds then
					table.insert(onPath, { model = model, t = t })
				end
			end
		end
	end
	table.sort(onPath, function(a, b)
		return a.t < b.t
	end)
	local hits = {}
	for i = 1, math.min(#onPath, maxHits or 1) do
		hits[i] = onPath[i].model
	end
	if #hits == 0 and aimPoint then
		-- C4 파트 0: assistExtra(선택 - 서버만) = 몹마다 더 넓힐 반경(속도 × 지연) · 상한 assistMaxStuds.
		local best, bestDist = nil, math.huge
		for _, model in ipairs(candidates) do
			local root = model.PrimaryPart
			if root and model.Parent and (root.Position - originPosition).Magnitude <= rangeStuds then
				local d = (root.Position - aimPoint).Magnitude
				local allowed = assistExtra and math.min(A.assistRadiusStuds + assistExtra(model), A.assistMaxStuds) or A.assistRadiusStuds
				if d <= allowed and d <= bestDist then
					best, bestDist = model, d
				end
			end
		end
		hits[1] = best
	end
	return hits, originPosition + dir * math.min(length, rangeStuds)
end

return AimPicker
