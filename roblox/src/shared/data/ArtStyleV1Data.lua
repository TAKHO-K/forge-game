-- A2-S 아트 샘플 1세트(승인용 - docs/art/art-direction-v1.md · docs/phase/A2-S-report.md). 스위치 = Workspace Attribute ArtStyleV1(서버가 부팅 때 enabled로 켜고 끈다 · /gg art on|off).
--   끄면 지금 게임과 완전히 같다: 몬스터 = MonsterRigSpec 몸체 · 무기 = 지금 메시 · 강화대 = 서버 도형 · 조명 = CartoonStyleData.active.
--   판정 무관: 몬스터 Hitbox · 무기 규격(WeaponRigSpec 길이 · Grip) · 강화대 서버 파트(충돌 · 거리 판정 자리)는 그대로 - 여기 값은 겉모습만.
--   색 · 치수 · 시간은 전부 이 파일. 조립 = shared/ArtV1Models(무기 · 강화대) · shared/BossRig.build(몬스터 - 같은 관절 표 규격) · 움직임 · 연출 = client/ArtV1View.
local V = Vector3.new
local C = Color3.fromRGB

local INK = C(30, 27, 46) -- 외곽선 색 #1E1B2E = 가장 어두운 색(순검정 금지)
local WHITE = C(255, 255, 255)

-- 몬스터 관절 표(MonsterRigSpec과 같은 모양: 관절 이름 Body = RootJoint · Head = Neck · 나머지 = 부위 이름). color = 역할 문자열 또는 Color3.
local function J(part, parent, size, color, at, o)
	o = o or {}
	local name = part == "Body" and "RootJoint" or (part == "Head" and "Neck" or part)
	return { name = name, parent = parent, part = part, size = size, color = color, at = at, pivot = o.pivot or V(0, 0, 0), rot = o.rot, shape = o.shape, material = o.material }
end
local R = "HumanoidRootPart"

-- T1 이끼 슬라임 v1(10파트): 민트 젤리 돔(몸 + 넓은 밑단) · 짙은 이끼 모자 + 새싹 두 잎(= 멀리서 보이는 "튀어나온 것 1개") · 큰 흰 눈 + 검은 눈동자 · 왼쪽 위 광택 1개.
--   바닥 잔디(#7BC950)보다 밝고 차가운 민트 → 명도 · 색상 대비. 관절 이름(RootJoint · Neck)이 옛 몸체와 같아 전조 포즈(MonsterSpeciesData.windup)가 그대로 먹는다.
local SLIME_BODY = C(104, 224, 160)
local SLIME_BASE = C(78, 192, 134) -- 밑단 = 몸 × 약 0.85(3톤 그늘 쪽)
local SLIME_MOSS = C(58, 132, 62)
local SLIME_LEAF = C(126, 196, 70)
local monsterRigs = {
	moss_slime = { attach = {}, joints = {
		J("Body", R, V(2.8, 2.4, 2.8), SLIME_BODY, V(0, -0.35, 0), { shape = "ball" }),
		J("Base", "Body", V(3.2, 0.9, 3.2), SLIME_BASE, V(0, -0.75, 0), { shape = "ball" }),
		J("Head", "Body", V(1.9, 0.6, 1.9), SLIME_MOSS, V(0, 1.1, 0.05), { shape = "ball" }),
		J("Leaf_L", "Head", V(0.3, 1.0, 0.7), SLIME_LEAF, V(-0.32, 0.6, 0), { rot = V(-90, 60, 90), shape = "wedge" }), -- = 바깥으로 30° 기울인 뒤 넓은 면이 앞(Play 3각도 확인 뒤 조정)
		J("Leaf_R", "Head", V(0.3, 0.8, 0.6), SLIME_LEAF, V(0.32, 0.5, 0), { rot = V(90, 60, -90), shape = "wedge" }),
		J("Eye_L", "Body", V(0.62, 0.8, 0.3), WHITE, V(-0.5, 0.4, -1.12), { shape = "ball" }),
		J("Eye_R", "Body", V(0.62, 0.8, 0.3), WHITE, V(0.5, 0.4, -1.12), { shape = "ball" }),
		J("Pupil_L", "Eye_L", V(0.34, 0.42, 0.2), INK, V(0, -0.08, -0.1), { shape = "ball" }), -- 가운데(안쪽으로 치우치면 사시처럼 보였다)
		J("Pupil_R", "Eye_R", V(0.34, 0.42, 0.2), INK, V(0, -0.08, -0.1), { shape = "ball" }),
		J("Shine", "Body", V(0.55, 0.32, 0.2), WHITE, V(0.98, 0.55, -0.62), { rot = V(-15, -50, -30), shape = "ball" }), -- +X = 보는 사람 왼쪽 위(한쪽 광택)
	} },
}

return {
	enabled = false, -- 기본 꺼짐(승인 전). 부팅 때 Workspace.ArtStyleV1 = 이 값
	attribute = "ArtStyleV1",
	lightingProfile = "artV1", -- 켜면 CartoonStyle.apply(이 프로필) · 끄면 CartoonStyleData.active
	ink = INK,

	-- ① 몬스터(서버 MonsterSpawner가 스폰 때 스위치를 보고 고른다 - 켠 뒤 새로 나는 몹부터)
	monsterRigs = monsterRigs,
	monsterMotion = {
		lodStuds = 160, -- 카메라에서 이보다 멀면 움직임 생략(MonsterRigAnimator와 같은 거리)
		idle = { bobStuds = 0.07, hz = 0.45, capLagStuds = 0.05 }, -- 대기: 숨쉬기(몸 위아래 + 모자 늦게 따라옴)
		walk = { minSpeed = 1.2, hopStuds = 0.55, hopHz = 2.4, leanDeg = 7 }, -- 걷기: 통통 튀기(이동 속도 stud/s 이상일 때)
		windupReleaseSeconds = 0.25, -- 전조 포즈(MonsterRigAnimator)가 끝난 뒤 이만큼은 손대지 않는다(두 코드가 같은 관절을 쓰지 않게)
		death = { rollSeconds = 0.3, rollDeg = 80, sinkStuds = 0.5, fadeFrom = 0.25, fadeSeconds = 0.4 }, -- 쓰러짐(비폭력): 옆으로 데굴 → 흐려짐(despawn 0.8초 안)
	},

	-- ② 대검(같은 형태 · 등급 3단계 look). 모델 축 = WeaponRigSpec(+Z 칼끝 · +X 날 폭 · Y 두께) · 길이 5.4(규격 5.5 ± 10%) · Grip = −1.1.
	greatsword = {
		pommelZ = -1.78, gripZ = -1.1, supportZ = -1.58,
		grip = { length = 1.15, width = 0.3, centerZ = -1.1 },
		pommel = 0.46,
		guard = { size = V(1.7, 0.34, 0.38), z = -0.36 },
		blade = { width = 0.96, thick = 0.2, fromZ = -0.17, toZ = 2.95, tipLength = 0.62 },
		fuller = { width = 0.22, thick = 0.24, fromZ = 0.05, toZ = 2.55 }, -- 가운데 홈(날보다 조금 두꺼워 양면에 보이는 띠)
		wing = { size = V(0.3, 0.95, 0.85), x = 1.05 }, -- 가드 끝 날개(전설 · 초월 - 0.55 × 0.7은 폰 거리에서 안 보였다)
		gem = 0.5, -- 가드 두께(0.34)보다 커야 양면에 보인다
		crack = { size = V(0.07, 0.25, 1.1), at = { { x = 0.18, z = 0.8, ry = 18 }, { x = -0.2, z = 1.9, ry = -22 } } }, -- 초월 금빛 균열(양면 관통 띠)
		trail = { top = V(0, 0, 2.2), bottom = V(0, 0, -1.3) }, -- 리본(블레이드 파트 로컬)
		gradeLook = { "normal", "normal", "normal", "legendary", "legendary", "legendary", "legendary", "transcendent" }, -- [WeaponGrade(0 일반 ~ 6 태초 · 7 초월) + 1] → look · "grade" 색 = ItemVisualData 등급 색 · 개발 미리보기 = Player Attribute ArtV1WeaponLook
		looks = {
			normal = { steel = C(206, 212, 224), steelShade = C(150, 158, 174), fuller = C(150, 158, 174), guard = C(112, 104, 98), grip = C(96, 62, 40), pommel = C(112, 104, 98) },
			legendary = { steel = C(232, 236, 244), steelShade = C(170, 176, 190), fuller = "grade", fullerNeon = false, guard = "grade", grip = C(90, 48, 30), pommel = "grade",
				wings = true, gem = C(255, 244, 214), gemNeon = true, light = { range = 7, brightness = 0.8 } },
			transcendent = { steel = C(38, 34, 48), steelShade = C(24, 22, 32), fuller = C(214, 176, 62), fullerNeon = true, guard = C(214, 176, 62), grip = C(24, 22, 32), pommel = C(214, 176, 62),
				wings = true, gem = C(255, 214, 90), gemNeon = true, cracks = C(255, 208, 92), light = { range = 9, brightness = 1.1, color = C(255, 214, 120) },
				sparks = { rate = 6, lifetime = 0.8, color = C(255, 214, 120), size = 0.18, speed = 1.2 } }, -- 파티클 ≤ 8(폰 예산)
		},
	},

	-- ③ 강화대(클라 겉모습 - 서버 Base · AnvilTop은 LocalTransparencyModifier로 숨기고 충돌 · 거리 판정 자리는 그대로). 로컬 축: −Z = 허브 쪽(앞) · 바닥 = y 0.
	forge = {
		hideParts = { "Base", "AnvilTop" },
		wood = C(104, 66, 40), woodTop = C(140, 96, 58), -- (139, 90, 43)은 조명 아래 주황 호박처럼 떴다(Play 실측) iron = C(78, 82, 100), ironTop = C(150, 156, 176), ironShade = C(52, 54, 68),
		stone = C(128, 120, 118), stoneShade = C(86, 80, 84), ember = C(255, 140, 50), ingot = C(255, 170, 60), sign = C(255, 230, 90), signBoard = C(96, 62, 40),
		light = { range = 9, brightness = 0.7, color = C(255, 170, 90) }, -- 16 · 1.6은 받침 · 굴뚝을 주황으로 물들였다(Play 실측)
		embers = { rate = 4, lifetime = 1.6, speed = 3, size = 0.25, color = C(255, 160, 70) }, -- 굴뚝 불씨 ≤ 6(폰 예산)
		outlineTag = true, -- 상호작용 대상 = 외곽선 풀 후보(태그 OutlineTarget)
	},

	-- ④ 강화 성공 연출(클라 · 판정 무관). 대성공 = 성공 중 +5 단위 도달(겉모습 분류만 - 서버 결과 종류는 그대로 "success").
	enhanceFx = {
		greatEvery = 5,
		success = { seconds = 0.9, flashSize = 3, flashSeconds = 0.12, ringSize = 6, ringSeconds = 0.5, sparks = 12, sparkColor = C(255, 150, 60), sparkSize = 0.6, sparkSpeed = 11, sparkSpread = 55, shake = nil }, -- 불꽃 0.35는 강화대 거리에서 점으로만 보였다(Play 실측)
		great = { seconds = 1.4, flashSize = 5, flashSeconds = 0.16, ringSize = 10, ringSeconds = 0.7, sparks = 20, sparkColor = C(255, 205, 70), sparkSize = 0.7, sparkSpeed = 16, sparkSpread = 70,
			stars = 4, starColor = C(255, 240, 150), starSize = 1.1, starSpeed = 6, starSpread = 90, starGravity = 4,
			pillar = { height = 9, width = 1.4, color = C(255, 214, 90), seconds = 1.2 }, shake = { seconds = 0.25, studs = 0.12 } },
		flashColor = WHITE, ringColor = C(255, 190, 90), sparkGravity = 30, particleLifetime = { 0.45, 0.8 }, emitterSeconds = 1.2,
	},
}
