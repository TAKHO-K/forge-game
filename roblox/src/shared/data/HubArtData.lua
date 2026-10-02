-- QUEUE-ALL7B 3 허브 건물 · NPC 겉모습(ArtStyleV1 켬일 때만 - 끄면 지금 상자 · 자리 기둥 그대로).
--   건물 = WorldMapData facilities row.buildings(크기 = HubArtMeta - 생성 표) · NPC · 게시판 = 자리(spot) 기둥 자리에 메시를 세운다(기둥 = 투명 · 충돌 끔 · 프롬프트 · 이름표 자리 그대로).
--   motion = 대기 동작 한 가지(부위 묶음이 관절(HubArtMeta pivots)을 축으로 offset + amp × sin(2π t / period) 도) - 클라 client/HubNpcView가 가까울 때만 돌린다.
--   축: X + = 팔이 앞(−Z)으로 · Z + = 오른팔이 바깥(+X)으로 · Y + = 고개를 왼쪽으로.
local HEAD = { "Head", "Face", "Hat", "Plume" }
return {
	folder = "HubArt", -- Workspace 아래 메시 모델 폴더(서버 server/HubArt)
	motionRadius = 150, -- 이 거리 안 NPC만 움직인다(stud)
	tagGap = 1.4, -- 이름표 = 메시 꼭대기 + 이만큼 · 기능 아이콘은 그 위 iconGap
	iconGap = 3.4,
	npcs = {
		{ id = "smith", model = "props/npc_smith", spot = "smith", motion = {
			{ parts = { "ArmR", "ToolR" }, pivot = "ArmR", axis = "X", offset = 25, amp = 35, period = 1.1 }, -- 망치질
			{ parts = HEAD, pivot = "Head", axis = "X", offset = 6, amp = 4, period = 1.1 },
		} },
		{ id = "merchant", model = "props/npc_merchant", spot = "shop", motion = {
			{ parts = { "ArmR" }, pivot = "ArmR", axis = "Z", offset = 30, amp = 18, period = 1.4 }, -- 손님 부르기
			{ parts = HEAD, pivot = "Head", axis = "Y", offset = 0, amp = 12, period = 3.2 },
		} },
		{ id = "tailor", model = "props/npc_tailor", spot = "tailor", motion = {
			{ parts = { "ArmR", "ToolR" }, pivot = "ArmR", axis = "X", offset = 35, amp = 10, period = 0.55 }, -- 가위질
			{ parts = HEAD, pivot = "Head", axis = "X", offset = 10, amp = 3, period = 2.2 },
		} },
		{ id = "knight", model = "props/npc_knight", spot = "challengeKnight", motion = {
			{ parts = HEAD, pivot = "Head", axis = "Y", offset = 0, amp = 18, period = 4.5 }, -- 둘러보기
			{ parts = { "ArmL", "ToolL" }, pivot = "ArmL", axis = "X", offset = 8, amp = 3, period = 3 },
		} },
		{ id = "keeper", model = "props/npc_keeper", spot = "noticeBoard", offset = { 5.5, -1.5 }, motion = {
			{ parts = { "ArmR", "ToolR" }, pivot = "ArmR", axis = "X", offset = 40, amp = 8, period = 2 }, -- 두루마리 보이기
			{ parts = HEAD, pivot = "Head", axis = "X", offset = 0, amp = 5, period = 2 },
		} },
	},
	props = {
		{ id = "board", model = "props/hub_board", spot = "noticeBoard" }, -- 마을 게시판(소식 빌보드 · 코드 프롬프트 자리)
	},
	-- 대장간 굴뚝 연기(HubArtMeta chimney 자리 · 연출 세기 꺼짐이면 끈다 - 클라 FxLevel은 남의 효과만이라 여기선 서버 한 번)
	smoke = { rate = 4, lifetime = { 2.5, 4 }, speed = { 2, 3.5 }, size = { 1.6, 4.2 }, rgb = { 196, 194, 200 }, transparency = { 0.35, 1 } },
}
