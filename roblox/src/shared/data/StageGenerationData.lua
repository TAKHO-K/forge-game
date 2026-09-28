-- C5-6 세대(世代) 데이터(docs/design/growth-curve-v2.md §7 - 자리만): 천장 17,000부터 everyStages마다 세대가 바뀐다(중반 5,000 · 후반 10,000 선택 시작점은 startStage로).
--   세대마다 이름 접미사 · 세대 세트 옵션 id(자리) · 세트 예산 배율(+budgetStepPerGeneration/세대) · 일반 몹 틴트 + 이름 접두사 · 관문 보스 id · 변이 id(자리) · 칭호 id(자리).
--   지금 구현 = 스테이지 → 세대 조회(shared/StageGeneration) · 몹 틴트 + 접두사(클라 GenerationView - 내 스테이지 기준) · 드랍 세트 이름 접미사(ItemDescribe). 관문 보스 변이 · 스킬 변경 · 세트 옵션 효과 = BR2 · 칭호 = U1.
return {
	startStage = 17000,
	everyStages = 1000,
	budgetStepPerGeneration = 0.10, -- 세대 세트 예산 배율 = 1 + 0.10 × 세대(자리 - 옵션 효과는 BR2)
	-- 세대 표(index = 세대 번호 1 ~ · 표 밖 = 마지막 행을 번호만 올려 되풀이). tint = 몹 몸통 색을 이 색 쪽으로 tintAlpha만큼.
	generations = {
		{ suffix = "잿빛", prefix = "잿빛", tint = Color3.fromRGB(120, 120, 130), setOptionId = "gen_ash", gateBossId = nil, mutationId = nil, titleId = nil },
		{ suffix = "핏빛", prefix = "핏빛", tint = Color3.fromRGB(170, 40, 50), setOptionId = "gen_blood", gateBossId = nil, mutationId = nil, titleId = nil },
		{ suffix = "서릿빛", prefix = "서릿빛", tint = Color3.fromRGB(150, 210, 255), setOptionId = "gen_frost", gateBossId = nil, mutationId = nil, titleId = nil },
		{ suffix = "황금빛", prefix = "황금빛", tint = Color3.fromRGB(230, 190, 80), setOptionId = "gen_gold", gateBossId = nil, mutationId = nil, titleId = nil },
		{ suffix = "칠흑", prefix = "칠흑", tint = Color3.fromRGB(30, 25, 40), setOptionId = "gen_void", gateBossId = nil, mutationId = nil, titleId = nil },
	},
	tintAlpha = 0.45,
}
