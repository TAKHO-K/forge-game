-- QUEUE-UI2 UI2-4 HUD [보상] 작은 창 판정(순수 - 하네스가 그대로 부른다). 줄 = HudData.rewards(출석 · 시즌 출석판 · 선물함).
--   questView = 서버 QuestUpdate 값(attendance · loginReady · board) · giftCount = 서버 Attribute GiftPending(선물함 남은 수)
local RewardHub = {}

-- 출석(일일 접속 보상 · 출석 칸) - panels/Attendance.hasClaimable과 같은 판정(그 함수가 이걸 부른다)
function RewardHub.attendance(v, split)
	if not v then
		return false
	end
	if v.loginReady and not split then -- UI-1b 나눔(split) = 접속 보상은 따로(RewardHub.login)
		return true
	end
	local att = v.attendance
	for _, entry in ipairs(att and att.rewards or {}) do
		if entry.day <= att.count and att.claimed[tostring(entry.day)] ~= true then
			return true
		end
	end
	return false
end

-- UI-1b 1-b 12: 접속 보상 창(나눔) = 오늘 첫 접속 보상을 아직 안 받음
function RewardHub.login(v)
	return v ~= nil and v.loginReady == true
end

-- 시즌 출석판: 오늘 받을 칸(또는 보너스)이 있으면
function RewardHub.seasonBoard(v)
	return v ~= nil and v.board ~= nil and v.board.todayKind ~= nil
end

function RewardHub.gift(giftCount)
	return (tonumber(giftCount) or 0) > 0
end

-- → { attendance = bool, seasonBoard = bool, gift = bool }, any(버튼 점 - 숫자 없음)
function RewardHub.dots(questView, giftCount, split)
	local d = { attendance = RewardHub.attendance(questView, split), seasonBoard = RewardHub.seasonBoard(questView), gift = RewardHub.gift(giftCount) }
	if split then
		d.login = RewardHub.login(questView)
	end
	return d, d.attendance or d.seasonBoard or d.gift or d.login == true
end

-- 환생 가능(02 v5 알림 ④ - 환생 = 마을 제단 · 메뉴 없음): 서버 PlayerProfile.rebirth와 같은 조건(레벨 ≥ 요구 레벨 · 회차 < 최대)
function RewardHub.rebirthReady(level, rebirthCount, requiredLevel, maxCount)
	return (tonumber(rebirthCount) or 0) < (tonumber(maxCount) or 0) and (tonumber(level) or 0) >= (tonumber(requiredLevel) or math.huge)
end

return RewardHub
