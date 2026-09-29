-- MV1 이동 치장 슬롯 자리(수익화 P4c용). QUEUE-B1 B2: 저장(v56 profile.cosmetics) · 구매 · 장착 = server/CosmeticService · 상점 탭 = client/panels/Shop.
--   구조(사용자): 테마 세트 1개를 사면 그 세트의 칸이 해금되고, 칸마다 다른 세트와 섞어 장착한다.
--   slots = 치장 칸(순서 = 표시 순서) · 칸마다 기본값(default - 지금 게임이 그리는 모습) · hook = 그 모습을 그리는 클라 코드(칸을 바꾸면 여기만 읽게 한다) ·
--   unlock = 해금 경로("set" = 트레일 세트 1개가 4칸을 한 번에 연다 · "product" = 칸 하나짜리 별도 상품).
--   파트 0(MV1 결정 7 확정): 트레일 세트 = 대시 트레일 · 점프 이펙트 · 활강 궤적 · 걷기 발자국 4칸 · 5번째 칸 글라이더 스킨 = 별도 상품.
return {
	slots = {
		{ id = "dashTrail", default = "classAccent", hook = "client/SkillEffects.dashAfterimage", unlock = "set" },
		{ id = "jumpFx", default = "flip", hook = "client/AirMotion", unlock = "set" },
		{ id = "glideTrail", default = "none", hook = "client/GlideView", unlock = "set" },
		{ id = "footstep", default = "none", hook = "(없음 - D1-3에서 태초 발자국 삭제)", unlock = "set" },
		{ id = "gliderSkin", default = "leaf", hook = "client/GlideView", unlock = "product" },
	},
	-- 트레일 세트 1개 = unlock "set" 칸 전부(4). 세트 항목 모양 = { id, name, looks = { dashTrail = …, jumpFx = …, glideTrail = …, footstep = … } }
	setSlots = { "dashTrail", "jumpFx", "glideTrail", "footstep" },
	-- QUEUE-B1 B2(P4c 골격): 테마 세트 목록 - 외형(looks) = 에셋 자리(A2-N2: ArtV1CosmeticData.themes 키 - ArtStyleV1 스위치 뒤에서만 그림 · "" = 기본 모습). 사는 법 = 반짝 조각(MonetizationData.shardPrices.theme) 또는
	--   로벅스 상품(MonetizationData.products.theme_<id>) · 시즌 패스 줄. 산 세트의 4칸은 칸마다 다른 세트와 섞어 장착한다(profile.cosmetics.equipped).
	sets = {
		{ id = "starlight", name = "별빛", looks = { dashTrail = "starlight", jumpFx = "starlight", glideTrail = "starlight", footstep = "starlight" } },
		{ id = "ember", name = "불씨", looks = { dashTrail = "ember", jumpFx = "ember", glideTrail = "ember", footstep = "ember" } },
		{ id = "frost", name = "서리꽃", looks = { dashTrail = "frost", jumpFx = "frost", glideTrail = "frost", footstep = "frost" } },
	},
	-- 글라이더 스킨 상품 = 칸 하나(gliderSkin)만. 항목 모양 = { id, name, look }
	gliderSkins = { -- QUEUE-B1 B2: 글라이더 스킨(칸 하나 · look = 에셋 자리)
		{ id = "petal", name = "꽃잎 글라이더", look = "" },
		{ id = "kite", name = "연 글라이더", look = "" },
	},
}
