-- 파티 구조 상수(24-1, PRD 20.47 [5] / 24-2 크로스서버 PRD 20.63). 밸런스 수치가 아니라 구조값이다 -
-- 보스 HP 배수의 지수 p는 여기 박지 않고 BossRules.partyHpExponent가 이 maxMembers·BossData.stageInterval·
-- InfiniteStageConfig.growthRate에서 매번 유도한다(새 밸런스 상수를 만들지 않는다는 지시).
local maxMembers = 4
-- 서버 정원 12 = 4인 × 3파티(PRD 20.38 [6]·20.47 [5](가)). 24-2부터 "12"를 코드에 직접 적지 않고
-- 이 두 값의 곱으로 유도한다 - 매치메이킹이 채우는 기준 인원(Players.PreferredPlayers에 해당).
local partiesPerServer = 3
-- 크로스서버 합류자가 매치메이킹 정원 위에 얹힐 수 있는 초과 여유 = 파티 한 팀 분량(24-2 [3]).
-- 서버 상한(Players.MaxPlayers로 대시보드에 설정해야 하는 값) = 12 + 4 = 16. 성능 근거는 PRD 20.63 [3].
local crossServerExtraSlots = maxMembers
-- 크로스서버 상태 레코드(MemoryStore)의 리더 서버 하트비트 간격. TTL은 하트비트 3회 - 리더 서버가
-- 죽어도(BindToClose를 못 탄 크래시) 3회 안에 레코드가 사라져 대기 중인 합류자가 풀린다.
local heartbeatSeconds = 30

return {
	-- 5인 이상은 보스 패턴 구속 시간(돌진 ⌈N/2⌉회)이 패턴 최소 간격 규칙을 깨는 상한이다.
	maxMembers = maxMembers,

	-- 초대 팝업 유지 시간(PRD 20.47 [5](라) "받는 쪽 팝업 15초"). 지나면 자동 거절.
	inviteTimeoutSeconds = 15,

	-- ═══ 24-2 크로스서버(PRD 20.63) ═══
	partiesPerServer = partiesPerServer,
	serverPreferredPlayers = maxMembers * partiesPerServer, -- 12
	serverCapacity = maxMembers * partiesPerServer + crossServerExtraSlots, -- 16

	-- 파티 코드 - 헷갈리는 글자(0/O, 1/I/L)를 뺀 알파벳 30자, 6자리 = 7.29×10⁸ 조합. 코드는 파티가
	-- 살아 있는 동안만 MemoryStore에 존재하므로 충돌 확률은 동시 파티 수/7억 - 무시 가능.
	codeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ2345678",
	codeLength = 6,

	heartbeatSeconds = heartbeatSeconds,
	recordTtlSeconds = heartbeatSeconds * 3, -- 90
	-- 원격 합류자의 좌석 예약 유지 시간 - 텔레포트 + 도착 서버 로딩(폰 최악 ≈ 60초)을 덮는 길이.
	-- 이 안에 도착하지 않으면 리더 서버가 좌석을 회수한다(레코드 TTL과 같은 값 - 값이 둘이면 어느
	-- 쪽이 먼저 만료되는지 매번 따져야 한다).
	seatTimeoutSeconds = heartbeatSeconds * 3, -- 90
	-- 합류 대기(보스전 중·서버 정원 초과) 중 레코드를 다시 읽는 간격. MemoryStore 요청 예산
	-- (분당 1000 + 120×동접)에서 대기자 4명 × 12회/분 = 48회 - 예산의 5% 미만.
	joinPollSeconds = 5,

	-- MemoryStore 해시맵·MessagingService 토픽 이름. 버전을 이름에 박아 스키마가 바뀌면 옛 레코드와
	-- 섞이지 않게 한다(SaveConfig.dataStoreName과 같은 관례).
	partyMapName = "ForgeParty_v1",
	memberMapName = "ForgePartyMember_v1",
	messagingTopic = "ForgeParty_v1",
}
