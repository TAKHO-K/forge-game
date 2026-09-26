-- MV1 이동 치장 슬롯 자리(수익화 P4c용 - 지금은 데이터 자리만: 저장 · 상점 · 장착 UI 없음).
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
	sets = {}, -- 트레일 세트 목록(P4c)
	-- 글라이더 스킨 상품 = 칸 하나(gliderSkin)만. 항목 모양 = { id, name, look }
	gliderSkins = {}, -- (P4c)
}
