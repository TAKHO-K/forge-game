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
			--
			-- 21-2 [1]: 10 → 27.1 (×k^6.93 = ×2.71, PRD-forge-game-roblox.md 20.44 [2] 조정안 (가)).
			-- 이유: 앵커 곡선 측정에서 처치 2.5초 곡선이 rec(L)=L−6.93인데 생존 7타(α, 17-1)는
			-- S=L에 앵커돼 있어, 처치 곡선 위에서는 생존이 39타였다 - S=L−7에서는 감소율 0이어도
			-- 7.8타를 버텨 방어력 시스템 전체가 무의미한 구간이었다. α로는 못 고치고(두 목표가
			-- 서로 다른 곡선), 공격력만 올리면 방어·최대체력(무기와 무관)은 그대로인 채 처치
			-- 곡선이 7스테이지 위로 올라와 rec(L)=L에서 두 목표가 만난다. 무기 등급 배율·강화
			-- 배율은 그대로다(PlayerCombat.getAttack이 이 값에 곱하는 구조 그대로). 파생 영향
			-- (판매가·경험치·보스 HP·강화 비용·골드)은 20.45 [1] 참고 - 전부 몬스터 HP/골드
			-- 기준이라 이 값에 안 걸리고, 레벨당 25마리(CharacterLevelConfig)는 S=L에서만
			-- 성립하는 식이라 오히려 이 조정으로 복구된다.
			baseAttack = 27.1,
		},
	},
}
