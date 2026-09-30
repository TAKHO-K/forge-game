-- QUEUE-10h Q5 BR2 방어구 세트(구역 세트 + 세대 세트). 계산 = shared/SetBonus.lua(순수) · 적용 = PlayerProfile.getOptionBonus(옵션 합산 공통 입구 - 상한 Option.sumWithCap 그대로).
--   세트 부위 = 갑옷 · 장갑 · 신발 3부위. 세트 계열 = 구역(item.setZone - 그 구역 일반 몹 · 반짝이 드랍과 그 구역 보스(관문 구역) 드랍이 같은 계열) - SAVE v49.
--   세트 이름 = 구역 테마 이름(WorldMapData.zones[].theme) + " 세트" - 구역 · 종 이름 규칙과 같은 글자.
--   세대 세트(C5-6 StageGenerationData): 3부위가 모두 같은 구역 + 같은 세대(드랍 스테이지 → StageGeneration)면 효과 × (1 + budgetStepPerGeneration × 세대). 세대 이름 = 세대 접두사 + 세트 이름.
--   enabled(스위치 · 결정 필요): 성장 예산(EconSim)에 아직 안 넣었다 - 기본 꺼짐. 켜면 2부위 = 최대 체력 +5% · 3부위 = 최종 피해 +5%(합 - 옵션 축 상한 안).
return {
	enabled = false,
	parts = { "armor", "gloves", "shoes" },
	-- n부위 이상이면 켜지는 효과(누적): { axis = 옵션 축 id(OptionData와 같은 id - getOptionBonus가 합산), value }
	tiers = {
		{ pieces = 2, axis = "maxHpPercent", value = 0.05 },
		{ pieces = 3, axis = "finalDamage", value = 0.05 },
	},
	nameSuffix = " 세트",
	-- A2-N4 §4-1(결정 필요 - 기본 끔): 구역마다 고유 3부위 효과(축이 다르고 가치는 같게). 켜면(uniqueThreePiece = true · enabled도 켜야 돈다) 위 tiers의 3부위 효과 대신 이 표를 쓴다 · 2부위(최대 체력 +5%)는 공통 그대로.
	--   가치 = 지금 3부위(최종 피해 +5%)와 같은 DPS 몫: 평균 프로필(레벨 100 · 1,000 · 무기 +20 · 보석 평균 3칸 - EconSimConfig healer.gearTiers.average) 60초 로테이션에서 최종 피해 +5% = DPS ×1.0294 →
	--   같은 ×1.0294가 되는 값을 역산(Claude outputs/A2-N4/sim/set_equiv.txt · 활 · 대검 · 쌍검 평균). 생존 축(방어 · 흡혈)은 BalanceSim 생존 눈금이 게임 전투 공식(C2)과 달라 같은 가치로 못 맞췄다 = [가정] 값.
	uniqueThreePiece = false,
	zoneThreePiece = {
		tier1 = { axis = "attackPercent", value = 0.047 }, -- 석조 평원: 위력(묵직한 돌 주먹)
		tier2 = { axis = "crit", value = 0.030 }, -- 수정 동굴: 치명(확률 · 피해 같은 값 - 옵션 치명과 같은 규칙)
		tier3 = { axis = "lifesteal", value = 0.01 }, -- 수몰 사원: 흡혈 [가정 - 옵션 기본값 0.03의 1/3]
		tier4 = { axis = "speedPercent", value = 0.050 }, -- 모래 유적: 신속(모래바람)
		tier5 = { axis = "finalDamage", value = 0.05 }, -- 폭풍 첨탑: 최종 피해(지금 3부위 그대로)
		tier6 = { axis = "defensePercent", value = 0.10 }, -- 빙하 동굴: 방어 [가정]
	},
}
