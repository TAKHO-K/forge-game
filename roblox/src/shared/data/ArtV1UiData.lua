-- A2-N2 2-5 UI 등급 프레임 8종(ArtStyleV1 스위치 뒤 · 코드 테두리 · 그라데이션 - client/GradeFrame). 아이콘 이미지는 가져오기 뒤(지금은 프레임만).
--   사다리: 등급이 오를수록 테두리 두께 · 그라데이션 · 움직임이 한 겹씩 쌓인다(무기 사다리와 같은 누적 언어). 색 = ItemVisualData 등급 색(여기 없음 · 초월만 흑금 전용).
--   thickness = UIStroke 두께 · sheen = 테두리 위 밝은 띠(UIGradient 두 색 - 등급 색 → 흰 쪽 섞기 비율) · spin = 띠가 도는 속도(도/초 · 0 = 멈춤) · fill = 칸 배경을 등급 색 쪽으로 섞는 비율 · glow = 바깥 빛(0 ~ 1)
local C = Color3.fromRGB

return {
	grades = {
		normal = { thickness = 1.5, sheen = 0, spin = 0, fill = 0.03, glow = 0 },
		rare = { thickness = 2, sheen = 0.35, spin = 0, fill = 0.06, glow = 0 },
		epic = { thickness = 2, sheen = 0.45, spin = 0, fill = 0.08, glow = 0.15 },
		legendary = { thickness = 2.5, sheen = 0.55, spin = 40, fill = 0.1, glow = 0.25 },
		relic = { thickness = 2.5, sheen = 0.6, spin = 60, fill = 0.12, glow = 0.3 },
		ancient = { thickness = 3, sheen = 0.6, spin = 80, fill = 0.14, glow = 0.38 },
		primordial = { thickness = 3, rainbow = true, spin = 90, fill = 0.1, glow = 0.45 }, -- 무지개 흐름(기존 태초 규칙)
		transcendent = { thickness = 3.5, blackGold = true, spin = 70, glow = 0.5 }, -- 흑금: 검은 칸 + 금 테두리 위를 도는 흰금 빛 + 금 숨쉬기
	},
	blackGold = {
		cell = C(24, 22, 32), gold = C(214, 176, 62), shine = C(255, 236, 170), dark = C(92, 72, 24),
		breatheHz = 0.6, -- 금빛 숨쉬기(바깥 빛 투명도가 오르내린다)
	},
	glowPad = 8, -- 바깥 빛 여백(px)
}
