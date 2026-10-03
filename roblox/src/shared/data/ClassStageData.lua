-- QUEUE-ALL9C 2-4 직업 선택 무대 = 전용 캐릭터(client/StageMascot)의 변신 애니메이션(client/ClassStage) 값. 업로드 없는 클라 관절 키프레임 · 서버 영향 없음.
--   타이밍(사용자 10-03 확정): 0.0 ~ 0.4 대기 → 연기 펑 / 0.4 ~ 1.4 방어구 v3 조각(부위 묶음마다 0.1초 간격 · 붙을 때 작은 반짝 + 몸 흔들림) /
--   1.4 ~ 1.9 무기가 위에서 떨어져 받음 / 1.9 ~ 2.6 직업별 웃긴 한 박자 / 2.6 ~ 3.0 포즈 + 직업 이름.
--   "애니메이션처럼": 키마다 이징(backOut = 살짝 넘쳤다 돌아옴) · 동작 앞 예비 동작(웅크림 · 고개 들기) · 착지 찌그러짐(squash +) · 머리 · 망토 = 스프링으로 늦게 따라옴.
--   포즈 = 관절(도 { x, y, z }): 어깨 · 엉덩이 = 방향(x = 드는 각 0 아래 · 90 앞 · 180 위 · y = 비틀기 · z = 벌림 - 오른쪽 +z / 왼쪽 −z = 바깥) ·
--     그 밖 = 회전(팔꿈치 +x = 굽힘 · 무릎 −x = 굽힘 · 허리 −x = 앞으로 숙임 · 목 +x = 고개 들기).
--   root = { y = 위아래(stud) · rz = 좌우 기울기(도) · rx = 앞뒤 기울기(도) } · squash = 찌그러짐(+) / 늘어남(−).
local C = Color3.fromRGB
return {
	mascot = {
		colors = { skin = C(255, 214, 170), shirt = C(86, 140, 220), pants = C(60, 66, 92), shoes = C(70, 50, 40) }, -- 게임 팔레트(밝은 하늘 파랑 · 남색)
		face = "rbxasset://textures/face.png", -- 기본 웃는 얼굴(업로드 없음)
		cape = { size = Vector3.new(1.7, 2.3, 0.08), restAngle = 0.12 },
		eyes = { x = { -0.2, 0.2 }, y = 0.16, z = -0.6, size = Vector3.new(0.22, 0.2, 0.04) }, -- 눈꺼풀 자리(머리 기준 - 기본 얼굴 눈)
		spring = { stiffness = 120, damping = 11, drive = 0.05, capeStiffness = 60, capeDamping = 6, capeDrive = 0.09 }, -- 머리 · 망토 따라오기
	},
	armorLook = "normal", armorZone = "tier1", armorGrade = "normal", -- 방어구 v3 외형 · 세트 색(기본)
	capeColors = { greatsword = C(196, 60, 52), healer = C(240, 236, 222) }, -- 망토 있는 직업만(없으면 망토 없음 - 도적 · 궁수는 후드 · 두건이 방어구에 있음)
	stage = {
		background = { top = C(150, 200, 245), bottom = C(232, 240, 250) },
		floor = { color = C(122, 186, 96), size = Vector3.new(9, 0.4, 9) },
		camera = { position = Vector3.new(0, 1.7, -16), lookAt = Vector3.new(0, 0.4, 0), fov = 40 }, -- 팔 · 무기를 위로 들어도 안 잘리게
		light = { ambient = C(170, 170, 185), color = C(255, 248, 235), direction = Vector3.new(-0.5, -1, 0.6) },
		particleMax = 14, particleMaxLite = 7, -- 연기 · 반짝 · 꽃 동시 개수 상한(폰 성능 - 가벼움 = 절반)
		holdSeconds = 1.2, -- 끝난 뒤 포즈 유지(그 다음 = 대기 숨쉬기 반복)
	},
	times = { smoke = 0.4, armorStart = 0.45, armorGap = 0.1, armorFly = 0.32, weaponDrop = 1.4, weaponCatch = 1.75, beat = 1.9, pose = 2.6, nameAt = 2.7, done = 3.0 },
	armorSlots = { -- 조각 묶음(붙는 몸 파트) · 칸마다 0.1초 간격(7칸 = 0.45 ~ 1.05 출발 → 1.37에 다 붙음) · 목록에 없는 파트 = 마지막 칸
		{ "LeftFoot", "RightFoot" }, { "LeftLowerLeg", "RightLowerLeg" }, { "LeftUpperLeg", "RightUpperLeg", "LowerTorso" }, { "UpperTorso", "Head" },
		{ "LeftUpperArm", "RightUpperArm" }, { "LeftLowerArm", "RightLowerArm" }, { "LeftHand", "RightHand" },
	},
	armorFlyFrom = { distance = 6, up = 4 }, -- 조각 출발 자리(몸에서 · 바깥 위)
	attachJiggle = 3.5, -- 조각이 붙을 때 몸 흔들림(도 · 감쇠 진동) - 붙은 부위 쪽으로 살짝 밀렸다 돌아옴
	overshoot = 0.14, overshootAt = 0.28, -- backOut 키 = 목표를 14% 지나친 자리를 키 간격 28% 앞에 넣는다(넘침 → 제자리)
	-- 부위별 시간차(초): 골반 · 다리가 먼저 · 허리 → 어깨 → 팔꿈치 → 손목 · 머리 순으로 늦게 따라온다(무게 이동 · 겹치는 동작)
	lag = { Waist = 0.03, RightShoulder = 0.05, LeftShoulder = 0.06, RightElbow = 0.09, LeftElbow = 0.1, RightWrist = 0.11, LeftWrist = 0.12, Neck = 0.08 },
	breath = { speed = 2.6, rise = 0.035, sway = 0.6, joints = { Waist = { 1.2, 0, 0 }, RightShoulder = { 0, 0, 1.5 }, LeftShoulder = { 0, 0, -1.5 } } }, -- 늘 깔리는 숨쉬기 · 무게중심
	blink = { times = { 0.12, 1.32, 2.48 }, every = 2.7, seconds = 0.11 }, -- 눈 깜빡임(3초 안 3번 · 그 뒤 반복)
	gaze = { maxYaw = 35, maxPitch = 25, weight = 0.8 }, -- 날아오는 조각 · 떨어지는 무기를 고개로 따라봄(도)
	dolly = 0.07, -- 카메라가 3초 동안 7% 다가감
	shadow = { color = C(40, 60, 40), size = 3.2, transparency = 0.55 }, -- 발밑 그림자(뛰면 작고 옅게)
	landings = { 0.55, 1.75, 2.92 }, -- 착지 · 무기 받기 · 포즈 착지 = 먼지 + 무릎 굽힘(포즈 키)
	weaponDropHeight = 8,
	poses = {
		idle = { j = { RightShoulder = { 0, 0, 6 }, LeftShoulder = { 0, 0, -6 }, RightElbow = { 12, 0, 0 }, LeftElbow = { 12, 0, 0 } } },
		crouch = { root = { y = -0.32 }, squash = 0.12, j = { Waist = { -14, 0, 0 }, RightHip = { 28, 0, 0 }, LeftHip = { 28, 0, 0 }, RightKnee = { -48, 0, 0 }, LeftKnee = { -48, 0, 0 }, RightAnkle = { 18, 0, 0 }, LeftAnkle = { 18, 0, 0 }, RightShoulder = { -25, 0, 10 }, LeftShoulder = { -25, 0, -10 }, RightElbow = { 20, 0, 0 }, LeftElbow = { 20, 0, 0 } } },
		poof = { root = { y = 0.45 }, squash = -0.1, j = { RightShoulder = { 165, 0, 18 }, LeftShoulder = { 165, 0, -18 }, Neck = { 12, 0, 0 } } },
		land = { root = { y = -0.12 }, squash = 0.14, j = { RightHip = { 14, 0, 0 }, LeftHip = { 14, 0, 0 }, RightKnee = { -26, 0, 0 }, LeftKnee = { -26, 0, 0 }, RightAnkle = { 12, 0, 0 }, LeftAnkle = { 12, 0, 0 }, RightShoulder = { 20, 0, 25 }, LeftShoulder = { 20, 0, -25 } } },
		armsOut = { j = { RightShoulder = { 10, 0, 32 }, LeftShoulder = { 10, 0, -32 }, RightElbow = { 10, 0, 0 }, LeftElbow = { 10, 0, 0 }, Neck = { -6, 0, 0 } } }, -- 조각을 받는 자세(팔 살짝 벌림)
		lookUp = { root = { y = -0.1 }, squash = 0.05, j = { Neck = { 28, 0, 0 }, Waist = { 8, 0, 0 }, RightShoulder = { -10, 0, 12 }, LeftShoulder = { -10, 0, -12 }, RightKnee = { -14, 0, 0 }, LeftKnee = { -14, 0, 0 }, RightHip = { 7, 0, 0 }, LeftHip = { 7, 0, 0 } } },
		reach = { root = { y = 0.12 }, squash = -0.06, j = { Neck = { 22, 0, 0 }, Waist = { 6, 0, 0 }, RightShoulder = { 160, 0, 10 }, LeftShoulder = { 160, 0, -10 }, RightElbow = { 10, 0, 0 }, LeftElbow = { 10, 0, 0 } } },
		catch = { root = { y = -0.22 }, squash = 0.15, j = { RightHip = { 18, 0, 0 }, LeftHip = { 18, 0, 0 }, RightKnee = { -34, 0, 0 }, LeftKnee = { -34, 0, 0 }, RightAnkle = { 14, 0, 0 }, LeftAnkle = { 14, 0, 0 } } },
	},
	-- 무기를 쥔 자세(직업) · 끝 포즈(직업) - 받은 뒤 · 한 박자 뒤
	hold = {
		greatsword = { j = { RightShoulder = { 38, 0, 12 }, RightElbow = { 62, 0, 0 }, LeftShoulder = { 42, 0, -6 }, LeftElbow = { 70, 0, 0 } } },
		dualblade = { j = { RightShoulder = { 30, 0, 22 }, RightElbow = { 55, 0, 0 }, LeftShoulder = { 30, 0, -22 }, LeftElbow = { 55, 0, 0 } } },
		bow = { j = { LeftShoulder = { 55, 0, -12 }, LeftElbow = { 20, 0, 0 }, RightShoulder = { 20, 0, 10 }, RightElbow = { 45, 0, 0 } } },
		healer = { j = { RightShoulder = { 25, 0, 14 }, RightElbow = { 70, 0, 0 }, LeftShoulder = { 0, 0, -8 }, LeftElbow = { 15, 0, 0 } } },
	},
	finale = {
		greatsword = { j = { RightShoulder = { 138, 0, 8 }, RightElbow = { 4, 0, 0 }, LeftShoulder = { 20, 0, -30 }, LeftElbow = { 30, 0, 0 }, Neck = { 6, 0, 0 }, Waist = { 4, 0, 0 } } }, -- 칼끝 = 팔 각 + 팔꿈치 각(90 = 위) → 140 = 위 · 뒤로 비스듬히 치켜듦
		dualblade = { j = { RightShoulder = { 95, 0, -38 }, RightElbow = { 30, 0, 0 }, LeftShoulder = { 95, 0, 38 }, LeftElbow = { 30, 0, 0 }, Neck = { 4, 0, 0 } } },
		bow = { j = { LeftShoulder = { 92, 0, -18 }, LeftElbow = { 0, 0, 0 }, RightShoulder = { 88, 0, -30 }, RightElbow = { 115, 0, 0 }, Neck = { 0, 18, 0 }, Waist = { 0, 12, 0 } } }, -- 활을 세워 겨누는 자세(왼팔 앞 · 오른손 시위 당김 · 몸 살짝 돌림)
		healer = { j = { RightShoulder = { 128, 0, 10 }, RightElbow = { 6, 0, 0 }, RightWrist = { -36, 0, 0 }, LeftShoulder = { 35, 0, -42 }, LeftElbow = { 25, 0, 0 }, Neck = { 8, 0, 0 } } }, -- 지팡이 머리 = 위 · 살짝 뒤
	},
	-- 직업별 웃긴 한 박자(1.9 ~ 2.6) = 키 목록(t = 박자 시작부터 초 · pose = 위 poses 이름 | "hold" | 표 · ease) + 소품(client/ClassStage BEAT_PROPS)
	beats = {
		heavy = { -- 검사: 너무 무거워 휘청 - 칼끝이 땅으로 끌려가며 앞으로 기우뚱 → 좌우로 휘청 → 버팀
			{ t = 0.0, pose = "hold", ease = "inOut" },
			{ t = 0.12, pose = { root = { y = -0.2, rx = 8 }, squash = 0.08, j = { RightShoulder = { 15, 0, 8 }, RightElbow = { 15, 0, 0 }, LeftShoulder = { 18, 0, -4 }, LeftElbow = { 20, 0, 0 }, Waist = { -22, 0, 0 }, Neck = { 10, 0, 0 } } }, ease = "in" },
			{ t = 0.28, pose = { root = { y = -0.25, rz = 12, rx = 6 }, squash = 0.1, j = { RightShoulder = { 12, 0, 6 }, RightElbow = { 10, 0, 0 }, LeftShoulder = { 15, 0, -28 }, Waist = { -18, 0, 8 }, RightKnee = { -20, 0, 0 }, LeftKnee = { -30, 0, 0 } } }, ease = "out" },
			{ t = 0.44, pose = { root = { y = -0.18, rz = -9, rx = 4 }, squash = 0.06, j = { RightShoulder = { 14, 0, 8 }, RightElbow = { 14, 0, 0 }, LeftShoulder = { 20, 0, -10 }, Waist = { -14, 0, -6 }, RightKnee = { -28, 0, 0 }, LeftKnee = { -16, 0, 0 } } }, ease = "inOut" },
			{ t = 0.58, pose = { root = { y = -0.1, rz = 4 }, squash = 0.03, j = { RightShoulder = { 25, 0, 10 }, RightElbow = { 40, 0, 0 }, LeftShoulder = { 30, 0, -6 }, LeftElbow = { 50, 0, 0 }, Waist = { -6, 0, 0 } } }, ease = "inOut" },
			{ t = 0.7, pose = "hold", ease = "backOut" },
		},
		juggle = { -- 도적: 단검 둘을 머리 위로 번갈아 던져 저글링 → 잡음
			{ t = 0.0, pose = "hold", ease = "inOut" },
			{ t = 0.08, pose = { root = { y = -0.12 }, squash = 0.06, j = { RightShoulder = { 20, 0, 20 }, LeftShoulder = { 20, 0, -20 }, RightElbow = { 70, 0, 0 }, LeftElbow = { 70, 0, 0 }, Neck = { 20, 0, 0 } } }, ease = "in" },
			{ t = 0.18, pose = { j = { RightShoulder = { 130, 0, 18 }, LeftShoulder = { 60, 0, -18 }, RightElbow = { 20, 0, 0 }, LeftElbow = { 60, 0, 0 }, Neck = { 26, 0, 0 } } }, ease = "out" },
			{ t = 0.3, pose = { j = { RightShoulder = { 60, 0, 18 }, LeftShoulder = { 130, 0, -18 }, RightElbow = { 60, 0, 0 }, LeftElbow = { 20, 0, 0 }, Neck = { 26, 0, 0 } } }, ease = "inOut" },
			{ t = 0.42, pose = { j = { RightShoulder = { 130, 0, 18 }, LeftShoulder = { 60, 0, -18 }, RightElbow = { 20, 0, 0 }, LeftElbow = { 60, 0, 0 }, Neck = { 26, 0, 0 } } }, ease = "inOut" },
			{ t = 0.54, pose = { root = { y = -0.18 }, squash = 0.12, j = { RightShoulder = { 40, 0, 22 }, LeftShoulder = { 40, 0, -22 }, RightElbow = { 50, 0, 0 }, LeftElbow = { 50, 0, 0 }, Neck = { 4, 0, 0 } } }, ease = "in" },
			{ t = 0.7, pose = "hold", ease = "backOut" },
		},
		apple = { -- 궁수: 머리 위 사과에 화살이 톡 꽂힘(몸에는 아무것도 안 닿음) → 깜짝 움찔 → 안도
			{ t = 0.0, pose = "hold", ease = "inOut" },
			{ t = 0.22, pose = "hold", ease = "inOut" },
			{ t = 0.3, pose = { root = { y = 0.25 }, squash = -0.12, j = { RightShoulder = { 20, 0, 40 }, LeftShoulder = { 50, 0, -40 }, Neck = { -6, 0, 0 }, Waist = { 4, 0, 0 } } }, ease = "out" },
			{ t = 0.4, pose = { root = { y = -0.12 }, squash = 0.12, j = { RightShoulder = { 25, 0, 30 }, LeftShoulder = { 50, 0, -30 }, RightKnee = { -24, 0, 0 }, LeftKnee = { -24, 0, 0 }, RightHip = { 12, 0, 0 }, LeftHip = { 12, 0, 0 } } }, ease = "in" },
			{ t = 0.56, pose = { root = { y = 0, rz = 3 }, j = { RightShoulder = { 120, 0, 30 }, RightElbow = { 120, 0, 0 }, Neck = { 14, 0, 0 } } }, ease = "inOut" }, -- 오른손으로 사과 쪽을 더듬어 봄
			{ t = 0.7, pose = "hold", ease = "backOut" },
		},
		flowers = { -- 치유사: 지팡이를 높이 들면(예비 동작 = 살짝 낮춤) 끝에서 꽃이 펑 → 놀라 몸을 젖힘 → 웃으며 들썩
			{ t = 0.0, pose = "hold", ease = "inOut" },
			{ t = 0.1, pose = { root = { y = -0.15 }, squash = 0.07, j = { RightShoulder = { 10, 0, 14 }, RightElbow = { 80, 0, 0 } } }, ease = "in" },
			{ t = 0.24, pose = { root = { y = 0.1 }, squash = -0.06, j = { RightShoulder = { 165, 0, 10 }, RightElbow = { 5, 0, 0 }, RightWrist = { -75, 0, 0 }, Neck = { 18, 0, 0 } } }, ease = "backOut" }, -- 손목을 뒤로 = 지팡이를 세워 듦
			{ t = 0.36, pose = { root = { y = 0.05, rx = -6 }, j = { RightShoulder = { 160, 0, 10 }, RightWrist = { -70, 0, 0 }, Waist = { 12, 0, 0 }, Neck = { 24, 0, 0 }, LeftShoulder = { 40, 0, -50 } } }, ease = "out" },
			{ t = 0.5, pose = { root = { y = 0.22 }, squash = -0.05, j = { RightShoulder = { 150, 0, 10 }, RightWrist = { -60, 0, 0 }, Waist = { 4, 0, 0 }, Neck = { 10, 0, 0 } } }, ease = "inOut" },
			{ t = 0.6, pose = { root = { y = 0 }, squash = 0.07, j = { RightShoulder = { 70, 0, 12 }, RightElbow = { 35, 0, 0 }, RightWrist = { -10, 0, 0 } } }, ease = "inOut" }, -- 지팡이를 세운 채로 내림(팔 각 + 팔꿈치 + 손목 ≈ 95 유지 - 튀는 프레임 방지)
			{ t = 0.7, pose = "hold", ease = "backOut" },
		},
	},
	props = {
		smoke = { puffs = 8, size = { 1.2, 2.6 }, color = C(240, 241, 245), seconds = 0.5, transparency = 0.45 }, -- 펑: 옅게 시작해 넓게 퍼지며 사라짐(몸을 오래 가리지 않게)
		sparkle = { color = C(255, 230, 130), size = 0.45, seconds = 0.35, count = 3 }, -- 조각이 붙을 때(묶음마다)
		finaleSparkle = { count = 6, size = 0.6, seconds = 0.5 },
		dust = { color = C(196, 170, 130), count = 4, fade = 0.5 }, -- 옅은 흙먼지(공처럼 보이지 않게)
		apple = { color = C(220, 52, 52), leaf = C(70, 170, 70), size = 0.9, onHead = 1.38 }, -- 머리 가운데에서 사과 가운데까지(머리 메시 1.25배 위에 얹힘)
		arrow = { color = C(150, 110, 70), from = 14, flySeconds = 0.18, at = 0.12 }, -- 박자 시작 + at에 출발 · flySeconds 뒤 꽂힘
		flowers = { colors = { C(255, 160, 200), C(255, 230, 120), C(170, 210, 255), C(255, 255, 255) }, count = 7, at = 0.42, seconds = 0.5 }, -- 지팡이를 들었다 살짝 내려 화면 안에 올 때 펑
	},
	sounds = { smoke = "recall_done", clank = "protect_ticket", catch = "pickup", heavy = "hit_heavy", juggle = "swing", apple = "hit_light", flowers = "codex_cell", pose = "title_get" },
}
