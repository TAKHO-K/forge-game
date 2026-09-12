-- UI 공통 색 팔레트(16-1 [5] 신설 → 16-2에서 `Claude outputs/hud-mockup.html`의 :root 변수값으로
-- 전면 교체). 16-1 값은 색조 3~4개(패널 회색조·금색 하나)로 급조한 것이었고, 이번 목업은
-- "공격 버튼이 플래시 게임 버튼 같다"는 피드백에서 나온 실제 디자인 시안이라 그 hex를
-- 그대로 옮긴다 - 임의로 톤을 더 넣거나 빼지 않았다.
--
-- 16-1 → 16-2 대조(무엇이 왜 바뀌었는지):
--   panel(28,28,34, 반투명0.15) -> panel(12,14,19, 반투명0.28) - 더 어둡고 더 투명해져서
--     "게임 화면이 비쳐야 한다"(지시 2)는 유리질 패널 느낌에 맞다.
--   border(70,70,84 고정) -> rim/rimHi 두 단계 - 목업은 테두리에 밝기가 다른 두 겹(기본 링 +
--     상단 하이라이트)을 쓴다. 하나로 뭉쳐뒀던 걸 실제로 두 톤으로 나눴다.
--   accent(255,196,60) 하나로 골드·경험치·강조를 전부 겸용 -> ember(공격·강조)/gold(재화)/
--     xp(경험치) 세 갈래로 분리 - 목업이 이 세 개를 서로 다른 색으로 명시했다(공격은 주황,
--     골드는 진한 금색, 경험치는 밝은 노랑 - 나란히 놓였을 때 구분이 돼야 하기 때문).
--   textSecondary 한 단계 -> textSecondary/textTertiary 두 단계(목업 ink-2/ink-3) - 칩 보조
--     텍스트("최고 기록", "STAGE" 라벨)처럼 본문보다 한 단계 더 죽여야 하는 자리가 실제로
--     있었다. 두 값 다 CSS rgba(ink, alpha)를 --panel-solid(12,14,19) 위에 얹었을 때의
--     실효색을 미리 섞어 넣은 것 - Roblox TextColor3는 알파를 못 받으므로 결과색을 계산해
--     박아 뒀다(alpha .62 → textSecondary, alpha .34 → textTertiary).
--   danger - 목업에는 "위험" 전용 색이 따로 없다(hp 빨강이 그 역할을 겸한다) - 그래서 hp와
--     같은 값으로 통일했다. 저장 실패 배너(SaveNoticeHud)도 결국 "빨간 경고"라 자연스럽다.
--   success - 유지하되 목업의 --ok 값(53,208,165)으로 갱신.
--
-- 등급 색 7단계(14-1, ItemVisualData.gradeVisuals)는 여전히 별도 축이라 안 건드린다 -
-- 인벤토리 창(16-3)의 칸 테두리는 목업의 --g1~--g6 하드코딩을 쓰지 않고 그 색을 그대로
-- 참조한다(지시 - "단일 출처를 유지한다").
--
-- 16-3 추가분(inventory-mockup.html) - slot/overlayDim 두 값만 새로 늘었다. 나머지는
-- 16-2 팔레트를 그대로 재사용한다(창 배경 --panel-2는 panel과 색은 같고 불투명도만
-- 다른데, 그 정도 차이는 BackgroundTransparency 인자 하나로 충분해 별도 토큰을
-- 만들지 않았다 - 아래 slot 항목과 같은 이유로 꼭 필요한 것만 늘린다).
return {
	panel = Color3.fromRGB(12, 14, 19), -- 반투명 패널 바닥(목업 --panel)
	panelTransparency = 0.28, -- CSS alpha .72 -> Roblox Transparency 1-.72
	rim = Color3.fromRGB(150, 165, 190), -- 얇은 링/테두리(목업 --rim)
	rimTransparency = 0.72, -- alpha .28
	rimHi = Color3.fromRGB(210, 225, 245), -- 상단 하이라이트(목업 --rim-hi, 반투명 얇은 선에만 쓴다)
	rimHiTransparency = 0.45, -- alpha .55
	ember = Color3.fromRGB(255, 122, 47), -- 강조 - 공격·강화(목업 --ember)
	emberDim = Color3.fromRGB(168, 67, 26), -- ember의 어두운 짝(눌림·비활성)
	hp = Color3.fromRGB(226, 59, 59), -- 체력(목업 --hp)
	hpDark = Color3.fromRGB(92, 26, 26), -- 체력바 트랙 바닥색(목업 --hp-dark)
	xp = Color3.fromRGB(242, 196, 61), -- 경험치(목업 --xp, 메이플식 노랑)
	gold = Color3.fromRGB(240, 180, 41), -- 재화(목업 --gold) - xp와 가까운 톤이지만 구분되는 색
	textPrimary = Color3.fromRGB(234, 238, 245), -- 목업 --ink
	textSecondary = Color3.fromRGB(150, 153, 159), -- 목업 --ink-2(alpha .62 실효색, panel-solid 기준)
	textTertiary = Color3.fromRGB(87, 90, 96), -- 목업 --ink-3(alpha .34 실효색, panel-solid 기준)
	danger = Color3.fromRGB(226, 59, 59), -- 목업에 별도 위험색이 없어 hp를 그대로 재사용
	success = Color3.fromRGB(53, 208, 165), -- 목업 --ok

	-- 16-3: 빈 칸·슬롯 바닥색(목업 --slot, rgba(30,35,45,.9)) - panel보다 밝고 더 불투명해서
	-- 20칸이 나란히 있을 때 등급 테두리 색과 배경이 섞이지 않는다.
	slot = Color3.fromRGB(30, 35, 45),
	slotTransparency = 0.1, -- alpha .9
	-- 16-3: 창을 열었을 때 뒤를 덮는 전체 화면 딤(목업 .dim, rgba(0,0,0,.42)).
	overlayDim = Color3.fromRGB(0, 0, 0),
	overlayDimTransparency = 0.58, -- alpha .42

	-- 18-2: 스킬 슬롯 금속판 톤. panel/rim과는 별도 축이다 - 슬롯은 "얇은 유리질 패널"이
	-- 아니라 "두꺼운 금속판"이어야 해서(지시 4) 더 불투명하고 톤이 좁다.
	metalTop = Color3.fromRGB(52, 56, 64), -- 슬롯 배경 그라디언트 위쪽(빛이 위에서 온다는 암시)
	metalBottom = Color3.fromRGB(22, 24, 29), -- 슬롯 배경 그라디언트 아래쪽
	metalOuter = Color3.fromRGB(8, 9, 11), -- 바깥쪽 어두운 금속 테두리
	metalInner = Color3.fromRGB(210, 220, 235), -- 안쪽 밝은 하이라이트 테두리
	metalInnerTransparency = 0.55,
	-- 잠긴 칸 - 채도를 거의 없앤 더 어두운 톤(발광 없음, 지시 4).
	lockedBg = Color3.fromRGB(17, 18, 20),
	lockedIcon = Color3.fromRGB(60, 62, 66),
	lockedRim = Color3.fromRGB(70, 72, 76),

	-- 19-2 [5]: 스킬 슬롯(Q/E) 안쪽 하이라이트선에만 쓰는 직업색. 아이콘 자체엔 강한 색을
	-- 안 입힌다(쿨다운 링과 색이 경쟁해서 둘 다 안 읽힌다는 지시) - 직업색은 이 테두리만
	-- 담당한다. 대검 값(#FF7A2F)은 우연히 ember와, 힐러 값(#F2C43D)은 우연히 xp와 같다 -
	-- 같은 값을 재사용하지 않고 그대로 새 항목으로 둔다(이 팔레트는 "직업"이라는 다른 축이라
	-- ember/xp가 나중에 바뀌어도 같이 바뀌면 안 된다).
	classAccent = {
		greatsword = Color3.fromRGB(255, 122, 47),
		dualblade = Color3.fromRGB(166, 77, 255),
		bow = Color3.fromRGB(59, 209, 192),
		healer = Color3.fromRGB(242, 196, 61),
	},
}
