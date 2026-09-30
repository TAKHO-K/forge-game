-- QUEUE-ALL3 Q7 모서리 다듬기(10 문서 7절): 너무 각진 석조 건물 · 직각 기둥 · 바위 블록을 둥근 모서리 메시(Blender 베벨 - 짧은 변의 10%)로 겉모습만 바꾼다.
--   방법 = client/BevelSkin(내 화면 · ArtStyleV1 뒤): 원래 Block 파트는 그대로(충돌 · 크기 · 자리 · 조회 불변 - LocalTransparencyModifier로 숨김) + 같은 CFrame · Size의 베벨 MeshPart(충돌 없음)를 겹친다.
--   종류 = 원래 Size를 짧은 변으로 나눈 비율과 가장 가까운(로그 거리) 등급 · 축 순서가 다르면 메시를 돌린다. 같은 메시 재사용 · 파트 수 상한 maxParts(삼각형 ≈ 108 × 상한).
--   대상 = 재질이 stoneMaterials이고 짧은 변 ≥ minSide · 긴 변 ≤ maxSide · 이름에 excludeNames가 없는 Block(바닥 타일 · 길 · 판정용 판 제외). 쐐기(WedgePart)는 이번 제외(방향 확인 전).
return {
	maxParts = 700,
	minSide = 1.5,
	maxSide = 160,
	classes = {
		{ key = "props/bevel/bevel_cube", ratio = { 1, 1, 1 } },
		{ key = "props/bevel/bevel_slab", ratio = { 4, 1, 4 } },
		{ key = "props/bevel/bevel_plate", ratio = { 12, 1, 12 } },
		{ key = "props/bevel/bevel_pillar", ratio = { 1, 4, 1 } },
		{ key = "props/bevel/bevel_beam", ratio = { 4, 1, 1 } },
		{ key = "props/bevel/bevel_wall", ratio = { 4, 4, 1 } },
	},
	stoneMaterials = { "Slate", "Rock", "Cobblestone", "Brick", "Concrete", "Granite", "Basalt", "Sandstone", "Limestone", "Marble", "Pavement", "CrackedLava", "Salt", "Pebble", "Glacier", "Ice" },
	excludeNames = { "Floor", "Ground", "Road", "Tile", "Hitbox", "Plate", "Pad", "Barrier", "Wall_Invisible", "Edge", "Water", "Collapse", "Rim", "Ring" },
	excludeAncestors = { "Monsters", "DistantMountains", "WayfinderLocal", "MapPinsLocal", "TravelChannelLocal" },
}
