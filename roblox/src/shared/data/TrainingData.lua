-- QUEUE-10h Q6 G3 공용 수련 · 직업 고유 능력(골드 성장원). 계산 = shared/Training.lua(순수 - 서버 · 클라 · EconSim 공용).
--   수련: 공격 · 체력 · 방어 3종. 한 단계 = perLevel(합연산). 공격 · 체력 = 마일스톤과 같은 "영구 버킷"(PlayerProfile.getMilestoneMultiplier · getMilestoneMaxHpMultiplier에 더함 - 합연산)
--     · 방어 = 옵션 축 defensePercent(옵션 합산 공통 입구 - 옵션 상한 안). 저장 = profile.training(계정 공유 - SAVE v50).
--   상한 = min(계정 최고 스테이지 ÷ stagesPerLevel(스테이지 연동), maxLevel) - 첫 측정(상한 없음 · 0.5 ~ 1%/단계)은 후반 골드가 남아돌아 전부 사져 일반 25,300이 5,774 → 1,318h로 무너졌다 → 최대 단계 + 작은 값(2차: 공격 +15% · 체력 +30%에서 상위 1% 25,300 = 2,079h → 절반 · 3차: 2,229h(하한 2,250 아래) → 체력만 다시 절반 → 2,231h · 4차 격자 ×0.25 / 0.5 / 0.75 = 2,395 / 2,383 / 2,382h → ×0.75 확정: 최대 공격 +5.6% · 체력 +5.6% · 방어 +3.75%) · 가격 = GoldCost.cost(tier1 잡몹 골드 × baseKills × levelGrowth^단계, 계정 최고 스테이지, "training")
--     - 가격이 골드 수입과 같은 율로 커지므로(GoldCost) "몇 마리분"이 단계마다 levelGrowth씩만 오른다.
--   직업 고유 능력: 직업마다 3개(공격 버킷 · 체력 버킷 · 직업 축). 저장 = classes[직업].abilities(직업별). 상한 = maxLevel(스테이지 연동 · stagesPerLevel도 같이).
--   수치(perLevel · baseKills · 상한)는 골드 예산 EconSim(docs/design/gold-budget-g3.md)으로 맞춘 값 - 결정 필요.
return {
	stagesPerLevel = 10,
	-- UI-1b 1-b 17(사용자 "+0.2%씩 올라 감흥 없음" · 경제 영향 0 방식): 한 번 누름 = 이 % 이상이 되는 최소 내부 레벨 묶음(상한까지 남은 만큼만 = 자투리 한 번에) ·
	--   내부 레벨 · 저장 · 총합 · 단계 가격은 그대로(비용 = 묶인 단계 가격 합 - Training.bundleCost) · 스위치 UiV2Flags.trainBundle.
	--   지금 값: 수련 공격 0.1%/단계 → 10단계 · 체력 0.4% → 3단계(1.2%) · 방어 0.2% → 5단계 / 직업 능력 0.0375% · 0.075% · 0.15% → +5%가 최대치보다 커서 = 상한까지 한 번에(보고)
	bundle = { stat = 0.01, ability = 0.05 },
	levelGrowth = 1.01,
	-- QUEUE-ALL9B 2(사용자 "골드를 조금만 써도 끝까지 가고 상승 %도 낮다"): 공용 수련 = 항목마다 최대 50단계 · 단계 상한 = 계정 최고 스테이지 ÷ 20(스테이지 1,000에서 50까지 열림) ·
	--   가격 = tier1 잡몹 32마리분 × 1.08^단계 × GoldCost(계정 최고 스테이지) - 단계가 오를수록 확실히 비싸다(0단계 ≈ 캐주얼 사냥 0.7분 · 39단계 ≈ 14분 · 49단계 ≈ 30분).
	--   효과(합연산): 공격 0.1%/단계(최대 +5% - 결정 ① 수련 체감 우선 — 사용자 10-03, 상위 1% 하한 2,200 → 2,150h · 옛 0.075%/최대 +3.75%) · 체력 0.4%/단계(최대 +20%) · 방어 0.2%/단계(최대 +10%).
	--   근거 = EconSim(docs/phase/QUEUE-ALL9B-report.md 3절): 캐주얼 스테이지 1,000 ≈ 37 ~ 39단계 · 50단계 ≈ 스테이지 1,800 · 상위 1% 25,300 = 공격 +3.75%에서 2,242h(통과) ·
	--   공격 +5%면 2,160h · +7.5%면 2,191h(하한 2,200 밖) - 공격 상한은 상위 1% 관문이 정한다(결정 필요). 체력 · 방어는 처치 속도에 안 걸려 크게 둘 수 있다.
	--   보스 = 실력: 기믹 실패 피해는 최대 체력 비율(BossData.mechanics.gimmickFail 55 · 85% · 방어 무시)이라 체력 · 방어 수련으로 패턴을 버틸 수 없다.
	-- PROG-2B-1 1(PROG-2A D1 A안 · D2 · D3 · GOLD-CURVE-1 G6 - 사용자 확정): 단계당 공격 · 체력 +1% · 방어 +0.5%(합연산 그대로) · 최대 50 · 상한 = 최고 스테이지 ÷ 20 그대로.
	--   가격 = priceBands(구간표 - 다음 단계 L이 속한 구간 { fromLevel, kills, growth } → kills × growth^(L − fromLevel)마리분 × GoldCost) - 1 ~ 25 = 40 × 1.04^(L − 1)(0.7 ~ 1.7분) ·
	--   26 ~ 50 = 400 × 1.04^(L − 26)(6.7 ~ 17분 · 25 → 26 계단 ×10). 1 ~ 50 합 18,324마리분(옛 32 × 1.08^L 합 18,361과 같음). 51 ~ 100 = 고급 수련(All10Data.advancedTraining).
	--   몹 HP 보정 = shared/ReferenceBuild(중앙값이 상한까지 산다고 보고 새 힘만큼 곱함 - 안 하면 상위 1% 하한 밖). 옛 값(공격 0.1% · 체력 0.4% · 방어 0.2% · 32 × 1.08^L) = ReferenceBuildData.legacyTraining.
	stats = {
		{ id = "attack", name = "공격 수련", bucket = "attack", perLevel = 0.01, maxLevel = 50, stagesPerLevel = 20, priceBands = { { fromLevel = 1, kills = 40, growth = 1.04 }, { fromLevel = 26, kills = 400, growth = 1.04 } } },
		{ id = "hp", name = "체력 수련", bucket = "hp", perLevel = 0.01, maxLevel = 50, stagesPerLevel = 20, priceBands = { { fromLevel = 1, kills = 40, growth = 1.04 }, { fromLevel = 26, kills = 400, growth = 1.04 } } },
		{ id = "defense", name = "방어 수련", axis = "defensePercent", perLevel = 0.005, maxLevel = 50, stagesPerLevel = 20, priceBands = { { fromLevel = 1, kills = 40, growth = 1.04 }, { fromLevel = 26, kills = 400, growth = 1.04 } } },
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
