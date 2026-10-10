-- QUEUE-MENU2 B: 캐릭터 칸(슬롯) 저장 - 계정 키 1개(공유 + 칸 목록 + 보관 목록) + 캐릭터 키 칸당 1개. 분류 근거 = docs/design/menu2-survey.md · docs/design/menu2-slot-save.md.
--   메모리 안 프로필 모양은 그대로(옛 단일 프로필) - 저장할 때만 나누고 읽을 때 합친다(server/SlotSave). 여기 없는 최상위 필드 = 전부 계정 키.
return {
	enabled = true, -- 스위치 SlotSave: 끄면 옛 경로(Player_<id> 한 키) - 켜 둔 동안 진행은 끌 때 옛 모양으로 합쳐 읽는다(손실 0 · SlotSave.mergeToLegacy)
	mergeOnDisable = true, -- 끈 경로가 접속마다 계정 키를 확인해 합친다(읽기 +1) - 슬롯을 한 번이라도 켠 게임은 켜 둔다
	legacyRecheck = false, -- 운영: 껐다가 다시 켤 때 true(그동안 옛 키에 쌓인 진행을 다시 이관) - 평소 false(접속 읽기 = 계정 + 캐릭터 2회 · 옛 키는 계정 키가 없을 때만)

	accountKeyPrefix = "Acct_", -- Acct_<UserId>
	characterKeyPrefix = "Char_", -- Char_<UserId>_<번호>(50자 이하)
	maxArchive = 10, -- 보관(삭제 대신) 최대
	windowSlideSeconds = 0.25, -- 이어하기 창 펼침
	numberGlyphs = { "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩" }, -- 같은 직업 번호(전사 ① · 전사 ②)
	-- 서버 거절 이유 → 글 키(menu.slot.err.<이유> · 메뉴 이동 금지 = menu.toMenuBlocked.<이유>) - 목록 밖 = menu.slot.err.default
	errorReasons = { full = true, boss = true, inherit = true, too_fast = true, busy = true, save_failed = true, load_failed = true, current = true, archive_full = true },
	blockReasons = { boss = true, inherit = true, enhance = true, craft = true, gift = true, trade = true },
	-- MENU2 판정 4(10-05): 처리 직후 메뉴 이동 금지 시간(연출 길이 + 여유 · server/MenuBlock) - 강화 결과 굴림 ≤ 0.8 · 재련 · 계승 연출 · 선물 받기 팝업
	blockAfterSeconds = { enhance = 1.5, craft = 1.5, inherit = 4, gift = 2, trade = 2 },
	lockedPreviewSlots = 1, -- 이어하기 창 끝 잠긴 칸("새 직업 출시 때 열림" - 날짜 약속 없음)
	switchMinSeconds = 5, -- 캐릭터 전환(메뉴 왕복) 최소 간격 - UpdateAsync가 읽기 + 쓰기 예산을 둘 다 쓴다

	-- 캐릭터 키로 가는 최상위 필드(사용자 B1 "캐릭터별" - 가방 · 골드 · 강화 · 보석 · 수련 · 계승/초월). 직업 칸 classes[classId]는 따로(그 캐릭터 직업 하나만).
	characterTop = { "gold", "inventory", "materials", "gemDust", "training", "transcendGems" },
	-- 캐릭터 키로 가는 안쪽 필드(부모 표 · 키) - 변환권 = 골드로 사는 보석 계열 · 메인 퀘스트 사슬
	characterNested = {
		{ "purchases", "optionRerollTickets" },
		{ "quests", "main" },
		{ "quests", "mainN" },
	},
	-- 이관(옛 단일 프로필 → 캐릭터): 공유였던 재화 · 수련 = 지금 직업 캐릭터 하나에(복제 방지 - 사용자 10-05 "수련 모든 캐릭터 복사 금지") · 다른 직업 캐릭터 = 그 직업 고유 데이터만
	--   예전 값 { training = true }(수련 모든 캐릭터 복사) - 되살리면 힘 복제
	copyToAllOnMigrate = {},
	-- 새 저장 필드 등록(QUEUE-UI1F · 규칙 = 추가만): path = 프로필 경로("*" = 아무 직업 칸) · scope = account(계정 키) | character(캐릭터 키).
	--   하네스 slot_save가 등록된 필드마다 "분리 → 합치기" 왕복에서 값이 그 범위로 가고 그대로 돌아오는지 본다(등록 없이 더한 필드 = 범위를 아무도 확인 안 함).
	addedFields = {
		{ path = { "settings", "lastSeenNewsId" }, scope = "account", sample = 7, note = "UI1F-1 소식 빨간 점(본 소식 id)" },
		{ path = { "settings", "textScale" }, scope = "account", sample = "xlarge", note = "UI2-2 글자 크기(보통 · 크게 · 아주 크게)" },
		{ path = { "classes", "*", "legacyPlayAdded" }, scope = "character", sample = true, note = "UI1F-1 옛 계정 플레이 시간을 이관 첫 캐릭터에 더함(한 번)" },
		{ path = { "inventory", 1, "obtainedAt" }, scope = "character", sample = 1791600000, note = "UI-1 4단계 장비 얻은 시각(가방 정렬 최신 · 옛 아이템 = 없음 → 가방 순서)" },
		{ path = { "settings", "bagSort" }, scope = "account", sample = "power", note = "UI-1 4단계 가방 정렬" },
		{ path = { "settings", "bagSortAsc" }, scope = "account", sample = true, note = "UI-1 4단계 가방 정렬 낮은 것 먼저" },
		{ path = { "codex", "boxDone", "1" }, scope = "account", sample = 25, note = "UI-1 5단계 도감 진행 상자 열린 스테이지(골드 고정)" },
		{ path = { "codex", "boxClaimed", "1" }, scope = "account", sample = true, note = "UI-1 5단계 도감 진행 상자 받음" },
		{ path = { "codex", "stars", "greatsword", "3" }, scope = "account", sample = 2, note = "UI-1 5단계 도감 성장 별(보상 없음)" },
		{ path = { "settings", "hudLayoutPc" }, scope = "account", sample = "leftMenu:48,120", note = "UI-1 7b HUD 편집 배치 PC(id:x,y;…)" },
		{ path = { "settings", "hudLayoutPhone" }, scope = "account", sample = "nextGoal:520,120", note = "UI-1 7b HUD 편집 배치 폰" },
		{ path = { "settings", "hudLayoutVersion" }, scope = "account", sample = 1, note = "UI-1 7b HUD 배치 형식 번호" },
		{ path = { "settings", "showKeys" }, scope = "account", sample = false, note = "UI-1 7b 단축키 표시" },
		{ path = { "settings", "vibrationOff" }, scope = "account", sample = true, note = "UI-1 7b 진동 끔" },
	},
	-- 진행이 없는 직업 칸은 캐릭터로 만들지 않는다: 경험치 0 · 최고 스테이지 ≤ 1 · 환생 0 · 무기 +0 · 등급 0 · 착용 장비 없음 · 보석 없음
}
