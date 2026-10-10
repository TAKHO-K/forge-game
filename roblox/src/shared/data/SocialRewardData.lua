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
	-- 코드 표(codes) = server/SocialCodeData로 옮김(SEC-FIX-1 4 - 여기는 클라에 복제돼 공지 전 코드가 보였다 · 옛 자리 남기지 않음). 게시판 = 서버가 공개 코드만 내려줌(BoardCodes).
	groupRewardEnabled = false,
	-- 허브 업데이트 게시판(새 소식 + 지금 유효한 코드 - 만료 지난 코드는 안 보인다)
	nextUpdateKey = "update.board.next", -- QUEUE-ALL9E1-ADD C: 소식 "다음 업데이트" 한 줄(날짜 약속 없음 - 업데이트 때 이 키의 문구만 바꾼다)
	-- id = 소식 번호(새 소식 = 지금 가장 큰 id + 1 · 바꾸지 않는다) → 메인 메뉴 [소식] 빨간 점 = 가장 큰 id > 계정 설정 lastSeenNewsId(QUEUE-UI1F-1)
	news = { -- 글 = TextData textKey(ko/en)
		{ id = 2, date = "2026-10-01", textKey = "update.board.news1" },
		{ id = 1, date = "2026-10-01", textKey = "update.board.news2" },
	},
	text = { ok = "코드 보상: %s", bad = "없는 코드예요", expired = "기한이 지난 코드예요", used = "이미 받은 코드예요", slow = "조금 뒤에 다시 입력해 주세요" }, -- 게시판 제목 · 코드 머리글 = TextData update.board.*
}
