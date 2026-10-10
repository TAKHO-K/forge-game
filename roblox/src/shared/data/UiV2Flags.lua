-- UI-1 묶음별 켜고 끄기(CC-UI-1 §1-2): 기본 켬 · false = 옛 UI로 돌아감(비교 · 되돌리기용 - 옛 코드는 지우지 않는다).
return {
	hud = true, -- 0 · 2단계: 02 v6 배치(폰 전투 버튼 = UiLayoutData.hud.phone.combat · 우리 점프 · 기본 점프 숨김) · B v2 스킬 칸 · 보스 바 위 가운데
	status = true, -- 1단계: A 상태 아이콘 줄(StatusIconData)
	parts = true, -- 1단계: A 공용 부품(토글 그림 스위치 · 게이지 · 배너 · 전투 문구 · 빈 상태)
	boss = true, -- 3단계: F 보스 창(진입 카드 · 2폼 카드 · 첫 만남 카드 · 잔류 선택)
	bag = true, -- 4단계: C 가방 · 장비
	codex = true, -- 5단계: D 도감
	enhance = true, -- 6단계: E 강화 불씨
	auto = true, -- 7단계: F 자동 창(출석 + 시즌판 · 선물함 순서)
	map = true, -- 7b단계: G 지도 · 구역 선택 · 보스 관문 · 더보기 · 설정 · HUD 편집
	text = true, -- UI-1b 1절 1: 글자 한 단계 키움(새 보통 = 옛 크게 ×1.15 · UiTokens.textBase · 최소 PC 본문 18 · 작은 15 / 폰 14 · 12) - 끔 = 옛 크기
	topbarBoss = true, -- UI-1b 1절 2(I v1 spec 0-3): 보스 바 = 로블록스 상단 바 가운데 빈 칸 안(GuiService.TopbarInset) - 끔 = UI-1 v6 자리(위 가운데 · 상단 바 아래)
	chipsV9 = true, -- UI-1b 1절 16(I v1 0-4): HUD 오른쪽 위 칩 = 높이 52 · 아이콘 36 · 이름 + 숫자 · 누르면 설명(hud/InfoChipsV9) - 끔 = 옛 칩
	enhanceBig = true, -- UI-1b 1절 15: 강화대 빠른 창 1.3배 · "유물 무기" 줄 없앰 · 재화 = 큰 아이콘 + "골드" + 누르면 설명 - 끔 = UI-1 크기
	layers = true, -- UI-1b 1-b 10: 창 층 표 하나(창 = HUD 메뉴 위 · 나중에 연 창이 위 · 창 Gui ZIndex 방식은 그대로) - 끔 = 옛 층(메뉴 150 · 출석 · 관문 160)
	help = true, -- UI-1b 1절 3: 지엽적 설명 줄 = 창 제목 옆 [?](HelpButton · HelpData) - 끔 = 설명 줄 그대로
	autoSplit = true, -- UI-1b 1-b 11 · 12(사용자 결정 - F "한 창 탭 2" 대체): 자동 창 = 따로 순서대로(첫 접속 7일 보상 → 접속 보상 → 시즌 출석판 → 선물함) · [오늘 하루 보지 않기] · 보상 칸 누르면 설명 - 끔 = UI-1 탭 2 창
	map1b = true, -- UI-1b 1-b 14: 지도 버튼 열 = 지도 판 밖 오른쪽 세로 · 안 가 본 구역 흐림 옅게 · 핀 흰 테 + 그림자 · 핀과 겹치는 구역 이름 비켜 놓기 - 끔 = UI-1 7b
	trainBundle = true, -- UI-1b 1-b 17: 수련 · 직업 능력 = 한 번 누름에 여러 내부 레벨 묶음(수련 +1% · 능력 +5% · 비용 = 합 · 저장 · 상한 그대로) - 끔 = 한 단계씩
	codexNewLook = true, -- UI-1b 1-b 18: 도감 보기 = 새 모습(보스 = F 초상 · 무기 = 새 v4 메시만 - 캐시에 없으면 새 도감 그림) · live 스위치와 무관(보기 전용) - 끔 = 옛 3D
	eggNo = true, -- UI-1b 1-b 19: 탐험의 알 = 위치 안내 없음(길 안내 · 지도 조각) · 힌트 = 구역만 · 이름 = "구역 n번 ✔" - 끔 = 비밀 둥지 n · 길 안내
	rest = true, -- 7c단계: H 알 · 펫 · 캐릭터 · 수련 · 퀘스트 · 파티 · 순위 · 상점
}
