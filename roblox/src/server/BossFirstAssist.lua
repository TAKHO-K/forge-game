-- GUARDIAN-V3 첫 보스 도움(BossFrameworkData.v3[보스].firstAssist - 새 몸이 뜰 때만 · data.firstAssist): 이 보스를 처치하기 전까지 전멸 1회마다
--   그 멤버가 보스에게 받는 피해 − perFail(최대 − max). 받는 피해 배율 = 출처 "bossAssist"(PlayerState - 스킬 · 평타 · 기믹 · 환경 피해 전부) · 전투 동안.
--   기록 = 저장 hints.bossAssist(v75 - 멤버 각자) · 처치하면 cleared(CombatResolution → noteClear) · 견습 보스전 제외.
local print = require(game:GetService("ReplicatedStorage").Shared.Log).info -- SEC-FIX-1 9: 라이브 = WARN(이 파일 print = INFO · 꺼짐) · Studio = 그대로
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossFramework = require(ReplicatedStorage.Shared.BossFramework)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)

local BossFirstAssist = {}

local SOURCE = "bossAssist"
local HOLD_SECONDS = 3 * 3600 -- 전투 동안(끝나면 지운다)

local function realMembers(encounter)
	local list = {}
	for _, member in ipairs(encounter.members or {}) do
		if typeof(member) == "Instance" and member:IsA("Player") then
			table.insert(list, member)
		end
	end
	return list
end

-- 멤버마다 지금 기록으로 배율을 건다(1이면 건 것을 푼다)
function BossFirstAssist.apply(encounter)
	local assist = encounter and not encounter.isTutorial and encounter.data.firstAssist
	if not assist then
		return
	end
	for _, member in ipairs(realMembers(encounter)) do
		local fails, cleared = PlayerProfile.getBossAssist(member, encounter.data.id)
		local multiplier = BossFramework.assistMultiplier(assist, fails, cleared)
		PlayerState.clearIncomingDamageMultiplierSource(member, SOURCE)
		if multiplier < 1 then
			PlayerState.setIncomingDamageMultiplierUntil(member, multiplier, HOLD_SECONDS, SOURCE)
			print(("[forge-game] 첫 보스 도움: %s - 전멸 %d회 → 받는 피해 × %.2f"):format(member.Name, fails, multiplier))
		end
	end
end

-- 전멸(BossEncounter.resetFor): 처치 전인 멤버의 전멸 수 + 1 → 배율 다시
function BossFirstAssist.onWipe(encounter)
	if not (encounter and not encounter.isTutorial and encounter.data.firstAssist) then
		return
	end
	for _, member in ipairs(realMembers(encounter)) do
		PlayerProfile.noteBossAssistFail(member, encounter.data.id)
	end
	BossFirstAssist.apply(encounter)
end

-- 처치(CombatResolution): 이 보스 첫 클리어 = 도움 끝
function BossFirstAssist.noteClear(player, data)
	if typeof(player) == "Instance" and data and data.firstAssist then
		PlayerProfile.markBossAssistCleared(player, data.id)
		PlayerState.clearIncomingDamageMultiplierSource(player, SOURCE)
	end
end

function BossFirstAssist.clear(encounter)
	for _, member in ipairs(realMembers(encounter)) do
		PlayerState.clearIncomingDamageMultiplierSource(member, SOURCE)
	end
end

return BossFirstAssist
