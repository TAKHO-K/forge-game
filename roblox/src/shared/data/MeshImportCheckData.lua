-- B3 메시 가져오기 검사 규칙(shared/MeshImportCheck · shared/MeshSwap · server/MeshImportDev가 읽는다). 수치는 여기만.
--   절차 · 이름 규칙 · 검사 항목 표 = docs/art/blender-to-studio.md. 리그 규격(MonsterRigSpec · BossRigSpec)은 읽기만 한다 - 필요한 추가 값은 이 파일에 둔다.
--   출처: 삼각형 예산 = style-bible §12(몬스터 1,500 · 보스 6,000 · 무기 800 - "시범에서 확정" 제안값) · 소품 1,500 = asset-pipeline §1-2 ·
--   3톤 배율 ×1.18 · ×0.72 = art-spec §1-2 · 구역 팔레트 = CartoonStyleData.palette(art-spec §2 - 여기에 다시 적지 않는다).
local MeshImportCheckData = {}

-- 가져온 모델에서 "기준 루트"로 읽는 파트 이름(Blender 스크립트가 원점에 작은 상자로 만든다 - 리그 루트와 같은 이름). 검사 · 교체에서 리그 파트로 세지 않는다.
MeshImportCheckData.referenceRootName = "HumanoidRootPart"
-- 리그 파트가 아니어도 남는 파트로 세지 않는 이름(가져오기 도구가 붙이는 것 · 판정 상자)
MeshImportCheckData.ignoreNames = { HumanoidRootPart = true, Hitbox = true }

-- ① 이름 · 클래스
MeshImportCheckData.allowedClasses = { MeshPart = true }

-- ② 관절(피벗) 위치: 측정 = 파트 안 Attachment(jointAttachmentName)가 있으면 그 자리, 없으면 파트 피벗(GetPivot - Blender 원점이 PivotOffset으로 남는다고 가정 - 미검증).
MeshImportCheckData.jointAttachmentName = "Joint"
MeshImportCheckData.jointToleranceStuds = 0.15 -- 규격 관절 자리와의 거리 상한(sizeScale 1 기준 - 검사 배율을 곱한다)
MeshImportCheckData.pivotAtCenterEpsilon = 0.02 -- 측정 관절 = 경계 가운데이면 "가져오기가 피벗을 가운데로 옮겼다" 힌트

-- ③ 삼각형 예산(모델 전체 합 · 기준 루트 제외). 출처는 머리 주석.
MeshImportCheckData.triBudget = { monster = 1500, boss = 6000, weapon = 800, prop = 1500 }
MeshImportCheckData.triAttribute = "TriCount" -- 파트 Attribute(Blender 커스텀 속성 이름과 같다)
MeshImportCheckData.metaFolder = "MeshMeta" -- ReplicatedStorage.Shared.MeshMeta.<모델 이름>(Blender 스크립트가 쓰는 Luau 메타 - parts[이름].tris)

-- ④ 크기 · 판정
MeshImportCheckData.size = {
	overallRatio = { min = 0.8, max = 1.25 }, -- 전체 경계(축마다) ÷ 규격 전체 경계
	partLongestRatio = { min = 0.5, max = 2.0 }, -- 파트 가장 긴 변 ÷ 규격 파트 가장 긴 변
	hitboxCoverageDrop = 0.15, -- 잡몹: 겉모습 경계 중 판정 상자와 겹치는 부피 비율이 규격 모양의 비율보다 이만큼 넘게 줄면 X
	queryPartRatio = { min = 0.8, max = 1.25 }, -- 보스: 조준 · 판정 파트(규격 query = true - Body · Head) 축마다 비율
	unitHints = { { ratio = 100, label = "cm → stud(×100)" }, { ratio = 0.01, label = "×0.01" }, { ratio = 3.571, label = "m → stud(×3.57)" }, { ratio = 0.28, label = "stud → m(×0.28)" } },
	unitHintTolerance = 0.15, -- 전체 비율이 위 배율의 ±15% 안이면 단위 힌트
}
-- 잡몹 판정 상자 기본값 - server/MonsterSpawner의 옛 몸통 + 머리 상자(2.4 × 4.6 × 1.6 · 가운데 y 0.8)와 같은 값. 종 hitbox(MonsterSpeciesData)가 있으면 그걸 쓴다.
MeshImportCheckData.defaultMonsterHitbox = { size = { 2.4, 4.6, 1.6 }, center = { 0, 0.8, 0 } }

-- ⑤ 팔레트: 허용 색 = 구역 팔레트(CartoonStyleData.palette - 종 티어의 구역 · 모르면 전부) + 외곽선색 + 리그 색 역할(BossRigSpec.colorOf - 종 · 보스 색) × 3톤 배율.
MeshImportCheckData.palette = {
	tones = { 1, 1.18, 0.72 },
	toleranceRGB = 6, -- 채널(0 ~ 255)마다 차 상한
	roles = { "body", "head", "dark", "accent", "eye", "mouth" },
}

-- ⑥ 투명 · 재질
MeshImportCheckData.maxTransparency = 0
MeshImportCheckData.allowedMaterials = { SmoothPlastic = true } -- 규격 관절에 material(예: Neon)이 적힌 파트는 그 재질도 허용
MeshImportCheckData.forbiddenChildren = { SurfaceAppearance = true, Decal = true, Texture = true } -- 텍스처 0장(style-bible §0-2 평면 3톤)

-- 교체(MeshSwap): 외형 파트 물리 속성 = BossRig.newPart와 같게(판정은 루트 · Hitbox · 규격 query 파트가 맡는다)
MeshImportCheckData.swap = {
	recolor = true, -- 교체 메시 색 = 리그 색 역할(종 · 보스 색 - 세대 틴트 · 피격 번쩍임 출발점이 같게). false면 가져온 색 유지
	previewFolder = "MeshPreview", -- Workspace.MeshPreview.<리그 id>(개발 명령 미리보기)
	previewDistance = 12, -- 개발자 앞 stud
	metaResidualStuds = 0.05, -- A2-N2 메타 정렬: 파트마다 이동량이 평균에서 이만큼 넘게 벗어나면 배치가 깨진 것(축 · 배율 오류)
}

-- 교체 모델 자리(PropModels · WeaponModels와 같은 방식 - 경로 생략 시 찾는 곳)
MeshImportCheckData.modelFolders = { monster = "MonsterModels", boss = "BossModels" }

return MeshImportCheckData
