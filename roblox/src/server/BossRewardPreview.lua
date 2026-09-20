-- 보스 첫 클리어 보상 미리보기 조회(30-0 S11, PRD 20.73 [4-2]). 스테이지 선택 패널이 보스 칸의 "받을 것 / 받은 것"을 그리려고 묻는다 - 판정은 전부 서버가 하고 클라는 그린다.
-- 요청 = 보스 스테이지 배열(최대 BossRewardPreviewData.maxStages개). 응답 = { ok, entries = { { stage, bossId, gearClaimed, dropTicket, resetTicket }... }, codex = { [bossId] = true } }.
--   gearClaimed = 지금 직업이 그 스테이지의 확정 장비를 이미 받았는가(직업별 bossFirstClearStages)
--   dropTicket · resetTicket = "none"(그 스테이지는 안 준다) / "available"(아직 안 받음) / "claimed"(계정으로 이미 받음 - 직업과 무관, 계정 공유 protectionClaimedStages)
--   bossId = BossRules.bossIdForStage(stage) - 스테이지만의 함수다(PRD 20.80 [A]: 스테이지 선택 UI의 보스 이름도 이 함수 하나를 본다).
-- 집합 전체를 Attribute로 복제하지 않는다(무한 스테이지라 끝없이 자란다) - 그래서 요청 - 응답 방식이다. 이 모듈은 상태를 읽기만 한다(요청 시각 표 하나만 갖는다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRewardPreviewData = require(ReplicatedStorage.Shared.data.BossRewardPreviewData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local PlayerProfile = require(script.Parent.PlayerProfile)

local BossRewardPreview = {}

local lastRequestAt = {} -- [Player] = 마지막 요청 시각(os.clock)

-- 입력 검사(순수): 배열 · 1 ~ maxStages개 · 전부 보스 스테이지(정수). 반환: true 또는 false, 사유("not_array" · "count" · "not_number" · "not_boss_stage").
function BossRewardPreview.validate(stages)
	if type(stages) ~= "table" then
		return false, "not_array"
	end
	local count = 0
	for key in pairs(stages) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false, "not_array"
		end
		count += 1
	end
	if count ~= #stages then
		return false, "not_array" -- 구멍 난 배열
	end
	if count < 1 or count > BossRewardPreviewData.maxStages then
		return false, "count"
	end
	for _, stage in ipairs(stages) do
		if type(stage) ~= "number" or stage ~= stage or stage == math.huge or stage % 1 ~= 0 then
			return false, "not_number"
		end
		if not BossRules.isBossStage(stage) then
			return false, "not_boss_stage"
		end
	end
	return true
end

local function ticketState(count, claimed)
	if count == 0 then
		return "none"
	end
	return claimed and "claimed" or "available"
end

-- 검증을 통과한 stages에 대한 응답을 만든다.
function BossRewardPreview.build(player, stages)
	local entries = {}
	for _, stage in ipairs(stages) do
		local dropCount, resetCount = Enhance.getBossGrant(stage)
		local claimed = PlayerProfile.hasClaimedProtectionStage(player, stage)
		table.insert(entries, {
			stage = stage,
			bossId = BossRules.bossIdForStage(stage),
			gearClaimed = PlayerProfile.hasBossFirstClearReward(player, stage),
			dropTicket = ticketState(dropCount, claimed),
			resetTicket = ticketState(resetCount, claimed),
		})
	end
	return { ok = true, entries = entries, codex = PlayerProfile.getBossCodex(player) }
end

-- 요청 1건 처리(RemoteEvent 핸들러와 자동 검증이 같은 함수를 부른다). now = 검증용 시각 주입. 잘못된 입력 · 너무 잦은 요청은 { ok = false, reason }로 거절한다(에러를 내지 않는다).
function BossRewardPreview.handle(player, stages, now)
	now = now or os.clock()
	local last = lastRequestAt[player]
	if last and now - last < BossRewardPreviewData.minIntervalSeconds then
		return { ok = false, reason = "rate" }
	end
	lastRequestAt[player] = now
	local valid, reason = BossRewardPreview.validate(stages)
	if not valid then
		return { ok = false, reason = reason }
	end
	return BossRewardPreview.build(player, stages)
end

function BossRewardPreview.forget(player)
	lastRequestAt[player] = nil
end

return BossRewardPreview
