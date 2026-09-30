-- A2-N3 Open Cloud 메시 가져오기 값(서버 ArtAssetLoader · shared/ArtMeshKit가 읽는다). 에셋 id 표 = shared/data/ArtAssetIds(생성 파일).
--   전부 ArtStyleV1 스위치 뒤 - 끄면 캐시를 쓰지 않는다(지금 게임과 같다). 메시는 모양만: 판정 · 경제 · 저장 무관.
return {
	cacheFolder = "ArtMeshCache", -- ReplicatedStorage.ArtMeshCache.<"monsters/rock_boar" 같은 키>(Rojo 관리 밖 - 서버가 실행 중 채운다)
	readyAttribute = "ArtMeshReady", -- 캐시 폴더 Attribute: 로드가 끝나면 true(클라 무기 · 아이콘이 다시 짓는 신호)
	-- Open Cloud FBX 가져오기 = cm 단위(× 100) · 앞뒤 반대(Y 180°) - A2-N3 세로 절단 실측(rock_boar Head z +1.95 ↔ 메타 −1.95 · Tusk_L x +0.775 ↔ −0.775 · y 같음)
	unitScale = 0.01,
	yawDegrees = 180,
	loadConcurrency = 4, -- 동시에 부르는 LoadAsset 수
	propsFirstPrefix = "props/", -- 로더 1단계(맵 소품 · 제단에 먼저 입힌다 → PropsReady)
	propsReadyAttribute = "PropsReady",
	mapBuiltAttribute = "WorldMapBuilt", -- Workspace Attribute - HuntingGround가 맵 · 제단을 다 지은 뒤 true(소품 메시는 그 뒤에 입힌다)
	-- 몬스터: 가져오기 순서표 6(슬라임 · 양 제외 - 아트 샘플 몸체 · 옛 몸체 유지)
	monsterSkip = { moss_slime = true, cloud_sheep = true },
	outlineSuffix = "_Outline",
	gateMeshWidth = 12.8, -- A2-N4: props/boss_gate · extras/gate_decor 메시의 기둥 중심 간격(코드 틀 WorldMapData.bossGate.width 40 = 기둥 중심 간격과 대응 - Play: 전체 폭 20.48로 맞추면 기둥이 빛 테 안쪽으로 작았다) - 배율 = width ÷ 이 값(server/BossGateArt)
	-- A2-N4 §3-3(A2-N3 결정 ③): 어두운 보스(남색 바닥 · 망토)는 잉크색 껍데기가 바닥에 묻힌다 → 보스별 밝은 외곽선 색(키 = 리그 id)
	outlineColorOf = { abyssal_lord = Color3.fromRGB(120, 230, 235), storm_lord = Color3.fromRGB(235, 240, 255) }, -- 보스 껍데기 메시(같은 뼈 용접 · 색 = ArtStyleV1Data.ink) → 그 보스는 외곽선 풀 Highlight를 끈다(Attribute MeshOutline)
	-- 무기: 게임 연결 = 이 직업만(성기사 paladin = 업로드 · id 기록만 - 순서표 5)
	weaponClasses = { greatsword = true, dualblade = true, bow = true, healer = true },
	weaponPieces = { dualblade = { "BladeRight", "BladeLeft" } }, -- WeaponRigSpec 조각 이름(같은 메시 복제 - 순서표 2)
	weaponDropParts = { bow = { "String" } }, -- 시위 = 코드(순서표 3)
	-- 펫(순서표 11): 저장된 펫 등급(부화 결과 EggData.hatchGrades 4단계) → 외형 등급(roblox/art/pets/<몸>_<외형>.fbx 3단계). 알 등급은 저장되지 않아 부화 결과 등급으로 잇는다.
	petLookOfGrade = { common = "normal", uncommon = "good", rare = "rare", epic = "rare" },
	petDecoColor = { -- 좋은 · 희귀 장식(Deco) 색 = 메타 looks(구역 색을 따르지 않는 대비색)
		dog = { good = "#3FC9B5", rare = "#F2C94C" },
		cat = { good = "#FFB547", rare = "#F2C94C" },
		dragon = { good = "#3FC9B5", rare = "#F2C94C" },
	},
	petGlowPoint = { dog = { 0, -0.02, -0.74 }, cat = { 0, 0.22, -0.74 }, dragon = { 0.1, 0.3, -0.68 } }, -- 희귀 외형 = 이 자리(몸 기준)에 PointLight(메타 glowPoint)
	petGlow = { range = 4, brightness = 1 },
	-- 방어구 착용 표시(순서표 14 · docs/art/armor-wear-spec.md 2안 = 클라 조각 + WeldConstraint). 모델 = armor/<부위>_<구역>_<외형>(외형 FBX 3종)
	armorLookOfGrade = { normal = "normal", rare = "normal", epic = "normal", legendary = "legendary", relic = "legendary", ancient = "legendary", primordial = "transcendent", transcendent = "transcendent" },
	armorScaleClamp = { min = 0.8, max = 1.35 }, -- 체형 배율(붙는 파트 Size ÷ refSize) 자르기 - 명세 §5
	-- A2-N4 P0-3 A안: 붙는 R15 파트 실측 맞춤(armorScaleClamp 대신). 파트마다 조각 묶음 경계를 목표 = 손 · 발은 파트 × (1 + handFootPad), 나머지는 파트 + 껍데기 shellStuds × 2 에 맞춘다.
	--   둘레(X · Z) = 목표에 딱 맞춤(늘리기 · 줄이기) · 길이(Y) = 목표보다 크면 줄이기만(어깨판이 팔 길이로 늘어나지 않게).
	armorFit = { shellStuds = 0.15, handFootPad = 0.10, handFootParts = { LeftHand = true, RightHand = true, LeftFoot = true, RightFoot = true },
		v3LengthClamp = { 0.6, 1.6 } }, -- QUEUE-ALL1 P2 v3: 길이(Y) = 붙는 파트 길이 ÷ 기준 체형 길이(이 범위로 자름) · 둘레 = 묶음의 가장 큰 껍데기로
	armorLookAttribute = "ArmorLook_", -- Player Attribute ArmorLook_<부위> = "<구역>|<등급>"(서버 InventorySync.push - 화면 전용 복사본 · 저장 아님)
	-- 조각 색(make_armor_wear.py palette와 같은 규칙): 본체 = 구역 base · _Trim = 구역 강조(영웅 이상 = 등급 색) · _Grade = 등급 색 · _Glow = Neon(보석 빛)
	armorZoneColors = {
		tier1 = { base = { 168, 162, 154 }, accent = { 92, 224, 138 } },
		tier2 = { base = { 120, 96, 190 }, accent = { 210, 108, 240 } },
		tier3 = { base = { 201, 228, 234 }, accent = { 235, 110, 90 } },
		tier4 = { base = { 217, 186, 140 }, accent = { 205, 150, 60 } },
		tier5 = { base = { 88, 92, 128 }, accent = { 120, 230, 255 } },
		tier6 = { base = { 236, 240, 246 }, accent = { 111, 200, 255 } },
	},
	armorGlow = { 255, 244, 214 },
	-- QUEUE-ALL1 P2 방어구 v3(docs/design/v2/02-armor-look-v3.md): 메시 = armor/<부위>_<직업>_<외형>(직업 4 × 부위 3 × 외형 3 = 36) · 세트(구역) = 주 · 보조 · 강조 3색.
	--   조각 색: 본체 = main · _Trim = sub · _Grade = accent(금속 장식) · _Glow = Neon(armorGlow). 초월 = 흑금(본체 검정 · _Trim = 세트 main - 세트가 읽히게 · _Grade 금) · 태초 = 흰 몸 + 등급 색.
	--   금지 색(문서): 강한 주황 · 빨강 넓은 면 · 흰 + 자홍 · 검정 + 금(초월 외). 직업 없는(더미 · 모름) 착용은 옛 armorZoneColors 규칙 그대로.
	armorClassAttribute = "ClassId",
	-- 중립 역할(_Steel 강철 · _Leather 가죽 - 세트와 무관): 한 벌이 세트 한 색이 되지 않게(Play 1차: 쌍검 tier5 = 남색 한 벌). 초월 · 태초는 흑금 · 흰 몸 규칙 안의 어두운 · 밝은 값.
	armorNeutral = {
		steel = { 186, 192, 204 }, leather = { 112, 76, 50 },
		transcendent = { steel = { 62, 58, 74 }, leather = { 46, 40, 52 } },
		primordial = { steel = { 228, 228, 236 }, leather = { 206, 198, 214 } },
	},
	armorSetColors = {
		tier1 = { main = { 150, 138, 120 }, sub = { 104, 140, 84 }, accent = { 176, 128, 70 } }, -- 석조 평원: 따뜻한 회갈 · 이끼 초록 · 청동
		tier2 = { main = { 178, 182, 196 }, sub = { 122, 96, 180 }, accent = { 240, 176, 210 } }, -- 수정 동굴: 은회 · 보라 · 연분홍 수정
		tier3 = { main = { 52, 150, 150 }, sub = { 220, 200, 160 }, accent = { 244, 240, 230 } }, -- 수몰 사원: 청록 · 모래색 · 진주 흰
		tier4 = { main = { 206, 168, 110 }, sub = { 40, 70, 130 }, accent = { 214, 176, 62 } }, -- 모래 유적: 모래 황토 · 짙은 청 · 금
		tier5 = { main = { 44, 52, 100 }, sub = { 130, 190, 240 }, accent = { 214, 220, 230 } }, -- 폭풍 첨탑: 짙은 남 · 하늘 · 은
		tier6 = { main = { 226, 236, 246 }, sub = { 130, 190, 230 }, accent = { 200, 208, 220 } }, -- 빙하 동굴: 흰 청 · 얼음 청 · 은
	},
	armorPrimordialBase = { 244, 242, 250 },
	armorTranscendent = { base = { 38, 34, 48 }, grade = { 214, 176, 62 }, glow = { 255, 208, 92 } }, -- 흑금(artlib BLACK_BODY · GOLD · GOLD_GLOW)
	-- 무기 등급(ArmorData.gradeOrder) → 파일 이름 등급(roblox/art/weapons/<직업>_<등급>.fbx)
	weaponGradeFile = { normal = "normal", rare = "rare", epic = "epic", legendary = "legendary", ancient = "ancient", relic = "relic", primordial = "primordial", transcendent = "transcendent" },
}
