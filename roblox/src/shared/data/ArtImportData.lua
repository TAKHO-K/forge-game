-- A2-N3 Open Cloud 메시 가져오기 값(서버 ArtAssetLoader · shared/ArtMeshKit가 읽는다). 에셋 id 표 = shared/data/ArtAssetIds(생성 파일).
--   전부 ArtStyleV1 스위치 뒤 - 끄면 캐시를 쓰지 않는다(지금 게임과 같다). 메시는 모양만: 판정 · 경제 · 저장 무관.
return {
	cacheFolder = "ArtMeshCache", -- ReplicatedStorage.ArtMeshCache.<"monsters/rock_boar" 같은 키>(Rojo 관리 밖 - 서버가 실행 중 채운다)
	readyAttribute = "ArtMeshReady", -- 캐시 폴더 Attribute: 로드가 끝나면 true(클라 무기 · 아이콘이 다시 짓는 신호)
	-- Open Cloud FBX 가져오기 = cm 단위(× 100) · 앞뒤 반대(Y 180°) - A2-N3 세로 절단 실측(rock_boar Head z +1.95 ↔ 메타 −1.95 · Tusk_L x +0.775 ↔ −0.775 · y 같음)
	unitScale = 0.01,
	yawDegrees = 180,
	loadConcurrency = 4, -- 동시에 부르는 LoadAsset 수
	-- 몬스터: 가져오기 순서표 6(슬라임 · 양 제외 - 아트 샘플 몸체 · 옛 몸체 유지)
	monsterSkip = { moss_slime = true, cloud_sheep = true },
	outlineSuffix = "_Outline", -- 보스 껍데기 메시(같은 뼈 용접 · 색 = ArtStyleV1Data.ink) → 그 보스는 외곽선 풀 Highlight를 끈다(Attribute MeshOutline)
	-- 무기: 게임 연결 = 이 직업만(성기사 paladin = 업로드 · id 기록만 - 순서표 5)
	weaponClasses = { greatsword = true, dualblade = true, bow = true, healer = true },
	weaponPieces = { dualblade = { "BladeRight", "BladeLeft" } }, -- WeaponRigSpec 조각 이름(같은 메시 복제 - 순서표 2)
	weaponDropParts = { bow = { "String" } }, -- 시위 = 코드(순서표 3)
	-- 무기 등급(ArmorData.gradeOrder) → 파일 이름 등급(roblox/art/weapons/<직업>_<등급>.fbx)
	weaponGradeFile = { normal = "normal", rare = "rare", epic = "epic", legendary = "legendary", ancient = "ancient", relic = "relic", primordial = "primordial", transcendent = "transcendent" },
}
