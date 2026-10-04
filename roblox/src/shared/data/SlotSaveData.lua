-- QUEUE-MENU2 B: 캐릭터 칸(슬롯) 저장 - 계정 키 1개(공유 + 칸 목록 + 보관 목록) + 캐릭터 키 칸당 1개. 분류 근거 = docs/design/menu2-survey.md · docs/design/menu2-slot-save.md.
--   메모리 안 프로필 모양은 그대로(옛 단일 프로필) - 저장할 때만 나누고 읽을 때 합친다(server/SlotSave). 여기 없는 최상위 필드 = 전부 계정 키.
return {
	enabled = true, -- 스위치 SlotSave: 끄면 옛 경로(Player_<id> 한 키) - 켜 둔 동안 진행은 끌 때 옛 모양으로 합쳐 읽는다(손실 0 · SlotSave.mergeToLegacy)
	mergeOnDisable = true, -- 끈 경로가 접속마다 계정 키를 확인해 합친다(읽기 +1) - 슬롯을 한 번이라도 켠 게임은 켜 둔다
	legacyRecheck = false, -- 운영: 껐다가 다시 켤 때 true(그동안 옛 키에 쌓인 진행을 다시 이관) - 평소 false(접속 읽기 = 계정 + 캐릭터 2회 · 옛 키는 계정 키가 없을 때만)

	accountKeyPrefix = "Acct_", -- Acct_<UserId>
	characterKeyPrefix = "Char_", -- Char_<UserId>_<번호>(50자 이하)
	maxArchive = 10, -- 보관(삭제 대신) 최대
	switchMinSeconds = 5, -- 캐릭터 전환(메뉴 왕복) 최소 간격 - UpdateAsync가 읽기 + 쓰기 예산을 둘 다 쓴다

	-- 캐릭터 키로 가는 최상위 필드(사용자 B1 "캐릭터별" - 가방 · 골드 · 강화 · 보석 · 수련 · 계승/초월). 직업 칸 classes[classId]는 따로(그 캐릭터 직업 하나만).
	characterTop = { "gold", "inventory", "materials", "gemDust", "training", "transcendGems" },
	-- 캐릭터 키로 가는 안쪽 필드(부모 표 · 키) - 변환권 = 골드로 사는 보석 계열 · 메인 퀘스트 사슬
	characterNested = {
		{ "purchases", "optionRerollTickets" },
		{ "quests", "main" },
		{ "quests", "mainN" },
	},
	-- 이관(옛 단일 프로필 → 캐릭터): 공유였던 재화는 지금 직업 캐릭터 하나에(복제 방지) · 수련은 이관되는 모든 캐릭터에 복사(지금 각 직업이 누리던 힘 유지)
	copyToAllOnMigrate = { training = true },
	-- 진행이 없는 직업 칸은 캐릭터로 만들지 않는다: 경험치 0 · 최고 스테이지 ≤ 1 · 환생 0 · 무기 +0 · 등급 0 · 착용 장비 없음 · 보석 없음
}
