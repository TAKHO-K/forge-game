-- QUEUE-ALL1 P4 §1 · §2(docs/design/v2/05): 초대 보상 · 코드 · 업데이트 게시판(허브). 서버 = server/SocialRewardService · 게시판 = client/UpdateBoard.
--   초대: 로블록스 초대창(client/FriendInvite - SocialService:PromptGameInvite)으로 들어온 친구의 **첫 접속**(저장 없음) = 양쪽 보상.
--     초대한 사람 = Player:GetJoinData().ReferredByPlayerId · 1쌍 1회(DataStore 쌍 키) · 초대자 하루 inviterDailyCap번 · 부계정 악용 방지 = 초대받은 계정 나이 ≥ minAccountAgeDays일
--     (그보다 어리면 초대받은 쪽만 받고 초대자는 안 받는다 - 기록만). 초대자가 오프라인이면 선물함(GiftService - 반짝 조각만 선물 가능)으로.
--   코드: 설정 창 입력 → 서버 검증(있음 · 기한 · 계정당 1회 - profile.redeemedCodes v58) · 대소문자 무시 · 앞뒤 공백 무시 · 1인 codeCooldownSeconds · 분당 codePerMinute번 · 모든 시도 기록(print + Telemetry).
--     보상 = 작게(강화석 · 반짝 조각) - 경제를 흔들지 않게 · 로벅스 판매 금지 목록과 무관(무료 지급). 커뮤니티(그룹) 가입 보상 = 그룹이 없어 자리만(groupRewardEnabled = false).
return {
	invite = {
		storeName = "SocialInvite_v1", studioSuffix = "_studio",
		minAccountAgeDays = 7, inviterDailyCap = 5,
		inviteeReward = { enhanceStone = 20, egg = 1, sparkleShard = 30 },
		inviterReward = { sparkleShard = 30 }, -- 오프라인이면 선물함
		text = { invitee = "친구 초대로 왔어요! 환영 보상", inviter = "초대한 친구가 처음 왔어요! 보상" },
	},
	codeCooldownSeconds = 3, codePerMinute = 8,
	codes = { -- 코드 표 한 곳(대문자 · 만료 = UTC 날짜 { 년, 월, 일 } 끝까지)
		{ code = "FORGE2026", reward = { enhanceStone = 15, sparkleShard = 20 }, expires = { 2026, 12, 31 }, note = "출시 기념" },
		{ code = "RIFTOPEN", reward = { sparkleShard = 30 }, expires = { 2026, 11, 30 }, note = "균열 시간 열림" },
	},
	groupRewardEnabled = false,
	-- 허브 업데이트 게시판(새 소식 + 지금 유효한 코드 - 만료 지난 코드는 안 보인다)
	news = {
		{ date = "2026-10-01", text = "균열 시간(매일 2번 · 20분) · 전 서버 합동 목표 · 주간 도전 추가!" },
		{ date = "2026-10-01", text = "방어구 외형 v3 - 직업마다 다른 모습 · 보스 아레나 바닥 새 단장" },
	},
	text = { ok = "코드 보상: %s", bad = "없는 코드예요", expired = "기한이 지난 코드예요", used = "이미 받은 코드예요", slow = "조금 뒤에 다시 입력해 주세요", board = "업데이트 소식", codes = "지금 쓸 수 있는 코드" },
}
