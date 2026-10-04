-- 게임 이름(고유명). 화면에 게임 이름을 쓰는 곳은 전부 여기서 읽는다(지금 = 메인 메뉴 로고 자리 - 클라 MainMenu가 플레이어 언어로 고른다).
--   사용자 10-04 확정: 한국어 "전설을 넘어서" · 영어 "Beyond Legendary". 게임 안에는 태그 없이 이름만(로블록스 홈 제목 태그 [⚔️강화 RPG] · [⚔️Upgrade RPG]는
--   Creator Hub에서 사용자가 입력 - 코드에 넣지 않는다). names에 없는 언어 = name(기본 = 한국어).
--   "NAME" = 이름 미정 자리값 - tools/i18n/check_textdata.py가 name == placeholderName이면 경고.
return {
	name = "전설을 넘어서",
	names = { ko = "전설을 넘어서", en = "Beyond Legendary" },
	placeholderName = "NAME", -- 자리값 판별용(검사 도구가 name과 비교)
}
