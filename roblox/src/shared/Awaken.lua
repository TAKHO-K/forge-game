-- D1 [3] 태초 각성 판정 · 비용(서버 차감 · 클라 표시가 같은 함수). 규칙: 태초 장비만 · itemLevel → 계정 역대 최고 스테이지(그보다 높게는 못 올린다) ·
-- 등급 · 강화 · 옵션(보석) · 태초 각인은 그대로 · 비용 = tier1 잡몹 골드 × PrimordialData.awakenGoldKills(GoldCost "awaken" - 계정 최고 스테이지 기준).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData) -- C5-7
local Text = require(ReplicatedStorage.Shared.Text)

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

-- 이유 → 글(desc.awaken.* - TextData_shared). 읽을 때 Text.get(그때의 언어) - 모르는 이유는 nil(호출부가 tostring으로 보여 준다).
local REASON_KEYS = {
	not_found = "desc.awaken.notFound",
	not_primordial = "desc.awaken.notPrimordial",
	already_max = "desc.awaken.alreadyMax",
	no_gold = "desc.awaken.noGold",
}
Awaken.reasonText = setmetatable({}, {
	__index = function(_, reason)
		local key = REASON_KEYS[reason]
		return key and Text.get(key) or nil
	end,
})

return Awaken
