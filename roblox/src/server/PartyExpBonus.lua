-- 파티 경험치 보너스 조건 판정(P2 G, 결정 10A) - 서버 전용. 경험치 · 재료를 지급하는 순간(PlayerProfile.getExpGainMultiplier → PartyState.getExpBonusFor)에만 불린다 -
-- 매 프레임 계산 없음. 받는 사람(recipient) 기준으로 파티원 한 명(member)이 인원에 드는가:
--   ① 같은 구역: 둘 다 같은 보스 인스턴스(BossEncounter) 안이거나, 둘 다 보스전 밖에서 같은 사냥 구역(tier 구역 - ZoneBounds) 안.
--   ② 반경: 두 캐릭터 사이 거리 ≤ PartyConfig.expBonusCondition.radiusStuds.
--   ③ 활동: 파티원이 최근 activeWithinSeconds초 안에 적에게 실제로 명중했다(PartyState.noteActivity - CombatResolution.resolveHit, P2.5a 결정 10 - 헛스윙 · 치유는 안 센다).
-- isEligible은 순수 함수(검증 (가)가 합성 입력으로 부른다). 이 모듈을 불러오면 PartyState에 판정 함수가 등록된다(CombatResolution이 require한다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local BossEncounter = require(script.Parent.BossEncounter)
local PartyState = require(script.Parent.PartyState)

local PartyExpBonus = {}

-- info = { zone = 구역 식별값(보스 인스턴스 표 또는 "zone:<키>", 구역 밖이면 nil), position = Vector3 또는 nil, lastActiveAt = 시각 또는 nil }
function PartyExpBonus.isEligible(recipientInfo, memberInfo, now)
	local condition = PartyConfig.expBonusCondition
	if recipientInfo.zone == nil or memberInfo.zone ~= recipientInfo.zone then
		return false
	end
	if not (recipientInfo.position and memberInfo.position) then
		return false
	end
	if (recipientInfo.position - memberInfo.position).Magnitude > condition.radiusStuds then
		return false
	end
	return memberInfo.lastActiveAt ~= nil and now - memberInfo.lastActiveAt <= condition.activeWithinSeconds
end

-- Studio 자동 검증 전용: 캐릭터가 없는 스탠드인(표)의 위치 · 구역을 대신 준다({ position = Vector3, zone = 구역 식별값 }). 라이브에서는 무시된다.
local debugPresence = {}
function PartyExpBonus.debugSetPresence(member, presence)
	if RunService:IsStudio() then
		debugPresence[member] = presence
	end
end

local function rootPosition(player)
	local character = typeof(player) == "Instance" and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

-- 지금 이 플레이어의 구역 식별값: 보스 인스턴스 표 → 사냥 구역("zone:<키>") → nil(리스폰 · 커뮤니티 · 강화소 등 사냥 구역 밖).
function PartyExpBonus.zoneOf(player, position)
	local encounter = BossEncounter.getEncounter(player)
	if encounter then
		return encounter
	end
	if not position then
		return nil
	end
	for _, zoneKey in ipairs(WorldConfig.tierZoneOrder) do
		if ZoneBounds.isInside(position, zoneKey) then
			return "zone:" .. zoneKey
		end
	end
	return nil
end

function PartyExpBonus.infoOf(player)
	local presence = debugPresence[player]
	local position = presence and presence.position or rootPosition(player)
	local zone
	if presence then
		zone = presence.zone
	else
		zone = PartyExpBonus.zoneOf(player, position)
	end
	return { zone = zone, position = position, lastActiveAt = PartyState.getLastActivity(player) }
end

PartyState.setExpEligibility(function(recipient, member)
	return PartyExpBonus.isEligible(PartyExpBonus.infoOf(recipient), PartyExpBonus.infoOf(member), os.clock())
end)

return PartyExpBonus
