-- M2 몬스터 = 종(외형 · 행동 - 이 파일) × 티어(수치 - MonsterData.tierN: HP · 공격 · 보상 · 크기 그대로). 참조 = docs/art/ref/10 · 11(구역당 2종).
--   MonsterData.species[id] = 티어 data 복사 + 이 표의 이름 · 색 · 몸체(MonsterRigSpec) · 성향. 스폰 풀 = WorldMapData 구역 hunt.monsters({ species, weight }).
-- 성향 카드(서버 MonsterAI가 읽는다):
--   aggro = "aggressive"(선공 - detectRadius 안에 들어오면 쫓음) · "passive"(비선공 - 맞으면 반격) · "chase"(추적 - 넓은 detectRadius로 찾아옴 · 한 사람을 쫓는 추적형 동시 상한 = chaseCapPerPlayer)
--     · "ambush"(매복 - 아주 가까이 와야 깨어남 = 선공의 좁은 반경) · "pack"(무리 - 비선공 + 한 마리가 맞으면 같은 무리 전체 반격 = 링크 어그로).
--   detectRadius(stud) · alertMotion("turn" 돌아봄 · "mark" ! 표시 · "roar" 포효) · approach("charge" 돌진 · "sneak" 살금 · "hop" 통통 · "surround" 포위) · speed(이동 배율 - 기준 MonsterData.moveSpeedStuds 10)
--   groupSize = { 최소, 최대 }(한 스폰 지점 무리 - 지점마다 종 하나) · leashDistance(스폰 자리에서 이 거리 넘으면 복귀 + 체력 회복) · linkAggro(무리 반격).
--   안전 지대(허브 · 구역 캠프) 진입 금지는 전 종 공통(MonsterAI). T1 · T2 선공형(선공 + 추적 + 매복) 스폰 비율 ≤ 30%(검사 = M2Verify).
-- 드래곤(옛 T6)은 참조 이미지에 없어 retired - 지시의 드래곤 규칙(무리 1 ~ 2 · 링크 어그로 없음 · 스폰 간격 ≥ 감지 ×2 + 여유)은 T6 선공 대형종 얼음 골렘에 적용(묶음 결정 B-1).
-- 평타 전조(windup): 서버가 전조 시간만큼 기다렸다 때린다(사거리 안에 남아 있으면) · 클라 MonsterRigAnimator가 관절 포즈로 보인다. 시범 3종(슬라임 · 멧돼지 · 골렘) - 나머지는 nil(옛 즉시 평타).
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
		aggro = "passive", detectRadius = 0, alertMotion = "turn", approach = "sneak", speed = 0.8, groupSize = { 3, 5 }, leashDistance = 38 },
	amethyst_bat = { tier = 2, displayName = "자수정 박쥐", body = C(95, 70, 150), head = C(95, 70, 150), accent = C(200, 130, 240),
		aggro = "chase", detectRadius = 30, alertMotion = "mark", approach = "surround", speed = 1.1, groupSize = { 2, 3 }, leashDistance = 55 },
	hermit_knight = { tier = 3, displayName = "소라게 기사", body = C(235, 110, 90), head = C(235, 220, 190), accent = C(245, 130, 105),
		aggro = "passive", detectRadius = 0, alertMotion = "turn", approach = "sneak", speed = 0.85, groupSize = { 3, 4 }, leashDistance = 38 },
	bubble_jelly = { tier = 3, displayName = "물방울 해파리", body = C(110, 215, 230), head = C(170, 235, 245), accent = C(70, 170, 195),
		aggro = "chase", detectRadius = 28, alertMotion = "mark", approach = "surround", speed = 0.9, groupSize = { 2, 4 }, leashDistance = 55 },
	sand_scorpion = { tier = 4, displayName = "모래 전갈", body = C(215, 150, 70), head = C(230, 175, 95), accent = C(170, 60, 50),
		aggro = "aggressive", detectRadius = 10, alertMotion = "roar", approach = "charge", speed = 1.25, groupSize = { 3, 4 }, leashDistance = 42 },
	cactus_imp = { tier = 4, displayName = "선인장 꼬마", body = C(70, 150, 70), head = C(90, 170, 85), accent = C(245, 150, 190),
		aggro = "ambush", detectRadius = 6, alertMotion = "mark", approach = "hop", speed = 1.0, groupSize = { 3, 5 }, leashDistance = 38 },
	bolt_imp = { tier = 5, displayName = "번개 임프", body = C(90, 60, 150), head = C(110, 80, 170), accent = C(120, 230, 255),
		aggro = "chase", detectRadius = 30, alertMotion = "roar", approach = "surround", speed = 1.15, groupSize = { 3, 4 }, leashDistance = 55 },
	cloud_sheep = { tier = 5, displayName = "구름 양", body = C(240, 242, 248), head = C(95, 100, 115), accent = C(250, 220, 90),
		aggro = "passive", detectRadius = 0, alertMotion = "turn", approach = "hop", speed = 0.9, groupSize = { 3, 5 }, leashDistance = 38 },
	ice_golem = { tier = 6, displayName = "얼음 골렘", body = C(170, 215, 245), head = C(200, 230, 250), accent = C(80, 155, 215),
		aggro = "aggressive", detectRadius = 14, alertMotion = "roar", approach = "charge", speed = 0.8, groupSize = { 1, 2 }, leashDistance = 45, linkAggro = false,
		windup = { seconds = 1.3, poses = { Arm_L = { rx = 150 }, Arm_R = { rx = 150 }, RootJoint = { rx = -8 } } } },
	snow_rabbit = { tier = 6, displayName = "눈토끼", body = C(245, 247, 252), head = C(250, 250, 255), accent = C(245, 180, 195),
		aggro = "pack", detectRadius = 0, alertMotion = "turn", approach = "hop", speed = 1.3, groupSize = { 4, 5 }, leashDistance = 45, linkAggro = true },
}

-- 옛 종(티어 대표 이름 - 22-2). 스폰 풀에서 빠졌다(retired - 데이터 · 이름은 티어 표에 남는다: MonsterData.tierN.retiredName).
MonsterSpeciesData.retired = { tier1 = "슬라임", tier2 = "고블린", tier3 = "오크", tier4 = "트롤", tier5 = "골렘", tier6 = "드래곤" }

-- 한 사람을 동시에 쫓는 추적형(aggro = "chase") 상한 · 안전 지대 여유(허브 safeRadius · 캠프 반경에 더하는 stud)
MonsterSpeciesData.chaseCapPerPlayer = 3
MonsterSpeciesData.safeZoneMarginStuds = 10
-- 선공형으로 세는 성향(T1 · T2 비율 검사)
MonsterSpeciesData.hostileAggro = { aggressive = true, chase = true, ambush = true }

return MonsterSpeciesData
