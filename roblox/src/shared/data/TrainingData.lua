-- QUEUE-10h Q6 G3 공용 수련 · 직업 고유 능력(골드 성장원). 계산 = shared/Training.lua(순수 - 서버 · 클라 · EconSim 공용).
--   수련: 공격 · 체력 · 방어 3종. 한 단계 = perLevel(합연산). 공격 · 체력 = 마일스톤과 같은 "영구 버킷"(PlayerProfile.getMilestoneMultiplier · getMilestoneMaxHpMultiplier에 더함 - 합연산)
--     · 방어 = 옵션 축 defensePercent(옵션 합산 공통 입구 - 옵션 상한 안). 저장 = profile.training(계정 공유 - SAVE v50).
--   상한 = min(계정 최고 스테이지 ÷ stagesPerLevel(스테이지 연동), maxLevel) - 첫 측정(상한 없음 · 0.5 ~ 1%/단계)은 후반 골드가 남아돌아 전부 사져 일반 25,300이 5,774 → 1,318h로 무너졌다 → 최대 단계 + 작은 값(2차: 공격 +15% · 체력 +30%에서 상위 1% 25,300 = 2,079h → 절반 · 3차: 2,229h(하한 2,250 아래) → 체력만 다시 절반 → 2,231h · 4차 격자 ×0.25 / 0.5 / 0.75 = 2,395 / 2,383 / 2,382h → ×0.75 확정: 최대 공격 +5.6% · 체력 +5.6% · 방어 +3.75%) · 가격 = GoldCost.cost(tier1 잡몹 골드 × baseKills × levelGrowth^단계, 계정 최고 스테이지, "training")
--     - 가격이 골드 수입과 같은 율로 커지므로(GoldCost) "몇 마리분"이 단계마다 levelGrowth씩만 오른다.
--   직업 고유 능력: 직업마다 3개(공격 버킷 · 체력 버킷 · 직업 축). 저장 = classes[직업].abilities(직업별). 상한 = maxLevel(스테이지 연동 · stagesPerLevel도 같이).
--   수치(perLevel · baseKills · 상한)는 골드 예산 EconSim(docs/design/gold-budget-g3.md)으로 맞춘 값 - 결정 필요.
return {
	stagesPerLevel = 10,
	levelGrowth = 1.01,
	stats = {
		{ id = "attack", name = "공격 수련", bucket = "attack", perLevel = 0.000375, maxLevel = 100, baseKills = 30 },
		{ id = "hp", name = "체력 수련", bucket = "hp", perLevel = 0.000375, maxLevel = 100, baseKills = 30 },
		{ id = "defense", name = "방어 수련", axis = "defensePercent", perLevel = 0.000375, maxLevel = 100, baseKills = 30 },
	},
	-- 직업 고유 능력: 직업 DPS 최저 대비 ≤ 1.32 유지(K1 규칙) - 네 직업 모두 공격 · 체력 버킷은 같은 값, 직업 축만 다르다(속도 축은 상한 작게).
	classAbilities = {
		greatsword = {
			{ id = "gs_might", name = "대검 숙련", bucket = "attack", perLevel = 0.000375, maxLevel = 50, baseKills = 60 },
			{ id = "gs_iron", name = "강철 체력", bucket = "hp", perLevel = 0.000375, maxLevel = 50, baseKills = 60 },
			{ id = "gs_guard", name = "철벽", axis = "defensePercent", perLevel = 0.0015, maxLevel = 25, baseKills = 60 },
		},
		dualblade = {
			{ id = "db_might", name = "쌍검 숙련", bucket = "attack", perLevel = 0.000375, maxLevel = 50, baseKills = 60 },
			{ id = "db_iron", name = "질긴 몸", bucket = "hp", perLevel = 0.000375, maxLevel = 50, baseKills = 60 },
			{ id = "db_swift", name = "잔걸음", axis = "speedPercent", perLevel = 0.00075, maxLevel = 25, baseKills = 60 },
		},
		bow = {
			{ id = "bow_might", name = "활 숙련", bucket = "attack", perLevel = 0.000375, maxLevel = 50, baseKills = 60 },
			{ id = "bow_iron", name = "단련된 몸", bucket = "hp", perLevel = 0.000375, maxLevel = 50, baseKills = 60 },
			{ id = "bow_swift", name = "빠른 시위", axis = "speedPercent", perLevel = 0.00075, maxLevel = 25, baseKills = 60 },
		},
		healer = {
			{ id = "hl_might", name = "치유사 숙련", bucket = "attack", perLevel = 0.000375, maxLevel = 50, baseKills = 60 },
			{ id = "hl_iron", name = "성스러운 몸", bucket = "hp", perLevel = 0.000375, maxLevel = 50, baseKills = 60 },
			{ id = "hl_grace", name = "은총", axis = "healingPower", perLevel = 0.0015, maxLevel = 25, baseKills = 60 },
		},
	},
}
