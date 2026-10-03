-- 게임 이름(고유명 - 언어와 무관하게 한 값). 화면에 게임 이름을 쓰는 곳은 전부 여기서 읽는다(지금 = 메인 메뉴 로고 자리).
--   "NAME" = 이름 미정 자리값(사용자 10-04) - tools/i18n/check_textdata.py가 남아 있으면 경고 · 출시 전 점검(docs/phase/launch-checklist.md)에서 확정 후 교체.
return {
	name = "NAME",
	placeholderName = "NAME", -- 자리값 판별용(검사 도구가 name과 비교)
}
