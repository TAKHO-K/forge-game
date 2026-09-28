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

	-- 아슬아슬 회피(서버 공통 판정 - TranscendentService): 전조 종료 windowSeconds 전에 위험 범위 안 → 적중 순간 밖 + 피해 0.
	--   graceSeconds = 적중 판정 뒤 이만큼 안에 피해가 없어야 "피해 0"(판정 틱 · 지연 여유). 지연 0.25 오판정 목표 각 ≤ 5%(Play 실측).
	closeDodge = { windowSeconds = 0.4, graceSeconds = 0.15 },

	-- 특수 옵션(부위별 1개 고정 · 리롤 불가 · 본인만) - item.special
	specialByPart = { gloves = "plunder", armor = "reversal", shoes = "soar" },
	specialNames = { plunder = "강탈", reversal = "역전", soar = "비상" },

	-- 강탈: 아슬아슬 회피한 패턴의 파편 1개 저장(새 회피 = 교체 · 보스전 끝 holdSeconds 뒤 소멸) → 다음 강공격(3타) 또는 Q에서 플레이어판으로 변환.
	--   파편 = 보스 스킬 primitive → { kind(연출 종류), radius(적중 반경) , multiplier(플레이어 공격력 계수 - 보스 수치 아님) }. 잡몹에도 사용.
	--   지시의 8종 매핑(지진파 · 돌진 · 눈덩이 · 낙뢰 · 회오리 · 독침 · 레이저 · 판 뒤집기) - 판정은 전부 "대상 둘레 원형 추가 타격"(고유 연출 · 띄움 · 투사체형 반사는 A2/BR2 - 결정 필요).
	plunder = {
		holdSeconds = 30,
		fragments = {
			circleBoss = { kind = "quake", label = "소형 파동", radius = 10, multiplier = 1.2 },
			ring = { kind = "quake", label = "소형 파동", radius = 10, multiplier = 1.2 },
			charge = { kind = "dashSlash", label = "돌진 베기", radius = 7, multiplier = 1.5 },
			circleTarget = { kind = "meteor", label = "낙뢰 1발", radius = 6, multiplier = 1.8 },
			line = { kind = "laser", label = "짧은 레이저", radius = 8, multiplier = 1.4 },
			gimmick = { kind = "flip", label = "앞 원형 넉백", radius = 9, multiplier = 1.0 },
		},
		fallback = { kind = "quake", label = "소형 파동", radius = 8, multiplier = 1.0 },
	},

	-- 역전: HP ≤ stunThreshold → 강공격이 잡몹 기절(stunSeconds) + 보스 피해 +bossBonus / HP ≤ surgeThreshold → Q 강화판(계수 × surgeCoefficient · 쿨 × surgeCooldownScale). 받는 피해 감소 · 회복 없음.
	reversal = { stunThreshold = 0.5, stunSeconds = 0.6, bossBonus = 0.15, surgeThreshold = 0.2, surgeCoefficient = 1.5, surgeCooldownScale = 0.5 },

	-- 비상: 아슬아슬 회피 또는 공중 강공격 적중 시 공중 행동(공중 점프 · 대시 · 공격) 초기화(쿨 resetCooldownSeconds). 최고 높이 상한(MovementConfig)은 그대로.
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
