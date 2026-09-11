-- UI 공통 색 팔레트(16-1 [5]). 지금까지 client/*.lua 18개 파일에 Color3.fromRGB(...)가
-- 60회 흩어져 있었고(패널 배경만도 (30,30,30)/(25,25,30)/(20,20,25) 세 가지로 갈려 있었다) -
-- 여기 한 번만 정해두면 16-3부터 만들 창(아이템창·강화대·설정창 등)이 전부 이 값을 참조할
-- 수 있다. 등급 색 7단계(14-1, ItemVisualData.gradeVisuals)는 "아이템 등급"이라는 별도 축이라
-- 건드리지 않는다 - 여기 팔레트는 그 등급 색과 나란히 참조되는 UI 뼈대 색이다.
return {
	background = Color3.fromRGB(18, 18, 22), -- 화면 밑바탕 기준점(패널이 없는 곳)
	panel = Color3.fromRGB(28, 28, 34), -- 패널 배경 통일값. 기존 세 값의 중간대로 잡았다.
	panelTransparency = 0.15,
	border = Color3.fromRGB(70, 70, 84),
	accent = Color3.fromRGB(255, 196, 60), -- 골드(10-1)와 같은 색조 - "보상·강조"를 한 색으로.
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(190, 190, 200),
	danger = Color3.fromRGB(224, 64, 64),
	success = Color3.fromRGB(96, 200, 120),
}
