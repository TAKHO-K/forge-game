-- M2 몬스터 = 종(외형 · 행동 - 이 파일) × 티어(수치 - MonsterData.tierN: HP · 공격 · 보상 · 크기 그대로). 참조 = docs/art/ref/10 · 11(구역당 2종).
--   MonsterData.species[id] = 티어 data 복사 + 이 표의 이름 · 색 · 몸체(MonsterRigSpec) · 성향. 스폰 풀 = WorldMapData 구역 hunt.monsters({ species, weight }).
-- 성향 카드(서버 MonsterAI가 읽는다):
--   aggro = "aggressive"(선공 - detectRadius 안에 들어오면 쫓음) · "passive"(비선공 - 맞으면 반격) · "chase"(추적 - 넓은 detectRadius로 찾아옴 · 한 사람을 쫓는 추적형 동시 상한 = chaseCapPerPlayer)
--     · "ambush"(매복 - 아주 가까이 와야 깨어남 = 선공의 좁은 반경) · "pack"(무리 - 비선공 + 한 마리가 맞으면 같은 무리 전체 반격 = 링크 어그로).
--   detectRadius(stud) · alertMotion("turn" 돌아봄 · "mark" ! 표시 · "roar" 포효) · approach("charge" 돌진 · "sneak" 살금 · "hop" 통통 · "surround" 포위) · speed(이동 배율 - 기준 MonsterData.moveSpeedStuds 10)
--   groupSize = { 최소, 최대 }(한 스폰 지점 무리 - 지점마다 종 하나) · leashDistance(스폰 자리에서 이 거리 넘으면 복귀 + 체력 회복) · linkAggro(무리 반격).
--   안전 지대(허브 · 구역 캠프) 진입 금지는 전 종 공통(MonsterAI). T1 · T2 선공형(선공 + 추적 + 매복) 스폰 비율 ≤ 30%(검사 = M2Verify).
-- QUEUE-10h Q1: T6 눈토끼 → 푸른 드래곤(blue_dragon · 얼음 계열 · 옛 T6 드래곤 수치 = 티어 data 그대로). 눈토끼는 retiredBy로 스폰 풀에서만 빠진다(데이터 · 참조 이미지 유지).
--   드래곤 규칙(무리 1 ~ 2 · 링크 어그로 없음 · 스폰 간격 72 ≥ 감지 16 × 2 + 10)은 드래곤으로 돌아가고, 얼음 골렘은 일반 선공 무리(3 ~ 4)로 되돌린다(묶음 결정 B-1 해제).
--   chaseCapped = 선공이어도 추적 동시 상한(chaseCapPerPlayer)을 같이 센다 · alertHoldSeconds = 발견 뒤 제자리 포효 시간(경계 모션 - 그동안 안 움직임).
--   attacks = 모양 공격 조각(MonsterAI 공용 - shared/MobAttackShape): 전조(windup.seconds · poses) → 동작(모양 안 전원 판정 · damage = 평타 배율 · launch = 넉백만) → 회복(recover - 제자리).
--     고르는 법: 대상이 등 뒤(prefer = "behind")면 그 공격, 아니면 prefer 없는 공격을 차례로. 주기 = 전조 + 회복 + cooldown → damage는 주기 × 평타(초당 피해 ≈ 티어 평타)로 맞춘 값.
-- 평타 전조(windup): 서버가 전조 시간만큼 기다렸다 때린다(사거리 안에 남아 있으면) · 클라 MonsterRigAnimator가 관절 포즈로 보인다. 시범 3종(슬라임 · 멧돼지 · 골렘) → 묶음 F1에서 12종 전부(참조 이미지 전조 문구 기준 · 0.6 ~ 1.3초).
local MonsterSpeciesData = {}

local C = Color3.fromRGB

MonsterSpeciesData.species = {
	moss_slime = { tier = 1, displayName = "이끼 슬라임", body = C(120, 200, 95), head = C(150, 215, 125), accent = C(60, 135, 55),
		aggro = "passive", detectRadius = 0, alertMotion = "turn", approach = "hop", speed = 0.9, groupSize = { 3, 4 }, leashDistance = 38,
		windup = { seconds = 1.0, poses = { RootJoint = { y = -0.35 }, Neck = { y = 0.3 } } } },
	rock_boar = { tier = 1, displayName = "바위 멧돼지", body = C(140, 138, 132), head = C(165, 162, 155), accent = C(90, 150, 70),
		aggro = "aggressive", detectRadius = 12, alertMotion = "mark", approach = "charge", speed = 1.2, groupSize = { 2, 3 }, leashDistance = 42,
		windup = { seconds = 0.8, poses = { Neck = { rx = -22 }, Leg_BL = { rx = -25 }, Leg_BR = { rx = -25 } } } },
	crystal_beetle = { tier = 2, displayName = "수정 딱정벌레", body = C(110, 80, 180), head = C(140, 110, 200), accent = C(215, 150, 245),
		aggro = "passive", detectRadius = 0, alertMotion = "turn", approach = "sneak", speed = 0.8, groupSize = { 3, 5 }, leashDistance = 38,
		windup = { seconds = 1.0, poses = { Shell2 = { y = 0.4 }, Shell1 = { rz = 15 }, Shell3 = { rz = -15 } } } },
	amethyst_bat = { tier = 2, displayName = "자수정 박쥐", body = C(95, 70, 150), head = C(95, 70, 150), accent = C(200, 130, 240),
		aggro = "chase", detectRadius = 30, alertMotion = "mark", approach = "surround", speed = 1.1, groupSize = { 2, 3 }, leashDistance = 55,
		windup = { seconds = 0.7, poses = { Wing_L = { rz = 60 }, Wing_R = { rz = -60 }, RootJoint = { y = 0.6 } } } },
	hermit_knight = { tier = 3, displayName = "소라게 기사", body = C(235, 110, 90), head = C(235, 220, 190), accent = C(245, 130, 105),
		aggro = "passive", detectRadius = 0, alertMotion = "turn", approach = "sneak", speed = 0.85, groupSize = { 3, 4 }, leashDistance = 38,
		windup = { seconds = 0.9, poses = { Claw_R = { rx = 70, y = 0.6 } } } },
	bubble_jelly = { tier = 3, displayName = "물방울 해파리", body = C(110, 215, 230), head = C(170, 235, 245), accent = C(70, 170, 195),
		aggro = "chase", detectRadius = 28, alertMotion = "mark", approach = "surround", speed = 0.9, groupSize = { 2, 4 }, leashDistance = 55,
		windup = { seconds = 1.0, poses = { RootJoint = { y = -0.3 }, Tentacle1 = { rx = -25 }, Tentacle2 = { rx = -25 }, Tentacle3 = { rx = 25 }, Tentacle4 = { rx = 25 } } } },
	sand_scorpion = { tier = 4, displayName = "모래 전갈", body = C(215, 150, 70), head = C(230, 175, 95), accent = C(170, 60, 50),
		aggro = "aggressive", detectRadius = 10, alertMotion = "roar", approach = "charge", speed = 1.25, groupSize = { 3, 4 }, leashDistance = 42,
		windup = { seconds = 0.8, poses = { Tail1 = { rx = -25 }, Tail2 = { rx = -20 } } } },
	cactus_imp = { tier = 4, displayName = "선인장 꼬마", body = C(70, 150, 70), head = C(90, 170, 85), accent = C(245, 150, 190),
		aggro = "ambush", detectRadius = 6, alertMotion = "mark", approach = "hop", speed = 1.0, groupSize = { 3, 5 }, leashDistance = 38,
		windup = { seconds = 0.8, poses = { Arm_L = { rz = 140 }, Arm_R = { rz = -140 } } } },
	bolt_imp = { tier = 5, displayName = "번개 임프", body = C(90, 60, 150), head = C(110, 80, 170), accent = C(120, 230, 255),
		aggro = "chase", detectRadius = 30, alertMotion = "roar", approach = "surround", speed = 1.15, groupSize = { 3, 4 }, leashDistance = 55,
		windup = { seconds = 0.8, poses = { Arm_L = { rx = 160 }, Arm_R = { rx = 160 } } } },
	cloud_sheep = { tier = 5, displayName = "구름 양", body = C(240, 242, 248), head = C(95, 100, 115), accent = C(250, 220, 90),
		aggro = "passive", detectRadius = 0, alertMotion = "turn", approach = "hop", speed = 0.9, groupSize = { 3, 5 }, leashDistance = 38,
		windup = { seconds = 1.0, poses = { RootJoint = { y = 0.2 }, Wool = { y = 0.4 } } } },
	ice_golem = { tier = 6, displayName = "얼음 골렘", body = C(170, 215, 245), head = C(200, 230, 250), accent = C(80, 155, 215),
		aggro = "aggressive", detectRadius = 14, alertMotion = "roar", approach = "charge", speed = 0.8, groupSize = { 3, 4 }, leashDistance = 45, -- Q1: 드래곤 규칙 해제(1 ~ 2 → 3 ~ 4)
		windup = { seconds = 1.3, poses = { Arm_L = { rx = 150 }, Arm_R = { rx = 150 }, RootJoint = { rx = -8 } } } },
	snow_rabbit = { tier = 6, displayName = "눈토끼", retiredBy = "blue_dragon", -- Q1: retired → 푸른 드래곤으로 교체(스폰 풀에서만 빠짐) body = C(245, 247, 252), head = C(250, 250, 255), accent = C(245, 180, 195),
		aggro = "pack", detectRadius = 0, alertMotion = "turn", approach = "hop", speed = 1.3, groupSize = { 4, 5 }, leashDistance = 45, linkAggro = true,
		windup = { seconds = 0.6, poses = { Ear_L = { rx = -45 }, Ear_R = { rx = -45 }, RootJoint = { y = -0.15 } } } },
	-- Q1 푸른 드래곤(T6 · 가장 위험한 잡몹 · 무리 1 ~ 2): 얼음 청색 본체 + 밝은 하늘색 배(head 색 = 배 · 턱) + 얼음 결정 강조(accent)
	blue_dragon = { tier = 6, displayName = "푸른 드래곤", body = C(70, 130, 205), head = C(175, 225, 250), accent = C(200, 240, 255),
		aggro = "aggressive", detectRadius = 16, alertMotion = "roar", alertHoldSeconds = 0.8, approach = "charge", speed = 0.85, groupSize = { 1, 2 }, leashDistance = 50, linkAggro = false,
		chaseCapped = true, attackRange = 12, chaseStop = 7,
		alertPose = { poses = { Neck1 = { rx = 20 }, Neck = { rx = 15 }, Jaw = { rx = -30 }, Wing_L = { rz = -25 }, Wing_R = { rz = 25 } } }, -- 포효(경계 - alertHoldSeconds 동안 · 클라 MonsterRigAnimator)
		hitbox = { size = Vector3.new(3.4, 5.0, 6.4), center = Vector3.new(0, 1.6, -0.8) }, -- 몸 단위(× sizeScale) - 몸통 + 목 + 머리(날개 · 꼬리 끝 제외)
		attacks = {
			{ id = "frostBreath", shape = "cone", range = 14, halfAngle = 35, damage = 2.2, recover = 0.6, cooldown = 0.8,
				windup = { seconds = 0.8, poses = { Neck1 = { rx = 25 }, Neck = { rx = 10 }, Jaw = { rx = -35 } } } }, -- 목 뒤로 젖힘 + 입 벌림 + 바닥 서리 궤적(클라)
			{ id = "tailSweep", shape = "rearArc", range = 12, prefer = "behind", damage = 1.9, recover = 0.5, cooldown = 0.8,
				windup = { seconds = 0.6, poses = { Tail1 = { rx = -35 }, Tail2 = { rx = -20 }, Tail3 = { rx = -15 } } } }, -- 꼬리 들어 올림
			{ id = "wingGust", shape = "circle", range = 10, damage = 1.0, recover = 0.6, cooldown = 0.8,
				launch = { heightStuds = 2, distanceStuds = 16 }, -- 넉백만(낮게 · 멀리 - 낙하는 FallServer 규칙 그대로)
				windup = { seconds = 0.7, poses = { Wing_L = { rz = -55 }, Wing_R = { rz = 55 }, RootJoint = { y = 0.3 } } } }, -- 날개 펼침
		} },
}

-- 옛 종(티어 대표 이름 - 22-2). 스폰 풀에서 빠졌다(retired - 데이터 · 이름은 티어 표에 남는다: MonsterData.tierN.retiredName).
MonsterSpeciesData.retired = { tier1 = "슬라임", tier2 = "고블린", tier3 = "오크", tier4 = "트롤", tier5 = "골렘", tier6 = "드래곤" }

-- 한 사람을 동시에 쫓는 추적형(aggro = "chase") 상한 · 안전 지대 여유(허브 safeRadius · 캠프 반경에 더하는 stud)
MonsterSpeciesData.chaseCapPerPlayer = 3
MonsterSpeciesData.safeZoneMarginStuds = 10
-- 선공형으로 세는 성향(T1 · T2 비율 검사)
MonsterSpeciesData.hostileAggro = { aggressive = true, chase = true, ambush = true }

return MonsterSpeciesData
