-- C5-5 복귀 부스트(docs/design/growth-curve-v2.md §7): 마지막 저장(profile.savedAt) 뒤 awayDays 이상 지나 접속하면 첫 boostSeconds 동안 경험치 · 드랍 × multiplier.
--   서버 판정(SaveServer 로드 직후 - profile.comeback.untilAt 저장 필드 v48) · 표시 = Player Attribute ComebackUntil(클라 토스트 · HUD) · 경험치 = PlayerProfile.getExpGainMultiplier · 드랍 = CombatResolution 장비 기대 개수.
--   악용 검사(보고서): 7일 쉬고 60분만 하는 패턴의 이득 = 60분 × 1.5 = 90분분 ≤ 일반 1일분(3시간 = 180분) - 매주 반복해도 일반 1일분을 못 넘는다.
return {
	awayDays = 7,
	boostSeconds = 3600,
	multiplier = 1.5,
}
