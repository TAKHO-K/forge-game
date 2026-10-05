-- BOSS-FRAMEWORK 공용(서버 · 클라): 어느 몸(리그 키)이 뜨는가 + 리그 검사(관절 ≤ 60 · 판정 사본 부위 · 부피 ±20%).
--   스위치 = shared/data/BossFrameworkData(live = 실전 · studioTrial = Studio + workspace BossFrameworkTrial).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage.Shared.data.BossFrameworkData)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local BossSkeleton = require(ReplicatedStorage.Shared.BossSkeleton)

local BossFramework = {}

-- 보스 id → 이번에 지을 리그 키(nil = 옛 몸)
function BossFramework.variantFor(bossId)
	local v = Data.live[bossId]
	if not v and RunService:IsStudio() and workspace:GetAttribute(Data.trialAttribute) == true then
		v = Data.studioTrial[bossId]
	end
	return v
end

function BossFramework.rigKeyFor(bossId)
	local v = bossId and BossFramework.variantFor(bossId)
	local key = v and (bossId .. "_" .. v)
	return (key and BossRigSpec.rigs[key]) and key or nil
end

-- GUARDIAN-V2 몸 가장자리 증가분(stud): 새 몸 가장자리 반폭(edgeHalfWidth × S × scale) − 옛 몸 가장자리 반폭(baseEdgeHalfWidth × S). S = 옛 몸 배율(visualScale).
--   보스 공격 반경(몸 가장자리 기준 장치 - BossFrameworkData.bodyEdge) · 플레이어 공격 도달(BodyRadius)이 같은 값을 더한다. 새 몸이 아니면 0.
function BossFramework.edgeGrowth(rig, S)
	if not (rig and rig.edgeHalfWidth and rig.baseEdgeHalfWidth) then
		return 0
	end
	return math.max(0, rig.edgeHalfWidth * S * (rig.scale or 1) - rig.baseEdgeHalfWidth * S)
end

-- GUARDIAN-V2 몸 가장자리 기준 장치: 인스턴스 데이터 사본에 반경 + 늘어난 몸 반지름(Data.bodyEdge[보스] - 없으면 그대로 돌려준다 · 원본 무변경).
--   rigKey = 이번에 뜨는 새 몸(rigKeyFor) · walk = 플레이어 걷기 속도(전조 맞춤 다시 - 서 있는 거리도 같이 늘어 보통 0초) · 반환 data, edge(stud), fitted({ [id] = 늘린 초 })
function BossFramework.applyBodyEdge(data, rigKey, walk)
	local cfg = data and Data.bodyEdge[data.id]
	local rig = rigKey and BossRigSpec.rigs[rigKey]
	local edge = (cfg and rig) and BossFramework.edgeGrowth(rig, data.sizeScale or 1) or 0
	if edge <= 0 then
		return data, 0, {}
	end
	local out = table.clone(data)
	out.bodyEdgeStuds = edge
	if cfg.innerSafe and out.innerSafeRadiusStuds then
		out.innerSafeRadiusStuds += edge
	end
	if cfg.chaseStop and out.chaseStopDistanceStuds then
		out.chaseStopDistanceStuds += edge
	end
	local skills, fitted = table.clone(out.skills or {}), {}
	for id in pairs(cfg.skills or {}) do
		local s = skills[id]
		if s then
			s = table.clone(s)
			for _, k in ipairs({ "radiusStuds", "innerRadiusStuds", "barrierRadiusStuds" }) do
				if type(s[k]) == "number" and s[k] > 0 then
					s[k] += edge
				end
			end
			if s.volleyShots then
				local list = {}
				for i, v in ipairs(s.volleyShots) do
					list[i] = table.clone(v)
					if v.radiusStuds then
						list[i].radiusStuds = v.radiusStuds + edge
					end
				end
				s.volleyShots = list
			end
			if s.conditions then
				local list = {}
				for i, c in ipairs(s.conditions) do
					list[i] = table.clone(c)
					if c.type == "targetWithin" and c.studs then
						list[i].studs = c.studs + edge
					end
				end
				s.conditions = list
			end
			if walk then
				local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
				local _, added = BossSkillMath.fitTelegraphs(s, 8 + edge, walk) -- 서 있는 거리(추격 정지 8)도 같이 늘었다
				if added > 0 then
					fitted[id] = added
				end
			end
			skills[id] = s
		end
	end
	out.skills = skills
	return out, edge, fitted
end

-- 카메라 줌 배율(새 몸 rig.cameraZoomScale - 모델 BossRigKey)
function BossFramework.cameraZoomScaleOf(model)
	local key = model and model:GetAttribute("BossRigKey")
	local rig = key and BossRigSpec.rigs[key]
	return rig and rig.cameraZoomScale or 1
end

-- 리그 검사: 반환 ok, lines(사람이 읽는 줄), stats
function BossFramework.checkRig(key)
	local rig = BossRigSpec.rigs[key]
	local lines, ok = {}, true
	if not rig then
		return false, { ("리그 없음 %s X"):format(tostring(key)) }, nil
	end
	local B = Data.budget
	local n = BossSkeleton.jointCount(rig)
	local function row(good, text)
		ok = ok and good
		table.insert(lines, text .. (good and " O" or " X"))
	end
	row(n <= B.joints, ("관절 %d ≤ %d"):format(n, B.joints))
	local vol, names = BossSkeleton.queryVolume(rig)
	local hasBody, hasHead = table.find(names, "Body") ~= nil, table.find(names, "Head") ~= nil
	row(hasBody and hasHead and #names <= B.queryParts, ("판정 사본 %s(Body · Head 필수 · ≤ %d)"):format(table.concat(names, " · "), B.queryParts))
	local old = rig.bossId and BossRigSpec.rigs[rig.bossId]
	local ratio = nil
	if old then
		local oldVol = BossSkeleton.queryVolume(old)
		ratio = vol / math.max(oldVol, 1e-6)
		row(math.abs(ratio - 1) <= B.queryVolumeTolerance + 1e-6, ("판정 사본 부피 %.2f → %.2f(× %.2f · 허용 ±%d%%)"):format(oldVol, vol, ratio, B.queryVolumeTolerance * 100))
	end
	-- 이름 겹침 · 부모 없음(지을 때 빠지는 관절)
	local parts, dup, orphan = { HumanoidRootPart = true }, {}, {}
	for _, j in ipairs(rig.joints) do
		if parts[j.part] then
			table.insert(dup, j.part)
		end
		if not parts[j.parent] then
			table.insert(orphan, j.name)
		end
		parts[j.part] = true
	end
	row(#dup == 0 and #orphan == 0, ("부위 이름 겹침 %d · 부모 없는 관절 %d%s"):format(#dup, #orphan, (#dup + #orphan > 0) and (" (" .. table.concat(dup, ",") .. " / " .. table.concat(orphan, ",") .. ")") or ""))
	for _, c in ipairs(rig.chains or {}) do
		if c.kind and not Data.springs[c.kind] then
			row(false, ("사슬 종류 %s 없음"):format(tostring(c.kind)))
		end
		for _, name in ipairs(c) do
			if not BossSkeleton.find(rig.joints, name) then
				row(false, ("사슬 관절 %s 없음"):format(name))
			end
		end
	end
	return ok, lines, { joints = n, queryVolume = vol, queryRatio = ratio, queryParts = names }
end

return BossFramework
