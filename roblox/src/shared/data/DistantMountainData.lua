-- QUEUE-ALL3 Q10 맵 바깥 먼 산(카툰 - 둥근 봉우리 · 층층 실루엣 · 구역 색 띠 · 물결 눈 꼭대기). 메시 = roblox/tools/blender/make_mountains.py(구역마다 2 ~ 3장 + LOD) → ArtMeshCache "props/mountains/<이름>".
--   세계 경계(WorldMapData.edge.radius 2,960 · 충돌 벽 그대로) 바깥에만 · 충돌 · 조회 · 터치 없음 · 그림자 끔 · 플레이 지형 불변. ArtStyleV1 뒤(메시 로더가 켬일 때만 캐시를 채운다 - 끔 = 전과 같음).
--   near = 구역 방향마다 가까운 산(앞산 짙게) · far = 한 바퀴 LOD 산(먼 산 옅고 푸르게 - hazeColor로 hazeLerp만큼 섞음). 삼각형 합 ≈ near 18 × 900 + far 18 × 150 ≈ 19,000(예산 20,000).
--   그래픽 "가벼움"(GraphicsMode lite) = far 줄을 클라에서 숨김(client/FxSettings).
return {
	folderName = "DistantMountains",
	baseDepth = 40, -- 바닥을 지면(floorTopY)보다 이만큼 낮게(밑면이 안 보이게)
	near = { r = 3450, jitterR = 250, angleOffsets = { -20, 0, 20 }, scale = { 0.85, 1.25 } },
	far = { r = 5300, jitterR = 300, count = 18, scale = { 1.6, 2.1 }, hazeColor = { 150, 180, 215 }, hazeLerp = 0.45 },
	seed = 20261001,
	-- 구역 → 메시 이름(순환) · 파트 색(메타 suggestedColors)
	zones = {
		tier1 = { meshes = { "mountain_tier1_a", "mountain_tier1_b", "mountain_tier1_c" }, colors = { Body = { 112, 176, 86 } } },
		tier2 = { meshes = { "mountain_tier2_a", "mountain_tier2_b" }, colors = { Body = { 112, 84, 170 }, Crystal = { 210, 108, 240 } } },
		tier3 = { meshes = { "mountain_tier3_a", "mountain_tier3_b" }, colors = { Body = { 40, 142, 152 }, Cap = { 128, 214, 200 } } },
		tier4 = { meshes = { "mountain_tier4_a", "mountain_tier4_b", "mountain_tier4_c" }, colors = { Body = { 204, 142, 72 }, Cap = { 238, 198, 124 } } },
		tier5 = { meshes = { "mountain_tier5_a", "mountain_tier5_b" }, colors = { Body = { 46, 54, 96 }, Snow = { 222, 230, 246 } } },
		tier6 = { meshes = { "mountain_tier6_a", "mountain_tier6_b", "mountain_tier6_c" }, colors = { Body = { 170, 192, 218 }, Snow = { 248, 251, 255 } } },
	},
}
