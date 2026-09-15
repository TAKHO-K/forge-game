-- 무기 보석 슬롯 데이터(23-2, PRD-forge-game-roblox.md 20.38 [2]). 밸런스 수치를 새로
-- 만들지 않는다는 지시에 따라, 여기 있는 값은 전부 구조 정의(어느 슬롯이 어느 등급인가)와
-- 기존 표(ArmorData.gradeOrder, PRD-forge-game.md 7.3-2)를 그대로 옮긴 이름뿐이다 - 숫자
-- 배율은 Gem.lua가 ItemVisualData.gradeVisuals(statMultiplier)에서 매번 계산한다(단일 출처).

return {
	-- 환생 5회 = 슬롯 5칸(1:1). slot i(1~5)가 열리는 시점 = 환생 i회, 그 슬롯이 받는 보석
	-- 등급은 상위 5등급(ArmorData.gradeOrder의 영웅~태초)을 그대로 오름차순으로 배정한다
	-- (20.38 [2] 표 - "우연이 아니라 상위 5등급 중 다섯 번째"). 하위 2등급(일반·희귀)엔
	-- 대응하는 슬롯이 없다.
	maxRebirthCount = 5,
	slotGradeOrder = { "epic", "legendary", "relic", "ancient", "primordial" },

	-- 고대·태초 전용 특수 옵션 이름 풀(PRD-forge-game.md 7.3-2 무기 행 4개 그대로 재사용).
	-- 원 설계는 이 넷이 각자 다른 "규칙형" 전투 로직(예: 연속격 = 3타 강타 발동 간격 변경)을
	-- 갖지만, 그 문서 자체가 "목록·방향 확정, 수치는 전부 TBD"라 이번 세션은 이름(정체성)만
	-- 무작위로 배정하고 실제 효과는 Gem.attackPercentBonusForGrade의 공통 수치로 대체한다 -
	-- 보수적 기본값 원칙(지시 그대로), 근거는 보고서 "임의 결정" 목록 참고. 영웅·전설·유물
	-- 등급(슬롯1~3)엔 옵션 풀이 없다 - purchases.optionRerollTickets 자체가 ancient/
	-- primordial 두 종류뿐이라(20.37 [6] 저장 스키마), 옵션 변환권으로 바꿀 대상이 애초에
	-- 이 두 등급에만 있다는 뜻이다.
	optionPoolByGrade = {
		ancient = { "연속격", "속사의 흔적" },
		primordial = { "심판의 표식", "삼위일체" },
	},

	-- 옵션 변환권 가격 배수(20.37 [5] "가격 = 그 순간 몬스터 1마리당 골드 × N, N≈30~50 -
	-- 정확한 N은 구현 후 실측"). 40은 그 범위의 중간값이다 - PRD가 이미 준 범위 안에서 고른
	-- 확정값이라 새 밸런스 상수를 만든 게 아니다(보고서 "임의 결정" 목록 참고). 서버
	-- (GemServer.server.lua)와 클라이언트(EnhanceUI.client.lua 표시용) 둘 다 이 값 하나만
	-- 본다 - 가격 계산 자체는 여전히 서버가 매번 다시 한다(클라이언트 값을 믿지 않는다).
	rerollTicketGoldMultiplier = 40,
}
