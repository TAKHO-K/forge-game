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
		-- QUEUE-ALL6 H 새 칸 6(꾸미기 소품 - 칸 하나짜리 상품 · items 목록 · 저장 profile.cosmetics.items v64). 겉모습만(판정 · 전투력 없음).
		{ id = "killFx", default = "none", hook = "client/CosmeticFx(처치 - 서버 CosmeticKill 중계)", unlock = "product" },
		{ id = "weaponSkin", default = "none", hook = "client/WeaponVisual(몸 재질만 - 등급 빛 그대로)", unlock = "product" },
		{ id = "enhanceFx", default = "none", hook = "client/CosmeticFx(EnhanceResult 성공만)", unlock = "product" },
		{ id = "recallFx", default = "none", hook = "client/CosmeticFx(RecallCastUntil)", unlock = "product" },
		{ id = "emote", default = "none", hook = "client/CosmeticFx(EmoteEvent - 파티원 수락)", unlock = "product" },
		{ id = "petAccessory", default = "none", hook = "client/PetView(펫 몸 틀 3종)", unlock = "product" },
	},
	-- QUEUE-ALL6 H 꾸미기 소품(칸 하나): { id, slot, name, look, seasonMonth? = 그 달(KST)에만 판매 }. 상점 = 치장 탭 안 "소품" 분류(칸별 묶음).
	itemSlots = { "killFx", "weaponSkin", "enhanceFx", "recallFx", "emote", "petAccessory" },
	items = {
		{ id = "rocketPop", slot = "killFx", name = "로켓 반짝", look = "rocket" }, -- #24 하늘 멀리 "반짝" + 작은 별 터짐(실제 몹은 그 자리에서 죽음 · 날아가는 건 그림)
		{ id = "balloonPop", slot = "killFx", name = "풍선 펑", look = "balloon" }, -- #26 부풀었다가 펑 + 색종이
		{ id = "crystalBlade", slot = "weaponSkin", name = "수정 결정 무기", look = "crystal" }, -- #3 반투명 자수정(무기 등급 빛은 그 위에 그대로)
		{ id = "goldenHammer", slot = "enhanceFx", name = "황금 망치", look = "goldenHammer" }, -- #70 강화 성공 장면만 금빛
		{ id = "forgeBrazier", slot = "recallFx", name = "대장간 화로", look = "brazier" }, -- #64 귀환 집중 · 사라짐
		{ id = "highFive", slot = "emote", name = "하이파이브", look = "highFive" }, -- #86 파티원 둘 · 상대 수락
		{ id = "petCrown", slot = "petAccessory", name = "펫 왕관", look = "crown" }, -- #75 펫 몸 3종(개 · 고양이 · 용)에 맞춤
		{ id = "starCrown", slot = "petAccessory", name = "별빛 왕관", look = "starCrown", boardOnly = 1 }, -- QUEUE-ALL9B 5 시즌 출석판 32칸 전용(상점 · 토큰 · 선물 X · 시즌 번호)
	},
	-- 트레일 세트 1개 = unlock "set" 칸 전부(4). 세트 항목 모양 = { id, name, looks = { dashTrail = …, jumpFx = …, glideTrail = …, footstep = … } }
	setSlots = { "dashTrail", "jumpFx", "glideTrail", "footstep" },
	-- QUEUE-B1 B2(P4c 골격): 테마 세트 목록 - 외형(looks) = 에셋 자리(A2-N2: ArtV1CosmeticData.themes 키 - ArtStyleV1 스위치 뒤에서만 그림 · "" = 기본 모습). 사는 법 = 반짝 조각(MonetizationData.shardPrices.theme) 또는
	--   로벅스 상품(MonetizationData.products.theme_<id>) · 시즌 패스 줄. 산 세트의 4칸은 칸마다 다른 세트와 섞어 장착한다(profile.cosmetics.equipped).
	sets = {
		{ id = "starlight", name = "별빛", looks = { dashTrail = "starlight", jumpFx = "starlight", glideTrail = "starlight", footstep = "starlight" } },
		{ id = "ember", name = "불씨", looks = { dashTrail = "ember", jumpFx = "ember", glideTrail = "ember", footstep = "ember" } },
		{ id = "frost", name = "서리꽃", looks = { dashTrail = "frost", jumpFx = "frost", glideTrail = "frost", footstep = "frost" } },
		{ id = "jelly", name = "말랑 젤리", looks = { dashTrail = "jelly", jumpFx = "jelly", glideTrail = "jelly", footstep = "jelly" } }, -- QUEUE-ALL1 P6(07 문서 · 199)
		{ id = "anvil", name = "망치와 모루", looks = { dashTrail = "anvil", jumpFx = "anvil", glideTrail = "anvil", footstep = "anvil" } }, -- QUEUE-ALL6 H #42 대시 금노랑 불꽃 · 점프 "깡!" 고리 · 활강 불씨 줄 · 발자국 망치 자국
		{ id = "halloween", name = "할로윈 박쥐", looks = { dashTrail = "halloween", jumpFx = "halloween", glideTrail = "halloween", footstep = "halloween" }, seasonMonth = 10 },
		-- QUEUE-ALL9B 4 시즌 패스 전용(passOnly - 상점 · 토큰 · 선물 X · 시즌 줄에서만) · 외형 = ArtV1CosmeticData 색 변형
		{ id = "meadowStar", name = "초원 별빛", looks = { dashTrail = "meadowStar", jumpFx = "meadowStar", glideTrail = "meadowStar", footstep = "meadowStar" }, passOnly = true },
		{ id = "violetStar", name = "보랏빛 별", looks = { dashTrail = "violetStar", jumpFx = "violetStar", glideTrail = "violetStar", footstep = "violetStar" }, passOnly = true },
		{ id = "auroraFrost", name = "오로라 서리", looks = { dashTrail = "auroraFrost", jumpFx = "auroraFrost", glideTrail = "auroraFrost", footstep = "auroraFrost" }, passOnly = true },
		{ id = "sodaJelly", name = "소다 젤리", looks = { dashTrail = "sodaJelly", jumpFx = "sodaJelly", glideTrail = "sodaJelly", footstep = "sodaJelly" }, passOnly = true },
		{ id = "moonEmber", name = "달빛 불씨", looks = { dashTrail = "moonEmber", jumpFx = "moonEmber", glideTrail = "moonEmber", footstep = "moonEmber" }, passOnly = true },
		{ id = "cloudWhaleTrail", name = "구름 고래 물결", looks = { dashTrail = "cloudWhaleTrail", jumpFx = "cloudWhaleTrail", glideTrail = "cloudWhaleTrail", footstep = "cloudWhaleTrail" }, seasonOnly = 1 }, -- QUEUE-ALL6 H #50 10월 한정 판매(산 사람은 계속) · 박쥐 떼 · 호박 발자국
	},
	-- 글라이더 스킨 상품 = 칸 하나(gliderSkin)만. 항목 모양 = { id, name, look }
	gliderSkins = { -- QUEUE-B1 B2: 글라이더 스킨(칸 하나 · look = 에셋 자리)
		{ id = "petal", name = "꽃잎 글라이더", look = "" },
		{ id = "kite", name = "연 글라이더", look = "" },
		-- QUEUE-ALL1 P6(07 문서): look = client/GlideView가 그리는 모양 id(판정 · 속도 불변 - 겉모습만)
		{ id = "dragonWing", name = "푸른 드래곤 날개", look = "dragonWing" }, -- 149 · 등에 T6 푸른 드래곤 날개(monsters/blue_dragon Wing_L · Wing_R 메시 재사용) · 천천히 날갯짓
		{ id = "slimeParachute", name = "슬라임 낙하산", look = "slimeParachute" }, -- QUEUE-ALL6 H #55 말랑한 슬라임 덮개 + 줄(판정 · 속도 불변)
		{ id = "cloudWhale", name = "구름 고래", look = "cloudWhale", seasonOnly = 1 }, -- 시즌 1 유료 줄 40칸 대표 · 작은 구름 고래를 타고 활강 + 물보라 궤적(extras/cloud_whale) · QUEUE-ALL1 R1(사용자): 시즌 1 한정 · 재판매 없음(상품 · 반짝 조각 · 선물 X) · 조급함 연출 금지(남은 시간 강조 · "곧 사라짐" 문구 없음)
		-- QUEUE-ALL9B 4 시즌 패스 전용 글라이더(색 변형 - base 모양 그대로)
		{ id = "mintParachute", name = "민트 낙하산", look = "mintParachute", passOnly = true },
		{ id = "berryParachute", name = "베리 낙하산", look = "berryParachute", passOnly = true },
		{ id = "jadeWing", name = "비취 날개", look = "jadeWing", passOnly = true },
		{ id = "amethystWing", name = "자수정 날개", look = "amethystWing", passOnly = true },
	},
}
