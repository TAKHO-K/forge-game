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
	-- 몬스터: 가져오기 순서표 6(슬라임 · 양 제외 - 아트 샘플 몸체 · 옛 몸체 유지)
	monsterSkip = { moss_slime = true, cloud_sheep = true },
	outlineSuffix = "_Outline", -- 보스 껍데기 메시(같은 뼈 용접 · 색 = ArtStyleV1Data.ink) → 그 보스는 외곽선 풀 Highlight를 끈다(Attribute MeshOutline)
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
	armorPrimordialBase = { 244, 242, 250 },
	armorTranscendent = { base = { 38, 34, 48 }, grade = { 214, 176, 62 }, glow = { 255, 208, 92 } }, -- 흑금(artlib BLACK_BODY · GOLD · GOLD_GLOW)
	-- 무기 등급(ArmorData.gradeOrder) → 파일 이름 등급(roblox/art/weapons/<직업>_<등급>.fbx)
	weaponGradeFile = { normal = "normal", rare = "rare", epic = "epic", legendary = "legendary", ancient = "ancient", relic = "relic", primordial = "primordial", transcendent = "transcendent" },
}
