-- 사냥터 좌표계·환산 기준. 밸런스 수식(감소율·등급 배율 등)은 여기 없다 - 그건 전투가 생길 때 넣는다.

return {
	-- 1 stud = 웹 10px. 기준: 로블록스 기본 캐릭터(R15) 너비 약 4stud(반지름 2stud) vs
	-- 웹 playerRadius=20px(지름 40px) -> 40px/4stud = 10px/stud.
	-- 사거리·투사체 속도 등 나머지 픽셀 값은 지금 환산하지 않는다. 이 비율만 기록해 둔다.
	pxPerStud = 10,

	huntingGround = {
		center = Vector3.new(0, 0, 0),
		size = Vector3.new(100, 2, 100), -- 몬스터가 추격할 여유를 둔 잠정 크기
	},

	-- 사냥터 중심 기준 XZ 오프셋. Y는 스크립트가 바닥 위 높이로 계산한다.
	playerSpawnOffset = Vector3.new(0, 0, -35),
	monsterSpawnOffset = Vector3.new(15, 0, 15),
}
