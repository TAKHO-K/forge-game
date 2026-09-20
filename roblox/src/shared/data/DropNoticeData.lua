-- 파티원 드랍 알림(30-0 S10, PRD 20.73 [5-3]) 규칙 값. 서버(DropNotice)는 등급 표를, 클라(DropFeed)는 시간 · 행 수를 읽는다.
-- 등급 id는 ArmorData.gradeOrder(태초 = "primordial")와 같다.
--
-- 사용자 결정(2026-09-20, PRD 20.93)이 PRD 20.73 [5-3]의 표시 규칙을 바꿨다:
--   · 드랍 피드 = 칩 스택 바로 아래 · 최대 3줄 · 새 알림이 맨 위 · 4초 뒤 흐려지며 사라짐 · 3줄이 넘으면 가장 오래된 줄부터 밀려남(대기열 없음).
--   · 태초(서버 전체)만 예외 - 피드가 아니라 화면 상단 가운데 배너 한 줄 4초 + 채팅 1줄.
-- 그래서 원래 지시서의 대기열(queueMax 8) · 등급별 우선순위 · 태초 8초는 쓰지 않는다.

return {
	-- 이 등급이 굴려지면 같은 파티 전원(본인 포함)에게 알린다. 솔로(파티 없음)는 serverWideGrades에 든 것만 알린다.
	partyGrades = { relic = true, ancient = true, primordial = true },
	-- 이 등급이 굴려지면 같은 서버 전원에게 알린다(파티 알림을 대신한다 - 배너 + 채팅 1줄).
	serverWideGrades = { primordial = true },

	feedRows = 3, -- 드랍 피드 최대 줄 수
	seconds = 4, -- 피드 · 배너 표시 시간(초) - 이 시간이 지나면 흐려지기 시작한다
	fadeSeconds = 0.4, -- 흐려지는 시간(초)
	groupWindowSeconds = 1, -- 같은 사람의 알림이 이 시간 안에 여럿이면 한 줄로 묶는다("… 외 1")
	moreFormat = " 외 %d", -- 묶음 표기 - %d = 묶인 나머지 건수
}
