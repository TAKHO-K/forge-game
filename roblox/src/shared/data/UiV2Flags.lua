-- UI-1 묶음별 켜고 끄기(CC-UI-1 §1-2): 기본 켬 · false = 옛 UI로 돌아감(비교 · 되돌리기용 - 옛 코드는 지우지 않는다).
return {
	hud = true, -- 0 · 2단계: 02 v6 배치(폰 전투 버튼 = UiLayoutData.hud.phone.combat · 우리 점프 · 기본 점프 숨김) · B v2 스킬 칸 · 보스 바 위 가운데
	status = true, -- 1단계: A 상태 아이콘 줄(StatusIconData)
	boss = true, -- 3단계: F 보스 창(진입 카드 · 2폼 카드 · 첫 만남 카드 · 잔류 선택)
	bag = true, -- 4단계: C 가방 · 장비
	codex = true, -- 5단계: D 도감
	enhance = true, -- 6단계: E 강화 불씨
	auto = true, -- 7단계: F 자동 창(출석 + 시즌판 · 선물함 순서)
	map = true, -- 7b단계: G 지도 · 구역 선택 · 보스 관문 · 더보기 · 설정 · HUD 편집
	rest = true, -- 7c단계: H 알 · 펫 · 캐릭터 · 수련 · 퀘스트 · 파티 · 순위 · 상점
}
