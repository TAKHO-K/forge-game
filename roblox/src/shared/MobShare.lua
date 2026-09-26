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

-- 잡는 사람(8초 안에 때렸거나 도운 참여자 - except는 빼고)의 최저 · 최고 스테이지. 없으면 nil.
local function activeBand(entry, except, now)
	local window = CombatConfig.participationWindowSeconds
	local low, high = nil, nil
	for who, at in pairs(entry.activeAt) do
		local stage = entry.partStage[who]
		if who ~= except and now - at <= window and stage then
			low = (low == nil or stage < low) and stage or low
			high = (high == nil or stage > high) and stage or high
		end
	end
	return low, high
end

-- 이 스테이지 사람이 지금 이 몹에 새로 닿으면 막히는가(이미 참여 중이면 false).
function MobShare.isBlocked(entry, who, stage, now)
	if entry.participants[who] ~= nil and now - entry.participants[who] <= CombatConfig.participationWindowSeconds then
		return false
	end
	local low, high = activeBand(entry, who, now)
	if low == nil then
		return false
	end
	return stage - low > CombatConfig.stealStageGap or high - stage > CombatConfig.stealStageGap
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
	entry.participants[who] = now
	entry.partStage[who] = stage
	if not passive then
		entry.activeAt[who] = now
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
