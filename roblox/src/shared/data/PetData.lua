-- QUEUE-10h Q11 펫 최소판(비전투 동행 - 나중에 탑승). 규칙 = shared/Pet.lua · 서버 = server/PetService.lua · 모습 = client/PetView.client.lua.
--   알 = EggData(구역 색 6 × 등급 3 · 후보 2종 50:50 - M1-3 그대로). 알은 무료 획득만(둥지 · 퀘스트 · 출석) - 유료 랜덤 없음.
--   부화: 알 창에서 [부화] → hatchSeconds 뒤 [받기] = 종(후보 50:50) · 등급(EggData.hatch + 부화 레벨 보정). 확률 공개 = Pet.hatchTable 한 곳.
--   부화 레벨: 부화 누적 횟수(hatchCount)로 오른다 → 일반 몫 일부가 위 등급으로(levels · shiftSplit).
--   해금(캐릭터 레벨): 자동 줍기 200(이번에 구현) · 부화 대기열 +1 300 · 둥지 약한 힌트 400 · 보관함 · 합성 추천 500(데이터 자리).
--   부화장 NPC = 허브 커뮤니티센터 자리(외형 · 배치는 H1 - 지금은 알 창에서 부화).
return {
	enabled = true,
	hatchSeconds = { normal = 60, good = 180, rare = 600 }, -- 알 등급별 부화 시간(초)
	queueBase = 1, -- 동시에 부화하는 알 수(해금 hatchQueuePlus = +1)
	petCap = 60, -- 펫 보관 상한(넘으면 부화 받기 거절 - 알은 대기열에 남는다)
	-- 부화 레벨: hatches = 그 레벨이 되는 누적 부화 수 · shift = 일반(common)에서 빼서 위 등급으로 옮기는 %p
	levels = {
		{ hatches = 0, shift = 0 },
		{ hatches = 3, shift = 3 },
		{ hatches = 10, shift = 6 },
		{ hatches = 25, shift = 9 },
		{ hatches = 50, shift = 12 },
	},
	shiftSplit = { uncommon = 0.6, rare = 0.3, epic = 0.1 }, -- 옮긴 몫의 나눔(합 1)
	unlocks = { autoPickup = 30, -- QUEUE-ALL6 A1(사용자 결정): 기준 = 계정 역대 최고 레벨(peakLevel - 환생해도 유지 · PetService) · QUEUE-STUDIO 0-3 · 200은 환생 5회 뒤라 캐주얼 19.5h → 30(EconSim 캐주얼 첫 도달 1.85h ≤ 3h)
		hatchQueuePlus = 300, nestHint = 400, storage = 500 },
	autoPickupRange = 14, -- 자동 줍기 반경(stud · 수평) - 줍기 자체는 ItemDropServer 한 곳(칸 확인 + 바닥 제거)
	autoPickupHeight = 8,
	hatchery = { zone = "hub", place = "communityCenter", placeholder = true }, -- NPC 자리(H1 배치 뒤)
	-- 몸 틀(3) - 종마다 하나. 크기 = 캐릭터 머리 정도(키 약 1.3 stud) · 파트 ≤ 8(몬스터 리깅 규칙과 같은 이름 규칙)
	bodyOf = {
		stoneTurtle = "dog", mossHare = "cat", pebbleMole = "dog", ruinOwl = "dragon",
		crystalBat = "dragon", prismLizard = "dog", gleamSnail = "cat", quartzFox = "cat",
		reefOtter = "dog", shellCrab = "cat", tideFrog = "dog", lotusFish = "dragon",
		duneFennec = "cat", cactusHedgehog = "dog", scarabBeetle = "cat", sunGecko = "dragon",
		sparkFerret = "cat", cloudSheep = "dog", thunderHawk = "dragon", galeSquirrel = "cat",
		frostPenguin = "dog", snowOwl = "dragon", iceSeal = "dog", auroraFox = "cat",
	},
	bodyNames = { dog = "강아지", cat = "고양이", dragon = "새끼 용" },
	-- 따라다니기(클라 보간 - 서버는 Attribute만): 주인 뒤 옆 offset · 따라붙는 속도(초당 비율) · 날기 높이
	follow = { offset = Vector3.new(2.6, 0, 2.4), lerpPerSecond = 6, flyHeight = 2.4, bobStuds = 0.25, bobSeconds = 1.6, teleportStuds = 40 },
	-- 리그(파트 이름 · 크기 · 위치 = 몸 중심 기준 stud). 색: base = 구역 색 · accent = 어둡게(EggData.look.patternDarken) · eye = 검정
	rigs = {
		dog = {
			{ name = "Body", size = Vector3.new(0.7, 0.55, 1.0), pos = Vector3.new(0, 0, 0), color = "base" },
			{ name = "Head", size = Vector3.new(0.6, 0.55, 0.55), pos = Vector3.new(0, 0.4, -0.6), color = "base" },
			{ name = "Ear_L", size = Vector3.new(0.14, 0.3, 0.2), pos = Vector3.new(-0.26, 0.62, -0.55), color = "accent" },
			{ name = "Ear_R", size = Vector3.new(0.14, 0.3, 0.2), pos = Vector3.new(0.26, 0.62, -0.55), color = "accent" },
			{ name = "Leg_F", size = Vector3.new(0.6, 0.3, 0.2), pos = Vector3.new(0, -0.4, -0.3), color = "accent" },
			{ name = "Leg_B", size = Vector3.new(0.6, 0.3, 0.2), pos = Vector3.new(0, -0.4, 0.3), color = "accent" },
			{ name = "Tail", size = Vector3.new(0.14, 0.14, 0.4), pos = Vector3.new(0, 0.2, 0.62), color = "accent" },
			{ name = "Eyes", size = Vector3.new(0.4, 0.1, 0.05), pos = Vector3.new(0, 0.48, -0.88), color = "eye" },
		},
		cat = {
			{ name = "Body", size = Vector3.new(0.6, 0.5, 1.0), pos = Vector3.new(0, 0, 0), color = "base" },
			{ name = "Head", size = Vector3.new(0.6, 0.5, 0.5), pos = Vector3.new(0, 0.42, -0.58), color = "base" },
			{ name = "Ear_L", size = Vector3.new(0.18, 0.24, 0.1), pos = Vector3.new(-0.2, 0.78, -0.58), color = "accent", wedge = true },
			{ name = "Ear_R", size = Vector3.new(0.18, 0.24, 0.1), pos = Vector3.new(0.2, 0.78, -0.58), color = "accent", wedge = true },
			{ name = "Leg_F", size = Vector3.new(0.5, 0.3, 0.18), pos = Vector3.new(0, -0.38, -0.3), color = "accent" },
			{ name = "Leg_B", size = Vector3.new(0.5, 0.3, 0.18), pos = Vector3.new(0, -0.38, 0.3), color = "accent" },
			{ name = "Tail", size = Vector3.new(0.12, 0.7, 0.12), pos = Vector3.new(0, 0.35, 0.6), color = "accent" },
			{ name = "Eyes", size = Vector3.new(0.38, 0.1, 0.05), pos = Vector3.new(0, 0.48, -0.84), color = "eye" },
		},
		dragon = {
			{ name = "Body", size = Vector3.new(0.6, 0.55, 0.9), pos = Vector3.new(0, 0, 0), color = "base" },
			{ name = "Head", size = Vector3.new(0.55, 0.5, 0.6), pos = Vector3.new(0, 0.4, -0.6), color = "base" },
			{ name = "Horn", size = Vector3.new(0.4, 0.2, 0.1), pos = Vector3.new(0, 0.72, -0.5), color = "accent" },
			{ name = "Wing_L", size = Vector3.new(0.9, 0.06, 0.5), pos = Vector3.new(-0.7, 0.3, 0), color = "accent" },
			{ name = "Wing_R", size = Vector3.new(0.9, 0.06, 0.5), pos = Vector3.new(0.7, 0.3, 0), color = "accent" },
			{ name = "Tail", size = Vector3.new(0.16, 0.16, 0.7), pos = Vector3.new(0, 0, 0.75), color = "accent" },
			{ name = "Eyes", size = Vector3.new(0.36, 0.1, 0.05), pos = Vector3.new(0, 0.48, -0.91), color = "eye" },
		},
	},
	flyingBodies = { dragon = true },
}
