-- 최소 스텁: Vector3 · Color3 · game · require(경로 끝 이름)
local V3 = {}
V3.__index = function(a, k) -- BOSS-NIGHT-1 0c: BossSkeleton(리그 v2 생성기)이 Unit · Magnitude · Dot · Cross · 나눗셈을 쓴다
	if k == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end
	if k == "Unit" then local m = math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) return setmetatable({ X = a.X / m, Y = a.Y / m, Z = a.Z / m }, V3) end
	if k == "Dot" then return function(p, q) return p.X * q.X + p.Y * q.Y + p.Z * q.Z end end
	if k == "Cross" then return function(p, q) return setmetatable({ X = p.Y * q.Z - p.Z * q.Y, Y = p.Z * q.X - p.X * q.Z, Z = p.X * q.Y - p.Y * q.X }, V3) end end
	return rawget(V3, k)
end
local function v(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return v(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b) if type(a) == "number" then return v(a * b.X, a * b.Y, a * b.Z) end if type(b) == "number" then return v(a.X * b, a.Y * b, a.Z * b) end return v(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
V3.__div = function(a, b) return v(a.X / b, a.Y / b, a.Z / b) end
V3.__unm = function(a) return v(-a.X, -a.Y, -a.Z) end
Vector3 = { new = v, zero = v(0, 0, 0), one = v(1, 1, 1) }
Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end, new = function(r, g, b) return { R = r, G = g, B = b } end }
Enum = setmetatable({}, { __index = function(t, k) return setmetatable({}, { __index = function(_, n) return { Name = n } end }) end })
sources = {}
local cache = {}
local function path(name)
	return setmetatable({ __name = name }, { __index = function(t, k) return path(k) end })
end
game = { GetService = function() return path("svc") end }
script = path("script") -- QUEUE-ALL4 G: BossRigSpec가 require(script.Parent.BossDetailSpec)를 부른다(A2-M1)
local rawRequire = require
require = function(tok)
	local name = type(tok) == "table" and rawget(tok, "__name") or tok
	if cache[name] == nil then
		local f = sources[name]
		assert(f, "모듈 없음: " .. tostring(name))
		cache[name] = f()
	end
	return cache[name]
end
-- 쓰지 않는 무거운 데이터 스텁
sources.MonsterSpeciesData = function() return { species = {} } end
sources.CartoonStyleData = function() return { palette = {} } end

sources.MeshImportCheckData = function()
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
	roles = { "body", "head", "dark", "accent", "eye", "mouth", "light", "shadow", "stone", "slab", "metal" }, -- QUEUE-ALL4 G: A2-M1 디테일 색 역할(BossRigSpec.colorOf)도 허용(옛 = 수호자 메시가 팔레트 X)
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

end

sources.MonsterRigSpec = function()
-- M2 잡몹 몸체 규격(참조 = docs/art/ref/10_monsters_T1-T3.png · 11_monsters_T4-T6.png). 보스 리그(BossRigSpec)와 같은 관절 표 · 같은 조립 함수(shared/BossRig.build - 파트 + Motor6D).
--   초안 = 단순 도형(block · ball · wedge) · 몸체당 파트 ≤ 10 · SmoothPlastic 단색 · 외형 파트는 CanCollide · CanQuery · CanTouch 전부 끔(판정은 MonsterSpawner의 투명 Hitbox · 루트 - 크기 = 옛 몸통 + 머리 그대로).
--   카툰 교체 = 같은 이름 파트 자리에 메시를 끼우면 된다(관절 이름 · 계층 · 부모 공간 자리가 약속 - docs/design/monster-body-draft.md).
-- 표준 부위 이름(필요한 것만 쓴다): Body(몸통 - 필수 · 색 틴트 · 피격 번쩍임) · Head(머리 - 필수 · 이름표 · 피해 숫자 기준) · Eyes · Leg_FL/FR/BL/BR(네 발) · Leg_L/R(두 발 · 막대 다리) ·
--   Arm_L/R · Fist_L/R · Claw_L/R · Tail1..n · Wing_L/R · Ear_L/R · Horn_L/R · Shell / Shell1..n(등 껍데기 · 수정) · Tentacle1..n · Wool(털 덩어리) · Tusk_L/R · Moss(등 이끼) · Flower
--   · Neck1..n(긴 목 마디 - 관절 이름 = 파트 이름 · Head의 관절 "Neck"과 겹치지 않게 번호를 붙인다) · Jaw(아래턱 - 입 벌림). Q1 푸른 드래곤만 파트 ≤ 14(maxParts).
-- 관절 이름: Body = "RootJoint" · Head = "Neck" · 나머지 = 부위 이름과 같다(모션 · 전조 포즈는 관절 이름으로만 가리킨다).
-- 단위: sizeScale 1 기준 · 루트 = (0, 0, 0) · 발바닥 = y −1.5 · 앞 = −Z. 색 역할 = BossRigSpec.colorOf(body · head · dark · accent · eye · mouth).
local V = Vector3.new

local function J(part, parent, size, color, at, o)
	o = o or {}
	local name = part == "Body" and "RootJoint" or (part == "Head" and "Neck" or part)
	return { name = name, parent = parent, part = part, size = size, color = color, at = at, pivot = o.pivot or V(0, 0, 0), rot = o.rot, shape = o.shape, material = o.material }
end

local R = "HumanoidRootPart"
local rigs = {}

-- T1 이끼 슬라임: 통통한 젤리 몸 + 이끼 모자(= Head) + 눈 두 개(4파트)
rigs.moss_slime = { joints = {
	J("Body", R, V(2.6, 2.2, 2.6), "body", V(0, -0.4, 0), { shape = "ball" }),
	J("Head", "Body", V(2.0, 0.45, 2.0), "accent", V(0, 0.95, 0)),
	J("Eye_L", "Body", V(0.35, 0.45, 0.12), "mouth", V(-0.45, 0.25, -1.22)),
	J("Eye_R", "Body", V(0.35, 0.45, 0.12), "mouth", V(0.45, 0.25, -1.22)),
} }

-- T1 바위 멧돼지: 낮고 긴 바위 몸 + 네 발 + 등 이끼 띠 + 엄니(10파트)
rigs.rock_boar = { joints = {
	J("Body", R, V(1.8, 1.5, 3.0), "body", V(0, -0.1, 0)),
	J("Head", "Body", V(1.3, 1.1, 1.0), "head", V(0, 0.05, -1.5), { pivot = V(0, 0, 0.45) }),
	J("Eyes", "Head", V(0.9, 0.2, 0.1), "mouth", V(0, 0.2, -0.52)),
	J("Tusk_L", "Head", V(0.2, 0.5, 0.2), "eye", V(-0.45, -0.25, -0.5), { rot = V(30, 0, 0) }),
	J("Tusk_R", "Head", V(0.2, 0.5, 0.2), "eye", V(0.45, -0.25, -0.5), { rot = V(30, 0, 0) }),
	J("Moss", "Body", V(1.3, 0.3, 2.4), "accent", V(0, 0.85, 0.1)),
	J("Leg_FL", "Body", V(0.45, 0.7, 0.45), "dark", V(-0.6, -0.75, -1.0), { pivot = V(0, 0.35, 0) }),
	J("Leg_FR", "Body", V(0.45, 0.7, 0.45), "dark", V(0.6, -0.75, -1.0), { pivot = V(0, 0.35, 0) }),
	J("Leg_BL", "Body", V(0.45, 0.7, 0.45), "dark", V(-0.6, -0.75, 1.0), { pivot = V(0, 0.35, 0) }),
	J("Leg_BR", "Body", V(0.45, 0.7, 0.45), "dark", V(0.6, -0.75, 1.0), { pivot = V(0, 0.35, 0) }),
} }

-- T2 수정 딱정벌레: 납작한 몸 + 작은 머리 + 막대 다리 + 등 수정 3개(8파트)
rigs.crystal_beetle = { joints = {
	J("Body", R, V(2.0, 1.1, 2.4), "body", V(0, -0.6, 0)),
	J("Head", "Body", V(1.0, 0.7, 0.8), "dark", V(0, -0.1, -1.4), { pivot = V(0, 0, 0.3) }),
	J("Eyes", "Head", V(0.7, 0.18, 0.1), "eye", V(0, 0.1, -0.42), { material = "Neon" }),
	J("Leg_L", "Body", V(0.3, 0.4, 2.0), "dark", V(-0.85, -0.55, 0), { pivot = V(0, 0.2, 0) }),
	J("Leg_R", "Body", V(0.3, 0.4, 2.0), "dark", V(0.85, -0.55, 0), { pivot = V(0, 0.2, 0) }),
	J("Shell1", "Body", V(0.45, 1.4, 0.45), "accent", V(-0.45, 1.2, 0.15), { rot = V(0, 0, 12) }),
	J("Shell2", "Body", V(0.55, 1.9, 0.55), "accent", V(0.05, 1.45, 0.35)),
	J("Shell3", "Body", V(0.4, 1.1, 0.4), "accent", V(0.55, 1.05, -0.1), { rot = V(0, 0, -14) }),
} }

-- T2 자수정 박쥐(공중): 둥근 몸 + 귀 달린 머리 + 날개 두 장(7파트) - 발이 땅에 안 닿는다(떠 있음)
rigs.amethyst_bat = { joints = {
	J("Body", R, V(1.5, 1.4, 1.4), "body", V(0, 0.8, 0), { shape = "ball" }),
	J("Head", "Body", V(1.1, 0.55, 0.9), "body", V(0, 0.75, -0.05)),
	J("Ear_L", "Head", V(0.3, 0.6, 0.2), "dark", V(-0.35, 0.5, 0), { rot = V(0, 0, 15) }),
	J("Ear_R", "Head", V(0.3, 0.6, 0.2), "dark", V(0.35, 0.5, 0), { rot = V(0, 0, -15) }),
	J("Eyes", "Body", V(0.8, 0.2, 0.1), "eye", V(0, 0.25, -0.7)),
	J("Wing_L", "Body", V(2.0, 1.2, 0.12), "accent", V(-0.7, 0.2, 0), { pivot = V(1.0, 0, 0), rot = V(0, 0, -18) }),
	J("Wing_R", "Body", V(2.0, 1.2, 0.12), "accent", V(0.7, 0.2, 0), { pivot = V(-1.0, 0, 0), rot = V(0, 0, 18) }),
} }

-- T3 소라게 기사: 몸 + 큰 소라 껍데기 + 집게 두 개(오른쪽이 큼) + 막대 다리(8파트)
rigs.hermit_knight = { joints = {
	J("Body", R, V(1.8, 0.9, 1.4), "body", V(0, -0.7, 0)),
	J("Head", "Body", V(0.8, 0.5, 0.4), "body", V(0, 0.45, -0.7), { pivot = V(0, -0.2, 0) }),
	J("Eyes", "Head", V(0.7, 0.25, 0.12), "mouth", V(0, 0.2, -0.22)),
	J("Shell", "Body", V(2.0, 2.0, 2.0), "head", V(0, 1.1, 0.5), { shape = "ball" }),
	J("Claw_L", "Body", V(0.9, 0.6, 0.7), "accent", V(-1.1, 0.1, -0.8), { pivot = V(0.3, 0, 0) }),
	J("Claw_R", "Body", V(1.2, 0.8, 0.9), "accent", V(1.2, 0.2, -0.9), { pivot = V(-0.4, 0, 0) }),
	J("Leg_L", "Body", V(0.25, 0.4, 1.2), "dark", V(-0.8, -0.45, 0), { pivot = V(0, 0.2, 0) }),
	J("Leg_R", "Body", V(0.25, 0.4, 1.2), "dark", V(0.8, -0.45, 0), { pivot = V(0, 0.2, 0) }),
} }

-- T3 물방울 해파리(부유): 갓 + 갓머리(= Head) + 굵은 촉수 4개(7파트 - 가는 촉수 금지)
rigs.bubble_jelly = { joints = {
	J("Body", R, V(2.2, 1.6, 2.2), "body", V(0, 1.0, 0), { shape = "ball" }),
	J("Head", "Body", V(1.5, 0.45, 1.5), "head", V(0, 0.72, 0)),
	J("Eyes", "Body", V(0.9, 0.22, 0.1), "mouth", V(0, 0.05, -1.05)),
	J("Tentacle1", "Body", V(0.3, 1.8, 0.3), "dark", V(-0.5, -0.7, -0.5), { pivot = V(0, 0.9, 0) }),
	J("Tentacle2", "Body", V(0.3, 1.8, 0.3), "dark", V(0.5, -0.7, -0.5), { pivot = V(0, 0.9, 0) }),
	J("Tentacle3", "Body", V(0.3, 1.8, 0.3), "dark", V(-0.5, -0.7, 0.5), { pivot = V(0, 0.9, 0) }),
	J("Tentacle4", "Body", V(0.3, 1.8, 0.3), "dark", V(0.5, -0.7, 0.5), { pivot = V(0, 0.9, 0) }),
} }

-- T4 모래 전갈: 납작한 몸 + 집게 + 위로 말린 꼬리 3마디(끝 = 독침)(10파트 - 보스 전갈의 축소판)
rigs.sand_scorpion = { joints = {
	J("Body", R, V(1.6, 0.7, 2.2), "body", V(0, -0.9, 0)),
	J("Head", "Body", V(1.0, 0.5, 0.7), "head", V(0, 0.05, -1.3), { pivot = V(0, 0, 0.2) }),
	J("Eyes", "Head", V(0.6, 0.15, 0.1), "mouth", V(0, 0.15, -0.36)),
	J("Claw_L", "Body", V(0.6, 0.4, 0.9), "head", V(-0.8, 0, -1.6), { pivot = V(0, 0, 0.35) }),
	J("Claw_R", "Body", V(0.6, 0.4, 0.9), "head", V(0.8, 0, -1.6), { pivot = V(0, 0, 0.35) }),
	J("Leg_L", "Body", V(0.25, 0.35, 1.8), "dark", V(-0.85, -0.35, 0.1), { pivot = V(0, 0.175, 0) }),
	J("Leg_R", "Body", V(0.25, 0.35, 1.8), "dark", V(0.85, -0.35, 0.1), { pivot = V(0, 0.175, 0) }),
	J("Tail1", "Body", V(0.45, 1.2, 0.45), "body", V(0, 0.3, 1.0), { pivot = V(0, -0.6, 0), rot = V(35, 0, 0) }),
	J("Tail2", "Tail1", V(0.4, 1.1, 0.4), "body", V(0, 0.6, 0), { pivot = V(0, -0.55, 0), rot = V(-65, 0, 0) }),
	J("Tail3", "Tail2", V(0.35, 0.7, 0.35), "accent", V(0, 0.55, 0), { pivot = V(0, -0.35, 0), rot = V(-70, 0, 0) }),
} }

-- T4 선인장 꼬마(매복): 기둥 몸 + 꽃 달린 머리 + 두 팔(6파트) - 평소엔 소품 선인장과 같은 실루엣
rigs.cactus_imp = { joints = {
	J("Body", R, V(1.2, 2.4, 1.2), "body", V(0, -0.3, 0)),
	J("Head", "Body", V(1.05, 0.6, 1.05), "body", V(0, 1.5, 0)),
	J("Flower", "Head", V(0.6, 0.3, 0.6), "accent", V(0, 0.45, 0)),
	J("Eyes", "Body", V(0.7, 0.2, 0.1), "mouth", V(0, 0.6, -0.62)),
	J("Arm_L", "Body", V(0.5, 1.0, 0.5), "body", V(-0.85, 0.2, 0), { pivot = V(0, -0.5, 0) }),
	J("Arm_R", "Body", V(0.5, 1.0, 0.5), "body", V(0.85, 0.2, 0), { pivot = V(0, -0.5, 0) }),
} }

-- T5 번개 임프: 작은 몸 + 뿔 머리 + 팔 · 다리 + 번개 꼬리(10파트)
rigs.bolt_imp = { joints = {
	J("Body", R, V(1.2, 1.2, 0.9), "body", V(0, -0.1, 0)),
	J("Head", "Body", V(1.1, 0.9, 0.9), "body", V(0, 0.6, 0), { pivot = V(0, -0.45, 0) }),
	J("Eyes", "Head", V(0.7, 0.2, 0.1), "eye", V(0, 0.05, -0.46)),
	J("Horn_L", "Head", V(0.2, 0.6, 0.2), "accent", V(-0.35, 0.55, 0), { rot = V(0, 0, 15), material = "Neon" }),
	J("Horn_R", "Head", V(0.2, 0.6, 0.2), "accent", V(0.35, 0.55, 0), { rot = V(0, 0, -15), material = "Neon" }),
	J("Arm_L", "Body", V(0.3, 0.9, 0.3), "dark", V(-0.75, 0.4, 0), { pivot = V(0, 0.45, 0) }),
	J("Arm_R", "Body", V(0.3, 0.9, 0.3), "dark", V(0.75, 0.4, 0), { pivot = V(0, 0.45, 0) }),
	J("Leg_L", "Body", V(0.4, 0.8, 0.4), "dark", V(-0.3, -0.6, 0), { pivot = V(0, 0.4, 0) }),
	J("Leg_R", "Body", V(0.4, 0.8, 0.4), "dark", V(0.3, -0.6, 0), { pivot = V(0, 0.4, 0) }),
	J("Tail", "Body", V(0.2, 0.9, 0.2), "accent", V(0, -0.4, 0.45), { pivot = V(0, 0.45, 0), rot = V(-60, 0, 0) }),
} }

-- T5 구름 양: 털 덩어리 몸 두 개 + 어두운 머리 + 네 발(8파트)
rigs.cloud_sheep = { joints = {
	J("Body", R, V(2.4, 2.0, 2.8), "body", V(0, -0.1, 0), { shape = "ball" }),
	J("Wool", "Body", V(1.6, 1.6, 1.6), "body", V(0, 0.7, 0.5), { shape = "ball" }),
	J("Head", "Body", V(0.9, 0.9, 1.0), "dark", V(0, 0.3, -1.45), { pivot = V(0, 0, 0.3) }),
	J("Eyes", "Head", V(0.6, 0.18, 0.1), "eye", V(0, 0.15, -0.52)),
	J("Leg_FL", "Body", V(0.35, 0.6, 0.35), "dark", V(-0.6, -0.9, -0.8), { pivot = V(0, 0.3, 0) }),
	J("Leg_FR", "Body", V(0.35, 0.6, 0.35), "dark", V(0.6, -0.9, -0.8), { pivot = V(0, 0.3, 0) }),
	J("Leg_BL", "Body", V(0.35, 0.6, 0.35), "dark", V(-0.6, -0.9, 0.8), { pivot = V(0, 0.3, 0) }),
	J("Leg_BR", "Body", V(0.35, 0.6, 0.35), "dark", V(0.6, -0.9, 0.8), { pivot = V(0, 0.3, 0) }),
} }

-- T6 얼음 골렘: 큰 몸통 + 작은 머리 + 굵은 팔 · 주먹 + 다리(9파트) - 무리 속 탱커
rigs.ice_golem = { joints = {
	J("Body", R, V(2.4, 2.0, 1.4), "body", V(0, 0.4, 0)),
	J("Head", "Body", V(1.0, 0.8, 0.9), "head", V(0, 1.0, -0.1), { pivot = V(0, -0.4, 0) }),
	J("Eyes", "Head", V(0.7, 0.18, 0.1), "mouth", V(0, 0.05, -0.46)),
	J("Arm_L", "Body", V(0.8, 1.6, 0.8), "body", V(-1.6, 0.6, 0), { pivot = V(0, 0.6, 0) }),
	J("Arm_R", "Body", V(0.8, 1.6, 0.8), "body", V(1.6, 0.6, 0), { pivot = V(0, 0.6, 0) }),
	J("Fist_L", "Arm_L", V(1.1, 1.0, 1.1), "accent", V(0, -0.8, 0), { pivot = V(0, 0.4, 0) }),
	J("Fist_R", "Arm_R", V(1.1, 1.0, 1.1), "accent", V(0, -0.8, 0), { pivot = V(0, 0.4, 0) }),
	J("Leg_L", "Body", V(0.8, 0.9, 0.8), "dark", V(-0.6, -1.0, 0), { pivot = V(0, 0.45, 0) }),
	J("Leg_R", "Body", V(0.8, 0.9, 0.8), "dark", V(0.6, -1.0, 0), { pivot = V(0, 0.45, 0) }),
} }

-- T6 눈토끼: 작은 둥근 몸 + 머리 + 긴 귀 + 꼬리(6파트) - 작아서 외곽선 두께가 중요(A2)
rigs.snow_rabbit = { joints = {
	J("Body", R, V(1.4, 1.1, 1.5), "body", V(0, -0.95, 0), { shape = "ball" }),
	J("Head", "Body", V(0.9, 0.9, 0.9), "body", V(0, 0.45, -0.6), { shape = "ball" }),
	J("Eyes", "Head", V(0.55, 0.16, 0.1), "mouth", V(0, 0.08, -0.44)),
	J("Ear_L", "Head", V(0.2, 0.8, 0.12), "accent", V(-0.2, 0.7, 0), { pivot = V(0, -0.4, 0), rot = V(0, 0, 10) }),
	J("Ear_R", "Head", V(0.2, 0.8, 0.12), "accent", V(0.2, 0.7, 0), { pivot = V(0, -0.4, 0), rot = V(0, 0, -10) }),
	J("Tail", "Body", V(0.4, 0.4, 0.4), "head", V(0, 0.1, 0.75), { shape = "ball" }),
} }

-- Q1 T6 푸른 드래곤(14파트 - 드래곤만 ≤ 14): 몸통 · 긴 목(Neck1) · 머리 · 턱 · 눈 · 날개 · 꼬리 3마디 · 네 발. 몸 단위 × sizeScale(T6 1.672) → 높이 11.4 · 길이 23.9 · 날개 폭 17.7 stud(FK 실측)
--   (플레이어 키 5의 약 2.2배 · 4.6배 - 아트 자료 docs/art/ref/19_monsters_T6_blue_dragon.md). 판정 = 종 hitbox(몸통 + 목 + 머리 상자).
rigs.blue_dragon = { maxParts = 14, joints = {
	J("Body", R, V(3.0, 2.2, 4.6), "body", V(0, 0.9, 0)),
	J("Leg_FL", "Body", V(0.8, 1.4, 0.8), "body", V(-1.1, -1.0, -1.5), { pivot = V(0, 0.7, 0) }),
	J("Leg_FR", "Body", V(0.8, 1.4, 0.8), "body", V(1.1, -1.0, -1.5), { pivot = V(0, 0.7, 0) }),
	J("Leg_BL", "Body", V(0.8, 1.4, 0.8), "body", V(-1.1, -1.0, 1.5), { pivot = V(0, 0.7, 0) }),
	J("Leg_BR", "Body", V(0.8, 1.4, 0.8), "body", V(1.1, -1.0, 1.5), { pivot = V(0, 0.7, 0) }),
	J("Neck1", "Body", V(1.0, 2.8, 1.0), "body", V(0, 0.9, -2.0), { pivot = V(0, -1.4, 0), rot = V(-20, 0, 0) }),
	J("Head", "Neck1", V(1.6, 1.2, 2.2), "body", V(0, 1.4, 0), { pivot = V(0, -0.3, 0.6), rot = V(20, 0, 0) }),
	J("Jaw", "Head", V(1.3, 0.3, 1.6), "head", V(0, -0.6, 0.3), { pivot = V(0, 0.15, 0.8) }),
	J("Eyes", "Head", V(1.2, 0.2, 0.1), "accent", V(0, 0.2, -1.1), { material = "Neon" }),
	J("Wing_L", "Body", V(4.0, 0.2, 2.6), "body", V(-1.5, 0.8, -0.4), { pivot = V(2.0, 0, 0), rot = V(0, 0, -20) }),
	J("Wing_R", "Body", V(4.0, 0.2, 2.6), "body", V(1.5, 0.8, -0.4), { pivot = V(-2.0, 0, 0), rot = V(0, 0, 20) }),
	J("Tail1", "Body", V(1.0, 0.9, 2.6), "body", V(0, 0.3, 2.3), { pivot = V(0, 0, -1.3), rot = V(10, 0, 0) }),
	J("Tail2", "Tail1", V(0.75, 0.7, 2.4), "body", V(0, 0, 1.3), { pivot = V(0, 0, -1.2) }),
	J("Tail3", "Tail2", V(0.5, 0.5, 2.2), "accent", V(0, 0, 1.2), { pivot = V(0, 0, -1.1) }),
} }

for _, rig in pairs(rigs) do
	rig.attach = rig.attach or {}
	assert(#rig.joints <= (rig.maxParts or 10), "M2 몸체 초안은 파트 10개 이하(드래곤 14 - maxParts)")
end

return { rigs = rigs, maxParts = 10 }

end

sources.BossSkeleton = function()
-- BOSS-FRAMEWORK 1 뼈대 생성기(순수 함수 - 데이터 표 BossRigSpec · BossRigV2Data가 부른다). 출력 = BossRigSpec 관절 표 규격 그대로
--   { name(Motor6D) · parent(부모 파트) · part(자식 파트) · size · shape · color · material · at(부모 공간 관절 자리) · pivot(자식 공간 관절 자리) · rot(기준 자세 도) · query }.
--   단위 = sizeScale 1 · 루트 = (0, 0, 0) · 발바닥 y −1.5 · 앞 = −Z. 모션 부호(A1 실측): 아래로 늘어진 부위 X +θ = 앞으로 든다 · 무릎 굽힘 X −θ.
--   biped · chain = 옛 BossRigSpec 안의 함수를 옮긴 것(식 · 순서 그대로 - 옛 리그 결과 불변). 나머지 = 새 몸 구조(바이블 §2): 네 발 · 뱀 하체 · 날개 · 코 · 여섯 다리.
--   관절 이름 규칙: 앞다리 = 이족 팔 이름(Shoulder · Elbow · Wrist → UpperArm · Forearm · Hand) · 뒷다리 = 이족 다리 이름(Hip · Knee · Ankle) → 잡기 부착점 · 발 접지 · 효과가 그대로 쓴다.
local BossSkeleton = {}

local V = Vector3.new

local function add(J, j)
	table.insert(J, j)
	return j
end
BossSkeleton.add = add

-- ─────────────────────────── 두 발 몸(옛 BossRigSpec biped 그대로) ───────────────────────────
-- o = { hips, torso, head(크기), headShape, thigh = { w, len }, shin = { w, len }, foot(크기), upperArm = { w, len }, forearm = { w, len }, hand(크기), shoulderX, stance(엉덩이 반폭) }
function BossSkeleton.biped(o)
	local J = {}
	local legLen = o.thigh.len + o.shin.len
	local hipJointY = -1.5 + o.foot.Y + legLen
	add(J, { name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", size = o.hips, color = "dark", at = V(0, hipJointY + o.hips.Y / 2, 0), pivot = V(0, 0, 0) })
	add(J, { name = "Waist", parent = "Hips", part = "Body", size = o.torso, color = "body", at = V(0, o.hips.Y / 2, 0), pivot = V(0, -o.torso.Y / 2, 0), query = true })
	add(J, { name = "Neck", parent = "Body", part = "Head", size = o.head, shape = o.headShape or "block", color = "head", at = V(0, o.torso.Y / 2, 0), pivot = V(0, -o.head.Y * 0.45, 0), query = true })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		add(J, { name = "Hip_" .. side, parent = "Hips", part = "Thigh_" .. side, size = V(o.thigh.w, o.thigh.len, o.thigh.w), color = "body", at = V(x * o.stance, -o.hips.Y / 2, 0), pivot = V(0, o.thigh.len / 2, 0) })
		add(J, { name = "Knee_" .. side, parent = "Thigh_" .. side, part = "Shin_" .. side, size = V(o.shin.w, o.shin.len, o.shin.w), color = "dark", at = V(0, -o.thigh.len / 2, 0), pivot = V(0, o.shin.len / 2, 0) })
		add(J, { name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, size = o.foot, color = "dark", at = V(0, -o.shin.len / 2, 0), pivot = V(0, o.foot.Y / 2, o.foot.Z * 0.25) })
		add(J, { name = "Shoulder_" .. side, parent = "Body", part = "UpperArm_" .. side, size = V(o.upperArm.w, o.upperArm.len, o.upperArm.w), color = "body",
			at = V(x * o.shoulderX, o.torso.Y / 2 - o.upperArm.w * 0.45, 0), pivot = V(0, o.upperArm.len / 2 - o.upperArm.w * 0.3, 0), rot = V(0, 0, x * 6) })
		add(J, { name = "Elbow_" .. side, parent = "UpperArm_" .. side, part = "Forearm_" .. side, size = V(o.forearm.w, o.forearm.len, o.forearm.w), color = "head", at = V(0, -o.upperArm.len / 2, 0), pivot = V(0, o.forearm.len / 2, 0), rot = V(8, 0, 0) })
		add(J, { name = "Wrist_" .. side, parent = "Forearm_" .. side, part = "Hand_" .. side, size = o.hand, color = "head", at = V(0, -o.forearm.len / 2, 0), pivot = V(0, o.hand.Y / 2, 0) })
	end
	-- 얼굴(표정 - 4b-4 낚아채는 순간): 눈 · 입
	add(J, { name = "Eyes", parent = "Head", part = "Eyes", size = V(o.head.X * 0.62, o.head.Y * 0.14, 0.08), color = "eye", material = "Neon", at = V(0, o.head.Y * 0.12, -o.head.Z / 2), pivot = V(0, 0, 0.02) })
	add(J, { name = "Jaw", parent = "Head", part = "Mouth", size = V(o.head.X * 0.42, o.head.Y * 0.1, 0.08), color = "mouth", at = V(0, -o.head.Y * 0.22, -o.head.Z / 2), pivot = V(0, o.head.Y * 0.04, 0.02) })
	return J
end

-- 사슬(꼬리 · 망토 · 수염 · 치마 · 코 · 날개 마디): n마디, 마디마다 length · 굵기 w0 → w1(끝으로 가늘어짐) · 첫 마디 기준 자세 rot0 · 다음 마디부터 rotStep(옛 BossRigSpec chain 그대로).
--   o.thick(선택 - 납작한 천 · 날개막: 두께를 따로) · o.query(선택 - 이 마디 번호만 판정 사본) · o.lengths · o.rots(선택 - 마디마다 길이 · 기준 자세 표)
function BossSkeleton.chain(J, o)
	local parent = o.parent
	for i = 1, o.count do
		local f = (i - 1) / math.max(o.count - 1, 1)
		local w = o.w0 + (o.w1 - o.w0) * f
		local name = ("%s%d"):format(o.prefix, i)
		local len = (o.lengths and o.lengths[i]) or o.length
		local prevLen = i > 1 and ((o.lengths and o.lengths[i - 1]) or o.length) or nil
		table.insert(J, {
			name = name, parent = parent, part = name, size = V(w * (o.flat or 1), len, o.thick or w), color = (i == o.count and o.tipColor) or o.color or "body",
			material = (i == o.count and o.tipMaterial) or o.material, shape = (i == o.count and o.tipShape) or "block",
			at = i == 1 and o.at or V(0, -prevLen / 2, 0), pivot = V(0, len / 2, 0), rot = (o.rots and o.rots[i]) or (i == 1 and o.rot0 or o.rotStep),
			query = (o.query == i) or nil,
		})
		parent = name
	end
	return J
end

-- ─────────────────────────── 네 발(매머드 · 너클 보행 시안의 기준) ───────────────────────────
-- 몸통이 수평: Hips(엉덩이) → Body(앞몸 · 척추 1) → Chest(척추 2 · 선택) → Neck → Head. 앞다리 = Body(또는 Chest) 앞 아래 · 뒷다리 = Hips 아래.
-- o = { hips, body, chest(선택), head, neckLen, legFront = { upper, lower, foot(크기), w }, legRear = { upper, lower, foot, w }, stanceX, frontZ, rearZ, height(엉덩이 관절 높이 - 없으면 다리 길이) }
function BossSkeleton.quadruped(o)
	local J = {}
	local rear, front = o.legRear, o.legFront
	local hipY = -1.5 + rear.foot.Y + rear.upper + rear.lower
	add(J, { name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", size = o.hips, color = "dark", at = V(0, hipY + o.hips.Y * 0.3, o.rearZ or 0.9), pivot = V(0, 0, 0) })
	-- 척추: Body가 Hips 앞으로 수평(관절 = Hips 앞면)
	add(J, { name = "Waist", parent = "Hips", part = "Body", size = o.body, color = "body", at = V(0, 0.1, -o.hips.Z / 2), pivot = V(0, 0, o.body.Z / 2), query = true })
	local front0, frontLen = "Body", o.body.Z
	if o.chest then
		add(J, { name = "Spine", parent = "Body", part = "Chest", size = o.chest, color = "body", at = V(0, 0.05, -o.body.Z / 2), pivot = V(0, 0, o.chest.Z / 2) })
		front0, frontLen = "Chest", o.chest.Z
	end
	add(J, { name = "Neck", parent = front0, part = "Head", size = o.head, color = "head", at = V(0, (o.neckY or 0.25), -frontLen / 2), pivot = V(0, 0, o.head.Z * 0.4), query = true })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		-- 앞다리(팔 이름)
		add(J, { name = "Shoulder_" .. side, parent = front0, part = "UpperArm_" .. side, size = V(front.w, front.upper, front.w), color = "body", at = V(x * o.stanceX, -0.2, -frontLen * 0.25), pivot = V(0, front.upper / 2, 0) })
		add(J, { name = "Elbow_" .. side, parent = "UpperArm_" .. side, part = "Forearm_" .. side, size = V(front.w * 0.9, front.lower, front.w * 0.9), color = "head", at = V(0, -front.upper / 2, 0), pivot = V(0, front.lower / 2, 0) })
		add(J, { name = "Wrist_" .. side, parent = "Forearm_" .. side, part = "Hand_" .. side, size = front.foot, color = "dark", at = V(0, -front.lower / 2, 0), pivot = V(0, front.foot.Y / 2, 0) })
		-- 뒷다리(다리 이름)
		add(J, { name = "Hip_" .. side, parent = "Hips", part = "Thigh_" .. side, size = V(rear.w, rear.upper, rear.w), color = "body", at = V(x * o.stanceX, -o.hips.Y * 0.3, 0), pivot = V(0, rear.upper / 2, 0) })
		add(J, { name = "Knee_" .. side, parent = "Thigh_" .. side, part = "Shin_" .. side, size = V(rear.w * 0.9, rear.lower, rear.w * 0.9), color = "dark", at = V(0, -rear.upper / 2, 0), pivot = V(0, rear.lower / 2, 0) })
		add(J, { name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, size = rear.foot, color = "dark", at = V(0, -rear.lower / 2, 0), pivot = V(0, rear.foot.Y / 2, 0) })
	end
	add(J, { name = "Eyes", parent = "Head", part = "Eyes", size = V(o.head.X * 0.7, o.head.Y * 0.12, 0.08), color = "eye", material = "Neon", at = V(0, o.head.Y * 0.18, -o.head.Z / 2), pivot = V(0, 0, 0.02) })
	add(J, { name = "Jaw", parent = "Head", part = "Mouth", size = V(o.head.X * 0.4, o.head.Y * 0.1, 0.08), color = "mouth", at = V(0, -o.head.Y * 0.3, -o.head.Z / 2), pivot = V(0, o.head.Y * 0.04, 0.02) })
	return J
end

-- ─────────────────────────── 뱀 하체(나가) ───────────────────────────
-- 이족 상체(다리 없음) + Hips 밑에서 뒤로 눕는 꼬리 n마디 + 끝 지느러미. o = { upper(biped 옵션 - 다리 값은 길이 계산용) · tail = { count, length, w0, w1, rot0, rotStep, query } · fin(크기) }
function BossSkeleton.serpent(o)
	local J = {}
	for _, j in ipairs(BossSkeleton.biped(o.upper)) do
		if not (j.name:find("^Hip_") or j.name:find("^Knee_") or j.name:find("^Ankle_")) then
			table.insert(J, j)
		end
	end
	local T = o.tail
	BossSkeleton.chain(J, { prefix = "Tail", parent = "Hips", count = T.count, length = T.length, w0 = T.w0, w1 = T.w1, flat = T.flat or 1.25, at = T.at or V(0, -0.2, 0.2),
		rot0 = T.rot0 or V(-80, 0, 0), rotStep = T.rotStep or V(-8, 0, 0), rots = T.rots, color = "body", query = T.query })
	if o.fin then
		add(J, { name = "TailFin", parent = "Tail" .. T.count, part = "TailFin", size = o.fin, shape = "wedge", color = "accent", at = V(0, -T.length / 2, 0), pivot = V(0, o.fin.Y / 2, 0) })
	end
	return J
end

-- ─────────────────────────── 날개(나비 4장 · 망토 날개) ───────────────────────────
-- pairs = { { tag = "F", at, rot0, count, length, w0, w1, rotStep, thick } … } → Wing<tag>_L1 … · Wing<tag>_R1 …(좌우 거울)
function BossSkeleton.wings(J, parent, pairsList, color, material)
	for _, p in ipairs(pairsList) do
		for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
			local x = s[2]
			BossSkeleton.chain(J, { prefix = ("Wing%s_%s"):format(p.tag, s[1]), parent = parent, count = p.count or 2, length = p.length, w0 = p.w0, w1 = p.w1, thick = p.thick or 0.06,
				at = V(p.at.X * x, p.at.Y, p.at.Z), rot0 = V(p.rot0.X, p.rot0.Y * x, p.rot0.Z * x), rotStep = V(p.rotStep.X, p.rotStep.Y * x, p.rotStep.Z * x), color = color or "accent", material = material })
		end
	end
	return J
end

-- ─────────────────────────── 여섯 다리(전갈 - 엉덩이 · 무릎) ───────────────────────────
-- legs = { z1, z2, z3 } · o = { parent, x, thigh, shin, w } → Hip<k>_<L|R> · Knee<k>_<L|R>(옛 전갈과 같은 이름 · 자세)
function BossSkeleton.hexapod(J, o)
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		for k, z in ipairs(o.legs) do
			local leg = ("%d_%s"):format(k, side)
			add(J, { name = "Hip" .. leg, parent = o.parent, part = "Thigh" .. leg, size = V(o.w, o.thigh, o.w), color = "head", at = V(x * o.x, o.y or -0.15, z), pivot = V(0, o.thigh / 2, 0), rot = V(0, 0, x * 125) })
			add(J, { name = "Knee" .. leg, parent = "Thigh" .. leg, part = "Shin" .. leg, size = V(o.w * 0.86, o.shin, o.w * 0.86), color = "dark", at = V(0, -o.thigh / 2, 0), pivot = V(0, o.shin / 2, 0), rot = V(0, 0, -x * 95) })
		end
	end
	return J
end

-- ─────────────────────────── 검사(관절 수 · 판정 사본 부피) ───────────────────────────
function BossSkeleton.jointCount(rig)
	return #rig.joints
end

-- 판정 사본(query = true 부위) 부피 합(sizeScale 1 · 상자 부피 · 공 = 상자 × π/6)
function BossSkeleton.queryVolume(rig)
	local v, names = 0, {}
	for _, j in ipairs(rig.joints) do
		if j.query then
			local box = j.size.X * j.size.Y * j.size.Z
			v += j.shape == "ball" and box * math.pi / 6 or box
			table.insert(names, j.part)
		end
	end
	return v, names
end

-- 관절 하나 찾기(이름)
function BossSkeleton.find(J, name)
	for _, j in ipairs(J) do
		if j.name == name then
			return j
		end
	end
	return nil
end

return BossSkeleton

end

sources.BossRigV2Data = function()
-- BOSS-FRAMEWORK 1 새 몸(리그 v2) 데이터 - 바이블 §2 보스별 몸 구조. 리그 키 = "<보스 id>_v2"(BossRigSpec.rigs에 같이 등록 · 모델 Attribute BossRigKey).
--   status: "trial" = 시험(Studio 스위치 BossFrameworkTrial로만 뜬다) · "draft" = 뼈대 초안(메시 · 클립 전 - 생성기 · 예산 검사용, 어디서도 안 쓴다).
--   실전 교체 = shared/data/BossFrameworkData.live(설계 담당 검수 뒤에만 채운다).
--   chains(2차 움직임 사슬) = { 관절 이름…, kind = tail | wing | cape | trunk | fur | crystal | cloth(스프링 값 = BossFrameworkData.springs), lag, sway(옛 결정적 흔들림 - BossMotion.chainSway) }.
--   contacts(선택) = 발 접지에 쓰는 부위(없으면 BossRigSpec가 Foot · Shin 끝으로 채운다). 판정 사본 = query = true 부위(Body · Head + 큰 몸이면 1개).
local BossSkeleton = require(script.Parent.Parent.BossSkeleton)

local V = Vector3.new
local add, chain = BossSkeleton.add, BossSkeleton.chain

local D = {}
D.rigs = {}

-- 막대 부위(수정 · 뿔 · 왕관): 중심 center · 회전 rot(도)로 놓되 관절 = 밑동(흔들림 · 터짐이 밑동에서 돈다)
-- 회전(도 - CFrame.Angles(rx, ry, rz)와 같은 순서 Rx · Ry · Rz)을 벡터에 적용(데이터 로드에 CFrame을 안 쓴다 - 하네스 · 도구 스텁에서도 돈다)
local function rotate(v, rot)
	local x, y, z = v.X, v.Y, v.Z
	local cz, sz = math.cos(math.rad(rot.Z)), math.sin(math.rad(rot.Z))
	x, y = x * cz - y * sz, x * sz + y * cz
	local cy, sy = math.cos(math.rad(rot.Y)), math.sin(math.rad(rot.Y))
	x, z = x * cy + z * sy, -x * sy + z * cy
	local cx, sx = math.cos(math.rad(rot.X)), math.sin(math.rad(rot.X))
	y, z = y * cx - z * sx, y * sx + z * cx
	return V(x, y, z)
end

local function stick(J, name, parent, size, center, rot, color, material, shape)
	local base = center - rotate(V(0, size.Y / 2, 0), rot)
	return add(J, { name = name, parent = parent, part = name, size = size, shape = shape, color = color, material = material, at = base, pivot = V(0, -size.Y / 2, 0), rot = rot })
end

-- ─────────────────────────── 구간 수호자 → 너클 보행 수정 골렘(GUARDIAN-V2 · Meshy 원본) ───────────────────────────
-- 상자 · 관절 = Meshy GLB(guardian_v1_meshy71 · A-포즈) 정면 · 옆 실측(모델 높이 10 = "m" 단위 · 발바닥 0 · fwd + = 앞)에 맞춤.
--   K = m → 리그 단위: 판정 사본(Body + Head) 부피 = 옛 몸 × 1.17(허용 ±20%) · 어깨 폭 = 바이블 §4 목표(15 stud @ S 3.9)에 맞춘 값(키는 그림 비율상 §4 추정보다 낮다 - 보고서).
--   팔 = Meshy A-포즈 그대로가 기준 자세(위팔 바깥 43° · 아래팔 · 손 앞으로) - 아래로 펴면 거대한 아래팔이 몸통을 뚫는다(고릴라 비율).
--   scale 1.5 = 바이블 §5 크기 × 1.5(보이는 몸 · 판정 사본 · 모션 이동 모두 - MonsterSpawner가 S × scale로 짓는다).
--   Jaw = 자리만(움직이지 않음 · 메시 없음) · 눈 · 룬 = KIT가 Neon으로 새로 만든다(rigs/section_guardian_v2.kit.json).
do
	local K = 0.40
	local function P(x, z, fwd) -- m 단위 점 → 리그 공간(x = 오른쪽 +)
		return V(K * x, K * z - 1.5, -K * fwd)
	end
	local function Z(w, h, d)
		return V(K * w, K * h, K * d)
	end
	-- 3 × 3 회전(CFrame.Angles(rx, ry, rz) = Rx · Ry · Rz 순서 - 데이터 로드에 CFrame을 안 쓴다)
	local function E(r)
		local cx, sx, cy, sy, cz, sz = math.cos(math.rad(r.X)), math.sin(math.rad(r.X)), math.cos(math.rad(r.Y)), math.sin(math.rad(r.Y)), math.cos(math.rad(r.Z)), math.sin(math.rad(r.Z))
		return {
			{ cy * cz, -cy * sz, sy },
			{ cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy },
			{ sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy },
		}
	end
	local function mulT(A, B) -- Aᵀ · B
		local M = {}
		for i = 1, 3 do
			M[i] = {}
			for j = 1, 3 do
				M[i][j] = A[1][i] * B[1][j] + A[2][i] * B[2][j] + A[3][i] * B[3][j]
			end
		end
		return M
	end
	local function applyT(A, v) -- Aᵀ · v
		return V(A[1][1] * v.X + A[2][1] * v.Y + A[3][1] * v.Z, A[1][2] * v.X + A[2][2] * v.Y + A[3][2] * v.Z, A[1][3] * v.X + A[2][3] * v.Y + A[3][3] * v.Z)
	end
	local function apply(A, v)
		return V(A[1][1] * v.X + A[1][2] * v.Y + A[1][3] * v.Z, A[2][1] * v.X + A[2][2] * v.Y + A[2][3] * v.Z, A[3][1] * v.X + A[3][2] * v.Y + A[3][3] * v.Z)
	end
	local function euler(M) -- Rx · Ry · Rz 분해(도)
		local ry = math.asin(math.clamp(M[1][3], -1, 1))
		return V(math.deg(math.atan2(-M[2][3], M[3][3])), math.deg(ry), math.deg(math.atan2(-M[1][2], M[1][1])))
	end
	local J, world = {}, { HumanoidRootPart = { R = E(Vector3.zero), c = Vector3.zero } }
	-- 세계 자리로 부위 하나: o = { name, parent, part, center, size, joint, rot(세계 도) · color · material · query }
	local function place(o)
		local par = world[o.parent]
		local Rw = E(o.rot or Vector3.zero)
		world[o.part] = { R = Rw, c = o.center }
		return add(J, { name = o.name, parent = o.parent, part = o.part, size = o.size, color = o.color or "body", material = o.material, query = o.query,
			at = applyT(par.R, o.joint - par.c), pivot = applyT(Rw, o.joint - o.center), rot = euler(mulT(par.R, Rw)) })
	end
	-- 팔 마디: 관절 a → 끝 b(m 단위) · 상자 길이 = 거리 + ext · 세계 회전 = (0, −1, 0)을 a→b로(rz = 바깥 · rx = 앞)
	local function seg(name, parent, part, a, b, w, d, ext, color)
		local pa, pb = P(a[1], a[2], a[3]), P(b[1], b[2], b[3])
		local dir = (pb - pa).Unit
		local rz = math.deg(math.asin(dir.X))
		local rx = math.deg(math.atan2(-dir.Z, -dir.Y))
		local len = (pb - pa).Magnitude + K * ext
		return place({ name = name, parent = parent, part = part, joint = pa, center = pa + dir * (len / 2 - K * ext * 0.25), size = V(K * w, len, K * d), rot = V(rx, 0, rz), color = color })
	end
	place({ name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", center = P(0, 2.55, -0.1), size = Z(4.0, 1.3, 3.0), joint = P(0, 2.55, 0), color = "dark" })
	place({ name = "Waist", parent = "Hips", part = "Body", center = P(0, 5.3, -0.35), size = Z(5.0, 4.6, 4.0), joint = P(0, 3.2, -0.2), query = true })
	place({ name = "Neck", parent = "Body", part = "Head", center = P(0, 7.95, 1.6), size = Z(2.8, 3.0, 2.9), joint = P(0, 6.9, 0.7), color = "head", query = true })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		place({ name = "Hip_" .. side, parent = "Hips", part = "Thigh_" .. side, center = P(x * 1.55, 2.15, -0.05), size = Z(1.8, 1.1, 1.9), joint = P(x * 1.5, 2.6, -0.05) })
		place({ name = "Knee_" .. side, parent = "Thigh_" .. side, part = "Shin_" .. side, center = P(x * 1.65, 1.25, -0.05), size = Z(1.75, 0.9, 1.8), joint = P(x * 1.6, 1.65, 0), color = "dark" })
		place({ name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, center = P(x * 1.8, 0.42, 0.15), size = Z(2.1, 0.85, 2.5), joint = P(x * 1.7, 0.8, -0.1), color = "dark" })
		seg("Shoulder_" .. side, "Body", "UpperArm_" .. side, { x * 2.9, 6.3, 0 }, { x * 4.6, 4.5, 0.3 }, 2.3, 2.4, 0.5)
		seg("Elbow_" .. side, "UpperArm_" .. side, "Forearm_" .. side, { x * 4.6, 4.5, 0.3 }, { x * 5.25, 2.35, 1.35 }, 3.2, 2.9, 0.5, "head")
		seg("Wrist_" .. side, "Forearm_" .. side, "Hand_" .. side, { x * 5.25, 2.35, 1.35 }, { x * 5.0, 0.3, 2.1 }, 3.1, 3.0, 0.2, "head")
		place({ name = "Pauldron_" .. side, parent = "UpperArm_" .. side, part = side == "L" and "LeftPauldron" or "RightPauldron", center = P(x * 3.35, 6.65, -0.1), size = Z(2.2, 2.0, 2.8), joint = P(x * 3.0, 6.6, 0), color = "head" })
	end
	-- 얼굴: 눈(Neon · KIT 생성 - 평소 모양 · 화남 · 헤롱 조각은 장식으로 같은 부위에) · 턱(자리만) · 눈썹 바위(Meshy 눈썹 - 표정)
	place({ name = "Eyes", parent = "Head", part = "Eyes", center = P(0, 7.92, 2.56), size = Z(1.7, 0.6, 0.12), joint = P(0, 7.92, 2.56), color = Color3.fromRGB(205, 90, 255), material = "Neon" }) -- Neon 색 = 가장 낮은 채널 ≤ 90(흰 날림 방지)
	place({ name = "Jaw", parent = "Head", part = "Mouth", center = P(0, 7.0, 2.6), size = Z(0.6, 0.2, 0.1), joint = P(0, 7.0, 2.6), color = "mouth" })
	place({ name = "Brow", parent = "Head", part = "Brow", center = P(0, 8.45, 2.45), size = Z(2.5, 0.55, 0.7), joint = P(0, 8.5, 2.1), color = "slab" })
	place({ name = "Rune", parent = "Body", part = "Rune", center = P(0, 4.15, 1.86), size = Z(1.0, 1.8, 0.14), joint = P(0, 4.15, 1.86), color = Color3.fromRGB(185, 70, 255), material = "Neon" })
	place({ name = "TassetF", parent = "Hips", part = "TassetF", center = P(0, 2.2, 1.35), size = Z(2.6, 1.2, 0.5), joint = P(0, 2.75, 1.3), color = "slab" })
	place({ name = "TassetB", parent = "Hips", part = "TassetB", center = P(0, 2.3, -1.55), size = Z(2.8, 1.3, 0.5), joint = P(0, 2.9, -1.5), color = "slab" })
	-- 등 수정 5(Meshy 등 수정 무리 실측 - 가운데 큰 것 · 왼쪽 큰 것 · 오른쪽 큰 것(더 눕힘) · 둥근 작은 것 둘) · 관절 = 밑동(흔들림 · 50% 터짐)
	--   가운데 · 큰 쌍 = Neon(Meshy 수정 면 그대로 빛 - 색 = 텍스처 평균에서 가장 낮은 채널 ≤ 90) · 둥근 둘 = 텍스처
	local GLOW = Color3.fromRGB(225, 90, 255)
	local function crystal(name, center, size, rot, glow)
		local c = P(center[1], center[2], center[3])
		local base = c - apply(E(rot), V(0, K * size[2] / 2, 0))
		return place({ name = name, parent = "Body", part = name, center = c, size = Z(size[1], size[2], size[3]), joint = base, rot = rot, color = glow and GLOW or "accent", material = glow and "Neon" or nil })
	end
	crystal("Crystal1", { 0, 7.35, -2.65 }, { 1.2, 3.2, 1.2 }, V(20, 0, 0), true)
	crystal("Crystal2", { -2.0, 8.0, -1.75 }, { 1.5, 4.0, 1.5 }, V(12, 0, 20), true)
	crystal("Crystal3", { 2.65, 7.9, -1.7 }, { 1.5, 4.0, 1.5 }, V(12, 0, -35), true)
	crystal("Crystal4", { -1.6, 5.9, -2.45 }, { 1.1, 1.1, 1.1 }, V(30, 0, 0))
	crystal("Crystal5", { 1.6, 6.0, -2.4 }, { 1.1, 1.1, 1.1 }, V(30, 0, 0))
	D.rigs.section_guardian_v2 = {
		bossId = "section_guardian", variant = "v2", status = "trial", plan = "biped", joints = J, accent = Color3.fromRGB(190, 110, 255),
		-- 바이블 §5 크기 × 1.5(MonsterSpawner · 전시 리그가 S × scale) → GUARDIAN-V3 6(사용자): 서 있는 키 약 30 stud = 직립(변신 뒤) 머리 꼭대기 FK 실측
		--   × 1.92에서 28.6(Studio 28.7 ~ 29.0) → 2.0에서 29.8. K(0.40)를 바꾸면 메시를 다시 굽고 올려야 한다 - K와 scale은 둘 다 균일 배율이라 결과가 같아 scale로 맞춘다
		--   (판정 사본 · 몸 가장자리 · 모션 이동이 같이 커진다).
		scale = 2.0,
		edgeHalfWidth = K * 4.45, -- 몸 가장자리 반폭(어깨 갑옷 바깥 - 리그 단위 · BossFramework.edgeGrowth)
		baseEdgeHalfWidth = 2.1, -- 옛 몸(BossRigSpec section_guardian) 가장자리 반폭 = 어깨 1.5 + 갑옷 0.1 + 0.5
		cameraZoomScale = 1.73, -- 바이블 §5-4 카메라 줌 × 약 1.3(크기 × 1.5일 때) → GUARDIAN-V3: 크기 비례 1.3 × 2.0 ÷ 1.5 = 1.73(CameraRig)
		attach = { HandR = { part = "Hand_R", at = V(0, -0.35, 0) }, HandL = { part = "Hand_L", at = V(0, -0.35, 0) }, Mouth = { part = "Head", at = V(0, -0.3, -0.5) }, Chest = { part = "Body", at = V(0, -0.45, -0.85) },
			ShoulderR = { part = "RightPauldron", at = V(0, 0.4, 0) }, ShoulderL = { part = "LeftPauldron", at = V(0, 0.4, 0) }, Back = { part = "Crystal1", at = V(0, 0.6, 0) } },
		chains = {
			{ "TassetF", kind = "crystal", lag = 0.5, sway = 1.2 }, { "TassetB", kind = "crystal", lag = 0.5, sway = 1.2 },
			{ "Crystal1", kind = "crystal", lag = 0.3, sway = 1.5 }, { "Crystal2", kind = "crystal", lag = 0.3, sway = 1.5 }, { "Crystal3", kind = "crystal", lag = 0.3, sway = 1.5 },
			{ "Crystal4", kind = "crystal", lag = 0.3, sway = 2 }, { "Crystal5", kind = "crystal", lag = 0.3, sway = 2 },
		},
		weight = 1.15,
		meshKey = "bosses/section_guardian_v2m", -- KIT 결과(Meshy 원본 · 옛 가짜 원본 시험 = bosses/section_guardian_v2 그대로 남김)
		themeColors = { body = Color3.fromRGB(60, 20, 70), head = Color3.fromRGB(90, 30, 100), accent = Color3.fromRGB(190, 110, 255) },
		recolor = { Hips = "shadow", Shin_L = "shadow", Shin_R = "shadow", Foot_L = "stone", Foot_R = "stone", UpperArm_L = "stone", UpperArm_R = "stone" },
	}
end

-- ─────────────────────────── BOSS-NIGHT-1 공용: Meshy 실측 좌표로 부위 놓기(수호자 v2와 같은 규칙 - 그 블록은 그대로 둔다) ───────────────────────────
--   K = 실측 단위(Meshy 모델 높이 1 = "H") → 리그 단위 · P(x, z, fwd) = 오른쪽 x · 높이 z(발바닥 0) · 앞 fwd(+ = 앞 = 리그 −Z).
--   place{ name, parent, part, center, size, joint, rot(세계 도) } · seg(관절 a → 끝 b 막대) · chainPts(점 목록 → 사슬 마디).
local function placer(K)
	local L = {}
	function L.P(x, z, fwd)
		return V(K * x, K * z - 1.5, -K * fwd)
	end
	function L.Z(w, h, d)
		return V(K * w, K * h, K * d)
	end
	local function E(r)
		local cx, sx, cy, sy, cz, sz = math.cos(math.rad(r.X)), math.sin(math.rad(r.X)), math.cos(math.rad(r.Y)), math.sin(math.rad(r.Y)), math.cos(math.rad(r.Z)), math.sin(math.rad(r.Z))
		return {
			{ cy * cz, -cy * sz, sy },
			{ cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy },
			{ sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy },
		}
	end
	local function mulT(A, B)
		local M = {}
		for i = 1, 3 do
			M[i] = {}
			for j = 1, 3 do
				M[i][j] = A[1][i] * B[1][j] + A[2][i] * B[2][j] + A[3][i] * B[3][j]
			end
		end
		return M
	end
	local function applyT(A, v)
		return V(A[1][1] * v.X + A[2][1] * v.Y + A[3][1] * v.Z, A[1][2] * v.X + A[2][2] * v.Y + A[3][2] * v.Z, A[1][3] * v.X + A[2][3] * v.Y + A[3][3] * v.Z)
	end
	local function euler(M)
		local ry = math.asin(math.clamp(M[1][3], -1, 1))
		return V(math.deg(math.atan2(-M[2][3], M[3][3])), math.deg(ry), math.deg(math.atan2(-M[1][2], M[1][1])))
	end
	L.J = {}
	local world = { HumanoidRootPart = { R = E(Vector3.zero), c = Vector3.zero } }
	-- 그 부위 국소 좌표에서 월드 아래쪽(배 · 땅 닿는 쪽) 점(접지 - 누운 꼬리 마디)
	function L.downOf(part, dist)
		local w = world[part]
		return applyT(w.R, V(0, -dist, 0))
	end
	function L.place(o)
		local par = world[o.parent]
		local Rw = E(o.rot or Vector3.zero)
		world[o.part] = { R = Rw, c = o.center }
		return add(L.J, { name = o.name, parent = o.parent, part = o.part, size = o.size, color = o.color or "body", material = o.material, query = o.query, shape = o.shape,
			at = applyT(par.R, o.joint - par.c), pivot = applyT(Rw, o.joint - o.center), rot = euler(mulT(par.R, Rw)) })
	end
	-- 막대 마디: 관절 a → 끝 b(실측 좌표) · 단면 w × d · 세계 회전 = (0, −1, 0)을 a → b로
	function L.seg(name, parent, part, a, b, w, d, ext, color, extra)
		local pa, pb = L.P(a[1], a[2], a[3]), L.P(b[1], b[2], b[3])
		local dir = (pb - pa).Unit
		local rz = math.deg(math.asin(math.clamp(dir.X, -1, 1)))
		local rx = math.deg(math.atan2(-dir.Z, -dir.Y))
		local len = (pb - pa).Magnitude + K * (ext or 0)
		local o = { name = name, parent = parent, part = part, joint = pa, center = pa + dir * (len / 2 - K * (ext or 0) * 0.25), size = V(K * w, len, K * d), rot = V(rx, 0, rz), color = color }
		for k, v in pairs(extra or {}) do
			o[k] = v
		end
		return L.place(o)
	end
	-- 점 목록 → 사슬(prefix1 .. n): 마디 i = 점 i → 점 i + 1 · 굵기 w0 → w1
	function L.chainPts(prefix, parent, pts, w0, w1, d0, d1, color, extra)
		local prev = parent
		for i = 1, #pts - 1 do
			local u = (i - 1) / math.max(#pts - 2, 1)
			local w, d = w0 + (w1 - w0) * u, (d0 or w0) + ((d1 or w1) - (d0 or w0)) * u
			L.seg(prefix .. i, prev, prefix .. i, pts[i], pts[i + 1], w, d, 0.02, color, extra)
			prev = prefix .. i
		end
	end
	return L
end
D.placer = placer

-- ─────────────────────────── 서리 거인 → 빙하 매머드 "빙하 엄니"(BOSS-NIGHT-1 1 · Meshy 원본 실측 · 네 발) ───────────────────────────
-- 상자 · 관절 = Meshy mammoth_v1_body(remesh30k · 원본과 같은 모양) 옆 · 앞 · 위 실측(모델 높이 1 = H · 발바닥 0 · fwd + = 머리 쪽).
--   K 2.4 = 판정 사본(Body · Hips · Head) 부피 = 옛 몸 × 1.14(허용 ±20%) · scale 3.3 = 등 높이(0.85 H) 30 stud(바이블 §5 × 1.5 목표 - 수호자 V3처럼 K 대신 scale로 크기).
--   다리 = 짧고 굵은 인형 비율(보이는 다리 0.15 H) · 앞다리 Shoulder · Elbow · Wrist(Hand = 앞발) · 뒷다리 Hip · Knee · Ankle(quad 보행 이름) ·
--   코 6마디(평면 자르기 = 리그 상자) · 상아 L/R 밑동 분리 · 귀 L/R · 꼬리 3(말린 꼬리) · 등 털 3(사슬) · 등 얼음 1(낙빙 흔들림) · 이마 털 얼음 1 · 턱(자리만).
--   앞 구역(상아 · 코 · 앞발) / 뒤 구역(뒷발차기) = 판정 구역은 스킬 데이터(BossFrameworkData.v3.frost_giant).
do
	local L = placer(2.4)
	local P, Z, place, seg, chainPts = L.P, L.Z, L.place, L.seg, L.chainPts
	place({ name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", center = P(0, 0.48, -0.3), size = Z(0.6, 0.66, 0.5), joint = P(0, 0.48, -0.08), query = true })
	place({ name = "Waist", parent = "Hips", part = "Body", center = P(0, 0.5, 0.15), size = Z(0.62, 0.7, 0.42), joint = P(0, 0.5, -0.06), query = true })
	place({ name = "Neck", parent = "Body", part = "Head", center = P(0, 0.68, 0.45), size = Z(0.36, 0.4, 0.3), joint = P(0, 0.7, 0.3), color = "head", query = true })
	place({ name = "Jaw", parent = "Head", part = "Mouth", center = P(0, 0.47, 0.52), size = Z(0.08, 0.03, 0.05), joint = P(0, 0.49, 0.5), color = "mouth" })
	place({ name = "HeadIce", parent = "Head", part = "HeadIce", center = P(0, 0.91, 0.47), size = Z(0.16, 0.1, 0.14), joint = P(0, 0.86, 0.47), color = "accent" })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		place({ name = "Ear_" .. side, parent = "Head", part = "Ear_" .. side, center = P(x * 0.275, 0.58, 0.23), size = Z(0.12, 0.4, 0.3), joint = P(x * 0.2, 0.66, 0.3), color = "head" })
		seg("Tusk_" .. side, "Head", "Tusk_" .. side, { x * 0.09, 0.46, 0.55 }, { x * 0.22, 0.5, 0.88 }, 0.08, 0.16, 0.02, "light")
		-- 앞다리(앞발 = Hand) · 뒷다리(뒷발 = Foot) - 발바닥 0
		seg("Shoulder_" .. side, "Body", "UpperArm_" .. side, { x * 0.19, 0.34, 0.15 }, { x * 0.19, 0.17, 0.15 }, 0.17, 0.18, 0.02)
		seg("Elbow_" .. side, "UpperArm_" .. side, "Forearm_" .. side, { x * 0.19, 0.17, 0.15 }, { x * 0.19, 0.08, 0.15 }, 0.16, 0.17, 0.02)
		place({ name = "Wrist_" .. side, parent = "Forearm_" .. side, part = "Hand_" .. side, center = P(x * 0.19, 0.04, 0.16), size = Z(0.18, 0.08, 0.2), joint = P(x * 0.19, 0.08, 0.15), color = "dark" })
		seg("Hip_" .. side, "Hips", "Thigh_" .. side, { x * 0.19, 0.34, -0.38 }, { x * 0.19, 0.17, -0.38 }, 0.17, 0.18, 0.02)
		seg("Knee_" .. side, "Thigh_" .. side, "Shin_" .. side, { x * 0.19, 0.17, -0.38 }, { x * 0.19, 0.08, -0.38 }, 0.16, 0.17, 0.02)
		place({ name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, center = P(x * 0.19, 0.04, -0.37), size = Z(0.18, 0.08, 0.2), joint = P(x * 0.19, 0.08, -0.38), color = "dark" })
	end
	-- 코 6마디(코끝 말림까지) · 꼬리 3(말린 꼬리) · 등 털 3(등 위 판 - 사슬) · 등 얼음 덩어리
	chainPts("Trunk", "Head", { { 0, 0.56, 0.58 }, { 0, 0.46, 0.62 }, { 0, 0.36, 0.61 }, { 0, 0.27, 0.59 }, { 0, 0.19, 0.56 }, { 0, 0.12, 0.52 }, { 0, 0.05, 0.47 } }, 0.13, 0.08, 0.13, 0.08, "head")
	chainPts("Tail", "Hips", { { 0, 0.56, -0.54 }, { 0, 0.56, -0.66 }, { 0, 0.5, -0.77 }, { 0, 0.4, -0.8 } }, 0.12, 0.1, 0.2, 0.2, "body")
	place({ name = "Fur1", parent = "Body", part = "Fur1", center = P(0, 0.83, 0.14), size = Z(0.5, 0.1, 0.22), joint = P(0, 0.83, 0.25), color = "light" })
	place({ name = "Fur2", parent = "Fur1", part = "Fur2", center = P(0, 0.85, -0.1), size = Z(0.52, 0.1, 0.26), joint = P(0, 0.85, 0.03), color = "light" })
	place({ name = "Fur3", parent = "Fur2", part = "Fur3", center = P(0, 0.8, -0.36), size = Z(0.5, 0.1, 0.26), joint = P(0, 0.83, -0.23), color = "light" })
	place({ name = "BackIce", parent = "Fur2", part = "BackIce", center = P(0, 0.93, -0.17), size = Z(0.24, 0.16, 0.28), joint = P(0, 0.87, -0.17), color = "accent" })
	D.rigs.frost_giant_v2 = {
		bossId = "frost_giant", variant = "v2", status = "trial", plan = "quad", joints = L.J, accent = Color3.fromRGB(200, 240, 255),
		scale = 3.3, -- 등 높이 0.85 H × K 2.4 × S 4.455 × 3.3 = 30 stud(바이블 §5)
		edgeHalfWidth = 2.4 * 0.31, -- 몸 가장자리 반폭(옆구리 털 바깥 - 리그 단위)
		frontHalfLength = 2.4 * 0.62, rearHalfLength = 2.4 * 0.56, -- 몸 중심(루트) → 머리 · 코 앞 끝 / 엉덩이 끝(앞 구역 · 뒤 구역 반경 - BossFramework.applyV3 radiusFrom)
		baseEdgeHalfWidth = 1.6, -- 옛 몸(서리 거인 직립) 가장자리 반폭 = 몸 0.95 + 팔 0.65
		cameraZoomScale = 1.3, -- 38 → 49.4(설계 메모: 50 상한)
		attach = { HandR = { part = "Trunk6", at = V(0, -0.1, 0) }, HandL = { part = "Tusk_L", at = V(0, -0.35, 0) }, ShoulderR = { part = "Tusk_R", at = V(0, -0.35, 0) }, ShoulderL = { part = "BackIce", at = V(0, 0.2, 0) },
			Mouth = { part = "Head", at = V(0, -0.25, -0.35) }, TuskTipL = { part = "Tusk_L", at = V(0, -0.4, 0) }, TuskTipR = { part = "Tusk_R", at = V(0, -0.4, 0) }, Back = { part = "BackIce", at = V(0, 0.2, 0) } },
		chains = { { "Trunk1", "Trunk2", "Trunk3", "Trunk4", "Trunk5", "Trunk6", kind = "trunk", lag = 0.5, sway = 6 }, { "Tail1", "Tail2", "Tail3", kind = "tail", lag = 0.5, sway = 5 },
			{ "Fur1", "Fur2", "Fur3", kind = "fur", lag = 0.55, sway = 2 }, { "Ear_L", kind = "cloth", lag = 0.5, sway = 4 }, { "Ear_R", kind = "cloth", lag = 0.5, sway = 4 } },
		weight = 1.5,
		contacts = { "Foot_L", "Foot_R", "Hand_L", "Hand_R" },
		meshKey = "bosses/frost_giant_v2m",
		themeColors = { body = Color3.fromRGB(235, 240, 248), head = Color3.fromRGB(225, 232, 242), accent = Color3.fromRGB(150, 215, 255) },
	}
end

-- ─────────────────────────── 심해 군주 → 나가(BOSS-NIGHT-1 3 · Meshy 원본 실측 · 뱀 하체 12마디 · 삼지창 = 키 × 1.1) ───────────────────────────
-- 상자 · 관절 = Meshy abyssal_v1_meshy71 정면 · 옆 · 위 실측(높이 1 = H · 상체 세운 키). Meshy 꼬리 = 허리 밑에서 내려와 오른쪽 → 뒤 → 왼쪽으로 감기고 지느러미가 왼쪽 뒤에서 솟음
--   (실측 x는 정면 그림의 반대 - yaw 180). K 7.1 = 판정 사본(Body · Head) 부피 = 옛 몸 × 1.10 · 키 7.1 × S 3.6 = 25.6 stud = 바이블 §5 "상체 약 25"(scale 1.0).
--   삼지창 = 오른손 자식 · 길이 1.1 H(약 28 stud) · 자루 굵게(KIT 상자 폭) · 창날 = 위 0.2 H. 접지 = 바닥에 누운 꼬리 마디 배 쪽(downOf).
do
	local L = placer(7.1)
	local P, Z, place, seg, chainPts = L.P, L.Z, L.place, L.seg, L.chainPts
	place({ name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", center = P(0, 0.44, 0.2), size = Z(0.22, 0.12, 0.2), joint = P(0, 0.46, 0.2), color = "dark" })
	place({ name = "Waist", parent = "Hips", part = "Body", center = P(0, 0.63, 0.2), size = Z(0.26, 0.3, 0.2), joint = P(0, 0.5, 0.2), query = true })
	place({ name = "Neck", parent = "Body", part = "Head", center = P(0, 0.86, 0.21), size = Z(0.15, 0.16, 0.15), joint = P(0, 0.79, 0.2), color = "head", query = true })
	place({ name = "Crest", parent = "Head", part = "BackFin", center = P(0, 0.96, 0.18), size = Z(0.2, 0.08, 0.13), joint = P(0, 0.93, 0.18), color = "accent" })
	place({ name = "Jaw", parent = "Head", part = "Mouth", center = P(0, 0.81, 0.28), size = Z(0.05, 0.02, 0.03), joint = P(0, 0.82, 0.27), color = "mouth" })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		place({ name = "Fin_" .. side, parent = "Head", part = side == "L" and "LeftFin" or "RightFin", center = P(x * 0.1, 0.9, 0.18), size = Z(0.07, 0.1, 0.1), joint = P(x * 0.07, 0.88, 0.19), color = "accent" })
		seg("Shoulder_" .. side, "Body", "UpperArm_" .. side, { x * 0.17, 0.72, 0.2 }, { x * 0.27, 0.58, 0.22 }, 0.09, 0.09, 0.02)
		seg("Elbow_" .. side, "UpperArm_" .. side, "Forearm_" .. side, { x * 0.27, 0.58, 0.22 }, { x * 0.33, 0.45, 0.22 }, 0.085, 0.085, 0.02)
		seg("Wrist_" .. side, "Forearm_" .. side, "Hand_" .. side, { x * 0.33, 0.45, 0.22 }, { x * 0.34, 0.38, 0.23 }, 0.07, 0.06, 0.01)
	end
	-- 뱀 꼬리 12마디(허리 밑 → 바닥 → 오른쪽 · 뒤 · 왼쪽으로 감김) + 꼬리 지느러미
	local tailPts = { { 0, 0.38, 0.2 }, { -0.05, 0.2, 0.22 }, { -0.15, 0.07, 0.2 }, { -0.3, 0.06, 0.08 }, { -0.35, 0.06, -0.08 }, { -0.3, 0.06, -0.2 }, { -0.18, 0.05, -0.3 },
		{ -0.02, 0.05, -0.33 }, { 0.12, 0.06, -0.32 }, { 0.22, 0.08, -0.3 }, { 0.29, 0.12, -0.3 }, { 0.33, 0.2, -0.3 }, { 0.35, 0.27, -0.3 } }
	chainPts("Tail", "Hips", tailPts, 0.2, 0.08, 0.17, 0.08, "body")
	place({ name = "TailFin", parent = "Tail12", part = "TailFin", center = P(0.3, 0.22, -0.31), size = Z(0.14, 0.24, 0.16), joint = P(0.34, 0.24, -0.3), color = "accent" })
	-- 삼지창(오른손 · 땅에서 키 × 1.1 높이까지) · 창날
	place({ name = "Trident", parent = "Hand_R", part = "Trident", center = P(0.36, 0.42, 0.24), size = Z(0.09, 0.9, 0.09), joint = P(0.345, 0.4, 0.23), color = "accent" })
	place({ name = "TridentHead", parent = "Trident", part = "TridentHead", center = P(0.36, 0.97, 0.24), size = Z(0.32, 0.24, 0.08), joint = P(0.36, 0.87, 0.24), color = "accent" })
	local tail = { kind = "tail", lag = 0.45, sway = 6 }
	for i = 1, 12 do
		tail[i] = "Tail" .. i
	end
	local contacts = {}
	for _, i in ipairs({ 5, 6, 7 }) do -- 바닥에 누운 마디(꼬리 시작 · 끝은 들림)
		table.insert(contacts, { part = "Tail" .. i, at = L.downOf("Tail" .. i, 7.1 * 0.085) })
	end
	D.rigs.abyssal_lord_v2 = {
		bossId = "abyssal_lord", variant = "v2", status = "trial", plan = "serpent", joints = L.J, accent = Color3.fromRGB(60, 200, 255),
		scale = 1.0, -- 상체 세운 키 = 1 H × K 7.1 × S 3.6 = 25.6 stud(바이블 §5)
		edgeHalfWidth = 7.1 * 0.2, -- 몸 가장자리 반폭(어깨 갑옷 바깥)
		baseEdgeHalfWidth = 1.6, -- 옛 몸(심해 군주) = 어깨 1.42 + 0.18
		cameraZoomScale = 1.3,
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0, 0.3, 0) }, ShoulderL = { part = "UpperArm_L", at = V(0, 0.3, 0) }, HandR = { part = "Hand_R", at = V(0, -0.2, 0) }, HandL = { part = "Hand_L", at = V(0, -0.2, 0) },
			Mouth = { part = "Head", at = V(0, -0.3, -0.5) }, TailTip = { part = "Tail12", at = V(0, -0.3, 0) }, TridentTip = { part = "TridentHead", at = V(0, 0.5, 0) } },
		chains = { tail, { "Crest", kind = "fur", lag = 0.4, sway = 3 }, { "Fin_L", kind = "fur", lag = 0.4, sway = 4 }, { "Fin_R", kind = "fur", lag = 0.4, sway = 4 } },
		weight = 1.1,
		contacts = contacts,
		meshKey = "bosses/abyssal_lord_v2m",
		themeColors = { body = Color3.fromRGB(40, 150, 150), head = Color3.fromRGB(230, 225, 215), accent = Color3.fromRGB(60, 200, 255) },
	}
end

-- ─────────────────────────── 수정 여왕 → 수정 나비 여왕(BOSS-NIGHT-1 4 · Meshy 몸 + 날개 + 홀 · 떠 있음 · 바이블 §2-2 · §8) ───────────────────────────
-- 상자 · 관절 = Meshy crystal_v1_body 정면 · 옆 실측(높이 1 = H · 더듬이 끝 포함 · 턱 0.70 · 어깨 0.68 · 손 0.43 ~ 0.49 = KIT 첫 굽기 부위 경계에서 다시 잼). K 7.0 = 판정 사본(Body · Head) 부피 = 옛 몸 × 1.10 · scale 1.15 = 키 약 29 stud(§5).
--   §8 노출 기준: Meshy 몸은 짧은 꽃잎 치마 + 무릎 블루머 + 맨 정강이 → KIT가 허리 → 발목 위까지 **닫힌 종 모양 치마(Skirt · 안팎 양면 · 드레스색)**를 새로 만들어 덮는다(다리는 발목 아래만).
--   날개 = 날개 GLB 한 장(위 · 아래 날개 L/R) → 위 날개 2마디 · 아래 날개 2마디 × 좌우 = 8. 홀 = 오른손 자식(보석 따로).
do
	local L = placer(7.0)
	local P, Z, place, seg, chainPts = L.P, L.Z, L.place, L.seg, L.chainPts
	local DRESS = Color3.fromRGB(165, 125, 215)
	place({ name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", center = P(0, 0.5, 0), size = Z(0.16, 0.08, 0.1), joint = P(0, 0.52, 0), color = "dark" })
	place({ name = "Waist", parent = "Hips", part = "Body", center = P(0, 0.6125, 0.005), size = Z(0.18, 0.145, 0.12), joint = P(0, 0.54, 0), query = true })
	place({ name = "Neck", parent = "Body", part = "Head", center = P(0, 0.81, 0.02), size = Z(0.19, 0.22, 0.21), joint = P(0, 0.695, 0), color = "head", query = true, shape = "ball" }) -- 판정 사본 = 공(부피 옛 몸 × 1.0 · KIT 자르기는 상자 그대로)
	place({ name = "Hair", parent = "Head", part = "Hair", center = P(0, 0.66, -0.1), size = Z(0.26, 0.4, 0.1), joint = P(0, 0.84, -0.06), color = "head" })
	place({ name = "Crown", parent = "Head", part = "Crown", center = P(0, 0.925, 0.0), size = Z(0.12, 0.05, 0.1), joint = P(0, 0.905, 0), color = "accent" })
	place({ name = "ChestGem", parent = "Body", part = "ChestGem", center = P(0, 0.6, 0.08), size = Z(0.05, 0.05, 0.03), joint = P(0, 0.6, 0.07), color = "accent" }) -- 드레스 보석(텍스처 - Neon 단색은 가슴 면을 통째로 덮었다)
	place({ name = "Skirt", parent = "Hips", part = "Skirt", center = P(0, 0.31, 0), size = Z(0.48, 0.5, 0.48), joint = P(0, 0.55, 0), color = DRESS })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		seg("Hip_" .. side, "Hips", "Thigh_" .. side, { x * 0.05, 0.5, 0 }, { x * 0.05, 0.26, 0.005 }, 0.08, 0.08, 0.02)
		seg("Knee_" .. side, "Thigh_" .. side, "Shin_" .. side, { x * 0.05, 0.26, 0.005 }, { x * 0.045, 0.05, 0 }, 0.07, 0.07, 0.02, "dark")
		place({ name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, center = P(x * 0.045, 0.02, 0.02), size = Z(0.06, 0.04, 0.09), joint = P(x * 0.045, 0.05, 0), color = "dark" })
		seg("Shoulder_" .. side, "Body", "UpperArm_" .. side, { x * 0.07, 0.68, 0 }, { x * 0.16, 0.58, 0 }, 0.05, 0.05, 0.01)
		seg("Elbow_" .. side, "UpperArm_" .. side, "Forearm_" .. side, { x * 0.16, 0.58, 0 }, { x * 0.215, 0.49, 0.01 }, 0.045, 0.045, 0.01)
		seg("Wrist_" .. side, "Forearm_" .. side, "Hand_" .. side, { x * 0.215, 0.49, 0.01 }, { x * 0.26, 0.435, 0.02 }, 0.045, 0.035, 0.01)
		place({ name = "Antenna_" .. side, parent = "Head", part = "Antenna_" .. side, center = P(x * 0.04, 0.96, 0.0), size = Z(0.03, 0.08, 0.03), joint = P(x * 0.035, 0.92, 0), color = "accent" })
		-- 날개(등 위쪽): 위 날개(크다) 안 · 밖 / 아래 날개 안 · 밖
		place({ name = "WingF_" .. side .. "1", parent = "Body", part = "WingF_" .. side .. "1", center = P(x * 0.11, 0.87, -0.1), size = Z(0.18, 0.34, 0.06), joint = P(x * 0.03, 0.74, -0.08), color = "accent" })
		place({ name = "WingF_" .. side .. "2", parent = "WingF_" .. side .. "1", part = "WingF_" .. side .. "2", center = P(x * 0.31, 0.87, -0.11), size = Z(0.22, 0.34, 0.06), joint = P(x * 0.2, 0.84, -0.1), color = "accent" })
		place({ name = "WingB_" .. side .. "1", parent = "Body", part = "WingB_" .. side .. "1", center = P(x * 0.085, 0.56, -0.1), size = Z(0.13, 0.28, 0.06), joint = P(x * 0.03, 0.68, -0.08), color = "accent" })
		place({ name = "WingB_" .. side .. "2", parent = "WingB_" .. side .. "1", part = "WingB_" .. side .. "2", center = P(x * 0.225, 0.56, -0.11), size = Z(0.15, 0.28, 0.06), joint = P(x * 0.15, 0.6, -0.1), color = "accent" })
	end
	-- 홀(오른손 · 손 아래로 0.25 · 위로 0.35) + 보석
	place({ name = "Scepter", parent = "Hand_R", part = "Scepter", center = P(0.285, 0.43, 0.04), size = Z(0.05, 0.5, 0.05), joint = P(0.275, 0.45, 0.03), color = "head" })
	place({ name = "ScepterGem", parent = "Scepter", part = "ScepterGem", center = P(0.285, 0.74, 0.04), size = Z(0.3, 0.12, 0.08), joint = P(0.285, 0.69, 0.04), color = "accent" })
	local chains = {}
	for _, w in ipairs({ "WingF_L", "WingF_R", "WingB_L", "WingB_R" }) do
		table.insert(chains, { w .. "1", w .. "2", kind = "wing", lag = 0.4, sway = 3 })
	end
	table.insert(chains, { "Hair", kind = "cloth", lag = 0.5, sway = 2 })
	table.insert(chains, { "Skirt", kind = "cloth", lag = 0.5, sway = 1.5 })
	table.insert(chains, { "Antenna_L", kind = "fur", lag = 0.3, sway = 5 })
	table.insert(chains, { "Antenna_R", kind = "fur", lag = 0.3, sway = 5 })
	D.rigs.crystal_queen_v2 = {
		bossId = "crystal_queen", variant = "v2", status = "trial", plan = "biped", joints = L.J, accent = Color3.fromRGB(150, 240, 255),
		scale = 1.15, -- 키 1 H × K 7.0 × S 3.6 × 1.15 = 29 stud(바이블 §5 · 떠 있음은 동작 세트 hover)
		edgeHalfWidth = 7.0 * 0.13, baseEdgeHalfWidth = 1.25, -- 몸 가장자리(머리카락 · 소매 바깥) - 옛 몸보다 좁으면 증가 0
		cameraZoomScale = 1.3,
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0, 0.2, 0) }, ShoulderL = { part = "UpperArm_L", at = V(0, 0.2, 0) }, HandR = { part = "Hand_R", at = V(0, -0.15, 0) }, HandL = { part = "Hand_L", at = V(0, -0.15, 0) },
			Mouth = { part = "Head", at = V(0, -0.2, -0.45) }, Gem = { part = "ScepterGem", at = V(0, 0, 0) }, Chest = { part = "ChestGem", at = V(0, 0, 0) } },
		chains = chains, weight = 0.8,
		meshKey = "bosses/crystal_queen_v2m",
		themeColors = { body = Color3.fromRGB(190, 160, 230), head = Color3.fromRGB(220, 210, 235), accent = Color3.fromRGB(150, 240, 255) },
	}
end

-- ─────────────────────────── 폭풍 군주 → 폭풍 기사 · 50% 비행 변신(BOSS-NIGHT-1 2 · Meshy 몸 + 부품 9 · 바이블 §2-5 · §10 · STORM-PARTS) ───────────────────────────
-- 상자 · 관절 = Meshy storm_v1_body(A-포즈 · 망토 없음) 정면 · 옆 실측(높이 1 = H · 발바닥 0 · fwd + = 앞). K 7.2 = 판정 사본(Body · Head) 부피 = 옛 몸 × 1.07 · scale 1.15 = 키 31 stud(§5).
--   1폼 = 몸 + 어깨 갑옷 · 번개 칼날(Pauldron_L/R) + 구름 깃(Plume) + 망토 4갈래 × 4마디(CapeA ~ D) + 지팡이 · 지팡이 보주(고리째 - 떨어져 떠다님).
--   2폼 = 망토 · 지팡이 · 1폼 어깨 · 아래팔 · 손 · 구름 깃 숨김 → 날개(Wing_L1 · L2 · R1 · R2) · 번개 왕관(Crown) · 가슴 코어(ChestCore) · 2폼 어깨(Pauldron2_L/R) · 건틀릿(Gauntlet_L/R - 아래팔 + 주먹)이 날아와 붙음.
--   부품 GLB → 상자 맞춤 = rigs/storm_lord_v2.kit.json(addons) · 보이기 전환 = BossClipSetData.storm_lord_v2.formParts(클라).
do
	local L = placer(7.2)
	local P, Z, place, seg, chainPts = L.P, L.Z, L.place, L.seg, L.chainPts
	place({ name = "RootJoint", parent = "HumanoidRootPart", part = "Hips", center = P(0, 0.47, 0), size = Z(0.22, 0.1, 0.12), joint = P(0, 0.49, 0), color = "dark" })
	place({ name = "Waist", parent = "Hips", part = "Body", center = P(0, 0.62, 0), size = Z(0.24, 0.3, 0.13), joint = P(0, 0.52, 0), query = true })
	place({ name = "Neck", parent = "Body", part = "Head", center = P(0, 0.85, 0.005), size = Z(0.13, 0.14, 0.13), joint = P(0, 0.79, 0), color = "head", query = true })
	place({ name = "Plume", parent = "Head", part = "Plume", center = P(0, 0.95, 0), size = Z(0.18, 0.11, 0.14), joint = P(0, 0.91, 0), color = "accent" })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		seg("Hip_" .. side, "Hips", "Thigh_" .. side, { x * 0.055, 0.47, 0 }, { x * 0.055, 0.3, 0.005 }, 0.09, 0.09, 0.02)
		seg("Knee_" .. side, "Thigh_" .. side, "Shin_" .. side, { x * 0.055, 0.3, 0.005 }, { x * 0.06, 0.07, 0 }, 0.08, 0.08, 0.02, "dark")
		place({ name = "Ankle_" .. side, parent = "Shin_" .. side, part = "Foot_" .. side, center = P(x * 0.06, 0.035, 0.065), size = Z(0.08, 0.07, 0.17), joint = P(x * 0.06, 0.07, 0), color = "dark" })
		seg("Shoulder_" .. side, "Body", "UpperArm_" .. side, { x * 0.15, 0.71, 0 }, { x * 0.225, 0.6, 0 }, 0.07, 0.07, 0.02)
		seg("Elbow_" .. side, "UpperArm_" .. side, "Forearm_" .. side, { x * 0.225, 0.6, 0 }, { x * 0.28, 0.52, 0 }, 0.065, 0.065, 0.02)
		seg("Wrist_" .. side, "Forearm_" .. side, "Hand_" .. side, { x * 0.28, 0.52, 0 }, { x * 0.305, 0.45, 0 }, 0.06, 0.05, 0.01)
		place({ name = "Pauldron_" .. side, parent = "UpperArm_" .. side, part = side == "L" and "LeftPauldron" or "RightPauldron", center = P(x * 0.17, 0.775, 0), size = Z(0.11, 0.23, 0.12), joint = P(x * 0.15, 0.71, 0), color = "head" })
		-- 2폼(숨김으로 시작): 어깨 · 건틀릿(아래팔 + 주먹 - 팔꿈치 관 자름)
		place({ name = "Pauldron2_" .. side, parent = "UpperArm_" .. side, part = "Pauldron2_" .. side, center = P(x * 0.185, 0.765, 0), size = Z(0.14, 0.17, 0.14), joint = P(x * 0.15, 0.71, 0), color = "head" })
		seg("Gauntlet_" .. side, "Forearm_" .. side, "Gauntlet_" .. side, { x * 0.225, 0.6, 0 }, { x * 0.31, 0.43, 0 }, 0.09, 0.09, 0.02, "head")
	end
	-- 로브(허리 갑옷 앞 · 뒤)
	place({ name = "RobeF", parent = "Hips", part = "RobeF", center = P(0, 0.445, 0.05), size = Z(0.22, 0.15, 0.04), joint = P(0, 0.52, 0.045), color = "body" })
	place({ name = "RobeB", parent = "Hips", part = "RobeB", center = P(0, 0.445, -0.05), size = Z(0.22, 0.15, 0.04), joint = P(0, 0.52, -0.045), color = "body" })
	-- 망토 4갈래 × 4마디(등 어깨 뒤 → 발목 위) - 1폼
	for i, x in ipairs({ -0.16, -0.055, 0.055, 0.16 }) do
		local tag = ({ "A", "B", "C", "D" })[i]
		chainPts("Cape" .. tag, "Body", { { x, 0.77, -0.085 }, { x * 1.05, 0.6, -0.1 }, { x * 1.1, 0.43, -0.11 }, { x * 1.15, 0.27, -0.12 }, { x * 1.2, 0.1, -0.13 } }, 0.105, 0.11, 0.06, 0.06, "dark")
	end
	-- 지팡이(오른손 · 땅 짚는 높이) + 보주(고리째)
	place({ name = "Staff", parent = "Hand_R", part = "Staff", center = P(0.31, 0.4, 0.03), size = Z(0.06, 0.66, 0.06), joint = P(0.305, 0.47, 0.02), color = "dark" })
	place({ name = "StaffOrb", parent = "Staff", part = "StaffOrb", center = P(0.31, 0.8, 0.03), size = Z(0.2, 0.14, 0.12), joint = P(0.31, 0.74, 0.03), color = "accent" })
	-- 2폼: 왕관 · 가슴 코어 · 날개 2 × 2
	place({ name = "Crown", parent = "Head", part = "Crown", center = P(0, 0.935, 0), size = Z(0.19, 0.15, 0.16), joint = P(0, 0.9, 0), color = "accent" })
	place({ name = "ChestCore", parent = "Body", part = "ChestCore", center = P(0, 0.66, 0.08), size = Z(0.16, 0.18, 0.03), joint = P(0, 0.66, 0.07), color = "accent" })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		place({ name = "Wing_" .. side .. "1", parent = "Body", part = "Wing_" .. side .. "1", center = P(x * 0.15, 0.82, -0.12), size = Z(0.22, 0.5, 0.06), joint = P(x * 0.05, 0.72, -0.1), color = "accent" })
		place({ name = "Wing_" .. side .. "2", parent = "Wing_" .. side .. "1", part = "Wing_" .. side .. "2", center = P(x * 0.4, 0.82, -0.13), size = Z(0.28, 0.5, 0.06), joint = P(x * 0.26, 0.82, -0.12), color = "accent" })
	end
	local cape = {}
	for _, tag in ipairs({ "A", "B", "C", "D" }) do
		table.insert(cape, { "Cape" .. tag .. "1", "Cape" .. tag .. "2", "Cape" .. tag .. "3", "Cape" .. tag .. "4", kind = "cape", lag = 0.5, sway = 5 })
	end
	table.insert(cape, { "Wing_L1", "Wing_L2", kind = "wing", lag = 0.4, sway = 3 })
	table.insert(cape, { "Wing_R1", "Wing_R2", kind = "wing", lag = 0.4, sway = 3 })
	table.insert(cape, { "RobeF", kind = "cloth", lag = 0.4, sway = 2 })
	table.insert(cape, { "RobeB", kind = "cloth", lag = 0.4, sway = 2 })
	D.rigs.storm_lord_v2 = {
		bossId = "storm_lord", variant = "v2", status = "trial", plan = "biped", joints = L.J, accent = Color3.fromRGB(255, 240, 90),
		scale = 1.15, -- 키 1 H × K 7.2 × S 3.75 × 1.15 = 31 stud(바이블 §5)
		edgeHalfWidth = 7.2 * 0.2, -- 몸 가장자리 반폭(어깨 갑옷 바깥)
		baseEdgeHalfWidth = 1.35, -- 옛 몸(폭풍 군주 직립) = 어깨 1.05 + 팔 0.3
		cameraZoomScale = 1.3,
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0, 0.2, 0) }, ShoulderL = { part = "UpperArm_L", at = V(0, 0.2, 0) }, HandR = { part = "Hand_R", at = V(0, -0.2, 0) }, HandL = { part = "Hand_L", at = V(0, -0.2, 0) },
			Mouth = { part = "Head", at = V(0, -0.2, -0.45) }, Orb = { part = "StaffOrb", at = V(0, 0, 0) }, FistR = { part = "Gauntlet_R", at = V(0, -0.5, 0) }, FistL = { part = "Gauntlet_L", at = V(0, -0.5, 0) } },
		chains = cape, weight = 1.0,
		meshKey = "bosses/storm_lord_v2m",
		themeColors = { body = Color3.fromRGB(40, 50, 90), head = Color3.fromRGB(190, 200, 215), accent = Color3.fromRGB(255, 225, 90) },
	}
end

return D

end

sources.BossRigSpec = function()
-- BR1-4b 보스 리그 규격(4b-1). 보스마다 부위(파트) · 관절(Motor6D 이름 · 계층) · 기준 자세 · 부착점 · 2차 움직임 사슬.
--   모션(shared/data/BossMotionData)은 **관절 이름으로만** 부위를 가리킨다 → A2에서 카툰 모델(메시)로 바꿔도 관절 이름 · 계층만 지키면 모션을 그대로 쓴다.
--   방식 = A1 리그 게이트(파트 + Motor6D · 클라가 Motor6D.Transform으로 절차 모션 - 업로드 없음). 루트(HumanoidRootPart)는 지금처럼 서버가 Anchored로 옮긴다(판정 위치 = 계산값 그대로) ·
--   나머지 부위는 Anchored 끔 + Motor6D로 루트에 묶인다(루트가 고정이라 물리 시뮬레이션 없음) · 부위는 전부 CanCollide · CanTouch 끔(판정 = 거리 기반 - 옛 몸통과 같다) ·
--   Body(몸통) · Head(머리) 이름은 그대로 둔다(조준 · 피해 숫자 · 이름표 · 색 바꾸기가 이 이름을 찾는다). 새 부위는 CanQuery도 끔(광선 판정에 새로 끼지 않게).
-- 단위: 좌표 · 크기는 sizeScale 1 기준(모델을 지을 때 BossData sizeScale을 곱한다). 루트 = (0, 0, 0) · 발바닥 = y −1.5(옛 몸통 바닥과 같은 자리) · 앞 = −Z.
-- 관절 표 = { name(Motor6D 이름), parent(부모 파트 이름), part(자식 파트 이름), size, shape("block" | "ball" | "wedge" | "cyl"), color("body" | "head" | "dark" | "accent" | "eye" | "mouth"),
--   material(선택 - "Neon" 등), at(부모 파트 공간의 관절 자리), pivot(자식 파트 공간의 관절 자리), rot(기준 자세 - 관절에서 자식이 돌아간 각 · 도), query(true = CanQuery 유지) }.
-- 모션 각 부호(A1 실측): 아래로 늘어진 부위를 X축 +θ 돌리면 앞으로 든다 · 무릎을 굽히면 X −θ · 허리 앞 숙임 X −θ · 고개 숙임 X −θ.
local BossRigSpec = {}

local V = Vector3.new

-- 두 발 몸 · 사슬 = shared/BossSkeleton(BOSS-FRAMEWORK 1 - 식 그대로 옮김 · 새 몸 구조 생성기와 같이 쓴다)
local BossSkeleton = require(script.Parent.Parent.BossSkeleton)
local biped, chain = BossSkeleton.biped, BossSkeleton.chain

local function add(J, j)
	table.insert(J, j)
	return J
end

-- ─────────────────────────── 보스 6종 ───────────────────────────
BossRigSpec.rigs = {}

-- 구간 수호자: 돌 골렘 - 굵은 팔 · 큰 주먹 · 어깨 갑주 · 가슴 룬(보스색 빛).
do
	local J = biped({
		hips = V(1.6, 0.5, 1.0), torso = V(2.4, 1.7, 1.3), head = V(1.1, 0.95, 1.0),
		thigh = { w = 0.75, len = 0.8 }, shin = { w = 0.7, len = 0.8 }, foot = V(0.8, 0.3, 1.1),
		upperArm = { w = 0.75, len = 1.0 }, forearm = { w = 0.8, len = 0.95 }, hand = V(1.05, 1.0, 1.05), shoulderX = 1.5, stance = 0.5,
	})
	add(J, { name = "Pauldron_L", parent = "UpperArm_L", part = "LeftPauldron", size = V(1.0, 0.5, 1.15), color = "head", at = V(-0.1, 0.45, 0), pivot = V(0, 0, 0) })
	add(J, { name = "Pauldron_R", parent = "UpperArm_R", part = "RightPauldron", size = V(1.0, 0.5, 1.15), color = "head", at = V(0.1, 0.45, 0), pivot = V(0, 0, 0) })
	add(J, { name = "Rune", parent = "Body", part = "Rune", size = V(0.7, 0.7, 0.08), color = "accent", material = "Neon", at = V(0, 0.2, -0.66), pivot = V(0, 0, 0) })
	BossRigSpec.rigs.section_guardian = {
		plan = "biped", joints = J, accent = Color3.fromRGB(190, 110, 255),
		attach = { HandR = { part = "Hand_R", at = V(0, -0.5, 0) }, HandL = { part = "Hand_L", at = V(0, -0.5, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.5) }, Chest = { part = "Body", at = V(0, 0.2, -0.7) },
			ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.9, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.9, 0) } },
		chains = {},
		weight = 1.0, -- 무게감(모션 전조 · 히트스톱 배율)
	}
end

-- 서리 거인: 크고 느린 거인 - 뿔 · 얼음 수염(2차 움직임) · 오른손 얼음 곤봉.
do
	local J = biped({
		hips = V(1.4, 0.5, 0.9), torso = V(1.9, 1.9, 1.15), head = V(1.0, 1.0, 1.0),
		thigh = { w = 0.62, len = 1.0 }, shin = { w = 0.56, len = 1.0 }, foot = V(0.72, 0.3, 1.0),
		upperArm = { w = 0.58, len = 1.05 }, forearm = { w = 0.58, len = 1.0 }, hand = V(0.72, 0.8, 0.72), shoulderX = 1.22, stance = 0.42,
	})
	add(J, { name = "Horn_L", parent = "Head", part = "LeftHorn", size = V(0.3, 1.0, 0.3), shape = "wedge", color = "accent", at = V(-0.45, 0.45, 0), pivot = V(0, -0.45, 0), rot = V(0, 0, 25) })
	add(J, { name = "Horn_R", parent = "Head", part = "RightHorn", size = V(0.3, 1.0, 0.3), shape = "wedge", color = "accent", at = V(0.45, 0.45, 0), pivot = V(0, -0.45, 0), rot = V(0, 180, 25) })
	chain(J, { prefix = "Beard", parent = "Head", count = 3, length = 0.38, w0 = 0.62, w1 = 0.3, flat = 1.1, at = V(0, -0.45, -0.3), rot0 = V(-8, 0, 0), rotStep = V(-6, 0, 0), color = "accent" })
	add(J, { name = "Club", parent = "Hand_R", part = "IceClub", size = V(0.55, 2.6, 0.55), shape = "cyl", color = "accent", material = "Ice", at = V(0, -0.35, 0), pivot = V(0, 0.9, 0) })
	BossRigSpec.rigs.frost_giant = {
		plan = "biped", joints = J, accent = Color3.fromRGB(200, 240, 255),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.4, 0) }, HandL = { part = "Hand_L", at = V(0, -0.4, 0) }, Mouth = { part = "Head", at = V(0, -0.25, -0.5) }, ClubTip = { part = "IceClub", at = V(0, 1.3, 0) } },
		chains = { { "Beard1", "Beard2", "Beard3", lag = 0.55, sway = 4 } },
		weight = 1.4,
	}
end

-- 심해 군주: 인어 군주 - 머리 지느러미 · 뒤로 끌리는 긴 꼬리 6마디(2차 움직임 · 꼬리 휩쓸기) · 삼지창.
do
	local J = biped({
		hips = V(1.5, 0.5, 1.1), torso = V(2.3, 1.6, 1.4), head = V(1.1, 0.9, 1.1),
		thigh = { w = 0.66, len = 0.72 }, shin = { w = 0.6, len = 0.72 }, foot = V(0.8, 0.25, 1.15),
		upperArm = { w = 0.62, len = 0.95 }, forearm = { w = 0.6, len = 0.9 }, hand = V(0.72, 0.72, 0.72), shoulderX = 1.42, stance = 0.46,
	})
	add(J, { name = "Fin_L", parent = "Head", part = "LeftFin", size = V(0.25, 0.8, 0.9), shape = "wedge", color = "accent", at = V(-0.6, 0.1, 0.1), pivot = V(0, -0.2, 0), rot = V(0, 0, 35) })
	add(J, { name = "Fin_R", parent = "Head", part = "RightFin", size = V(0.25, 0.8, 0.9), shape = "wedge", color = "accent", at = V(0.6, 0.1, 0.1), pivot = V(0, -0.2, 0), rot = V(0, 0, -35) })
	add(J, { name = "Crest", parent = "Body", part = "BackFin", size = V(0.25, 1.1, 1.2), shape = "wedge", color = "accent", at = V(0, 0.4, 0.7), pivot = V(0, -0.3, 0), rot = V(0, 180, 0) })
	chain(J, { prefix = "Tail", parent = "Hips", count = 6, length = 0.75, w0 = 0.75, w1 = 0.32, flat = 1.2, at = V(0, -0.15, 0.5), rot0 = V(-75, 0, 0), rotStep = V(-9, 0, 0), color = "head", tipColor = "accent", tipShape = "wedge" })
	add(J, { name = "Trident", parent = "Hand_R", part = "Trident", size = V(0.22, 4.2, 0.22), shape = "cyl", color = "accent", at = V(0, -0.3, 0), pivot = V(0, -0.6, 0) })
	add(J, { name = "TridentHead", parent = "Trident", part = "TridentHead", size = V(0.9, 0.7, 0.15), shape = "wedge", color = "accent", material = "Neon", at = V(0, 2.1, 0), pivot = V(0, -0.35, 0) })
	BossRigSpec.rigs.abyssal_lord = {
		plan = "biped", joints = J, accent = Color3.fromRGB(60, 200, 255),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.4, 0) }, HandL = { part = "Hand_L", at = V(0, -0.4, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.55) }, TailTip = { part = "Tail6", at = V(0, -0.3, 0) } },
		chains = { { "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", lag = 0.45, sway = 7 } },
		weight = 1.1,
	}
end

-- 수정 여왕: 가는 몸 · 수정 치마 4장 × 2마디(2차 움직임) · 왕관 · 등 수정 날개 · 홀.
do
	local J = biped({
		hips = V(1.2, 0.5, 0.9), torso = V(1.5, 1.7, 0.9), head = V(0.9, 0.95, 0.9), headShape = "ball",
		thigh = { w = 0.5, len = 0.9 }, shin = { w = 0.45, len = 0.9 }, foot = V(0.55, 0.25, 0.9),
		upperArm = { w = 0.45, len = 0.95 }, forearm = { w = 0.42, len = 0.9 }, hand = V(0.5, 0.6, 0.5), shoulderX = 0.95, stance = 0.35,
	})
	for i, s in ipairs({ { "F", V(0, 0, -0.45), V(12, 0, 0) }, { "B", V(0, 0, 0.45), V(-12, 0, 0) }, { "L", V(-0.6, 0, 0), V(0, 0, -12) }, { "R", V(0.6, 0, 0), V(0, 0, 12) } }) do
		chain(J, { prefix = "Skirt" .. s[1], parent = "Hips", count = 2, length = 0.75, w0 = i <= 2 and 1.25 or 0.95, w1 = i <= 2 and 1.35 or 1.05, flat = 1, at = s[2] + V(0, -0.1, 0), rot0 = s[3], rotStep = s[3] * 0.5, color = "head", tipColor = "accent", tipMaterial = "Glass" })
	end
	add(J, { name = "Crown", parent = "Head", part = "Crown", size = V(0.8, 0.5, 0.8), shape = "cyl", color = "accent", material = "Neon", at = V(0, 0.5, 0), pivot = V(0, -0.2, 0), rot = V(0, 0, 90) })
	add(J, { name = "Wing_L", parent = "Body", part = "LeftShard", size = V(0.35, 1.6, 0.35), shape = "wedge", color = "accent", material = "Glass", at = V(-0.4, 0.5, 0.45), pivot = V(0, -0.7, 0), rot = V(-15, 0, 30) })
	add(J, { name = "Wing_R", parent = "Body", part = "RightShard", size = V(0.35, 1.6, 0.35), shape = "wedge", color = "accent", material = "Glass", at = V(0.4, 0.5, 0.45), pivot = V(0, -0.7, 0), rot = V(-15, 180, 30) })
	add(J, { name = "Scepter", parent = "Hand_R", part = "Scepter", size = V(0.18, 2.4, 0.18), shape = "cyl", color = "head", at = V(0, -0.25, 0), pivot = V(0, -0.5, 0) })
	add(J, { name = "ScepterGem", parent = "Scepter", part = "ScepterGem", size = V(0.5, 0.5, 0.5), shape = "ball", color = "accent", material = "Neon", at = V(0, 1.25, 0), pivot = V(0, 0, 0) })
	BossRigSpec.rigs.crystal_queen = {
		plan = "biped", joints = J, accent = Color3.fromRGB(150, 240, 255),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.3, 0) }, HandL = { part = "Hand_L", at = V(0, -0.3, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.45) }, Gem = { part = "ScepterGem", at = V(0, 0, 0) } },
		chains = { { "SkirtF1", "SkirtF2", lag = 0.4, sway = 3 }, { "SkirtB1", "SkirtB2", lag = 0.4, sway = 3 }, { "SkirtL1", "SkirtL2", lag = 0.4, sway = 3 }, { "SkirtR1", "SkirtR2", lag = 0.4, sway = 3 } },
		weight = 0.8,
	}
end

-- 폭풍 군주: 마법사 - 오른손 지팡이 · 망토 2줄 × 3마디(2차 움직임) · 어깨 칼날.
do
	local J = biped({
		hips = V(1.3, 0.5, 0.9), torso = V(1.7, 1.8, 1.0), head = V(0.95, 1.0, 0.95),
		thigh = { w = 0.55, len = 0.95 }, shin = { w = 0.5, len = 0.95 }, foot = V(0.6, 0.25, 0.95),
		upperArm = { w = 0.5, len = 1.0 }, forearm = { w = 0.48, len = 0.95 }, hand = V(0.55, 0.6, 0.55), shoulderX = 1.05, stance = 0.38,
	})
	add(J, { name = "Blade_L", parent = "Body", part = "LeftBlade", size = V(0.3, 1.5, 0.3), shape = "wedge", color = "accent", at = V(-0.95, 0.9, 0), pivot = V(0, -0.6, 0), rot = V(0, 0, 15) })
	add(J, { name = "Blade_R", parent = "Body", part = "RightBlade", size = V(0.3, 1.5, 0.3), shape = "wedge", color = "accent", at = V(0.95, 0.9, 0), pivot = V(0, -0.6, 0), rot = V(0, 180, 15) })
	chain(J, { prefix = "CapeL", parent = "Body", count = 3, length = 0.8, w0 = 0.8, w1 = 0.95, flat = 1, at = V(-0.42, 0.8, 0.55), rot0 = V(-6, 0, 0), rotStep = V(-3, 0, 0), color = "dark" })
	chain(J, { prefix = "CapeR", parent = "Body", count = 3, length = 0.8, w0 = 0.8, w1 = 0.95, flat = 1, at = V(0.42, 0.8, 0.55), rot0 = V(-6, 0, 0), rotStep = V(-3, 0, 0), color = "dark" })
	add(J, { name = "Staff", parent = "Hand_R", part = "Staff", size = V(0.25, 4.6, 0.25), shape = "cyl", color = "dark", at = V(0, -0.3, 0), pivot = V(0, -0.4, 0) })
	add(J, { name = "StaffOrb", parent = "Staff", part = "StaffOrb", size = V(0.7, 0.7, 0.7), shape = "ball", color = "accent", material = "Neon", at = V(0, 2.35, 0), pivot = V(0, 0, 0) })
	BossRigSpec.rigs.storm_lord = {
		plan = "biped", joints = J, accent = Color3.fromRGB(255, 240, 90),
		attach = { ShoulderR = { part = "UpperArm_R", at = V(0.1, 0.8, 0) }, ShoulderL = { part = "UpperArm_L", at = V(-0.1, 0.8, 0) }, HandR = { part = "Hand_R", at = V(0, -0.3, 0) }, HandL = { part = "Hand_L", at = V(0, -0.3, 0) }, Mouth = { part = "Head", at = V(0, -0.2, -0.5) }, Orb = { part = "StaffOrb", at = V(0, 0, 0) } },
		chains = { { "CapeL1", "CapeL2", "CapeL3", lag = 0.5, sway = 5 }, { "CapeR1", "CapeR2", "CapeR3", lag = 0.5, sway = 5 } },
		weight = 0.9,
	}
end

-- 전갈 여왕: 낮고 넓은 몸 · 다리 6(엉덩이 · 무릎) · 집게 2(어깨 · 팔꿈치 · 집게 턱) · 꼬리 3 × 8마디(꼬리마다 따로 흔들림 · 4b-5 한 명씩 매단다).
do
	local J = {}
	add(J, { name = "RootJoint", parent = "HumanoidRootPart", part = "Body", size = V(2.4, 0.9, 2.2), color = "body", at = V(0, -0.1, 0), pivot = V(0, 0, 0), query = true })
	add(J, { name = "Neck", parent = "Body", part = "Head", size = V(1.3, 0.7, 0.9), color = "head", at = V(0, 0.05, -1.1), pivot = V(0, 0, 0.42), query = true })
	add(J, { name = "Eyes", parent = "Head", part = "Eyes", size = V(0.8, 0.14, 0.08), color = "eye", material = "Neon", at = V(0, 0.15, -0.45), pivot = V(0, 0, 0.02) })
	add(J, { name = "Jaw", parent = "Head", part = "Mouth", size = V(0.6, 0.12, 0.08), color = "mouth", at = V(0, -0.18, -0.45), pivot = V(0, 0.04, 0.02) })
	for _, s in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local side, x = s[1], s[2]
		for k, z in ipairs({ -0.6, 0.15, 0.85 }) do
			local leg = ("%d_%s"):format(k, side)
			add(J, { name = "Hip" .. leg, parent = "Body", part = "Thigh" .. leg, size = V(0.28, 1.0, 0.28), color = "head", at = V(x * 1.2, -0.15, z), pivot = V(0, 0.5, 0), rot = V(0, 0, x * 125) })
			add(J, { name = "Knee" .. leg, parent = "Thigh" .. leg, part = "Shin" .. leg, size = V(0.24, 1.95, 0.24), color = "dark", at = V(0, -0.5, 0), pivot = V(0, 0.975, 0), rot = V(0, 0, -x * 95) })
		end
		add(J, { name = "Shoulder_" .. side, parent = "Body", part = "UpperArm_" .. side, size = V(0.4, 1.0, 0.4), color = "head", at = V(x * 0.95, 0.05, -1.05), pivot = V(0, 0.5, 0), rot = V(95, x * -25, 0) })
		add(J, { name = "Elbow_" .. side, parent = "UpperArm_" .. side, part = "Forearm_" .. side, size = V(0.42, 1.0, 0.42), color = "body", at = V(0, -0.5, 0), pivot = V(0, 0.5, 0), rot = V(40, 0, 0) })
		add(J, { name = "Wrist_" .. side, parent = "Forearm_" .. side, part = "Hand_" .. side, size = V(0.8, 0.9, 0.5), color = "head", at = V(0, -0.5, 0), pivot = V(0, 0.4, 0), rot = V(-45, 0, 0) })
		add(J, { name = "Pincer_" .. side, parent = "Hand_" .. side, part = "Pincer_" .. side, size = V(0.3, 0.9, 0.3), shape = "wedge", color = "accent", at = V(-x * 0.25, -0.4, 0), pivot = V(0, 0.45, 0), rot = V(0, 0, x * 10) })
	end
	local tailRot = { -30, 0, 30 }
	for t = 1, 3 do
		chain(J, { prefix = ("Tail%d_"):format(t), parent = "Body", count = 8, length = 0.55, w0 = 0.45, w1 = 0.24, at = V((t - 2) * 0.45, 0.3, 1.0), rot0 = V(-127, tailRot[t], 0), rotStep = V(-20, 0, 0),
			color = "body", tipColor = "accent", tipShape = "wedge", tipMaterial = "Neon" })
	end
	local chains = {}
	for t = 1, 3 do
		local c = { lag = 0.5, sway = 9, phase = t * 1.9 }
		for i = 1, 8 do
			c[i] = ("Tail%d_%d"):format(t, i)
		end
		chains[t] = c
	end
	BossRigSpec.rigs.scorpion_queen = {
		plan = "scorpion", joints = J, accent = Color3.fromRGB(255, 190, 60),
		-- 4b-5 매달기: 꼬리 1 = 끝(8마디) · 꼬리 2 = 가운데(5) · 꼬리 3 = 밑(4 - 2마디는 잡힌 사람 발이 땅에 묻혔다) · 넷째부터 = 집게(HandR · HandL)
		attach = {
			Tail1 = { part = "Tail1_8", at = V(0, -0.3, 0) }, Tail2 = { part = "Tail2_5", at = V(0, 0, 0) }, Tail3 = { part = "Tail3_4", at = V(0, 0, 0) },
			HandR = { part = "Hand_R", at = V(0, -0.5, 0) }, HandL = { part = "Hand_L", at = V(0, -0.5, 0) }, Mouth = { part = "Head", at = V(0, -0.1, -0.5) },
		},
		chains = chains,
		weight = 0.8,
	}
end

-- BOSS-FRAMEWORK 1: 새 몸(리그 v2 - shared/data/BossRigV2Data)을 "<보스 id>_v2" 키로 같이 등록한다(모델 Attribute BossRigKey가 고른다 · BossRig = 보스 id 그대로).
--   어느 몸이 뜨는지 = shared/data/BossFrameworkData(실전 live · Studio 시험 스위치) - 등록만으로는 아무 보스도 바뀌지 않는다.
local BossRigV2Data = require(script.Parent.BossRigV2Data)
for key, rig in pairs(BossRigV2Data.rigs) do
	rig.key = key
	BossRigSpec.rigs[key] = rig
end

-- BR1-4c c-10 발 접지: 발바닥 점(클라 BossAnimator가 매 프레임 가장 낮은 발을 땅에 맞춘다 - 뜬 발 · 바닥 관통 없음). 두 발 = 발 파트 밑면 · 전갈 = 다리 끝.
--   v2 = rig.contacts(접지 부위 이름 - 네 발 · 너클 · 뱀 꼬리)가 있으면 그것 · contactAt = 모든 부위의 밑점(동작 세트가 바꿔 고른다 - BossClipSetData contacts).
for _, rig in pairs(BossRigSpec.rigs) do
	rig.feet = {}
	if rig.variant then
		rig.contactAt = {}
		for _, j in ipairs(rig.joints) do
			rig.contactAt[j.part] = V(0, -j.size.Y / 2, 0)
		end
	end
	for _, j in ipairs(rig.joints) do
		if rig.contacts then
			for _, c in ipairs(rig.contacts) do -- 이름(밑점 = 아래 끝) 또는 { part, at }(누운 꼬리 - 배 쪽 점)
				if c == j.part then
					table.insert(rig.feet, { part = j.part, at = V(0, -j.size.Y / 2, 0) })
				elseif type(c) == "table" and c.part == j.part then
					table.insert(rig.feet, { part = j.part, at = c.at })
					rig.contactAt[j.part] = c.at
				end
			end
		elseif j.part == "Foot_L" or j.part == "Foot_R" then
			table.insert(rig.feet, { part = j.part, at = V(0, -j.size.Y / 2, 0) })
		elseif j.part:match("^Shin%d_[LR]$") then
			table.insert(rig.feet, { part = j.part, at = V(0, -j.size.Y / 2, 0) })
		end
	end
end

-- 모델 → 리그 키(BossRigKey가 있으면 v2 · 없으면 보스 id = 옛 리그)
function BossRigSpec.keyOf(model)
	return model:GetAttribute("BossRigKey") or model:GetAttribute("BossRig")
end
function BossRigSpec.rigOf(model)
	local key = BossRigSpec.keyOf(model)
	return key and BossRigSpec.rigs[key] or nil, key
end

-- 색 역할 → 실제 색(bodyColor · headColor = BossData · accent = 위 표 · 나머지 = 파생).
function BossRigSpec.colorOf(role, look, rig)
	if typeof(role) == "Color3" then -- A2-S 아트 샘플: 관절 표에 색을 직접 적은 부위
		return role
	end
	if role == "head" then
		return look.headColor
	elseif role == "dark" then
		return look.bodyColor:Lerp(Color3.new(0, 0, 0), 0.3)
	elseif role == "accent" then
		return rig.accent or look.headColor
	elseif role == "eye" then
		return Color3.new(1, 1, 1):Lerp(rig.accent or Color3.new(1, 1, 1), 0.35)
	elseif role == "mouth" then
		return Color3.fromRGB(25, 18, 22)
	elseif role == "light" then -- A2-M1 디테일 색 역할(새 색 없이 보스 색에서 파생)
		return look.headColor:Lerp(Color3.new(1, 1, 1), 0.35)
	elseif role == "shadow" then
		return look.bodyColor:Lerp(Color3.new(0, 0, 0), 0.5)
	elseif role == "stone" then
		return look.bodyColor:Lerp(Color3.fromRGB(140, 136, 150), 0.42)
	elseif role == "slab" then -- 밝은 판석(명도 대비 - 머리색을 회백으로)
		return look.headColor:Lerp(Color3.fromRGB(205, 200, 215), 0.4)
	elseif role == "metal" then
		return look.headColor:Lerp(Color3.fromRGB(150, 150, 160), 0.6)
	end
	return look.bodyColor
end

-- A2-M1 접지: 보스 리그 전부 발바닥을 바닥에 맞춘다(shared/BossRig.rootLift - 루트 판정 자리는 그대로)
-- A2-M1 디테일(shared/data/BossDetailSpec - ArtStyleV1 스위치 뒤): 새 관절(detail = true · 스위치 끔이면 안 짓는다) · 2차 움직임 사슬 · 장식 · 테마 색을 얹는다.
local BossDetailSpec = require(script.Parent.BossDetailSpec)
for id, rig in pairs(BossRigSpec.rigs) do
	rig.groundLift = true
	local detail = BossDetailSpec.bosses[id]
	if detail then
		for _, j in ipairs(detail.joints or {}) do
			table.insert(rig.joints, j)
		end
		for _, c in ipairs(detail.chains or {}) do
			c.detail = true
			table.insert(rig.chains, c)
		end
		rig.deco = detail.deco
		rig.themeColors = detail.themeColors
		rig.recolor = detail.recolor
	end
end

-- 대공 잡기 들기 자리(4b-3 · 4b-5): 잡힌 순서대로 이 부착점에 매단다(서버 server/BossAirGrab · 클라 BossAnimator 같은 FK) · 두 발 몸 = 오른손 · 왼손 · 어깨 · 전갈 = 꼬리 끝 · 가운데 · 밑 → 넷째부터 집게.
BossRigSpec.holdSlots = { biped = { "HandR", "HandL", "ShoulderR", "ShoulderL" }, scorpion = { "Tail1", "Tail2", "Tail3", "HandR", "HandL" } }
BossRigSpec.holdHangStuds = 1.3 -- 부착점 아래 잡힌 사람 루트까지(stud)
BossRigSpec.holdMarkColors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(120, 230, 120), Color3.fromRGB(255, 220, 90), Color3.fromRGB(230, 130, 255) } -- 4b-5 잡힌 사람 머리 위 표식(자리 순서)

-- 모션 LOD(4b 검증 - 클라 비용): 카메라에서 이 거리(stud) 밖이면 모션 갱신을 줄인다.
BossRigSpec.lod = { fullStuds = 160, reducedHz = 15, farStuds = 400 }

return BossRigSpec

end

sources.BossDetailSpec = function()
-- A2-M1 보스 디테일(사용자 지시 2026-09-30: "보스별 파트를 더 추가하고 최대 파트 제한을 풀어 보스전만큼은 정성 들여 만들었구나 알 수 있게 - 이번 아트 작업의 핵심"
--   · "모바일 평균 유저 기준 4인 도전 때 렉이 걸리면 안 된다 - 적당히"). BossRigSpec의 리그 위에 얹는다(ArtStyleV1 스위치 뒤 - 끄면 옛 모습 그대로).
--   joints = 움직이는 새 부위(관절 표와 같은 규격 - 망토 · 꼬리 · 깃발 조각 등 2차 움직임 사슬) · chains = 그 부위의 2차 움직임 사슬(BossRigSpec chains 규격)
--   deco = 부모 부위에 용접되는 장식 파트(관절 없음 = 모션 계산 비용 0 · 충돌 · 조준 · 터치 없음): { parent, name, size, at(부모 부위 공간 · 단위 = sizeScale 1),
--     rot(도 - X · Y · Z), shape("block" | "ball" | "wedge" | "cyl" | "corner"), color(역할 - body · head · dark · accent · eye · mouth · light · shadow · stone · metal 또는 Color3),
--     material(선택 - "Neon" · "Glass" · "Ice" · "Slate" …), lod(1 = 늘 · 2 = 세밀 - 폰 · 먼 거리에서 클라가 숨김 · client/BossDetailLod) }
--   themeColors = 몸 · 머리 · 강조 색(A2-N2 확정 `roblox/art/bosses/<보스>.meta.json` themeColors - 스위치 켬일 때 BossData 색 대신).
-- 파트 예산(art-direction §6 A2-M1 개정): 두 발 보스 ≤ 80 · 전갈 여왕 ≤ 110(세밀 lod 2 포함) · 폰에서 보이는 수(lod 1) ≤ 60 · 80.
-- 이름 규칙: 장식 = Deco_<부위>_<무엇>(좌우 _L · _R) · 새 관절 = 파트 이름과 같게(TassetF · BannerL1 …) - Blender 스크립트(make_boss.py)도 같은 이름 · 피벗.
local BossDetailSpec = {}

local V = Vector3.new

local function mirrorX(list)
	-- _L 항목을 _R로(부모 · 이름 · x · ry · rz 부호) 복사한다
	local out = {}
	for _, d in ipairs(list) do
		table.insert(out, d)
		if d.name:find("_L$") then
			local r = d.rot or V(0, 0, 0)
			table.insert(out, {
				parent = d.parent:gsub("_L$", "_R"):gsub("^Left", "Right"), name = d.name:gsub("_L$", "_R"), size = d.size, shape = d.shape, color = d.color,
				material = d.material, lod = d.lod, at = V(-d.at.X, d.at.Y, d.at.Z), rot = V(r.X, -r.Y, -r.Z),
			})
		end
	end
	return out
end
BossDetailSpec.mirrorX = mirrorX

local function deco(parent, name, size, at, rot, color, opts)
	opts = opts or {}
	return { parent = parent, name = name, size = size, at = at, rot = rot or V(0, 0, 0), color = color, shape = opts.shape, material = opts.material, lod = opts.lod or 1 }
end

-- 사슬(깃발 · 천 · 꼬리 조각) - BossRigSpec chain과 같은 모양의 관절 표
local function chain(J, o)
	local parent = o.parent
	for i = 1, o.count do
		local f = (i - 1) / math.max(o.count - 1, 1)
		local w = o.w0 + (o.w1 - o.w0) * f
		local name = ("%s%d"):format(o.prefix, i)
		table.insert(J, {
			name = name, parent = parent, part = name, size = V(w, o.length, o.thick or w), color = (i == o.count and o.tipColor) or o.color or "body",
			material = (i == o.count and o.tipMaterial) or o.material, shape = "block",
			at = i == 1 and o.at or V(0, -o.length / 2, 0), pivot = V(0, o.length / 2, 0), rot = i == 1 and o.rot0 or o.rotStep, detail = true,
		})
		parent = name
	end
end

BossDetailSpec.bosses = {}

-- ─────────────────────────── 구간 수호자: 고대 돌 골렘 · 보라 룬 수정 ───────────────────────────
-- 콘셉트: 구간을 지키는 오래된 석상. 몸은 겹겹이 쌓인 판석(가슴 · 어깨 · 허리띠 · 무릎) · 등과 머리에 보라 수정이 돋고 룬이 빛난다.
-- 실루엣 = 넓은 어깨 + 머리 수정 관 + 등 수정 3 + 허리 깃발 2(걸을 때 펄럭임). 무게감 = 두꺼운 팔뚝 테 · 주먹 돌기 · 발 발톱.
do
	local J = {}
	-- 허리 앞 · 뒤 판석(걸음 · 타격에 흔들리는 2차 움직임)
	table.insert(J, { name = "TassetF", parent = "Hips", part = "TassetF", size = V(1.05, 0.7, 0.16), color = "slab", at = V(0, -0.16, -0.56), pivot = V(0, 0.34, 0), rot = V(-6, 0, 0), detail = true })
	table.insert(J, { name = "TassetB", parent = "Hips", part = "TassetB", size = V(1.05, 0.7, 0.16), color = "slab", at = V(0, -0.16, 0.56), pivot = V(0, 0.34, 0), rot = V(6, 0, 0), detail = true })
	-- 허리 옆 룬 깃발 2줄 × 3조각(천 - 강조색 끝)
	chain(J, { prefix = "BannerL", parent = "Hips", count = 3, length = 0.46, w0 = 0.5, w1 = 0.42, thick = 0.07, at = V(-0.78, -0.1, 0.34), rot0 = V(4, 0, 6), rotStep = V(3, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	chain(J, { prefix = "BannerR", parent = "Hips", count = 3, length = 0.46, w0 = 0.5, w1 = 0.42, thick = 0.07, at = V(0.78, -0.1, 0.34), rot0 = V(4, 0, -6), rotStep = V(3, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	local D = {
		-- 머리: 얼굴 판석(이마 · 턱) + 수정 관(가운데 큰 결정 + 양옆 2쌍)
		deco("Head", "Deco_Head_Brow", V(1.2, 0.26, 0.34), V(0, 0.26, -0.44), V(-12, 0, 0), "slab"),
		deco("Head", "Deco_Head_Jaw", V(0.96, 0.26, 0.38), V(0, -0.4, -0.32), V(8, 0, 0), "stone"),
		deco("Head", "Deco_Head_Cheek_L", V(0.2, 0.5, 0.5), V(-0.58, -0.05, -0.2), V(0, 0, 0), "stone"),
		deco("Head", "Deco_Head_Crown", V(0.3, 0.85, 0.3), V(0, 0.78, 0.05), V(0, 45, 0), "accent", { material = "Glass" }),
		deco("Head", "Deco_Head_CrownSide_L", V(0.24, 0.6, 0.24), V(-0.3, 0.66, 0.1), V(0, 45, 20), "accent", { material = "Glass" }),
		deco("Head", "Deco_Head_CrownOuter_L", V(0.18, 0.4, 0.18), V(-0.5, 0.55, 0.12), V(0, 45, 34), "accent", { material = "Glass", lod = 2 }),
		-- 가슴 판석(룬 둘레) · 룬 빛줄기(세밀)
		deco("Body", "Deco_Chest_Top", V(2.05, 0.38, 0.24), V(0, 0.64, -0.74), V(-4, 0, 0), "slab"),
		deco("Body", "Deco_Chest_Side_L", V(0.62, 1.02, 0.22), V(-0.92, 0.02, -0.72), V(0, -8, 0), "stone"),
		deco("Body", "Deco_Chest_Belly", V(1.36, 0.4, 0.22), V(0, -0.6, -0.72), V(0, 0, 0), "slab"),
		deco("Body", "Deco_Chest_Ray_L", V(0.34, 0.06, 0.04), V(-0.5, 0.2, -0.72), V(0, 0, 0), "accent", { material = "Neon", lod = 2 }),
		deco("Body", "Deco_Chest_RayLow_L", V(0.3, 0.06, 0.04), V(-0.3, -0.12, -0.72), V(0, 0, -40), "accent", { material = "Neon", lod = 2 }),
		-- 등 수정 무리 5(뒤 실루엣 - 큰 가운데 + 양옆 + 작은 끝)
		deco("Body", "Deco_Back_Crystal", V(0.46, 1.7, 0.46), V(0, 0.7, 0.86), V(-22, 45, 0), "accent", { material = "Glass" }),
		deco("Body", "Deco_Back_CrystalSide_L", V(0.36, 1.2, 0.36), V(-0.6, 0.45, 0.8), V(-16, 45, 24), "accent", { material = "Glass" }),
		deco("Body", "Deco_Back_CrystalSmall_L", V(0.26, 0.7, 0.26), V(-0.95, 0.1, 0.72), V(-10, 45, 40), "accent", { material = "Glass", lod = 2 }),
		deco("Body", "Deco_Back_Slab", V(1.6, 1.1, 0.2), V(0, 0.05, 0.72), V(0, 0, 0), "stone"),
		-- 어깨 판석 덮개 · 돌 가시 2 · 룬 띠(세밀)
		deco("LeftPauldron", "Deco_Pauldron_Cap_L", V(1.2, 0.3, 1.3), V(-0.05, 0.3, 0), V(0, 0, 12), "slab"),
		deco("LeftPauldron", "Deco_Pauldron_Spike_L", V(0.28, 0.62, 0.28), V(-0.28, 0.55, 0.24), V(0, 45, 20), "stone"),
		deco("LeftPauldron", "Deco_Pauldron_Spike2_L", V(0.22, 0.46, 0.22), V(-0.22, 0.48, -0.28), V(0, 45, 14), "stone"),
		deco("LeftPauldron", "Deco_Pauldron_Rune_L", V(0.5, 0.08, 0.04), V(0, 0.02, -0.66), V(0, 0, 0), "accent", { material = "Neon", lod = 2 }),
		-- 팔: 위팔 룬(세밀) · 팔꿈치 돌 · 팔뚝 판석 테 · 주먹 돌기(세밀)
		deco("UpperArm_L", "Deco_UpperArm_Rune_L", V(0.05, 0.56, 0.05), V(-0.4, -0.1, 0), V(0, 0, 0), "accent", { material = "Neon", lod = 2 }),
		deco("Forearm_L", "Deco_Forearm_Elbow_L", V(0.5, 0.36, 0.42), V(0, 0.42, 0.3), V(20, 0, 0), "stone"),
		deco("Forearm_L", "Deco_Forearm_Band_L", V(0.96, 0.38, 0.96), V(0, 0.08, 0), V(0, 0, 0), "slab"),
		deco("Hand_L", "Deco_Hand_Knuckle_L", V(0.95, 0.26, 0.26), V(0, -0.28, -0.56), V(0, 0, 0), "stone", { lod = 2 }),
		-- 허리띠(앞 버클 = 수정 · 양옆 돌)
		deco("Hips", "Deco_Belt", V(1.72, 0.2, 1.1), V(0, 0.2, 0), V(0, 0, 0), "shadow"),
		deco("Hips", "Deco_Belt_Buckle", V(0.52, 0.52, 0.24), V(0, 0.05, -0.56), V(0, 0, 45), "accent", { material = "Glass" }),
		deco("Hips", "Deco_Belt_Side_L", V(0.38, 0.44, 1.0), V(-0.86, 0.02, 0), V(0, 0, 0), "stone"),
		-- 다리: 허벅지 판석 · 무릎 판 · 정강이 판 · 발 앞 돌(세밀)
		deco("Thigh_L", "Deco_Thigh_Plate_L", V(0.86, 0.52, 0.86), V(0, 0.14, 0), V(0, 0, 0), "stone"),
		deco("Thigh_L", "Deco_Knee_L", V(0.6, 0.44, 0.26), V(0, -0.38, -0.4), V(-10, 0, 0), "slab"),
		deco("Shin_L", "Deco_Shin_L", V(0.72, 0.6, 0.2), V(0, 0.02, -0.38), V(0, 0, 0), "stone"),
		deco("Foot_L", "Deco_Toe_L", V(0.86, 0.24, 0.3), V(0, -0.02, -0.64), V(0, 0, 0), "stone", { lod = 2 }),
	}
	BossDetailSpec.bosses.section_guardian = {
		joints = J,
		chains = { { "TassetF", lag = 0.55, sway = 2.5 }, { "TassetB", lag = 0.55, sway = 2.5 }, { "BannerL1", "BannerL2", "BannerL3", lag = 0.4, sway = 6 }, { "BannerR1", "BannerR2", "BannerR3", lag = 0.4, sway = 6 } },
		deco = mirrorX(D),
		recolor = { Hips = "shadow", Shin_L = "shadow", Shin_R = "shadow", Foot_L = "stone", Foot_R = "stone", UpperArm_L = "stone", UpperArm_R = "stone" }, -- 디테일 모드 부위 색(명도 위계: 어두운 속 ↔ 밝은 판석 ↔ 빛나는 수정)
		themeColors = { body = Color3.fromRGB(60, 20, 70), head = Color3.fromRGB(90, 30, 100), accent = Color3.fromRGB(190, 110, 255) },
	}
end

-- ─────────────────────────── 서리 거인: 얼음 갑옷 · 털 망토의 거인 ───────────────────────────
-- 콘셉트: 설산의 거인 족장. 푸른 회색 털 망토(등 · 2차 움직임 - Play 4: 흰 털은 흰 얼음 아레나에서 묻혀 돌색으로) · 털 허리띠와 다리 감개 · 얼음 갑주(가슴 · 어깨 · 무릎) · 머리 얼음 관 · 등 고드름 · 곤봉에 박힌 얼음 가시.
-- 실루엣 = 높고 넓은 어깨(얼음 어깨 갑주 + 가시) + 등 망토 + 곤봉 끝 가시. 무게감 = 두꺼운 털 장화 · 무릎 얼음.
do
	local J = {}
	chain(J, { prefix = "Mantle", parent = "Body", count = 3, length = 0.6, w0 = 1.7, w1 = 1.95, thick = 0.14, at = V(0, 0.78, 0.64), rot0 = V(6, 0, 0), rotStep = V(4, 0, 0), color = "stone", material = "Fabric" })
	chain(J, { prefix = "Loin", parent = "Hips", count = 2, length = 0.45, w0 = 0.85, w1 = 0.75, thick = 0.08, at = V(0, -0.16, -0.5), rot0 = V(-4, 0, 0), rotStep = V(-3, 0, 0), color = "stone", material = "Fabric" })
	local D = {
		deco("Head", "Deco_Head_Brow", V(1.08, 0.22, 0.32), V(0, 0.26, -0.46), V(-10, 0, 0), "light", { material = "Fabric" }),
		deco("Head", "Deco_Head_IceCrown", V(0.26, 0.66, 0.26), V(0, 0.7, 0), V(0, 45, 0), "accent", { material = "Ice" }),
		deco("Head", "Deco_Head_IceCrownSide_L", V(0.2, 0.46, 0.2), V(-0.28, 0.62, 0.06), V(0, 45, 16), "accent", { material = "Ice" }),
		deco("Body", "Deco_Collar_Fur", V(2.15, 0.48, 1.42), V(0, 0.9, 0.05), V(0, 0, 0), "stone", { material = "Fabric" }),
		deco("Body", "Deco_Chest_Ice", V(1.35, 0.95, 0.22), V(0, 0.2, -0.66), V(0, 0, 0), "accent", { material = "Ice" }),
		deco("Body", "Deco_Chest_Rune", V(0.95, 0.06, 0.04), V(0, 0.2, -0.78), V(0, 0, 0), "accent", { material = "Neon", lod = 2 }),
		deco("Body", "Deco_Back_Icicle", V(0.3, 1.0, 0.3), V(0, 0.45, 0.78), V(-28, 45, 0), "accent", { material = "Ice" }),
		deco("Body", "Deco_Back_IcicleSide_L", V(0.24, 0.75, 0.24), V(-0.52, 0.3, 0.74), V(-22, 45, 20), "accent", { material = "Ice", lod = 2 }),
		deco("UpperArm_L", "Deco_Pauldron_Ice_L", V(0.98, 0.52, 0.98), V(-0.08, 0.46, 0), V(0, 0, 10), "accent", { material = "Ice" }),
		deco("UpperArm_L", "Deco_Pauldron_Spike_L", V(0.24, 0.62, 0.24), V(-0.32, 0.82, 0), V(0, 45, 26), "accent", { material = "Ice" }),
		deco("UpperArm_L", "Deco_Shoulder_Fur_L", V(0.72, 0.3, 0.72), V(0, 0.12, 0), V(0, 0, 0), "stone", { material = "Fabric", lod = 2 }),
		deco("Forearm_L", "Deco_Forearm_Fur_L", V(0.74, 0.36, 0.74), V(0, 0.12, 0), V(0, 0, 0), "stone", { material = "Fabric" }),
		deco("Hand_L", "Deco_Hand_Ice_L", V(0.62, 0.22, 0.22), V(0, -0.22, -0.4), V(0, 0, 0), "accent", { material = "Ice", lod = 2 }),
		deco("Hips", "Deco_Belt_Fur", V(1.58, 0.32, 1.08), V(0, 0.1, 0), V(0, 0, 0), "stone", { material = "Fabric" }),
		deco("Hips", "Deco_Belt_Buckle", V(0.42, 0.42, 0.2), V(0, 0.1, -0.56), V(0, 0, 45), "accent", { material = "Ice" }),
		deco("Thigh_L", "Deco_Knee_Ice_L", V(0.52, 0.42, 0.22), V(0, -0.48, -0.36), V(-10, 0, 0), "accent", { material = "Ice" }),
		deco("Shin_L", "Deco_Shin_Fur_L", V(0.72, 0.58, 0.72), V(0, -0.16, 0), V(0, 0, 0), "stone", { material = "Fabric" }),
		deco("Foot_L", "Deco_Boot_L", V(0.84, 0.38, 1.1), V(0, 0.04, -0.02), V(0, 0, 0), "shadow"),
		deco("IceClub", "Deco_Club_SpikeA", V(0.22, 0.6, 0.22), V(0, 1.05, -0.32), V(-40, 45, 0), "accent", { material = "Ice" }),
		deco("IceClub", "Deco_Club_SpikeB", V(0.22, 0.6, 0.22), V(0.3, 0.85, 0.15), V(30, 45, -40), "accent", { material = "Ice" }),
		deco("IceClub", "Deco_Club_SpikeC", V(0.2, 0.5, 0.2), V(-0.3, 0.7, 0.12), V(25, 45, 40), "accent", { material = "Ice", lod = 2 }),
		deco("Beard3", "Deco_Beard_Icicle", V(0.14, 0.4, 0.14), V(0, -0.3, 0), V(0, 45, 0), "accent", { material = "Ice", lod = 2 }),
	}
	BossDetailSpec.bosses.frost_giant = {
		joints = J,
		chains = { { "Mantle1", "Mantle2", "Mantle3", lag = 0.55, sway = 4 }, { "Loin1", "Loin2", lag = 0.5, sway = 3 } },
		deco = mirrorX(D),
		recolor = { Hips = "shadow" },
		themeColors = { body = Color3.fromRGB(96, 150, 204), head = Color3.fromRGB(226, 240, 250), accent = Color3.fromRGB(170, 232, 255) },
	}
end

-- ─────────────────────────── 심해 군주: 산호 왕관 · 조개 갑주의 인어 왕 ───────────────────────────
-- 콘셉트: 가라앉은 신전의 왕. 산호 왕관 · 조개 어깨 · 비늘 가슴판 · 진주 목걸이 · 수염 촉수 3(2차 움직임) · 꼬리 지느러미 · 삼지창 곁날.
do
	local J = {}
	chain(J, { prefix = "TentL", parent = "Head", count = 3, length = 0.34, w0 = 0.2, w1 = 0.1, thick = 0.2, at = V(-0.26, -0.44, -0.36), rot0 = V(8, 0, 4), rotStep = V(6, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	chain(J, { prefix = "TentM", parent = "Head", count = 3, length = 0.38, w0 = 0.22, w1 = 0.1, thick = 0.22, at = V(0, -0.46, -0.42), rot0 = V(10, 0, 0), rotStep = V(6, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	chain(J, { prefix = "TentR", parent = "Head", count = 3, length = 0.34, w0 = 0.2, w1 = 0.1, thick = 0.2, at = V(0.26, -0.44, -0.36), rot0 = V(8, 0, -4), rotStep = V(6, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Neon" })
	local D = {
		deco("Head", "Deco_Head_Coral", V(0.18, 0.72, 0.18), V(0, 0.66, 0.02), V(0, 0, 0), "accent", { material = "Glass" }),
		deco("Head", "Deco_Head_CoralSide_L", V(0.15, 0.52, 0.15), V(-0.26, 0.58, 0.02), V(0, 0, 22), "accent", { material = "Glass" }),
		deco("Head", "Deco_Head_CoralTwig_L", V(0.1, 0.32, 0.1), V(-0.42, 0.74, 0.02), V(0, 0, 48), "accent", { material = "Glass", lod = 2 }),
		deco("Head", "Deco_Head_Visor", V(1.16, 0.2, 0.32), V(0, 0.22, -0.5), V(-8, 0, 0), "shadow"),
		deco("UpperArm_L", "Deco_Pauldron_Shell_L", V(1.02, 0.46, 1.02), V(-0.08, 0.42, 0), V(0, 0, 15), "light"),
		deco("UpperArm_L", "Deco_Pauldron_Ridge_L", V(0.12, 0.5, 0.92), V(-0.2, 0.6, 0), V(0, 0, 15), "accent", { lod = 2 }),
		deco("Body", "Deco_Chest_ScaleTop", V(1.65, 0.3, 0.14), V(0, 0.45, -0.73), V(0, 0, 0), "head"),
		deco("Body", "Deco_Chest_ScaleMid", V(1.4, 0.3, 0.14), V(0, 0.1, -0.73), V(0, 0, 0), "light"),
		deco("Body", "Deco_Chest_ScaleLow", V(1.1, 0.3, 0.14), V(0, -0.25, -0.73), V(0, 0, 0), "head"),
		deco("Body", "Deco_Pearl_L", V(0.24, 0.24, 0.24), V(-0.36, 0.7, -0.72), V(0, 0, 0), "light", { shape = "ball" }),
		deco("Body", "Deco_Pearl_Center", V(0.3, 0.3, 0.3), V(0, 0.6, -0.8), V(0, 0, 0), "accent", { shape = "ball", material = "Neon" }),
		deco("Forearm_L", "Deco_Forearm_Fin_L", V(0.1, 0.62, 0.52), V(-0.34, 0, 0.1), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass" }),
		deco("Hips", "Deco_Belt", V(1.6, 0.22, 1.2), V(0, 0.15, 0), V(0, 0, 0), "shadow"),
		deco("Hips", "Deco_Belt_Shell", V(0.52, 0.42, 0.18), V(0, 0.1, -0.6), V(0, 0, 0), "light"),
		deco("Tail2", "Deco_Tail_Fin2", V(0.1, 0.5, 0.5), V(0, 0, 0.42), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass" }),
		deco("Tail3", "Deco_Tail_Fin3", V(0.1, 0.45, 0.45), V(0, 0, 0.38), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass" }),
		deco("Tail4", "Deco_Tail_Fin4", V(0.1, 0.4, 0.4), V(0, 0, 0.32), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass", lod = 2 }),
		deco("Tail5", "Deco_Tail_Fin5", V(0.1, 0.35, 0.35), V(0, 0, 0.28), V(0, 0, 0), "accent", { shape = "wedge", material = "Glass", lod = 2 }),
		deco("Shin_L", "Deco_Shin_Scale_L", V(0.68, 0.5, 0.2), V(0, 0.05, -0.33), V(0, 0, 0), "head"),
		deco("Trident", "Deco_Trident_ProngL", V(0.1, 0.62, 0.1), V(-0.32, 2.25, 0), V(0, 0, 12), "accent", { material = "Neon" }),
		deco("Trident", "Deco_Trident_ProngR", V(0.1, 0.62, 0.1), V(0.32, 2.25, 0), V(0, 0, -12), "accent", { material = "Neon" }),
		deco("Trident", "Deco_Trident_Ring", V(0.5, 0.14, 0.5), V(0, 1.8, 0), V(0, 0, 0), "light"),
	}
	BossDetailSpec.bosses.abyssal_lord = {
		joints = J,
		chains = { { "TentL1", "TentL2", "TentL3", lag = 0.35, sway = 7 }, { "TentM1", "TentM2", "TentM3", lag = 0.35, sway = 7, phase = 1.1 }, { "TentR1", "TentR2", "TentR3", lag = 0.35, sway = 7, phase = 2.3 } },
		deco = mirrorX(D),
		recolor = {},
		themeColors = { body = Color3.fromRGB(24, 66, 112), head = Color3.fromRGB(36, 140, 146), accent = Color3.fromRGB(70, 226, 214) },
	}
end

-- ─────────────────────────── 수정 여왕: 수정궁의 여왕(분홍 몸 · 청록 결정) ───────────────────────────
-- 콘셉트: 우아한 결정 여왕. 머리 뒤 후광 · 왕관 가시 · 이마 보석 · 옷깃 · 어깨 결정 · 팔찌 · 허리 보석 · 치마 끝 결정(세밀) · 날개 2단(2차 움직임) · 뒤 옷자락.
do
	local J = {}
	table.insert(J, { name = "Wing2_L", parent = "LeftShard", part = "LeftShard2", size = V(0.28, 1.25, 0.28), shape = "wedge", color = "accent", material = "Glass", at = V(0, 0.2, 0.08), pivot = V(0, -0.55, 0), rot = V(-8, 0, 22), detail = true })
	table.insert(J, { name = "Wing2_R", parent = "RightShard", part = "RightShard2", size = V(0.28, 1.25, 0.28), shape = "wedge", color = "accent", material = "Glass", at = V(0, 0.2, 0.08), pivot = V(0, -0.55, 0), rot = V(-8, 0, 22), detail = true })
	chain(J, { prefix = "Train", parent = "Body", count = 3, length = 0.62, w0 = 1.05, w1 = 1.3, thick = 0.06, at = V(0, 0.55, 0.48), rot0 = V(6, 0, 0), rotStep = V(5, 0, 0), color = "head", tipColor = "accent", tipMaterial = "Glass" })
	local D = {
		deco("Head", "Deco_Halo_Top", V(1.3, 0.1, 0.1), V(0, 0.95, 0.5), V(0, 0, 0), "accent", { material = "Neon" }),
		deco("Head", "Deco_Halo_Side_L", V(0.1, 1.0, 0.1), V(-0.65, 0.45, 0.5), V(0, 0, 0), "accent", { material = "Neon" }),
		deco("Head", "Deco_Halo_Corner_L", V(0.1, 0.5, 0.1), V(-0.5, 0.88, 0.5), V(0, 0, -45), "accent", { material = "Neon", lod = 2 }),
		deco("Head", "Deco_Head_Jewel", V(0.16, 0.16, 0.08), V(0, 0.2, -0.46), V(0, 0, 45), "accent", { material = "Neon" }),
		deco("Crown", "Deco_Crown_Spike", V(0.14, 0.6, 0.14), V(0, 0.5, -0.3), V(0, 45, 0), "accent", { material = "Glass" }),
		deco("Crown", "Deco_Crown_SpikeSide_L", V(0.12, 0.46, 0.12), V(-0.3, 0.42, -0.1), V(0, 45, 10), "accent", { material = "Glass" }),
		deco("Crown", "Deco_Crown_SpikeBack_L", V(0.1, 0.36, 0.1), V(-0.24, 0.36, 0.26), V(0, 45, 14), "accent", { material = "Glass", lod = 2 }),
		deco("Body", "Deco_Collar", V(1.34, 0.2, 0.84), V(0, 0.88, 0), V(0, 0, 0), "light"),
		deco("Body", "Deco_Chest_Gem", V(0.36, 0.36, 0.12), V(0, 0.35, -0.5), V(0, 0, 45), "accent", { material = "Neon" }),
		deco("UpperArm_L", "Deco_Shoulder_Crystal_L", V(0.18, 0.6, 0.18), V(-0.16, 0.6, 0), V(0, 45, 22), "accent", { material = "Glass" }),
		deco("UpperArm_L", "Deco_Shoulder_Crystal2_L", V(0.14, 0.42, 0.14), V(-0.1, 0.52, 0.16), V(0, 45, 12), "accent", { material = "Glass", lod = 2 }),
		deco("UpperArm_L", "Deco_Epaulet_L", V(0.62, 0.18, 0.56), V(0, 0.42, 0), V(0, 0, 8), "light"),
		deco("Forearm_L", "Deco_Bracelet_L", V(0.52, 0.14, 0.52), V(0, -0.3, 0), V(0, 0, 0), "accent", { material = "Glass" }),
		deco("Hips", "Deco_Belt", V(1.3, 0.14, 1.0), V(0, 0.2, 0), V(0, 0, 0), "light"),
		deco("Hips", "Deco_Belt_Gem", V(0.26, 0.26, 0.1), V(0, 0.15, -0.5), V(0, 0, 45), "accent", { material = "Neon" }),
		deco("SkirtF2", "Deco_Hem_F_L", V(0.14, 0.42, 0.14), V(-0.42, -0.45, 0), V(0, 45, 0), "accent", { material = "Glass", lod = 2 }),
		deco("SkirtB2", "Deco_Hem_B_L", V(0.14, 0.42, 0.14), V(-0.42, -0.45, 0), V(0, 45, 0), "accent", { material = "Glass", lod = 2 }),
		deco("SkirtL2", "Deco_Hem_Side_L", V(0.14, 0.4, 0.14), V(0, -0.45, -0.3), V(0, 45, 0), "accent", { material = "Glass", lod = 2 }),
		deco("ScepterGem", "Deco_Scepter_Prong_L", V(0.08, 0.42, 0.08), V(-0.28, 0.16, 0), V(0, 0, 25), "accent", { material = "Glass" }),
		deco("ScepterGem", "Deco_Scepter_ProngTop", V(0.08, 0.45, 0.08), V(0, 0.38, 0), V(0, 0, 0), "accent", { material = "Glass" }),
	}
	BossDetailSpec.bosses.crystal_queen = {
		joints = J,
		chains = { { "Wing2_L", lag = 0.5, sway = 4 }, { "Wing2_R", lag = 0.5, sway = 4, phase = 1.3 }, { "Train1", "Train2", "Train3", lag = 0.45, sway = 4 } },
		deco = mirrorX(D),
		recolor = {},
		themeColors = { body = Color3.fromRGB(222, 120, 172), head = Color3.fromRGB(246, 204, 224), accent = Color3.fromRGB(84, 226, 214) },
	}
end

-- ─────────────────────────── 폭풍 군주: 두건 쓴 폭풍 마법사 ───────────────────────────
-- 콘셉트: 천둥 첨탑의 군주. 두건(얼굴 그늘) · 높은 옷깃 · 가슴 번개 무늬(노란 빛) · 어깨 판 · 팔 보호대 · 허리 구슬 · 앞 · 뒤 옷자락(2차 움직임) · 지팡이 초승달 날.
do
	local J = {}
	chain(J, { prefix = "RobeF", parent = "Hips", count = 2, length = 0.55, w0 = 1.0, w1 = 1.12, thick = 0.08, at = V(0, -0.2, -0.48), rot0 = V(-4, 0, 0), rotStep = V(-3, 0, 0), color = "head" })
	chain(J, { prefix = "RobeB", parent = "Hips", count = 2, length = 0.62, w0 = 1.1, w1 = 1.2, thick = 0.08, at = V(0, -0.2, 0.48), rot0 = V(4, 0, 0), rotStep = V(3, 0, 0), color = "head" })
	local D = {
		deco("Head", "Deco_Hood_Shell", V(1.15, 0.62, 0.92), V(0, 0.34, 0.18), V(0, 0, 0), "shadow"),
		deco("Head", "Deco_Hood_Side_L", V(0.14, 0.84, 0.92), V(-0.56, 0, 0.12), V(0, 0, 0), "shadow"),
		deco("Head", "Deco_Hood_Peak", V(0.42, 0.32, 0.42), V(0, 0.64, -0.18), V(30, 45, 0), "shadow"),
		deco("Head", "Deco_Face_Mask", V(0.82, 0.36, 0.06), V(0, -0.24, -0.49), V(0, 0, 0), "shadow"),
		deco("Body", "Deco_Collar", V(1.5, 0.52, 0.26), V(0, 0.95, -0.32), V(-15, 0, 0), "head"),
		deco("Body", "Deco_Collar_Spike_L", V(0.12, 0.52, 0.12), V(-0.62, 1.12, -0.22), V(0, 0, 20), "accent", { material = "Neon", lod = 2 }),
		deco("Body", "Deco_Bolt_A", V(0.09, 0.52, 0.04), V(0, 0.42, -0.52), V(0, 0, 25), "accent", { material = "Neon" }),
		deco("Body", "Deco_Bolt_B", V(0.09, 0.42, 0.04), V(0.08, 0.06, -0.52), V(0, 0, -25), "accent", { material = "Neon" }),
		deco("Body", "Deco_Bolt_C", V(0.09, 0.42, 0.04), V(0, -0.28, -0.52), V(0, 0, 25), "accent", { material = "Neon" }),
		deco("UpperArm_L", "Deco_Shoulder_Plate_L", V(0.78, 0.3, 0.72), V(-0.05, 0.46, 0), V(0, 0, 15), "head"),
		deco("UpperArm_L", "Deco_Shoulder_Edge_L", V(0.72, 0.06, 0.06), V(-0.05, 0.62, -0.37), V(0, 0, 15), "accent", { material = "Neon", lod = 2 }),
		deco("Forearm_L", "Deco_Bracer_L", V(0.6, 0.42, 0.6), V(0, 0.05, 0), V(0, 0, 0), "shadow"),
		deco("Forearm_L", "Deco_Bracer_Rune_L", V(0.06, 0.34, 0.04), V(0, 0.05, -0.31), V(0, 0, 20), "accent", { material = "Neon", lod = 2 }),
		deco("Hips", "Deco_Belt", V(1.42, 0.26, 1.0), V(0, 0.15, 0), V(0, 0, 0), "shadow"),
		deco("Hips", "Deco_Belt_Orb", V(0.32, 0.32, 0.32), V(0, 0.12, -0.52), V(0, 0, 0), "accent", { shape = "ball", material = "Neon" }),
		deco("StaffOrb", "Deco_Staff_CrescentL", V(0.12, 0.72, 0.12), V(-0.46, 0.1, 0), V(0, 0, 25), "accent", { material = "Neon" }),
		deco("StaffOrb", "Deco_Staff_CrescentR", V(0.12, 0.72, 0.12), V(0.46, 0.1, 0), V(0, 0, -25), "accent", { material = "Neon" }),
		deco("StaffOrb", "Deco_Staff_Spike", V(0.1, 0.5, 0.1), V(0, 0.56, 0), V(0, 45, 0), "accent", { material = "Neon" }),
		deco("Shin_L", "Deco_Shin_Guard_L", V(0.56, 0.5, 0.16), V(0, 0.1, -0.3), V(0, 0, 0), "shadow"),
		deco("Thigh_L", "Deco_Knee_L", V(0.46, 0.32, 0.18), V(0, -0.46, -0.3), V(-10, 0, 0), "head"),
		deco("Foot_L", "Deco_Boot_L", V(0.66, 0.3, 1.0), V(0, 0.03, 0), V(0, 0, 0), "shadow"),
	}
	BossDetailSpec.bosses.storm_lord = {
		joints = J,
		chains = { { "RobeF1", "RobeF2", lag = 0.5, sway = 4 }, { "RobeB1", "RobeB2", lag = 0.5, sway = 5, phase = 1.4 } },
		deco = mirrorX(D),
		recolor = {},
		themeColors = { body = Color3.fromRGB(92, 97, 128), head = Color3.fromRGB(118, 124, 156), accent = Color3.fromRGB(255, 224, 64) },
	}
end

-- ─────────────────────────── 전갈 여왕: 모래 무덤의 여제(금 장신구) ───────────────────────────
-- 콘셉트: 사막 여제. 겹겹 등딱지 · 금 테두리 · 금 왕관 가시 · 큰 턱 · 옆 눈(세밀) · 집게 톱니(세밀) · 팔 금 띠 · 다리 가시(세밀) · 꼬리 금 고리 · 목걸이 보석 · 등 비단 베일(2차 움직임).
do
	local J = {}
	chain(J, { prefix = "Veil", parent = "Body", count = 3, length = 0.4, w0 = 1.0, w1 = 0.8, thick = 0.05, at = V(0, 0.55, 0.2), rot0 = V(70, 0, 0), rotStep = V(8, 0, 0), color = "accent", material = "Fabric" })
	local D = {
		deco("Body", "Deco_Carapace_Front", V(2.0, 0.22, 0.8), V(0, 0.52, -0.6), V(-6, 0, 0), "head"),
		deco("Body", "Deco_Carapace_Mid", V(2.1, 0.22, 0.8), V(0, 0.56, 0.05), V(-6, 0, 0), "head"),
		deco("Body", "Deco_Carapace_Back", V(1.9, 0.22, 0.75), V(0, 0.52, 0.7), V(-6, 0, 0), "head"),
		deco("Body", "Deco_Carapace_TrimF", V(2.04, 0.07, 0.09), V(0, 0.62, -0.98), V(0, 0, 0), "accent", { material = "Metal", lod = 2 }),
		deco("Body", "Deco_Carapace_TrimM", V(2.14, 0.07, 0.09), V(0, 0.66, -0.32), V(0, 0, 0), "accent", { material = "Metal", lod = 2 }),
		deco("Body", "Deco_Carapace_TrimB", V(1.94, 0.07, 0.09), V(0, 0.62, 0.34), V(0, 0, 0), "accent", { material = "Metal", lod = 2 }),
		deco("Body", "Deco_Side_Ridge_L", V(0.16, 0.32, 1.8), V(-1.26, 0.2, 0), V(0, 0, 0), "head"),
		deco("Body", "Deco_Necklace", V(1.2, 0.09, 0.09), V(0, 0.2, -1.13), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Body", "Deco_Necklace_Gem", V(0.22, 0.32, 0.1), V(0, 0.04, -1.15), V(0, 0, 0), "accent", { material = "Neon" }),
		deco("Head", "Deco_Crown_Band", V(1.1, 0.12, 0.6), V(0, 0.38, 0.15), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Head", "Deco_Crown_Spike", V(0.13, 0.5, 0.13), V(0, 0.62, 0.1), V(0, 45, 0), "accent", { material = "Metal" }),
		deco("Head", "Deco_Crown_SpikeSide_L", V(0.11, 0.4, 0.11), V(-0.36, 0.54, 0.16), V(0, 45, 14), "accent", { material = "Metal" }),
		deco("Head", "Deco_Mandible_L", V(0.14, 0.18, 0.48), V(-0.35, -0.25, -0.62), V(0, -20, 0), "light", { shape = "wedge" }),
		deco("Head", "Deco_Eye_Side_L", V(0.12, 0.12, 0.05), V(-0.46, 0.22, -0.46), V(0, 0, 0), "eye", { material = "Neon", lod = 2 }),
		deco("Hand_L", "Deco_Claw_Tooth_L", V(0.12, 0.32, 0.12), V(0.22, -0.3, -0.2), V(0, 45, 0), "light", { lod = 2 }),
		deco("Hand_L", "Deco_Claw_Tooth2_L", V(0.12, 0.28, 0.12), V(0.22, -0.02, -0.22), V(0, 45, 0), "light", { lod = 2 }),
		deco("Forearm_L", "Deco_Arm_Band_L", V(0.5, 0.14, 0.5), V(0, 0.2, 0), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Thigh1_L", "Deco_Leg_Spike1_L", V(0.1, 0.36, 0.1), V(0, 0.2, 0.15), V(0, 45, 0), "light", { lod = 2 }),
		deco("Thigh2_L", "Deco_Leg_Spike2_L", V(0.1, 0.36, 0.1), V(0, 0.2, 0.15), V(0, 45, 0), "light", { lod = 2 }),
		deco("Thigh3_L", "Deco_Leg_Spike3_L", V(0.1, 0.36, 0.1), V(0, 0.2, 0.15), V(0, 45, 0), "light", { lod = 2 }),
		deco("Tail1_7", "Deco_Tail1_Ring", V(0.36, 0.1, 0.36), V(0, 0, 0), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Tail2_7", "Deco_Tail2_Ring", V(0.36, 0.1, 0.36), V(0, 0, 0), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Tail3_7", "Deco_Tail3_Ring", V(0.36, 0.1, 0.36), V(0, 0, 0), V(0, 0, 0), "accent", { material = "Metal" }),
		deco("Tail1_3", "Deco_Tail1_Plate", V(0.52, 0.12, 0.44), V(0, 0, 0.22), V(0, 0, 0), "head", { lod = 2 }),
		deco("Tail2_3", "Deco_Tail2_Plate", V(0.52, 0.12, 0.44), V(0, 0, 0.22), V(0, 0, 0), "head", { lod = 2 }),
		deco("Tail3_3", "Deco_Tail3_Plate", V(0.52, 0.12, 0.44), V(0, 0, 0.22), V(0, 0, 0), "head", { lod = 2 }),
	}
	BossDetailSpec.bosses.scorpion_queen = {
		joints = J,
		chains = { { "Veil1", "Veil2", "Veil3", lag = 0.5, sway = 6 } },
		deco = mirrorX(D),
		recolor = {},
		themeColors = { body = Color3.fromRGB(168, 95, 38), head = Color3.fromRGB(206, 150, 104), accent = Color3.fromRGB(255, 196, 60) },
	}
end

return BossDetailSpec

end

sources.MeshImportCheck = function()
-- B3 메시 가져오기 검사기: Blender → FBX → Studio 3D Importer로 가져온 모델이 리그 규격(MonsterRigSpec · BossRigSpec)에 맞는지 항목별 O/X.
--   절차 · 규칙 = docs/art/blender-to-studio.md · 수치 = shared/data/MeshImportCheckData(여기에 숫자를 두지 않는다).
--   check(desc, rigId, opts) - 순수 함수(표 기술자만 읽는다 - 로컬 하네스 roblox/tools/harness/mesh_import_test.luau가 가짜 모델로 돈다).
--     desc = { name, reference(기준 루트 있음), parts = { { name, className, joint = {x,y,z}, center, min, max(기준 루트 공간 · stud), color = {r,g,b}(0 ~ 255),
--              material(이름), transparency, triCount(nil = 모름), textureId, forbidden = { 클래스 이름 } } } }
--     opts = { scale(기본 1 - 규격 sizeScale), look = { bodyColor, headColor }(색 역할 - 기본 = 종 · 보스 데이터) }
--     반환: ok, lines(결과표 문자열 줄 - "[MeshCheck] ①-1 … O"), rows({ id, label, ok, detail })
--   describe(model, opts) - 실제 Model(Instance) → 표 기술자(Studio에서만 - server/MeshImportDev가 부른다). opts.meta = Blender 메타(MeshMeta 모듈 표).
--   expected(rigId, scale) - 규격의 기준 자세(FK): 관절 자리 · 파트 경계 · 관절 프레임(교체 도우미 shared/MeshSwap도 이걸 쓴다).
--   FK는 CFrame 없이 숫자로 푼다(CFrame.Angles(rx, ry, rz) = Rx · Ry · Rz와 같은 순서 - BossRig.jointFrames와 같은 뜻).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.MeshImportCheckData)
local MonsterRigSpec = require(ReplicatedStorage.Shared.data.MonsterRigSpec)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local MonsterSpeciesData = require(ReplicatedStorage.Shared.data.MonsterSpeciesData)
local CartoonStyleData = require(ReplicatedStorage.Shared.data.CartoonStyleData)

local MeshImportCheck = {}

-- ─────────────── 숫자 3D(표 {x, y, z} · 3 × 3 행 우선 9칸) ───────────────
local function v3(v)
	return { v.X, v.Y, v.Z }
end

local function rotXYZ(rot)
	if not rot then
		return { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
	end
	local a, b, c = math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)
	local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
	-- Rx · Ry · Rz
	return {
		cb * cc, -cb * sc, sb,
		ca * sc + sa * sb * cc, ca * cc - sa * sb * sc, -sa * cb,
		sa * sc - ca * sb * cc, sa * cc + ca * sb * sc, ca * cb,
	}
end

local function mulMM(A, B)
	local out = {}
	for r = 0, 2 do
		for c = 0, 2 do
			out[r * 3 + c + 1] = A[r * 3 + 1] * B[c + 1] + A[r * 3 + 2] * B[c + 4] + A[r * 3 + 3] * B[c + 7]
		end
	end
	return out
end

local function mulMV(A, v)
	return {
		A[1] * v[1] + A[2] * v[2] + A[3] * v[3],
		A[4] * v[1] + A[5] * v[2] + A[6] * v[3],
		A[7] * v[1] + A[8] * v[2] + A[9] * v[3],
	}
end

local function add(a, b)
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

local function scaled(a, s)
	return { a[1] * s, a[2] * s, a[3] * s }
end

local function dist(a, b)
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- 프레임 { R, p } 합성: A · B
local function compose(A, B)
	return { R = mulMM(A.R, B.R), p = add(mulMV(A.R, B.p), A.p) }
end

local IDENTITY = { R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, p = { 0, 0, 0 } }

local function fmt3(v)
	return ("(%.2f, %.2f, %.2f)"):format(v[1], v[2], v[3])
end

-- ─────────────── 규격 ───────────────
function MeshImportCheck.rigOf(rigId)
	if MonsterRigSpec.rigs[rigId] then
		return MonsterRigSpec.rigs[rigId], "monster"
	elseif BossRigSpec.rigs[rigId] then
		return BossRigSpec.rigs[rigId], "boss"
	end
	return nil, nil
end

-- 색 역할용 look · accent(몬스터 = MonsterSpeciesData · 보스 = BossData - BossRig.build가 받는 것과 같은 값)
function MeshImportCheck.lookFor(rigId)
	local rig, kind = MeshImportCheck.rigOf(rigId)
	if kind == "monster" then
		local s = MonsterSpeciesData.species[rigId]
		if s then
			return { sizeScale = 1, bodyColor = s.body, headColor = s.head }, { accent = s.accent or rig.accent }, "tier" .. tostring(s.tier)
		end
	elseif kind == "boss" then
		local BossData = require(ReplicatedStorage.Shared.data.BossData)
		local b = BossData.bosses and BossData.bosses[rig.bossId or rigId] -- BOSS-FRAMEWORK: 새 몸 리그 키(<보스>_v2) = 그 보스 색
		local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
		local zoneKey
		for _, z in ipairs(WorldMapData.zones or {}) do
			if z.bossId == rigId then
				zoneKey = z.key
			end
		end
		if b then
			return { sizeScale = 1, bodyColor = b.bodyColor, headColor = b.headColor }, rig, zoneKey
		end
	end
	return nil, rig, nil
end

-- 기준 자세 FK. 반환: { kind, rig, order = { 파트 이름 }, parts = { [이름] = { joint, jointFrame, center, min, max, size, longest, material, query, color } }, min, max, hitbox }
function MeshImportCheck.expected(rigId, scale)
	local rig, kind = MeshImportCheck.rigOf(rigId)
	if not rig then
		return nil
	end
	local S = scale or 1
	local frames = { HumanoidRootPart = IDENTITY }
	local out = { kind = kind, rig = rig, order = {}, parts = {} }
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, j in ipairs(rig.joints) do
		local parentF = frames[j.parent] or IDENTITY
		local jointF = compose(parentF, { R = rotXYZ(j.rot), p = scaled(v3(j.at), S) })
		local partF = compose(jointF, { R = IDENTITY.R, p = scaled(v3(j.pivot or Vector3.new(0, 0, 0)), -S) })
		frames[j.part] = partF
		local half = scaled(v3(j.size), S / 2)
		local e: { number } = {}
		for r = 0, 2 do
			e[r + 1] = math.abs(partF.R[r * 3 + 1]) * half[1] + math.abs(partF.R[r * 3 + 2]) * half[2] + math.abs(partF.R[r * 3 + 3]) * half[3]
		end
		local pmin: { number } = { partF.p[1] - e[1], partF.p[2] - e[2], partF.p[3] - e[3] }
		local pmax: { number } = { partF.p[1] + e[1], partF.p[2] + e[2], partF.p[3] + e[3] }
		for k = 1, 3 do
			lo[k] = math.min(lo[k], pmin[k])
			hi[k] = math.max(hi[k], pmax[k])
		end
		table.insert(out.order, j.part)
		out.parts[j.part] = {
			joint = jointF.p, jointFrame = jointF, jointName = j.name, parent = j.parent, center = partF.p, min = pmin, max = pmax,
			size = scaled(v3(j.size), S), longest = math.max(j.size.X, j.size.Y, j.size.Z) * S,
			material = j.material, query = j.query == true, color = j.color,
		}
	end
	out.min, out.max = lo, hi
	if kind == "monster" then
		local s = MonsterSpeciesData.species[rigId]
		local box = s and s.hitbox
		if box then
			out.hitbox = { size = scaled(v3(box.size), S), center = scaled(v3(box.center), S) }
		else
			local d = Data.defaultMonsterHitbox
			out.hitbox = { size = scaled(d.size, S), center = scaled(d.center, S) }
		end
	end
	return out
end

-- ─────────────── 팔레트 ───────────────
local function to255(c)
	if type(c) == "table" and c[1] then
		return c
	end
	return { c.R * 255, c.G * 255, c.B * 255 }
end

function MeshImportCheck.allowedColors(rigId, opts)
	opts = opts or {}
	local list = {}
	local function push(c, label)
		if c then
			table.insert(list, { rgb = to255(c), label = label })
		end
	end
	local look, rigProxy, zoneKey = MeshImportCheck.lookFor(rigId)
	look = opts.look or look
	local zones = {}
	for key, zone in pairs(CartoonStyleData.palette or {}) do
		if not zoneKey or key == zoneKey then
			zones[key] = zone
		end
	end
	for key, zone in pairs(zones) do
		for role, c in pairs(zone) do
			push(c, key .. "." .. role)
		end
	end
	push(CartoonStyleData.outline and CartoonStyleData.outline.color, "outline")
	if look and look.bodyColor and look.headColor then
		for _, role in ipairs(Data.palette.roles) do
			push(BossRigSpec.colorOf(role, look, rigProxy or {}), "rig." .. role)
		end
	end
	local out = {}
	for _, base in ipairs(list) do
		for _, t in ipairs(Data.palette.tones) do
			table.insert(out, {
				rgb = { math.min(base.rgb[1] * t, 255), math.min(base.rgb[2] * t, 255), math.min(base.rgb[3] * t, 255) },
				label = t == 1 and base.label or ("%s×%.2f"):format(base.label, t),
			})
		end
	end
	return out
end

local function nearestColor(rgb, allowed)
	local best, bestLabel = math.huge, nil
	for _, a in ipairs(allowed) do
		local d = math.max(math.abs(rgb[1] - a.rgb[1]), math.abs(rgb[2] - a.rgb[2]), math.abs(rgb[3] - a.rgb[3]))
		if d < best then
			best, bestLabel = d, a.label
		end
	end
	return best, bestLabel
end

local function hex(rgb)
	return ("#%02X%02X%02X"):format(math.floor(rgb[1] + 0.5), math.floor(rgb[2] + 0.5), math.floor(rgb[3] + 0.5))
end

-- ─────────────── 검사 ───────────────
function MeshImportCheck.check(desc, rigId, opts)
	opts = opts or {}
	local rows, lines = {}, {}
	local function row(id, label, ok, detail)
		table.insert(rows, { id = id, label = label, ok = ok, detail = detail })
		table.insert(lines, ("[MeshCheck] %s %s%s %s"):format(id, label, detail and detail ~= "" and (" - " .. detail) or "", ok and "O" or "X"))
	end
	local hints = {}
	local S = opts.scale or 1
	local exp = MeshImportCheck.expected(rigId, S)
	if not exp or type(desc) ~= "table" or type(desc.parts) ~= "table" then
		row("0", "규격 · 모델", false, ("리그 id %s 없음 또는 기술자 아님"):format(tostring(rigId)))
		return false, lines, rows
	end
	table.insert(lines, 1, ("[MeshCheck] 모델 %s → 리그 %s(%s · 파트 %d · 배율 %.2f)"):format(tostring(desc.name), rigId, exp.kind, #exp.order, S))

	-- 이름 표
	local byName, dup = {}, {}
	for _, p in ipairs(desc.parts) do
		if not Data.ignoreNames[p.name] then
			if byName[p.name] then
				table.insert(dup, p.name)
			end
			byName[p.name] = p
		end
	end

	-- ① 파트 이름
	row("①-0", "기준 루트 " .. Data.referenceRootName, desc.reference == true, desc.reference and "" or "없음 - 모델 피벗을 기준으로 잰다")
	local missing, extra = {}, {}
	for _, name in ipairs(exp.order) do
		if not byName[name] then
			table.insert(missing, name)
		end
	end
	for name in pairs(byName) do
		if not exp.parts[name] and not (desc.attached and desc.attached[name]) then -- A2-N3: 껍데기(_Outline) · 메타 장식 묶음(deco)은 부위에 용접되는 정상 파트
			table.insert(extra, name)
		end
	end
	table.sort(extra)
	row("①-1", "빠진 리그 파트 없음", #missing == 0, #missing > 0 and ("빠짐: " .. table.concat(missing, ", ")) or ("%d/%d"):format(#exp.order, #exp.order))
	row("①-2", "남는 · 중복 파트 없음", #extra == 0 and #dup == 0, (#extra > 0 and ("남음: " .. table.concat(extra, ", ")) or "") .. (#dup > 0 and (" 중복: " .. table.concat(dup, ", ")) or ""))

	-- ② 관절(피벗) 자리
	local tol = Data.jointToleranceStuds * S
	local bad, atCenter, measured, worst = {}, 0, 0, 0
	for _, name in ipairs(exp.order) do
		local p = byName[name]
		if p then
			if not p.joint then
				table.insert(bad, name .. "(관절 모름)")
			else
				measured += 1
				local d = dist(p.joint, exp.parts[name].joint)
				worst = math.max(worst, d)
				if d > tol then
					table.insert(bad, ("%s %.2f"):format(name, d))
					if p.center and dist(p.joint, p.center) <= Data.pivotAtCenterEpsilon then
						atCenter += 1
					end
				end
			end
		end
	end
	row("②", ("관절 자리 오차 ≤ %.2f"):format(tol), #bad == 0 and measured > 0, #bad > 0 and table.concat(bad, ", ") or ("최대 %.3f"):format(worst))
	if atCenter > 0 and atCenter * 2 >= #bad then
		table.insert(hints, ("② X %d개의 측정 관절 = 파트 경계 가운데 → 가져오기가 피벗(Blender 원점)을 옮겼다: 파트에 Attachment \"%s\"를 관절 자리에 두거나 피벗 편집(문서 §7)"):format(atCenter, Data.jointAttachmentName))
	end

	-- ③ 삼각형 예산
	local unknown, total = {}, 0
	for name, p in pairs(byName) do
		if type(p.triCount) == "number" then
			total += p.triCount
		else
			table.insert(unknown, name)
		end
	end
	table.sort(unknown)
	local budget = Data.triBudget[exp.kind]
	row("③-1", "파트별 삼각형 수 알려짐(Attribute " .. Data.triAttribute .. " 또는 메타)", #unknown == 0, #unknown > 0 and ("모름: " .. table.concat(unknown, ", ")) or "")
	row("③-2", ("삼각형 합 ≤ %d(%s)"):format(budget, exp.kind), #unknown == 0 and total <= budget, ("합 %d"):format(total))

	-- ④ 크기 · 판정
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, p in pairs(byName) do
		if p.min and p.max then
			for k = 1, 3 do
				lo[k] = math.min(lo[k], p.min[k])
				hi[k] = math.max(hi[k], p.max[k])
			end
		end
	end
	local R = Data.size
	local ratios, okOverall = {}, lo[1] < math.huge
	for k = 1, 3 do
		local want = exp.max[k] - exp.min[k]
		local got = hi[k] - lo[k]
		local r = want > 0 and got / want or 0
		ratios[k] = r
		okOverall = okOverall and r >= R.overallRatio.min and r <= R.overallRatio.max
	end
	row("④-1", ("전체 크기 ÷ 규격(축마다 %.2f ~ %.2f)"):format(R.overallRatio.min, R.overallRatio.max), okOverall, ("x %.2f · y %.2f · z %.2f"):format(ratios[1] or 0, ratios[2] or 0, ratios[3] or 0))
	if not okOverall and lo[1] < math.huge then
		local mean = (ratios[1] + ratios[2] + ratios[3]) / 3
		for _, h in ipairs(R.unitHints) do
			if math.abs(mean / h.ratio - 1) <= R.unitHintTolerance then
				table.insert(hints, ("④-1 전체 비율 약 %.3f = 단위 %s 같다 → 3D Importer 단위(Stud) · Blender 단위 배율 확인(문서 §7)"):format(mean, h.label))
			end
		end
	end
	if exp.hitbox then
		-- 겉모습 경계 중 판정 상자와 겹치는 부피 비율 - 규격 모양(판정 상자를 맞춘 기준)보다 많이 줄면 "보이는 곳 ≠ 맞는 곳"
		local c, h = exp.hitbox.center, exp.hitbox.size
		local hbMin = { c[1] - h[1] / 2, c[2] - h[2] / 2, c[3] - h[3] / 2 }
		local hbMax = { c[1] + h[1] / 2, c[2] + h[2] / 2, c[3] + h[3] / 2 }
		local function coverage(a, b)
			local inter, vol = 1, 1
			for k = 1, 3 do
				inter *= math.max(0, math.min(b[k], hbMax[k]) - math.max(a[k], hbMin[k]))
				vol *= math.max(b[k] - a[k], 1e-6)
			end
			return inter / vol
		end
		local want = coverage(exp.min, exp.max)
		local got = lo[1] < math.huge and coverage(lo, hi) or 0
		row("④-2", ("판정 상자(Hitbox)와 겹치는 비율 ≥ 규격 − %.2f"):format(R.hitboxCoverageDrop), got >= want - R.hitboxCoverageDrop,
			("겹침 %.2f(규격 %.2f) · 상자 %s @ %s"):format(got, want, fmt3(h), fmt3(c)))
	else
		local badQ = {}
		for _, name in ipairs(exp.order) do
			local e, p = exp.parts[name], byName[name]
			if e.query and p and p.min then
				for k = 1, 3 do
					local r = (p.max[k] - p.min[k]) / math.max(e.max[k] - e.min[k], 1e-6)
					if r < R.queryPartRatio.min or r > R.queryPartRatio.max then
						table.insert(badQ, ("%s 축%d %.2f"):format(name, k, r))
						break
					end
				end
			end
		end
		row("④-2", ("판정 파트(query) 크기 ÷ 규격 %.2f ~ %.2f"):format(R.queryPartRatio.min, R.queryPartRatio.max), #badQ == 0, table.concat(badQ, ", "))
	end
	local badPart = {}
	for _, name in ipairs(exp.order) do
		local p = byName[name]
		if p and p.min then
			local longest = math.max(p.max[1] - p.min[1], p.max[2] - p.min[2], p.max[3] - p.min[3])
			local r = longest / math.max(exp.parts[name].longest, 1e-6)
			if r < R.partLongestRatio.min or r > R.partLongestRatio.max then
				table.insert(badPart, ("%s %.2f"):format(name, r))
			end
		end
	end
	row("④-3", ("파트 가장 긴 변 ÷ 규격(%.2f ~ %.2f)"):format(R.partLongestRatio.min, R.partLongestRatio.max), #badPart == 0, table.concat(badPart, ", "))

	-- ⑤ 팔레트
	local allowed = MeshImportCheck.allowedColors(rigId, opts)
	local badColor = {}
	for _, name in ipairs(exp.order) do
		local p = byName[name]
		if p and p.color then
			local d = nearestColor(p.color, allowed)
			if d > Data.palette.toleranceRGB then
				table.insert(badColor, ("%s %s"):format(name, hex(p.color)))
			end
		end
	end
	row("⑤", ("팔레트 색만(허용 %d색 · 채널 차 ≤ %d)"):format(#allowed, Data.palette.toleranceRGB), #badColor == 0, table.concat(badColor, ", "))

	-- ⑥ 클래스 · 투명 · 재질 · 텍스처
	local badClass, badAlpha, badMat, badTex = {}, {}, {}, {}
	for name, p in pairs(byName) do
		if not Data.allowedClasses[p.className or ""] then
			table.insert(badClass, ("%s(%s)"):format(name, tostring(p.className)))
		end
		if (p.transparency or 0) > Data.maxTransparency then
			table.insert(badAlpha, ("%s %.2f"):format(name, p.transparency))
		end
		local e = exp.parts[name]
		local mat = p.material or "SmoothPlastic"
		if not (Data.allowedMaterials[mat] or (e and e.material == mat)) then
			table.insert(badMat, ("%s %s"):format(name, mat))
		end
		if (p.textureId and p.textureId ~= "") or (p.forbidden and #p.forbidden > 0) then
			table.insert(badTex, ("%s %s"):format(name, (p.forbidden and #p.forbidden > 0) and table.concat(p.forbidden, "/") or "TextureID"))
		end
	end
	for _, t in ipairs({ badClass, badAlpha, badMat, badTex }) do
		table.sort(t)
	end
	row("⑥-1", "클래스 MeshPart", #badClass == 0, table.concat(badClass, ", "))
	row("⑥-2", ("투명도 ≤ %s"):format(tostring(Data.maxTransparency)), #badAlpha == 0, table.concat(badAlpha, ", "))
	row("⑥-3", "재질 SmoothPlastic(규격이 정한 재질만 예외)", #badMat == 0, table.concat(badMat, ", "))
	row("⑥-4", "텍스처 · SurfaceAppearance · Decal 없음", #badTex == 0, table.concat(badTex, ", "))

	local pass = 0
	for _, r in ipairs(rows) do
		if r.ok then
			pass += 1
		end
	end
	for _, h in ipairs(hints) do
		table.insert(lines, "[MeshCheck] 힌트: " .. h)
	end
	table.insert(lines, ("[MeshCheck] 결과 %d/%d 통과"):format(pass, #rows))
	return pass == #rows, lines, rows
end

-- ─────────────── Instance → 기술자(Studio) ───────────────
local function localBounds(part, refCF)
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	local h = part.Size / 2
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local q = refCF:PointToObjectSpace(part.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
				lo = { math.min(lo[1], q.X), math.min(lo[2], q.Y), math.min(lo[3], q.Z) }
				hi = { math.max(hi[1], q.X), math.max(hi[2], q.Y), math.max(hi[3], q.Z) }
			end
		end
	end
	return lo, hi
end

function MeshImportCheck.referenceFrame(model)
	local ref = model:FindFirstChild(Data.referenceRootName, true)
	if ref and ref:IsA("BasePart") then
		return ref.CFrame, ref
	end
	return model:GetPivot(), nil
end

function MeshImportCheck.describe(model, opts)
	opts = opts or {}
	local meta = opts.meta
	local refCF, ref = MeshImportCheck.referenceFrame(model)
	local desc = { name = model.Name, reference = ref ~= nil, parts = {}, attached = {} }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= ref then
			local att = d:FindFirstChild(Data.jointAttachmentName)
			local jointWorld = (att and att:IsA("Attachment")) and att.WorldPosition or d:GetPivot().Position
			local lo, hi = localBounds(d, refCF)
			local forbidden = {}
			for _, c in ipairs(d:GetChildren()) do
				if Data.forbiddenChildren[c.ClassName] then
					table.insert(forbidden, c.ClassName)
				end
			end
			local tri = d:GetAttribute(Data.triAttribute)
			if type(tri) ~= "number" and meta and meta.parts and meta.parts[d.Name] then
				tri = meta.parts[d.Name].tris
			end
			if d.Name:match("_Outline$") or (meta and meta.deco and meta.deco[d.Name]) then
				desc.attached[d.Name] = true
			end
			table.insert(desc.parts, {
				name = d.Name, className = d.ClassName, joint = v3(refCF:PointToObjectSpace(jointWorld)), center = v3(refCF:PointToObjectSpace(d.Position)),
				min = lo, max = hi, color = { d.Color.R * 255, d.Color.G * 255, d.Color.B * 255 }, material = d.Material.Name, transparency = d.Transparency,
				triCount = type(tri) == "number" and tri or nil, textureId = d:IsA("MeshPart") and d.TextureID or "", forbidden = forbidden,
			})
		end
	end
	return desc
end

-- 기준 자세 관절 프레임 → CFrame(교체 도우미)
function MeshImportCheck.toCFrame(F)
	local R, p = F.R, F.p
	return CFrame.new(p[1], p[2], p[3], R[1], R[2], R[3], R[4], R[5], R[6], R[7], R[8], R[9])
end

return MeshImportCheck

end

sources.MeshSwap = function()
-- B3 메시 교체 도우미: 가져온 모델(Blender → Studio)의 메시를 같은 이름 리그 파트 자리에 1:1로 끼운다.
--   swap(rigModel, importModel, rigId, opts) - rigModel = shared/BossRig.build로 지은 기준 자세 리그(Motor6D.Transform = 기본 · 루트 Anchored - 개발 미리보기).
--     ① 가져온 파트를 기준 루트(MeshImportCheckData.referenceRootName) 기준 자리 그대로 리그 루트 기준으로 옮긴다(× sizeScale).
--     ② 옛 파트의 Motor6D · 부착점(Rig_*)을 새 메시로 옮기고, 관절 C0 · C1은 규격 관절 프레임(MeshImportCheck.expected)으로 다시 계산한다
--        → 모션(관절 이름 · 계층)은 그대로 · 메시의 피벗이 가져오기에서 어긋나도 관절은 규격 자리에서 돈다.
--     ③ 물리 속성(CanCollide · CanTouch 끔 · CanQuery = 옛 파트 그대로 · Massless)과 색(MeshImportCheckData.swap.recolor)을 옛 파트에서 옮긴다.
--     가져온 모델에 없는 파트는 옛 파트 그대로 둔다(반쯤 만든 모델도 미리볼 수 있다).
--   반환: count(끼운 수), lines(결과 줄 - "[MeshSwap] …"), refCF(가져온 모델 기준 프레임 - 남는 메시를 같은 자리에 둘 때).
--   opts.lift(A2-N3) = 보스 접지 높이(BossRig.rootLift) · 스폰 연결 = shared/ArtMeshKit.applyRig(ArtStyleV1 뒤).
--   스폰(MonsterSpawner · BossRig.build)에는 아직 연결하지 않는다 - 연결 자리 = docs/art/blender-to-studio.md §8.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.MeshImportCheckData)
local MeshImportCheck = require(ReplicatedStorage.Shared.MeshImportCheck)

local MeshSwap = {}

-- A2-N2: 기준 루트 없는 가져오기(A2-N1 FBX)를 Blender 메타로 맞춘다. 메시는 휴식 자세 월드 방향으로 구워져 있다(회전 0) → 가져온 모델 안 상대 배치는 그대로고
--   모르는 것은 평행 이동 하나뿐. 파트마다 (메타 경계 가운데 center - 가져온 파트 가운데)의 평균 = 이동량 · 가장 큰 어긋남 = 배치가 깨졌는지 검사(Data.swap.metaResidualStuds).
--   points = { { name, center = {x,y,z} 가져온 모델 기준 } } · meta = { parts = { [이름] = { center = {x,y,z} } } } (리그 공간 · 배율 1). 반환 offset {x,y,z} · residual · 쓴 수.
function MeshSwap.alignFromMeta(points, meta, scale)
	local S = scale or 1
	local sum, n = { 0, 0, 0 }, 0
	local pairsUsed = {}
	for _, p in ipairs(points) do
		local m = meta and meta.parts and meta.parts[p.name]
		if m and m.center then
			local d = { m.center[1] * S - p.center[1], m.center[2] * S - p.center[2], m.center[3] * S - p.center[3] }
			for k = 1, 3 do
				sum[k] += d[k]
			end
			n += 1
			table.insert(pairsUsed, d)
		end
	end
	if n == 0 then
		return nil, math.huge, 0
	end
	local offset = { sum[1] / n, sum[2] / n, sum[3] / n }
	local residual = 0
	for _, d in ipairs(pairsUsed) do
		residual = math.max(residual, math.sqrt((d[1] - offset[1]) ^ 2 + (d[2] - offset[2]) ^ 2 + (d[3] - offset[3]) ^ 2))
	end
	return offset, residual, n
end

function MeshSwap.swap(rigModel, importModel, rigId, opts)
	opts = opts or {}
	local lines = {}
	local S = opts.scale or 1
	local exp = MeshImportCheck.expected(rigId, S)
	local root = rigModel:FindFirstChild("HumanoidRootPart")
	if not exp or not root then
		table.insert(lines, ("[MeshSwap] 리그 %s 규격 또는 루트 없음 X"):format(tostring(rigId)))
		return 0, lines
	end
	local refCF, ref = MeshImportCheck.referenceFrame(importModel)
	local rootCF = root.CFrame * CFrame.new(0, opts.lift or 0, 0) -- A2-N3: 보스 접지(BossRig.rootLift) - 루트에 붙는 관절이 올라간 만큼 메시 · 관절 자리도 올린다
	local sources = {}
	for _, d in ipairs(importModel:GetDescendants()) do
		if d:IsA("BasePart") and d ~= ref and not Data.ignoreNames[d.Name] then
			sources[d.Name] = sources[d.Name] or d
		end
	end
	-- 기준 루트가 없고 메타(center)가 있으면: 기준 = 모델 피벗의 위치만(회전 0 - 구운 방향) + 메타 평균 이동량
	local metaShift = nil
	if not ref and opts.meta then
		local base = CFrame.new(importModel:GetPivot().Position)
		local points = {}
		for name, src in pairs(sources) do
			local c = base:PointToObjectSpace(src.Position)
			table.insert(points, { name = name, center = { c.X, c.Y, c.Z } })
		end
		local offset, residual, used = MeshSwap.alignFromMeta(points, opts.meta, 1) -- 가져온 모델 단위(배율 전) - 아래 rel × S
		if offset then
			refCF = base * CFrame.new(-offset[1], -offset[2], -offset[3])
			metaShift = { residual = residual, used = used }
			table.insert(lines, ("[MeshSwap] 메타 정렬: 파트 %d · 가장 큰 어긋남 %.3f stud %s"):format(used, residual, residual <= Data.swap.metaResidualStuds and "O" or "X(배치 깨짐 - 가져오기 축 · 배율 확인)"))
		end
	end

	local replaced = {} -- [옛 파트] = 새 메시
	local kept = {}
	for _, name in ipairs(exp.order) do
		local old = rigModel:FindFirstChild(name)
		local src = sources[name]
		if old and old:IsA("BasePart") and src then
			local mesh = src:Clone()
			for _, c in ipairs(mesh:GetChildren()) do
				if not c:IsA("Attachment") then
					c:Destroy() -- 가져온 파트에 딸린 스크립트 · 조인트 · 표면 효과는 옮기지 않는다
				end
			end
			if S ~= 1 then
				mesh.Size = mesh.Size * S
			end
			local rel = refCF:ToObjectSpace(src.CFrame)
			mesh.CFrame = rootCF * (CFrame.new(rel.Position * S) * rel.Rotation)
			mesh.Name = name
			mesh.Anchored = false
			mesh.Massless = true
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.CanQuery = old.CanQuery
			mesh.CastShadow = old.CastShadow
			if Data.swap.recolor then
				mesh.Color = old.Color
				mesh.Material = old.Material -- A2-N3: 리그 재질(Neon 눈 · 룬)도 같이
			end
			mesh:SetAttribute("MeshSwapFrom", importModel:GetFullName())
			mesh.Parent = rigModel
			for _, c in ipairs(old:GetChildren()) do
				if c:IsA("Motor6D") then
					c.Parent = mesh
				elseif c:IsA("Attachment") then
					c.CFrame = mesh.CFrame:ToObjectSpace(old.CFrame * c.CFrame)
					c.Parent = mesh
				end
			end
			replaced[old] = mesh
		else
			table.insert(kept, name)
		end
	end

	-- 관절 다시 걸기: 바뀐 파트에 닿은 Motor6D만(Part1 이름 = 규격 파트 이름 → 규격 관절 프레임)
	local rejoined = 0
	for _, m in ipairs(rigModel:GetDescendants()) do
		if m:IsA("Motor6D") then
			local p0, p1 = replaced[m.Part0], replaced[m.Part1]
			if p0 or p1 then
				m.Part0 = p0 or m.Part0
				m.Part1 = p1 or m.Part1
				local e = m.Part1 and exp.parts[m.Part1.Name]
				if e and m.Part0 then
					local jointWorld = rootCF * MeshImportCheck.toCFrame(e.jointFrame)
					m.C0 = m.Part0.CFrame:ToObjectSpace(jointWorld)
					m.C1 = m.Part1.CFrame:ToObjectSpace(jointWorld)
					rejoined += 1
				end
			end
		end
	end
	local count = 0
	for old in pairs(replaced) do
		old:Destroy()
		count += 1
	end
	rigModel:SetAttribute("MeshSwapped", count)
	table.insert(lines, ("[MeshSwap] %s ← %s(%s): 끼움 %d/%d · 관절 다시 걸기 %d%s %s"):format(rigId, importModel:GetFullName(), ref and "기준 루트" or (metaShift and "메타" or "모델 피벗"), count, #exp.order, rejoined,
		#kept > 0 and (" · 그대로(파트) " .. table.concat(kept, ", ")) or "", count == #exp.order and "O" or "X"))
	return count, lines, refCF
end

return MeshSwap

end

REALMETA = {rock_boar={parts={["Body"]={origin={0.0,-0.1,0.0},center={-0.0,-0.0,0.035}},["Head"]={origin={0.0,-0.05,-1.5},center={0.0,-0.051,-1.95}},["Eyes"]={origin={0.0,0.15,-2.47},center={0.0,0.2,-2.24}},["Tusk_L"]={origin={-0.45,-0.3,-2.45},center={-0.775,0.193,-2.667}},["Tusk_R"]={origin={0.45,-0.3,-2.45},center={0.769,0.165,-2.651}},["Moss"]={origin={0.0,0.75,0.1},center={0.08,0.963,-0.115}},["Leg_FL"]={origin={-0.6,-0.85,-1.0},center={-0.6,-1.165,-1.0}},["Leg_FR"]={origin={0.6,-0.85,-1.0},center={0.6,-1.165,-1.0}},["Leg_BL"]={origin={-0.6,-0.85,1.0},center={-0.6,-1.165,1.0}},["Leg_BR"]={origin={0.6,-0.85,1.0},center={0.6,-1.165,1.0}}}},blue_dragon={parts={["Body"]={origin={0.0,0.9,0.0},center={0.0,1.091,-0.05}},["Leg_FL"]={origin={-1.1,-0.1,-1.5},center={-1.1,-0.807,-1.649}},["Leg_FR"]={origin={1.1,-0.1,-1.5},center={1.1,-0.807,-1.649}},["Leg_BL"]={origin={-1.1,-0.1,1.5},center={-1.1,-0.804,1.314}},["Leg_BR"]={origin={1.1,-0.1,1.5},center={1.1,-0.804,1.314}},["Neck1"]={origin={0.0,1.8,-2.0},center={0.0,3.004,-2.429}},["Head"]={origin={0.0,4.4311,-2.9577},center={-0.007,5.282,-3.186}},["Jaw"]={origin={0.0,4.1311,-3.2577},center={0.0,4.076,-4.083}},["Eyes"]={origin={0.0,4.9311,-4.6577},center={0.0,4.931,-4.558}},["Wing_L"]={origin={-1.5,1.7,-0.4},center={-4.092,3.032,-0.474}},["Wing_R"]={origin={1.5,1.7,-0.4},center={4.092,3.032,-0.474}},["Tail1"]={origin={0.0,1.2,2.3},center={0.0,1.053,3.566}},["Tail2"]={origin={0.0,0.7485,4.8605},center={0.0,0.619,6.028}},["Tail3"]={origin={0.0,0.3318,7.224},center={0.0,0.177,8.43}}}},sand_scorpion={parts={["Body"]={origin={0.0,-0.9,0.0},center={0.0,-0.9,-0.03}},["Head"]={origin={0.0,-0.85,-1.3},center={0.0,-0.869,-1.675}},["Eyes"]={origin={0.0,-0.7,-1.86},center={0.0,-0.66,-1.8}},["Claw_L"]={origin={-0.8,-0.9,-1.6},center={-0.84,-0.817,-1.916}},["Claw_R"]={origin={0.8,-0.9,-1.6},center={0.846,-0.82,-1.916}},["Leg_L"]={origin={-0.85,-1.25,0.1},center={-1.055,-1.167,0.025}},["Leg_R"]={origin={0.85,-1.25,0.1},center={1.055,-1.167,0.025}},["Tail1"]={origin={0.0,-0.6,1.0},center={0.013,-0.11,1.331}},["Tail2"]={origin={0.0,0.383,1.6883},center={0.012,0.861,1.431}},["Tail3"]={origin={0.0,1.3356,1.1383},center={0.0,1.098,0.709}}}},ice_golem={parts={["Body"]={origin={0.0,0.4,0.0},center={0.016,0.601,-0.016}},["Head"]={origin={0.0,1.4,-0.1},center={-0.001,1.8,-0.116}},["Eyes"]={origin={0.0,1.85,-0.56},center={0.0,1.85,-0.7}},["Arm_L"]={origin={-1.6,1.0,0.0},center={-1.591,0.4,-0.005}},["Arm_R"]={origin={1.6,1.0,0.0},center={1.609,0.4,-0.005}},["Fist_L"]={origin={-1.6,-0.4,0.0},center={-1.568,-0.8,-0.011}},["Fist_R"]={origin={1.6,-0.4,0.0},center={1.639,-0.8,-0.014}},["Leg_L"]={origin={-0.6,-0.6,0.0},center={-0.617,-1.05,0.001}},["Leg_R"]={origin={0.6,-0.6,0.0},center={0.583,-1.05,0.001}}}}}
-- A2-N2 3절 하네스: 회전 0으로 구운 메시(A2-N1 FBX)를 메타 center로 정렬 + 관절 다시 걸기가 옛 회전 파트와 같은 움직임을 내는가
local MeshImportCheck = require("MeshImportCheck")
local MeshSwap = require("MeshSwap")

-- 3 × 3 회전(행 우선) + 위치 = 작은 CFrame
local function mul(A, B) -- A · B
	local R = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += A.R[i * 3 + k + 1] * B.R[k * 3 + j + 1]
			end
			R[i * 3 + j + 1] = s
		end
	end
	local p = {}
	for i = 0, 2 do
		p[i + 1] = A.p[i + 1] + A.R[i * 3 + 1] * B.p[1] + A.R[i * 3 + 2] * B.p[2] + A.R[i * 3 + 3] * B.p[3]
	end
	return { R = R, p = p }
end
local function inv(A)
	local R = { A.R[1], A.R[4], A.R[7], A.R[2], A.R[5], A.R[8], A.R[3], A.R[6], A.R[9] }
	local p = {}
	for i = 0, 2 do
		p[i + 1] = -(R[i * 3 + 1] * A.p[1] + R[i * 3 + 2] * A.p[2] + R[i * 3 + 3] * A.p[3])
	end
	return { R = R, p = p }
end
local function point(A, x)
	return mul(A, { R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, p = x }).p
end
local function rotX(deg)
	local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
	return { R = { 1, 0, 0, 0, c, -s, 0, s, c }, p = { 0, 0, 0 } }
end
local function dist(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

local fails = 0
local function check(ok, line)
	print((ok and "O " or "X ") .. line)
	if not ok then
		fails += 1
	end
end

for _, case in ipairs({ { rig = "rock_boar", parts = { "Tusk_L", "Tusk_R", "Head" } }, { rig = "blue_dragon", parts = { "Neck1", "Head", "Wing_L", "Tail2" } } }) do
	local exp = MeshImportCheck.expected(case.rig, 1)
	assert(exp, case.rig)
	-- ① 메타 정렬: 메타 center = 휴식 자세 경계 가운데(파트 가운데 + 구운 모양 탓 어긋남) · 가져오기 = 알 수 없는 이동 T
	local T = { 13.2, -4.7, 88.1 }
	local meta, points = { parts = {} }, {}
	local rotated = 0
	for i, name in ipairs(exp.order) do
		local e = exp.parts[name]
		local c = { e.center[1] + 0.03 * i, e.center[2] - 0.02 * i, e.center[3] + 0.01 * i }
		meta.parts[name] = { center = c }
		table.insert(points, { name = name, center = { c[1] - T[1], c[2] - T[2], c[3] - T[3] } })
		if math.abs(e.jointFrame.R[1] - 1) > 1e-6 or math.abs(e.jointFrame.R[5] - 1) > 1e-6 then
			rotated += 1
		end
	end
	local off, res, used = MeshSwap.alignFromMeta(points, meta, 1)
	check(dist(off, T) < 1e-9 and res < 1e-9 and used == #exp.order, ("%s 메타 정렬: 이동 %.3f %.3f %.3f · 어긋남 %.2e · 파트 %d(회전 관절 %d)"):format(case.rig, off[1], off[2], off[3], res, used, rotated))
	-- 한 파트 축이 뒤집혀 가져와지면(Y↔Z) 어긋남이 문턱을 넘어야 한다
	local broken = table.clone(points)
	local b = broken[2]
	broken[2] = { name = b.name, center = { b.center[1], b.center[3], b.center[2] } }
	local _, res2 = MeshSwap.alignFromMeta(broken, meta, 1)
	check(res2 > 0.05, ("%s 깨진 배치 감지: 어긋남 %.3f > 0.05"):format(case.rig, res2))

	-- ② 관절 다시 걸기: 옛 파트(회전 있음)와 새 메시(회전 0 · 경계 가운데)가 같은 관절 회전에서 같은 자리로 가는가
	for _, name in ipairs(case.parts) do
		local e = exp.parts[name]
		assert(e, name)
		local J = e.jointFrame
		-- 옛 파트 월드 = 관절 프레임 · (-pivot) 이동(expected가 쓰는 식 그대로) = partFrame. 여기서는 center와 관절 회전으로 다시 만든다.
		local oldF = { R = J.R, p = e.center }
		local mc = meta.parts[name].center
		local newF = { R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, p = mc }
		local C1old, C1new = mul(inv(oldF), J), mul(inv(newF), J)
		local worst = 0
		for _, deg in ipairs({ 0, 25, -40, 70 }) do
			local posedOld = mul(mul(J, rotX(deg)), inv(C1old))
			local posedNew = mul(mul(J, rotX(deg)), inv(C1new))
			for _, lp in ipairs({ { 0, 0, 0 }, { 0.3, -0.2, -0.6 }, { -0.5, 0.4, 0.2 } }) do
				local x = point(oldF, lp) -- 옛 파트 위 한 점(월드 휴식)
				local xNewLocal = point(inv(newF), x) -- 구운 메시에서 같은 점
				worst = math.max(worst, dist(point(posedOld, lp), point(posedNew, xNewLocal)))
			end
		end
		local jointStill = dist(point(mul(mul(J, rotX(55)), inv(C1new)), point(inv(newF), J.p)), J.p)
		check(worst < 1e-9 and jointStill < 1e-9, ("%s.%s 관절 회전 4각도: 옛 파트와 차 %.2e · 관절점 고정 %.2e"):format(case.rig, name, worst, jointStill))
	end
end
-- ③ 실제 A2-N1 메타(center · origin): origin = 규격 관절 자리와 같은가 · 정렬은 실제 center로
for rig, m in pairs(REALMETA) do
	local exp = MeshImportCheck.expected(rig, 1)
	local worst, missing = 0, 0
	local pts = {}
	for name, e in pairs(exp.parts) do
		local mp = m.parts[name]
		if mp then
			worst = math.max(worst, dist(mp.origin, e.joint))
			table.insert(pts, { name = name, center = { mp.center[1] + 5, mp.center[2] - 2, mp.center[3] + 1 } })
		else
			missing += 1
		end
	end
	local off, res = MeshSwap.alignFromMeta(pts, m, 1)
	check(worst < 0.01 and missing == 0 and res < 1e-6 and math.abs(off[1] + 5) < 1e-6, ("실제 메타 %s: origin ↔ 규격 관절 최대 %.4f · 빠진 파트 %d · 정렬 어긋남 %.1e"):format(rig, worst, missing, res))
end
print(fails == 0 and "===MESH 하네스 O===" or ("===MESH 하네스 X " .. fails .. "==="))
