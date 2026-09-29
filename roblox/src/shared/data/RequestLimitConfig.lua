-- 공통 요청 제한(QUEUE-6h-b 후속 - security-audit-alpha F6 · F7). 서버 입구 = server/RequestGate.lua.
-- 자체 제한이 없던 클라 → 서버 Remote 22개(+ 이미 0.3초 제한이 있던 SkillInfoRequest)가 이 표 하나로 사람 × Remote마다 제한된다
-- (초과 요청은 조용히 버림 · RemoteFunction은 넘친 요청에만 그 인자의 마지막 결과를 돌려준다 - 정상 요청은 항상 새로 계산해 옛 가방 · 요약이 가지 않는다).
-- 방식 = 토큰 통: burst개까지 한꺼번에, 그 뒤로는 초당 perSecond개. 정상 조작(장비 연속 판매 · 잠금 연타 · 창 끌기)은 닿지 않는 값이다.
return {
	default = { perSecond = 10, burst = 10 },
	remotes = {
		-- 직업 전환 = 버프 · 화살 · 분신 정리 + 스탯 재계산(가장 무겁다 - 감사 F6 권고 "1초")
		ClassSelectRequest = { perSecond = 1, burst = 2 },
		-- 창을 끄는 동안 위치를 연달아 보낼 수 있다(저장은 즉시 저장 스로틀이 따로 막는다)
		SetInventoryWindowPosition = { perSecond = 20, burst = 20 },
	},
	-- RemoteFunction 기본(감사 F7 권고는 0.2초 캐시였지만 상태를 읽는 함수(가방 · 보석 · 요약)는 변경 직후 다시 읽으면 옛 값이 가서 통만 쓴다)
	functionDefault = { perSecond = 10, burst = 20 },
}
