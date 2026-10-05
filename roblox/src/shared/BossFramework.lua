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
	-- 새 몸 밸런스(BossSim 재실행으로 정한 값 - 새 몸이 뜰 때만 · BossData 원본 무변경): 체력 × hpScale · 공격력(스킬 · 평타 피해) × damageScale
	if cfg.hpScale and out.hp then
		out.hp *= cfg.hpScale
		out.bodyEdgeHpScale = cfg.hpScale
	end
	local dmg = cfg.damageScale
	if dmg and out.basicAttackDamageMultiplier then -- 피해 배율(감소식 뒤에 곱하는 값 - 공격력에 곱하면 비선형) = 평타 · 스킬 multiplier 전부
		out.basicAttackDamageMultiplier *= dmg
		out.bodyEdgeDamageScale = dmg
	end
	local skills, fitted = table.clone(out.skills or {}), {}
	if dmg then
		local function scaled(t)
			local c = table.clone(t)
			for k, v in pairs(c) do
				if k == "multiplier" and type(v) == "number" then
					c[k] = v * dmg
				elseif type(v) == "table" and k ~= "conditions" then
					c[k] = scaled(v)
				end
			end
			return c
		end
		for id, s in pairs(skills) do
			skills[id] = scaled(s)
		end
	end
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

-- GUARDIAN-V3(BossFrameworkData.v3[보스] - 새 몸이 뜰 때만 · applyBodyEdge 뒤): 인스턴스 사본에 바닥 표시 끔 · 예비 동작 연장 · 돌진 폭 = 몸 폭 · 이속 · 질주 ·
--   지진파 그림 · 반응 스킬(바나나 · 도약 - 몸 가장자리 기준 반경) · 첫 보스 도움 설정을 얹는다. 반환 data(사본 - 설정이 없으면 그대로).
function BossFramework.applyV3(data, rigKey)
	local cfg = data and Data.v3[data.id]
	local rig = rigKey and BossRigSpec.rigs[rigKey]
	if not (cfg and rig) then
		return data
	end
	local S = data.sizeScale or 1
	local bodyHalf = rig.edgeHalfWidth and rig.edgeHalfWidth * S * (rig.scale or 1) or 0 -- 새 몸 가장자리 반폭(stud)
	local out = table.clone(data)
	out.v3 = cfg
	out.bodyHalfWidthStuds = bodyHalf
	local skills = table.clone(out.skills or {})
	for id, s in pairs(skills) do
		local hide = cfg.hideFloor[id]
		local longer = cfg.windup.skills[id]
		if hide or longer or (id == "charge" and cfg.chargeHalfWidth == "body") or (s.primitive == "ring" and cfg.ringStyle) then
			s = table.clone(s)
			if hide then
				s.noFloor = true
			end
			if longer then
				s.telegraphSeconds += cfg.windup.seconds
			end
			if id == "charge" and cfg.chargeHalfWidth == "body" then
				s.pathHalfWidthStuds = bodyHalf
				s.markStyle = "crack"
			end
			if s.primitive == "ring" then
				s.ringStyle = cfg.ringStyle
			end
			skills[id] = s
		end
	end
	local reactive = {}
	for _, id in ipairs(cfg.reactiveOrder or {}) do
		local s = cfg.skills[id] and table.clone(cfg.skills[id])
		if s then
			if s.radiusFromEdge then
				s.radiusStuds += bodyHalf
			end
			if s.landShortFromEdge then
				s.landShortStuds = bodyHalf
			end
			-- 새 몸 밸런스의 피해 계수(몸 가장자리 장치 damageScale)는 공격력 배율(multiplier)에만 - 최대 체력 비율(바나나 7%)은 지시 값 그대로
			if s.damage and s.damage.multiplier and out.bodyEdgeDamageScale then
				s.damage = table.clone(s.damage)
				s.damage.multiplier *= out.bodyEdgeDamageScale
			end
			skills[id] = s
			table.insert(reactive, id)
		end
	end
	out.skills = skills
	out.reactiveOrder = reactive
	if out.moveSpeedStuds and cfg.move then
		out.moveSpeedStuds *= cfg.move.speedScale
		out.sprintBeyondStuds = cfg.move.sprintBeyondStuds
		out.sprintMultiplier = cfg.move.sprintMultiplier
	end
	out.basicNoFloor = cfg.hideFloor.basic == true
	out.innerRingHidden = cfg.hideFloor.innerRing == true
	out.basicWindupExtraSeconds = cfg.windup.basic and cfg.windup.seconds or nil
	out.firstAssist = cfg.firstAssist
	return out
end

-- 첫 보스 도움 배율(실패 횟수 → 받는 피해 배율 · 첫 클리어 뒤 1): BossFrameworkData.v3[보스].firstAssist
function BossFramework.assistMultiplier(assist, fails, cleared)
	if not assist or cleared then
		return 1
	end
	return 1 - math.min((fails or 0) * assist.perFail, assist.max)
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
