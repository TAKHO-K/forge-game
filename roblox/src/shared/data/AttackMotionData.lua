-- 직업별 평타 표시 수치(14-2 → W1). W1부터 스윙 포즈 · 시각은 PlayerMotionData(관절 포즈 클립) + MotionTiming(타격 프레임 = 서버 원거리 발사 시각)이 맡는다 -
-- 옛 무기 회전 키프레임(parts · armSwing · releaseT · totalDurationSeconds)은 삭제. 여기는 검기(Trail) 색 · 굵기와 MV1 공중 공격 몸 자세만 남는다.
--   air = MV1 공중 공격(사용자 - 임시 → W1 팔 포즈는 PlayerMotionData.weapons[직업].air):
--     bodyPitchDeg = 몸을 앞으로 싣는 각(AirMotion lean) · bodySpinDeg = 제자리 회전(AirMotion spin) · hoverSeconds = 원거리 공중 정지(프레야식 - AirHover · 서버 AttackServer가 대공 잡기 체공으로 적는다).
-- MV1: 무기 5종째 방패망치(머리 위 내려치기)는 아직 직업 · 무기 데이터가 없다 - 생기면 그 직업 표에 air = { bodyPitchDeg = 24 }(대검과 같은 틀)을 넣는다.
return {
	greatsword = {
		air = { bodyPitchDeg = 24 }, -- 공중 내려찍기(몸을 앞으로 싣는다)
		trailWidth = 1.4,
		trailColor = Color3.fromRGB(220, 235, 255),
	},
	dualblade = {
		air = { bodySpinDeg = 360 }, -- 공중 회전 베기(몸 한 바퀴)
		trailWidth = 0.6,
		trailColor = Color3.fromRGB(200, 245, 245),
	},
	bow = {
		air = { bodyPitchDeg = 22, hoverSeconds = 0.25 }, -- 프레야식: 짧게 멈춰 앞으로 숙여 아래로 쏜다(활 겨눔 = PlayerMotionData.weapons.bow.air)
	},
	healer = {
		air = { bodyPitchDeg = 22, hoverSeconds = 0.25 }, -- 공중 영창 후 아래로 발사
		trailWidth = 0.5,
		trailColor = Color3.fromRGB(230, 200, 255),
	},
}
