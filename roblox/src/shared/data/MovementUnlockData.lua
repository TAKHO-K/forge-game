-- MV1 환생 해금표(사용자 결정 - 해금표는 데이터로). 이동 · 공중 전투 기술은 환생 횟수로 열린다.
--   기준 환생 횟수 = 계정의 직업 중 가장 많이 환생한 횟수(PlayerProfile - Player Attribute MoveTier). 직업을 바꿔도 이동 기술은 그대로다.
--   저장 필드는 없다(환생 횟수에서 매번 파생) - 개발 계정의 옛 저장(공중 점프 2회 사용 중)은 이관 없이 그 계정의 최대 환생 횟수대로 열린다(MV1 보고서 §해금).
--   tiers[환생 횟수] = {
--     airJumps           공중 점프 충전(착지하면 다시 찬다 - MovementConfig.airJump.heightFraction) · 0이면 공중 점프 없음
--     airAttack          공중 공격 가능(아니면 공중 클릭 = 옛 규칙대로 착지 순간 발동하는 버퍼)
--     glide              활강(공중에서 대시 길게 누름 - MovementConfig.glide)
--     airHeavy           공중 3타 = 강공격 판정 + 무기 반짝임(아니면 공중 3타도 일반 타격)
--     glideSecondsBonus  활강 게이지 + 초
--     airDashRangeMultiplier 공중 대시 거리 ×(지상 대시는 그대로)
--   }
--   공중 대시는 환생 0부터 한 체공 1회(태초 신발 = DashConfig.primordialShoes.charges회).
local TIERS = {
	[0] = { airJumps = 0, airAttack = false, glide = false, airHeavy = false, glideSecondsBonus = 0, airDashRangeMultiplier = 1 },
	[1] = { airJumps = 1, airAttack = true, glide = false, airHeavy = false, glideSecondsBonus = 0, airDashRangeMultiplier = 1 },
	[2] = { airJumps = 1, airAttack = true, glide = true, airHeavy = false, glideSecondsBonus = 0, airDashRangeMultiplier = 1 },
	[3] = { airJumps = 2, airAttack = true, glide = true, airHeavy = true, glideSecondsBonus = 0, airDashRangeMultiplier = 1 },
	[4] = { airJumps = 2, airAttack = true, glide = true, airHeavy = true, glideSecondsBonus = 3, airDashRangeMultiplier = 1.25 },
	[5] = { airJumps = 2, airAttack = true, glide = true, airHeavy = true, glideSecondsBonus = 3, airDashRangeMultiplier = 1.25 },
}

return {
	tiers = TIERS,
	maxTier = 5,

	-- 공중 공격 예산(한 체공 - 서버 AirState가 세고 넘으면 거부): 해금된 공중 점프 1개당 perUnlockedJump회 + 이번 체공에 쓴 공중 대시 1번당 perAirDash회.
	--   예: 환생 3 = 2 + 대시 1 = 3(공중 3타 강공격). 예산은 "해금 수"로 센다(공중 점프를 실제로 썼는지와 무관 - 점프 직후 정점에서 쳐도 된다). 착지하면 새 체공 = 새 예산.
	--   태초 장갑은 예산을 늘리지 않는다(사용자 수정 - 태초 특수옵션 = 성장 속도에 닿지 않는 유틸: 장갑 = 붙잡기 MovementConfig.ledgeGrab).
	airAttack = { perUnlockedJump = 1, perAirDash = 1 },

	-- 해금 순간 안내(18번 시트 규칙 - 그림 + 한 줄 · 40자 이하 · 번역 가능 문자열 TextData moveUnlock.popup.<n>). diagram = 클라 MoveUnlockPopup이 그리는 그림 종류.
	popups = {
		[1] = { diagram = "airJump", textKey = "moveUnlock.popup.1" },
		[2] = { diagram = "glide", textKey = "moveUnlock.popup.2" },
		[3] = { diagram = "airCombo", textKey = "moveUnlock.popup.3" },
		[4] = { diagram = "boost", textKey = "moveUnlock.popup.4" },
		[5] = { diagram = "weapon", textKey = "moveUnlock.popup.5" },
	},

	-- 환생 보상 목록(환생 1 ~ 5 보상 줄 - 보상 줄 UI는 U1 · 지금은 환생 탭에 간단 표시). 줄 = TextData 키(한 줄 = 한 보상).
	rewardRows = {
		[1] = { "moveUnlock.reward.1" },
		[2] = { "moveUnlock.reward.2" },
		[3] = { "moveUnlock.reward.3" },
		[4] = { "moveUnlock.reward.4" },
		[5] = { "moveUnlock.reward.5" },
	},

	-- 환생 횟수 → 해금 행(범위 밖은 끝으로 자른다).
	tierFor = function(rebirthCount)
		local n = math.clamp(math.floor(tonumber(rebirthCount) or 0), 0, 5)
		return TIERS[n], n
	end,
}
