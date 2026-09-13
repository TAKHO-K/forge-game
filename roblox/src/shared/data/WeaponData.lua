-- 무기 정의. 웹 v1엔 무기 등급(grade) 개념이 없다(장비 등급은 갑옷/장갑/신발에만 있다,
-- data/items.js ITEM_GRADES) - 무기 등급 축은 10-2 작업 지시([1])로 새로 만든 것이다.
--
-- 20-1부터 등급은 무기 정의(정적)가 아니라 저장 데이터(classes[classId].weapon.grade,
-- 0~6)에 있다 - 환생으로 오르는 값이라 강화 단계(level)와 같은 성격이다(PRD 20.38 [2]).
-- 그래서 이 파일엔 더 이상 grade/gradeMultiplier 필드가 없다 - 등급 배율은
-- PlayerCombat.getAttack이 ArmorData.gradeOrder(순서)+ItemVisualData.gradeVisuals[].
-- statMultiplier(배율, 1.0/1.4/2.0/3.0/4.5/8.0/15.0)에서 직접 읽는다. ArmorData.grades[].
-- defenseGradeMultiplier는 쓰지 않는다 - 그건 방어력 감소율 앵커에서 역산된 값이라
-- 공격력에 쓸 근거가 없다(PRD 20.38 지시).
--
-- starterId: 신규 프로필에 지급하는 기본 무기(SaveSystem.defaultProfile/migrate가 참조).
-- weapons: id -> 정의. PlayerProfile에는 {id, level, grade}만 저장하고(강화 단계·등급은
-- 계속 바뀌는 값이라 저장 대상, 나머지는 여기서 매번 조회하는 정적 데이터) 여기 없는
-- 필드를 저장에 중복해서 넣지 않는다.

return {
	starterId = "starter_sword",

	weapons = {
		starter_sword = {
			id = "starter_sword",
			displayName = "기본 무기",
			-- CombatConfig.playerAttackPower(=10)에 있던 캐릭터 고유 공격력을 무기 기반값으로
			-- 옮겼다(10-2 [1]) - 이제 공격력은 무기 기본값×등급 배율×강화 배율×클래스 배율이다.
			baseAttack = 10,
		},
	},
}
