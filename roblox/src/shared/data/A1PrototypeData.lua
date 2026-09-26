-- A1 시제품(기술 검증 - 완성 에셋 아님) 치수 · 색. server/A1Prototypes가 읽는다(/gg a1 <이름>). art-spec 3 · 4 · 5장 수치를 옮겼다(키 = 스터드).
local function rgb(hex)
	return Color3.fromHex(hex)
end

return {
	-- 이끼 슬라임(art-spec 3장 T1): 키 3.0 · 반구 몸 2조각(위 · 아래) + 이끼 모자 3 · 관절 Root, Top · 대비 포인트 = 눈
	mossSlime = {
		height = 3.0, width = 3.4,
		body = rgb("#63C977"), bodyShade = rgb("#3F9A5A"), moss = rgb("#4E9A3A"), eye = rgb("#1E1B2E"), eyeShine = rgb("#FFFFFF"),
		squash = { downScaleY = 0.72, downScaleXZ = 1.18, seconds = 1.0 }, -- 전조: 납작 찌부(1.0초)
	},
	-- 구간 수호자(art-spec 4장): 키 16 · 파트 + Motor6D · Head, Shoulder_R, Hand_R(잡기), Hand_L
	guardian = {
		height = 16,
		body = rgb("#5C6E5A"), stone = rgb("#A8A29A"), rune = rgb("#5CE08A"), eye = rgb("#FFD34D"),
		-- 달려와서 낚아채기(기술 검증 모션): 키프레임 = 시각(초) · 관절 각(도)
		grabKeys = {
			{ t = 0.0, name = "달림", rootLean = 12, shoulderR = -35, elbowR = 20, shoulderL = 35, crouch = 0, reach = 0 },
			{ t = 0.6, name = "몸 낮춤", rootLean = 28, shoulderR = -10, elbowR = 60, shoulderL = 20, crouch = 2.5, reach = 0 },
			{ t = 1.0, name = "Hand_R 뻗음", rootLean = 34, shoulderR = -95, elbowR = 5, shoulderL = 10, crouch = 3, reach = 3 },
			{ t = 1.3, name = "잡음", rootLean = 20, shoulderR = -70, elbowR = 70, shoulderL = 10, crouch = 1.5, reach = 1 },
			{ t = 2.0, name = "복귀", rootLean = 0, shoulderR = 0, elbowR = 0, shoulderL = 0, crouch = 0, reach = 0 },
		},
	},
	-- 전갈 여왕 꼬리(art-spec 4장): Bone 체인 8마디(필수) · 부착점 A(끝 = 8) · B(중간 = 5) · C(밑 = 2)
	scorpionTail = {
		segments = 8, segmentLength = 2.4, segmentWidth = 1.6, curlDegPerBone = -22, -- 음수 = 위로 말림(A1 실측)
		attach = { A = 8, B = 5, C = 2 },
		body = rgb("#D9924A"), sting = rgb("#A8612E"), holdColors = { rgb("#4C8DFF"), rgb("#FFD34D"), rgb("#FF4D5A") },
	},
	-- 대검 7등급(art-spec 5장 - 누적 표현 · 색은 ItemVisualData 우선). 길이 5.
	greatsword = {
		length = 5, bladeWidth = 0.9, bladeThick = 0.22, guardWidth = 1.8, gripLength = 1.1, spacing = 3.2,
		steel = rgb("#D8DCE4"), steelShade = rgb("#9AA1AE"), grip = rgb("#5A3A26"), gem = rgb("#FFFFFF"), whiteAura = rgb("#FFFFFF"),
	},
	-- 카툰 풀 소품(잔디 안 B): 3잎 쐐기 덩어리 · 거리 컬링(클라)
	grassClump = { blades = 3, height = 1.6, width = 0.5, color = rgb("#5DAE45"), tip = rgb("#8BD35F"), spacing = 3.5, radius = 40, cullDistance = 80 },
}
