-- C5-7 초월(超越) 등급(docs/design/transcendent-tier.md). 8번째 등급(ArmorData.gradeOrder 마지막) - 여기 있는 값이 초월의 전부다(연출 색 · 드랍 · 특수 옵션 · 알림).
-- 서버(TranscendentService · PrimordialRegistry · Loot · PlayerProfile)와 클라(PrimordialFx · DetailSheet)가 같이 읽는다.

return {
	gradeId = "transcendent",
	-- 위력: 딜 부위(장갑 · 신발) 초월 = 태초(고대 × 1.25) × 이 값 = 고대 × 1.5 · 갑옷 방어 = 태초 × armorStep.
	dpsStepOverPrimordial = 1.5 / 1.25,
	armorStep = 1.5,

	-- 공급(바닥 드랍 자체 확률 - 해당 표에서 영웅 몫을 같은 양만큼 줄여 합 1 유지). 일반 몹 = 별도 굴림(태초와 같은 방식 · 레벨 감쇠 적용) × tier 3구간 배율.
	drop = {
		bossFirstClear = 0.00001, -- 0.001%
		raid = 0.000002, -- 0.0002%
		sparkle = 0.000005, -- 0.0005%
		field = 0.0000001, -- 0.00001%(장비 1개당 · tier 배율 전)
		fieldTierScale = { 0.7, 0.7, 1, 1, 1.4, 1.4 },
	},

	-- 처리: 분해 불가 · 판매 불가 · 각성 무료 · 무제한 · 기본 잠금 · 계승 가능(특수 옵션 = 부위 고정이라 같이 간다).
	dismantleBlocked = true,
	sellBlocked = true,
	awakenFree = true,

	-- 특수 옵션(부위별 1개 고정 · 리롤 불가 · 본인만). C5-7b(사용자 결정): 강탈 · 역전 · 아슬아슬 회피 폐기 → 환영 · 광폭. 판정 = TranscendentService.
	--   부위 고정이라 item.special(v47 옛 값 plunder · reversal 포함)은 읽지 않고 이 표로 정한다 - 저장 구조 변경 없음.
	specialByPart = { gloves = "phantom", armor = "frenzy", shoes = "soar" },
	specialNames = { phantom = "환영", frenzy = "광폭", soar = "비상" },

	-- 환영(幻影 - 장갑): 기본 공격이 대상에 들어가면 chance 확률(서버 굴림)로 등 뒤 환영이 같은 대상에 추가타 1회 = 기본 공격 피해 1회분(한 타 배율 · 딜링모드 · 치명 굴림 포함 · 3타 배율 제외).
	--   환영 추가타 heavyEvery번째마다 강공격(3타 강공격 배율 · 연출). 공격 요청 1회당 최대 1번 · 보스 포함 · 근접 즉시 판정(원거리 직업도 화살 도달 순간 같은 대상에 즉시).
	--   연출(클라 PrimordialFx): 등 뒤 back · up stud에 흑금 무기 + 팔(임시 파트) · 추가타 때 대상으로 lungeSeconds 찌르고 돌아온다 · sendStuds 안의 사람에게만.
	phantom = { chance = 0.25, heavyEvery = 3, sendStuds = 120, backStuds = 2.2, upStuds = 1.6, lungeSeconds = 0.16, returnSeconds = 0.22, bodyTransparency = 0.45 },

	-- 광폭(狂暴 - 갑옷): 전투 중(최근 combatWindowSeconds 안에 공격했거나 맞음 - PlayerState.lastCombatActionAt) 이동 속도 +moveSpeedBonus · 공격 속도 +attackSpeedBonus(신발 공속 % 합에 더한다 →
	--   공속 상한 ×2.5 · 최소 간격 0.33초 · 넘는 몫 = 피해 환산 그대로) · 대시(DashConfig) · 돌진형 스킬(shape = "dash") 쿨 × dashCooldownScale. 이속은 JumpMath.moveSpeedMultiplier 상한(×1.5) 안.
	--   발동 중 흑금 오라가 짙어진다(auraTransparency - 평소 0.5 맥동).
	frenzy = { combatWindowSeconds = 5, moveSpeedBonus = 0.10, attackSpeedBonus = 0.10, dashCooldownScale = 0.8, auraTransparency = 0.15 },

	-- 비상(신발): 공중 강공격(3타)이 적에게 적중하면 공중 행동(공중 점프 · 대시 · 공격) 초기화(쿨 resetCooldownSeconds). 공중 스킬은 원래 착지 판정 · 공중 행동을 쓰지 않는다(SkillServer - 유지).
	--   최고 높이 상한(MovementConfig · HeightGuard 24.38)은 그대로 - 세션 정점은 안 건드린다.
	soar = { resetCooldownSeconds = 4 },

	-- 알림 · 낭만(태초 = 같은 서버만 · 초월 = 전 서버): 세계 번호 카운터 · 최근 목록 · 토픽 · 칭호 · 색.
	announce = {
		counterKey = "transcendentCounter",
		recentKey = "recentTranscendent",
		topic = "TranscendentFound",
		titleId = "transcendentOne",
		bannerSeconds = 8,
		slowSeconds = 1.0,
		pillarSeconds = 45,
		glyph = "✦",
		color = Color3.fromRGB(214, 176, 62), -- 옅은 금
		darkColor = Color3.fromRGB(16, 13, 10), -- 검은 본체
		chatText = "★ {name}님이 세계 {no}번째 초월 [{part}]를 획득했습니다!", -- TextData transcendent.worldChat과 같은 문장(서버 배너 payload가 이름 · 번호 · 부위를 준다)
	},
}
