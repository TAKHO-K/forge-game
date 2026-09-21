-- 파티 "연결 끊김" 표시 헬퍼(S19b B). 서버 스냅샷의 멤버 하나가 유예 중이면 member.awayRemaining(남은 초)을 싣고 온다 - 클라는 받은 시각(os.clock) 기준으로 끝나는 시각을 적어 두고
-- 남은 시간을 m:ss로 센다(서버 · 클라 시계를 맞출 필요가 없다). 파티 목록(PartyList)과 파티창(panels/Party) 둘이 같은 함수를 쓴다.

local PartyAway = {}

-- 스냅샷을 받은 순간 한 번 부른다(같은 표를 여러 리스너가 받아도 안전하다 - 이미 적혀 있으면 그대로).
function PartyAway.stamp(state)
	if state then
		for _, member in ipairs(state.members) do
			if member.awayRemaining and not member.awayEndsAt then
				member.awayEndsAt = os.clock() + member.awayRemaining
			end
		end
	end
	return state
end

-- 남은 초(유예 중이 아니면 nil).
function PartyAway.remaining(member)
	if not member.awayEndsAt then
		return nil
	end
	return math.max(0, member.awayEndsAt - os.clock())
end

-- "m:ss"(올림 - 0초가 되기 전에는 0:00이 안 보인다).
function PartyAway.clock(seconds)
	local whole = math.ceil(seconds)
	return ("%d:%02d"):format(math.floor(whole / 60), whole % 60)
end

-- 표시 글: PC "연결 끊김 2:41" · 모바일 축약형(폭 78) "끊김 2:41". 유예 중이 아니면 nil.
function PartyAway.text(member, compact)
	local remaining = PartyAway.remaining(member)
	if not remaining then
		return nil
	end
	return ("%s %s"):format(compact and "끊김" or "연결 끊김", PartyAway.clock(remaining))
end

-- 다른 서버로 재접속한 끊긴 멤버에게 뜨는 복귀 초대 문구(S20 사전 작업 1): "OOO님의 파티로 돌아가기 (남은 시간 m:ss)" - 남은 시간은 파티의 유예(연결 끊김 m:ss)와 같은 카운트다운이다.
-- S20b 사전 작업 2: 요청 배너 첫 줄(제목) = 누가 · 무엇을 → "{name}님의 파티로 돌아가기"(RequestBanner.fitTitle이 이름만 줄인다) · 본문 = 남은 시간. 두 조각을 이으면 옛 한 줄 문구와 같다.
PartyAway.reconnectTitle = "{name}님의 파티로 돌아가기"
function PartyAway.reconnectRemainingText(remainingSeconds)
	return ("남은 시간 %s"):format(PartyAway.clock(math.max(0, remainingSeconds)))
end
function PartyAway.reconnectBody(leaderName, remainingSeconds)
	return ("%s (%s)"):format(PartyAway.reconnectTitle:gsub("{name}", leaderName), PartyAway.reconnectRemainingText(remainingSeconds))
end

return PartyAway
