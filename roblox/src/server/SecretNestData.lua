-- S1 비밀 둥지(C) 자리 - 서버 전용(ServerScriptService - 클라에 복제 안 됨 · M1-3 결정 6). 모양 · 필드 규칙 = shared/data/NestData 머리 주석(같은 스펙).
--   공유 NestData가 서버 실행 중 · Studio edit(지형 굽기)에서만 이 목록을 합친다. 클라는 C 자리를 계산할 수 없다(앵커도 가까이 가야 월드에 나온다 - NestServer).
return {
	{ id = "t1_c_field", zone = "tier1", track = "C", sub = "field", r = 1590, lat = -560, face = 180, kit = "alcove", cover = "fakeWall", hint = { "stone", "moss" } },
	{ id = "t1_c_h1", zone = "tier1", track = "C", sub = "hidden", r = 2505, lat = 0, inLandmark = true, kit = "alcove", cover = "slab", hint = { "moss" } },
	{ id = "t1_c_h2", zone = "tier1", track = "C", sub = "hidden", r = 1060, lat = 640, face = -30, kit = "alcove", cover = "vine", hint = { "fireflies" } },
	{ id = "t1_c_h3", zone = "tier1", track = "C", sub = "hidden", r = 1330, lat = 380, kit = "alcove", cover = "trunk", hint = { "birds" } },
	{ id = "t1_c_h4", zone = "tier1", track = "C", sub = "hidden", r = 2540, lat = 360, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t1_c_h5", zone = "tier1", track = "C", sub = "hidden", r = 1000, lat = -300, face = 60, kit = "alcove", cover = "vine", hint = { "fireflies", "moss" } },
	{ id = "t2_c_field", zone = "tier2", track = "C", sub = "field", r = 1720, lat = 560, face = 90, kit = "alcove", cover = "fakeWall", hint = { "stone", "fireflies" } },
	{ id = "t2_c_h1", zone = "tier2", track = "C", sub = "hidden", r = 2330, lat = 700, face = 150, kit = "alcove", cover = "vine", hint = { "fireflies" } },
	{ id = "t2_c_h2", zone = "tier2", track = "C", sub = "hidden", r = 1320, lat = -620, kit = "alcove", cover = "vine", hint = { "moss" } },
	{ id = "t2_c_h3", zone = "tier2", track = "C", sub = "hidden", r = 2505, lat = 0, inLandmark = true, kit = "alcove", cover = "slab", hint = { "stone" } },
	{ id = "t2_c_h4", zone = "tier2", track = "C", sub = "hidden", r = 1950, lat = -720, face = -60, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t2_c_h5", zone = "tier2", track = "C", sub = "hidden", r = 1990, lat = 780, face = 170, kit = "alcove", cover = "fakeWall", hint = { "moss" } },
	{ id = "t3_c_field", zone = "tier3", track = "C", sub = "field", r = 1710, lat = -440, kit = "alcove", cover = "underwater", river = 4, hint = { "flow", "fireflies" } },
	{ id = "t3_c_h1", zone = "tier3", track = "C", sub = "hidden", r = 1300, lat = -662, face = -70, kit = "alcove", cover = "waterfall", hint = { "flow" } },
	{ id = "t3_c_h2", zone = "tier3", track = "C", sub = "hidden", r = 2450, lat = 290, face = 60, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t3_c_h3", zone = "tier3", track = "C", sub = "hidden", r = 1200, lat = 560, kit = "alcove", cover = "vine", hint = { "fireflies" } },
	{ id = "t3_c_h4", zone = "tier3", track = "C", sub = "hidden", r = 1000, lat = -150, kit = "alcove", cover = "trunk", hint = { "birds" } },
	{ id = "t3_c_h5", zone = "tier3", track = "C", sub = "hidden", r = 2250, lat = 640, face = 120, kit = "alcove", cover = "vine", hint = { "moss" } },
	{ id = "t4_c_field", zone = "tier4", track = "C", sub = "field", r = 1480, lat = 530, kit = "alcove", cover = "oasis", hint = { "fireflies" } },
	{ id = "t4_c_h1", zone = "tier4", track = "C", sub = "hidden", r = 1200, lat = 480, kit = "alcove", cover = "buried", hint = { "stone" } },
	{ id = "t4_c_h2", zone = "tier4", track = "C", sub = "hidden", r = 2290, lat = 590, face = 150, kit = "alcove", cover = "buried", hint = { "stone" } },
	{ id = "t4_c_h3", zone = "tier4", track = "C", sub = "hidden", r = 2420, lat = -210, kit = "alcove", cover = "slab", hint = { "moss" } },
	{ id = "t4_c_h4", zone = "tier4", track = "C", sub = "hidden", r = 1700, lat = -300, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t4_c_h5", zone = "tier4", track = "C", sub = "hidden", r = 2050, lat = -560, kit = "alcove", cover = "buried", hint = { "birds" } },
	{ id = "t5_c_field", zone = "tier5", track = "C", sub = "field", r = 2215, lat = 640, face = -140, kit = "alcove", cover = "fakeWall", base = "natural", hint = { "stone", "moss" } }, -- 흔들다리 아래 절벽 틈
	{ id = "t5_c_h1", zone = "tier5", track = "C", sub = "hidden", r = 2150, lat = -600, kit = "alcove", cover = "timed", templeBack = true, hint = { "stone" } }, -- 번개 칠 때만 열리는 문(신전 뒤)
	{ id = "t5_c_h2", zone = "tier5", track = "C", sub = "hidden", r = 2400, lat = -450, kit = "alcove", cover = "fakeWall", hint = { "moss" } },
	{ id = "t5_c_h3", zone = "tier5", track = "C", sub = "hidden", r = 1600, lat = -450, kit = "alcove", cover = "vine", hint = { "fireflies" } },
	{ id = "t5_c_h4", zone = "tier5", track = "C", sub = "hidden", r = 1250, lat = 560, face = -40, kit = "alcove", cover = "vine", hint = { "moss" } },
	{ id = "t5_c_h5", zone = "tier5", track = "C", sub = "hidden", r = 2470, lat = -110, kit = "alcove", cover = "slab", hint = { "stone" } },
	{ id = "t6_c_field", zone = "tier6", track = "C", sub = "field", r = 1438, lat = -612, face = 0, kit = "alcove", cover = "ice", noMound = true, hint = { "moss" } }, -- 빙벽 틈(빙하 혀 안)
	{ id = "t6_c_h1", zone = "tier6", track = "C", sub = "hidden", r = 2140, lat = 455, face = 30, kit = "alcove", cover = "ice", base = 55, hint = { "fireflies" } }, -- 호수 선반 뒤 얼음 틈
	{ id = "t6_c_h2", zone = "tier6", track = "C", sub = "hidden", r = 2400, lat = -300, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t6_c_h3", zone = "tier6", track = "C", sub = "hidden", r = 2480, lat = -150, kit = "alcove", cover = "slab", hint = { "moss" } },
	{ id = "t6_c_h4", zone = "tier6", track = "C", sub = "hidden", r = 1200, lat = -600, face = 30, kit = "alcove", cover = "ice", hint = { "stone" } },
	{ id = "t6_c_h5", zone = "tier6", track = "C", sub = "hidden", r = 1450, lat = 700, face = -60, kit = "alcove", cover = "vine", hint = { "fireflies" } },
	{ id = "hub_c_chimney", zone = "hub", track = "C", sub = "village", kit = "chimney", facility = "forge", eggZone = "tier1" },
	{ id = "hub_c_attic", zone = "hub", track = "C", sub = "village", kit = "attic", facility = "market", eggZone = "tier2" },
	{ id = "hub_c_trunk", zone = "hub", track = "C", sub = "village", kit = "trunk", angleDeg = 255, eggZone = "tier3" },
	{ id = "hub_c_arch", zone = "hub", track = "C", sub = "village", kit = "arch", facility = "portal", eggZone = "tier4" },
}
