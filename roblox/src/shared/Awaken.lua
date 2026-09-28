-- D1 [3] 태초 각성 판정 · 비용(서버 차감 · 클라 표시가 같은 함수). 규칙: 태초 장비만 · itemLevel → 계정 역대 최고 스테이지(그보다 높게는 못 올린다) ·
-- 등급 · 강화 · 옵션(보석) · 태초 각인은 그대로 · 비용 = tier1 잡몹 골드 × PrimordialData.awakenGoldKills(GoldCost "awaken" - 계정 최고 스테이지 기준).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData) -- C5-7

local Awaken = {}

-- C5-7: 초월은 각성 무료(item을 주면 등급에 따라 0).
function Awaken.cost(accountBestStage, item)
	if item and item.grade == TranscendentData.gradeId and TranscendentData.awakenFree then
		return 0
	end
	return GoldCost.cost(MonsterData.tier1.goldDrop * PrimordialData.awakenGoldKills, accountBestStage, "awaken")
end

-- 못 하는 이유(nil = 할 수 있다): not_found · not_primordial(고대 포함 - 태초 · 초월만) · already_max(이미 역대 최고).
function Awaken.blockReason(item, accountBestStage)
	if not item then
		return "not_found"
	end
	if item.grade ~= "primordial" and item.grade ~= TranscendentData.gradeId then
		return "not_primordial"
	end
	if (item.itemLevel or 0) >= (accountBestStage or 1) then
		return "already_max"
	end
	return nil
end

Awaken.reasonText = {
	not_found = "장비를 찾을 수 없어요",
	not_primordial = "각성은 태초 · 초월 장비만 할 수 있어요",
	already_max = "이미 역대 최고 스테이지예요",
	no_gold = "골드가 부족해요",
}

return Awaken
