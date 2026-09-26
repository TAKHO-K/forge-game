-- M1-3 구조물(둥지가 아닌 것) - 폐허 · 수정 · 선인장 · 계곡 기슭 계단. 둥지 키트(신전 · 다리 · 수중 신전 · 사당)는 NestData 쪽이 짓는다.
-- 재질 · 색 = 지형 재질과 같은 이름(TerrainGenData.materialColors)을 써서 파트가 지형과 이어져 보이게 한다. 같은 모양(선인장 · 수정 군집)은 같은 틀 함수 하나로 찍는다.
return {
	-- T1 돌기둥 폐허(열주 - 두 줄 · 몇 개는 부러졌다 · 쓰러진 기둥 · 낮은 단)
	colonnade = { zone = "tier1", r = 1950, lat = 130, face = 20, rows = 2, cols = 6, spacing = 12, rowGap = 16, h = 16, dia = 3.6,
		broken = { [2] = 7, [5] = 10, [9] = 4, [11] = 9 }, fallen = { 4, 8 }, dais = { w = 78, d = 26, h = 1.2 }, material = "Limestone" },
	-- T2 수정 군집(같은 틀 - 기울어진 육각 기둥 5개 · 관문 색 수정 = BossData 수정 여왕 색). 굴 안 · 입구 · 들판에 몇 곳만.
	crystals = { zone = "tier2", material = "Glass", transparency = 0.25,
		clusters = { { 2245, 612, 1.3 }, { 2290, 648, 1.0 }, { 2230, 660, 0.8 }, { 2070, 455, 1.1 }, { 2095, 500, 0.7 }, { 1150, -420, 0.9 }, { 1550, 560, 1.0 }, { 2350, -380, 1.2 } } },
	-- T4 선인장 밭(닿으면 작은 피해 + 살짝 밀림 · 필수 길 위 금지 - 검증) · 가운데 = 오아시스(C 둥지)
	cactus = {
		zone = "tier4", material = "LeafyGrass",
		fields = { { r = 1480, lat = 560, inner = 30, outer = 74, count = 26, seed = 11 }, { r = 2050, lat = -560, inner = 18, outer = 62, count = 22, seed = 23 } },
		height = { 6, 11 }, trunk = 2.2, arm = 1.4,
		-- 피해(서버): 루트가 선인장 중심 반경(trunk/2 + touchStuds) 안이면 현재 체력의 hpFraction(이것만으로는 안 죽는다 - PlayerDamage.applyCurrentHpFraction) ·
		--   사람마다 cooldownSeconds · windowSeconds 동안 최대 maxPerWindow번(상한) · 밀림 = 선인장 반대쪽 pushSpeed(클라가 속도로 준다).
		hazard = { touchStuds = 1.6, hpFraction = 0.04, cooldownSeconds = 0.6, windowSeconds = 5, maxPerWindow = 3, pushSpeed = 26 }, -- 판정 주기 = TerrainServer 폴링(0.25초)
	},
}
