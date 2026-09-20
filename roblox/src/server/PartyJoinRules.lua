-- 파티 구성 변경(초대 · 수락)의 공통 금지 조건 - PartyServer.server.lua가 쓰고 자동 검증(S12)이 같은 함수를 부른다(RemoteEvent 핸들러 안의 local 함수로는 검증이 부를 수 없다).
-- 견습 중인 사람도 파티를 맺을 수 있다(S12, PRD 20.73 [7-2]) - 견습은 보스만 싱글이고 사냥은 처음부터 공유 몬스터였다.
-- 파티 보스에서 견습 멤버를 빼는 일은 BossEncounter가 한다(getEntryMembers).

local PlayerProfile = require(script.Parent.PlayerProfile)
local BossEncounter = require(script.Parent.BossEncounter)
local PartyCrossServer = require(script.Parent.PartyCrossServer)

local PartyJoinRules = {}

-- 막히면 사유 문자열(PartyServer의 REASON_TEXT 키), 통과면 nil.
function PartyJoinRules.checkJoinable(inviter, invitee)
	if not PlayerProfile.getProfile(inviter) or not PlayerProfile.getProfile(invitee) then
		return "no_profile"
	end
	if BossEncounter.getActive(inviter) then
		return "in_boss" -- 보스 HP가 입장 인원에 고정돼 있어 중간 합류는 없다(PRD 20.47 [6](다)).
	end
	if PartyCrossServer.isJoining(invitee) then
		return "joining"
	end
	return nil
end

return PartyJoinRules
