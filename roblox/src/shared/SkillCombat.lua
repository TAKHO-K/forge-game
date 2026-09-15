-- 스킬 판정 유형 2종의 순수 기하 함수(20-2a) - "선분 판정"(관통돌진 - 시작점~끝점 경로에
-- 닿는 전원)과 "원형 판정"(회전베기 - 시전자 중심 반경 안 전원). AimPicker.lua(단일 대상,
-- 방향 기준 최근접 픽)와는 목적이 다르다 - 이건 "몇 명이든 조건에 맞으면 전부" 돌려준다.
-- 거리는 XZ 평면(수평)으로 보고, 높이차는 Reach.sameLayer 상한(8)으로만 자른다(22-4 - 지형에
-- 높낮이가 생겼다. 선분 판정은 시전 경로 위 가장 가까운 점의 Y, 원형 판정은 중심 Y 기준).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Reach = require(ReplicatedStorage.Shared.Reach)

local SkillCombat = {}

local function flat(vector3)
	return Vector3.new(vector3.X, 0, vector3.Z)
end

-- startPos~endPos 선분에서 radiusStuds 안에 들어오는 몬스터 전원(중복 없음 - 후보 목록
-- 자체가 몬스터 하나당 한 번씩만 나온다).
function SkillCombat.hitsOnSegment(startPos, endPos, radiusStuds, candidates)
	local segStart = flat(startPos)
	local segDelta = flat(endPos) - segStart
	local segLengthSq = segDelta:Dot(segDelta)

	local hits = {}
	for _, model in ipairs(candidates) do
		local root = model.PrimaryPart
		if root and model.Parent then
			local point = flat(root.Position)
			local t = 0
			if segLengthSq > 1e-6 then
				t = math.clamp((point - segStart):Dot(segDelta) / segLengthSq, 0, 1)
			end
			local closest = segStart + segDelta * t
			local pathY = startPos.Y + (endPos.Y - startPos.Y) * t
			if (point - closest).Magnitude <= radiusStuds
				and Reach.sameLayer(root.Position, Vector3.new(0, pathY, 0)) then
				table.insert(hits, model)
			end
		end
	end
	return hits
end

-- center 기준 radiusStuds 원 안에 들어오는 몬스터 전원.
function SkillCombat.hitsInCircle(center, radiusStuds, candidates)
	local flatCenter = flat(center)

	local hits = {}
	for _, model in ipairs(candidates) do
		local root = model.PrimaryPart
		if root and model.Parent then
			if (flat(root.Position) - flatCenter).Magnitude <= radiusStuds and Reach.sameLayer(root.Position, center) then
				table.insert(hits, model)
			end
		end
	end
	return hits
end

return SkillCombat
