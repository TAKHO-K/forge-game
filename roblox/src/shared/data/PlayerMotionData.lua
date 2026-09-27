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

-- ───────── 대검(양손) - 무게감 있는 대각 휘두르기 · 몸통이 따라 돈다 · 3타 내려찍기 ─────────
-- 칼 방향 θ(앞 수평 = 0 · 위 = 90 · 뒤 = 180) ≈ 오른 어깨 x + 팔꿈치 x + 손목 x(옆으로 벌림 z가 작을 때).
local GS_STANCE = { Waist = { 0, -15, 0 }, Neck = { 0, 12, 0 }, RightShoulder = { 35, 0, 5 }, RightElbow = { 55, 0, 0 }, RightWrist = { -45, 0, 0 } } -- 중단(θ 45)
local GS_OVER_R = { Waist = { 8, -40, 0 }, Neck = { 0, 30, 0 }, RightShoulder = { 150, -10, 30 }, RightElbow = { 60, 0, 0 }, RightWrist = { -20, 0, 0 } } -- 오른 어깨 위로 젖힘(θ 190)
local GS_LOW_L = { Waist = { -10, 45, 0 }, Neck = { 0, -30, 0 }, RightShoulder = { 25, 0, -40 }, RightElbow = { 30, 0, 0 }, RightWrist = { -60, 0, 0 } } -- 왼쪽 아래로 따라 휘두름(θ −5)
local GS_OVERHEAD = { Waist = { 12, -5, 0 }, Neck = { -5, 0, 0 }, RightShoulder = { 170, 0, 10 }, RightElbow = { 50, 0, 0 }, RightWrist = { -20, 0, 0 } } -- 머리 위(θ 200)
W.greatsword = {
	ik = "support",
	stance = GS_STANCE,
	move = { Waist = { -5, -12, 0 }, Neck = { 0, 10, 0 }, RightShoulder = { 20, 0, 8 }, RightElbow = { 70, 0, 0 }, RightWrist = { -50, 0, 0 } }, -- 낮춘 중단(θ 40)
	dash = { Waist = { -20, -10, 0 }, Neck = { 15, 5, 0 }, RightShoulder = { 10, 0, 15 }, RightElbow = { 40, 0, 0 }, RightWrist = { -80, 0, 0 } }, -- 몸을 숙이고 칼끝을 앞 아래로(θ −30)
	getupRise = { Root = { 25, 0, 0, 0, -1.3, 0 }, Waist = { -25, 0, 0 }, RightShoulder = { 40, 0, 15 }, RightElbow = { 40, 0, 0 }, RightWrist = { -110, 0, 0 }, RightHip = { 70, 0, 0 }, RightKnee = { -90, 0, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -40, 0, 0 } }, -- 칼을 짚고(θ −30) 한쪽 무릎으로
	attacks = {
		{ ant = MELEE_CONTACT, act = 0.12, rec = 0.235, cocked = GS_OVER_R, -- 1타: 오른 위 → 왼 아래 대각
			contact = { Waist = { -10, 20, 0 }, Neck = { 0, -15, 0 }, RightShoulder = { 75, -20, -10 }, RightElbow = { 15, 0, 0 }, RightWrist = { -75, 0, 0 } }, -- θ 15
			through = GS_LOW_L, settle = GS_LOW_L },
		{ ant = MELEE_CONTACT, act = 0.12, rec = 0.235, cocked = GS_LOW_L, -- 2타: 왼 아래 → 오른 위 거슬러 베기
			contact = { Waist = { -5, -15, 0 }, Neck = { 0, 10, 0 }, RightShoulder = { 95, 10, 30 }, RightElbow = { 15, 0, 0 }, RightWrist = { -90, 0, 0 } }, -- θ 20
			through = { Waist = { 5, -40, 0 }, Neck = { 0, 25, 0 }, RightShoulder = { 140, 10, 55 }, RightElbow = { 25, 0, 0 }, RightWrist = { -70, 0, 0 } }, -- θ 95
			settle = GS_OVERHEAD }, -- → 3타 준비(머리 위)
		{ ant = MELEE_CONTACT, act = 0.14, rec = 0.215, cocked = GS_OVERHEAD, -- 3타: 내려찍기
			contact = { Waist = { -25, 0, 0 }, Neck = { 15, 0, 0 }, RightShoulder = { 60, 0, 5 }, RightElbow = { 10, 0, 0 }, RightWrist = { -70, 0, 0 } }, -- θ 0
			through = { Waist = { -35, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 35, 0, 5 }, RightElbow = { 5, 0, 0 }, RightWrist = { -80, 0, 0 } }, -- θ −40(땅을 찍는다)
			settle = GS_STANCE },
	},
	air = { ant = MELEE_CONTACT, act = 0.15, rec = 0.205, cocked = { Waist = { 10, 0, 0 }, RightShoulder = { 165, 0, 10 }, RightElbow = { 50, 0, 0 }, RightWrist = { -20, 0, 0 } }, -- 공중 내려찍기(몸 앞 기울임 = AirMotion)
		contact = { Waist = { -30, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 45, 0, 5 }, RightElbow = { 10, 0, 0 }, RightWrist = { -70, 0, 0 } }, -- θ −15
		through = { Waist = { -35, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 20, 0, 5 }, RightElbow = { 5, 0, 0 }, RightWrist = { -75, 0, 0 } }, settle = GS_STANCE }, -- θ −50
}

-- ───────── 쌍검(양손 각 1) - 양손 번갈아 빠른 베기 · 3타 교차 베기 ─────────
-- 칼 방향 θ = 그 팔 어깨 x + 팔꿈치 x + 손목 x(왼팔 바깥 = 어깨 z −).
local function with(base, extra)
	local t = table.clone(base)
	for k, v in pairs(extra) do
		t[k] = v
	end
	return t
end
local DB_R_GUARD = { RightShoulder = { 35, 0, 15 }, RightElbow = { 70, 0, 0 }, RightWrist = { -60, 0, 0 } } -- θ 45
local DB_L_GUARD = { LeftShoulder = { 40, 0, -15 }, LeftElbow = { 75, 0, 0 }, LeftWrist = { -70, 0, 0 } }
local DB_STANCE = with(with(DB_R_GUARD, DB_L_GUARD), { Waist = { -5, -10, 0 }, Neck = { 5, 8, 0 } })
local DB_R_UP = with(DB_L_GUARD, { Waist = { 0, -30, 0 }, Neck = { 0, 20, 0 }, RightShoulder = { 110, 0, 45 }, RightElbow = { 60, 0, 0 }, RightWrist = { -30, 0, 0 } }) -- 오른칼 들기(θ 140)
local DB_R_LOW = with(DB_L_GUARD, { Waist = { -8, 30, 0 }, Neck = { 0, -20, 0 }, RightShoulder = { 40, 0, -40 }, RightElbow = { 20, 0, 0 }, RightWrist = { -70, 0, 0 } }) -- 왼쪽 아래로 벤 끝(θ −10)
local DB_L_UP = with(DB_R_GUARD, { Waist = { 0, 30, 0 }, Neck = { 0, -20, 0 }, LeftShoulder = { 110, 0, -45 }, LeftElbow = { 60, 0, 0 }, LeftWrist = { -30, 0, 0 } })
local DB_L_LOW = with(DB_R_GUARD, { Waist = { -8, -30, 0 }, Neck = { 0, 20, 0 }, LeftShoulder = { 40, 0, 40 }, LeftElbow = { 20, 0, 0 }, LeftWrist = { -70, 0, 0 } })
local DB_CROSS_UP = { Waist = { 10, 0, 0 }, Neck = { -5, 0, 0 }, RightShoulder = { 130, 0, 35 }, RightElbow = { 50, 0, 0 }, RightWrist = { -30, 0, 0 }, LeftShoulder = { 130, 0, -35 }, LeftElbow = { 50, 0, 0 }, LeftWrist = { -30, 0, 0 } } -- θ 150
W.dualblade = {
	stance = DB_STANCE,
	move = { Waist = { -10, -5, 0 }, Neck = { 8, 5, 0 }, RightShoulder = { 15, 0, 12 }, RightElbow = { 65, 0, 0 }, RightWrist = { -60, 0, 0 }, LeftShoulder = { 15, 0, -12 }, LeftElbow = { 65, 0, 0 }, LeftWrist = { -60, 0, 0 } }, -- θ 20
	dash = { Waist = { -25, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 5, 0, 20 }, RightElbow = { 50, 0, 0 }, RightWrist = { -85, 0, 0 }, LeftShoulder = { 5, 0, -20 }, LeftElbow = { 50, 0, 0 }, LeftWrist = { -85, 0, 0 } }, -- 숙이고 칼끝 앞 아래(θ −30)
	getupRise = { Root = { 20, 0, 0, 0, -1.3, 0 }, Waist = { -20, 0, 0 }, RightShoulder = { 20, 0, 30 }, RightElbow = { 60, 0, 0 }, LeftShoulder = { 20, 0, -30 }, LeftElbow = { 60, 0, 0 }, RightHip = { 60, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftHip = { 60, 0, 0 }, LeftKnee = { -80, 0, 0 } }, -- 웅크렸다 튀어 오름
	attacks = {
		{ ant = MELEE_CONTACT, act = 0.06, rec = 0.085, cocked = DB_R_UP, -- 1타 오른손 대각
			contact = with(DB_L_GUARD, { Waist = { -8, 10, 0 }, Neck = { 0, -8, 0 }, RightShoulder = { 80, 0, -5 }, RightElbow = { 15, 0, 0 }, RightWrist = { -80, 0, 0 } }), -- θ 15
			through = DB_R_LOW, settle = DB_L_UP },
		{ ant = MELEE_CONTACT, act = 0.06, rec = 0.085, cocked = DB_L_UP, -- 2타 왼손 대각
			contact = with(DB_R_GUARD, { Waist = { -8, -10, 0 }, Neck = { 0, 8, 0 }, LeftShoulder = { 80, 0, 5 }, LeftElbow = { 15, 0, 0 }, LeftWrist = { -80, 0, 0 } }),
			through = DB_L_LOW, settle = DB_CROSS_UP },
		{ ant = MELEE_CONTACT, act = 0.07, rec = 0.075, cocked = DB_CROSS_UP, -- 3타 교차(두 칼이 X자로 몸 앞을 지난다)
			contact = { Waist = { -15, 0, 0 }, Neck = { 10, 0, 0 }, RightShoulder = { 80, 0, -15 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 80, 0, 15 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -80, 0, 0 } }, -- θ 10
			through = { Waist = { -20, 0, 0 }, Neck = { 12, 0, 0 }, RightShoulder = { 45, 0, -40 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 45, 0, 40 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -80, 0, 0 } }, -- θ −25
			settle = DB_STANCE },
	},
	air = { ant = MELEE_CONTACT, act = 0.2, rec = 0.1, cocked = DB_CROSS_UP, -- 공중 회전 베기(몸 한 바퀴 = AirMotion spin) - 두 팔을 옆으로 벌려 칼이 원을 그린다
		contact = { Waist = { -5, 0, 0 }, RightShoulder = { 80, 0, 70 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 80, 0, -70 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -80, 0, 0 } },
		through = { Waist = { -5, 0, 0 }, RightShoulder = { 70, 0, 80 }, RightElbow = { 10, 0, 0 }, RightWrist = { -80, 0, 0 }, LeftShoulder = { 70, 0, -80 }, LeftElbow = { 10, 0, 0 }, LeftWrist = { -80, 0, 0 } }, settle = DB_STANCE },
}

-- ───────── 활(왼손 활 · 오른손 시위) - 활 든 왼팔을 뻗고 오른손을 볼까지 당겨 놓는다 · 공중 = 짧은 정지 후 아래로 ─────────
-- 활 날개 = 왼손 엄지 쪽(θ = 왼 어깨 x + 팔꿈치 x + 손목 x). 조준 = 몸을 오른쪽으로 60° 틀고(허리 y −60) 왼팔을 과녁 쪽으로(어깨 z −60 = 바깥 → 앞) · 오른손 = 시위 IK.
local BOW_STANCE = { Waist = { 0, -25, 0 }, Neck = { 0, 25, 0 }, LeftShoulder = { 35, 0, -10 }, LeftElbow = { 30, 0, 0 }, LeftWrist = { -10, 0, 0 } } -- 활을 몸 앞 낮게(θ 55)
local BOW_AIM = { Waist = { 0, -60, 0 }, Neck = { 0, 55, 0 }, LeftShoulder = { 90, 0, -60 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { 0, 0, 0 } }
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
	air = { ant = 0.429, act = 0.05, rec = 0.1, cocked = BOW_AIM, -- 프레야식: 정지(AirHover) 동안 아래로 겨눔
		contact = { Waist = { -25, -55, 0 }, Neck = { 15, 50, 0 }, LeftShoulder = { 50, 0, -60 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { 0, 0, 0 } },
		through = { Waist = { -25, -55, 0 }, Neck = { 15, 50, 0 }, LeftShoulder = { 50, 0, -60 }, LeftElbow = { 0, 0, 0 }, LeftWrist = { 0, 0, 0 } }, settle = BOW_STANCE, draw = { 0, 1, 0, 0 } },
}

-- ───────── 지팡이(양손) - 양손으로 들어 올려 영창 → 앞으로 뻗기 · 치유는 위로 들기 ─────────
-- 지팡이 머리 방향 θ = 오른 어깨 x + 팔꿈치 x + 손목 x(0 = 앞 수평 · 90 = 위).
local ST_STANCE = { Waist = { 0, -10, 0 }, Neck = { 0, 10, 0 }, RightShoulder = { 20, 0, 8 }, RightElbow = { 70, 0, 0 }, RightWrist = { -10, 0, 0 } } -- θ 80(거의 세움)
local ST_RAISE = { Waist = { 10, -5, 0 }, Neck = { -10, 0, 0 }, RightShoulder = { 160, 0, 10 }, RightElbow = { 20, 0, 0 }, RightWrist = { -90, 0, 0 } } -- 머리 위로 들어 올림(θ 90)
local ST_THRUST = { Waist = { -12, 5, 0 }, Neck = { 5, 0, 0 }, RightShoulder = { 85, 0, 0 }, RightElbow = { 5, 0, 0 }, RightWrist = { -90, 0, 0 } } -- 앞으로 뻗기(θ 0)
W.healer = {
	ik = "support",
	stance = ST_STANCE,
	move = { Waist = { -5, -5, 0 }, Neck = { 0, 5, 0 }, RightShoulder = { 15, 0, 10 }, RightElbow = { 65, 0, 0 }, RightWrist = { -10, 0, 0 } },
	dash = { Waist = { -20, 0, 0 }, Neck = { 15, 0, 0 }, RightShoulder = { 10, 0, 15 }, RightElbow = { 40, 0, 0 }, RightWrist = { -80, 0, 0 } },
	getupRise = { Root = { 25, 0, 0, 0, -1.3, 0 }, Waist = { -25, 0, 0 }, RightShoulder = { 40, 0, 10 }, RightElbow = { 40, 0, 0 }, RightWrist = { -110, 0, 0 }, RightHip = { 70, 0, 0 }, RightKnee = { -90, 0, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -40, 0, 0 } }, -- 지팡이를 짚고(θ −30)
	attacks = {
		{ ant = 0.1925, act = 0.04, rec = 0.064, cocked = ST_STANCE, contact = ST_THRUST, through = ST_THRUST, settle = ST_RAISE },
		{ ant = 0.1925, act = 0.04, rec = 0.064, cocked = ST_RAISE, contact = ST_THRUST, through = ST_THRUST, settle = ST_RAISE },
		{ ant = 0.1925, act = 0.04, rec = 0.064, cocked = ST_RAISE, contact = ST_THRUST, through = ST_THRUST, settle = ST_STANCE },
	},
	-- 치유(스킬 모션 = K - 자세 자리만): 위로 높이 들기(θ 90)
	heal = { Waist = { 12, 0, 0 }, Neck = { -20, 0, 0 }, RightShoulder = { 175, 0, 5 }, RightElbow = { 10, 0, 0 }, RightWrist = { -95, 0, 0 } },
	air = { ant = 0.1925, act = 0.04, rec = 0.1, cocked = ST_RAISE, -- 공중 영창 후 아래로(θ −40)
		contact = { Waist = { -30, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 55, 0, 0 }, RightElbow = { 5, 0, 0 }, RightWrist = { -100, 0, 0 } },
		through = { Waist = { -30, 0, 0 }, Neck = { 20, 0, 0 }, RightShoulder = { 55, 0, 0 }, RightElbow = { 5, 0, 0 }, RightWrist = { -100, 0, 0 } }, settle = ST_STANCE },
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
