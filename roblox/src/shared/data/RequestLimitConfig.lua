-- 공통 요청 제한(QUEUE-6h-b 후속 - security-audit-alpha F6 · F7). 서버 입구 = server/RequestGate.lua.
-- 자체 제한이 없던 클라 → 서버 Remote 22개(+ 이미 0.3초 제한이 있던 SkillInfoRequest)가 이 표 하나로 사람 × Remote마다 제한된다
-- (초과 요청은 조용히 버림 · RemoteFunction은 넘친 요청에만 그 인자의 마지막 결과를 돌려준다 - 정상 요청은 항상 새로 계산해 옛 가방 · 요약이 가지 않는다).
-- 방식 = 토큰 통: burst개까지 한꺼번에, 그 뒤로는 초당 perSecond개. 정상 조작(장비 연속 판매 · 잠금 연타 · 창 끌기)은 닿지 않는 값이다.
return {
	default = { perSecond = 10, burst = 10 },
	remotes = {
		-- 직업 전환 = 버프 · 화살 · 분신 정리 + 스탯 재계산(가장 무겁다 - 감사 F6 권고 "1초")
		ClassSelectRequest = { perSecond = 1, burst = 2 },
		OwnClothesToggle = { perSecond = 3, burst = 4 }, -- QUEUE-ALL9E1 LOOK2 장비창 "내 아바타 옷 보이기"(캐릭터 옷 다시 입힘 - 연타 막기)
		TranscendRequest = { perSecond = 4, burst = 8 }, -- QUEUE-ALL10 초월 계승 · 강화 칸 · 수련 · 보석(RemoteFunction)
		-- 창을 끄는 동안 위치를 연달아 보낼 수 있다(저장은 즉시 저장 스로틀이 따로 막는다)
		SetInventoryWindowPosition = { perSecond = 20, burst = 20 },
		-- QUEUE-B1 B2 상점 창구(구매 프롬프트 · 장착 · 받기) - 사람 손 속도면 닿지 않는다
		ShopRequest = { perSecond = 4, burst = 8 },
		-- QUEUE-ALL6 H 하이파이브: 요청마다 상대 화면에 제안 팝업 → 2초에 1번(괴롭힘 방지 - 리뷰)
		EmoteRequest = { perSecond = 0.5, burst = 2 },
		-- QUEUE-ALL4 B(security-audit-launch): 주간 도전 입장 = 보스 아레나 · 보스 스폰(무겁다) - 실패 뒤 다시 누르기는 되게 통 2
		WeeklyChallengeStart = { perSecond = 0.5, burst = 2 },
		-- 주간 순위 = 서버 공용 캐시(WeeklyChallengeData.topCacheSeconds)가 DataStore 읽기를 막고, 이 통은 한 사람의 연타만 막는다(넘치면 마지막 결과)
		WeeklyChallengeTop = { perSecond = 1, burst = 3 },
		-- 견습 바로 가기 = 순간이동 + 도착지 미리 불러오기(RequestStreamAroundAsync) - TravelRequest 전체(기본 통) 안의 동작별 키
		TravelTutorialZone = { perSecond = 0.2, burst = 2 },
		-- 구경 가기(서버 이동) = 1인 20초에 1번(옛 SpectateService COOLDOWN 20을 데이터로)
		SpectateRequest = { perSecond = 0.05, burst = 1 },
		EnhanceRequest = { perSecond = 4, burst = 6 }, -- QUEUE-ALL9B 6(서비스 쿨다운 0.5초 = 초당 2 · 화면 연타 여유)
		QuestRequest = { perSecond = 8, burst = 12 }, -- QUEUE-ALL9B 6(창 열기 view + 받기 연속 · 동작별 0.2초 제한은 그대로)
	},
	-- RemoteFunction 기본(감사 F7 권고는 0.2초 캐시였지만 상태를 읽는 함수(가방 · 보석 · 요약)는 변경 직후 다시 읽으면 옛 값이 가서 통만 쓴다)
	functionDefault = { perSecond = 10, burst = 20 },
}
