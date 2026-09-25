-- 보스 연출 1차(P3d A - 카툰) 데이터. 게임 판정은 이 파일을 읽지 않는다 - 클라 연출(client/BossFx · BossMotionView · BossPatternVisuals)만 읽는다.
-- 규칙(사용자 지시): 굵은 외곽선 · 평면적이고 채도 높은 색 · 과장된 모션(찌그러짐 · 늘어남 · 예비 동작 · 여운) · 덩어리감 있는 파티클. 연출은 클라 로컬이고 서버 시간 · 판정을
-- 멈추지 않는다(서버가 보낸 시각에 맞춰 그리기만 한다). 전조(빨강 장판 · 파동 띠 · 돌진선 · 대상 표식)를 가리면 안 된다 - 먼지는 낮고 반투명하게, 짧게.
-- 내 화면 효과(흔들림 · 가까운 먼지)는 강하게, 다른 멤버가 주인공인 효과는 약하게(otherPlayerWeight).
-- 새 에셋 · ParticleEmitter 없음: "파티클" = 풀링한 파트(공 · 판 · 막대)를 한 RenderStepped가 움직인다(BossFx) - 동시 상한 maxActive.
--
-- 보스별 모션(A1) = bosses[보스 id] - 스타일 이름은 client/BossMotionView의 빌더 표 키다(보스 이름이 들어간 함수는 없다 - 새 보스는 여기 한 줄).
--   slam(지진파 찍기 - ring 스킬의 예비 동작 · 임팩트): "twoFistSlam"(두 손 내려찍기) · "tailSwipe"(꼬리 휘두르기) · "staffStrike"(지팡이 찍기) · "hopLand"(점프 착지)
--   charge(돌진 - A4): "hoofScrape"(발 긁기 → 돌진) · "burrow"(잠행 - 몸은 땅속, 꼬리 먼지만)
--   지진파가 없는 보스(서리 거인 · 수정 여왕 · 전갈 여왕)는 slam이 없다 - 그대로 둔다.
return {
	bosses = {
		section_guardian = { slam = "twoFistSlam", charge = "hoofScrape" },
		abyssal_lord = { slam = "tailSwipe" },
		storm_lord = { slam = "staffStrike" },
		scorpion_queen = { charge = "burrow" },
	},
	defaultSlam = "hopLand", -- bosses에 slam이 없는 새 ring 보스

	-- 성능(A5): 동시에 움직이는 효과 조각(먼지 · 파편 · 속도선 · 잔상)의 상한 · 풀에 남겨 둘 조각 수. 12인 서버에서도 보스전은 파티(≤ 4명)마다 따로라 한 클라가 그리는 것은
	-- 자기 파티의 보스 하나뿐이다 - 상한은 한 클라 기준.
	maxActive = 90,
	poolKeep = 120,
	otherPlayerWeight = 0.5, -- 다른 멤버가 주인공인 효과(그 사람이 돌진 대상 · 그 사람이 떨어짐)는 조각 수 · 크기에 이 배율

	-- 모션 박자(A1 · A2): 예고(전조) 시간을 비율로 나눈다 - 서버 hop과 같은 시계(shockTelegraph seconds)라 찍는 순간 = 파동이 나가는 순간.
	windupFraction = 0.6, -- 0 ~ 0.6 크게 들어 올린다(늘어남 · 뒤로 젖힘)
	holdFraction = 0.25, -- 0.6 ~ 0.85 꼭대기에서 멈칫(떨림)
	-- 나머지 0.15 = 내려찍기(빠르게) → 임팩트 뒤 recoverSeconds 동안 납작 → 원래대로(여운)
	recoverSeconds = 0.35,
	stretch = 1.25, -- 들어 올릴 때 세로 늘어남(가로는 1 ÷ √stretch)
	squash = 0.7, -- 임팩트 순간 세로 찌그러짐(가로는 1 ÷ √squash)

	-- 풍압(A2): 찍는 순간 방사형 먼지 + 바람 줄기
	impact = {
		dustCount = 14, dustRadius = 10, dustSize = { 1.6, 2.6 }, dustSeconds = 0.55, dustTransparency = 0.45,
		streakCount = 10, streakLength = { 7, 11 }, streakSeconds = 0.3, streakThickness = 0.25,
		ringSeconds = 0.35, ringRadius = 16,
	},
	-- 가까운 플레이어 화면 흔들림(로컬 · 약하게). 거리 nearStuds 안에서 amplitude(stud)를 거리에 따라 줄인다. 끄기 = 플레이어 Attribute SettingBossScreenShake = false
	-- (설정창이 생기면 그 토글이 이 Attribute를 쓴다 - BossFx.setShakeEnabled).
	shake = { enabled = true, nearStuds = 45, amplitudeStuds = 0.35, seconds = 0.22, chargeTargetBonus = 1.4 },

	-- 땅 파도(A3): 파동 띠 자리의 바닥이 솟았다 꺼진다(시각 전용 - 띠 = 판정 자리 그대로). 솟은 흙 = 맵 바닥색을 조금 밝게, 외곽선 = 어두운 테.
	groundWave = { segments = 32, crestHeight = 1.3, rollSpeed = 10, rollWaves = 6, rimDarken = 0.35 },
	-- M1 BR1-3 후속(사용자 - 지진파 상 · 하 구분, 모양 1순위): 색 = 보스 머리색(테마)을 바닥색과 밝기 차 minLumaGap 이상이 되게 밝히거나 어둡게(바닥과 섞이지 않게).
	--   하단(땅 파동) = 두꺼운 흙물결(불투명 띠 + 마루) + 지나간 자리 바닥이 꿈틀 들썩(heave - 파동 안쪽 띠의 작은 블록이 솟았다 가라앉는다).
	--   상단(공중 파동) = 머리 높이 얇은 칼날 고리(blade - 네온 · 두께 bladeHeight) + 판정 띠는 아주 옅게(bandTransparency) + 흰 테두리 두 줄(판정 위 · 아래). 인형 방식 · 파티클 0.
	quakeLook = { minLumaGap = 0.4, groundTransparency = 0.05, bladeHeight = 0.5, bandTransparency = 0.88,
		heave = { segments = 28, amplitude = 0.9, behindStuds = 5, width = 4, waves = 5, speed = 14 } },

	-- 돌진 속도감(A4)
	charge = {
		scrapeInterval = 0.28, scrapeDust = 3, -- 전조 동안 발 긁기 먼지(보스 뒤쪽)
		streakInterval = 0.05, streakPerTick = 2, streakLength = { 6, 10 }, streakSeconds = 0.22,
		ghostInterval = 0.09, ghostSeconds = 0.3, ghostTransparency = 0.6, ghostMax = 4,
		trailInterval = 0.07, trailSize = { 1.4, 2.2 },
		impactChunks = 8, impactRing = 14,
	},

	-- 단상 금 · 무너짐(C2) · 지형 재생성(D2) · 모래 구덩이 달그락(E2)
	dais = { crackDust = 8, crumbleChunks = 14, warnAmplitudeStuds = 0.45, warnMinSeconds = 0.35, warnDust = 10 }, -- warn* = P3d-F B3 붕괴 예고(흔들림 · 먼지)
	regrow = { shadowTransparency = 0.45, glowPulse = 6 },
	rattle = { amplitudeStuds = 0.25, seconds = 0.35 },
}
