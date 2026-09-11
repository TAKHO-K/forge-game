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
-- 등급 색 7단계(14-1, ItemVisualData.gradeVisuals)는 여전히 별도 축이라 안 건드린다.
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
}
