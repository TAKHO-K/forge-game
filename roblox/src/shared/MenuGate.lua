-- 메인 메뉴 버그(10-05): 메뉴는 모든 접속에서 보인다(Studio Play 포함) · 옛 "메뉴 건너뛰기" 저장값(skipMenu)은 읽지 않는다(필드는 남김).
--   건너뛰기 = 검증 · 촬영이 명시적으로 켜는 테스트 플래그만: Edit에서 ReplicatedStorage Attribute TestSkipMainMenuUntil = os.time() + 초(만료 시각 - 켜 둔 채 잊어도 풀린다).
--   Studio라는 이유 · 검증 무장(VerifyArmedUntil)만으로는 건너뛰지 않는다. 옛 Attribute DevSkipMainMenu(참/거짓)는 남아 있으면 메뉴가 계속 안 떠서 더는 읽지 않는다.
local MenuGate = {}

MenuGate.flagName = "TestSkipMainMenuUntil"

-- 순수: { isStudio, now, flagUntil } → 메뉴를 건너뛰는가
function MenuGate.shouldSkip(env)
	if not env.isStudio then
		return false
	end
	return type(env.flagUntil) == "number" and env.flagUntil > (env.now or 0)
end

return MenuGate
