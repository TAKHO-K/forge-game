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

-- ═════════════════════════════ W3b 나머지 모션(W3a 기준 그대로 - docs/design/motion-standard.md) ═════════════════════════════
-- 힘 = 발 → 허리 → 어깨 → 팔 → 무기 · 무기 무게만큼 준비 · 따라 휘두름 · 전조 → 동작 → 회복 · 선형 보간 금지 · 판정 시각 · 값 불변(모션이 판정에 맞춘다).

-- ───────── 스킬(SkillInput → WeaponVisual.playSkill · 남 = 중계 AirMoveFx "skillQ" · "skillE") ─────────
-- 한 번 동작 = 공격 클립과 같은 모양(ant → act → rec · 키 포즈 4개 · 같은 이징). 대검 Q · 활 E = 서버가 대시 시작 순간 판정 → 전조를 짧게 · 동작 = 대시 이동 시간 동안.
-- channel(대검 E · 쌍검 E) = 서버 틱(SkillData channelSeconds ÷ tickCount - 시전 순간부터)에 맞춘 주기 동작: spinDeg = 틱 한 번에 도는 온몸 회전(Root) · 틱 순간이 가장 빠르게(wobbleDeg) /
--   alternate = 틱마다 두 포즈를 번갈아(틱 = 한 칼 끝). 채널이 끝나면 through → settle(rec). trail = 동작 · 채널 동안 리본 · ik = false면 보조 손 · 시위 IK 끔.
-- 히트스톱: 서버 결과(맞음)가 오면 SkillInput이 applyHitstop - 채널은 틱 시각이 밀리지 않게 포즈만 잠깐 멈추고 시계는 그대로(WeaponVisual).
local S = {}
-- 대검 Q 관통돌진: 오른 허리 뒤로 칼을 당겨 몸을 감았다가(전조) → 깊은 런지로 앞으로 곧게 찌르며 미끄러진다(대시 0.25초 = 동작) → 무게에 끌려 한 발 더 → 중단
local GS_COIL = with(body(0.4, -12, -28, 0), { Waist = { 0, -45, 0 }, Neck = { 0, 35, 0 }, RightShoulder = { 25, 0, 25 }, RightElbow = { 95, 0, 0 }, RightWrist = { -110, 0, 0 } }) -- θ 10(허리 옆 뒤)
-- Play 1 다듬음: 숙임(루트 + 허리)만큼 칼도 같이 기울어 칼끝이 땅을 찍었다 → 어깨를 숙임만큼 더 들어 칼을 수평으로(θ = 어깨 + 팔꿈치 + 손목 − 숙임) · 무릎 덜 굽힘
local GS_THRUST = with(body(0.35, 30, 4, 10), { Waist = { -10, 5, 0 }, Neck = { 10, -5, 0 }, RightShoulder = { 115, 0, 5 }, RightElbow = { 5, 0, 0 }, RightWrist = { -93, 0, 0 } }) -- 몸 기준 θ 27 − 숙임 20 ≈ 앞으로 곧게
local GS_THRUST_END = with(body(0.4, 32, 6, 12), { Waist = { -14, 8, 0 }, Neck = { 12, -6, 0 }, RightShoulder = { 120, 0, 3 }, RightElbow = { 2, 0, 0 }, RightWrist = { -98, 0, 0 } })
-- 대검 E 회전베기: 왼 허리 장전 → 칼을 오른쪽 옆으로 수평으로 뻗고 낮은 자세로 온몸이 돈다(틱 1초마다 한 바퀴 · 틱 순간 가장 빠름) → 무게에 끌려 멈춤
local GS_SPIN = with(body(0.34, 0, 0, 4), { Waist = { -6, 0, 0 }, Neck = { 0, 0, 0 }, RightShoulder = { 88, 0, 55 }, RightElbow = { 5, 0, 0 }, RightWrist = { -92, 0, 0 } }) -- θ 0 · 오른쪽 옆
S.greatsword = {
	Q = { ant = 0.06, act = 0.22, rec = 0.32, cocked = GS_COIL, contact = GS_THRUST, through = GS_THRUST_END, settle = GS_READY, trail = true },
	E = { ant = 0.12, act = 0.12, rec = 0.36, cocked = GS_LOAD_L, contact = GS_SPIN, through = with(GS_SPIN, { Waist = { -14, 20, 0 }, Neck = { 6, -15, 0 } }), settle = GS_READY, trail = true,
		channel = { spinDeg = -360, wobbleDeg = 22 } },
}
-- 쌍검 Q 그림자분신: 두 칼을 얼굴 앞 X로 모았다가 → 양옆으로 떨쳐 펼치며 반 발 물러선다(분신이 그 자리에)
local DB_CROSS = db({ { RightShoulder = { 110, 0, -35 }, RightElbow = { 40, 0, 0 }, RightWrist = { -20, 0, 0 } }, { LeftShoulder = { 110, 0, 35 }, LeftElbow = { 40, 0, 0 }, LeftWrist = { -20, 0, 0 } }, body(0.25, 0, 0, 2) }, { Waist = { 4, 0, 0 }, Neck = { -4, 0, 0 } })
local DB_SPREAD = db({ { RightShoulder = { 55, 0, 50 }, RightElbow = { 5, 0, 0 }, RightWrist = { -60, 0, 0 } }, { LeftShoulder = { 55, 0, -50 }, LeftElbow = { 5, 0, 0 }, LeftWrist = { -60, 0, 0 } }, body(0.3, -16, 0, -4) }, { Waist = { 8, 0, 0 }, Neck = { -6, 0, 0 } }) -- 앞 아래 사선으로 떨침(Play 1: 옆 수평은 T자처럼 보였다)
-- 쌍검 E 난무: 틱(1/6초)마다 한 칼 - 오른칼 · 왼칼을 번갈아 몸을 좌우로 틀며 벤다
local DB_FLURRY_R = db({ DB_R_LOW, DB_L_HIGH, body(0.32, 16, 12, 6) }, { Waist = { -10, 28, 0 }, Neck = { 0, -20, 0 } })
local DB_FLURRY_L = db({ DB_L_LOW, DB_R_HIGH, body(0.32, -10, -12, 6) }, { Waist = { -10, -28, 0 }, Neck = { 0, 20, 0 } })
S.dualblade = {
	Q = { ant = 0.1, act = 0.15, rec = 0.26, cocked = DB_CROSS, contact = DB_CROSS, through = DB_SPREAD, settle = DB_STANCE, trail = true },
	E = { ant = 0.05, act = 0.1, rec = 0.26, cocked = DB_1_READY, contact = DB_FLURRY_L, through = DB_3_READY, settle = DB_STANCE, trail = true,
		channel = { alternate = { DB_FLURRY_R, DB_FLURRY_L } } },
}
-- 활 Q 강궁(버프 켜기): 활을 들어 올려 깊게 당기고(강궁 당김) 가슴을 펴 버틴다 → 대기 / 활 E 백스텝샷: 뒤로 뛰며 몸을 젖히고 다리를 접음(과녁 조준 유지) → 웅크려 착지
local BOW_HOP = with(BOW_AIM, { Root = { 12, 0, 0, 0, 0.1, 0 }, RightHip = { 55, 0, 0 }, RightKnee = { -85, 0, 0 }, LeftHip = { 35, 0, 0 }, LeftKnee = { -60, 0, 0 } })
S.bow = {
	Q = { ant = 0.14, act = 0.34, rec = 0.26, cocked = BOW_STANCE, contact = with(BOW_AIM, body(0.22, 14, 0, 0)), through = with(with(BOW_AIM, body(0.16, 14, 0, -6)), { Neck = { -6, 85, 0 } }), settle = BOW_STANCE,
		draw = { 0, 1, 1, 0 }, heavyShot = true },
	E = { ant = 0.03, act = 0.2, rec = 0.3, cocked = BOW_STANCE, contact = BOW_HOP, through = with(BOW_AIM, { Root = { 6, 0, 0, 0, 0, 0 }, RightHip = { 25, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftHip = { 15, 0, 0 }, LeftKnee = { -20, 0, 0 } }),
		settle = with(BOW_AIM, body(0.45, 12, 0, 6)), draw = { 0, 0.4, 0.6, 0 } },
}
-- 치유사 Q 치유: 지팡이를 모았다가 높이 들고 왼 손바닥을 하늘로 · 가슴을 편다 / E 딜링모드: 지팡이를 앞 땅에 내리꽂고 체중을 싣는다(왼주먹 가슴 앞)
local ST_HEAL = with(body(0, 0, 0, -4), { Waist = { 10, 0, 0 }, Neck = { -18, 0, 0 }, RightShoulder = { 172, 0, 8 }, RightElbow = { 8, 0, 0 }, RightWrist = { -95, 0, 0 }, LeftShoulder = { 150, 0, -30 }, LeftElbow = { 15, 0, 0 }, LeftWrist = { -60, 0, 0 } })
local ST_PLANT = with(body(0.38, 20, 0, 10), { Waist = { -14, 10, 0 }, Neck = { 8, -8, 0 }, RightShoulder = { 60, 0, 12 }, RightElbow = { 20, 0, 0 }, RightWrist = { -150, 0, 0 }, LeftShoulder = { 70, 0, 10 }, LeftElbow = { 70, 0, 0 }, LeftWrist = { 0, 0, 0 } }) -- θ −70
S.healer = {
	Q = { ant = 0.16, act = 0.36, rec = 0.3, cocked = ST_GATHER, contact = ST_HEAL, through = with(ST_HEAL, { Root = { 4, 0, 0, 0, 0.08, 0 } }), settle = ST_STANCE },
	E = { ant = 0.12, act = 0.14, rec = 0.3, cocked = ST_GATHER, contact = ST_PLANT, through = with(ST_PLANT, { Root = { -12, 0, 0, 0, -0.45, 0 }, Waist = { -18, 10, 0 } }), settle = ST_STANCE, trail = true },
}
P.skills = S

-- ───────── 덧씌움 반응(피격 · 착지 · 도약 · 공중 점프 · 활강 시작/끝 - 지금 포즈 위에 곱한다) ─────────
-- 모양 = 빠르게 들어가(peak × seconds - outCubic) → hold초 버팀 → 천천히 풀림(inOutSine). 포즈에 없는 관절은 가중치 = 세기(애니메이터 위로 섞는다).
P.overlay = {
	-- 피격(서버 PlayerHitFeedback - 내 캐릭터): 한 대가 최대 체력의 bigHitFraction 이상 = 큰 피격(뒤로 밀림) · 미만 = 움찔 · 쉴드만 막음 = 움찔
	bigHitFraction = 0.12,
	flinch = { seconds = 0.22, peak = 0.2, pose = { Root = { 5, 0, 0, 0, -0.06, 0.12 }, Waist = { 8, 0, 4 }, Neck = { -10, 0, 0 }, RightShoulder = { -8, 0, 6 }, LeftShoulder = { -8, 0, -6 } } },
	big = { seconds = 0.5, peak = 0.16, hold = 0.06, pose = { Root = { 14, 0, 0, 0, -0.22, 0.55 }, Waist = { 14, 0, 0 }, Neck = { -14, 0, 0 }, RightShoulder = { -20, 0, 18 }, LeftShoulder = { -20, 0, -18 }, RightHip = { -10, 0, 0 }, LeftHip = { 18, 0, 0 }, LeftKnee = { -25, 0, 0 } } },
	-- 착지(모든 캐릭터 - 착지 직전 아래 속도): softSpeed 이상 = 무릎 굽혀 받기 · heavySpeed 이상 = "쿵"(깊게 웅크려 왼손으로 땅 짚기). 낙하 쓰러짐(FallKnockdown) · 넉백 착지(일어나기)는 제외.
	softSpeed = 22, heavySpeed = 60, -- 지상 점프 한 번 착지 ≈ 38 · 나무 정거장 한 층 ≈ 60+
	landSoft = { seconds = 0.26, peak = 0.3, pose = with(body(0.3, 6, 0, 6), { Waist = { -6, 0, 0 } }) },
	landHeavy = { seconds = 0.6, peak = 0.12, hold = 0.16, pose = with(body(0.95, 18, 0, 22), { Waist = { -18, 0, 0 }, Neck = { 14, 0, 0 }, LeftShoulder = { 55, 0, -15 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { 0, 0, 0 } }) },
	-- 도약(지상 점프 · 모든 캐릭터 - 세로 속도로 감지) · 코요테 점프(내 캐릭터 - 발판 끝을 발끝으로 차고 몸을 앞으로 던짐) · 공중 점프(무릎 당겨 안기 - 앞 한 바퀴 = AirMotion flip)
	takeoff = { seconds = 0.3, peak = 0.35, pose = { Waist = { 6, 0, 0 }, Neck = { -6, 0, 0 }, RightHip = { -12, 0, 0 }, LeftHip = { 45, 0, 0 }, LeftKnee = { -75, 0, 0 } } },
	coyote = { seconds = 0.34, peak = 0.3, pose = { Waist = { -14, 0, 0 }, Neck = { 10, 0, 0 }, RightHip = { -22, 0, 0 }, RightKnee = { -20, 0, 0 }, LeftHip = { 55, 0, 0 }, LeftKnee = { -80, 0, 0 } } },
	airJump = { seconds = 0.4, peak = 0.3, pose = { Waist = { -12, 0, 0 }, RightHip = { 75, 0, 0 }, RightKnee = { -110, 0, 0 }, LeftHip = { 60, 0, 0 }, LeftKnee = { -100, 0, 0 } } },
	-- 2단 대시: 첫 대시 자세 위에 몸을 비틀어 한 번 더 박차는 모양(허리 · 루트 회전)
	dash2 = { seconds = 0.3, peak = 0.3, pose = { Root = { -8, -25, 0 }, Waist = { -6, 25, 0 }, Neck = { 0, -15, 0 } } },
	-- 활강 시작(몸을 쭉 펴 바람 받기 - 팔 = P.glide) · 끝(다리를 앞으로 내밀어 착지 준비)
	glideIn = { seconds = 0.34, peak = 0.35, pose = { Waist = { 8, 0, 0 }, Neck = { -8, 0, 0 }, RightHip = { -15, 0, 0 }, LeftHip = { -15, 0, 0 }, RightKnee = { -10, 0, 0 }, LeftKnee = { -10, 0, 0 } } },
	glideOut = { seconds = 0.4, peak = 0.3, pose = { Waist = { 12, 0, 0 }, Neck = { -6, 0, 0 }, RightHip = { 50, 0, 0 }, RightKnee = { -40, 0, 0 }, LeftHip = { 45, 0, 0 }, LeftKnee = { -35, 0, 0 } } },
	-- 넉백 체공(내 캐릭터 AirLocked 동안 유지 - 착지하면 넘어짐 → 일어나기): 뒤로 젖히고 팔다리가 앞으로 딸려 온다
	knockAir = { Root = { 25, 0, 0 }, Waist = { 15, 0, 0 }, Neck = { -15, 0, 0 }, RightShoulder = { 120, 0, 40 }, LeftShoulder = { 120, 0, -40 }, RightHip = { 55, 0, 0 }, RightKnee = { -70, 0, 0 }, LeftHip = { 35, 0, 0 }, LeftKnee = { -50, 0, 0 } },
	-- 기절(보스 playerStun - 모든 화면): 비틀(stagger - 큰 피격처럼 뒤로) → 휘청(dazed 자세 위에 sway 진폭(도 · z축) · 주기) → 회복(recoverSeconds 동안 풀림)
	stun = { staggerSeconds = 0.35, recoverSeconds = 0.35, swayPeriod = 1.1,
		dazed = with(body(0.35, 8, 0, 8), { Waist = { -12, 0, 0 }, Neck = { 22, 0, 0 }, RightShoulder = { -15, 0, 8 }, LeftShoulder = { -15, 0, -8 } }),
		sway = { Root = 7, Waist = -6, Neck = 10 } },
}

-- ───────── 넘어짐 → 일어나기(무기별 무릎 짚기 - getup.riseSeconds를 kneelFraction : 나머지로 나눈다 · 전체 · 무적 불변) ─────────
P.getup.kneelFraction = 0.45
W.greatsword.getupKneel = with(body(1.1, 30, 0, 18), { Waist = { -20, 0, 0 }, Neck = { 10, 0, 0 }, RightShoulder = { 45, 0, 12 }, RightElbow = { 35, 0, 0 }, RightWrist = { -125, 0, 0 } }) -- 칼끝을 땅에 짚고(θ −45) 한쪽 무릎
W.greatsword.getupRise = with(body(0.35, 18, 0, 10), { Waist = { -12, -10, 0 }, RightShoulder = { 40, 0, 12 }, RightElbow = { 60, 0, 0 }, RightWrist = { -60, 0, 0 } }) -- 칼을 들어 올리며 선다
W.dualblade.getupKneel = db({ DB_R_GUARD, DB_L_GUARD, body(1.15, 0, 0, 14) }, { Waist = { -18, 0, 0 }, Neck = { 12, 0, 0 } }) -- 두 칼을 쥔 채 웅크림
W.dualblade.getupRise = db({ DB_R_GUARD, DB_L_GUARD, body(0.1, 10, 0, -4) }, { Waist = { 6, 0, 0 }, Neck = { -4, 0, 0 } }) -- 튀어 오름
W.bow.getupKneel = with(BOW_STANCE, with(body(1.05, 26, -10, 14), { Waist = { -16, -25, 0 }, RightShoulder = { 40, 0, 15 }, RightElbow = { 30, 0, 0 } })) -- 오른손으로 땅 짚고 활은 몸 앞
W.bow.getupRise = with(BOW_STANCE, body(0.3, 14, 0, 6))
W.healer.getupKneel = with(body(1.1, 28, 0, 16), { Waist = { -18, 0, 0 }, Neck = { 8, 0, 0 }, RightShoulder = { 55, 0, 10 }, RightElbow = { 30, 0, 0 }, RightWrist = { -125, 0, 0 }, LeftShoulder = { 20, 0, -12 }, LeftElbow = { 30, 0, 0 } }) -- 지팡이를 짚고
W.healer.getupRise = with(ST_STANCE, body(0.3, 14, 0, 6))
W.paladin.getupKneel = PH_STANCE

-- ───────── 대시(무기별 - 온몸 숙여 박차기 · W3a 다리 키) ─────────
-- Play 1: 숙임 20 ~ 26°는 무기 끝이 땅에 박혔다 → 12 ~ 14°
W.greatsword.dash = with(W.greatsword.dash, body(0.3, 26, 0, 12))
W.dualblade.dash = with(W.dualblade.dash, body(0.28, 28, 0, 14))
W.bow.dash = with(W.bow.dash, body(0.28, 24, 0, 12))
W.healer.dash = with(W.healer.dash, body(0.28, 24, 0, 12))

-- ───────── 사망 · 부활(모든 캐릭터 - 서버가 BreakJointsOnDeath 끔 · 쓰러진 뒤 부활까지 그대로 누움) ─────────
-- 사망 = 비틀(뒤로 젖히며 무릎이 풀림) → 무릎 꿇음 → 앞으로 엎어짐(무기는 손에 쥔 채). 부활 = 한쪽 무릎(무기별 getupKneel)에서 → 일어나 → 전투 자세.
P.death = { staggerSeconds = 0.22, kneelSeconds = 0.3, fallSeconds = 0.38,
	stagger = with(body(0.2, -8, 0, -6), { Waist = { 10, 0, 0 }, Neck = { -15, 0, 0 }, RightShoulder = { 10, 0, 15 }, LeftShoulder = { 10, 0, -15 } }),
	kneel = { Root = { -10, 0, 0, 0, -1.2, 0 }, Waist = { -10, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 5, 0, 10 }, LeftShoulder = { 5, 0, -10 }, RightHip = { 95, 0, 0 }, RightKnee = { -95, 0, 0 }, LeftHip = { 5, 0, 0 }, LeftKnee = { -105, 0, 0 } },
	lie = { Root = { -82, 0, 8, 0, -1.95, -0.4 }, Waist = { 5, 0, 0 }, Neck = { -25, 20, 0 }, RightShoulder = { 150, 0, 25 }, RightElbow = { 20, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 150, 0, -25 }, LeftElbow = { 20, 0, 0 }, LeftWrist = { -80, 0, 0 },
		RightHip = { 5, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -30, 0, 0 } }, -- Play 1: 몸이 땅에 묻히고 무기가 솟음 → 높이 −2.3 → −1.95 · 손목으로 무기 눕힘
}
P.respawn = { kneelSeconds = 0.25, riseSeconds = 0.4, settleSeconds = 0.15 }

-- ───────── 꺼내기 · 수납(W1 규격 자리 그대로 - 몸이 따라간다) ─────────
P.reach.back = with(P.reach.back, with(body(0.15, 6, -12, 0), { Waist = { 4, -22, 0 }, Neck = { 0, 16, 0 } })) -- 어깨 뒤로 손을 뻗으며 몸을 비튼다
P.reach.hip = with(P.reach.hip, with(body(0.2, 4, 0, 6), { Waist = { -10, 0, 0 }, Neck = { 6, 0, 0 } })) -- 허리로 손을 내리며 살짝 숙인다

P.weapons = W
return P
