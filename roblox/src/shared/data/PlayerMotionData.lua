-- W1 플레이어 모션 세트(무기별) - 코드로 재생하는 포즈 데이터(애니메이션 에셋 업로드 없음 · 라이브에서 그대로 돈다: W1 보고서 ⑤).
--   재생 = client/PoseRig(관절 Transform · 직접 FK · 보조 손 IK) + client/WeaponVisual(모든 캐릭터 - 남의 캐릭터 포함). 시각 계산 = shared/MotionTiming(서버도 같은 함수).
--
-- 관절 = R15 이름(AnimationConstraint · Motor6D 공통 Transform). 값 = { x, y, z } 도(CFrame.Angles 순서) + 선택 { …, dx, dy, dz } 이동(stud - Root만: 누움 · 무릎 = 몸을 내린다 · 루트 파트는 그대로). 부착점 회전이 전부 0이라 축 = 부모 파트 축:
--   어깨 x+ = 팔을 앞으로 든다 · z+ = 오른팔 바깥(왼팔은 z− 가 바깥) · y = 팔 비틀기 / 팔꿈치 x+ = 굽힘 / 손목 x+ = 손등 쪽으로 젖힘(무기 끝이 앞 → 아래)
--   허리(Waist) y+ = 몸통 왼쪽으로 비틂 · x− = 앞으로 숙임 / 목(Neck) = 머리(몸통 반대로 조금 돌려 시선 유지) / Root = 온몸(넘어짐 · 일어나기만)
-- 포즈에 없는 관절 = 애니메이터(걷기 등) 그대로. 상체 포즈는 하체를 안 건드린다(걸으면서 공격).
--
-- 공격 클립(attack1 ~ 3 · heavy · air) = 전조(ant) → 동작(act) → 회복(rec) 세 구간 · 키 포즈 4개:
--   cocked(전조 시작 = 준비) → contact(전조 끝 = 타격 프레임 - hit) → through(동작 끝 = 따라 휘두름) → settle(회복 끝 = 다음 타의 준비 자세 또는 전투 대기)
--   근접 서버 피해 = 요청 즉시(AttackServer) → 타격 프레임(ant) = 1프레임(W2-2 - 궤적도 요청 순간). 무게감 = 준비 자세(이전 타의 회복이 다음 타의 전조) · 긴 따라 휘두름 · 몸통 회전 · 히트스톱.
--   원거리 서버 발사 = MotionTiming.releaseSeconds(같은 함수) → 타격 프레임 = 전조 끝(시위 놓음 · 구슬 발사).
--   구간 이징(선형 금지): ant = inQuad(가속) · act = outCubic(못 박듯 멈춤) · rec = inOutSine. 공격 속도가 빨라지면 전조부터 줄인다(MotionTiming.scale).
--
-- 상태 전환(대기 ↔ 이동 ↔ 수납 ↔ 대시 ↔ 활강 ↔ 공격 끝) = blend 0.15 ~ 0.3초(비선형 - smootherstep).
local P = {}

-- W2-2: 근접 타격 프레임 = 1프레임(서버는 요청을 받는 즉시 판정 · 궤적은 요청 순간 - 셋이 같은 순간). 옛 전조 0.045(대검 · 성기사) · 0.03(쌍검).
--   무게감 = 앞 타의 회복(rec)이 다음 타의 준비 자세 + 따라 휘두름(act) · 히트스톱(판정 시각은 그대로 - 모션이 판정에 맞춘다).
local MELEE_CONTACT = 1 / 60

-- 공통 수치
P.blend = { min = 0.15, max = 0.3, default = 0.2, attackIn = 0.06 } -- attackIn = 공격 시작 때 지금 자세 → cocked(전조 안에 들어가야 타격 프레임이 늦지 않는다)
P.hitstopSeconds = 0.05 -- 타격 순간 클라 히트스톱(모든 타 - 3타 강공격은 WeaponVisual 강공격 값이 더 길다)
P.combatHoldSeconds = 8 -- 마지막 전투 행동 뒤 이만큼 지나면 무기를 수납(서버 Player Attribute CombatUntil)
P.drawSeconds = 0.35 -- 꺼내기 · 수납 동작
P.drawGrabT = 0.45 -- 꺼내기 동작 중 무기가 수납 자리 → 손으로 옮겨 붙는 순간(비율)
P.idlePeriodSeconds = 2.4 -- 전투 대기 숨쉬기 주기
P.moveBlendSpeed = 4 -- 이동 속도(stud/s) 0 → 이 값 이상에서 이동 자세 가중치 1
P.speedScale = { antMinFraction = 0.4, antMinSeconds = 0.015, recMinFraction = 0.3, actMinFraction = 0.5, actMinSeconds = 0.03 } -- MotionTiming.scale
P.heavySlow = 0.7 -- 3타 강공격 = 따라 휘두름 · 회복을 이만큼 느리게(타격 프레임은 그대로 - 서버 즉시 판정)
-- 원거리 서버 발사 시각(초 - 요청 뒤 · 투사체 비행 제외) = W1 전 서버 값 그대로(옛 AttackMotionData releaseT × 길이: 활 0.78 × 0.55 · 지팡이 0.55 × 0.35) ·
--   공격 속도 · 3타 · 공중과 무관(옛 서버와 같다). 밸런스 불변: 이 값을 바꾸면 처치 시간이 바뀐다(W1 후속 실측 - 0.20초로 줄였더니 EconSim 상위 1% 25,300이
--   1,968 → 1,759시간). 모션이 이 시각에 맞춘다: 활 · 지팡이는 발사를 예약(큐)해 이 시각에 놓는다 - 공격 간격이 더 짧으면 당긴 채 연사(WeaponVisual).
P.rangedReleaseSeconds = { bow = 0.78 * 0.55, healer = 0.55 * 0.35 }
-- W2 결정 4: 공중 사격만 시위를 빨리 놓는다 - 공중 정지(AttackMotionData.bow.air.hoverSeconds 0.25) 안에 발사(옛 0.429 = 떨어지기 시작한 뒤 발사).
--   공중 공격 수는 체공 예산(MoveRules.airAttackBudget)이 정하므로 공중 피해 ÷ 지상 ≤ 0.66 불변 · 정지 시간 · 대공 잡기 체공 기록 불변. 지팡이(0.1925)는 이미 정지 안.
P.rangedAirReleaseSeconds = { bow = 0.2 }
-- W2-6 활 당기는 손: 놓는 순간 튕김(kickSeconds - 손목 펴기 포함) · 연사 사이 "다음 화살 잡기" = 발사 간격의 앞 returnFraction 동안 손이 시위로 돌아간다.
P.bowHand = { kickSeconds = 0.12, returnFraction = 0.35 }
-- C3-2 · W3a 활 강궁(SkillData.bow.Q.heavyShot - 버프 중 발사): 더 깊게 당김 = 당김 고정점을 귀 쪽 뒤로(drawAnchorExtra - 머리 기준 · WeaponRigSpec.bow.drawAnchor에 더한다 · 시위도 drawStudsScale배) ·
--   쏜 뒤 반동 = recoilSeconds 동안 recoil 포즈를 sin 모양으로 더 한다(몸이 뒤로 살짝 밀림 - Root 뒤로 · 허리 젖힘 · 머리는 과녁 유지).
P.heavyShot = { drawAnchorExtra = Vector3.new(0.25, 0.05, 0.45), drawStudsScale = 1.35, recoilSeconds = 0.26,
	recoil = { Root = { 6, 0, 0, 0, 0, 0.35 }, Waist = { 10, 0, 0 }, Neck = { -6, 0, 0 } } }
-- W2 결정 1: 근접 대상(클라 조준 = 서버와 같은 AimPicker)이 옆 · 뒤면 몸을 먼저 그쪽으로 빠르게 돌려 휘두른다(Root 관절 - 연출만 · 판정 · 루트 파트 불변) → 리본 방향 = 맞은 방향
P.turnToTarget = { minDeg = 50, seconds = 0.04 }
-- W2-4 활 · 지팡이: 대상이 이 거리(루트 ↔ 루트) 안이면 쏘는 대신 휘두르는 모습(피해 · 판정 시각 = 원거리 그대로 - 타격 프레임 = 서버 발사 시각 · 화살 · 구슬은 안 그린다)
P.closeSwing = { rangeStuds = 6 }

-- 넘어짐 → 일어나기(W1 · BR1-4가 부른다): 장난감처럼 튕김 → 짧게 누움 → 무기별 일어나기 → 전투 자세 · 전체 ≤ 0.8초 ·
--   일어나는 동안 서버 무적(getupInvulnSeconds - 서버가 발사 허가 · 강제 이동 기록을 본 뒤에만) · 입력 버퍼(공격 · 대시 = 끝나는 순간 나간다).
P.getup = {
	bounceSeconds = 0.14, lieSeconds = 0.2, riseSeconds = 0.34, settleSeconds = 0.1, -- 합 0.78
	invulnSeconds = 0.68, -- 착지 ~ 일어나기 끝(튕김 + 누움 + 일어남 - 서버 무적 · 받는 피해 0)
	bufferSeconds = 0.8, -- 이 시간 안에 누른 공격 · 대시 1개를 끝나는 순간 낸다(마지막 것)
	serverWindowSeconds = 3, -- 서버: 보스 발사(HeightGuard.grantLaunch)가 이 시간 안에 있었고 아직 안 썼을 때만 무적(발사 1건당 1회)
	minGapSeconds = 1.2, -- 서버: 무적 요청 간격
	-- 전신 포즈(Root 포함). bounce = 튕겨 뒤로 젖힘 · lie = 등을 대고 누움(Root x = 뒤로 눕기) · rise = 무기별(아래 weapons[].getupRise)
	bounce = { Root = { 18, 0, 6, 0, -0.4, 0 }, Waist = { 10, 0, 0 }, Neck = { 10, 0, 0 }, RightWrist = { -60, 0, 0 }, LeftWrist = { -60, 0, 0 }, RightShoulder = { 30, 0, 40 }, LeftShoulder = { 30, 0, -40 }, RightHip = { 40, 0, 0 }, LeftHip = { 25, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftKnee = { -10, 0, 0 } },
	lie = { Root = { 80, 0, 0, 0, -2.3, 0.4 }, Waist = { 5, 0, 0 }, Neck = { -20, 0, 0 }, RightWrist = { -95, 0, 0 }, LeftWrist = { -95, 0, 0 }, -- 손목을 꺾어 무기를 몸 옆으로 눕힌다
		 RightShoulder = { 10, 0, 25 }, LeftShoulder = { 10, 0, -25 }, RightHip = { 10, 0, 0 }, LeftHip = { 30, 0, 0 }, RightKnee = { -15, 0, 0 }, LeftKnee = { -50, 0, 0 } },
}

-- 무기별(직업 id) - stance = 전투 대기 · move = 무기 든 채 이동(상체) · dash · glide · sheathed(수납 중 팔 = 애니메이터 그대로 - 비어 있음) ·
--   attacks[1 ~ 3] · heavy(3타 강공격 - 없으면 attacks[3]) · air(공중 공격 - MV1 몸 기울임 · 회전은 AirMotion이 따로) · getupRise(일어나는 자세).
--   ik = 보조 손 IK("support" = 왼손 → 무기 Support 점 · "string" = 오른손 → 시위 당김 점 · 없음).
local W = {}

-- ───────── W3a 공통: 몸 전체(발 → 허리 → 어깨 → 팔 → 무기) ─────────
-- 다리 · Root 키: body(dy, stride, yaw, lean) = 무게 싣기(dy = 루트를 내리는 양 stud · 두 무릎을 같이 굽혀 발이 땅에 남게) · stride = 앞뒤 벌림(도 - + = 왼발 앞) ·
--   yaw = 온몸 돌림(도 - Root y) · lean = 온몸 앞 숙임(도 - Root x −). 다리 길이 ≈ 2.3(R15 허벅지 + 정강이) - 두 다리 모두 발 높이 = 2.3 × cos(a) × cos(stride).
--   걷는 동안은 다리 키의 가중치를 이동 속도만큼 줄인다(WeaponVisual - 걸으며 공격 · 다리 = 애니메이터).
local LEG = 2.3
local function body(dy, stride, yaw, lean)
	dy, stride = math.max(dy or 0, 0), stride or 0
	local cs = math.cos(math.rad(stride))
	local ca = math.clamp((LEG * cs - dy) / (LEG * cs), -1, 1) -- 두 다리 발 높이 = LEG·cos(a)·cos(s) = LEG·cos(s) − dy
	local a = math.deg(math.acos(ca))
	return {
		Root = { -(lean or 0), yaw or 0, 0, 0, -dy, 0 },
		LeftHip = { a + stride, 0, 0 }, LeftKnee = { -2 * a, 0, 0 },
		RightHip = { a - stride, 0, 0 }, RightKnee = { -2 * a, 0, 0 },
	}
end
local function with(base, extra)
	local t = table.clone(base)
	for k, v in pairs(extra) do
		t[k] = v
	end
	return t
end
P.body = body

-- ───────── 대검(양손 · W3a) - 어깨 위로 크게 들었다가 체중을 실어 내려베기 · 가로베기 · 3타 = 몸을 크게 돌려 내려찍기 ─────────
-- 칼 방향 θ ≈ 오른 어깨 x + 팔꿈치 x + 손목 x(옆으로 벌림 z가 작을 때). 왼손 = 보조 손 IK(자루 아래 - WeaponRigSpec.greatsword support).
-- 무게: 전조 = 앞 타의 회복(settle = 다음 타의 들어 올림) · 동작 = 무게에 끌려가듯 길게(outCubic) · 무릎을 굽혀 루트를 내린다 · 따라 휘두름이 몸 반대편 아래까지.
local GS_READY = with(body(0.12, 8, 0, 0), { Waist = { 0, -20, 0 }, Neck = { 0, 15, 0 }, RightShoulder = { 40, 0, 10 }, RightElbow = { 60, 0, 0 }, RightWrist = { -40, 0, 0 } }) -- 중단(θ 60) · 살짝 굽힘
local GS_UP_R = with(body(0.08, -10, -12, 0), { Waist = { 12, -60, 0 }, Neck = { -5, 45, 0 }, RightShoulder = { 170, -15, 40 }, RightElbow = { 70, 0, 0 }, RightWrist = { -5, 0, 0 } }) -- 오른 어깨 위로 젖힘(θ 235 - 칼이 등 뒤로 늘어진다)
local GS_LOW_L = with(body(0.42, 22, 18, 8), { Waist = { -25, 50, 0 }, Neck = { 12, -40, 0 }, RightShoulder = { 35, 0, -45 }, RightElbow = { 15, 0, 0 }, RightWrist = { -80, 0, 0 } }) -- 왼쪽 아래까지 끌려감(θ −30)
local GS_LOAD_L = with(body(0.22, -6, 18, 0), { Waist = { 0, 55, 0 }, Neck = { 0, -40, 0 }, RightShoulder = { 80, 0, -60 }, RightElbow = { 30, 0, 0 }, RightWrist = { -100, 0, 0 } }) -- 왼 허리 옆에 칼을 눕혀 장전(θ 10)
local GS_OVERHEAD = with(body(0, 0, -25, 0), { Waist = { 15, -10, 0 }, Neck = { -10, 5, 0 }, RightShoulder = { 175, 0, 15 }, RightElbow = { 60, 0, 0 }, RightWrist = { 0, 0, 0 } }) -- 머리 위로 크게(θ 235) · 몸을 오른쪽으로 감아 둔다
W.greatsword = {
	ik = "support",
	stance = GS_READY,
	move = { Waist = { -5, -12, 0 }, Neck = { 0, 10, 0 }, RightShoulder = { 20, 0, 8 }, RightElbow = { 70, 0, 0 }, RightWrist = { -50, 0, 0 } }, -- 낮춘 중단(θ 40)
	dash = { Waist = { -20, -10, 0 }, Neck = { 15, 5, 0 }, RightShoulder = { 10, 0, 15 }, RightElbow = { 40, 0, 0 }, RightWrist = { -80, 0, 0 } }, -- 몸을 숙이고 칼끝을 앞 아래로(θ −30)
	getupRise = { Root = { 25, 0, 0, 0, -1.3, 0 }, Waist = { -25, 0, 0 }, RightShoulder = { 40, 0, 15 }, RightElbow = { 40, 0, 0 }, RightWrist = { -110, 0, 0 }, RightHip = { 70, 0, 0 }, RightKnee = { -90, 0, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -40, 0, 0 } }, -- 칼을 짚고(θ −30) 한쪽 무릎으로
	attacks = {
		{ ant = MELEE_CONTACT, act = 0.17, rec = 0.23, cocked = GS_UP_R, -- 1타: 오른 어깨 위 → 체중 싣고 왼 아래로 대각 내려베기
			contact = with(body(0.3, 16, 8, 4), { Waist = { -12, -5, 0 }, Neck = { 5, 5, 0 }, RightShoulder = { 105, -15, 12 }, RightElbow = { 20, 0, 0 }, RightWrist = { -60, 0, 0 } }), -- θ 65(내려오는 중)
			through = GS_LOW_L, settle = GS_LOAD_L }, -- 회복 = 2타 장전(왼 허리)
		{ ant = MELEE_CONTACT, act = 0.17, rec = 0.23, cocked = GS_LOAD_L, -- 2타: 왼 허리 → 한 발 내딛으며 오른쪽으로 가로베기
			contact = with(body(0.28, 20, -5, 3), { Waist = { -6, 0, 0 }, Neck = { 0, 0, 0 }, RightShoulder = { 85, 0, 10 }, RightElbow = { 10, 0, 0 }, RightWrist = { -90, 0, 0 } }), -- θ 5 · 몸 앞 수평
			through = with(body(0.34, 14, -22, 4), { Waist = { -10, -62, 0 }, Neck = { 0, 45, 0 }, RightShoulder = { 75, 0, 70 }, RightElbow = { 15, 0, 0 }, RightWrist = { -85, 0, 0 } }), -- 오른쪽 뒤까지 끌려감(θ 5)
			settle = GS_OVERHEAD }, -- 회복 = 3타 준비(머리 위로 크게 · 몸을 감는다)
		{ ant = MELEE_CONTACT, act = 0.2, rec = 0.26, cocked = GS_OVERHEAD, -- 3타: 몸을 크게 돌리며 온몸으로 내려찍기
			-- Play 3 다듬음: 옛 초안(루트 −0.6 ~ −0.75 · 숙임 10 ~ 14° · 손목 −75)은 몸이 너무 가라앉아 칼이 땅속으로 들어가 안 보였다
			contact = with(body(0.38, 24, 16, 6), { Waist = { -22, 12, 0 }, Neck = { 14, -10, 0 }, RightShoulder = { 95, 0, 5 }, RightElbow = { 10, 0, 0 }, RightWrist = { -45, 0, 0 } }), -- θ 60(앞으로 내리꽂는 중)
			through = with(body(0.45, 26, 20, 8), { Waist = { -30, 16, 0 }, Neck = { 18, -14, 0 }, RightShoulder = { 70, 0, 5 }, RightElbow = { 5, 0, 0 }, RightWrist = { -55, 0, 0 } }), -- θ 20(앞 아래로 찍은 끝)
			settle = GS_READY },
	},
	air = { ant = MELEE_CONTACT, act = 0.17, rec = 0.2, cocked = with(GS_OVERHEAD, { RightHip = { 55, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftHip = { 35, 0, 0 }, LeftKnee = { -60, 0, 0 }, Root = { 0, 0, 0 } }), -- 공중 내려찍기(다리 접음 · 몸 앞 기울임 = AirMotion)
		contact = { Waist = { -30, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 45, 0, 5 }, RightElbow = { 10, 0, 0 }, RightWrist = { -70, 0, 0 }, RightHip = { 40, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -40, 0, 0 } }, -- θ −15
		through = { Waist = { -38, 0, 0 }, Neck = { 22, 0, 0 }, RightShoulder = { 20, 0, 5 }, RightElbow = { 5, 0, 0 }, RightWrist = { -75, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftHip = { 15, 0, 0 }, LeftKnee = { -30, 0, 0 } }, settle = GS_READY }, -- θ −50
}

-- ───────── 쌍검(양손 각 1 · W3a) - 몸 회전 + 한 발 스텝과 함께 두 칼 시차 교차 베기 · 3타 = 양손 동시 크게 ─────────
-- 한 번의 공격 = 두 칼 묶음(ClassData hitsPerSwing 2): 동작 구간(act) 끝 = 앞 칼만 다 벤 자리 · 뒤 칼은 회복(rec) 앞부분에 따라 벤다(시차) → 회복 끝 = 다음 타 준비.
-- 칼 방향 θ = 그 팔 어깨 x + 팔꿈치 x + 손목 x(왼팔 바깥 = 어깨 z −).
local DB_R_GUARD = { RightShoulder = { 35, 0, 15 }, RightElbow = { 70, 0, 0 }, RightWrist = { -60, 0, 0 } } -- θ 45
local DB_L_GUARD = { LeftShoulder = { 40, 0, -15 }, LeftElbow = { 75, 0, 0 }, LeftWrist = { -70, 0, 0 } }
local DB_STANCE = with(with(with(DB_R_GUARD, DB_L_GUARD), body(0.2, 12, 0, 4)), { Waist = { -5, -10, 0 }, Neck = { 5, 8, 0 } })
local DB_R_HIGH = { RightShoulder = { 130, 0, 50 }, RightElbow = { 60, 0, 0 }, RightWrist = { -20, 0, 0 } } -- 오른칼 오른 어깨 위(θ 170)
local DB_L_HIGH = { LeftShoulder = { 130, 0, -50 }, LeftElbow = { 60, 0, 0 }, LeftWrist = { -20, 0, 0 } }
local DB_R_MID = { RightShoulder = { 85, 0, -10 }, RightElbow = { 15, 0, 0 }, RightWrist = { -80, 0, 0 } } -- 몸 앞을 가로지르는 중(θ 20)
local DB_L_MID = { LeftShoulder = { 85, 0, 10 }, LeftElbow = { 15, 0, 0 }, LeftWrist = { -80, 0, 0 } }
local DB_R_LOW = { RightShoulder = { 40, 0, -45 }, RightElbow = { 15, 0, 0 }, RightWrist = { -80, 0, 0 } } -- 왼쪽 아래로 다 벤 끝(θ −25)
local DB_L_LOW = { LeftShoulder = { 40, 0, 45 }, LeftElbow = { 15, 0, 0 }, LeftWrist = { -80, 0, 0 } }
local function db(parts, extra)
	local t = {}
	for _, part in ipairs(parts) do
		for k, v in pairs(part) do
			t[k] = v
		end
	end
	for k, v in pairs(extra) do
		t[k] = v
	end
	return t
end
local DB_1_READY = db({ DB_R_HIGH, DB_L_GUARD, body(0.16, -8, -15, 0) }, { Waist = { 5, -35, 0 }, Neck = { 0, 25, 0 } }) -- 오른칼 들고 몸을 오른쪽으로 감음
local DB_2_READY = db({ DB_R_LOW, DB_L_HIGH, body(0.22, 18, 12, 4) }, { Waist = { 0, 30, 0 }, Neck = { 0, -22, 0 } }) -- 1타 끝 = 왼칼 들림(2타 준비)
local DB_3_READY = db({ DB_R_HIGH, DB_L_HIGH, body(0.05, 0, 0, 0) }, { Waist = { 12, 0, 0 }, Neck = { -8, 0, 0 } }) -- 두 칼 머리 위로 크게(X 준비)
W.dualblade = {
	stance = DB_STANCE,
	move = { Waist = { -10, -5, 0 }, Neck = { 8, 5, 0 }, RightShoulder = { 15, 0, 12 }, RightElbow = { 65, 0, 0 }, RightWrist = { -60, 0, 0 }, LeftShoulder = { 15, 0, -12 }, LeftElbow = { 65, 0, 0 }, LeftWrist = { -60, 0, 0 } }, -- θ 20
	dash = { Waist = { -25, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 5, 0, 20 }, RightElbow = { 50, 0, 0 }, RightWrist = { -85, 0, 0 }, LeftShoulder = { 5, 0, -20 }, LeftElbow = { 50, 0, 0 }, LeftWrist = { -85, 0, 0 } }, -- 숙이고 칼끝 앞 아래(θ −30)
	getupRise = { Root = { 20, 0, 0, 0, -1.3, 0 }, Waist = { -20, 0, 0 }, RightShoulder = { 20, 0, 30 }, RightElbow = { 60, 0, 0 }, LeftShoulder = { 20, 0, -30 }, LeftElbow = { 60, 0, 0 }, RightHip = { 60, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftHip = { 60, 0, 0 }, LeftKnee = { -80, 0, 0 } }, -- 웅크렸다 튀어 오름
	attacks = {
		{ ant = MELEE_CONTACT, act = 0.12, rec = 0.24, cocked = DB_1_READY, -- 1타: 왼발 내딛으며 몸을 왼쪽으로 돌려 오른칼 → (시차) 왼칼 교차
			contact = db({ DB_R_MID, DB_L_HIGH, body(0.2, 14, -2, 2) }, { Waist = { -8, 0, 0 }, Neck = { 0, 0, 0 } }),
			through = db({ DB_R_LOW, DB_L_MID, body(0.26, 20, 10, 4) }, { Waist = { -10, 25, 0 }, Neck = { 0, -18, 0 } }), -- 오른칼 끝 · 왼칼 가로지르는 중(시차)
			settle = DB_2_READY },
		{ ant = MELEE_CONTACT, act = 0.12, rec = 0.24, cocked = DB_2_READY, -- 2타: 오른발 딛으며 몸을 오른쪽으로 되돌려 왼칼 → (시차) 오른칼
			contact = db({ DB_L_MID, DB_R_LOW, body(0.2, -6, 4, 2) }, { Waist = { -8, 5, 0 }, Neck = { 0, -4, 0 } }),
			through = db({ DB_L_LOW, DB_R_MID, body(0.26, -14, -12, 4) }, { Waist = { -10, -28, 0 }, Neck = { 0, 20, 0 } }),
			settle = DB_3_READY },
		{ ant = MELEE_CONTACT, act = 0.14, rec = 0.24, cocked = DB_3_READY, -- 3타: 두 칼 동시에 X자로 크게 내려 벤다(몸을 숙이며 한 발 깊게)
			contact = db({ DB_R_MID, DB_L_MID, body(0.45, 24, 0, 10) }, { Waist = { -20, 0, 0 }, Neck = { 12, 0, 0 } }),
			through = db({ DB_R_LOW, DB_L_LOW, body(0.55, 26, 0, 14) }, { Waist = { -28, 0, 0 }, Neck = { 16, 0, 0 } }),
			settle = DB_STANCE },
	},
	air = { ant = MELEE_CONTACT, act = 0.2, rec = 0.1, cocked = db({ DB_R_HIGH, DB_L_HIGH }, { Waist = { 10, 0, 0 }, RightHip = { 50, 0, 0 }, RightKnee = { -70, 0, 0 }, LeftHip = { 50, 0, 0 }, LeftKnee = { -70, 0, 0 } }), -- 공중 회전 베기(몸 한 바퀴 = AirMotion spin) - 다리를 접고 두 팔을 옆으로 벌려 칼이 원을 그린다
		contact = { Waist = { -5, 0, 0 }, RightShoulder = { 80, 0, 70 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 80, 0, -70 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -80, 0, 0 }, RightHip = { 45, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { 45, 0, 0 }, LeftKnee = { -60, 0, 0 } },
		through = { Waist = { -5, 0, 0 }, RightShoulder = { 70, 0, 80 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 70, 0, -80 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -80, 0, 0 }, RightHip = { 35, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftHip = { 35, 0, 0 }, LeftKnee = { -45, 0, 0 } }, settle = DB_STANCE },
}

-- ───────── 활(왼손 활 · 오른손 시위) - 활 든 왼팔을 뻗고 오른손을 볼까지 당겨 놓는다 · 공중 = 짧은 정지 후 아래로 ─────────
-- 활 날개 = 왼손 엄지 쪽(θ = 왼 어깨 x + 팔꿈치 x + 손목 x). 조준(W2-6) = 몸을 옆으로 90° 틀고(허리 y −90 · 왼 어깨가 과녁 쪽) 머리는 과녁을 본다(목 +85) ·
--   왼팔 = 활을 과녁 쪽으로 곧게(화살 축이 당김 고정점 = 턱 · 뺨 옆을 지나게 - WeaponRigSpec.bow.drawAnchor) · 오른손 = 시위 IK(고정점까지).
--   값 = 체형 4종 모형 최적화(화살 방향 = 앞 수평 · 공중 = 13° 아래 + 몸 숙임 22°) - 활은 23° 눕힘(오른쪽 위로).
local BOW_STANCE = { Waist = { 0, -25, 0 }, Neck = { 0, 25, 0 }, LeftShoulder = { 35, 0, -10 }, LeftElbow = { 30, 0, 0 }, LeftWrist = { -10, 0, 0 } } -- 활을 몸 앞 낮게(θ 55)
local BOW_AIM = { Waist = { -5, -90, 0 }, Neck = { 5, 85, 0 }, LeftShoulder = { 32.7, -42.7, -68.5 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -21.5, 45, -29.5 } }
local BOW_AIM_AIR = { Waist = { -12, -90, 0 }, Neck = { 12, 85, 0 }, LeftShoulder = { 45.2, -37.8, -57.8 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { -16.6, 45, -35.1 } }
W.bow = {
	ik = "string", -- 오른손 → 시위 당김 점(당김 = draw 0 ~ 1)
	stance = BOW_STANCE,
	move = { Waist = { -5, -15, 0 }, Neck = { 0, 15, 0 }, LeftShoulder = { 15, 0, -10 }, LeftElbow = { 25, 0, 0 }, LeftWrist = { -10, 0, 0 } },
	dash = { Waist = { -20, -10, 0 }, Neck = { 15, 10, 0 }, LeftShoulder = { -15, 0, -20 }, LeftElbow = { 40, 0, 0 }, LeftWrist = { -20, 0, 0 } },
	getupRise = { Root = { 20, 0, 0, 0, -1.3, 0 }, Waist = { -20, -20, 0 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 30, 0, 0 }, RightHip = { 70, 0, 0 }, RightKnee = { -90, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -50, 0, 0 } },
	-- 원거리 공격: 전조 = 들어 올리며 당김(draw 0 → 1 · 길이 = 서버 발사 시각 rangedReleaseSeconds) · 타격 프레임 = 놓음 · 동작 = 시위 튕김 · 회복 = 조준 유지 → 대기. 연사 = 큐(WeaponVisual)
	attacks = {
		{ ant = 0.429, act = 0.05, rec = 0.08, cocked = BOW_STANCE, contact = BOW_AIM, through = BOW_AIM, settle = BOW_AIM, draw = { 0, 1, 0, 0 } },
		{ ant = 0.429, act = 0.05, rec = 0.08, cocked = BOW_AIM, contact = BOW_AIM, through = BOW_AIM, settle = BOW_AIM, draw = { 0, 1, 0, 0 } },
		{ ant = 0.429, act = 0.05, rec = 0.08, cocked = BOW_AIM, contact = BOW_AIM, through = BOW_AIM, settle = BOW_STANCE, draw = { 0, 1, 0, 0 } },
	},
	-- W2-4 가까운 대상: 활을 왼 어깨 위로 들었다가 앞 오른쪽 아래로 후려친다(타격 = 서버 발사 시각 - ant 고정)
	closeSwing = { ant = P.rangedReleaseSeconds.bow, act = 0.08, rec = 0.12,
		cocked = { Waist = { 5, 30, 0 }, Neck = { 0, -25, 0 }, LeftShoulder = { 150, 0, -30 }, LeftElbow = { 40, 0, 0 }, LeftWrist = { -20, 0, 0 } },
		contact = { Waist = { -15, -30, 0 }, Neck = { 10, 25, 0 }, LeftShoulder = { 70, 0, 20 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -60, 0, 0 } },
		through = { Waist = { -20, -45, 0 }, Neck = { 10, 35, 0 }, LeftShoulder = { 40, 0, 40 }, LeftElbow = { 15, 0, 0 }, LeftWrist = { -70, 0, 0 } }, settle = BOW_STANCE },
	air = { ant = 0.2, act = 0.05, rec = 0.1, cocked = BOW_AIM, -- 프레야식: 정지(AirHover 0.25) 안에 아래로 겨눠 놓는다(ant = rangedAirReleaseSeconds.bow)
		contact = BOW_AIM_AIR, through = BOW_AIM_AIR, settle = BOW_STANCE, draw = { 0, 1, 0, 0 } },
}

-- ───────── 지팡이(W3a - 한 손 지팡이 + 빈손 = 시전 손) ─────────
-- 오른손 = 지팡이(머리 방향 θ = 오른 어깨 x + 팔꿈치 x + 손목 x · 0 = 앞 수평 · 90 = 위). 왼손 = 대상 쪽으로 손바닥을 펴 뻗는 시전 손(배를 잡지 않는다 - 보조 손 IK 없음).
-- 시전 = 지팡이를 들어 모았다가(전조 - 서버 발사 시각까지) 지팡이 머리와 왼 손바닥을 같이 앞으로 내민다(타격 프레임 = 발사) · 한 발 내딛으며 몸을 싣는다.
local ST_LEFT_REST = { LeftShoulder = { 15, 0, -12 }, LeftElbow = { 25, 0, 0 }, LeftWrist = { 0, 0, 0 } } -- 빈손 = 몸 옆 자연스럽게(배 잡기 금지)
local ST_STANCE = with(with(ST_LEFT_REST, body(0.08, 6, 0, 0)), { Waist = { 0, -12, 0 }, Neck = { 0, 10, 0 }, RightShoulder = { 20, 0, 10 }, RightElbow = { 70, 0, 0 }, RightWrist = { -10, 0, 0 } }) -- 지팡이 세움(θ 80)
local ST_GATHER = with(body(0.05, -6, -10, 0), { Waist = { 8, -30, 0 }, Neck = { -5, 22, 0 }, RightShoulder = { 150, 0, 20 }, RightElbow = { 40, 0, 0 }, RightWrist = { -90, 0, 0 }, -- 지팡이 머리 위로 모음(θ 100)
	LeftShoulder = { 60, 0, 25 }, LeftElbow = { 100, 0, 0 }, LeftWrist = { 30, 0, 0 } }) -- 왼손 = 가슴 앞으로 끌어 모음(힘 모으기)
local ST_CAST = with(body(0.22, 18, 10, 4), { Waist = { -12, 15, 0 }, Neck = { 6, -10, 0 }, RightShoulder = { 95, 0, 15 }, RightElbow = { 10, 0, 0 }, RightWrist = { -95, 0, 0 }, -- 지팡이 머리 앞으로(θ 10)
	LeftShoulder = { 88, 0, 8 }, LeftElbow = { 8, 0, 0 }, LeftWrist = { -70, 0, 0 } }) -- 왼손 = 대상 쪽으로 뻗고 손바닥을 편다(손목 젖힘)
local ST_CAST_HOLD = with(body(0.26, 20, 12, 5), { Waist = { -14, 18, 0 }, Neck = { 8, -12, 0 }, RightShoulder = { 90, 0, 15 }, RightElbow = { 12, 0, 0 }, RightWrist = { -95, 0, 0 },
	LeftShoulder = { 92, 0, 6 }, LeftElbow = { 4, 0, 0 }, LeftWrist = { -75, 0, 0 } })
W.healer = {
	-- ik 없음: 한 손 지팡이(W3a - 옛 양손 IK는 보조 손이 지팡이 아래 = 배 앞에 머물러 "배를 잡는" 자세였다)
	stance = ST_STANCE,
	move = with(ST_LEFT_REST, { Waist = { -5, -5, 0 }, Neck = { 0, 5, 0 }, RightShoulder = { 15, 0, 10 }, RightElbow = { 65, 0, 0 }, RightWrist = { -10, 0, 0 } }),
	dash = { Waist = { -20, 0, 0 }, Neck = { 15, 0, 0 }, RightShoulder = { 10, 0, 15 }, RightElbow = { 40, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { -20, 0, -20 }, LeftElbow = { 20, 0, 0 } },
	getupRise = { Root = { 25, 0, 0, 0, -1.3, 0 }, Waist = { -25, 0, 0 }, RightShoulder = { 40, 0, 10 }, RightElbow = { 40, 0, 0 }, RightWrist = { -110, 0, 0 }, RightHip = { 70, 0, 0 }, RightKnee = { -90, 0, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -40, 0, 0 } }, -- 지팡이를 짚고(θ −30)
	attacks = {
		{ ant = 0.1925, act = 0.06, rec = 0.12, cocked = ST_GATHER, contact = ST_CAST, through = ST_CAST_HOLD, settle = ST_GATHER },
		{ ant = 0.1925, act = 0.06, rec = 0.12, cocked = ST_GATHER, contact = ST_CAST, through = ST_CAST_HOLD, settle = ST_GATHER },
		{ ant = 0.1925, act = 0.08, rec = 0.16, cocked = ST_GATHER, contact = with(ST_CAST, { Waist = { -18, 5, 0 } }), through = with(ST_CAST_HOLD, { Waist = { -22, 5, 0 } }), settle = ST_STANCE },
	},
	-- W2-4 가까운 대상: 오른 어깨 위로 젖혔다가 왼쪽 아래로 대각 휘두르기(타격 = 서버 발사 시각) · 왼손은 균형
	closeSwing = { ant = P.rangedReleaseSeconds.healer, act = 0.08, rec = 0.1,
		cocked = with(body(0.05, -6, -10, 0), { Waist = { 8, -40, 0 }, Neck = { 0, 30, 0 }, RightShoulder = { 150, -10, 30 }, RightElbow = { 60, 0, 0 }, RightWrist = { -20, 0, 0 }, LeftShoulder = { 30, 0, -40 }, LeftElbow = { 30, 0, 0 } }),
		contact = with(body(0.2, 16, 8, 4), { Waist = { -10, 20, 0 }, Neck = { 0, -15, 0 }, RightShoulder = { 75, -20, -10 }, RightElbow = { 15, 0, 0 }, RightWrist = { -75, 0, 0 }, LeftShoulder = { 20, 0, -50 }, LeftElbow = { 20, 0, 0 } }),
		through = with(body(0.24, 18, 12, 5), { Waist = { -10, 45, 0 }, Neck = { 0, -30, 0 }, RightShoulder = { 25, 0, -40 }, RightElbow = { 30, 0, 0 }, RightWrist = { -60, 0, 0 }, LeftShoulder = { 25, 0, -55 }, LeftElbow = { 20, 0, 0 } }), settle = ST_STANCE },
	-- 치유(스킬 모션 = K - 자세 자리만): 위로 높이 들기(θ 90)
	heal = { Waist = { 12, 0, 0 }, Neck = { -20, 0, 0 }, RightShoulder = { 175, 0, 5 }, RightElbow = { 10, 0, 0 }, RightWrist = { -95, 0, 0 } },
	air = { ant = 0.1925, act = 0.04, rec = 0.1, cocked = with(ST_GATHER, { Root = { 0, 0, 0 }, RightHip = { 40, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { 25, 0, 0 }, LeftKnee = { -45, 0, 0 } }), -- 공중 모았다가 아래로(θ −40) · 왼손도 아래로
		contact = { Waist = { -30, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 55, 0, 0 }, RightElbow = { 5, 0, 0 }, RightWrist = { -100, 0, 0 }, LeftShoulder = { 60, 0, 5 }, LeftElbow = { 5, 0, 0 }, LeftWrist = { -70, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -30, 0, 0 } },
		through = { Waist = { -30, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 55, 0, 0 }, RightElbow = { 5, 0, 0 }, RightWrist = { -100, 0, 0 }, LeftShoulder = { 60, 0, 5 }, LeftElbow = { 5, 0, 0 }, LeftWrist = { -70, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -30, 0, 0 } }, settle = ST_STANCE },
}

-- ───────── 방패망치(성기사 - 출시 후 · 데이터 자리만) - 방패를 앞에 두고 망치를 머리 위에서 내려친다 ─────────
local PH_STANCE = { LeftShoulder = { 60, 0, -10 }, LeftElbow = { 80, 0, 0 }, LeftWrist = { 0, 0, 0 }, RightShoulder = { 20, 0, 15 }, RightElbow = { 80, 0, 0 }, RightWrist = { 0, 0, 0 } }
local PH_UP = { Waist = { 10, -10, 0 }, LeftShoulder = { 60, 0, -10 }, LeftElbow = { 80, 0, 0 }, RightShoulder = { 170, 0, 15 }, RightElbow = { 60, 0, 0 }, RightWrist = { 20, 0, 0 } }
local PH_DOWN = { Waist = { -20, 0, 0 }, LeftShoulder = { 55, 0, -10 }, LeftElbow = { 85, 0, 0 }, RightShoulder = { 60, 0, 5 }, RightElbow = { 10, 0, 0 }, RightWrist = { -20, 0, 0 } }
W.paladin = {
	stance = PH_STANCE, move = PH_STANCE, dash = PH_STANCE, getupRise = PH_STANCE,
	attacks = {
		{ ant = MELEE_CONTACT, act = 0.12, rec = 0.205, cocked = PH_UP, contact = PH_DOWN, through = PH_DOWN, settle = PH_UP },
		{ ant = MELEE_CONTACT, act = 0.12, rec = 0.205, cocked = PH_UP, contact = PH_DOWN, through = PH_DOWN, settle = PH_UP },
		{ ant = MELEE_CONTACT, act = 0.14, rec = 0.205, cocked = PH_UP, contact = PH_DOWN, through = PH_DOWN, settle = PH_STANCE },
	},
	air = { ant = MELEE_CONTACT, act = 0.15, rec = 0.205, cocked = PH_UP, contact = PH_DOWN, through = PH_DOWN, settle = PH_STANCE },
}

-- 활강(모든 무기 공통 - 무기는 수납 자리로): 두 팔을 머리 위 글라이더로
P.glide = { Waist = { -5, 0, 0 }, Neck = { 10, 0, 0 }, RightShoulder = { 165, 0, 20 }, RightElbow = { 25, 0, 0 }, LeftShoulder = { 165, 0, -20 }, LeftElbow = { 25, 0, 0 } }
-- 꺼내기 · 수납(손이 수납 자리로 뻗는 자세): back = 오른손이 오른 어깨 뒤로 · hip = 양손이 허리로
P.reach = {
	back = { Waist = { 0, -15, 0 }, RightShoulder = { 165, 0, 25 }, RightElbow = { 110, 0, 0 }, RightWrist = { 20, 0, 0 } },
	hip = { Waist = { -5, 0, 0 }, RightShoulder = { -15, 0, 15 }, RightElbow = { 30, 0, 0 }, LeftShoulder = { -15, 0, -15 }, LeftElbow = { 30, 0, 0 } },
}

P.weapons = W
return P
