-- QUEUE-UI UI-0 아이콘 표 한 곳: 아이콘 ID → 그림(ArtAssetIds 키 = 업로드 기록) · 칠하기 방식. 화면 코드는 아이콘 ID만 쓴다(그림 id를 직접 쓰지 않는다).
--   지금 그림 = 흰 글리프(임시) → 카툰 아이콘(자체 색)으로 통째 교체 예정: 교체 = 이 표의 asset만 바꾸고 tint = false.
--   tint = true  → 흰 글리프에 코드가 글리프 색(tintFg 토큰)을 입힌다(바탕 = 그 아이콘을 담은 칸 · 버튼 색).
--   tint = false → 그림 자체 색 그대로(바탕 없음).
--   asset이 없거나(아직 안 받음 - 01 MISSING.md) 업로드 기록이 없으면 fallback 글자를 그린다(임시 - 파일 이름만 맞춰 둠).
--   file = 넘김 묶음 안 파일 이름(받으면 roblox/tools/opencloud/upload.py로 올리고 asset = 그 ArtAssetIds 키).
-- QUEUE-UI UI-0 아이콘 표 한 곳: 아이콘 ID → 그림(ArtAssetIds 키 = 업로드 기록) · 칠하기 방식. 화면 코드는 아이콘 ID만 쓴다(그림 id를 직접 쓰지 않는다).
--   QUEUE-UI2 UI2-1: 아이콘 v2(00 디자인 시스템 "이 세계의 물건" · 자체 색) = ui/ds/icon-<이름>(00 묶음이 기준 이름). tint = false(그림 색 그대로).
--   old = 옛 HUD 아이콘 키(지우지 않음 - 되돌리기 · 비교용). 01 · 02 · 03 묶음에서 이름만 다르고 내용이 같은 파일 = aliases(해시 비교 - 다시 올리지 않음).
--   tint = true → 흰 글리프에 코드가 글리프 색(tintFg 토큰)을 입힌다 · asset 업로드 기록이 없으면 fallback 글자.
return {
	icons = {
		["archive"] = { asset = "ui/ds/icon-archive", tint = false, fallback = "▤" },
		["atk-bow"] = { asset = "ui/ds/icon-atk-bow", tint = false, fallback = "?" },
		["atk-dagger"] = { asset = "ui/ds/icon-atk-dagger", tint = false, fallback = "?" },
		["atk-staff"] = { asset = "ui/ds/icon-atk-staff", tint = false, fallback = "?" },
		["atk-sword"] = { asset = "ui/ds/icon-atk-sword", tint = false, fallback = "?" },
		["back"] = { asset = "ui/ds/icon-back", tint = false, fallback = "<" },
		["bag"] = { asset = "ui/ds/icon-bag", tint = false, fallback = "?", old = "icons/hud/bag" },
		["book"] = { asset = "ui/ds/icon-book", tint = false, fallback = "?", old = "icons/hud/codex" },
		["close"] = { asset = "ui/ds/icon-close", tint = false, fallback = "X" },
		["compass"] = { asset = "ui/ds/icon-compass", tint = false, fallback = "?" },
		["dash"] = { asset = "ui/ds/icon-dash", tint = false, fallback = "?" },
		["gear"] = { asset = "ui/ds/icon-gear", tint = false, fallback = "?", old = "icons/hud/settings" },
		["gold"] = { asset = "ui/ds/icon-gold", tint = false, fallback = "?" },
		["growth"] = { asset = "ui/ds/icon-growth", tint = false, fallback = "?", old = "icons/hud/growth" },
		["home"] = { asset = "ui/ds/icon-home", tint = false, fallback = "?", old = "icons/hud/return" },
		["info"] = { asset = "ui/ds/icon-info", tint = false, fallback = "i" },
		["jump"] = { asset = "ui/ds/icon-jump", tint = false, fallback = "?" },
		["lock"] = { asset = "ui/ds/icon-lock", tint = false, fallback = "🔒" },
		["lockon"] = { asset = "ui/ds/icon-lockon", tint = false, fallback = "?" },
		["map"] = { asset = "ui/ds/icon-map", tint = false, fallback = "?", old = "icons/hud/map" },
		["more"] = { asset = "ui/ds/icon-more", tint = false, fallback = "⋯", old = "icons/hud/more" },
		["party"] = { asset = "ui/ds/icon-party", tint = false, fallback = "?", old = "icons/hud/party" },
		["party2"] = { asset = "ui/ds/icon-party2", tint = false, fallback = "?" },
		["pet"] = { asset = "ui/ds/icon-pet", tint = false, fallback = "?", old = "icons/hud/pet" },
		["play"] = { asset = "ui/ds/icon-play", tint = false, fallback = "▶" },
		["plus"] = { asset = "ui/ds/icon-plus", tint = false, fallback = "+" },
		["quest"] = { asset = "ui/ds/icon-quest", tint = false, fallback = "?", old = "icons/hud/quest" },
		["rank"] = { asset = "ui/ds/icon-rank", tint = false, fallback = "?", old = "icons/hud/rank" },
		["rebirth"] = { asset = "ui/ds/icon-rebirth", tint = false, fallback = "?", old = "icons/hud/rebirth" },
		["shop"] = { asset = "ui/ds/icon-shop", tint = false, fallback = "?", old = "icons/hud/shop" },
		["star"] = { asset = "ui/ds/icon-star", tint = false, fallback = "★" },
		["x"] = { asset = "ui/ds/icon-x", tint = false, fallback = "X" },
		-- 00 v3(10-05): 구역 선택 · 수련 · 보상
		["zone"] = { asset = "ui/ds/icon-zone", tint = false, fallback = "?", old = "icons/hud/zone_select" },
		["training"] = { asset = "ui/ds/icon-training", tint = false, fallback = "?", old = "icons/hud/training" },
		["reward"] = { asset = "ui/ds/icon-reward", tint = false, fallback = "?" },
		-- 스킬 아이콘 16장(00 v2 · icon-skill-<직업>-<칸>) - 아이콘은 직업 · 칸으로 고른다(이름 · 설명 = 게임 데이터)
		["skill-greatsword-q"] = { asset = "ui/ds/icon-skill-greatsword-q", tint = false, fallback = "Q" }, ["skill-greatsword-e"] = { asset = "ui/ds/icon-skill-greatsword-e", tint = false, fallback = "E" }, ["skill-greatsword-r"] = { asset = "ui/ds/icon-skill-greatsword-r", tint = false, fallback = "R" }, ["skill-greatsword-t"] = { asset = "ui/ds/icon-skill-greatsword-t_v3", tint = false, fallback = "T", old = "ui/ds/icon-skill-greatsword-t" },
		["skill-dualblade-q"] = { asset = "ui/ds/icon-skill-dualblade-q_v3", tint = false, fallback = "Q", old = "ui/ds/icon-skill-dualblade-q" }, ["skill-dualblade-e"] = { asset = "ui/ds/icon-skill-dualblade-e", tint = false, fallback = "E" }, ["skill-dualblade-r"] = { asset = "ui/ds/icon-skill-dualblade-r", tint = false, fallback = "R" }, ["skill-dualblade-t"] = { asset = "ui/ds/icon-skill-dualblade-t", tint = false, fallback = "T" },
		["skill-bow-q"] = { asset = "ui/ds/icon-skill-bow-q", tint = false, fallback = "Q" }, ["skill-bow-e"] = { asset = "ui/ds/icon-skill-bow-e", tint = false, fallback = "E" }, ["skill-bow-r"] = { asset = "ui/ds/icon-skill-bow-r", tint = false, fallback = "R" }, ["skill-bow-t"] = { asset = "ui/ds/icon-skill-bow-t", tint = false, fallback = "T" },
		["skill-healer-q"] = { asset = "ui/ds/icon-skill-healer-q", tint = false, fallback = "Q" }, ["skill-healer-e"] = { asset = "ui/ds/icon-skill-healer-e", tint = false, fallback = "E" }, ["skill-healer-r"] = { asset = "ui/ds/icon-skill-healer-r", tint = false, fallback = "R" }, ["skill-healer-t"] = { asset = "ui/ds/icon-skill-healer-t", tint = false, fallback = "T" },
	},
	-- 넘김 묶음 파일 이름 → 00 기준 아이콘 ID(같은 그림 · sha256 같음 - 10-05 UI2-1)
	aliases = {
		["icon-attack-bow"] = "atk-bow", ["icon-attack-dagger"] = "atk-dagger", ["icon-attack-staff"] = "atk-staff", ["icon-attack-sword"] = "atk-sword",
		["menu-backpack"] = "bag", ["menu-codex"] = "book", ["menu-growth"] = "growth", ["menu-map"] = "map", ["menu-more"] = "more",
		["menu-party-phone"] = "party2", ["menu-party"] = "party", ["menu-pet"] = "pet", ["menu-rank"] = "rank", ["menu-rebirth"] = "rebirth",
		["menu-return"] = "home", ["menu-settings"] = "gear", ["menu-shop"] = "shop",
	},
	-- 01 v1 흰 글리프(옛 - 업로드 안 함 · 파일 이름만): close · lock · plus · more · archive · back · play · info · star = 01_main-menu/v1/assets/icon-*.png
	-- 직업별 그림(직업 선택 전설 일러스트 · 카드 얼굴) - 직업 id로 찾는다(신직업 = 줄 추가 · 없으면 임시 실루엣)
	classArt = {
		greatsword = { legend = "ui/legends/class-warrior", face = "ui/legends/face-warrior", faceRect = { 173, 13, 314 } },
		bow = { legend = "ui/legends/class-archer", face = "ui/legends/face-archer", faceRect = { 165, 5, 266 } },
		healer = { legend = nil, face = nil, placeholder = "ui/legends/class-healer-placeholder" }, -- 전설 그림 대기 = 자리표시 그림(01 v2 · "그림 곧 공개")
		dualblade = { legend = nil, face = nil, placeholder = "ui/legends/class-rogue-placeholder" },
	},
	-- 공격 버튼 아이콘 = 지금 직업 무기 아이콘(무기 아이콘 키 = icons/weapons/<직업>_<등급> - client/ItemIcons.keyFor)
	attackUsesWeaponIcon = true,
}
