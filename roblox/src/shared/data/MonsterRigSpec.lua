-- M2 잡몹 몸체 규격(참조 = docs/art/ref/10_monsters_T1-T3.png · 11_monsters_T4-T6.png). 보스 리그(BossRigSpec)와 같은 관절 표 · 같은 조립 함수(shared/BossRig.build - 파트 + Motor6D).
--   초안 = 단순 도형(block · ball · wedge) · 몸체당 파트 ≤ 10 · SmoothPlastic 단색 · 외형 파트는 CanCollide · CanQuery · CanTouch 전부 끔(판정은 MonsterSpawner의 투명 Hitbox · 루트 - 크기 = 옛 몸통 + 머리 그대로).
--   카툰 교체 = 같은 이름 파트 자리에 메시를 끼우면 된다(관절 이름 · 계층 · 부모 공간 자리가 약속 - docs/design/monster-body-draft.md).
-- 표준 부위 이름(필요한 것만 쓴다): Body(몸통 - 필수 · 색 틴트 · 피격 번쩍임) · Head(머리 - 필수 · 이름표 · 피해 숫자 기준) · Eyes · Leg_FL/FR/BL/BR(네 발) · Leg_L/R(두 발 · 막대 다리) ·
--   Arm_L/R · Fist_L/R · Claw_L/R · Tail1..n · Wing_L/R · Ear_L/R · Horn_L/R · Shell / Shell1..n(등 껍데기 · 수정) · Tentacle1..n · Wool(털 덩어리) · Tusk_L/R · Moss(등 이끼) · Flower.
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

for _, rig in pairs(rigs) do
	rig.attach = rig.attach or {}
	assert(#rig.joints <= 10, "M2 몸체 초안은 파트 10개 이하")
end

return { rigs = rigs, maxParts = 10 }
