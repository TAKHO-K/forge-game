-- 이동 수치(G2a - 맵 그레이박스 M1의 기준). 근거 · 파생 표 = docs/design/movement-metrics.md.
-- 1단 점프 · 걷기 · 중력은 place 설정(StarterPlayer.CharacterJumpHeight 7.2 · CharacterWalkSpeed 16 · Workspace.Gravity 196.2)과 같은 값을 적어 둔다 -
-- 코드는 place 값을 바꾸지 않고, 계산(2단 속도 · 체공 · 서버 높이 허용치)만 이 값을 읽는다. place 값을 바꾸면 여기도 같이 바꾼다.
return {
	gravity = 196.2,
	jumpHeightStuds = 7.2, -- 1단 발 최고 높이(이륙 지면 기준). TerrainConfig.heightToleranceStuds 8(같은 층) · 아레나 벽 14의 전제
	walkSpeedStuds = 16, -- WorldConfig.playerWalkSpeedStuds · PlayerProfile BASE_WALK_SPEED_STUDS와 같은 값
	rootAboveFeetStuds = 3, -- 발 = 루트 − 3(HipHeight 2 + 루트 반높이 1)

	-- 공중 점프(M1-0 - 사용자 결정: 겐지 · 한조식 스택형, 필드 · 보스 아레나 같은 규칙): 공중에서 점프 버튼을 누를 때마다 충전 1을 쓰고 지금 높이에서 1단 × heightFraction만큼 더 오른다.
	-- 충전은 바닥을 밟으면 charges로 돌아온다. 공중대시는 한 체공에 1회이고 공중 점프와 어느 순서로든 섞는다(G2a의 상한형 · 대시 택일 · 아레나 전용 제한은 폐기).
	-- 최대 발 높이 = 1단 × (1 + charges × heightFraction) = 7.2 × 2.7 = 19.44(정점마다 누를 때). 0.85 = 80 ~ 90% 중 가운데(표 = docs/design/movement-metrics.md v2).
	-- MV1: charges = 해금 최대(환생 3회). 사람마다 쓰는 수 = MovementUnlockData(환생 0 = 0 · 1 ~ 2 = 1 · 3+ = 2) - 서버 높이 검증 허용치는 이 최대로 잰다(느슨한 쪽 - S1에서 사람별로 좁힌다).
	-- newPressGapSeconds: 누른 채로 있으면 JumpRequest가 반복된다 - 직전 요청과 이만큼 떨어진 요청만 새 누름. minAirSeconds: 이륙 직후의 같은 누름을 공중 점프로 읽지 않게.
	-- dashPendingSeconds: 공중대시를 요청한 뒤 결과(서버 왕복)가 올 때까지 공중 점프를 막는 여유(결과가 오면 트윈 끝 시각으로 덮는다 - 트윈이 끝나며 속도 0이라 그 사이 점프는 충전만 날아간다).
	airJump = { charges = 2, heightFraction = 0.85, newPressGapSeconds = 0.1, minAirSeconds = 0.05, dashPendingSeconds = 0.5 },

	-- MV1 활강(사용자 - 젤다 고공비행 느낌 · 환생 2회 해금): 공중에서 대시를 길게 누르면(DashConfig.input.glideHoldSeconds) 켜진다.
	--   forwardSpeed = 수평 전진(stud/s - 바라보는 방향 · 이동 속도 옵션과 무관: S1 속도 상한을 한 값으로 둔다) · descentSpeed = 하강(stud/s - 일정) · turnDegPerSecond = 이동 입력 쪽으로 도는 속도.
	--   gaugeSeconds = 게이지(환생 4회 + MovementUnlockData.glideSecondsBonus) · 착지하면 refillSeconds에 가득(서 있는 동안만 찬다) · 공중에서는 안 찬다.
	--   끝 = 대시 다시 누름 · 점프 · 게이지 소진(→ 자유 낙하) · 착지 · 물. 공중 점프 충전은 착지해야만 돌아온다(활강은 충전을 쓰지 않는다).
	--   아무리 빨리 떨어지고 있어도 켤 수 있다(켜는 순간 하강 = descentSpeed - 활강도 낙법이다).
	--   look: 글라이더 소품(나뭇잎 - 색 = 나무 점프맵 잎 발판 여름색 WorldMapData.hub.tree.seasons.summer.leafPad 재사용) · poseLeanDeg = 앞으로 눕는 각.
	--   gaugeUi: 캐릭터 옆 원형 게이지(점 dots개 고리 · 초록 → 노랑 → 빨강 경계 = 남은 비율 warnFraction · dangerFraction).
	glide = {
		forwardSpeed = 30, descentSpeed = 5, turnDegPerSecond = 150,
		gaugeSeconds = 8, refillSeconds = 2,
		look = { leafColor = Color3.fromRGB(118, 165, 94), stemColor = Color3.fromRGB(108, 62, 44), -- 줄기 = 나무 껍질 어두운 색(WorldMapData barkDark) 재사용
			leafSize = Vector3.new(7, 0.3, 3.6), aboveHeadStuds = 2.2, poseLeanDeg = 55 },
		gaugeUi = { dots = 16, sizePx = 46, dotPx = 7, sideStuds = 2.6, warnFraction = 0.5, dangerFraction = 0.25 },
	},

	-- MV1 태초 장갑 = 붙잡기(사용자 수정 - 딜 · 공격 횟수 · 공속 영향 0): 공중에서 벽 · 절벽 모서리에 닿으면 매달린다 → 점프 키로 올라선다. 한 체공 1회(착지하면 다시 찬다).
	--   잡는 조건(클라 - 매 프레임): 떨어지는 중이거나 느리게 오르는 중(세로 속도 ≤ maxRiseSpeed) · 앞 reachStuds 안에 벽 · 그 벽 윗면(모서리)이 발 위 minLedgeAboveFeet ~ 손 높이(maxLedgeAboveFeet) ·
	--     모서리 위 standClearStuds 높이가 비었다(올라설 자리). 매달림 = 루트 고정(모서리 − hangBelowStuds) · hangMaxSeconds 뒤 저절로 놓는다 · 점프 = 모서리 위 climbInStuds 안쪽으로 올라섬.
	--   서버(합법 동작 등록): 클라가 LedgeClimb(모서리 윗점 · 벽 방향)를 보내면 서버가 그 점 위에서 광선으로 모서리를 다시 확인하고(serverTolerance · 점이 서버가 본 루트에서 수평 pointSlackStuds 안) 태초 장갑 · 체공 1회를 확인한 뒤
	--     HeightGuard 허가(발 최고 = 모서리 + permitMarginStuds · permitSeconds)를 준다 - 허가 없이 오르면 옛 규칙대로 되돌린다. 올라서기 = 새 지면(기준이 모서리 위로 옮는다).
	--   대공 잡기의 공중 시간 규칙은 그대로다(매달림 = 공중 - 보스 BossAirGrab이 그대로 센다).
	ledgeGrab = {
		reachStuds = 2.6, maxRiseSpeed = 8, minLedgeAboveFeet = 2.5, maxLedgeAboveFeet = 7.5, standClearStuds = 5.5, hangBelowStuds = 4.2,
		hangMaxSeconds = 4, climbInStuds = 2.4, climbSeconds = 0.22,
		serverTolerance = 3, pointSlackStuds = 12, permitMarginStuds = 0, permitSeconds = 4.8, requestGapSeconds = 0.3, -- 허가 = 매달리는 순간 요청(오르기 전에 서버에 닿게) · 매달림 4 + 오르기 0.22 + 여유 · 높이 여유는 HeightGuard 허가 여유(permit.marginStuds)만(리뷰 2: 두 겹이었다)
	},

	-- MV1 낙하(사용자 결정 · 보완): 판정 = 착지 순간 수직 속도(공중 점프 · 활강으로 떨어지는 속도를 죽이면 산다 = "낙법") → 환산 높이 h = v² ÷ 2g(MoveRules.fallHeightOf).
	--   피해 = 최대 체력 × clamp((h − 안전 높이) ÷ (lethalHeight − 안전 높이), 0, 1) - 고정 %최대체력 · 방어 · 피해 감소 · 방어막 무시(판정형 피해).
	--   안전 높이 = 합법 점프 정점(점프력 옵션 상한 + 공중 점프 전부 = 21.38 - JumpMath.maxClimbStuds) + safeMarginStuds → 평소 점프 · 사다리는 피해 0.
	--   lethalHeight = 나무 세 번째 정거장 높이(360 - WorldMapLayout.stations()[3] · 검증 MV1(가)가 대조) - 그 높이에서 그냥 떨어지면 100% = 쓰러짐.
	--   100%(또는 피해로 체력 0) = 쓰러짐("쿵!" · 그을린 모습 knockdownSeconds) → 마지막 안전 지점(이번 체공을 시작한 땅)에서 체력 가득 · 아이템 손실 없음.
	--   불꽃 꼬리(경고) = 예상 피해가 flameWarnFraction 이상인 속도로 떨어지는 동안.
	--   제외(서버가 판정): 강제 이동 후 착지(보스 던지기 · 회오리 · 넉백 · 점프대 · 통통 열매 = HeightGuard 발사 허가 · 예외가 permitGraceSeconds 안 - 새 강제 이동은 HeightGuard.exempt 또는 grantLaunch를 부른다) ·
	--     사다리에서 떨어짐 · 나무 점프맵(허브 나무 둘레 WorldMapData.progress.treeRadius 안 - 체크포인트 복귀 규칙) · 보스전(BossEncounterId - 아레나 낙사 기믹 규칙) · 물 착지 · 넉백 잠금(클라 AirLocked).
	--   reportMaxSpeed = 클라가 보낸 속도 상한(그 위는 자른다) · reportMinGapSeconds = 사람마다 보고 간격 · charredSeconds = 일어난 뒤에도 그을린 모습이 남는 시간.
	fall = {
		safeMarginStuds = 3, lethalHeight = 360, flameWarnFraction = 0.5,
		knockdownSeconds = 1.6, charredSeconds = 5, permitGraceSeconds = 1.0,
		reportMaxSpeed = 2000, reportMinGapSeconds = 0.3,
		-- 리뷰 1(보안): 보고 = 서버가 본 체공과 맞아야 인정 - 서버 체공 세션이 끝난 지 reportWindowSeconds 안(또는 진행 중)이고 체공 시간 ≥ 보고 속도의 자유 낙하 시간(v ÷ g) × airtimeSlack.
		--   쓰러져 일어날 때 체력 = min(떨어지기 전 체력, 최대 × reviveHpCapFraction)(최소 1) - 낮은 체력에서 일부러 떨어져 가득 회복하는 길을 막는다(결정 요청).
		reportWindowSeconds = 1.5, airtimeSlack = 0.7, reviveHpCapFraction = 0.3,
		flame = { size = 6, heat = 12, maxDistance = 220 }, -- 불꽃 꼬리(로블록스 기본 Fire + Trail · 새 에셋 없음)
		charredColor = Color3.fromRGB(22, 24, 29), charredBlend = 0.65, -- 그을림 = 어두운 채움 Highlight(채움 불투명도 = charredBlend · 끝나면 지운다) · 색 = UIColors.metalBottom 값 재사용(새 색 금지)
	},

	-- 공중 점프 · 공중대시 모션(클라가 그린다 - 판정 없음). 루트 관절(Motor6D) C0에 회전을 더한다: 공중 점프 = 앞으로 한 바퀴(flipSeconds), 공중대시 = 앞으로 기울임(leanDeg · 대시 시간 동안).
	-- 입력 즉시 시작(준비 동작 없음). 남에게는 서버가 중계한다(relayMinGapSeconds보다 잦은 요청은 버린다).
	airMotion = { flipSeconds = 0.32, leanDeg = 22, relayMinGapSeconds = 0.08 },

	-- 점프력 옵션(펫 두 번째 옵션 예정 - 아직 출처 없음): "점프 높이 +%"로 정의한다(속도 %면 높이가 제곱으로 커진다). 합산 상한 +10%. 공중 점프도 이 높이의 비율이라 같이 커진다(최대 발 21.38).
	-- M1-0: 보스 아레나도 적용한다(G2a의 아레나 무시는 벽 14 · 한 체공 두 박자 여유 때문이었다 - 공중 점프 자유화로 둘 다 전제가 사라졌다).
	jumpHeightBonusCap = 0.10,

	-- 이동속도 합산 상한(신발 + 신속 옵션 · 보석): 걷기 배율 ≤ ×1.5(= 24 stud/s). 공격 속도(같은 신속 값)는 상한 없이 그대로다 - 상한을 넘는 몫은 공속으로만 남는다.
	-- 옛 값: 상한 없음(태초 신발 +549% ≈ 104 stud/s). 결정 필요(G2a 보고서 - 넘는 몫 처리 방식).
	moveSpeedMaxMultiplier = 1.5,

	-- 구조물이 부서질 때 윗면에 서 있던 사람(피해 · 튕김 없는 무너짐 - 지진파 · 모래 구덩이 · 끼임 해제 · 상한 교체): 클라가 아래로 이 속도를 준다(3.5 높이 0.19초 → 0.08초).
	-- 이번 낙하에는 공중 점프를 못 쓴다(G2a - 넉백 뒤와 같다, 착지하면 풀린다).
	structureDropSpeedStuds = 40,

	-- 서버 높이 검증(D0 부록 I §5): 발 − 마지막으로 서 있던 발 높이 > 최대 도달(JumpMath.maxReachStuds - 점프력 상한 · 공중 점프 전부) + toleranceStuds가 strikes번 이어지면 서 있던 자리로 되돌린다(+ 보스전이면 그 판 리더보드 무효).
	-- tolerance 1.0 = 복제 지연 · 보간 여유. 허용치를 넘으면 루트에서 아래로 (3 + 허용치 + probeStuds) 광선을 쏴 발 바로 아래 지면을 기준으로 다시 잰다(폴링이 짧은 착지를 놓친 경우 · FloorMaterial 지연).
	-- teleportResetStuds: 한 폴링(0.25초)에 이만큼 넘게 움직이면 순간이동으로 보고 기준을 새로 잡는다(정상 최대 = 24 × 0.25 + 대시 30.8 = 36.8 · MV1 활강 30/s × 0.25 = 7.5). graceSeconds = 그 뒤 유예.
	-- exemptExtraSeconds: 넉백 · 회오리 · 파편 튕김은 서버가 보낸 순간부터 체공 + 이만큼 검사를 건너뛴다.
	-- permit(M1-2c 발사 허가 - 점프대 · 통통 열매 · 보스 발사 패턴 공용 · server/LaunchPermit · HeightGuard.grant): 서버가 발사를 확인하면 "발 최고 높이 = 설계 정점 + 공중 점프 전부 + marginStuds"를 준다.
	--   허용 = max(평소 허용, 허가 높이). 겹쳐 쌓지 않는다(가장 최근 것만). 만료 = 착지(허가 뒤 공중을 한 번 봤고 landGraceSeconds 지난 뒤 서 있으면) · 공중을 못 보고 unusedSeconds 동안 서 있으면(안 쓴 허가).
	--   시간 상한(점프대 padSeconds · 보스 = 설계 체공 + bossExtraSeconds)이 지나면 바로 끊지 않고 "내려가기만"(가장 낮았던 발 + 평소 허용까지)으로 좁히다가 descendMaxSeconds 뒤 끝(활공 · 대시 대비).
	--   점프대 확인 = 최근 historySeconds 동안 서버가 본 루트 위치 중 하나가 발판 기둥(반경 + reachSlackStuds · 윗면 − belowSlackStuds ~ 정점) 안(요청 시각의 "지금 거리"가 아니다) ·
	--   요청이 위치보다 먼저 와도 pendingSeconds 동안 다시 본다 · 사람마다 cooldownSeconds.
	permit = { marginStuds = 4, padSeconds = 4, bossExtraSeconds = 2, landGraceSeconds = 0.2, unusedSeconds = 1.0, descendMaxSeconds = 20,
		-- 발판 확인 = 발이 윗면 − belowSlackStuds ~ 윗면 + aboveSlackStuds인 표본(리뷰 2: 정점 높이 기둥 전체를 받으면 공중에서 요청을 되풀이해 허가를 이어 받는다) ·
		-- 요청 최소 간격 requestGapSeconds(리뷰 4) · 기록 보관 = historySeconds + historyKeepExtraSeconds.
		historySeconds = 0.5, historyKeepExtraSeconds = 0.1, pendingSeconds = 0.5, reachSlackStuds = 4, belowSlackStuds = 3, aboveSlackStuds = 6,
		cooldownSeconds = 0.25, requestGapSeconds = 0.1 },
	-- S1 수평 이동 검사(서버 권위 - HeightGuard.evaluateHorizontal · 같은 0.25초 폴링). 토큰 버킷: 초당 rate만큼 차고(최대 rate × bucketSeconds + slackStuds - 지연 0.25로 표본이 몰려도 1초까지 흡수),
	--   표본 사이 수평 이동만큼 쓴다. 모자라면 = 마지막 정상 자리로 되돌림(킥 · 자동 제재 없음 · 위반 횟수 로그). rate = 합법 이동 목록(legal)에서 지금 켜진 것 중 가장 큰 값:
	--   walk = 걷기 상한(16 × 1.5) · glide = 활강 전진(서버 Attribute Gliding) × glideMargin · water = 걷기 상한 + 물살 최대(flowMaxStuds) · permit = 발사 허가 비행(점프대 · 통통 열매 · 보스 발사 · 붙잡기 올라서기) ·
	--   대시 = 서버가 준 대시마다 그 거리(× dashMargin)를 따로 쌓아 dashWindowSeconds 동안 쓴다(2단 대시 = 두 번) · 밀림 burst(선인장) · 예외(붙잡힘 · 가둠 · 서버 순간이동 = HeightGuard.reset · 루트 고정 · 사망) = 검사 안 함.
	--   서버 순간이동 표시 없는 큰 이동(옛 "한 폴링 50 넘으면 순간이동으로 인정" - S1에서 삭제)은 이 검사가 되돌린다.
	--   permitSpeed = 서버가 건 보스 발사(grantLaunch - 넉백 · 회오리 · 판 털기 초속 약 350 · 던지기) 설계 체공 중 수평 상한.
	--   padSpeedMargin(S1 후속 0-4) = 플레이어 발판 허가(나무 점프대 · 수정 부수기 발판)의 수평 상한 = 설계 수평 속도(포물선 거리 ÷ 비행 시간) × 이 여유. 통통 열매 · 붙잡기 = 걷기 그대로(수평 속도를 안 준다).
	--   walkMargin = 걷기 상한 물리 여유(경사 미끄럼 · 부딪힘 - S1 지연 실측: 상한 그대로면 24/s로 계속 걸을 때 버킷이 안 차 경계 오탐 1건) - 10% 미만 속도 조작은 못 잡는다(보고서).
	moveGuard = { bucketSeconds = 1.5, slackStuds = 3, walkMargin = 1.1, glideMargin = 1.1, flowMaxStuds = 18, permitSpeed = 400, padSpeedMargin = 1.25, dashMargin = 1.15, dashWindowSeconds = 1.3, burstWindowSeconds = 1.0,
		legal = { "걷기(이속 상한 24)", "대시 · 공중 대시 · 태초 2단 대시(서버 대시 허가)", "활강(Gliding)", "물살", "발사 허가(점프대 · 통통 열매 · 보스 던지기 · 회오리 · 판 털기 · 넉백 · 붙잡기 올라서기)",
			"선인장 밀림(burst)", "원거리 공중 정지 · 일어나기(이동 0)", "사다리 · 덩굴(수직)", "서버 순간이동(Travel · 리프트 · 복귀 · 보스 입장 · 보스 기믹 = HeightGuard.reset)", "붙잡힘 · 가둠(exempt)" } },
	-- stallSeconds · stallDropStuds(S1 후속 0-1 - 공중 정체): 활강 · 원거리 공중 정지 · 허가 · 예외 · 유예 밖에서 공중으로 stallSeconds 넘게 stallDropStuds만큼도 안 내려가면 되돌린다
	--   (허용 높이 아래에 떠서 버티는 "날기" - G2a(나) 체인 첫머리에 서버가 본 위치가 발 +17.3에서 6초 정지했는데 아무 검사도 안 걸렸다). 합법 최대 = 공중 점프 2 + 대시 약 2.0초(JumpMath.maxAirSeconds) ·
	--   태초 2단 대시 · 지연 0.25 몰림 여유 · 태초 장갑 매달림(hangMaxSeconds 4 + 오르기 0.22 - 허가가 거절돼도: 정체 리뷰 2) = 5초. 발 아래 probe 안에 지면이 보이면 서 있는 것으로 친다.
	heightGuard = { toleranceStuds = 1.0, strikes = 2, probeStuds = 3.5, teleportResetStuds = 50, graceSeconds = 1.0, exemptExtraSeconds = 0.5, stallSeconds = 5.0, stallDropStuds = 1.0,
		climbBox = Vector3.new(7, 10, 7) }, -- M1-4: 오르는 중 = 루트 둘레 이 상자 안에 사다리(TrussPart · Climbable)가 있을 때만 "서 있음"(지연 0.25 × 오르기 속도 여유)

	-- M1-3 물(Terrain 물 - 익사 없음 · 로블록스 기본 헤엄): 공중 점프 충전은 물 밖 착지에서만 돌아온다(물에 떠 있기만으로는 안 찬다 - 물 → 공중 점프 무한 사다리 방지).
	--   물속 대시 = 불가(dashInWater false - 결정: 물살 거슬러 대시로 강을 무의미하게 만들지 않게 · 대시 도착점 계산이 물 위 · 물속을 구분하지 못한다). 판정 = 루트 복셀이 물(점유율 ≥ inWaterOccupancy).
	--   물살(강): 클라가 하류로 흐름 속도만큼 끌고 간다(TerrainShape 흐름) · 서버는 물살 안 수평 속도 ≤ 걷기 상한 + 물살 + capMarginStuds를 잰다(넘으면 경고 · 횟수 - 속도 검사 없는 지금 규칙 안에서 기록만).
	--   flowCheckSeconds = 클라가 흐름 식을 다시 계산하는 간격 · teleportIgnoreSpeed = 이보다 빠른 한 폴링 이동은 순간이동(Travel이 따로 처리 - 속도 상한 검사에서 뺀다).
	water = { dashInWater = false, rechargeInWater = false, inWaterOccupancy = 0.4, capMarginStuds = 8, capStrikes = 3, flowCheckSeconds = 0.2, teleportIgnoreSpeed = 200 },

	-- 카메라(M1-0 - 사용자 결정): 기본 = 로블록스 기본 카메라(회전 · 줌 · 각도 자유)에 줌 범위만 건다(캐릭터가 작아 보이지 않게 기본 거리를 가깝게). 설정의 "탑다운 시점"을 켠 사람만
	-- G2a 값(55° · 45 · 각 40 ~ 70 · 줌 25 ~ 70)으로 각을 조인다. 줌 최소 10 = 1인칭 · 코앞 금지(조준 · 캐릭터 가림). spawnSnapSeconds = 스폰 직후 기본 거리(탑다운이면 각도도)로 맞추는 시간.
	camera = {
		free = { zoomStuds = 22, zoomMinStuds = 10, zoomMaxStuds = 60 },
		topDown = { pitchDeg = 55, pitchMinDeg = 40, pitchMaxDeg = 70, zoomStuds = 45, zoomMinStuds = 25, zoomMaxStuds = 70 },
		spawnSnapSeconds = 0.3,
		-- M1-0 결정 ②(사용자 확정): 보스전 중에만(Player Attribute BossEncounterId) 내려다보는 각 최소 30° - 누운 카메라에서 장판이 납작해지고 앞 장판이 뒤를 가린다. 필드는 자유.
		bossPitchMinDeg = 30,
	},

	-- 시점 고정(자체 구현 - 기본 Shift Lock은 끈다 · 대시 LeftShift와 충돌 0): 켜면 마우스를 화면 가운데에 묶고 캐릭터가 카메라 방향을 본다. 카메라는 오른쪽 어깨 너머(cameraOffsetStuds).
	shiftLock = { cameraOffsetStuds = Vector3.new(1.75, 0, 0) },
}
