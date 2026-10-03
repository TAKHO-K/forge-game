-- QUEUE-ALL6 C 아이템 설명 표(한 곳): 재료 · 재화 · 보상 종류의 이름 · 한 줄 설명(40자 · 무엇에 쓰는지) · 그림 · 지금 가진 개수 읽는 곳.
--   보상 칸 펼쳐 보기(client/ui/RewardDetail) · 가방 재료 칸 · 상점 줄이 모두 이 표의 같은 문구(TextData_items: item.name.<id> · item.desc.<id> - ko/en)를 쓴다.
--   owned: attr = LocalPlayer Attribute 이름(서버가 내린다) · source = "eggs"(client/NestState 알 개수) · 없음 = 개수 줄 안 보임.
return {
	order = { "gold", "enhanceStone", "highEnhanceStone", "egg", "gemDust", "sparkleShard", "protectDrop", "protectReset", "rerollTicket", "rebirthTicket", "passExp", "title" },
	items = {
		gold = { icon = "gold", owned = { attr = "Gold" } },
		enhanceStone = { icon = "enhanceStone", owned = { attr = "MaterialEnhanceStone" } },
		highEnhanceStone = { icon = "highEnhanceStone", owned = { attr = "MaterialHighEnhanceStone" } },
		egg = { icon = "egg", owned = { source = "eggs" } },
		gemDust = { icon = "gemDust", owned = { attr = "GemDust" } },
		sparkleShard = { icon = "sparkleShard", owned = { attr = "SparkleShard" } },
		protectDrop = { icon = "protectDrop", owned = { attr = "ProtectionDrop" } },
		protectReset = { icon = "protectReset", owned = { attr = "ProtectionReset" } },
		rerollTicket = { icon = "rerollTicket" }, -- 등급별 개수(가방 보석 탭이 따로 보여 준다)
		rebirthTicket = { icon = "rebirthTicket", owned = { attr = "RebirthTicket" } },
		passExp = { icon = "passExp", owned = { attr = "PassExp" } },
		title = { icon = "title" },
	},
	alias = { goldKills = "gold", eggZone = "egg" }, -- 보상 표 키 → 아이템 id
	-- QUEUE-ALL9B R1 재화 칸(client/ui/CurrencyBar - HUD 오른쪽 위 · 가방 위쪽 줄): 기존 재화만(새 재화 없음) · 값 = 위 owned.attr(서버 Attribute).
	--   always = HUD 접힌 칸에 늘 보임 · more = 누르면 펼쳐짐 · 가방 줄 = always + more 전부 · 초 = 접힘 · +n 떠오름 · 묶기.
	currencyBar = { always = { "gold", "sparkleShard" }, more = { "enhanceStone", "highEnhanceStone", "gemDust", "protectDrop", "protectReset" }, closeSeconds = 3, gainSeconds = 0.8, batchSeconds = 0.2 },
}
