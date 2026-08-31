-- 무기 정의. 웹 v1엔 무기 등급(grade) 개념이 없다(장비 등급은 갑옷/장갑/신발에만 있다,
-- data/items.js ITEM_GRADES) - 무기 등급 축은 10-2 작업 지시([1])로 새로 만든 것이다.
-- 배율 값은 웹 장비 등급표의 관례(normal=1.0)를 그대로 따랐다 - 나중에 무기 드랍이
-- 생기면 이 테이블에 등급을 확장한다.
--
-- starterId: 신규 프로필에 지급하는 기본 무기(SaveSystem.defaultProfile/migrate가 참조).
-- weapons: id -> 정의. PlayerProfile에는 {id, level}만 저장하고(강화 단계는 계속 바뀌는
-- 값이라 저장 대상, 나머지는 여기서 매번 조회하는 정적 데이터) 여기 없는 필드를 저장에
-- 중복해서 넣지 않는다.

return {
	starterId = "starter_sword",

	weapons = {
		starter_sword = {
			id = "starter_sword",
			displayName = "기본 무기",
			grade = "normal",
			gradeMultiplier = 1.0,
			-- CombatConfig.playerAttackPower(=10)에 있던 캐릭터 고유 공격력을 무기 기반값으로
			-- 옮겼다(10-2 [1]) - 이제 공격력은 무기 기본값×강화 배율×등급 배율×클래스 배율이다.
			baseAttack = 10,
		},
	},
}
