-- QUEUE-UI UI-0 아이콘 표 한 곳: 아이콘 ID → 그림(ArtAssetIds 키 = 업로드 기록) · 칠하기 방식. 화면 코드는 아이콘 ID만 쓴다(그림 id를 직접 쓰지 않는다).
--   지금 그림 = 흰 글리프(임시) → 카툰 아이콘(자체 색)으로 통째 교체 예정: 교체 = 이 표의 asset만 바꾸고 tint = false.
--   tint = true  → 흰 글리프 + 코드가 바탕 원(tintBg 토큰)을 칠하고 글리프 색(tintFg 토큰)을 입힌다.
--   tint = false → 그림 자체 색 그대로(바탕 없음).
--   asset이 없거나(아직 안 받음 - 01 MISSING.md) 업로드 기록이 없으면 fallback 글자를 그린다(임시 - 파일 이름만 맞춰 둠).
--   file = 넘김 묶음 안 파일 이름(받으면 roblox/tools/opencloud/upload.py로 올리고 asset = 그 ArtAssetIds 키).
return {
	icons = {
		close = { file = "01_main-menu/v1/assets/icon-close.png", asset = nil, tint = true, tintFg = "text.primary", fallback = "✕" },
		lock = { file = "01_main-menu/v1/assets/icon-lock.png", asset = nil, tint = true, tintFg = "text.muted", fallback = "🔒" },
		plus = { file = "01_main-menu/v1/assets/icon-plus.png", asset = nil, tint = true, tintFg = "accent", fallback = "+" },
		more = { file = "01_main-menu/v1/assets/icon-more.png", asset = nil, tint = true, tintFg = "text.secondary", fallback = "⋯" },
		archive = { file = "01_main-menu/v1/assets/icon-archive.png", asset = nil, tint = true, tintFg = "text.primary", fallback = "▤" },
		back = { file = "01_main-menu/v1/assets/icon-back.png", asset = nil, tint = true, tintFg = "text.primary", fallback = "<" },
		play = { file = "01_main-menu/v1/assets/icon-play.png", asset = nil, tint = true, tintFg = "accent", fallback = "▶" },
		info = { file = "01_main-menu/v1/assets/icon-info.png", asset = nil, tint = true, tintFg = "info", fallback = "i" },
		star = { file = "01_main-menu/v1/assets/icon-star.png", asset = nil, tint = true, tintFg = "accent", fallback = "★" },
	},
	-- 직업별 그림(직업 선택 전설 일러스트 · 카드 얼굴) - 직업 id로 찾는다(신직업 = 줄 추가 · 없으면 임시 실루엣)
	classArt = {
		greatsword = { legend = "ui/legends/class-warrior", face = "ui/legends/face-warrior", faceRect = { 173, 13, 314 } },
		bow = { legend = "ui/legends/class-archer", face = "ui/legends/face-archer", faceRect = { 165, 5, 266 } },
		healer = { legend = nil, face = nil }, -- 01 MISSING: class-healer-placeholder.png
		dualblade = { legend = nil, face = nil }, -- 01 MISSING: class-rogue-placeholder.png
	},
	-- 공격 버튼 아이콘 = 지금 직업 무기 아이콘(무기 아이콘 키 = icons/weapons/<직업>_<등급> - client/ItemIcons.keyFor)
	attackUsesWeaponIcon = true,
}
