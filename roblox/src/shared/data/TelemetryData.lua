-- QUEUE-10h Q15 T1 통계(AnalyticsService - 서버만 · 퍼블리시된 서버에서만 전송 · Studio = 드라이런 로그). 모듈 = server/Telemetry.lua.
--   개인 식별 정보 없음(이름 · 채팅 · 아이디를 필드에 넣지 않는다 - AnalyticsService가 사용자 단위 집계를 한다). 값은 구간으로만.
--   누적: 경제 = [플레이어][화폐 · 흐름 · 거래 종류]의 합 · 커스텀 = 마지막 값 → flushSeconds마다 · 퇴장 때 한 번에 보낸다(이벤트 수 제한 대비).
--   상품 · 구매 이벤트(IAP · 상품 SKU)는 P4c 뒤 - 지금 자리만(categories.purchase = 꺼짐).
return {
	enabled = true,
	flushSeconds = 300,
	dryRunInStudio = true, -- Studio = 보내지 않고 [T1] 로그만
	-- 분류별 켜기/끄기 · 표본 비율(0 ~ 1 - userId 해시로 사람 단위 고정 표본)
	categories = {
		economy = { enabled = true, sample = 1 },
		custom = { enabled = true, sample = 1 },
		funnel = { enabled = true, sample = 1 },
		purchase = { enabled = false, sample = 1 }, -- 자리(P4c)
	},
	-- 화폐(≤ 5 - AnalyticsService 권장): 흐름 = 획득(Source) · 사용(Sink)
	currencies = { gold = "Gold", enhanceStone = "EnhanceStone", gemDust = "GemDust", sparkleShard = "SparkleShard" },
	-- 커스텀 필드 3(구간값 문자열): 1 = 스테이지 구간 · 2 = 직업 · 3 = 환생 구간
	stageBuckets = { 1, 50, 200, 1000, 5000, 20000 }, -- 이 값 이상 = 그 구간(마지막은 이상)
	rebirthBuckets = { 0, 1, 3, 5 },
	-- 온보딩 퍼널 단계 이름 순서(QuestData.ftue의 funnel과 같은 이름 - 번호 = 순서)
	funnelOrder = { "ftue_fight", "ftue_drop", "ftue_equip", "ftue_skill", "ftue_enhance", "ftue_gem", "ftue_ult", "ftue_boss" },
}
