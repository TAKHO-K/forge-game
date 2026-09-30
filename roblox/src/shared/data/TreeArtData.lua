-- QUEUE-ALL1 ★0-2 카툰 나무(ArtStyleV1 뒤 · 겉모습만 - 충돌 = 틀 줄기 원기둥 그대로). 메시 = roblox/tools/blender/make_trees.py → props/trees/<이름>(Open Cloud).
--   필드: PropData Common_Tree 틀마다 구역 변형 하나(자리 해시 - 같은 자리 = 늘 같은 나무) · 같은 메시를 구역 팔레트로 칠한다(묶음 그리기 · 반복 티는 자리 회전 · 배율 + 변형).
--   허브 큰 나무(BigTree): 잎 뭉치(SeasonRole leaves · leavesDeep 공)마다 덩어리 덮개(clump) - 색 = 그 뭉치의 계절 색(어두운 면 × darkK · 밝은 면 = 흰색 쪽 lightK).
--   허브 나무(임시 자리 - H1 배치 전): hub.spots(방위 · 반경 · 종류). 줄기 충돌 = 큰 나무만(틀 줄기) · 관목 없음 · 장식수 = 가는 원기둥.
--   바람: 가까운 잎만 약하게(클라 TreeWind) · 폰 = 끔.
return {
	keyPrefix = "props/trees/",
	variants = {
		tier1 = { "tree_oak", "tree_twin", "tree_round" },
		tier3 = { "tree_coast", "tree_coast", "tree_oak" },
		default = { "tree_oak", "tree_round" },
	},
	-- { 줄기, 잎 중간, 잎 아랫면, 잎 윗면 } - 구역 색(강한 주황 · 빨강 · 흰 + 자홍 금지)
	palettes = {
		tier1 = { bark = { 112, 76, 52 }, leaf = { 98, 150, 72 }, dark = { 62, 104, 56 }, light = { 150, 196, 98 } },
		tier3 = { bark = { 118, 92, 70 }, leaf = { 72, 150, 118 }, dark = { 44, 106, 92 }, light = { 128, 196, 150 } },
		hub = { bark = { 116, 80, 54 }, leaf = { 104, 162, 78 }, dark = { 66, 112, 60 }, light = { 162, 206, 104 } },
		default = { bark = { 112, 76, 52 }, leaf = { 98, 150, 72 }, dark = { 62, 104, 56 }, light = { 150, 196, 98 } },
	},
	clumps = { "clump_a", "clump_b", "clump_c" },
	bigTree = { roles = { leaves = true, leavesDeep = true }, darkK = 0.72, lightK = 0.24, scale = 1.06 }, -- 덮개 = 뭉치 크기 × scale(뭉치가 안 비치게)
	hub = {
		spots = {
			{ angleDeg = -60, r = 335, kind = "tree_oak", scale = 1.25 }, { angleDeg = -52, r = 352, kind = "hub_shrub", scale = 1 },
			{ angleDeg = 0, r = 335, kind = "tree_round", scale = 1.2 }, { angleDeg = 8, r = 350, kind = "hub_topiary", scale = 1 },
			{ angleDeg = 60, r = 335, kind = "tree_twin", scale = 1.2 }, { angleDeg = 52, r = 352, kind = "hub_shrub", scale = 1.1 },
			{ angleDeg = 120, r = 335, kind = "tree_oak", scale = 1.3 }, { angleDeg = 128, r = 350, kind = "hub_topiary", scale = 1 },
			{ angleDeg = 180, r = 335, kind = "tree_round", scale = 1.25 }, { angleDeg = 172, r = 352, kind = "hub_shrub", scale = 1 },
			{ angleDeg = 240, r = 335, kind = "tree_twin", scale = 1.2 }, { angleDeg = 248, r = 350, kind = "hub_topiary", scale = 1 },
		},
		topiaryCollider = { height = 15, diameter = 1.2 }, -- 장식수 줄기 충돌(원기둥)
		clearStuds = 6, -- 자리 둘레 이 안에 다른 충돌 파트가 있으면 그 나무는 건너뜀(끼임 방지)
	},
	wind = { radiusStuds = 80, maxParts = 160, degrees = 1.4, periodSeconds = 3.4, mobile = false },
}
