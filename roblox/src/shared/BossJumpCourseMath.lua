-- BR1-2 점프맵 계산(순수 함수 - 서버 BossJumpCourse · 검증 · 하네스가 같은 식을 쓴다). 데이터 = BossJumpMapData.
--   layout(course)        코스 로컬 좌표(시작 발판 = 원점 · 첫 방향 +X)의 발판 목록 { position(윗면 가운데), width, checkpoint, crystal, index }
--   maxGap(rise, combo)   높이 차 rise에 내려앉을 때 그 기술 조합으로 건너는 최대 수평 간격(끝 → 끝, 걷기 walkSpeedStuds) - movement-metrics v2 §2 식
--   classify(step)        그 단계를 건너는 가장 약한 기술 조합(safety 안) - 없으면 nil
--   validate(course)      완주 가능 · 어려움 구성 검사 → ok, 문제 목록, 단계별 조합
--   place(course, ...)    아레나 중심 기준 자리 · 방향을 골라 월드 발판 목록(아레나 안 · 보스 자리 밖이 되는 첫 방향)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BossJumpMapData = require(ReplicatedStorage.Shared.data.BossJumpMapData)
local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)

local BossJumpCourseMath = {}

-- 약한 것부터(공중 점프 수, 대시)
BossJumpCourseMath.COMBOS = {
	{ label = "1단", airJumps = 0, dash = false },
	{ label = "공중 1", airJumps = 1, dash = false },
	{ label = "공중 2", airJumps = 2, dash = false },
	{ label = "1단 + 대시", airJumps = 0, dash = true },
	{ label = "공중 1 + 대시", airJumps = 1, dash = true },
	{ label = "공중 2 + 대시", airJumps = 2, dash = true },
}

local gapCache = {}
function BossJumpCourseMath.maxGap(rise, combo)
	local key = ("%.2f|%d|%s"):format(rise, combo.airJumps, tostring(combo.dash))
	if gapCache[key] then
		return gapCache[key]
	end
	local dashSeconds = combo.dash and DashConfig.durationSeconds or nil
	local air = JumpMath.maxAirSeconds(nil, combo.airJumps, dashSeconds, rise, nil, 16)
	local gap = -1
	if air and air > 0 then
		gap = BossJumpMapData.walkSpeedStuds * (air - (dashSeconds or 0)) + (combo.dash and DashConfig.rangeStuds or 0)
	end
	gapCache[key] = gap
	return gap
end

function BossJumpCourseMath.classify(step)
	for _, combo in ipairs(BossJumpCourseMath.COMBOS) do
		local limit = BossJumpCourseMath.maxGap(step.rise, combo) * BossJumpMapData.safety
		if step.gap <= limit then
			return combo, limit
		end
	end
	return nil, nil
end

function BossJumpCourseMath.layout(course)
	local list = {}
	local heading = 0
	local position = Vector3.new(0, 0, 0)
	local prevWidth = 0
	for index, step in ipairs(course.steps) do
		heading += math.rad(step.turnDeg or 0)
		local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
		local advance = index == 1 and 0 or (prevWidth / 2 + step.gap + step.width / 2)
		position = position + dir * advance + Vector3.new(0, step.rise, 0)
		table.insert(list, { index = index, position = position, width = step.width, checkpoint = step.checkpoint == true, crystal = step.crystal == true })
		prevWidth = step.width
	end
	return list
end

function BossJumpCourseMath.validate(course)
	local problems, combos = {}, {}
	local hard, lastDash = 0, -math.huge
	for index, step in ipairs(course.steps) do
		if index > 1 then
			local combo = BossJumpCourseMath.classify(step)
			combos[index] = combo
			if not combo then
				table.insert(problems, ("%s %d단계 못 건넘(간격 %.0f · 높이 %.0f)"):format(course.name, index, step.gap, step.rise))
			else
				if combo.airJumps >= 2 or combo.dash then
					hard += 1
				end
				if combo.dash then
					if index - lastDash < BossJumpMapData.dashSpacingSteps then
						table.insert(problems, ("%s %d단계 대시가 너무 촘촘(앞 대시 %d단계)"):format(course.name, index, lastDash))
					end
					lastDash = index
				end
			end
		end
		if step.width < BossJumpMapData.minWidth then
			table.insert(problems, ("%s %d단계 발판 %.1f < %.1f"):format(course.name, index, step.width, BossJumpMapData.minWidth))
		end
	end
	if hard < BossJumpMapData.minHardSteps then
		table.insert(problems, ("%s 어려운 단계 %d < %d"):format(course.name, hard, BossJumpMapData.minHardSteps))
	end
	local last = course.steps[#course.steps]
	if not (last and last.crystal) then
		table.insert(problems, course.name .. " 마지막 발판에 수정이 없다")
	end
	return #problems == 0, problems, combos, hard
end

-- 코스를 아레나에 놓는다: 시작 발판 = 중심에서 siteAngle 방위 siteRadiusStuds · 첫 방향은 12가지(30°) 중 모든 발판이 아레나 안(반경 − wallMargin − 폭) · 보스 자리(centerClear) 밖인 첫 것.
-- 반환: 월드 발판 목록(position = 중심 + 회전된 로컬 + 바닥 높이) 또는 nil.
function BossJumpCourseMath.place(course, siteAngleRad, center, floorY, arenaRadius)
	local localList = BossJumpCourseMath.layout(course)
	local site = Vector3.new(math.cos(siteAngleRad), 0, math.sin(siteAngleRad)) * BossJumpMapData.siteRadiusStuds
	for k = 0, 11 do
		local rot = siteAngleRad + math.rad(90 + 30 * k)
		local c, s = math.cos(rot), math.sin(rot)
		local ok, world = true, {}
		for _, p in ipairs(localList) do
			local x = site.X + p.position.X * c - p.position.Z * s
			local z = site.Z + p.position.X * s + p.position.Z * c
			local r = math.sqrt(x * x + z * z)
			if r > arenaRadius - BossJumpMapData.wallMarginStuds - p.width or r < BossJumpMapData.centerClearStuds then
				ok = false
				break
			end
			table.insert(world, { index = p.index, position = Vector3.new(center.X + x, floorY + p.position.Y, center.Z + z), width = p.width, checkpoint = p.checkpoint, crystal = p.crystal })
		end
		if ok then
			return world, k
		end
	end
	return nil
end

return BossJumpCourseMath
