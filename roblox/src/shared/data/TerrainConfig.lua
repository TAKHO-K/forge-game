-- Y축 지형 규칙의 단일 출처(22-4). 20.49가 "평탄 전제"로 세운 도달원 규칙을 "완만한 경사는
-- 허용, 급경사·수직은 여전히 밖"으로 재정의하면서 필요해진 상수 전부가 여기 있다. 몬스터
-- 지면 추적(MonsterAI.server.lua) · 판정 높이차(Reach.lua) · 드랍 스냅(ItemDropSpawner) ·
-- 대시 지면 추종(DashEndpoint) · 플레이어 등반 한계(TerrainServer) · 심연 복귀가 같은 값을
-- 읽는다. 어느 하나도 이 파일 밖에 같은 숫자를 다시 적지 않는다.
--
-- 기존 관계식 검사(PRD 20.42 - 새 상수는 "어떤 기존 관계식을 넘는가"를 먼저 본다):
--   격자 64 / 어그로 25.6 / 리쉬 38.4 사슬(20-4에서 절대값 고정)은 전부 XZ 수평 거리로 계산을
--   유지한다 - 아래 높이 상한은 그 위에 얹는 "필터"일 뿐, 거리 값 자체를 바꾸지 않는다.
--   3D 거리로 바꿨다면 경사에서 사거리·리쉬가 실질 축소돼 사슬이 깨졌을 것이다.

local MAX_SLOPE_DEGREES = 45
-- 2stud 앞을 찔러 보는 이유: 잡몹 몸통 두께(1.2×배율)와 이동속도 10stud/s × 갱신 0.1초 = 1stud의
-- 두 배다 - 갱신 사이에 지형 특징(계단 한 단 폭 ≥ 2)을 건너뛰지 않는다.
local PROBE_AHEAD_STUDS = 2

return {
	-- ═══ 경사 한계 ═══
	-- 45°: (1) tan45=1이라 "2stud 앞이 2stud 오르면 한계"로 계단 한 단 높이(아래 maxStepHeight)와
	-- 하나의 관계식으로 묶인다. (2) 로블록스 Humanoid 기본 MaxSlopeAngle은 89°로 거의 수직도
	-- 오른다 - 플레이어도 이 값으로 잠가(TerrainServer.server.lua) "나는 오르는데 몬스터는 못
	-- 오는" 지형을 없앤다. (3) 45° 언덕에서 높이차 상한 8까지 오르는 수평 거리가 8이라 평타
	-- 사거리 10 안이다 - 언덕 비탈에서 싸워도 판정이 끊기지 않는다.
	maxSlopeDegrees = MAX_SLOPE_DEGREES,
	maxSlopeTangent = math.tan(math.rad(MAX_SLOPE_DEGREES)),

	-- ═══ 몬스터 지면 추적 ═══
	probeAheadStuds = PROBE_AHEAD_STUDS,
	-- 계단 한 단 = 앞 2stud에서 허용되는 최대 상승 = probeAhead × tan(경사한계) = 2. 이보다 큰
	-- 단차는 절벽으로 본다(오르내림 양방향 - 내려가기만 허용하면 추격 후 못 돌아온다).
	-- R15 Humanoid가 자동으로 밟고 오르는 단 높이(HipHeight≈2)와도 같다.
	maxStepHeightStuds = PROBE_AHEAD_STUDS * math.tan(math.rad(MAX_SLOPE_DEGREES)),
	-- 지면 Raycast 갱신 주기. 이동 중인 몬스터만 쏜다(idle은 0회) - 10stud/s면 갱신 사이 1stud.
	probeIntervalSeconds = 0.1,
	-- Raycast 창: 발 위치 기준 위·아래 각 4(=계단 한 단의 2배). 이 창 밖은 "지면 없음"과
	-- 같은 결과(막힘)라 심연과 절벽을 구분할 필요가 없다.
	probeUpStuds = 4,
	probeDownStuds = 4,
	-- 몬스터 루트 중심은 발(지면)에서 이 높이 - HuntingGround/BossEncounter가 스폰 Y에 쓰던
	-- 관례값(바닥 윗면 + 1.5)을 그대로 상수로 올렸다.
	monsterFootOffsetStuds = 1.5,
	-- 복귀(returning) 중 막힌 채 이 시간이 지나면 집으로 순간이동한다 - 나갈 때 비켜 간 경로가
	-- 돌아올 때 직선상에 없으면 영원히 절벽 밑에 서 있게 되는 것을 막는다.
	returningStuckTeleportSeconds = 3,

	-- ═══ 판정 높이차 상한(어그로·리쉬 대상·평타·스킬·보스 패턴 공통) ═══
	-- 8 = 플레이어 점프 높이(JumpHeight 7.2) + 여유. "점프로 닿는 높이는 같은 층"이라는 기준 -
	-- 이보다 높은 절벽 위아래로는 서로 못 때리고 어그로도 안 붙는다.
	heightToleranceStuds = 8,
	-- 줍기는 더 좁다: 루트 중심이 지면에서 약 4(HipHeight 2 + 루트 반높이 1 + 바닥) - "발밑에
	-- 있는 것만" 줍는다. 언덕 아래 아이템을 위에서 줍지 못한다(내려가야 한다).
	pickupHeightToleranceStuds = 4,

	-- ═══ 플레이어 ═══
	-- 심연 복귀선. 드래곤 돌길 심연 바닥(20.49, y=-6)보다 깊고, 엔진 FallenPartsDestroyHeight
	-- (-500, 도달하면 캐릭터 사망)보다 훨씬 위 - 죽음 대신 복귀로 처리하려면 그 사이여야 한다.
	voidReturnY = -24,
	voidCheckIntervalSeconds = 0.25,
	-- 대시 지면 추종 표본 간격(DashEndpoint) - 16stud 대시에 4회 Raycast.
	dashGroundSampleStuds = 4,
}
