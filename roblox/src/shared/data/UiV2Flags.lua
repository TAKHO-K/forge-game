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
	rest = true, -- 7c단계: H 알 · 펫 · 캐릭터 · 수련 · 퀘스트 · 파티 · 순위 · 상점
}
