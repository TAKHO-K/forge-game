-- 환생을 어디서 · 언제 요청할 수 있는가(S12b F) - 서버 판정 한 곳. G1-3부터 자리는 커뮤니티 환생 제단 하나(강화대 환생 탭은 안내만).
-- 둘 다 "요청 시점에 플레이어가 그 물체 반경 안에 있는가"를 서버가 직접 잰다. 그 뒤 환생 조건(레벨 · 최대 회차)은 PlayerProfile.rebirth가 그대로 본다.
-- 보스전 중 · 강화 요청 처리 직후에는 어느 자리에서도 안 된다.
--   evaluate = 순수 함수(검증 (가)가 합성 입력으로 부른다) · check = 실제 Player의 보스전 · 강화 상태를 모아 evaluate를 부른다 · attempt = check + PlayerProfile.rebirth(RebirthServer가 부른다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossEncounter = require(script.Parent.BossEncounter)
local EnhanceService = require(script.Parent.EnhanceService)
local PlayerProfile = require(script.Parent.PlayerProfile)

local RebirthAccess = {}

-- 제단 자리(월드 좌표). 강화대 판정과 같이 3D 거리로 잰다(HuntingGround가 제단 물체를 이 좌표에 놓는다).
function RebirthAccess.altarPosition()
	return WorldConfig.huntingGround.center + WorldConfig.zones.community.center + WorldConfig.rebirthAltar.offsetFromCommunity
end

-- 위치 → 어느 자리 안인가("station" · "altar" · nil). position은 Vector3.
-- G1-3(사용자 결정): 강화대 자리는 뺐다 - 환생은 커뮤니티 센터의 제단 한 곳(강화대 환생 탭은 안내만).
function RebirthAccess.placeOf(position)
	if (position - RebirthAccess.altarPosition()).Magnitude <= WorldConfig.rebirthAltar.interactionRangeStuds then
		return "altar"
	end
	return nil
end

-- 순수 판정. state = { position = Vector3 | nil, inBossFight = boolean, enhancing = boolean }. 반환: true, 자리("station" · "altar") | false, 거절 사유("no_character" · "out_of_range" · "boss_fight" · "enhancing").
function RebirthAccess.evaluate(state)
	if not state.position then
		return false, "no_character"
	end
	local place = RebirthAccess.placeOf(state.position)
	if not place then
		return false, "out_of_range"
	end
	if state.inBossFight then
		return false, "boss_fight"
	end
	if state.enhancing then
		return false, "enhancing"
	end
	return true, place
end

-- 실제 Player의 상태로 evaluate를 부른다(환생 조건 자체는 안 본다).
function RebirthAccess.check(player, rootPosition)
	return RebirthAccess.evaluate({
		position = rootPosition,
		inBossFight = BossEncounter.getEncounter(player) ~= nil,
		enhancing = EnhanceService.isBusy(player),
	})
end

-- 환생 요청 하나를 처리한다. 반환: 클라에 보낼 payload(조용히 무시할 요청이면 nil).
--   자리 밖 · 캐릭터 없음 → nil(강화대 밖과 같은 취급) / 보스전 · 강화 중 → { success = false, reason } / 그 뒤는 PlayerProfile.rebirth(레벨 · 최대 회차 조건) 결과 그대로.
function RebirthAccess.attempt(player, rootPosition)
	local allowed, reason = RebirthAccess.check(player, rootPosition)
	if not allowed then
		if reason == "boss_fight" or reason == "enhancing" then
			return { success = false, reason = reason }
		end
		return nil
	end
	local success, reasonOrCount, requiredLevel = PlayerProfile.rebirth(player)
	if success then
		return { success = true, rebirthCount = reasonOrCount }
	end
	return { success = false, reason = reasonOrCount, requiredLevel = requiredLevel }
end

return RebirthAccess
