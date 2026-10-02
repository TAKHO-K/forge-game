-- QUEUE-ALL7B 2 마을 기능 지점: HUD 아이콘에서 뺀(또는 창 깊숙이 있던) 기능을 허브 건물 · NPC 자리에서 연다(단축키 · 창 안 길은 그대로).
--   spot = WorldMapData.hub.facilities[].spots id(자리 표시 기둥 - 이름표는 서버 WorldMap이 Label로 단다) · panel = PanelRegistry id · focus = 그 창의 탭(없으면 기본)
--   icon = 머리 위 · 지도 아이콘(icons/...) · nameKey · actionKey · introKey = TextData(ko · en) · intro = 첫 방문 소개 한 줄을 본 적 있음(SettingsData 키 - 재접속 유지)
--   클라 = client/HubServices.client.lua(프롬프트 · 머리 위 아이콘 · 첫 소개) · 지도 = WorldMapPanel · Minimap이 이 표를 읽는다.
return {
	promptDistance = 10, -- 프롬프트가 뜨는 거리(stud - 다른 허브 프롬프트와 같은 손 거리)
	introRadius = 22, -- 이만큼 다가가면 첫 소개 한 줄(한 번만)
	iconOffsetY = 9, -- 자리 기둥 위 이름표 위로(stud)
	services = {
		{ id = "hallOfFame", spot = "hallOfFame", panel = "leaderboard", icon = "icons/hud/rank", nameKey = "hub.service.hallOfFame", actionKey = "hub.service.hallOfFame.action", introKey = "hub.service.hallOfFame.intro", intro = "hubIntroRank" },
		{ id = "noticeBoard", spot = "noticeBoard", panel = "settings", focus = "game", icon = "icons/hud/attendance", nameKey = "hub.service.noticeBoard", actionKey = "hub.service.noticeBoard.action", introKey = "hub.service.noticeBoard.intro", intro = "hubIntroBoard" },
		{ id = "challengeKnight", spot = "challengeKnight", panel = "quests", focus = "challenge", icon = "icons/ui/pin_boss", nameKey = "hub.service.challengeKnight", actionKey = "hub.service.challengeKnight.action", introKey = "hub.service.challengeKnight.intro", intro = "hubIntroChallenge" },
		-- QUEUE-ALL8 A: 출시 기능 자리(정식 이름 + 프롬프트 · 설명 = hintKey 한 줄 · 첫 소개 없음)
		{ id = "refine", spot = "refine", panel = "inventory", icon = "icons/hud/forge", nameKey = "hub.service.refine", actionKey = "hub.service.refine.action", hintKey = "hub.service.refine.hint" },
		{ id = "gemcraft", spot = "gemcraft", panel = "inventory", icon = "icons/hud/codex", nameKey = "hub.service.gemcraft", actionKey = "hub.service.gemcraft.action", hintKey = "hub.service.gemcraft.hint" },
		{ id = "shop", spot = "shop", panel = "shop", focus = "recommend", icon = "icons/hud/shop", nameKey = "hub.service.shop", actionKey = "hub.service.shop.action" },
		{ id = "tailor", spot = "tailor", panel = "character", focus = "cosmetics", icon = "icons/codex/tab_equipment", nameKey = "hub.service.tailor", actionKey = "hub.service.tailor.action", introKey = "hub.service.tailor.intro", intro = "hubIntroTailor" },
	},
}
