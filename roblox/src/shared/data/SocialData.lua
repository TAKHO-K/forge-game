-- 소셜 값(S12b) - 이름 표시 형식 · 머리 위 이름표 · 장비 보기 조회 제한 · 귓속말 명령. UI 표시 값이라 밸런스 수치는 없지만 core 코드에 박지 않으려고 여기 둔다.

return {
	-- 이름 표시: "★n Lv.35 표시이름". ★n · Lv 부분은 이름보다 한 단계 작은 글씨(sizeSteps에서 바로 아래 단 - 12 미만은 없다) + 다른 색.
	label = {
		sizeSteps = { 20, 16, 14, 12 }, -- Theme.text(title · header · body · caption)와 같은 4단
		levelColorName = "textSecondary",
		rebirthColorName = "gold",
		levelFormat = "Lv.%d",
		rebirthFormat = "★%d",
	},

	-- 머리 위 이름표(커스텀 BillboardGui). 기본 이름표(Humanoid.DisplayDistanceType)는 끈다. 이름표는 클릭이 없다(오터치 방지).
	nameplate = {
		maxDistanceStuds = 60,
		offsetStuds = 3.4, -- 머리 위(HumanoidRootPart 기준)
		width = 240,
		height = 26,
		textSize = 16, -- 이름 글씨 단(header) - Lv 부분은 label.sizeSteps로 한 단계 아래
	},

	-- 장비 보기 서버 조회: 같은 요청자의 연속 요청 사이 최소 간격(초).
	inspect = {
		minIntervalSeconds = 0.5,
	},

	-- 귓속말: TextChatService 기본 명령. 입력창에 "<명령> <표시이름> "을 채우기만 한다(문자열을 서버로 보내지 않는다 - 채팅 필터 정책).
	whisper = {
		command = "/w",
	},
}
