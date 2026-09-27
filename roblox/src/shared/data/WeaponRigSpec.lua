-- 무기 모델 규격(MV1 신설 · W1 보강) - 무기마다 "어떻게 쥐는가"를 모델과 따로 적는다. 새 무기 모델은 이 규격(손잡이 점 · 축 · 기준 크기 · 부착점 이름)만 맞추면
-- 모션(PlayerMotionData)을 다시 만들지 않는다. 기준 = 전통 사용법: 대검 양손 · 쌍검 양손 각 1자루 · 활 = 왼손 활 + 오른손 시위 · 지팡이 양손 · 성기사(출시 후) = 왼손 작은 방패 + 오른손 뿅망치.
--
-- 모델 로컬 축 규칙(모든 무기 공통 - 교체 모델도 같게 만든다):
--   칼 · 망치 = +Z가 끝(칼끝 · 망치 머리) · +X = 날 선(칼 - 베는 쪽) · 지팡이 = +Y가 머리(지금 메시 원본 축) · 활 = X = 날개(위아래 끝) · +Z = 시위 쪽(쏘는 사람 쪽) · 방패 = −Z가 앞면.
-- 부착점(교체 모델 - 이름 고정 · attachments): Grip = 쥐는 손 자리(필수) · Tip = 끝(규격 검사 - 축 · 길이) · Support = 양손 무기 보조 손 자리 · StringNock = 활 시위 가운데(쉬는 자리).
--   지금 모델(SpecialMesh - 부착점 없음)은 아래 grip · support · stringNock 좌표를 쓴다(원본 메시 단위 - 배율 전).
--
--   hands          "both"(양손 한 자루) | "pair"(양손 각 1자루) | "bow"(왼손 활 · 오른손 시위) | "shieldHammer"(왼손 방패 · 오른손 망치)
--   pieces[]       조각마다(한 자루 = 1 · 쌍검 = 2 · 성기사 = 방패 + 망치):
--     name           WeaponModelData 조각 이름(없으면 무기 하나 = "main")
--     hand           쥐는 손(RightHand | LeftHand)
--     grip           손잡이 점(모델 로컬 · 원본 단위). 손바닥 점(palm)에 온다.
--     tipAxis        끝 방향 축("+Z" 등 - 규격 검사가 Tip − Grip 방향과 대조)
--     refLength      기준 크기(끝에서 끝 · stud) · nativeLength = 지금 메시의 원본 길이 → 배율 = refLength ÷ nativeLength(균일)
--     hold           쥔 방향 = 모델 축 → 손 축(손 축: 팔을 내리면 −Y = 손가락 · −Z = 엄지(앞) · +X = 오른쪽). 칼 = 끝이 엄지 쪽 · 날 선이 손가락 쪽(베는 방향).
--     support        양손 무기 보조 손(반대 손) 자리(모델 로컬 · 원본 단위) - 팔 = IK(client/PoseRig)
--     stringNock · drawStuds   활: 시위 가운데(쉬는 자리) · 최대 당김(+Z 방향 stud - 시위 표시 상한). 오른손 = IK로 쉬는 시위 → 당김 고정점
--     drawAnchor     활(W2-6): 다 당긴 오른손 손바닥 자리 = 머리 로컬(+X 오른쪽 · +Y 위 · −Z 얼굴 앞) - 턱 · 뺨 옆(머리 상자 밖 · 얼굴 앞쪽 절반).
--                    머리 기준이라 체형 · 크기가 달라도 손이 얼굴 옆에 온다(옛 = 활 축으로 drawStuds 당김 → 목 뒤로 파고들었다). 시위 가운데는 손바닥을 따라간다.
--     drawPole       당기는 팔꿈치 방향(몸통 로컬 - 오른쪽 = 과녁 반대 · 살짝 아래 = 팔꿈치 어깨 높이) · handBackLimit = 손바닥 머리 로컬 z 상한(머리 뒷면 0.6보다 앞)
--     releaseKick · releaseOpenDeg   놓는 순간 손이 튕기는 거리(머리 로컬 - 뒤 · 바깥) · 손목을 펴는 각(도)
--     sheath         비전투 자리: mount = "back"(UpperTorso) | "hip"(LowerTorso) · pos = 그 파트 기준 손잡이 점 자리 · z · x = 모델 +Z · +X가 향할 방향(그 파트 축)
local function holdOf(xTo, yTo, zTo)
	return CFrame.fromMatrix(Vector3.zero, xTo, yTo, zTo)
end
-- 칼(끝 +Z · 날 +X): 끝 → 엄지(−Z) · 날 선 → 손가락(−Y)
local BLADE_HOLD = holdOf(Vector3.new(0, -1, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))
local SWORD_NATIVE = 3.3 -- "Dual Bronze Sword" 칼날 메시 원본 길이(칼끝 z ≈ +2.1 · 가드 ≈ −0.95 · 자루 끝 ≈ −1.6 - MV1 · W1 눈금 스크린샷)
local STAFF_NATIVE = 5.6 -- 지팡이 메시 원본 길이(스크린샷 - 머리 = 메시 +Y)

local SPEC = {
	attachments = { grip = "Grip", tip = "Tip", support = "Support", stringNock = "StringNock" },
	-- 손바닥 점(손 파트 로컬 - 쥔 주먹 가운데)
	palm = { RightHand = Vector3.new(0, -0.18, -0.05), LeftHand = Vector3.new(0, -0.18, -0.05) },
	-- 규격 검사 허용치(WeaponRigCheck): 길이 ±10% · 보조 손 거리(손잡이 점에서 stud). 축 = 모델의 가장 긴 축이 tipAxis + Tip이 손잡이보다 끝 쪽
	check = { lengthTolerance = 0.1, supportMinStuds = 0.35, supportMaxStuds = 2.2 },
	-- 교체 모델 자리(PropModels와 같은 방식): ReplicatedStorage.Shared.WeaponModels.<직업>(조각이 여럿이면 자식 이름 = 조각 이름) - 없으면 지금 메시
	overrideFolder = "WeaponModels",
}

SPEC.weapons = {
	greatsword = {
		hands = "both",
		pieces = {
			{ hand = "RightHand", grip = Vector3.new(0, 0, -1.1), tipAxis = "+Z", refLength = 5.5, nativeLength = SWORD_NATIVE, hold = BLADE_HOLD,
				support = Vector3.new(0, 0, -1.45), -- 오른손 바로 아래(자루 끝 쪽)
				sheath = { mount = "back", pos = Vector3.new(0.45, 0.95, 0.72), z = Vector3.new(-0.55, -1, 0.05), x = Vector3.new(0, 0, 1) } }, -- 등 대각(손잡이 = 오른 어깨 위)
		},
	},
	dualblade = {
		hands = "pair",
		pieces = {
			{ name = "BladeRight", hand = "RightHand", grip = Vector3.new(0, 0, -1.1), tipAxis = "+Z", refLength = 2.6, nativeLength = SWORD_NATIVE, hold = BLADE_HOLD,
				sheath = { mount = "hip", pos = Vector3.new(0.95, 0.15, 0), z = Vector3.new(0.12, -0.9, 0.5), x = Vector3.new(0, 0.5, 1) } }, -- 허리 양쪽(칼끝 = 뒤 아래)
			{ name = "BladeLeft", hand = "LeftHand", grip = Vector3.new(0, 0, -1.1), tipAxis = "+Z", refLength = 2.6, nativeLength = SWORD_NATIVE, hold = BLADE_HOLD,
				sheath = { mount = "hip", pos = Vector3.new(-0.95, 0.15, 0), z = Vector3.new(-0.12, -0.9, 0.5), x = Vector3.new(0, 0.5, 1) } },
		},
	},
	bow = {
		hands = "bow",
		pieces = {
			-- 활 손잡이 = 가운데 마디 배(WeaponModelData.bow.limbs[3]) · 날개 X = 위아래(엄지 쪽) · 시위 +Z = 쏘는 사람 쪽(팔꿈치 쪽)
			{ hand = "LeftHand", grip = Vector3.new(0, 0, -0.67), tipAxis = "+X", refLength = 5.74, nativeLength = 5.74,
				hold = holdOf(Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0)),
				stringNock = Vector3.new(0, 0, 0.7347), drawStuds = 1.6, stringHand = "RightHand",
				-- W2-6: 체형 4종(표준 · 큰 · 작은 · 날씬 - Studio 실측 부착점) 모형에서 손 · 아래팔 · 활이 머리 상자를 안 뚫고 · 팔꿈치 = 어깨 +0.12 ~ 0.27 · 화살 축 어긋남 ≤ 0.13
				drawAnchor = Vector3.new(1.0, -0.55, -0.1), drawPole = Vector3.new(1, -0.2, 0), handBackLimit = 0.3,
				releaseKick = Vector3.new(0.3, 0.05, 0.25), releaseOpenDeg = 35,
				sheath = { mount = "back", pos = Vector3.new(0, 0.25, 0.75), z = Vector3.new(0, 0, -1), x = Vector3.new(0.55, 1, 0) } }, -- 등(대각 · 시위가 몸 쪽)
		},
	},
	healer = {
		hands = "both",
		pieces = {
			-- 지팡이: 메시 +Y = 머리(W1 스크린샷 - 구슬이 나가는 끝) · 오른손 = 아래쪽 · 왼손 = 그 위(머리 쪽) 1 stud. 지팡이만 끝 축이 +Y(메시 원본 그대로 - 교체 모델도 +Y 머리)
			{ hand = "RightHand", grip = Vector3.new(0, -0.6, 0), tipAxis = "+Y", refLength = 5.6, nativeLength = STAFF_NATIVE,
				hold = holdOf(Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 1, 0)), -- 머리(+Y) = 엄지 쪽
				support = Vector3.new(0, 0.4, 0),
				sheath = { mount = "back", pos = Vector3.new(-0.2, 0.2, 0.72), z = Vector3.new(0, 0, 1), x = Vector3.new(1, -0.45, 0) } }, -- 등 대각(머리 = 오른 어깨 위 · y = z × x)
		},
	},
	-- 성기사(출시 후 - 직업 · 모델 없음): 규격만. 방패 = 팔 안쪽 손잡이(−Z 앞면이 손등 쪽) · 망치 = 자루 끝에서 1/4(머리 +Z)
	paladin = {
		hands = "shieldHammer",
		pieces = {
			{ name = "Shield", hand = "LeftHand", grip = Vector3.new(0, 0, 0.2), tipAxis = "-Z", refLength = 2.4, nativeLength = 2.4,
				hold = holdOf(Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)),
				sheath = { mount = "back", pos = Vector3.new(0, 0.1, 0.75), z = Vector3.new(0, 0, 1), x = Vector3.new(1, 0, 0) } },
			{ name = "Hammer", hand = "RightHand", grip = Vector3.new(0, 0, -0.75), tipAxis = "+Z", refLength = 3.0, nativeLength = 3.0, hold = BLADE_HOLD,
				sheath = { mount = "hip", pos = Vector3.new(0.95, 0.1, 0.1), z = Vector3.new(0, -1, 0.2), x = Vector3.new(0, 0, 1) } },
		},
	},
}

-- 수납 자리 CFrame(마운트 파트 기준 - 손잡이 점이 pos에 · 모델 +Z · +X가 sheath.z · x로).
function SPEC.sheathCFrame(sheath)
	local z = sheath.z.Unit
	local x = (sheath.x - z * sheath.x:Dot(z)).Unit
	return CFrame.fromMatrix(sheath.pos, x, z:Cross(x), z)
end

-- 조각 배율(균일).
function SPEC.scaleOf(piece)
	return piece.refLength / piece.nativeLength
end

return SPEC
