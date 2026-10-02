-- QUEUE-ALL8 C 허브 3D 이름표 규칙(client/HubLabelView). 거리 = 내 캐릭터에서 이름표 자리까지(stud · 수평 아님 - 3D).
--   종류: function = 기능 자리(재련대 · 게시판 · 강화대 …) · npc = 사람 자리(대장장이 · 재봉사 · 도전 기사 · 보석상인) · building = 포탈 안내판 · street = 거리 · 광장 이름(Facility).
--   거리: near 안 = 이름 + 아이콘 · near ~ far = 아이콘만(아이콘 없는 이름표 = 숨김 · building 안내판 = 글 자체가 표지라 far까지) · far 밖 = 거리 이름만(streetFarScale로 작게).
--   겹침: 화면 상자가 겹치면 priority 작은 쪽(먼저)만 · 같으면 가까운 쪽 · 바뀐 상태가 holdSeconds 이어져야 바꾼다(깜빡임 막기) · 나타남 · 사라짐 = fadeSeconds.
return {
	nearStuds = 40,
	farStuds = 120,
	fadeSeconds = 0.2,
	holdSeconds = 0.3,
	updateHz = 10, -- 거리 · 겹침 판정 횟수(투명도 보간 = 매 프레임)
	overlapPadPx = 4, -- 화면 상자끼리 이만큼 떨어져야 안 겹친다
	priority = { ["function"] = 1, npc = 2, building = 3, street = 4 },
	streetFarScale = 0.72,
	npcSpots = { smith = true, tailor = true, challengeKnight = true }, -- 자리 이름표가 NPC 머리 위(나머지 자리 = 기능)
	nameplates = { -- 자리 기둥이 아닌 이름표(NameplateGui · 모델 이름 = 종류)
		EnhanceStation = "function",
		RebirthAltar = "function",
		GemMerchant = "npc",
	},
	portalSignFolder = "PortalSignsLocal", -- 포탈 안내판(클라가 만든다) = building
	-- C3 폰(터치 배치): 이름표 크기 배율 · 글자 상한(843 × 592 캡처 기준 - 큰 글자가 거리 하나를 덮었다)
	phone = { scale = 0.8, maxTextSize = 15 },
	maxTextSize = 22, -- PC 상한(TextScaled가 칸 높이만큼 커진다)
	-- C4 업데이트 소식 = 마을 게시판 메시 판면(SurfaceGui · client/UpdateBoard): 줄 수 상한(넘으면 마지막 줄 = "더 보기" - 누르면 전체 창)
	board = { maxLines = 4, pixelsPerStud = 50, titleSize = 26, lineSize = 17 },
}
