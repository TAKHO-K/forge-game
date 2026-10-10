-- SEC-FIX-1 4: 교환 코드 표(서버 전용 - ServerScriptService는 클라에 복제되지 않는다). 옛 자리 = shared/data/SocialRewardData.codes(ReplicatedStorage →
--   변조 클라가 require로 공지 전 코드까지 읽고 바로 입력할 수 있었다 - VERIFY-6 SEC2 #3). 코드 검사 = server/SocialRewardService만 · 게시판(client/UpdateBoard)은
--   서버가 내려주는 공개 코드(hidden · inactive · 만료 아님)만 받는다(RemoteFunction BoardCodes). 쿨다운 · 문구 · 초대 수치는 그대로 shared/data/SocialRewardData.
-- QUEUE-STUDIO 0-2(사용자 결정 10-01): 출시 코드 = "출시 기념" · "좋아요 목표" 2개(FIRSTBOSS 없음 · 옛 RIFTOPEN 뺌). 게시판 설명 = TextData noteKey(ko/en).
--   hidden = 게시판에 안 보임(입력은 됨) - 좋아요 목표를 달성해 공지할 때 false로 바꿔 업데이트한다.
--   QUEUE-ALL6 A5(사용자 결정): 좋아요 목표 단계 = 1단계 1,000(LIKES1K) → 5,000 → 10,000. inactive = 없는 코드처럼(입력 X · 게시판 X) - 앞 단계를 달성하면 그 줄의
--   inactive를 지우고(입력 가능 · 숨김) 공지 때 hidden도 지운다. 5K · 10K 보상 · 기한은 자리값(켤 때 확정).
return {
	codes = { -- 코드 표 한 곳(대문자 · 만료 = UTC 날짜 { 년, 월, 일 } 끝까지)
		{ code = "FORGE2026", reward = { enhanceStone = 15, sparkleShard = 20 }, expires = { 2026, 12, 31 }, note = "출시 기념", noteKey = "update.board.code.launch" },
		{ code = "LIKES1K", likesGoal = 1000, reward = { enhanceStone = 10, sparkleShard = 10 }, expires = { 2027, 1, 31 }, note = "좋아요 목표", noteKey = "update.board.code.likes", hidden = true },
		{ code = "LIKES5K", likesGoal = 5000, reward = { enhanceStone = 15, sparkleShard = 15 }, expires = { 2027, 6, 30 }, note = "좋아요 목표 2단계", noteKey = "update.board.code.likes", hidden = true, inactive = true },
		{ code = "LIKES10K", likesGoal = 10000, reward = { enhanceStone = 20, sparkleShard = 20 }, expires = { 2027, 12, 31 }, note = "좋아요 목표 3단계", noteKey = "update.board.code.likes", hidden = true, inactive = true },
	},
}
