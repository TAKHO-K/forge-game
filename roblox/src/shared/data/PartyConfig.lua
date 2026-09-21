-- 파티 구조 상수(24-1, PRD 20.47 [5] / 24-2 크로스서버 PRD 20.63). 밸런스 수치가 아니라 구조값이다 -
-- 보스 HP 배수의 지수 p는 여기 박지 않고 BossRules.partyHpExponent가 이 maxMembers·BossData.stageInterval·
-- InfiniteStageConfig.growthRate에서 매번 유도한다(새 밸런스 상수를 만들지 않는다는 지시).
local maxMembers = 4
-- 힐러 파티 버프 b 재도출(24-4, PRD 20.64) - 24-3의 b=1/(maxMembers-1)=1/3은 "힐러의
-- DPS가 0"이라는 잘못된 전제에서 나온 값이었다(딜러 3명을 4명분으로 끌어올리는 계산 -
-- 힐러 자신의 딜을 아예 안 쳤다). 실제로는 힐러도 딜링모드(E)로 딜을 하므로 b가 크게
-- 과대했다(24-3 값대로면 힐러 4인 파티가 딜러 4인 파티보다 빨라진다 - 아래 r로 보면
-- 4×0.9491×(1+1/3)=5.06 > 4, 상한 위반).
--
-- r = 힐러 1인 DPS ÷ 딜러(대검) 1인 DPS. 대검을 기준(1.0)으로 잡은 이유: PRD 20.36 [4]가
-- "힐러 = 최저 직업 동률"을 의도했고, 20.44 [1]-D 재측정 표에서도 대검이 4직업 중 가장
-- 낮은 로테이션 총딜이라 이미 이 프로젝트의 기존 DPS 비교 기준("대검 대비" 열)이었다.
-- /gg anchor <직업> 실측(레벨100/스테이지100/등급0 앵커, Studio, 24-4):
--   대검 로테이션 60초 총딜 = 598.6(atk-단위), 힐러(딜링모드 100% 가동) = 948.5.
--   raw 비율 948.5/598.6 = 1.5845.
-- 이 raw 비율은 "힐링모드가 한 번도 안 꺼진다"는 가정이다 - 실제로는 딜링모드 소모(E)가
-- 회피 못한 피격과 함께 체력을 깎아 힐러가 주기적으로 이탈·회복해야 한다(그사이 딜이
-- 0이 된다 - "힐 쿨마다 딜 사이클이 끊기는 손실"). 이 손실은 새로 재는 게 아니라 이미
-- 있는 값을 쓴다 - SkillData.healer.E.drainPercentPerSecond(0.012)가 21-2에서
-- BalanceSim.solveHealerDrain(0.6, …)으로 역산돼 실효 가동률 0.599로 확정된 그 값이다
-- (PRD 20.44 [1]-D). 힐러 hitRatio 실측(0.1026)이 그 튜닝 때와 정확히 일치해 그대로
-- 재사용해도 앵커가 어긋나지 않는다.
--   r = 1.5845 × 0.599 = 0.9491.
-- 상수로 안 박고 데이터로 남긴다(지시) - healerDpsRatio가 그 값이고, b는 아래 식이
-- maxMembers·healerDpsRatio에서 매번 계산한다(숫자 하드코딩 아님).
local healerDpsRatio = 0.9491
-- b의 허용 구간(N=maxMembers, r=healerDpsRatio):
--   하한 (N-1+r)(1+b) ≥ N  -  힐러를 한 명 넣은 정원 파티가 딜러 정원 파티보다 느리면 안 된다
--   상한 N·r·(1+b) ≤ N, 즉 b ≤ 1/r - 1  -  전원 힐러가 딜러 정원 파티를 넘으면 안 된다
-- r=0.9491로 [0.0129, 0.0536] - 구간이 좁지만 비지 않는다. 중간값이 아니라 "하한"을
-- 골랐다 - 이유는 딜러3+힐러1의 총 DPS를 딜러4인과 정확히 같게 만드는 지점이 수학적으로
-- 이 하한이기 때문이다(하한 부등식 자체가 그 등식의 "≥"판이다). 중간값을 쓰면 딜러
-- 3+힐러1의 DPS가 딜러4인보다 커져(위 검산표 참고) "힐러 수가 늘수록 처치 시간이
-- 길어져야 한다"는 검산 조건의 첫 행(0→1)에서 뒤집힌다 - 하한에서는 그 두 행이 정확히
-- 동률이라 뒤집히지 않는다. 부수 효과: 이 지점에서 딜러3+힐러1의 총 DPS가 4(대검 1인
-- 대비)와 정확히 같아, p(BossRules.partyHpExponent, "정원 파티 DPS=maxMembers배" 전제)의
-- 전제도 근사가 아니라 등식으로 유지된다.
local healerBuffFraction = maxMembers / (maxMembers - 1 + healerDpsRatio) - 1
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

	-- 24-3: 힐러의 힐을 받은 파티원의 최종 피해 배율 계수. 위 healerBuffFraction 주석 참고.
	healerBuffFraction = healerBuffFraction,
	-- 24-4: b 계산에 쓴 실측 r(힐러 1인 DPS ÷ 대검 1인 DPS, 딜링모드 가동률 포함). 위 주석 참고.
	healerDpsRatio = healerDpsRatio,

	-- 30-0 S09(PRD 20.73 [5-1]): 같은 서버의 파티 인원(실제 Player만 - 더미 · 텔레포트 중인 원격 좌석 제외)별 경험치 보너스. 없는 인원(솔로)은 0.
	-- 성장 옵션(상한 25%)과는 곱이다: 배수 = (1 + 옵션 합) × (1 + 이 값).
	expBonusByMemberCount = { [2] = 0.10, [3] = 0.15, [4] = 0.20 },

	-- 초대 팝업 유지 시간(PRD 20.47 [5](라) "받는 쪽 팝업 15초"). 지나면 자동 거절.
	inviteTimeoutSeconds = 15,

	-- S19b B: 연결이 끊긴 파티원의 자리를 비워 두는 시간(초). 이 안에 다시 접속하면 원래 파티로 복귀하고, 지나면 자동 탈퇴한다. 파티장은 그동안에도 추방할 수 있다.
	-- 0이면 유예 없이 끊기는 즉시 탈퇴(옛 동작). 접속 중인 다른 실제 멤버가 없으면(혼자 남거나 전원이 끊기면) 유예 없이 바로 탈퇴한다.
	disconnectGraceSeconds = 180,
	-- S19b B: 다른 서버로 재접속한 끊긴 멤버에게 복귀 초대(파티 서버로 이동)를 띄워 두는 시간(초). 유예 안에서만 뜬다.
	reconnectOfferSeconds = 60,

	-- 25-3: 리더가 보스 스테이지로 이동할 때 뜨는 투표 제한 시간(PRD 20.47 [6](라)의 원래
	-- 제안 "입장 수락 팝업 10초"를 그대로 가져온다). 시간 안에 아무도 동의하지 않으면 무산.
	stageVoteTimeoutSeconds = 10,

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
