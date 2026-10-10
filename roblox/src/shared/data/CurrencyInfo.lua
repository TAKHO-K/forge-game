-- UI-1b 1절 15 · 16(I v1 spec 0-4 · pc_10 · ph_06): 재화 · 칩 설명 창(A 설명 창) 문구 = 키(TextData_ui1b) · 제목 = 이름("골드") · 줄 = 사용처 · 획득처
--   (사용자 10-10: "이게 무엇 · 어디에 씀 · 어디서 얻음" 대신 간단한 단어 - what 문구는 남겨 두되 줄로는 안 씀).
--   이름 = item.name.<id>(ItemInfoData 같은 이름) · 그림 = icons/reward/<id>. 새 재화 = 여기 한 줄 + 글자 키(ko · en).
return {
	rows = { "where", "use" }, -- 줄 순서 = 획득처 → 사용처(사용자 10-10: 모든 InfoTip 같은 틀 - 첫 줄 이름 한 단어 · "획득처: …" · "사용처: …")
	ids = {
		gold = { name = "item.name.gold" },
		sparkleShard = { name = "item.name.sparkleShard" },
		enhanceStone = { name = "item.name.enhanceStone" },
		highEnhanceStone = { name = "item.name.highEnhanceStone" },
		gemDust = { name = "item.name.gemDust" },
		power = { name = "ui1b.chip.power" },
		level = { name = "ui1b.chip.level" },
	},
}
