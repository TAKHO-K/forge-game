-- C1 기준 스테이지(잡몹 공유 HP 규칙) - 순수 함수. 서버 MonsterState가 잡몹 entry에 그대로 쓰고, 검증 (가) · 악용 시뮬레이터(server/MobShareSim)가 같은 함수를 부른다.
--
-- 옛 C안(19-4): hpRatio(0 ~ 1)를 공유하고 때린 사람마다 "자기 스테이지 HP"로 나눠 뺐다 → 낮은 스테이지에서 깎은 비율이 높은 스테이지 몹에 그대로 샜다.
-- 지금: 몬스터마다 참여자(최근 CombatConfig.participationWindowSeconds초 안에 타격 · 어그로 · 치유/보호) 목록을 두고,
--   기준 스테이지(refStage) = 참여자 중 가장 높은 스테이지. 모든 피해를 기준 HP로 환산한다(hpRatio = 기준 HP에 대한 남은 비율).
--   · 기준이 오를 때(더 높은 사람 참여): 깎인 절대량을 새 기준 HP로 다시 나눈다 → 남은 비율 = 1 − (1 − 비율) × k^(옛 − 새). 기여 비율도 같은 배율로 줄이고,
--     기존 참여자의 첫 타격 · 타격 수는 지금부터 다시 센다("현재 기준에서 쌓은 것만").
--   · 기준이 내려갈 때(최고 참여자 이탈 · 무참여): 비율 유지. 떠난 높은 사람은 자기 스테이지 > 기준이라 보상 자격을 잃고(eligible),
--     남은 사람은 같은 스테이지 동료가 그만큼 깎아 준 것과 같은 상황이라 이득 보는 사람이 없다.
--   · 스테이지를 바꾸면(purge): 그 사람의 참여 · 기여 · 첫 타격 기록을 지운다. 그 사람만 닿았던 몹(다른 참여자 · 다른 기여 없음)은 체력 가득으로 초기화.
--   · C1 후속(사용자 결정 + 리뷰): 새로 닿는 사람은 몹의 "잡는 사람"(8초 안에 때렸거나 도운 참여자 - activeAt) 전원과 스테이지 차가
--     CombatConfig.stealStageGap(10) 이하여야 참여한다. 최저보다 10 넘게 높거나(= 결정 문구) 최고보다 10 넘게 낮으면 막힌다(참여 안 됨 · 피해 0 · 기준 안 오름 -
--     파티 여부 무관). 10 이하면 기존 공유 규칙(스틸 가능 · 기준 상승 재정규화). 이미 참여 중인 사람은 나중에 온 사람 때문에 막히지 않는다(먼저 온 사람 우선).
--     쫓기기만 한 참여자(passive)는 기준(= 체력 · 몹이 주는 피해)에는 들지만 잡는 사람이 아니다 - 막힘 판정에서 빠진다(낮은 사람이 몹을 끌고 다니거나 잠수
--     파티원이 쫓기기만 해도 높은 사람이 막히는 방해 차단). 대신 몹은 기준 − 10보다 낮은 사람을 쫓지 않는다(MonsterAI - 초보 태그 즉사 · 1 탱커 차단). 목적 = 스침 손해 · 버스 · 낯선 사람 방해를 한 규칙으로. 그래서 기준 상승은
--     "참여자가 없는(비었거나 전부 떠난) 몹에 높은 사람이 새로 닿을 때"만 일어난다 - 남은 비율은 그때 재정규화된다.
--   · C1 마무리(사용자 결정): "스테이지 차 10"을 canShare(환생 같음 · 레벨 차 표 · 스테이지 차 10 AND)로 교체. 막힘 = 스틸 불가 + 더 높은 스테이지.
--     스틸 불가한 낮은 사람은 막히지 않고 같이 때린다(follower - 기여는 기준 HP로 환산돼 사실상 0 · 잡는 사람 집합(주인)은 안 바뀐다 - 대칭 판정의 목적 유지).
--   · C1 결정 5 보정(사용자 결정): 막힘 방향에 성장(환생 → 레벨 - compareGrowth)을 더함. 성장이 더 높거나 스테이지가 더 높으면 막힌다(blocksAgainst).
-- 절대 HP(k^(스테이지 − 1))는 만들지 않는다 - 배율은 k^(스테이지 차)만 쓴다(스테이지 34,230에서도 inf · nan 없음 - 하한은 0으로 접힌다).
-- entry 필드: hpRatio · refStage(nil = 아직 아무도) · participants([who] = 마지막 참여 시각) · partStage([who] = 기록을 쌓은 스테이지) ·
--   contributions([who] = 기준 HP에 대한 누적 비율) · firstHitAt · hitCounts. who = Player 또는 표(검증 스탠드인) - 키로만 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)

local MobShare = {}

function MobShare.fresh(entry)
	entry.hpRatio = 1.0
	entry.refStage = nil
	entry.participants = {}
	entry.partStage = {}
	entry.contributions = {}
	entry.firstHitAt = {}
	entry.hitCounts = {}
	entry.activeAt = {}
	return entry
end

-- 기준 fromStage → toStage로 옮길 때 비율에 곱하는 값 = H(from) ÷ H(to) = k^(from − to). 너무 작으면 0(깎인 양이 사실상 없다).
function MobShare.scale(fromStage, toStage)
	local value = InfiniteStageConfig.growthRate ^ (fromStage - toStage)
	if value ~= value or value == math.huge then
		return 0
	end
	return value
end

local function rise(entry, newRef, now)
	local old = entry.refStage
	entry.refStage = newRef
	if old == nil then
		return false
	end
	local f = MobShare.scale(old, newRef)
	entry.hpRatio = 1 - (1 - entry.hpRatio) * f
	for who, c in pairs(entry.contributions) do
		entry.contributions[who] = c * f
	end
	for who in pairs(entry.firstHitAt) do
		entry.firstHitAt[who] = now
		entry.hitCounts[who] = nil -- 처치 시간 = 상승 뒤 경과(한 대 상한 - getKillSecondsFor의 기본 1타). 0이면 "한 방 처치"로 최대 감점(리뷰 5)
	end
	return true
end

local function expire(entry, now)
	local window = CombatConfig.participationWindowSeconds
	for who, at in pairs(entry.participants) do
		if now - at > window then
			entry.participants[who] = nil
		end
	end
end

-- C1 마무리: 사람 비교 단위 = { stage, level, rebirth }. 실제 Player = Attribute(CharacterLevel · RebirthCount - 지금 값), 스탠드인 표 = who.level · who.rebirth(없으면 1 · 0).
function MobShare.profileOf(who, stage)
	if typeof(who) == "Instance" then
		return { stage = stage, level = who:GetAttribute("CharacterLevel") or 1, rebirth = who:GetAttribute("RebirthCount") or 0 }
	end
	return { stage = stage, level = who.level or 1, rebirth = who.rebirth or 0 }
end

-- 둘 중 낮은 레벨이 든 구간의 허용 레벨 차(CombatConfig.stealLevelGapTiers).
function MobShare.levelGapFor(lowLevel)
	local gap = CombatConfig.stealLevelGapTiers[1].gap
	for _, row in ipairs(CombatConfig.stealLevelGapTiers) do
		if lowLevel >= row.minLevel then
			gap = row.gap
		end
	end
	return gap
end

-- ★ 스틸 가능 판정(대칭 - a · b 순서 무관). 막힘 · 따라 치기 · 어그로 필터 · 클라 자물쇠가 전부 이 함수 하나를 쓴다.
-- ① 환생 같음 ② 레벨 차 ≤ 낮은 레벨 구간 표 ③ 스테이지 차 ≤ stealStageGap.
function MobShare.canShare(a, b)
	if a.rebirth ~= b.rebirth then
		return false
	end
	if math.abs(a.level - b.level) > MobShare.levelGapFor(math.min(a.level, b.level)) then
		return false
	end
	return math.abs(a.stage - b.stage) <= CombatConfig.stealStageGap
end

-- C1 결정 5 보정: 성장 비교 = 환생 → 같으면 레벨. 반환 1(a가 높음) · -1(b가 높음) · 0(같음).
function MobShare.compareGrowth(a, b)
	if a.rebirth ~= b.rebirth then
		return a.rebirth > b.rebirth and 1 or -1
	end
	if a.level ~= b.level then
		return a.level > b.level and 1 or -1
	end
	return 0
end

-- 성장 차 자체가 스틸 불가 사유인가(환생 다름 · 레벨 차 > 구간 표). 아니면 성장은 "같은 급"으로 본다(리뷰 2 - 레벨 1 차이로 방향이 뒤집히지 않게).
local function growthApart(a, b)
	return a.rebirth ~= b.rebirth or math.abs(a.level - b.level) > MobShare.levelGapFor(math.min(a.level, b.level))
end

-- 막힘 = 스틸 불가 + (성장이 더 높음 - 스테이지를 초보와 같게 · 낮게 맞춘 강한 계정 · 또는 스테이지가 더 높음).
-- 스테이지 쪽을 남긴 이유: 성장이 낮아도(환생 직후 계정 등) 더 높은 스테이지 follower는 기준을 끌어올려 주인 몹의 체력 · 피해를 키우고 어그로를 떼어 낸다.
-- 그래서 같이 때리는(follower) 쪽 = 스틸 불가인데 성장도 스테이지도 높지 않은 사람뿐.
local function blocksAgainst(me, other)
	if MobShare.canShare(me, other) then
		return false
	end
	return (growthApart(me, other) and MobShare.compareGrowth(me, other) > 0) or me.stage > other.stage
end

-- 잡는 사람(8초 안에 때렸거나 도운 참여자 - except는 빼고)마다 fn(who, profile). 주인 = 그중 처음 때린 사람(이 집합이 비면 해제).
local function eachHunter(entry, except, now, fn)
	local window = CombatConfig.participationWindowSeconds
	for who, at in pairs(entry.activeAt) do
		local stage = entry.partStage[who]
		if who ~= except and now - at <= window and stage then
			if fn(who, MobShare.profileOf(who, stage)) then
				return true
			end
		end
	end
	return false
end

-- 8초 안에 때렸거나 도운 사람(주인)이 있는가.
function MobShare.hasHunters(entry, now)
	return eachHunter(entry, nil, now, function()
		return true
	end)
end

-- 이 사람이 지금 이 몹에 새로 닿으면 막히는가(이미 때리거나 도운 참여자면 false - 먼저 온 사람 우선 · 쫓기기만 한 사람은 새로 닿는 것과 같다).
-- 잡는 사람 중 누구와라도 "스틸 불가 + 내가 더 높음"이면 막힌다. 낮은 쪽은 막히지 않고 같이 때린다(주인은 그대로 - touch의 follower).
function MobShare.isBlocked(entry, who, stage, now)
	-- 면제 = 이미 때리거나 도운 참여자(잡는 사람 · follower). 쫓기기만 한 참여자는 면제 안 함(리뷰 1 - 먼저 쫓긴 강한 계정이 초보가 주인이 된 몹을 계속 끌고 치는 길 차단)
	local window = CombatConfig.participationWindowSeconds
	local at = entry.participants[who]
	if at ~= nil and now - at <= window and (entry.contributions[who] ~= nil or (entry.activeAt[who] ~= nil and now - entry.activeAt[who] <= window)) then
		return false
	end
	local me = MobShare.profileOf(who, stage)
	return eachHunter(entry, who, now, function(_, other)
		return blocksAgainst(me, other)
	end)
end

-- 잡는 사람 전원과 스틸 가능한가(= 잡는 사람이 될 수 있는가). 아니면 같이 때려도 잡는 사람 집합(주인)을 바꾸지 않는다 -
-- 리뷰 2(대칭)의 목적: 나중에 온 낮은 사람이 잡는 사람 집합에 들어가 그 파티의 다른 멤버를 막는 길 차단.
local function fitsHunters(entry, who, stage, now)
	local me = MobShare.profileOf(who, stage)
	return not eachHunter(entry, who, now, function(_, other)
		return not MobShare.canShare(me, other)
	end)
end

-- 어그로 필터: 나보다 높은 참여자(잡는 사람 · 쫓김 모두) 중 스틸 불가한 사람이 있으면 쫓지 않는다(몹은 기준 = 최고 참여자 공격력으로 문다 - 초보 태그 즉사 · 1 탱커 차단).
function MobShare.tooWeakFor(entry, who, stage)
	local me = MobShare.profileOf(who, stage)
	for other in pairs(entry.participants) do
		local otherStage = entry.partStage[other]
		if other ~= who and otherStage and otherStage > stage and not MobShare.canShare(me, MobShare.profileOf(other, otherStage)) then
			return true
		end
	end
	return false
end

-- 클라 자물쇠용: 잡는 사람 목록을 문자열로("userId,stage,level,rebirth,만료서버시각;…" - 스탠드인 userId = 0). toServerTime(at) = os.clock 시각 → 서버 시각.
function MobShare.encodeHunters(entry, now, toServerTime)
	local parts = {}
	local window = CombatConfig.participationWindowSeconds
	eachHunter(entry, nil, now, function(who, p)
		local id = typeof(who) == "Instance" and who.UserId or 0
		table.insert(parts, ("%d,%d,%d,%d,%.1f"):format(id, p.stage, p.level, p.rebirth, toServerTime(entry.activeAt[who] + window)))
		return false
	end)
	table.sort(parts)
	return table.concat(parts, ";")
end

-- 클라: 이 목록의 몹이 나(me = { userId, stage, level, rebirth })에게 잠겼는가(서버 isBlocked와 같은 판정 - 이미 잡는 사람이면 false).
function MobShare.lockedFor(encoded, me, serverNow)
	if encoded == nil or encoded == "" then
		return false
	end
	local locked = false
	for id, stage, level, rebirth, untilAt in encoded:gmatch("(%-?%d+),(%d+),(%d+),(%d+),([%d%.]+)") do
		if tonumber(untilAt) > serverNow then
			if tonumber(id) == me.userId then
				return false
			end
			locked = locked or blocksAgainst(me, { stage = tonumber(stage), level = tonumber(level), rebirth = tonumber(rebirth) })
		end
	end
	return locked
end

-- 창 안 참여자 중 최고 스테이지(except는 빼고). 없으면 nil.
local function topStage(entry, except)
	local top = nil
	for who in pairs(entry.participants) do
		local stage = entry.partStage[who]
		if who ~= except and stage and (top == nil or stage > top) then
			top = stage
		end
	end
	return top
end

-- 창 밖 참여자를 빼고 기준을 다시 잡는다. 참여자가 하나도 없으면 기준은 그대로 둔다(다음에 닿는 사람이 정한다).
-- 반환: 기준 스테이지, 비율이 다시 환산됐는가(상승).
function MobShare.refresh(entry, now)
	expire(entry, now)
	local top = topStage(entry, nil)
	if top == nil then
		return entry.refStage, false
	end
	local rose = false
	if entry.refStage == nil or top > entry.refStage then
		rose = rise(entry, top, now)
	elseif top < entry.refStage then
		entry.refStage = top -- 내려갈 때 = 비율 유지
	end
	return entry.refStage, rose
end

-- 이 사람의 기록을 지운다(스테이지 변경 · 퇴장). 이 사람만 닿았던 몹이면 초기화하고 true.
function MobShare.purge(entry, who)
	if entry.partStage[who] == nil and entry.contributions[who] == nil and entry.participants[who] == nil then
		return false
	end
	entry.participants[who] = nil
	entry.partStage[who] = nil
	entry.contributions[who] = nil
	entry.firstHitAt[who] = nil
	entry.hitCounts[who] = nil
	entry.activeAt[who] = nil
	if next(entry.participants) == nil and next(entry.contributions) == nil then
		MobShare.fresh(entry)
		return true
	end
	return false
end

-- 참여(타격 전 · 어그로 · 도움). 기록된 스테이지와 지금 스테이지가 다르면 먼저 지운다(스테이지 변경을 놓친 경로 - 견습 단계 전환 등 - 의 안전망).
-- passive = 쫓기기만 함(잡는 사람이 아님 - MonsterAI 어그로). 타격(applyDamage) · 도움(support)은 잡는 사람.
-- 반환: 기준 스테이지, 초기화됐는가, 기준 상승으로 비율이 다시 환산됐는가, 막혔는가(잡는 사람과 stealStageGap 넘게 차이 - 참여 안 됨).
function MobShare.touch(entry, who, stage, now, passive)
	local wasReset = false
	local recorded = entry.partStage[who]
	if recorded ~= nil and recorded ~= stage then
		wasReset = MobShare.purge(entry, who)
	end
	expire(entry, now)
	if MobShare.isBlocked(entry, who, stage, now) then
		return entry.refStage, wasReset, false, true
	end
	local wasHunter = entry.activeAt[who] ~= nil and now - entry.activeAt[who] <= CombatConfig.participationWindowSeconds
	entry.participants[who] = now
	entry.partStage[who] = stage
	-- 리뷰 1: 쫓기기만 하는 높은 사람(passive)이 있는 몹에 스틸 불가한 낮은 사람이 먼저 쳐서 주인이 되면 그 높은 사람의 파티원을 막는다 → 나보다 높은 스틸 불가 참여자가 있으면 주인이 안 된다
	if not passive and (wasHunter or (fitsHunters(entry, who, stage, now) and not MobShare.tooWeakFor(entry, who, stage))) then
		entry.activeAt[who] = now -- 잡는 사람. 아니면(스틸 불가한 낮은 사람) follower - 참여 · 기여는 되지만 주인 집합은 그대로
	end
	local ref, rose = MobShare.refresh(entry, now)
	return ref, wasReset, rose, false
end

-- 도움(치유 · 보호 · 버프): target이 지금 참여자면 helper도 참여자. 반환 = 참여시켰는가.
function MobShare.support(entry, helper, helperStage, target, now)
	local at = entry.participants[target]
	if at == nil or now - at > CombatConfig.participationWindowSeconds then
		return false
	end
	local _, _, _, blocked = MobShare.touch(entry, helper, helperStage, now)
	return not blocked
end

-- 기준 HP로 환산한 피해 비율을 뺀다(touch 뒤에 부른다). 반환 = 죽었는가.
function MobShare.applyRatio(entry, who, ratioDealt, now)
	entry.hpRatio -= ratioDealt
	if who ~= nil then
		entry.contributions[who] = (entry.contributions[who] or 0) + ratioDealt
		entry.firstHitAt[who] = entry.firstHitAt[who] or now
		entry.hitCounts[who] = (entry.hitCounts[who] or 0) + 1
	end
	return entry.hpRatio <= 0
end

-- 보상 자격: 기여 ≥ 문턱 · 기록을 쌓은 스테이지 = 지금 스테이지 · 지금 스테이지 ≤ 기준(기준이 내려가 자기보다 낮아졌으면 = 높은 기준에서 쌓은 기여를 낮은 HP로 바꿔 먹는 길 차단).
function MobShare.eligible(entry, who, stageNow)
	local c = entry.contributions[who]
	if c == nil or c < CombatConfig.contributionRewardThreshold then
		return false, "low"
	end
	if entry.partStage[who] ~= stageNow then
		return false, "stage_changed"
	end
	if entry.refStage == nil or stageNow > entry.refStage then
		return false, "above_ref"
	end
	return true, nil
end

return MobShare
