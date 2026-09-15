-- 무한 모드 보스 데이터(15-1). PRD-forge-game-roblox.md 20.8-6이 정한 "구간별 보스 풀 +
-- 풀 안에서 랜덤" 구조를 그대로 옮긴다 - 지금은 종류를 하나만 만들지만(지시 [2], 여러 종
-- 제작은 다음 단계), pools 구조 자체는 나중에 항목을 추가하기만 하면 되도록 미리 잡아둔다.
--
-- stageInterval=5: 이 프로젝트엔 "몇 스테이지마다 보스"를 정한 기존 값이 없다(웹 v1의
-- 6단계 보스는 무한 스테이지가 아니라 유한 6판짜리 별도 콘텐츠라 참고가 안 된다,
-- PRD-forge-game-roblox.md 20.9 "웹 v1과의 차이" 참고). 로블록스 무한 모드는 지금 몬스터가
-- tier1 하나뿐이고 스테이지당 성장률 k=1.155(InfiniteStageConfig)만 있어 "긴 구간을 나눠
-- 보스로 매듭짓는다"는 의도 자체가 아직 실측 근거가 없다 - 그래서 이번 판단은 두 조건으로
-- 정했다: (1) 로블록스 타워/시뮬레이터 장르의 "10층마다 보스"보다 촘촘해야 지금 같은
-- 초기 빌드(레벨업・장비 축이 막 생긴 시점)에서 첫 보스를 금방 만나 검증할 수 있다,
-- (2) 5단계 간격이면 stage 5(첫 보스)의 잡몹 공격력이 8×1.155^4≈14.2로 아직 맨몸 캐릭터가
-- 버틸 수 있는 크기다(반면 10단계 간격이면 stage10 잡몹 공격력이 이미 8×1.155^9≈29.2로
-- 방어구 없는 캐릭터를 잡몹 평타만으로 즉사시켜 보스 자체를 검증할 수 없다 - 15-1 세션
-- 계산). 결론: stageInterval=5.
--
-- hpMultiplier=20은 새로 만든 값이 아니라 PRD-forge-game-roblox.md 20.9가 이미 확정해 둔
-- "일반 몬스터 체력 = 보스 체력 ÷ 20"을 그대로 뒤집어 재사용한 것이다(보스가 잡몹 20마리
-- 분량의 체력). attackMultiplier=1(평타는 잡몹과 동일)은 이번 세션에서 새로 정한 값 -
-- "보스가 위험한 이유"를 평타 크기가 아니라 heavyAttackMultiplier(주기적 예고 공격)
-- 하나에 몰아서, 평소엔 잡몹과 다르지 않다가 그 순간만 위험해지는 대비를 분명히 하려는
-- 의도다(지시 [3] "가장 싸게 긴장을 만드는 것 하나만").
return {
	stageInterval = 5,

	pools = {
		{ minStage = 1, bossIds = { "section_guardian" } },
	},

	bosses = {
		section_guardian = {
			id = "section_guardian",
			displayName = "구간 수호자",

			-- 잡몹(MonsterData.tier1) 대비 배율. 실제 수치는 그 스테이지의 잡몹 값에
			-- 곱해서 매번 계산한다(BossRules.buildInstanceData) - 여기 절대값을 박지 않는다
			-- (data/ 폴더 규칙, 스테이지가 바뀌어도 이 표를 고칠 필요가 없어야 한다).
			hpMultiplier = 20,
			attackMultiplier = 1,
			goldMultiplier = 20,
			expMultiplier = 20,

			-- 예고 후 강한 일격(지시 [3]에서 고른 유일한 긴장 장치). 평타의 3배 - 15-1
			-- 세션 계산(stage5 기준 감소율 42.9%, 데미지 24.4 vs playerMaxHp=10)으로 확인한
			-- 즉사급 수치다. 즉사이므로 반드시 예고가 있어야 한다는 지시 조건을 그대로
			-- 따른다 - telegraphWarmupSeconds 동안 보스가 멈춰 서서 색이 바뀌고, 그 사이
			-- 플레이어 이동속도(16stud/s)면 attackRangeStuds 밖으로 벗어나기 충분하다
			-- (로블록스엔 아직 웹의 대시·무적시간이 없어 이동만으로 피해야 한다).
			heavyAttackMultiplier = 3,
			heavyAttackIntervalSeconds = 6,
			telegraphWarmupSeconds = 1.5,
			telegraphColor = Color3.fromRGB(200, 30, 30),

			-- 크기·속도 - 아트 다듬기는 동결 상태라 기본 파트 크기만 키운다(지시 "하지 말
			-- 것"). sizeScale은 MonsterSpawner.buildModel의 파트 크기에 곱한다.
			sizeScale = 3,
			bodyColor = Color3.fromRGB(60, 20, 70),
			headColor = Color3.fromRGB(90, 30, 100),
			moveSpeedStuds = 8, -- 잡몹(10)보다 느리다 - 덩치가 큰 느낌 + 회피 난이도를 낮춘다.
			attackRangeStuds = 14, -- 커진 몸집만큼 사거리도 조금 더 길다.
			attackCooldownSeconds = 1.0,
			-- 21-3: 추격 정지 거리. 보스 몸통 충돌을 껐으므로(MonsterSpawner - 진동파 호핑·돌진이
			-- 캐릭터를 밀어내는 사고 방지) 이 값이 없으면 보스가 플레이어 좌표까지 파고들어 겹친다 -
			-- 겹치면 진동파가 발밑(반경 0)에서 시작해 점프 창이 파동 통과 시간(0.17초)뿐이 된다.
			-- 몸통 반폭 3.6 + 캐릭터 반폭 1 + 여유 = 8, 사거리 14 안이라 평타엔 영향이 없다.
			chaseStopDistanceStuds = 8,

			-- ═══ 패턴(21-3, PRD-forge-game-roblox.md 20.44 [3](나) 설계 → 20.46 구현) ═══
			-- 모든 시간은 초, 거리는 stud(아레나 좌표계 = WorldConfig와 같은 stud). 회피 전제는
			-- "걷기 16stud/s + 점프(높이 7.2, 체공 0.54초)"뿐이다 - 대시(21-2)는 보너스지 필수가
			-- 아니다(지시). 예고 시간 하한 = 시각 반응 0.25 + 터치 입력 지연 0.1 + 서버→클라
			-- 표시 지연 0.15 + 회피 동작 시간 + 여유 - 각 패턴 주석에 그 계산을 적어 둔다.
			--
			-- 스케줄링(BossPatterns.lua): 패턴은 한 번에 하나만 돈다(같은 상태 머신의 phase
			-- 하나). 각 패턴은 자기 intervalSeconds 시계(직전 종료 시각 기준)를 갖고, 보스가
			-- 평상 상태이고 직전 패턴 종료 후 patternMinGapSeconds가 지났을 때 가장 오래 기다린
			-- 패턴부터 시작한다. 강공격(위 heavyAttack* 필드 - 15-1 현행 6초/1.5초/×3 그대로,
			-- 21-3에서 확인만 했다)도 이 스케줄러를 같이 탄다 - 주기 6초는 "직전 강공격 종료
			-- 기준"이라 다른 패턴이 끼면 그만큼 밀린다(겹침 방지가 주기 정확도보다 우선).
			-- HP 구간별 빈도 변화는 PRD에 없어 고정이다(21-3 기록).
			--
			-- 패턴 간 최소 간격(패턴의 "보스 구속 종료" - 파동이 대상을 지나간 시점·돌진 후
			-- 헤롱 종료 등 - 기준). 평소 6초: 패턴 사이에 평타 추격 구간이 확실히 있어 "패턴을
			-- 연속으로 여러 개 쓰는" 일이 없다(사용자 지시 - 연속 사용은 체력 20% 이하에서만).
			-- 격노(HP ≤ enragedHpFraction) 2.5초 = 착지 0.54(진동파 회피 직후) + 반응 0.5 +
			-- 옆걸음 0.4 + 여유 1.0 - 연속으로 와도 "진동파 회피 직후 돌진을 착지 경직으로 못
			-- 피한다"(지시 [5])는 일은 없는 하한.
			patternMinGapSeconds = 6,
			enragedHpFraction = 0.2,
			enragedPatternMinGapSeconds = 2.5,
			-- 입장·재도전 유예(20.44 [3](다) 채택) - 텔레포트 직후 예고 없이 맞지 않게 한다.
			entryGraceSeconds = 2,

			patterns = {
				-- 패턴 1 진동파(20.44 [3](나) #1). 보스가 hopHeightStuds만큼 떠올랐다 찍는 동작
				-- 자체가 예고(telegraphSeconds 1.2)이고, 찍는 순간 파동이 waveSpeedStuds로
				-- 퍼진다. 피해 = 잡몹 평타 ×2(7타 앵커 기준 최대체력의 28.6%). 판정은 서버가
				-- "파동 두께가 플레이어를 지나는 동안 한 순간이라도 공중이었는가"로 한다 - 점프
				-- 입력 창 = 체공 0.54 + 통과 4/24=0.17 = 0.71초(서버가 보는 실측 체공은 0.6~0.7).
				-- 24 > 걷기 16이라 뛰어서는 못 피한다(의도, 점프가 유일한 답). waveCount 3 =
				-- "줄넘기" - repeatIntervalSeconds 1.5 ≥ 체공 0.54 + 반응·입력 0.35 + 통과 0.17
				-- = 1.06 + 여유 0.44(첫 예고 1.2는 PRD값 - 첫 파동은 땅에 서서 시작하므로 체공
				-- 항이 없어 1.2 > 0.5 + 0.17로 충분하다).
				shockwave = {
					intervalSeconds = 11,
					telegraphSeconds = 1.2,
					waveCount = 3,
					repeatIntervalSeconds = 1.5,
					waveSpeedStuds = 24,
					waveThicknessStuds = 4,
					damageMultiplier = 2,
					hopHeightStuds = 4,
					-- 공중 판정 여유 - 지면 거리(레이캐스트)가 서 있을 때(HipHeight + 루트 반높이)보다
					-- 이만큼 더 크면 공중. 21-3 실측: 점프 중 이 문턱 위에 있는 시간 0.58초.
					airborneClearanceStuds = 0.5,
				},

				-- 패턴 3 정신집중→돌진(20.44 [3](나) #3). 느낌표가 뜨는 "순간" 플레이어 좌표를
				-- 고정하고(추적 안 함 - 회피가 실력이 되는 핵심), focusSeconds 뒤 그 좌표를 지나
				-- 벽까지 speedStuds로 직진한다. 피해 = 최대체력의 damageMaxHpFraction(방어 무관 -
				-- 직업 무관하게 회피를 강제). 회피 = 경로선에서 옆으로 6stud(0.375초, 채널링 50%
				-- 속도여도 0.75초) - 1.5 ≥ 0.5 + 0.375 + 여유 0.625. 경로 폭 반경 4 + 캐릭터
				-- 반폭 1 = 5 < 6. 벽·담장에 닿으면(arenaMarginStuds 안쪽) 멈춘다 - 아레나 밖으로
				-- 절대 안 나간다(도착점을 시작 시점에 AABB로 자른다). 멈춘 뒤 recoverSeconds 동안
				-- 헤롱거리며 주저앉는다(사용자 지시 - 5초 이내, 백어택 시간): 몸이 dazeSinkStuds
				-- 내려앉고 dazeTiltDeg 기울며 머리 위에 어지럼 말풍선이 뜬다. 이 4초는 돌진을 피한
				-- 사람에게만 주어지는 보상 딜타임이다(맞은 사람은 80%를 잃고 회복부터 해야 한다).
				charge = {
					intervalSeconds = 15,
					focusSeconds = 1.5,
					speedStuds = 60,
					pathHalfWidthStuds = 4,
					damageMaxHpFraction = 0.8,
					recoverSeconds = 4.0,
					dazeSinkStuds = 1.2,
					dazeTiltDeg = 25,
					arenaMarginStuds = 4, -- 보스 몸통 반폭(1.2×3=3.6)보다 조금 크게.
				},

				-- 패턴 4 낙석(21-3 추가). 표적 장판 count개(첫 장판은 플레이어 현재 위치, 나머지는
				-- 그 주변 scatterStuds 안 랜덤) telegraphSeconds 뒤 radiusStuds 안에 있으면 피해
				-- (잡몹 평타 ×2). 회피 = 걷기(반경 6 + 1 = 7stud, 0.44초 - 1.5 ≥ 0.5 + 0.44 +
				-- 여유 0.56). 돌진처럼 좌표 고정형이라 "계속 움직이는 사람은 안 맞는다".
				meteor = {
					intervalSeconds = 13,
					telegraphSeconds = 1.5,
					count = 3,
					radiusStuds = 6,
					scatterStuds = 10,
					damageMultiplier = 2,
				},

				-- 패턴 5 십자 화염(21-3 추가). 보스 중심에서 4방향(첫 볼리 각도는 플레이어 방향,
				-- 90도 간격) 벽까지 뻗는 직선 halfWidthStuds 폭 - telegraphSeconds 예고 뒤 선
				-- 위면 피해(잡몹 평타 ×2). 두 번째 볼리는 rotateDeg 돌려서 한 번 더 - 첫 볼리를
				-- 피해 대각선에 섰으면 두 번째는 다시 옆으로 걸어야 한다. 회피 = 옆으로 4stud
				-- (0.25초). 선은 아레나 AABB로 잘라 담장 밖으로 안 나간다.
				cross = {
					intervalSeconds = 17,
					telegraphSeconds = 1.5,
					volleys = 2,
					rotateDeg = 45,
					halfWidthStuds = 3,
					damageMultiplier = 2,
				},
			},
		},
	},
}
