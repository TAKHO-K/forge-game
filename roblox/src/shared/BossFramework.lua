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
