-- A2-N4 §2-6 맵 변화 패턴 에셋화(ArtStyleV1 뒤 · 클라 겉모습만 - 판정 파트 크기 · 충돌 · 재질 불변, 덧붙인 것은 충돌 · 조준 · 터치 끔).
--   곡면 = 기존 Blender 키트 메시(props/kit - ArtMeshCache) 재사용 · 나머지 = Studio 파트. 그리는 곳 = client/ArtV1PatternDress · BossArenaPropsView(모래 구덩이).
return {
	-- 구간 수호자 붕괴 조각 바닥(server/BossArenaMap BossArenaSliceFloor_*): 조각 경계 잉크 줄 + 허브 테 · 무너질 때 돌 부스러기가 떨어진다
	slice = {
		seamColor = { 46, 38, 34 },
		seamWidth = 1.1, -- Play: 0.45는 아레나 전체 시점에서 안 보였다
		seamLift = 0.03,
		hubRingExtra = 0.5, -- 허브 원판보다 이만큼 넓은 어두운 원판(허브 테)
		rubbleMesh = "props/kit/T1_Boulder",
		rubblePerWedge = 1,
		rubbleSize = { 1.6, 3.0 },
		rubbleFallStuds = 22,
		rubbleSeconds = 1.3,
	},
	-- 수정 여왕 점프맵 발판(server/BossJumpCourse - CourseSite 속성): 발판 밑 떠 있는 바위 섬 + 어두운 테두리 · 체크포인트 = 초록 수정 가시
	jumpStep = {
		islandMesh = "props/kit/T5_FloatStone",
		islandColor = { 92, 74, 128 },
		islandWidthScale = 1.05,
		islandHeightScale = 0.55,
		rimColor = { 52, 36, 78 },
		rimExtra = 0.5,
		rimDrop = 0.25,
		checkpointMesh = "props/kit/T2_CrystalSpike",
		checkpointColor = { 110, 230, 160 },
		checkpointHeight = 2.4,
	},
	-- 깨는 수정 두 개(server/BossJumpCourse → spawnRescueTarget · RescueKind = "crystal"): 몸통(판정)은 로컬에서 숨기고 수정 무리 메시를 씌운다
	crystal = {
		mesh = "props/kit/T2_CrystalCluster",
		sizeScale = 1.35,
		transparency = 0.1,
	},
	-- 모래 구덩이(client/BossArenaPropsView.spawnPit): 비탈 → 가운데로 갈수록 짙어지는 깔때기 고리 2장(판정 반경 그대로)
	pit = {
		rings = { { fraction = 0.72, darken = 0.14, lift = 0.1 }, { fraction = 0.48, darken = 0.28, lift = 0.12 } },
	},
}
