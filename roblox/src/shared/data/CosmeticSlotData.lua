-- MV1 이동 치장 슬롯 자리(수익화 P4c용 - 지금은 데이터 자리만: 저장 · 상점 · 장착 UI 없음).
--   구조(사용자): 테마 세트 1개를 사면 그 세트의 칸이 해금되고, 칸마다 다른 세트와 섞어 장착한다.
--   slots = 치장 칸(순서 = 표시 순서) · 칸마다 기본값(default - 지금 게임이 그리는 모습) · hook = 그 모습을 그리는 클라 코드(칸을 바꾸면 여기만 읽게 한다).
--   지시 문구 "세트 1개 = 4칸 해금"과 칸 목록 5개(글라이더 스킨 · 활강 궤적 · 대시 트레일 · 점프 이펙트 · 걷기 발자국)가 다르다 → setUnlockSlots = 4는 결정 대기(MV1 보고서).
return {
	slots = {
		{ id = "gliderSkin", default = "leaf", hook = "client/GlideView" },
		{ id = "glideTrail", default = "none", hook = "client/GlideView" },
		{ id = "dashTrail", default = "classAccent", hook = "client/SkillEffects.dashAfterimage" },
		{ id = "jumpFx", default = "flip", hook = "client/AirMotion" },
		{ id = "footstep", default = "none", hook = "(없음 - D1-3에서 태초 발자국 삭제)" },
	},
	setUnlockSlots = 4,
	sets = {}, -- 테마 세트 목록(P4c)
}
