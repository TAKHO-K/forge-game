-- 조준점 기준 대상 선정(16-7). 클라이언트(AimTarget.lua, 표시용)와 서버
-- (AttackServer.server.lua, 판정용)가 같은 함수를 써야 "화면에 보이는 조준 대상"과 "실제로
-- 맞는 대상"이 어긋나지 않는다.
--
-- 사거리 안 후보 중 조준 방향(원점->조준점)에 가장 가까운 것을 고른다. 화면 픽셀 클릭
-- 판정이 아니라 방향 기반이다 - 작은 몬스터를 정확히 클릭하기 어렵고, 탑다운 게임이라
-- 방향 기반이 더 자연스럽다. 방향과 맞는(dot>0) 후보가 하나도 없으면(뒤쪽만 있거나
-- aimPoint가 없으면) 사거리 안 최근접으로 대체한다.
local AimPicker = {}

function AimPicker.pick(originPosition, aimPoint, rangeStuds, candidates)
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
			if dist <= rangeStuds then
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

return AimPicker
