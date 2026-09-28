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
}
