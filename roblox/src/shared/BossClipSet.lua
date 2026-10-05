-- BOSS-FRAMEWORK 2 동작 세트 묶기 · 빠짐 검사(순수 함수 - 서버 · 클라 · 하네스 공용). 데이터 = shared/data/BossClipSetData.
--   get(rigKey)      - 묶은 세트(동작 = 히트스톱을 BossFrameworkData.hitstop 범위로 맞춘 사본 · 빌린 plan 동작도 사본) 또는 nil(옛 몸)
--   clip(set, name)  - 이름 → 동작(세트 것 → plan 것) · 출처("own" | "borrowed")
--   coverage(rigKey) - 빠짐 검사: 세트마다 필수 동작 · BossData 스킬표 전부 · 변신 · 번쩍 부위 · 소리 자리 · 타격 정렬(접촉 = 판정 시각). 반환 ok, rows
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.BossClipSetData)
local Frame = require(ReplicatedStorage.Shared.data.BossFrameworkData)
local MotionData = require(ReplicatedStorage.Shared.data.BossMotionData)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)

local BossClipSet = {}

local GAITS = { biped = true, knuckle = true, quad = true, serpent = true, hover = true, hexapod = true }
BossClipSet.gaits = GAITS

local function clampHitstop(clip, weight)
	local c = table.clone(clip)
	local h = (clip.hitstop or 0) * weight
	if h > 0 and clip.post and #clip.post > 0 then
		local H = Frame.hitstop
		c.hitstop = math.clamp(h, H.min, H.max) / weight
		c.hitstopFrom = clip.hitstop
	end
	return c
end

local cache = {}
function BossClipSet.get(rigKey)
	if cache[rigKey] ~= nil then
		return cache[rigKey] or nil
	end
	local raw = Data[rigKey]
	local rig = BossRigSpec.rigs[rigKey]
	if not raw or not rig then
		cache[rigKey] = false
		return nil
	end
	local weight = rig.weight or 1
	local plan = MotionData[raw.plan or "biped"] or MotionData.biped
	local set = table.clone(raw)
	set.key, set.rig, set.planData, set.clips, set.sources = rigKey, rig, plan, {}, {}
	for name, clip in pairs(raw.clips or {}) do
		set.clips[name] = clampHitstop(clip, weight)
		set.sources[name] = "own"
	end
	-- 세트가 쓰는 plan 동작(빌림)도 같은 범위로 맞춘 사본을 둔다
	local function borrow(name)
		if type(name) == "string" and not set.clips[name] and plan.clips[name] then
			set.clips[name] = clampHitstop(plan.clips[name], weight)
			set.sources[name] = "borrowed"
		end
	end
	for _, form in pairs(raw.forms) do
		for _, name in pairs(form.skills or {}) do
			borrow(name)
		end
		borrow(form.env)
		borrow(form.throw)
		for _, name in pairs(form.motions or {}) do
			borrow(name)
		end
	end
	for _, name in ipairs({ "grab_tele", "grab_reach", "grab_hold", "grab_snatch", "hopSlam", "quake_finish", "rest", "basic_R", "basic_L", "roar" }) do
		borrow(name)
	end
	cache[rigKey] = set
	return set
end

function BossClipSet.clip(set, name)
	if not name then
		return nil
	end
	local c = set.clips[name] or set.planData.clips[name]
	return c, set.sources[name] or (c and "borrowed") or nil
end

-- 세트 묶음의 동작 이름 하나 풀기(검사용): "gait" · "plan:<키>" · "@grab" · 동작 이름
local function resolveMotion(set, form, name)
	if name == "gait" then
		return GAITS[form.gait] == true, "gait:" .. tostring(form.gait)
	end
	if type(name) ~= "string" then
		return false, "없음"
	end
	local planKey = name:match("^plan:(.+)$")
	if planKey then
		return set.planData[planKey] ~= nil, "빌림(plan " .. planKey .. ")"
	end
	if name == "@grab" then
		local ok = true
		for _, n in ipairs({ "grab_tele", "grab_reach", "grab_hold", "grab_snatch" }) do
			ok = ok and BossClipSet.clip(set, n) ~= nil
		end
		return ok and BossClipSet.clip(set, form.throw) ~= nil, "잡기 흐름(" .. tostring(form.throw) .. ")"
	end
	local c, src = BossClipSet.clip(set, name)
	return c ~= nil, (src == "own" and "전용" or "빌림") .. " " .. name
end

-- 빠짐 검사. skills = BossData 인스턴스 스킬표(없으면 데이터 원본) · sounds = BossSoundData(선택)
function BossClipSet.coverage(rigKey, skills, sounds, contactTime)
	local rows, ok = {}, true
	local function row(good, form, key, what)
		ok = ok and good
		table.insert(rows, { ok = good, form = form, key = key, what = what })
	end
	local set = BossClipSet.get(rigKey)
	if not set then
		row(false, "-", "세트", "동작 세트 없음 " .. tostring(rigKey))
		return false, rows
	end
	local rig = set.rig
	local parts = {}
	for _, j in ipairs(rig.joints) do
		parts[j.part] = true
	end
	for _, formName in ipairs({ "before", "after" }) do
		local form = set.forms[formName]
		if not form then
			row(false, formName, "세트", "없음")
			continue
		end
		row(GAITS[form.gait] == true, formName, "보행", tostring(form.gait))
		for _, key in ipairs(Frame.requiredClips) do
			local good, what = resolveMotion(set, form, form.motions and form.motions[key])
			row(good, formName, key, what)
		end
		for id, skill in pairs(skills or {}) do
			local name = form.skills and form.skills[id]
			local good, what = resolveMotion(set, form, name)
			-- 타격 정렬: 전조가 있는 전용 · 빌린 동작 = 접촉 시각이 판정 시각(전조 끝)과 같아야 한다
			if good and contactTime and name ~= "@grab" then
				local c = BossClipSet.clip(set, name)
				local hit = skill.telegraphSeconds or 0
				if c and c.pre and #c.pre > 0 and c.post and c.align ~= false and hit > 0 then
					local d = contactTime(c, hit) - hit
					if math.abs(d) > 1e-6 then
						good, what = false, what .. (" · 접촉 − 판정 %.3f초"):format(d)
					end
				end
			end
			if good and name ~= "@grab" then
				local c = BossClipSet.clip(set, name)
				if c and (c.hitstop or 0) > 0 then
					local h = c.hitstop * (rig.weight or 1)
					if h < Frame.hitstop.min - 1e-6 or h > Frame.hitstop.max + 1e-6 then
						good, what = false, what .. (" · 타격 정지 %.3f"):format(h)
					end
				end
			end
			row(good, formName, "스킬 " .. id, what)
		end
	end
	-- 변신
	local T = set.transform
	local tc = T and BossClipSet.clip(set, T.clip)
	row(tc ~= nil and T.hit ~= nil and T.switchAt ~= nil and T.switchAt <= (T.seconds or math.huge), "변신", "transform", T and tostring(T.clip) or "없음")
	-- 번쩍(때리는 부위) - 스킬마다 · 리그에 있는 부위
	for id in pairs(skills or {}) do
		local list = set.flash and set.flash[id]
		local good = list ~= nil and #list > 0
		for _, p in ipairs(list or {}) do
			good = good and parts[p] == true
		end
		row(good, "번쩍", id, list and table.concat(list, " · ") or "없음")
	end
	-- 소리 자리(음원은 비어 있어도 됨 - 자리만)
	if sounds then
		local s = sounds.bosses and sounds.bosses[rig.bossId]
		row(s ~= nil and s.roar ~= nil and s.step ~= nil and s.transform ~= nil, "소리", "포효 · 걷기 · 변신", s and "자리 있음" or "없음")
		for id in pairs(skills or {}) do
			row(s ~= nil and s.skills ~= nil and s.skills[id] ~= nil, "소리", id, (s and s.skills and s.skills[id]) and "자리 있음" or "없음")
		end
	end
	return ok, rows
end

return BossClipSet
