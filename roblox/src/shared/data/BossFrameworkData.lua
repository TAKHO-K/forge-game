-- BOSS-FRAMEWORK 스위치 · 공통 수치(바이블 §1-2 ~ §1-4). 게임 판정 · 스킬 수치는 여기 없다(BossData 그대로).
local D = {}

-- 어느 보스가 새 몸(리그 v2)으로 뜨는가.
--   live = 실전(라이브 포함) - **설계 담당이 수호자 시험을 검수한 뒤에만 채운다**(지금 비어 있음 = 6보스 모두 옛 몸).
--   studioTrial = Studio에서 workspace Attribute BossFrameworkTrial = true일 때만(시험 · 촬영 · 하네스) - 라이브 서버에서는 무시.
D.live = {}
D.studioTrial = { section_guardian = "v2", frost_giant = "v2", storm_lord = "v2", abyssal_lord = "v2" } -- BOSS-NIGHT-1: 매머드 · 폭풍 · 나가 새 몸(시험 스위치로만)
D.trialAttribute = "BossFrameworkTrial"

-- GUARDIAN-V2 몸 가장자리 기준 근접 반경(바이블 §5 - 공통 장치 · 보스별 · 기본 끔 = 표에 없음): 새 몸(리그 v2 · edgeHalfWidth)이 뜰 때만
--   반경 = 기존 값 + 늘어난 몸 반지름(BossFramework.edgeGrowth - 서버 spawnEncounter가 인스턴스 사본에 얹는다 · BossData 원본 무변경).
--   skills = { [스킬 id] = true }(보스 중심 원 · 부채 반경 · 안쪽 반경 · 대상 거리 조건 · 반사 결계 반경) · innerSafe = 근접 원형 구역 · chaseStop = 추격 정지 거리.
D.bodyEdge = {
	-- damageScale 0.80 = GUARDIAN-V2 5 BossSim(아는 보스 원거리 · 근거리 · 스테이지 100 · 500 · 600판): 전멸 55 ~ 59% → 42 ~ 50% · 받는 피해 94 ~ 97% → 84 ~ 88% · 처치 69초 그대로(체력 무변경)
	-- GUARDIAN-V3 6(사용자 목표: 첫 조우 전멸 ≤ 50% - 근접 · 원거리 각각): 키 30 · 돌진 폭 = 몸 폭 · 바나나 · 도약이 더해진 V3 모형에서 체력 × 0.85 · 피해 × 0.62
	--   (BossSim 600판 · 스테이지 100 · 500 - 처음 전멸 원거리 약 46% · 근접 약 43% · 처치 58초 · guardian_v3/s6_bosssim.txt). 아는 보스 전멸 약 24 ~ 28%(바이블 30 ~ 50 하한 아래 - 보고서 결정 필요).
	section_guardian = { skills = { heavy = true, innerSmash = true, swipe = true, mirror = true }, innerSafe = true, chaseStop = true, damageScale = 0.62, hpScale = 0.85 },
	-- BOSS-NIGHT-1 1 매머드: 보스 중심 원 · 부채(빙결 강타 r18 · 원 안 짓밟기 · 강화 평타 · 발 구르기 r30 · 얼음 거울) = 몸 가장자리 기준 · 밸런스 = BossSim(mammoth_v1/s_bosssim.txt)
	--   피해 × 0.60(600판 · 처음 전멸 원거리 약 41% · 근접 약 48% ≤ 50 · 아는 보스 약 14 ~ 21% = 바이블 30 ~ 50 하한 아래 - 수호자와 같은 구조 · 보고서 결정 필요)
	frost_giant = { skills = { slam = true, innerSmash = true, swipe = true, stomp = true, mirror = true }, innerSafe = true, chaseStop = true, damageScale = 0.60, hpScale = 1.0 },
	-- BOSS-NIGHT-1 2 폭풍 군주: 강화 평타 · 원 안 낙뢰 · 번개 결계 = 몸 가장자리 기준 · 밸런스 = BossSim(storm_v1/s_bosssim.txt)
	--   피해 × 0.95(600판 · 처음 전멸 원거리 약 33% · 근접 약 45% ≤ 50 · × 1.0이면 근접 52%) - 아는 보스 12 ~ 18%(30 ~ 50 아래 - 다른 보스와 같은 구조)
	storm_lord = { skills = { swipe = true, innerSmash = true, mirror = true }, innerSafe = true, chaseStop = true, damageScale = 0.95, hpScale = 1.0 },
	-- BOSS-NIGHT-1 3 나가: 꼬리 휩쓸기(도넛 안 · 밖) · 꼬리 반원 · 강화 평타 · 물의 장막 = 몸 가장자리 기준 · 밸런스 = BossSim(abyssal_v1/s_bosssim.txt)
	--   피해 × 0.75(600판 · 처음 원거리 47% · 근접 49% · 아는 보스 33 ~ 34% - 두 목표 모두 안) · 새 몸이 옛 몸보다 넓지 않아 몸 가장자리 증가 0(밸런스 계수만)
	abyssal_lord = { skills = { sweep = true, tailSweep = true, swipe = true, mirror = true }, chaseStop = true, damageScale = 0.75, hpScale = 1.0 },
}

-- GUARDIAN-V3(사용자 시험 피드백 · 바이블 §11): 새 몸이 뜰 때만(BossFramework.applyV3 - 몸 가장자리 장치 뒤 · 인스턴스 사본 · BossData 원본 · 라이브 무변경).
--   hideFloor = 바닥 전조를 그리지 않는 근접 공격(서버가 사건에 noFloor를 싣는다 - 판정 · 시간 그대로): 스킬 id · basic(평타 쓸기) · innerRing(근접 원형 구역 파랑 원)
--   windup = 예비 동작 연장(초 - 전조 = 예비 동작이라 판정 시각도 같이 늦어진다 = 피하기 쉬워지는 쪽) · skills = 늘릴 스킬 · basic = 평타 예비 신호를 이만큼 먼저
--   glow = 예비 동작 동안 때리는 손 수정 발광(클라 Highlight - 끝 0.15초는 흰 번쩍이 덮는다) · 부위 = 동작 세트 flash 표 · basic = 평타 휘두를 손
--   marks = 남기는 바닥 표시(근접 아님)의 색 - 연보라 반투명(빨강 금지): 돌진 경로 균열선(폭 = 몸 폭) · 도약 착지 균열 원 · 지진파 균열 링
--   move = 기본 이속 × speedScale · 대상이 sprintBeyondStuds 밖이면 × sprintMultiplier(질주)
--   skills = 새 반응 스킬(BossScheduler ⑧ - 전역 쿨 무시 · 일반 후보 제외 · reactiveOrder 순서) · ringStyle = 지진파 그림(클라 BossQuakeView)
--   firstAssist = 첫 보스 도움(실패 1회마다 보스에게 받는 피해 − perFail · 최대 − max · 이 보스 첫 클리어 전까지 · 저장 bossAssist v75)
--   sim = BossDifficultySim 가정(반응 스킬 - 원거리가 30 stud 밖에 머무는 비율 · 바나나 · 도약 명중 확률)
local LAVENDER = Color3.fromRGB(190, 160, 255)
D.v3 = {
	section_guardian = {
		hideFloor = { heavy = true, innerSmash = true, swipe = true, basic = true, innerRing = true },
		windup = { seconds = 0.12, skills = { heavy = true, innerSmash = true, swipe = true }, basic = true },
		glow = { color = Color3.fromRGB(200, 110, 255), fillPeak = 0.55, outline = 0.35, skills = { heavy = true, innerSmash = true, swipe = true, banana = true, leap = true }, basic = true },
		-- 채움 = 연보라 비발광(반투명) · 균열선 = 보라 Neon(가장 낮은 채널 ≤ 90 - 연보라 Neon은 흰색으로 날아갔다 · Studio 캡처)
		marks = { color = LAVENDER, crackColor = Color3.fromRGB(160, 90, 255), transparency = 0.6, crackTransparency = 0.25, crackWidth = 0.35 },
		chargeHalfWidth = "body", -- 돌진 경로 반폭(판정 · 그림) = 새 몸 가장자리 반폭(edgeHalfWidth × S × scale)
		move = { speedScale = 1.3, sprintBeyondStuds = 25, sprintMultiplier = 1.5 },
		ringStyle = "quakeSlabs",
		reactiveOrder = { "leap", "banana" },
		skills = {
			-- 바나나 던지기: 대상이 30 stud 밖에 1.5초 머물면(쿨 3초) · 예비 0.45초(팔 뒤로 + 바나나 발광) → 110 stud/s 직선 · 리드 조준 50% · 최대 체력 7% · 광폭(≤ 50%) = 3갈래 부채
			banana = {
				primitive = "projectile", motion = "fist", projectileStyle = "banana", reactive = true, -- 말풍선 없음(낙석 "?"와 겹쳤다 - 신호 = 예비 동작 · 손 바나나 발광)
				conditions = { { type = "targetBeyondFor", studs = 30, seconds = 1.5 } },
				cooldownSeconds = 3, priority = 0,
				telegraphSeconds = 0.45, count = 1, spreadDeg = 0, launchIntervalSeconds = 0,
				speedStuds = 110, turnRateDeg = 0, radiusStuds = 2, lifetimeSeconds = 1.6, heightMode = "air", launchHeightStuds = 9,
				targetRule = "target", leadSeconds = 1.0, leadFraction = 0.5, reflectable = false,
				overrides = { { hpBelow = 0.5, set = { count = 3, spreadDeg = 14 } } },
				onMiss = { { type = "noteMiss", key = "banana" } },
				damage = { kind = "maxHp", fraction = 0.07 }, damageLabel = "바나나",
				meshSlot = "GuardianBanana",
			},
			-- 빗나감 → 도약: 바나나가 대상에 안 맞으면 miss + 1 · 12초 창 안 2회 → 준비 1.1초(V3.1 · 0.9 → 1.1 · 웅크림 · 수정 발광 · 착지 균열 원 - 마지막 0.4초 고정 · 걸어서 회피 여유 0.39초) → 포물선 0.8초(최대 60 stud) →
			--   착지 충격 반경 = 몸 가장자리 + 12 · 넉백. 착지 자리 = 대상 자리에서 몸 가장자리 반폭만큼 앞(몸 끝이 대상 자리에 닿는다 - 고정 뒤 1.2초 = 걸어서 원 밖).
			leap = {
				primitive = "leap", bubble = "heavy", motion = "fist", reactive = true,
				conditions = { { type = "missesWithin", key = "banana", count = 2, seconds = 12 } },
				onStart = { { type = "clearMisses", key = "banana" } },
				cooldownSeconds = 0, priority = 0,
				telegraphSeconds = 1.1, lockSeconds = 0.4, flightSeconds = 0.8, apexStuds = 22, maxLeapStuds = 60,
				radiusStuds = 12, radiusFromEdge = true, landShortFromEdge = true,
				onHit = { { type = "launch", heightStuds = 4, distanceStuds = 16 } },
				damage = { kind = "attack", multiplier = 1.5 }, damageLabel = "도약",
			},
		},
		firstAssist = { perFail = 0.10, max = 0.30 },
		-- 원거리가 30 stud 밖에 있는 비율 0.25: 활 사거리 15(10 × 1.5) + 새 몸 피격 반경 약 6.2 = 보스 중심 약 21 stud 안에서 때린다 → 30 밖 = 피하기 · 물러남 동안만(보스 질주 15.6이 따라붙음)
		sim = { rangedFarShare = 0.25, meleeFarShare = 0.08, farSegmentSeconds = 3, bananaHit = { first = 0.45, later = 0.3 }, leapHit = { first = 0.55, later = 0.35 } },
	},
	-- BOSS-NIGHT-1 1 빙하 매머드 "빙하 엄니"(설계 메모 MAMMOTH-SCORPION-NOTES · 새 몸이 뜰 때만): 수호자와 같은 근접 규칙(바닥 표시 없음 · 예비 +0.12 · 엄니/코/발 발광) +
	--   신규 4패턴 = 얼음 상아 발사 tuskShot(얼음 창 spear 대체 · 고드름처럼 자기 축 회전 2발) · 코 채찍 trunkWhip · 상아 돌진 gore(경로 폭 = 몸 폭 · 균열선) · 뒷발차기 backKick(반응 - 뒤쪽 1.5초).
	--   앞 구역 = 상아 · 코 · 앞발(radiusFrom = "front" - 몸 중심 → 머리 앞 끝) · 뒤 구역 = 뒷발차기(radiusFrom = "rear" - 몸 중심 → 엉덩이 끝) · 옆구리는 상대 안전.
	frost_giant = {
		hideFloor = { slam = true, innerSmash = true, swipe = true, trunkWhip = true, backKick = true, basic = true, innerRing = true },
		windup = { seconds = 0.12, skills = { slam = true, innerSmash = true, swipe = true, trunkWhip = true }, basic = true },
		glow = { color = Color3.fromRGB(120, 200, 255), fillPeak = 0.55, outline = 0.35, skills = { slam = true, innerSmash = true, swipe = true, trunkWhip = true, backKick = true, tuskShot = true, gore = true }, basic = true,
			basicParts = { R = "Tusk_R", L = "Tusk_L" } },
		marks = { color = LAVENDER, crackColor = Color3.fromRGB(160, 90, 255), transparency = 0.6, crackTransparency = 0.25, crackWidth = 0.35 },
		bodyCharges = { gore = true }, -- 돌진 경로 반폭 = 몸 가장자리 반폭 · 균열선
		lockFacing = true, -- 스킬 시작 순간 대상 쪽으로 몸 방향 고정(스킬 동안 안 돎 → 등 뒤가 생긴다 - 뒷발차기) · 스킬 끝 = 다시 대상을 봄
		displayNameNote = "빙하 엄니", -- 표시 이름 = BossData displayName(전 몸 공통 - 사용자 확정)
		removeSkills = { "spear" }, -- 얼음 창 → 얼음 상아 발사(tuskShot)
		addSkills = {
			-- 얼음 상아 발사: 머리 숙임 → 상아에 얼음이 자람(1.4초) → 얼음 상아 복제 2발(왼 → 오른 0.4초 간격 · 자기 축 회전) · 상아 본체는 그대로
			tuskShot = {
				primitive = "projectile", bubble = "meteor", motion = "tusk", projectileStyle = "icetusk",
				cooldownSeconds = 12, priority = 0, starvationSeconds = 45,
				telegraphSeconds = 1.4, count = 2, spreadDeg = 10, launchIntervalSeconds = 0.4,
				speedStuds = 70, turnRateDeg = 0, radiusStuds = 2.5, lifetimeSeconds = 3, heightMode = "air", launchHeightStuds = 12,
				targetRule = "target", leadSeconds = 0.6, leadFraction = 0.5, reflectable = true,
				damage = { kind = "attack", multiplier = 1.8 }, damageLabel = "얼음 상아",
				meshSlot = "FrostIceTusk",
			},
			-- 코 채찍: 코를 옆으로 감았다가 휘두름(앞 140° 부채 · 반경 = 머리 앞 끝 + 12) · 번쩍 = 코 끝 3마디 · 맞으면 옆으로 밀림
			trunkWhip = {
				primitive = "sector", bubble = "swipe", motion = "trunk",
				cooldownSeconds = 9, priority = 0, starvationSeconds = 45,
				conditions = { { type = "targetWithin", studs = 12 } },
				telegraphSeconds = 1.2, angleDeg = 140, radiusStuds = 12, radiusFrom = "front", facing = "target",
				dodge = { distanceStuds = 7.1 },
				onHit = { { type = "launch", heightStuds = 3, distanceStuds = 12 } },
				damage = { kind = "attack", multiplier = 1.6 }, damageLabel = "코 채찍",
			},
			-- 상아 돌진: 고개 숙이고 발 구름(2.2초) → 직선 돌진(경로 폭 = 몸 폭 · 연보라 균열선) → 벽에서 헤롱
			gore = {
				primitive = "charge", bubble = "charge", motion = "tusk",
				cooldownSeconds = 16, priority = 0, starvationSeconds = 45,
				conditions = { { type = "notAfter", skills = { "grab" } } },
				telegraphSeconds = 2.2, speedStuds = 55, pathHalfWidthStuds = 4, dashCount = 1,
				recoverSeconds = 3.5, dazeSinkStuds = 1.2, dazeTiltDeg = 12,
				arenaMarginStuds = 4, marginFrom = "front", -- 벽 멈춤 = 머리 앞 끝 + 4(긴 몸이 벽에 묻히지 않게)
				damage = { kind = "attack", multiplier = 2.1 }, damageLabel = "상아 돌진",
			},
		},
		reactiveOrder = { "backKick" },
		skills = {
			-- 뒷발차기(반응): 대상이 엉덩이 쪽 부채(뒤 ±60° · 엉덩이 끝 + 20 안)에 1.5초 → 앞발 버티고 두 뒷다리 차기(예비 1.1 · 뒤 120° · 엉덩이 끝 + 14) · 넉백 큼
			backKick = {
				primitive = "sector", bubble = "swipe", motion = "kick", reactive = true, facing = "target", keepFacing = true, -- 직전 스킬 방향 그대로(엉덩이가 대상 쪽)
				conditions = { { type = "targetBehindFor", seconds = 1.5, halfAngleDeg = 60, studs = 20, from = "rear" } },
				cooldownSeconds = 6, priority = 0,
				telegraphSeconds = 1.1, angleDeg = 120, radiusStuds = 14, radiusFrom = "rear", -- 예비 1.1 ≥ 인지 0.5 + 옆 8 stud 걷기 0.5(대시 없이 피함)
				onHit = { { type = "launch", heightStuds = 6, distanceStuds = 28 } },
				damage = { kind = "attack", multiplier = 2.0 }, damageLabel = "뒷발차기",
			},
		},
		-- BossDifficultySim 가정: 뒤쪽에 머무는 구간 비율(근접 · 원거리) · 평균 구간 길이 · 반응 스킬 명중(처음 · 두 번째부터)
		sim = { behindShare = { melee = 0.18, ranged = 0.04 }, behindSegmentSeconds = 3, hit = { backKick = { first = 0.6, later = 0.35 } } },
	},
	-- BOSS-NIGHT-1 2 폭풍 군주(바이블 §2-5 · §10 · STORM-PARTS): 근접 규칙(강화 평타 · 원 안 낙뢰 바닥 표시 없음 · 예비 +0.12 · 지팡이/주먹 노랑 발광) +
	--   50% 변신 무적 2.8초(진행 중 스킬 끊김 · 패턴 정지 · 받는 피해 × 0 - 그동안 클라: 망토 → 날개 · 1폼 부품 숨김 · 2폼 부품 날아와 붙음 · 후광). 스킬표 · 피해 무변경(2폼 = 주먹 동작).
	storm_lord = {
		hideFloor = { swipe = true, innerSmash = true, basic = true, innerRing = true },
		windup = { seconds = 0.12, skills = { swipe = true, innerSmash = true }, basic = true },
		glow = { color = Color3.fromRGB(255, 225, 90), fillPeak = 0.55, outline = 0.35, skills = { swipe = true, innerSmash = true, discharge = true, thunderRing = true, strike = true, boltSpear = true, tornado = true }, basic = true,
			basicParts = { R = "Hand_R", L = "Hand_L" } },
		marks = { color = LAVENDER, crackColor = Color3.fromRGB(160, 90, 255), transparency = 0.6, crackTransparency = 0.25, crackWidth = 0.35 },
		transformGuard = { hpBelow = 0.5, seconds = 2.8 },
	},
	-- BOSS-NIGHT-1 3 나가(바이블 §2-3): 근접 규칙(강화 평타 · 평타 바닥 표시 없음 · 예비 +0.12 · 삼지창 · 꼬리 청록 발광) - 꼬리 휩쓸기 · 꼬리 반원(큰 범위 · 점프)은 바닥 표시 유지 · 스킬표 무변경
	abyssal_lord = {
		hideFloor = { swipe = true, basic = true, innerRing = true },
		windup = { seconds = 0.12, skills = { swipe = true }, basic = true },
		glow = { color = Color3.fromRGB(60, 200, 255), fillPeak = 0.55, outline = 0.35, skills = { swipe = true, sweep = true, tailSweep = true, tide = true, tridentThrow = true, spout = true }, basic = true,
			basicParts = { R = "TridentHead", L = "Hand_L" } },
		marks = { color = LAVENDER, crackColor = Color3.fromRGB(160, 90, 255), transparency = 0.6, crackTransparency = 0.25, crackWidth = 0.35 },
	},
}

-- 교체 슬롯 → 메시 캐시 키(ArtAssetIds · ArtMeshCache). 캐시가 없으면(아트 스위치 끔) 클라가 파트로 그린다.
--   V3.1: Meshy "어둠에 오염되는 바나나"(guardian_v1_banana_remesh10k → prop_kit 3,000삼각형 · 구운 색 512) - 옛 Blender 임시 메시 fx/guardian_banana는 그대로 남김(삭제 금지).
--   meshSlotTextures = 그 메시에 입힐 아틀라스(ArtAssetIds image id - 없으면 색 재질)
D.meshSlots = { GuardianBanana = "fx/guardian_banana_m", FrostIceTusk = "fx/frost_icetusk_m", StormOrb = "fx/storm_orb_m" }
D.meshSlotTextures = { GuardianBanana = "fx/guardian_banana_m_atlas1", FrostIceTusk = "fx/frost_icetusk_m_atlas1", StormOrb = "fx/storm_orb_m_atlas1" }

-- 예산(바이블 §1-4) - 하네스 · /gg boss frame check가 검사한다
D.budget = {
	joints = 60, meshParts = 90, outlines = 12, neon = 10, tris = 30000, partTris = 5000, outlineTris = 8000, atlases = 3, atlasSize = 1024,
	queryVolumeTolerance = 0.2, -- 판정 사본 부피 = 옛 몸 ±20%
	queryParts = 3, -- Body · Head + 큰 몸이면 1개
}

-- 타격 정지(히트스톱) 범위(초 - 무게 곱한 뒤) · 클립 세트를 묶을 때 이 범위로 맞춘다(전조 · 판정 시각 무관 - 보이는 몸만)
D.hitstop = { min = 0.05, max = 0.08 }

-- 번쩍임(때리는 부위 흰 테): 전조 끝(판정 시각) 직전 seconds초 · 흰색만(빨강 · 진한 주황 금지 - 바이블 §1-2)
D.flash = { seconds = 0.15, color = Color3.fromRGB(255, 255, 255), fillPeak = 0.55, outline = 0 }

-- 2차 움직임 스프링(관절 사슬 - 클라 client/BossSpring): kind별 강성 k · 감쇠 c · 몸 가속 반응 gain · 회전 반응 turnGain · 다음 마디로 전달 carry · 최대 각(도)
D.springs = {
	tail = { k = 38, c = 6.5, gain = 1.0, turnGain = 9, carry = 0.85, max = 40 },
	wing = { k = 55, c = 7, gain = 0.8, turnGain = 6, carry = 0.7, max = 30 },
	cape = { k = 30, c = 5.5, gain = 1.2, turnGain = 10, carry = 0.9, max = 45 },
	trunk = { k = 34, c = 6, gain = 1.0, turnGain = 8, carry = 0.85, max = 35 },
	fur = { k = 70, c = 8, gain = 0.6, turnGain = 4, carry = 0.6, max = 18 },
	crystal = { k = 140, c = 9, gain = 0.35, turnGain = 2, carry = 0.5, max = 8 },
	cloth = { k = 60, c = 7, gain = 0.9, turnGain = 5, carry = 0.7, max = 25 },
}
-- 폰 · 낮은 그래픽(GraphicsMode lite): 스프링을 이 배율로 갱신(0.5 = 절반 - 두 프레임에 한 번)
D.springLiteRate = 0.5

-- 빠짐 검사(BossClipSet.coverage): 동작 세트마다 꼭 있어야 하는 동작 이름. 스킬은 BossData 스킬표 전부(빠지면 실패).
D.requiredClips = { "idle", "walk", "intro", "death", "env", "flinch", "stun" }
D.requiredOnce = { "transform" } -- 세트 묶음(변신 전/후)에 한 번
-- 변신(겉모습 - 서버 무변경): 겉모습 격노 순간(BossMotionData.enrage.phaseAt) 뒤 진행 중인 스킬이 끝나면 변신 동작 1회(최대 대기 maxWait초 뒤엔 바로)
D.transform = { maxWait = 3.0 }

return D
