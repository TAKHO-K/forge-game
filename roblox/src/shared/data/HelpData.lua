-- UI-1b 1절 3(사용자 "지엽적인 설명은 [?] 도움말로" · I v1 spec 0-2): 창 제목 옆 [?] = A 설명 창(client/ui/v2/InfoTip) 내용.
--   틀(모든 InfoTip 같음): 첫 줄 = 이름 한 단어(title 키) · 그 아래 짧은 줄 "항목: 글"(rows = { 항목 키, 글 키 }) · 문구 = TextData_ui1b(ko · en).
--   "새로 생긴 [?]" = 처음 1번만 작은 점(설정 helpSeen = 본 id 목록 · 서버가 이 표의 id만 받음).
local H = {}
H.ids = { -- 줄 = { 항목 키, 글 키 } · 글 키는 이미 있던 문구를 그대로 쓰기도 한다(ui1.pet.rules 등 - 창에서 옮겨 온 줄)
	ember = { title = "ui1b.help.ember.title", rows = { { "ui1b.help.row.rule", "ui1b.help.ember.rule" }, { "ui1b.help.row.full", "ui1b.help.ember.full" }, { "ui1b.help.row.down", "ui1b.help.ember.down" } } },
	codex = { title = "ui1b.help.codex.title", rows = { { "ui1b.help.row.box", "ui1b.help.codex.box" }, { "ui1b.help.row.star", "ui1b.help.codex.star" }, { "ui1b.help.row.titleRow", "ui1b.help.codex.titleRow" } } },
	egg = { title = "ui1b.help.egg.title", rows = { { "ui1b.help.row.rule", "ui1.pet.rules" }, { "ui1b.help.row.odds", "ui1.pet.oddsNote" } } },
	attendance = { title = "ui1b.help.attendance.title", rows = { { "ui1b.help.row.reset", "ui1b.help.attendance.reset" }, { "ui1b.help.row.all", "ui1b.help.attendance.all" } } },
	settings = { title = "ui1b.help.settings.title", rows = {} }, -- 줄마다 [?] = 제목 = 줄 이름 · 줄 = 그 줄 설명(Settings가 넘김)
	hudEdit = { title = "ui1b.help.hudEdit.title", rows = { { "ui1b.help.row.move", "ui1b.help.hudEdit.move" }, { "ui1b.help.row.forbid", "ui1b.help.hudEdit.forbid" }, { "ui1b.help.row.overlap", "ui1b.help.hudEdit.overlap" } } },
	bossGate = { title = "ui1b.help.bossGate.title", rows = { { "ui1b.help.row.party", "ui1.gate.partyHint" }, { "ui1b.help.row.power", "ui1b.help.bossGate.power" } } }, -- + 처음 만남이면 "처음" 줄(창이 넘김)
	shop = { title = "ui1b.help.shop.title", rows = { { "ui1b.help.row.token", "ui1b.help.shop.token" }, { "ui1b.help.row.starter", "ui1b.help.shop.starter" } } },
	training = { title = "ui1b.help.training.title", rows = { { "ui1b.help.row.rule", "training.line" }, { "ui1b.help.row.unlock", "training.adv.locked" } } },
	quests = { title = "ui1b.help.quests.title", rows = { { "ui1b.help.row.daily", "ui1b.help.quests.daily" }, { "ui1b.help.row.weekly", "quests.weekly" } } },
}
H.order = { "ember", "codex", "egg", "attendance", "settings", "hudEdit", "bossGate", "shop", "training", "quests" }
H.maxLen = 400 -- 설정 helpSeen 글 길이 상한(id 목록 "a,b,c")
return H
