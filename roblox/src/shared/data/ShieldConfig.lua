-- 쉴드 층 겹침 규칙(S13b, 사용자 지시 2026-09-20). 쉴드는 대상마다 "층 목록"이고 층 하나 = { 양, 만료 시각, 시전자 }다(shared/ShieldLayers.lua).
-- 누가 어떤 양 · 지속시간으로 거는가는 스킬 데이터가 정한다(SkillData.healer.Q.shield) - 여기는 층이 쌓이는 규칙만 둔다.
return {
	-- 대상 1명당 최대 층 수. 이미 이만큼 있으면 (자기 층을 교체하는 경우가 아닌) 새 쉴드는 걸리지 않는다.
	maxLayers = 4,
	-- 시전 순간에 대상에게 이미 이 층 수 이상 있으면(교체할 때는 자기 층을 뺀 수) 새 쉴드량에 halveMultiplier를 곱한다 - 3 · 4번째 층은 반감.
	halveFromExistingLayers = 2,
	halveMultiplier = 0.5,
}
