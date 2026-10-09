-- BR1-4b 보스 모션 데이터(4b-2 · 4b-3). 관절 이름(shared/data/BossRigSpec)으로만 부위를 가리킨다 - 모델을 바꿔도 관절 이름이 같으면 그대로 쓴다.
-- 자세(pose) = { [관절 이름] = { rx, ry, rz, px, py, pz } } - 각 = 도, 자리 = 단위(sizeScale 1 기준 · 모델 크기를 곱한다) · **부모 부위 축 기준**(기준 자세 rot와 무관 - shared/BossMotion이 변환).
--   부호(A1 실측): 아래로 늘어진 팔 · 다리를 rx +θ = 앞으로 든다 · 무릎 굽힘 rx −θ · 허리 앞 숙임 rx −θ · 고개 숙임 rx −θ · 오른팔 rz + = 옆으로 벌림(왼팔 −) · ry + = 왼쪽으로 돈다.
-- 동작(clip) = {
--   pre = { { f, pose, ease } … }  전조: f = 스킬 시작 → 때리는 순간(서버 전조 bubbleSeconds) 사이 비율 - 전조가 길든 짧든 **때리는 순간에 동작이 온다**(판정 시각 불변).
--   post = { { s, pose, ease } … } 동작 · 지나침 · 회복: s = 때리는 순간 뒤 초.
--   loop = { period, poses = { … } } 마지막 키 뒤 스킬이 끝날 때까지 되풀이(채널 - 빔 · 회오리).
--   hitstop(초) · squash(단위 - 몸 눌림) · tremble = { from, amp, joints } 전조 끝 떨림(강화 평타 - BR1-3 규칙) · flash = 부위 이름(떨림 동안 번쩍) }
-- ease = "in" | "out" | "inout" | "back"(살짝 지나쳐 돌아옴) - 직선 보간 없음. 동작 사이 섞기 = blendIn(기본 0.18초) · 끝 섞기 0.3초.
local D = {}

-- 좌우 대칭: _R ↔ _L 이름을 바꾸고 ry · rz · px 부호를 뒤집는다.
local function mirror(pose)
	local out = {}
	for joint, v in pairs(pose) do
		local name = joint:gsub("_R$", "_TMP"):gsub("_L$", "_R"):gsub("_TMP$", "_L")
		out[name] = { v[1] or 0, -(v[2] or 0), -(v[3] or 0), -(v[4] or 0), v[5] or 0, v[6] or 0 }
	end
	return out
end
D.mirror = mirror

local function merge(...)
	local out = {}
	for _, pose in ipairs({ ... }) do
		for joint, v in pairs(pose) do
			out[joint] = v
		end
	end
	return out
end
D.merge = merge

local function mirrorClip(clip)
	local out = {}
	for k, v in pairs(clip) do
		out[k] = v
	end
	for _, list in ipairs({ "pre", "post" }) do
		if clip[list] then
			out[list] = {}
			for i, key in ipairs(clip[list]) do
				out[list][i] = { f = key.f, s = key.s, ease = key.ease, pose = mirror(key.pose) }
			end
		end
	end
	if clip.tremble then
		out.tremble = { from = clip.tremble.from, amp = clip.tremble.amp, joints = {} }
		for i, j in ipairs(clip.tremble.joints) do
			out.tremble.joints[i] = j:gsub("_R$", "_TMP"):gsub("_L$", "_R"):gsub("_TMP$", "_L")
		end
	end
	return out
end

-- ═══════════════════════════ 두 발 몸(biped) 공통 ═══════════════════════════
local B = {}
D.biped = B

-- 대기: 호흡(몸통이 부풀었다 줄어듦 = 허리 · 어깨 · 엉덩이 높이) · 체중 이동(좌우) · 두리번(머리가 먼저 → 몸이 따라옴)
B.idle = {
	breath = { period = 3.4, waist = 2.2, shoulder = 2.5, lift = 0.025 },
	sway = { period = 7.5, roll = 2.2, shift = 0.05 },
	look = { everySeconds = 4.5, yawDeg = 32, bodyFollow = 0.35, neckSpeed = 5, bodySpeed = 1.6 },
}

-- 걷기: 발이 땅에 붙어 미끄러지지 않게 = 걸음 위상을 **이동 거리 ÷ 보폭**으로 진행(shared/BossMotion). 엉덩이 흔들 각 = asin(보폭 ÷ (2 × 다리 길이))로 보폭과 맞춘다.
--   knee = 앞으로 옮기는 발의 무릎 굽힘 · arm = 팔 흔들 · bob = 몸 위아래 · lean = 달릴수록 앞으로 숙임(속도 비) · turnLean = 방향 전환 때 몸을 먼저 기울임(도 / (rad/s))
B.walk = { stride = 0.75, knee = 38, arm = 18, bob = 0.06, lean = 8, twist = 5, turnLean = 7, runAt = 1.6 }

-- A2-M1 여운 · 겹침(12원칙 follow-through · overlapping action): 동작 층을 이 관절 묶음만 delay초 늦게 한 번 더 표본 - 팔꿈치 → 손목 · 목 → 턱 · 꼬리 끝으로 갈수록 늦다.
--   휘두르는 구간(전조 끝 ~ 접촉 + 히트스톱)에서는 지연이 0으로 줄어든다(shared/BossMotion - 때리는 부위가 판정보다 늦게 닿지 않게). delay × 보스 무게(weight).
B.overlap = {
	{ delay = 0.035, joints = { "Elbow_R", "Elbow_L", "Neck", "Tail2", "Tail3" } },
	{ delay = 0.07, joints = { "Wrist_R", "Wrist_L", "Jaw", "Tail4", "Tail5", "Tail6" } },
}

-- 전투 준비 자세(평타 사이 - 이전 타의 회복이 다음 타의 전조)
B.guard = {
	Waist = { -6, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.08, 0 },
	Shoulder_R = { 32, 0, 12 }, Elbow_R = { 62, 0, 0 }, Shoulder_L = { 26, 0, -12 }, Elbow_L = { 58, 0, 0 },
	Hip_L = { 12, 0, -3 }, Hip_R = { 8, 0, 3 }, Knee_L = { -20, 0, 0 }, Knee_R = { -16, 0, 0 }, Ankle_L = { 8, 0, 0 }, Ankle_R = { 8, 0, 0 },
}

-- 평타(작은 모션 = 짧은 전조): 준비 자세 → 빠른 한 방 → 살짝 지나침 → 천천히 준비 자세
local basicR = {
	post = {
		{ s = 0.07, ease = "out", pose = merge(B.guard, { Waist = { -12, -28, 0 }, Shoulder_R = { 100, 0, 8 }, Elbow_R = { 12, 0, 0 }, Neck = { -4, 10, 0 } }) },
		{ s = 0.17, ease = "back", pose = merge(B.guard, { Waist = { -16, -34, 0 }, Shoulder_R = { 88, 0, -12 }, Elbow_R = { 6, 0, 0 }, Neck = { -6, 12, 0 } }) },
		{ s = 0.62, ease = "inout", pose = B.guard },
	},
	hitstop = 0.04,
}
B.clips = {}
B.clips.basic_R = basicR
B.clips.basic_L = mirrorClip(basicR)
-- A2-N3 결정 ②: 평타 예비 동작(서버 BossSwingPrepAt 전 0.25초) - 휘두를 팔을 뒤 위로 들고 몸을 반대로 비튼다(타격 자세 Waist −28 · Shoulder_R 100의 반대쪽)
local prepR = merge(B.guard, { Waist = { 6, 20, 0 }, Shoulder_R = { 150, 0, 24 }, Elbow_R = { 70, 0, 0 }, Neck = { 2, -8, 0 }, RootJoint = { 0, 0, 0, 0, -0.1, 0 } })
B.basicPrep = { R = prepR, L = mirror(prepR) }

-- 강화 평타(스킬 swipe · 큰 휘두름): 팔을 휘두를 듯 떨림 + 무기 번쩍(전조 끝 40%) → 가로 휩쓸기 → 지나침 → 회복
local SWIPE_PRE = {
	{ f = 0.35, ease = "inout", pose = merge(B.guard, { Waist = { 2, -40, 0 }, Shoulder_R = { 40, 0, 75 }, Elbow_R = { 35, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.14, 0 } }) },
	{ f = 1.0, ease = "out", pose = merge(B.guard, { Waist = { 4, -55, 0 }, Shoulder_R = { 30, 0, 95 }, Elbow_R = { 25, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.18, 0 }, Neck = { 0, 20, 0 } }) },
}
-- QUEUE-ALL1 01 C-2(모션 > 판정 - 판정 부채꼴 반경 14 그대로): 접촉 · 지나침에서 팔을 굽혀 몸 쪽으로 휘두른다(옛 = 어깨 90 · 80 · 팔꿈치 8 · 15 - 팔을 쭉 뻗어
--   수호자 15.8 · 심해 17.4 · 폭풍 19.0 stud까지 닿았다 → 14.7 · 15.0 · 16.5(폭풍 = 대기 자세 16.0이 하한) · FK 하네스 앞 100° 안 최대).
B.clips.swipe = {
	pre = SWIPE_PRE,
	post = {
		{ s = 0.09, ease = "out", pose = merge(B.guard, { Waist = { -10, 45, 0 }, Shoulder_R = { 50, 0, 5 }, Elbow_R = { 75, 0, 0 }, Neck = { 0, -15, 0 } }) },
		{ s = 0.22, ease = "back", pose = merge(B.guard, { Waist = { -12, 58, 0 }, Shoulder_R = { 45, 0, -35 }, Elbow_R = { 80, 0, 0 }, Neck = { 0, -18, 0 } }) },
		{ s = 0.85, ease = "inout", pose = B.guard },
	},
	hitstop = 0.07, squash = 0.1,
	tremble = { from = 0.6, amp = 3.5, joints = { "Shoulder_R", "Elbow_R" } },
	flash = "weapon", -- 무기(없으면 오른손)를 번쩍
}
-- 팔을 쭉 뻗는 옛 휘두름 - 수정 여왕만(몸이 작아 굽히면 13.3 → 11.5 = 판정의 0.82로 모자란다 · D.bossClips)
local swipeWide = {
	pre = SWIPE_PRE,
	post = {
		{ s = 0.09, ease = "out", pose = merge(B.guard, { Waist = { -10, 45, 0 }, Shoulder_R = { 90, 0, 5 }, Elbow_R = { 8, 0, 0 }, Neck = { 0, -15, 0 } }) },
		{ s = 0.22, ease = "back", pose = merge(B.guard, { Waist = { -12, 58, 0 }, Shoulder_R = { 80, 0, -35 }, Elbow_R = { 15, 0, 0 }, Neck = { 0, -18, 0 } }) },
		{ s = 0.85, ease = "inout", pose = B.guard },
	},
	hitstop = 0.07, squash = 0.1,
	tremble = { from = 0.6, amp = 3.5, joints = { "Shoulder_R", "Elbow_R" } },
	flash = "weapon",
}

-- 두 손 내려찍기(큰 모션 = 긴 전조 · 큰 피해): 들어 올려 뒤로 젖힘(웅크림) → 내려찍기 → 몸 눌림 + 히트스톱 → 천천히 일어남
local SLAM_UP = { Waist = { 16, 0, 0 }, Neck = { 14, 0, 0 }, Shoulder_R = { 175, 0, 14 }, Shoulder_L = { 175, 0, -14 }, Elbow_R = { 38, 0, 0 }, Elbow_L = { 38, 0, 0 },
	RootJoint = { 0, 0, 0, 0, -0.12, 0 }, Hip_L = { 18, 0, -4 }, Hip_R = { 18, 0, 4 }, Knee_L = { -30, 0, 0 }, Knee_R = { -30, 0, 0 }, Ankle_L = { 12, 0, 0 }, Ankle_R = { 12, 0, 0 } }
local SLAM_HIT = { Waist = { -38, 0, 0 }, Neck = { -10, 0, 0 }, Shoulder_R = { 55, 0, 8 }, Shoulder_L = { 55, 0, -8 }, Elbow_R = { 8, 0, 0 }, Elbow_L = { 8, 0, 0 },
	RootJoint = { 0, 0, 0, 0, -0.42, -0.1 }, Hip_L = { 40, 0, -6 }, Hip_R = { 40, 0, 6 }, Knee_L = { -62, 0, 0 }, Knee_R = { -62, 0, 0 }, Ankle_L = { 22, 0, 0 }, Ankle_R = { 22, 0, 0 } }
B.clips.slam = {
	pre = {
		{ f = 0.3, ease = "inout", pose = merge(SLAM_UP, { Waist = { 8, 0, 0 }, Shoulder_R = { 130, 0, 14 }, Shoulder_L = { 130, 0, -14 } }) },
		{ f = 0.85, ease = "out", pose = SLAM_UP },
		{ f = 1.0, ease = "in", pose = merge(SLAM_UP, { Waist = { 20, 0, 0 }, Shoulder_R = { 188, 0, 12 }, Shoulder_L = { 188, 0, -12 } }) },
	},
	post = {
		{ s = 0.09, ease = "in", pose = SLAM_HIT },
		{ s = 0.3, ease = "out", pose = merge(SLAM_HIT, { Waist = { -44, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.48, -0.12 } }) },
		{ s = 1.1, ease = "inout", pose = B.guard },
	},
	hitstop = 0.1, squash = 0.25,
}
-- QUEUE-ALL1 01 C-2: 원 안 강공격(innerSmash · 판정 원 12)용 내려찍기 - 전조는 slam 그대로 · 발 앞 가까이 찍는다(허리 −38 → −15 · 어깨 55 → 20).
--   수호자 손 14.7 → 14.0(대기 자세 13.3이 하한) · 서리 거인은 곤봉이 대기 자세부터 21.8이라 몸 크기가 하한.
local SMASH_IN = merge(SLAM_HIT, { Waist = { -15, 0, 0 }, Shoulder_R = { 20, 0, 8 }, Shoulder_L = { 20, 0, -8 }, Elbow_R = { 20, 0, 0 }, Elbow_L = { 20, 0, 0 } })
B.clips.smash_in = {
	pre = B.clips.slam.pre,
	post = {
		{ s = 0.09, ease = "in", pose = SMASH_IN },
		{ s = 0.3, ease = "out", pose = merge(SMASH_IN, { Waist = { -21, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.48, -0.12 } }) },
		{ s = 1.1, ease = "inout", pose = B.guard },
	},
	hitstop = 0.1, squash = 0.25,
}

-- 한 손 주먹 내리꽂기(fist)
B.clips.punch = {
	pre = {
		{ f = 0.5, ease = "inout", pose = merge(B.guard, { Waist = { 6, 30, 0 }, Shoulder_R = { -25, 0, 20 }, Elbow_R = { 95, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.12, 0.05 } }) },
		{ f = 1.0, ease = "out", pose = merge(B.guard, { Waist = { 10, 38, 0 }, Shoulder_R = { -35, 0, 22 }, Elbow_R = { 110, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.16, 0.08 } }) },
	},
	post = {
		{ s = 0.08, ease = "out", pose = merge(B.guard, { Waist = { -22, -30, 0 }, Shoulder_R = { 105, 0, 5 }, Elbow_R = { 5, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.25, -0.15 } }) },
		{ s = 0.2, ease = "back", pose = merge(B.guard, { Waist = { -26, -36, 0 }, Shoulder_R = { 95, 0, -5 }, Elbow_R = { 2, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.28, -0.18 } }) },
		{ s = 0.9, ease = "inout", pose = B.guard },
	},
	hitstop = 0.07, squash = 0.12,
}
-- QUEUE-ALL1 01 C-2: 폭풍 군주 원 안 낙뢰(innerSmash · 판정 원 12)용 - 전조는 punch 그대로 · 지팡이를 발 곁 바닥에 내리꽂는다(어깨 105 → 20 · 팔꿈치 5 → 45).
--   지팡이 끝 19.1 → 15.2(대기 자세 16.0보다 안쪽 - 몸 크기가 하한).
B.clips.punch_in = {
	pre = B.clips.punch.pre,
	post = {
		{ s = 0.08, ease = "out", pose = merge(B.guard, { Waist = { -8, -30, 0 }, Shoulder_R = { 20, 0, 5 }, Elbow_R = { 45, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.25, -0.15 } }) },
		{ s = 0.2, ease = "back", pose = merge(B.guard, { Waist = { -12, -36, 0 }, Shoulder_R = { 10, 0, -5 }, Elbow_R = { 45, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.28, -0.18 } }) },
		{ s = 0.9, ease = "inout", pose = B.guard },
	},
	hitstop = 0.07, squash = 0.12,
}

-- 발 구르기(stomp)
B.clips.stomp = {
	pre = {
		{ f = 0.6, ease = "inout", pose = merge(B.guard, { Hip_R = { 75, 0, 5 }, Knee_R = { -95, 0, 0 }, Ankle_R = { 10, 0, 0 }, Waist = { 6, 0, 8 }, Shoulder_R = { 20, 0, 45 }, Shoulder_L = { 20, 0, -45 }, RootJoint = { 0, 0, 0, -0.06, 0.05, 0 } }) },
		{ f = 1.0, ease = "out", pose = merge(B.guard, { Hip_R = { 90, 0, 5 }, Knee_R = { -105, 0, 0 }, Ankle_R = { 15, 0, 0 }, Waist = { 10, 0, 10 }, Shoulder_R = { 25, 0, 55 }, Shoulder_L = { 25, 0, -55 }, RootJoint = { 0, 0, 0, -0.08, 0.1, 0 } }) },
	},
	post = {
		{ s = 0.07, ease = "in", pose = merge(B.guard, { Hip_R = { 5, 0, 5 }, Knee_R = { -10, 0, 0 }, Waist = { -18, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.35, 0 }, Hip_L = { 30, 0, -4 }, Knee_L = { -50, 0, 0 } }) },
		{ s = 0.24, ease = "out", pose = merge(B.guard, { Hip_R = { 8, 0, 5 }, Knee_R = { -18, 0, 0 }, Waist = { -22, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.4, 0 }, Hip_L = { 34, 0, -4 }, Knee_L = { -56, 0, 0 } }) },
		{ s = 1.0, ease = "inout", pose = B.guard },
	},
	hitstop = 0.09, squash = 0.2,
}

-- 하늘로 들기 · 영창(hand · staff · 투사체 · 낙석 등 시전형)
B.clips.cast = {
	pre = {
		{ f = 0.4, ease = "inout", pose = merge(B.guard, { Shoulder_R = { 120, 0, 20 }, Elbow_R = { 30, 0, 0 }, Waist = { 8, 10, 0 }, Neck = { 12, 0, 0 } }) },
		{ f = 1.0, ease = "out", pose = merge(B.guard, { Shoulder_R = { 168, 0, 12 }, Elbow_R = { 10, 0, 0 }, Waist = { 12, 12, 0 }, Neck = { 22, 0, 0 }, RootJoint = { 0, 0, 0, 0, 0.04, 0 } }) },
	},
	post = {
		{ s = 0.1, ease = "out", pose = merge(B.guard, { Shoulder_R = { 95, 0, 10 }, Elbow_R = { 5, 0, 0 }, Waist = { -14, -8, 0 }, Neck = { -4, 0, 0 } }) },
		{ s = 0.24, ease = "back", pose = merge(B.guard, { Shoulder_R = { 80, 0, 5 }, Elbow_R = { 5, 0, 0 }, Waist = { -18, -12, 0 } }) },
		{ s = 0.9, ease = "inout", pose = B.guard },
	},
	hitstop = 0.03,
}

-- 포효(roar · sonic): 가슴을 펴고 고개를 젖힘 · 두 팔 벌림 · 입 벌림 → 떨림 유지
local ROAR = { Waist = { 20, 0, 0 }, Neck = { 32, 0, 0 }, Jaw = { 0, 0, 0, 0, -0.12, 0 }, Shoulder_R = { 30, 0, 70 }, Shoulder_L = { 30, 0, -70 }, Elbow_R = { 35, 0, 0 }, Elbow_L = { 35, 0, 0 },
	RootJoint = { 0, 0, 0, 0, -0.1, 0.05 }, Hip_L = { 10, 0, -8 }, Hip_R = { 10, 0, 8 }, Knee_L = { -18, 0, 0 }, Knee_R = { -18, 0, 0 } }
B.clips.roar = {
	pre = {
		{ f = 0.5, ease = "inout", pose = merge(B.guard, { Waist = { -20, 0, 0 }, Neck = { -18, 0, 0 }, Shoulder_R = { 45, 0, 20 }, Shoulder_L = { 45, 0, -20 }, Elbow_R = { 90, 0, 0 }, Elbow_L = { 90, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.2, 0 } }) },
		{ f = 1.0, ease = "out", pose = merge(B.guard, { Waist = { -26, 0, 0 }, Neck = { -22, 0, 0 }, Shoulder_R = { 50, 0, 15 }, Shoulder_L = { 50, 0, -15 }, Elbow_R = { 105, 0, 0 }, Elbow_L = { 105, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.25, 0 } }) },
	},
	post = {
		{ s = 0.12, ease = "out", pose = ROAR },
		{ s = 0.3, ease = "back", pose = merge(ROAR, { Waist = { 24, 0, 0 }, Neck = { 38, 0, 0 } }) },
	},
	loop = { period = 0.16, poses = { ROAR, merge(ROAR, { Waist = { 22, 0, 2 }, Neck = { 36, 0, -3 } }) } },
	hitstop = 0.05, tremble = { from = 0.7, amp = 2.5, joints = { "Waist", "Neck" } },
}

-- 두 손 앞으로 모아 쏘기(빔 · 파도 · 소용돌이 채널)
local BEAM = { Waist = { -8, 0, 0 }, Shoulder_R = { 88, 0, -18 }, Shoulder_L = { 88, 0, 18 }, Elbow_R = { 5, 0, 0 }, Elbow_L = { 5, 0, 0 }, Wrist_R = { -60, 0, 0 }, Wrist_L = { -60, 0, 0 },
	RootJoint = { 0, 0, 0, 0, -0.12, 0 }, Hip_L = { 25, 0, -5 }, Hip_R = { -5, 0, 5 }, Knee_L = { -30, 0, 0 }, Knee_R = { -8, 0, 0 } }
B.clips.beam = {
	pre = {
		{ f = 0.5, ease = "inout", pose = merge(B.guard, { Waist = { 10, 35, 0 }, Shoulder_R = { 40, 0, 10 }, Shoulder_L = { 60, 0, 30 }, Elbow_R = { 90, 0, 0 }, Elbow_L = { 90, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.18, 0.08 } }) },
		{ f = 1.0, ease = "out", pose = merge(B.guard, { Waist = { 14, 42, 0 }, Shoulder_R = { 35, 0, 5 }, Shoulder_L = { 55, 0, 35 }, Elbow_R = { 100, 0, 0 }, Elbow_L = { 100, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.22, 0.1 } }) },
	},
	post = { { s = 0.1, ease = "out", pose = BEAM } },
	loop = { period = 0.12, poses = { BEAM, merge(BEAM, { Waist = { -9, 0, 1 }, Shoulder_R = { 89, 1, -18 } }) } },
	hitstop = 0.03, tremble = { from = 0.6, amp = 2, joints = { "Shoulder_R", "Shoulder_L" } },
}

-- 회오리(spin): 팔 벌리고 제자리 돌기(루트 관절 ry가 계속 돈다 - BossMotion spin)
B.clips.spin = {
	pre = {
		{ f = 0.6, ease = "inout", pose = merge(B.guard, { Waist = { 6, 50, 0 }, Shoulder_R = { 20, 0, 60 }, Shoulder_L = { 20, 0, -60 }, RootJoint = { 0, 0, 0, 0, -0.2, 0 } }) },
		{ f = 1.0, ease = "out", pose = merge(B.guard, { Waist = { 8, 65, 0 }, Shoulder_R = { 15, 0, 75 }, Shoulder_L = { 15, 0, -75 }, RootJoint = { 0, 0, 0, 0, -0.25, 0 } }) },
	},
	post = { { s = 0.1, ease = "out", pose = { Waist = { -6, 0, 0 }, Shoulder_R = { 10, 0, 88 }, Shoulder_L = { 10, 0, -88 }, Elbow_R = { 5, 0, 0 }, Elbow_L = { 5, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.05, 0 } } } },
	loop = { period = 0.4, poses = { { Waist = { -6, 0, 0 }, Shoulder_R = { 10, 0, 88 }, Shoulder_L = { 10, 0, -88 } }, { Waist = { -4, 0, 3 }, Shoulder_R = { 14, 0, 84 }, Shoulder_L = { 6, 0, -92 } } } },
	spin = 720, -- 도/초(때리는 순간부터)
}

-- 달리기 자세 위에 덮는 윗몸(돌진 · 쫓아가 잡기)
B.clips.charge = {
	pre = {
		-- 발 긁기: 몸을 낮추고 뒤로 젖혔다가(웅크림) 앞으로 숙이며 오른발로 땅을 긁는다
		{ f = 0.2, ease = "inout", pose = merge(B.guard, { Waist = { -25, 0, 0 }, Neck = { 18, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.3, 0.1 }, Hip_R = { -30, 0, 3 }, Knee_R = { -40, 0, 0 } }) },
		{ f = 0.4, ease = "inout", pose = merge(B.guard, { Waist = { -30, 0, 0 }, Neck = { 22, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.32, 0.1 }, Hip_R = { 10, 0, 3 }, Knee_R = { -20, 0, 0 } }) },
		{ f = 0.6, ease = "inout", pose = merge(B.guard, { Waist = { -25, 0, 0 }, Neck = { 18, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.3, 0.1 }, Hip_R = { -30, 0, 3 }, Knee_R = { -40, 0, 0 } }) },
		{ f = 0.8, ease = "inout", pose = merge(B.guard, { Waist = { -30, 0, 0 }, Neck = { 22, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.32, 0.1 }, Hip_R = { 10, 0, 3 }, Knee_R = { -20, 0, 0 } }) },
		-- QUEUE-ALL5 C: "out" → "inout"(앞 키가 속도 0으로 끝나는데 "out"은 최대 속도로 출발 - 전조 1.0초 삼지창 던지기에서 어깨가 한 프레임에 1.85배 튐) · 키 자세 · 시각 그대로
		{ f = 1.0, ease = "inout", pose = merge(B.guard, { Waist = { -34, 0, 0 }, Neck = { 26, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.35, 0.12 }, Shoulder_R = { -20, 0, 15 }, Shoulder_L = { -20, 0, -15 } }) },
	},
	post = { { s = 0.12, ease = "out", pose = { Waist = { -32, 0, 0 }, Neck = { 26, 0, 0 }, Shoulder_R = { -30, 0, 18 }, Shoulder_L = { -30, 0, -18 }, Elbow_R = { 40, 0, 0 }, Elbow_L = { 40, 0, 0 } } } },
	loop = { period = 0.3, poses = { { Waist = { -32, 0, 0 }, Neck = { 26, 0, 0 }, Shoulder_R = { -30, 0, 18 }, Shoulder_L = { -30, 0, -18 } }, { Waist = { -30, 0, 2 }, Neck = { 24, 0, 0 }, Shoulder_R = { -26, 0, 18 }, Shoulder_L = { -34, 0, -18 } } } },
	upper = true, -- 다리는 걸음(달리기)이 그린다
	hitstop = 0.03,
	-- BR1-4c c-7 "뭐든 부순다": 전조 동안 대상을 노려봄(눈이 붉게 빛남 - glare) · 콧김 먼지 · 몸 떨림(끝으로 갈수록 셈)
	tremble = { from = 0.35, amp = 2.4, joints = { "Waist", "Neck", "Shoulder_R", "Shoulder_L" } },
	glare = true,
}

-- 대공 잡기(4b-3 · 09-27 정정 흐름): 전조 = 두 팔을 하늘로(점프하지 마) · 쫓기 = 달리며 두 팔을 앞으로 · 낚아챔 = 팔 휘두름 + 히트스톱 + 표정 · 들기 = 머리 위로 · 발버둥에 흔들림
local GRAB_UP = { Waist = { 10, 0, 0 }, Neck = { 24, 0, 0 }, Shoulder_R = { 160, 0, 32 }, Shoulder_L = { 160, 0, -32 }, Elbow_R = { 22, 0, 0 }, Elbow_L = { 22, 0, 0 },
	RootJoint = { 0, 0, 0, 0, -0.1, 0 }, Hip_L = { 14, 0, -6 }, Hip_R = { 14, 0, 6 }, Knee_L = { -24, 0, 0 }, Knee_R = { -24, 0, 0 } }
B.clips.grab_tele = {
	pre = {
		{ f = 0.15, ease = "out", pose = GRAB_UP },
		{ f = 0.7, ease = "inout", pose = merge(GRAB_UP, { Shoulder_R = { 165, 0, 38 }, Shoulder_L = { 165, 0, -38 } }) },
		{ f = 1.0, ease = "inout", pose = merge(GRAB_UP, { Waist = { 4, 0, 0 }, Neck = { 10, 0, 0 }, Shoulder_R = { 120, 0, 30 }, Shoulder_L = { 120, 0, -30 }, RootJoint = { 0, 0, 0, 0, -0.22, 0 } }) },
	},
	tremble = { from = 0.75, amp = 2.5, joints = { "Shoulder_R", "Shoulder_L" } },
}
local REACH = { Waist = { -22, 0, 0 }, Neck = { 20, 0, 0 }, Shoulder_R = { 95, 0, 25 }, Shoulder_L = { 95, 0, -25 }, Elbow_R = { 12, 0, 0 }, Elbow_L = { 12, 0, 0 } }
B.clips.grab_reach = { -- 쫓는 동안(윗몸만 · 다리는 달리기) - A2-M1: 되풀이 추가(옛 = 되풀이가 없어 0.45초 뒤 층이 꺼져 달리는 내내 팔이 내려가 있다가 낚아챌 때 한 번에 올라갔다)
	post = { { s = 0.15, ease = "out", pose = REACH } },
	loop = { period = 0.32, poses = { REACH, merge(REACH, { Shoulder_R = { 100, 0, 22 }, Shoulder_L = { 90, 0, -28 }, Waist = { -24, 3, 0 } }) } }, -- 달리며 팔이 조금씩 흔들림
	upper = true, blendIn = 0.35,
}
B.clips.grab_snatch = { -- 낚아채는 순간(BossPickAt) - 더하는 층(지금 자세에 더한다 - 작은 값): 팔을 바깥으로 뺐다가 안으로 휘둘러 낚아챔 + 눈 치켜뜸 · 입 벌림
	post = {
		{ s = 0.0, ease = "out", pose = { Waist = { 0, -25, 0 }, Shoulder_R = { -30, 0, 40 }, Elbow_R = { -5, 0, 0 } } },
		{ s = 0.1, ease = "in", pose = { Waist = { -6, 20, 0 }, Shoulder_R = { 15, 0, -15 }, Elbow_R = { 15, 0, 0 }, Eyes = { 0, 0, 0, 0, 0.03, 0 }, Jaw = { 0, 0, 0, 0, -0.1, 0 } } },
		{ s = 0.35, ease = "back", pose = { Waist = { -3, 8, 0 }, Shoulder_R = { 5, 0, 0 }, Jaw = { 0, 0, 0, 0, -0.05, 0 } } },
		{ s = 0.7, ease = "inout", pose = {} },
	},
	hitstop = 0.09, face = true,
}
local HOLD = { Waist = { 4, 0, 0 }, Neck = { 8, 0, 0 }, Shoulder_R = { 112, 0, 22 }, Shoulder_L = { 112, 0, -22 }, Elbow_R = { 18, 0, 0 }, Elbow_L = { 18, 0, 0 }, -- 몸 앞 위로 뻗어 매단다(잡힌 사람이 주먹에 가려지지 않게)
	RootJoint = { 0, 0, 0, 0, -0.06, 0 }, Hip_L = { 10, 0, -6 }, Hip_R = { 10, 0, 6 }, Knee_L = { -16, 0, 0 }, Knee_R = { -16, 0, 0 } }
B.clips.grab_hold = {
	post = { { s = 0.25, ease = "out", pose = HOLD } },
	loop = { period = 0.5, poses = { HOLD, merge(HOLD, { Waist = { 5, 4, 2 }, Shoulder_R = { 109, 0, 24 }, Shoulder_L = { 115, 0, -20 } }) } }, -- 발버둥에 흔들림
}
B.holdPose = HOLD

-- 던지기(보스마다 다른 던지기 - 아래 보스 표가 고른다). 전조 = BossThrowPlan 앞 throwWindup초.
B.clips.throw_overhead = { -- 수호자: 두 손 머리 뒤로 → 앞으로 내던짐
	pre = {
		{ f = 0.6, ease = "inout", pose = merge(HOLD, { Waist = { 22, 0, 0 }, Neck = { 20, 0, 0 }, Shoulder_R = { 195, 0, 20 }, Shoulder_L = { 195, 0, -20 }, Elbow_R = { 50, 0, 0 }, Elbow_L = { 50, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.2, 0.1 } }) },
		{ f = 1.0, ease = "out", pose = merge(HOLD, { Waist = { 26, 0, 0 }, Neck = { 22, 0, 0 }, Shoulder_R = { 205, 0, 18 }, Shoulder_L = { 205, 0, -18 }, Elbow_R = { 55, 0, 0 }, Elbow_L = { 55, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.25, 0.12 } }) },
	},
	post = {
		{ s = 0.1, ease = "out", pose = { Waist = { -34, 0, 0 }, Neck = { -6, 0, 0 }, Shoulder_R = { 75, 0, 10 }, Shoulder_L = { 75, 0, -10 }, Elbow_R = { 5, 0, 0 }, Elbow_L = { 5, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.3, -0.15 }, Hip_L = { 30, 0, 0 }, Knee_L = { -45, 0, 0 } } },
		{ s = 0.3, ease = "back", pose = { Waist = { -40, 0, 0 }, Shoulder_R = { 60, 0, 5 }, Shoulder_L = { 60, 0, -5 }, RootJoint = { 0, 0, 0, 0, -0.34, -0.18 }, Hip_L = { 34, 0, 0 }, Knee_L = { -50, 0, 0 } } },
		{ s = 1.1, ease = "inout", pose = B.guard },
	},
	hitstop = 0.08, squash = 0.12,
}
B.clips.throw_spin = { -- 서리 거인: 한 바퀴 돌며 옆으로 내던짐(해머 던지기)
	pre = {
		{ f = 0.5, ease = "sine", pose = merge(HOLD, { Waist = { 6, 60, 0 }, Shoulder_R = { 60, 0, 85 }, Shoulder_L = { 60, 0, -85 }, RootJoint = { 0, 0, 0, 0, -0.2, 0 } }) },
		{ f = 1.0, ease = "in", pose = merge(HOLD, { Waist = { 8, 80, 0 }, Shoulder_R = { 40, 0, 95 }, Shoulder_L = { 40, 0, -95 }, RootJoint = { 0, 0, 0, 0, -0.25, 0 } }) },
	},
	post = {
		{ s = 0.12, ease = "out", pose = { Waist = { -10, -60, 0 }, Shoulder_R = { 95, 0, -20 }, Shoulder_L = { 40, 0, -80 }, Elbow_R = { 5, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.2, -0.1 } } },
		{ s = 0.34, ease = "back", pose = { Waist = { -12, -72, 0 }, Shoulder_R = { 85, 0, -35 }, Shoulder_L = { 30, 0, -70 }, RootJoint = { 0, 0, 0, 0, -0.22, -0.12 } } },
		{ s = 1.2, ease = "inout", pose = B.guard },
	},
	spinPre = 360, -- 전조 동안 몸이 한 바퀴(루트 ry)
	hitstop = 0.08, squash = 0.1,
}
B.clips.throw_tail = { -- 심해 군주: 몸을 비틀어 꼬리로 후려 날림
	pre = {
		{ f = 1.0, ease = "inout", pose = merge(HOLD, { Waist = { 4, -60, 0 }, RootJoint = { 0, -40, 0, 0, -0.2, 0 }, Tail1 = { 0, 60, 0 }, Tail2 = { 0, 20, 0 }, Tail3 = { 0, 15, 0 } }) },
	},
	post = {
		{ s = 0.12, ease = "out", pose = { Waist = { -8, 55, 0 }, RootJoint = { 0, 60, 0, 0, -0.2, 0 }, Shoulder_R = { 100, 0, 40 }, Shoulder_L = { 100, 0, -40 }, Tail1 = { 0, -75, 0 }, Tail2 = { 0, -25, 0 }, Tail3 = { 0, -20, 0 } } },
		{ s = 0.35, ease = "back", pose = { Waist = { -8, 65, 0 }, RootJoint = { 0, 70, 0, 0, -0.2, 0 }, Tail1 = { 0, -85, 0 }, Tail2 = { 0, -30, 0 }, Tail3 = { 0, -25, 0 } } },
		{ s = 1.2, ease = "inout", pose = B.guard },
	},
	hitstop = 0.08,
}
B.clips.throw_push = { -- 수정 여왕: 두 손바닥을 앞으로 - 보이지 않는 힘으로 밀어 날림
	pre = {
		{ f = 1.0, ease = "inout", pose = merge(HOLD, { Waist = { 14, 0, 0 }, Shoulder_R = { 60, 0, 10 }, Shoulder_L = { 60, 0, -10 }, Elbow_R = { 110, 0, 0 }, Elbow_L = { 110, 0, 0 }, Wrist_R = { -40, 0, 0 }, Wrist_L = { -40, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.12, 0.1 } }) },
	},
	post = {
		{ s = 0.08, ease = "out", pose = { Waist = { -16, 0, 0 }, Shoulder_R = { 92, 0, -12 }, Shoulder_L = { 92, 0, 12 }, Elbow_R = { 0, 0, 0 }, Elbow_L = { 0, 0, 0 }, Wrist_R = { -80, 0, 0 }, Wrist_L = { -80, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.1, -0.12 } } },
		{ s = 0.3, ease = "back", pose = { Waist = { -20, 0, 0 }, Shoulder_R = { 95, 0, -15 }, Shoulder_L = { 95, 0, 15 }, Wrist_R = { -85, 0, 0 }, Wrist_L = { -85, 0, 0 } } },
		{ s = 1.1, ease = "inout", pose = B.guard },
	},
	hitstop = 0.06,
}
B.clips.throw_staff = { -- 폭풍 군주: 지팡이를 아래에서 위로 올려 쳐 바람으로 날림
	pre = {
		{ f = 1.0, ease = "inout", pose = merge(HOLD, { Waist = { -14, 30, 0 }, Shoulder_R = { -30, 0, 20 }, Elbow_R = { 20, 0, 0 }, Shoulder_L = { 40, 0, -30 }, RootJoint = { 0, 0, 0, 0, -0.3, 0 } }) },
	},
	post = {
		{ s = 0.1, ease = "out", pose = { Waist = { 16, -20, 0 }, Neck = { 20, 0, 0 }, Shoulder_R = { 175, 0, 10 }, Elbow_R = { 5, 0, 0 }, Shoulder_L = { 60, 0, -40 }, RootJoint = { 0, 0, 0, 0, 0.08, 0 } } },
		{ s = 0.32, ease = "back", pose = { Waist = { 20, -24, 0 }, Neck = { 24, 0, 0 }, Shoulder_R = { 185, 0, 5 }, Shoulder_L = { 55, 0, -45 } } },
		{ s = 1.1, ease = "inout", pose = B.guard },
	},
	hitstop = 0.06,
}
B.throwWindup = 0.7 -- 던지기 전조 초(BossThrowPlan 앞)

-- BR1-4c c-9 · c-10 지진파: 파동마다 뛰어올라(서버가 몸을 든다) 내려찍기 - 웅크림(전조) → 공중 웅크림 → 착지 내려찍기(몸 눌림) → 회복. hit = 착지(서버 hop 끝 = 파동 시작).
local HOP_AIR = { Waist = { 10, 0, 0 }, Shoulder_R = { 150, 0, 25 }, Shoulder_L = { 150, 0, -25 }, Elbow_R = { 30, 0, 0 }, Elbow_L = { 30, 0, 0 },
	Hip_L = { 45, 0, -6 }, Hip_R = { 45, 0, 6 }, Knee_L = { -70, 0, 0 }, Knee_R = { -70, 0, 0 }, Ankle_L = { 20, 0, 0 }, Ankle_R = { 20, 0, 0 } }
local HOP_LAND = { Waist = { -28, 0, 0 }, Shoulder_R = { 60, 0, 12 }, Shoulder_L = { 60, 0, -12 }, Elbow_R = { 8, 0, 0 }, Elbow_L = { 8, 0, 0 },
	RootJoint = { 0, 0, 0, 0, -0.38, 0 }, Hip_L = { 40, 0, -8 }, Hip_R = { 40, 0, 8 }, Knee_L = { -65, 0, 0 }, Knee_R = { -65, 0, 0 }, Ankle_L = { 25, 0, 0 }, Ankle_R = { 25, 0, 0 } }
B.clips.hopSlam = {
	pre = {
		{ f = 0.12, ease = "out", pose = merge(B.guard, { RootJoint = { 0, 0, 0, 0, -0.3, 0 }, Hip_L = { 35, 0, -5 }, Hip_R = { 35, 0, 5 }, Knee_L = { -60, 0, 0 }, Knee_R = { -60, 0, 0 }, Waist = { -12, 0, 0 } }) },
		{ f = 0.45, ease = "out", pose = HOP_AIR },
		{ f = 1.0, ease = "in", pose = merge(HOP_AIR, { Waist = { 16, 0, 0 }, Shoulder_R = { 175, 0, 15 }, Shoulder_L = { 175, 0, -15 } }) },
	},
	post = {
		{ s = 0.06, ease = "out", pose = HOP_LAND },
		{ s = 0.5, ease = "inout", pose = B.guard },
	},
	hitstop = 0.06, squash = 0.2,
	airborne = { from = 0.2, to = 1.0 }, -- 뛰어오른 동안은 발 접지 보정을 끈다(발이 떠 있는 게 맞다)
}
-- 마무리 강타(피해 없는 연출): 크게 들었다가 거칠게 내려찍고 몸을 부르르
B.clips.quake_finish = {
	pre = {
		{ f = 1.0, ease = "out", pose = merge(SLAM_UP, { Waist = { 22, 0, 0 }, Shoulder_R = { 190, 0, 14 }, Shoulder_L = { 190, 0, -14 } }) },
	},
	post = {
		{ s = 0.07, ease = "in", pose = merge(SLAM_HIT, { Waist = { -45, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.5, -0.12 } }) },
		{ s = 0.3, ease = "back", pose = merge(SLAM_HIT, { Waist = { -40, 0, 4 } }) },
	},
	hitstop = 0.1, squash = 0.3, finishHit = 0.35, -- 전조 = 0.35초(서버 finishSeconds 안)
}
-- 숨 고르기(휴식 틈): 무릎에 손 짚고 헐떡임 - 가까이 와 때릴 틈
local REST = { Waist = { -30, 0, 0 }, Neck = { 18, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.25, 0.05 }, Shoulder_R = { 45, 0, 12 }, Shoulder_L = { 45, 0, -12 }, Elbow_R = { 35, 0, 0 }, Elbow_L = { 35, 0, 0 },
	Hip_L = { 30, 0, -6 }, Hip_R = { 30, 0, 6 }, Knee_L = { -40, 0, 0 }, Knee_R = { -40, 0, 0 }, Ankle_L = { 12, 0, 0 }, Ankle_R = { 12, 0, 0 }, Jaw = { 0, 0, 0, 0, -0.06, 0 } }
B.clips.rest = {
	post = { { s = 0.35, ease = "inout", pose = REST } },
	loop = { period = 0.9, poses = { REST, merge(REST, { Waist = { -26, 0, 0 }, Neck = { 22, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.2, 0.05 }, Shoulder_R = { 42, 0, 14 }, Shoulder_L = { 42, 0, -14 } }) } },
}
B.phaseClips = { finish = "quake_finish", rest = "rest" }

-- A2-M1 등장 웅크림(땅 · 물 · 모래에서 솟을 때 - 한쪽 무릎 · 주먹으로 땅 짚음 · 고개 숙임 → 일어서며 포효)
B.introCrouch = { RootJoint = { 8, 0, 0, 0, -0.9, 0 }, Waist = { -34, 0, 0 }, Neck = { -24, 0, 0 },
	Hip_L = { 70, 0, -6 }, Knee_L = { -95, 0, 0 }, Ankle_L = { 25, 0, 0 }, Hip_R = { 20, 0, 6 }, Knee_R = { -110, 0, 0 }, Ankle_R = { -10, 0, 0 },
	Shoulder_R = { 20, 0, 14 }, Elbow_R = { 30, 0, 0 }, Shoulder_L = { 45, 0, -10 }, Elbow_L = { 20, 0, 0 } }
B.introRoar = "roar"

-- 피격(작게 움찔 - 더하는 층)
B.flinch = { seconds = 0.26, pose = { Waist = { 7, 0, 3 }, Neck = { 10, 0, 0 }, RootJoint = { 0, 0, 0, 0, 0, 0.05 } } }

-- 기절(비틀거림 → 주저앉음 → 일어남): stagger = 앞 0.55초 · rise = 끝 0.8초 · 그 사이 주저앉아 머리 빙빙
B.stun = {
	stagger = { Waist = { -12, 0, 10 }, Neck = { -18, 0, 12 }, Shoulder_R = { 20, 0, 30 }, Shoulder_L = { 10, 0, -20 }, Elbow_R = { 20, 0, 0 }, Elbow_L = { 25, 0, 0 },
		RootJoint = { 0, 0, 12, 0.05, -0.2, 0 }, Hip_L = { 25, 0, -8 }, Knee_L = { -45, 0, 0 }, Hip_R = { -8, 0, 6 }, Knee_R = { -10, 0, 0 } },
	sit = { RootJoint = { -8, 0, 0, 0, -1.55, -0.2 }, Waist = { -18, 0, 0 }, Neck = { -22, 0, 0 }, Shoulder_R = { 15, 0, 28 }, Shoulder_L = { 15, 0, -28 }, Elbow_R = { 25, 0, 0 }, Elbow_L = { 25, 0, 0 },
		Hip_L = { 82, 0, -14 }, Hip_R = { 82, 0, 14 }, Knee_L = { -12, 0, 0 }, Knee_R = { -18, 0, 0 }, Ankle_L = { -20, 0, 0 }, Ankle_R = { -20, 0, 0 } },
	staggerSeconds = 0.55, riseSeconds = 0.8, wobble = { hz = 0.9, neck = 12, waist = 5 },
	eyes = { 0, 0, 90 }, -- 눈 = 빙글(세로 막대)
}

-- 사망(BR1-4c c-5 처치 연출 - 잔인한 표현 없음): 비틀거리다 → 털썩 주저앉음 → 머리 위 별이 빙빙(헤롱 · 눈 빙글) → 사라짐.
-- 처음 slowSeconds는 화면만 느리게(slowRate - 서버 판정 · 보상 · 기록은 막타 시각 그대로). 클라가 서버 모델을 복제해 그린다(서버 모델은 곧 지워진다).
B.death = {
	keys = {
		{ s = 0.3, ease = "out", pose = merge(B.stun.stagger, { Waist = { -16, 0, 14 }, Neck = { -22, 0, 16 } }) },
		{ s = 0.75, ease = "inout", pose = merge(B.stun.stagger, { Waist = { -8, 0, -12 }, Neck = { -15, 0, -14 }, RootJoint = { 0, 0, -10, -0.05, -0.3, 0 } }) },
		{ s = 1.25, ease = "in", pose = B.stun.sit },
		{ s = 1.45, ease = "out", pose = merge(B.stun.sit, { RootJoint = { -12, 0, 0, 0, -1.65, -0.2 }, Waist = { -22, 0, 0 } }) },
	},
	-- A2-M1: 사망 연출 ≤ 3초(사용자 지시) - 슬로모션 0.8초(× 0.4) → 털썩(실시간 약 1.7초) → 별 · X X 눈 → 빛으로 흩어짐(scatterFrom) → 사라짐(fadeFrom + fadeSeconds = 실시간 약 3.0초).
	--   옛 = 슬로모션 1.2초 · 사라짐 3.2 + 0.8(실시간 약 3.9초).
	hitstopAt = 1.25, fadeFrom = 2.0, fadeSeconds = 0.5, scatterFrom = 1.75, eyes = { 0, 0, 90 }, stars = true, slowSeconds = 0.8, slowRate = 0.4,
}
-- ═══════════════════════════ 전갈(scorpion) ═══════════════════════════
local S = {}
D.scorpion = S

local function legs(f)
	local out = {}
	for k = 1, 3 do
		for _, side in ipairs({ "L", "R" }) do
			local x = side == "R" and 1 or -1
			local hip, knee = f(k, x)
			out[("Hip%d_%s"):format(k, side)] = hip
			out[("Knee%d_%s"):format(k, side)] = knee
		end
	end
	return out
end
local function tails(f)
	local out = {}
	for t = 1, 3 do
		for i = 1, 8 do
			local v = f(t, i)
			if v then
				out[("Tail%d_%d"):format(t, i)] = v
			end
		end
	end
	return out
end
S.legs, S.tails = legs, tails

S.idle = {
	breath = { period = 2.8, lift = 0.03, claw = 6 },
	tail = { period = 2.6, yaw = 7, curl = 4, travel = 0.55 }, -- 꼬리마다 위상이 달라 따로 흔들린다(BossRigSpec chains.phase)
	look = { everySeconds = 3.5, yawDeg = 25, bodyFollow = 0.2, neckSpeed = 6, bodySpeed = 2 },
}
-- 세 다리씩 번갈아 딛기(1L · 2R · 3L ↔ 1R · 2L · 3R) - 위상 = 이동 거리 ÷ 보폭
S.walk = { stride = 0.55, swing = 22, lift = 18, bob = 0.04, runAt = 1.6, turnLean = 4, groupA = { "1_L", "2_R", "3_L" } }

S.overlap = {
	{ delay = 0.035, joints = { "Elbow_R", "Elbow_L", "Neck", "Tail1_3", "Tail2_3", "Tail3_3", "Tail1_4", "Tail2_4", "Tail3_4" } },
	{ delay = 0.07, joints = { "Pincer_R", "Pincer_L", "Jaw", "Tail1_6", "Tail2_6", "Tail3_6", "Tail1_7", "Tail2_7", "Tail3_7", "Tail1_8", "Tail2_8", "Tail3_8" } },
}

S.guard = merge(
	{ RootJoint = { 0, 0, 0, 0, -0.05, 0 }, Shoulder_R = { 10, 0, 0 }, Shoulder_L = { 10, 0, 0 }, Pincer_R = { 0, 0, 25 }, Pincer_L = { 0, 0, -25 } },
	tails(function(_, i)
		return i <= 2 and { -8, 0, 0 } or nil
	end)
)
S.clips = {}
local snapR = {
	post = {
		{ s = 0.06, ease = "out", pose = merge(S.guard, { Shoulder_R = { -30, 12, 0 }, Elbow_R = { -25, 0, 0 }, Pincer_R = { 0, 0, 0 }, RootJoint = { 0, 8, 0, 0, -0.08, -0.08 } }) },
		{ s = 0.16, ease = "back", pose = merge(S.guard, { Shoulder_R = { -36, 16, 0 }, Elbow_R = { -30, 0, 0 }, Pincer_R = { 0, 0, -6 }, RootJoint = { 0, 10, 0, 0, -0.1, -0.1 } }) },
		{ s = 0.5, ease = "inout", pose = S.guard },
	},
	hitstop = 0.03,
}
S.clips.basic_R = snapR
S.clips.basic_L = mirrorClip(snapR)
-- A2-N3 결정 ②: 집게 평타 예비 동작 - 집게를 옆으로 벌려 뒤로 당김
local prepS = merge(S.guard, { Shoulder_R = { 22, -24, 0 }, Elbow_R = { 18, 0, 0 }, Pincer_R = { 0, 0, 42 }, RootJoint = { 0, -8, 0, 0, -0.06, 0 } })
S.basicPrep = { R = prepS, L = mirror(prepS) }

-- 강화 평타(집게 찰싹): 집게를 옆으로 크게 벌려 떨다가 가로로 후려침
S.clips.swipe = {
	pre = {
		{ f = 0.4, ease = "inout", pose = merge(S.guard, { Shoulder_R = { 20, -45, 0 }, Elbow_R = { 20, 0, 0 }, Pincer_R = { 0, 0, 40 }, RootJoint = { 0, -15, 0, 0, -0.1, 0 } }) },
		{ f = 1.0, ease = "out", pose = merge(S.guard, { Shoulder_R = { 25, -60, 0 }, Elbow_R = { 25, 0, 0 }, Pincer_R = { 0, 0, 45 }, RootJoint = { 0, -22, 0, 0, -0.14, 0 } }) },
	},
	post = {
		{ s = 0.08, ease = "out", pose = merge(S.guard, { Shoulder_R = { -20, 45, 0 }, Elbow_R = { -15, 0, 0 }, Pincer_R = { 0, 0, 0 }, RootJoint = { 0, 22, 0, 0, -0.12, 0 } }) },
		{ s = 0.22, ease = "back", pose = merge(S.guard, { Shoulder_R = { -24, 58, 0 }, Elbow_R = { -18, 0, 0 }, RootJoint = { 0, 28, 0, 0, -0.12, 0 } }) },
		{ s = 0.8, ease = "inout", pose = S.guard },
	},
	hitstop = 0.06, squash = 0.06,
	tremble = { from = 0.6, amp = 4, joints = { "Shoulder_R", "Pincer_R" } },
	flash = "Pincer_R",
}
-- 꼬리 찌르기(sting · stingJab): 세 꼬리를 뒤로 당겼다가 앞으로 내리꽂음
local function tailPose(base, step, yaw)
	return tails(function(t, i)
		return { (i == 1 and base or step), (i == 1 and (yaw or 0) * (t - 2) or 0), 0 }
	end)
end
S.clips.sting = {
	pre = {
		{ f = 0.5, ease = "inout", pose = merge(S.guard, tailPose(22, 6), { RootJoint = { 6, 0, 0, 0, -0.08, 0.1 } }) },
		{ f = 1.0, ease = "out", pose = merge(S.guard, tailPose(30, 8), { RootJoint = { 8, 0, 0, 0, -0.1, 0.12 } }) },
	},
	post = {
		{ s = 0.08, ease = "out", pose = merge(S.guard, tailPose(-28, -9), { RootJoint = { -10, 0, 0, 0, -0.18, -0.15 } }) },
		{ s = 0.24, ease = "back", pose = merge(S.guard, tailPose(-34, -11), { RootJoint = { -12, 0, 0, 0, -0.2, -0.18 } }) },
		{ s = 0.8, ease = "inout", pose = S.guard },
	},
	hitstop = 0.06, squash = 0.1,
}
-- 땅 파기(잠행 · 개미지옥 · 잠행 찌르기 시작): 몸을 낮추고 다리를 벌려 모래를 판다
local DIG = merge(legs(function(_, x)
	return { 0, 0, x * 18 }, { 0, 0, -x * 10 }
end), { RootJoint = { -6, 0, 0, 0, -0.55, 0 }, Shoulder_R = { -30, 20, 0 }, Shoulder_L = { -30, -20, 0 } })
S.clips.dig = {
	pre = {
		{ f = 0.25, ease = "inout", pose = merge(DIG, { RootJoint = { -6, 0, 4, 0, -0.45, 0 } }) },
		{ f = 0.5, ease = "inout", pose = merge(DIG, { RootJoint = { -6, 0, -4, 0, -0.5, 0 } }) },
		{ f = 0.75, ease = "inout", pose = merge(DIG, { RootJoint = { -6, 0, 4, 0, -0.55, 0 } }) },
		{ f = 1.0, ease = "inout", pose = DIG },
	},
	post = { { s = 0.1, ease = "out", pose = DIG } },
	loop = { period = 0.3, poses = { merge(DIG, { RootJoint = { -6, 0, 3, 0, -0.55, 0 } }), merge(DIG, { RootJoint = { -6, 0, -3, 0, -0.55, 0 } }) } },
	airborne = { from = 0, to = 1000 }, buried = true, -- 모래를 파는 동안 다리 끝은 모래 속(의도) - 발 접지 보정을 끈다
}
-- 두 집게 휩쓸기(clawSweep): 두 집게를 활짝 벌렸다가 안으로 끌어모음
S.clips.clawSweep = {
	pre = {
		{ f = 0.5, ease = "inout", pose = merge(S.guard, { Shoulder_R = { 15, -55, 0 }, Shoulder_L = { 15, 55, 0 }, Pincer_R = { 0, 0, 45 }, Pincer_L = { 0, 0, -45 }, RootJoint = { 4, 0, 0, 0, -0.1, 0.05 } }) },
		{ f = 1.0, ease = "out", pose = merge(S.guard, { Shoulder_R = { 20, -70, 0 }, Shoulder_L = { 20, 70, 0 }, Pincer_R = { 0, 0, 50 }, Pincer_L = { 0, 0, -50 }, RootJoint = { 6, 0, 0, 0, -0.14, 0.08 } }) },
	},
	post = {
		{ s = 0.09, ease = "out", pose = merge(S.guard, { Shoulder_R = { -15, 30, 0 }, Shoulder_L = { -15, -30, 0 }, Pincer_R = { 0, 0, 0 }, Pincer_L = { 0, 0, 0 }, RootJoint = { -6, 0, 0, 0, -0.16, -0.1 } }) },
		{ s = 0.25, ease = "back", pose = merge(S.guard, { Shoulder_R = { -20, 38, 0 }, Shoulder_L = { -20, -38, 0 }, RootJoint = { -8, 0, 0, 0, -0.18, -0.12 } }) },
		{ s = 0.9, ease = "inout", pose = S.guard },
	},
	hitstop = 0.07, squash = 0.1, tremble = { from = 0.7, amp = 3, joints = { "Shoulder_R", "Shoulder_L" } },
}
-- 아르마딜로 태세(curl): 몸을 말고 꼬리로 덮는다
local CURL = merge(legs(function(_, x)
	return { 0, 0, -x * 25 }, { 0, 0, x * 20 }
end), tails(function(_, i)
	return { i == 1 and -20 or -12, 0, 0 }
end), { RootJoint = { -12, 0, 0, 0, -0.4, 0 }, Shoulder_R = { -40, 30, 0 }, Shoulder_L = { -40, -30, 0 }, Neck = { -20, 0, 0 } })
S.clips.curl = {
	pre = { { f = 1.0, ease = "inout", pose = CURL } },
	post = { { s = 0.1, ease = "out", pose = CURL } },
	loop = { period = 0.8, poses = { CURL, merge(CURL, { RootJoint = { -13, 0, 1, 0, -0.42, 0 } }) } },
	airborne = { from = 0, to = 1000 }, buried = true, -- 몸을 말아 웅크린 동안(다리가 몸 밑으로 모래에 묻힘 - 의도)
}
-- 대공 잡기: 전조 = 집게 · 꼬리를 하늘로 / 들기 = 꼬리 끝 · 가운데 · 밑에 한 명씩(4b-5) / 던지기 = 꼬리 투석(뒤로 감았다가 앞으로 채찍)
local S_UP = merge(S.guard, tails(function(_, i)
	return { i == 1 and 12 or 5, 0, 0 }
end), { Shoulder_R = { -50, -20, 0 }, Shoulder_L = { -50, 20, 0 }, Pincer_R = { 0, 0, 45 }, Pincer_L = { 0, 0, -45 }, RootJoint = { 8, 0, 0, 0, 0.1, 0.05 }, Neck = { 15, 0, 0 } })
S.clips.grab_tele = { pre = { { f = 0.2, ease = "out", pose = S_UP }, { f = 1.0, ease = "inout", pose = merge(S_UP, { RootJoint = { 4, 0, 0, 0, -0.1, 0 } }) } }, tremble = { from = 0.75, amp = 3, joints = { "Shoulder_R", "Shoulder_L" } } }
local S_REACH = { Shoulder_R = { -10, -10, 0 }, Shoulder_L = { -10, 10, 0 }, Pincer_R = { 0, 0, 45 }, Pincer_L = { 0, 0, -45 } }
S.clips.grab_reach = { post = { { s = 0.15, ease = "out", pose = S_REACH } }, loop = { period = 0.3, poses = { S_REACH, merge(S_REACH, { Pincer_R = { 0, 0, 38 }, Pincer_L = { 0, 0, -38 } }) } }, upper = true } -- A2-M1: 되풀이 추가(쫓는 내내 집게 벌림)
S.clips.grab_snatch = {
	post = {
		{ s = 0.0, ease = "out", pose = merge(tails(function(_, i)
			return { i == 1 and 20 or 6, 0, 0 }
		end), { Pincer_R = { 0, 0, 45 } }) },
		{ s = 0.1, ease = "in", pose = merge(tails(function(_, i)
			return { i == 1 and -15 or -6, 0, 0 }
		end), { Pincer_R = { 0, 0, 0 }, Jaw = { 0, 0, 0, 0, -0.08, 0 } }) },
		{ s = 0.6, ease = "inout", pose = {} },
	},
	hitstop = 0.09, face = true,
}
local S_HOLD = merge(S.guard, tails(function(t, i)
	return { i == 1 and 6 or 2, i == 1 and (t - 2) * 18 or 0, 0 }
end), { RootJoint = { 4, 0, 0, 0, 0, 0 } })
S.clips.grab_hold = { post = { { s = 0.25, ease = "out", pose = S_HOLD } }, loop = { period = 0.45, poses = { S_HOLD, merge(S_HOLD, { RootJoint = { 5, 3, 2, 0, 0, 0 } }) } } }
S.holdPose = S_HOLD
S.clips.throw_tail = {
	pre = { { f = 1.0, ease = "inout", pose = merge(S_HOLD, tails(function(t, i)
		return { i == 1 and 26 or 7, (t - 2) * 10, 0 }
	end), { RootJoint = { 10, 0, 0, 0, -0.15, 0.12 } }) } },
	post = {
		{ s = 0.09, ease = "out", pose = merge(S.guard, tails(function(_, i)
			return { i == 1 and -30 or -10, 0, 0 }
		end), { RootJoint = { -12, 0, 0, 0, -0.2, -0.15 } }) },
		{ s = 0.3, ease = "back", pose = merge(S.guard, tails(function(_, i)
			return { i == 1 and -36 or -12, 0, 0 }
		end), { RootJoint = { -14, 0, 0, 0, -0.22, -0.18 } }) },
		{ s = 1.0, ease = "inout", pose = S.guard },
	},
	hitstop = 0.08, squash = 0.1,
}
S.throwWindup = 0.6
-- A2-M1 등장: 모래 속에서 튀어나옴 - 웅크림(다리 오므림 · 꼬리 말림) → 집게 · 꼬리를 치켜들고 쉭(hiss)
S.introCrouch = merge(legs(function(_, x)
	return { 0, 0, -x * 20 }, { 0, 0, x * 18 }
end), tails(function(_, i)
	return { i == 1 and -18 or -10, 0, 0 }
end), { RootJoint = { -10, 0, 0, 0, -0.35, 0 }, Shoulder_R = { -35, 25, 0 }, Shoulder_L = { -35, -25, 0 } })
local HISS = merge(S.guard, tails(function(_, i)
	return { i == 1 and 16 or 7, 0, 0 }
end), { Shoulder_R = { -55, -30, 0 }, Shoulder_L = { -55, 30, 0 }, Pincer_R = { 0, 0, 50 }, Pincer_L = { 0, 0, -50 }, RootJoint = { 10, 0, 0, 0, 0.12, 0.06 }, Neck = { 18, 0, 0 }, Jaw = { 0, 0, 0, 0, -0.08, 0 } })
S.clips.hiss = {
	pre = { { f = 1.0, ease = "inout", pose = merge(S.guard, { RootJoint = { -4, 0, 0, 0, -0.1, 0 }, Shoulder_R = { -20, 10, 0 }, Shoulder_L = { -20, -10, 0 } }) } },
	post = { { s = 0.12, ease = "out", pose = HISS }, { s = 0.3, ease = "back", pose = merge(HISS, { Pincer_R = { 0, 0, 56 }, Pincer_L = { 0, 0, -56 } }) } },
	loop = { period = 0.14, poses = { HISS, merge(HISS, { RootJoint = { 10, 0, 1, 0, 0.12, 0.06 } }) } },
	hitstop = 0.05, tremble = { from = 0.6, amp = 3, joints = { "Shoulder_R", "Shoulder_L" } },
}
S.introRoar = "hiss"
S.flinch = { seconds = 0.24, pose = { RootJoint = { 6, 0, 3, 0, 0.05, 0.06 }, Neck = { 10, 0, 0 } } }
S.stun = {
	stagger = merge(legs(function(k, x)
		return { 0, (k - 2) * 8, x * 10 }, { 0, 0, -x * 6 }
	end), { RootJoint = { 0, 0, 14, 0, -0.2, 0 }, Neck = { -10, 0, 10 } }),
	sit = merge(legs(function(_, x)
		return { 0, 0, x * 35 }, { 0, 0, -x * 25 }
	end), tails(function(_, i)
		return { i == 1 and 40 or 12, 0, 0 }
	end), { RootJoint = { 0, 0, 0, 0, -0.75, 0 }, Neck = { -18, 0, 0 }, Shoulder_R = { -45, 30, 0 }, Shoulder_L = { -45, -30, 0 } }),
	staggerSeconds = 0.5, riseSeconds = 0.7, wobble = { hz = 1.1, neck = 10, waist = 0 }, eyes = { 0, 0, 90 },
}
S.death = { -- 비틀 → 다리 풀려 털썩 → 별 빙빙
	keys = {
		{ s = 0.3, ease = "out", pose = S.stun.stagger },
		{ s = 1.25, ease = "in", pose = S.stun.sit },
		{ s = 1.45, ease = "out", pose = merge(S.stun.sit, { RootJoint = { 0, 0, 0, 0, -0.85, 0 } }) },
	},
	hitstopAt = 1.25, fadeFrom = 2.0, fadeSeconds = 0.5, scatterFrom = 1.75, eyes = { 0, 0, 90 }, stars = true, slowSeconds = 0.8, slowRate = 0.4, -- A2-M1 ≤ 3초(위 두 발 몸과 같다)
}

-- ═══════════════════════════ 보스별(스킬 id → 동작 · 걷기 · 던지기 · 무게) ═══════════════════════════
-- skill 값 = 동작 이름(그 보스 plan의 clips) 또는 { clip, upper }. 없는 스킬은 primitive · motion 기본표(defaults)로.
D.bosses = {
	section_guardian = {
		walk = { stride = 0.7, knee = 36, arm = 16, bob = 0.07 },
		skills = { heavy = "slam", shockwave = "stomp", meteor = "cast", charge = "charge", cross = "punch", swipe = "swipe", fists = "punch", orbs = "cast", earthSplit = "punch", mirror = "cast", innerSmash = "smash_in" },
		env = "slam", throw = "throw_overhead",
		signature = { "heavy", "charge" },
		intro = { style = "rise", depth = 3.4, riseFrac = 0.44, riseEase = "out" }, -- A2-M1: 땅을 가르고 솟는 석상
	},
	frost_giant = {
		walk = { stride = 0.8, knee = 30, arm = 12, bob = 0.09, lean = 6 },
		skills = { slam = "slam", icefall = "cast", spike = "stomp", roar = "roar", swipe = "swipe", spear = "cast", stomp = "stomp", snowball = "cast", mirror = "cast", innerSmash = "smash_in" },
		env = "roar", throw = "throw_spin",
		signature = { "slam", "roar" },
		intro = { style = "iceBreak", depth = 0.9, riseFrac = 0.4, riseEase = "back" }, -- A2-M1: 얼음 덩어리를 깨고 일어섬
	},
	abyssal_lord = {
		walk = { stride = 0.65, knee = 34, arm = 16, bob = 0.06 },
		skills = { sweep = "slam_wide", tide = "stomp", spout = "cast", colors = "cast", swipe = "swipe", tailSweep = "tailSweep", vortex = "vortex", bubbles = "cast", mirror = "cast" },
		env = "beam", throw = "throw_tail",
		signature = { "tailSweep", "vortex" },
		intro = { style = "emerge", depth = 3.8, riseFrac = 0.46, riseEase = "sine" }, -- A2-M1: 물에서 천천히 떠오름
	},
	crystal_queen = {
		walk = { stride = 0.62, knee = 32, arm = 14, bob = 0.05, twist = 8 },
		skills = { burst = "cast", drop = "cast", energyBeam = "beam", orgel = "orgel", swipe = "swipe", spikes = "punch", shards = "cast", mirrorDash = "charge", mirror = "cast" },
		env = "cast", throw = "throw_push",
		signature = { "energyBeam", "orgel" },
		intro = { style = "assemble", depth = 1.2, riseFrac = 0.44, riseEase = "back", fromAbove = true, spinDeg = 180, crouch = {} }, -- A2-M1: 결정이 모여 조립되며 내려앉음
	},
	scorpion_queen = {
		walk = { stride = 0.55, swing = 22, lift = 18 },
		skills = { claw = "clawSweep", sting = "sting", stab = "dig", sandSearch = "dig", swipe = "swipe", stingJab = "sting", ambush = "dig", clawSweep = "clawSweep", armadillo = "curl" },
		env = "dig", throw = "throw_tail",
		signature = { "clawSweep", "stab" },
		intro = { style = "burrow", depth = 2.2, riseFrac = 0.36, riseEase = "back" }, -- A2-M1: 모래 속에서 튀어나옴
	},
	storm_lord = {
		walk = { stride = 0.66, knee = 34, arm = 14, bob = 0.06, twist = 6 },
		skills = { discharge = "stomp", whirl = "spin", strike = "cast", rods = "cast", swipe = "swipe", tornado = "cast", thunderRing = "stomp", boltSpear = "cast", mirror = "cast", innerSmash = "punch_in" },
		env = "beam", throw = "throw_staff",
		signature = { "whirl", "strike" },
		intro = { style = "descend", depth = 6, riseFrac = 0.34, riseEase = "in", fromAbove = true, crouch = {} }, -- A2-M1: 번개와 함께 하늘에서 내리꽂힘
	},
}

-- 보스 전용 대표 동작(두 발 몸 위에 얹는다)
local tailSweep = {
	pre = {
		{ f = 0.6, ease = "inout", pose = merge(B.guard, { Waist = { 4, 55, 0 }, RootJoint = { 0, 30, 0, 0, -0.15, 0 }, Tail1 = { 0, -40, 0 }, Tail2 = { 0, -15, 0 }, Tail3 = { 0, -10, 0 } }) },
		{ f = 1.0, ease = "out", pose = merge(B.guard, { Waist = { 6, 65, 0 }, RootJoint = { 0, 40, 0, 0, -0.18, 0 }, Tail1 = { 0, -55, 0 }, Tail2 = { 0, -20, 0 }, Tail3 = { 0, -15, 0 } }) },
	},
	post = {
		{ s = 0.1, ease = "out", pose = merge(B.guard, { Waist = { -4, -40, 0 }, RootJoint = { 0, -80, 0, 0, -0.15, 0 }, Tail1 = { 0, 70, 0 }, Tail2 = { 0, 30, 0 }, Tail3 = { 0, 25, 0 }, Tail4 = { 0, 15, 0 } }) },
		{ s = 0.3, ease = "back", pose = merge(B.guard, { Waist = { -6, -48, 0 }, RootJoint = { 0, -95, 0, 0, -0.15, 0 }, Tail1 = { 0, 85, 0 }, Tail2 = { 0, 35, 0 }, Tail3 = { 0, 28, 0 }, Tail4 = { 0, 18, 0 } }) },
		{ s = 1.1, ease = "inout", pose = B.guard },
	},
	hitstop = 0.07, squash = 0.08,
}
local VORTEX = { Waist = { -4, 0, 0 }, Shoulder_R = { 90, 0, 60 }, Shoulder_L = { 90, 0, -60 }, Elbow_R = { 40, 0, 0 }, Elbow_L = { 40, 0, 0 }, Neck = { 10, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.1, 0 } }
local vortex = {
	pre = {
		{ f = 0.5, ease = "inout", pose = merge(B.guard, { Shoulder_R = { 120, 0, 40 }, Shoulder_L = { 120, 0, -40 }, Waist = { 10, 0, 0 }, Neck = { 18, 0, 0 } }) },
		{ f = 1.0, ease = "out", pose = merge(B.guard, { Shoulder_R = { 150, 0, 45 }, Shoulder_L = { 150, 0, -45 }, Waist = { 14, 0, 0 }, Neck = { 24, 0, 0 }, RootJoint = { 0, 0, 0, 0, 0.05, 0 } }) },
	},
	post = { { s = 0.1, ease = "out", pose = VORTEX } },
	loop = { period = 1.2, poses = { VORTEX, merge(VORTEX, { Waist = { -4, 25, 0 }, Shoulder_R = { 80, 0, 70 } }), VORTEX, merge(VORTEX, { Waist = { -4, -25, 0 }, Shoulder_L = { 80, 0, -70 } }) } },
	hitstop = 0.03,
}
local ORGEL = { Waist = { 6, 0, 0 }, Neck = { 14, 0, 0 }, Shoulder_R = { 150, 0, 12 }, Elbow_R = { 12, 0, 0 }, Shoulder_L = { 35, 0, -25 }, Elbow_L = { 70, 0, 0 } }
local orgel = { -- 수정 여왕: 홀을 높이 들어 종을 울리듯 흔든다
	-- A2-M1 2차(리뷰: 자세 변화가 작아 안 읽힘): 먼저 홀을 아래로 모으며 몸을 낮췄다가(예비) 발끝으로 솟으며 머리 위로 크게 치켜든다 · 흔들기 폭 ±15 → ±25 · 시간 칸(pre 비율)은 그대로
	pre = {
		{ f = 0.3, ease = "inout", pose = merge(B.guard, { Waist = { 18, 0, 0 }, Neck = { -6, 0, 0 }, Shoulder_R = { 20, 0, 30 }, Elbow_R = { 60, 0, 0 }, Shoulder_L = { 30, 0, -30 }, Elbow_L = { 60, 0, 0 }, RootJoint = { 0, 0, 0, 0, -0.25, 0 } }) },
		{ f = 0.7, ease = "inout", pose = merge(B.guard, ORGEL, { RootJoint = { 0, 0, 0, 0, 0.15, 0 } }) },
		{ f = 1.0, ease = "out", pose = merge(B.guard, ORGEL, { Shoulder_R = { 172, 0, 6 }, Waist = { -8, 0, 0 }, Neck = { 22, 0, 0 }, RootJoint = { 0, 0, 0, 0, 0.2, 0 } }) },
	},
	post = { { s = 0.12, ease = "out", pose = merge(ORGEL, { Shoulder_R = { 130, 0, 20 }, Waist = { -4, 0, 0 } }) } },
	loop = { period = 0.6, poses = { merge(ORGEL, { Shoulder_R = { 138, 0, 35 }, Waist = { 6, -8, 0 } }), merge(ORGEL, { Shoulder_R = { 152, 0, -15 }, Waist = { 6, 8, 0 } }) } },
	hitstop = 0.04,
}
D.bossClips = {
	abyssal_lord = { tailSweep = tailSweep, vortex = vortex, slam_wide = B.clips.slam }, -- slam_wide = slam과 같은 동작 · 땅 치기 효과만 옛 크기(impacts - 판정 원 24)
	crystal_queen = { orgel = orgel, swipe = swipeWide },
}

-- 스킬이 표에 없을 때: primitive · motion → 동작
D.defaults = {
	biped = { circleBoss = "slam", ring = "stomp", circleTarget = "cast", charge = "charge", line = "punch", sector = "swipe", projectile = "cast", reflect = "cast", sweep = "beam", vortex = "cast", sonic = "roar", colorMatch = "cast", orgel = "cast", boomerang = "charge", lightningRods = "cast", sandSearch = "cast" },
	scorpion = { circleBoss = "clawSweep", ring = "clawSweep", circleTarget = "sting", charge = "dig", line = "sting", sector = "clawSweep", projectile = "sting", reflect = "curl", sandSearch = "dig" },
}

-- A2-M1 피격 반응 세기(클라 BossAnimator - 체력 감소 비율로): 세기 = clamp(base + 감소 비율 × perHpRatio, base, max) · 1.2 넘으면 길이 ×1.4(강공격 · 치명 = 크게 · 판정 무관)
D.flinchAmp = { base = 0.7, perHpRatio = 60, max = 2.0 }

-- A2-M1 보이는 루트 보간(클라 BossAnimator - 서버 루트는 판정 자리 그대로): 2차 임계 감쇠 스프링(omega - 클수록 빨리 따라감 · 지연 ≈ 2 / omega초) +
--   복제 틱 사이 속도 보정(estVel = 새 자리 ÷ 틱 간격을 velBlend로 섞음 · 앞당김 = min(마지막 틱 뒤 시간, maxLeadSeconds) + 스프링 지연 × springLeadFraction) ·
--   staleSeconds 동안 새 자리가 안 오면 멈춘 것 - estVel을 stopDecay(1/초)로 거둔다.
D.interp = { omega = 16, velBlend = 0.5, staleSeconds = 0.08, stopDecay = 18, maxLeadSeconds = 0.05, springLeadFraction = 0.85 }
-- A2-N4 P0-1: 보이는 방향 - 이 속도(stud/초)를 넘게 움직이면 가는 쪽 · 아니면 대상 쪽(클라 BossAnimator)
D.faceMoveMinSpeed = 2
-- BOSS-NIGHT-2 A 조준 고정(겉모습만): 발생 지점 스킬(BossOriginData)은 서버가 예고 순간 정한 조준 방향(모델 Attribute BossAimLockYaw)으로 스킬 끝까지 몸을 고정하고
--   머리 시선은 정면(0°)으로 lookRate(1/초)로 모은다 - 시선 추적 · 몸 회전 때문에 시전마다 손 · 부위 자리가 흔들리던 것(MELEE-ORIGIN §4). enabled = false면 옛 동작.
D.aimLock = { enabled = true, lookRate = 14 }
-- A2-N4 §3-3(A2-N3 결정 ④): 평타 예비(basicPrepSeconds) 동안 몸 전체 약한 흰 번쩍임 - 최대 채움 불투명 peak(사인 곡선 · 예비 한가운데가 가장 밝다)
D.prepFlash = { color = Color3.fromRGB(255, 255, 255), peak = 0.28 }

-- A2-M1 몸 충격 효과(클라 client/BossBodyFx - 판정 무관 · 접촉 순간 = 판정 순간): 동작 이름 → { kind, parts(효과 자리 부위), size, shake(가까운 화면 흔들림 배율 - 설정 존중) }
--   kind: ground = 땅 치기(갈라진 고리 · 흙먼지 · 파편) · whoosh = 휘두름(바람 줄기) · spark = 시전(손의 빛 방울) · roar = 포효(가슴 높이 음파 고리 · 발밑 먼지)
--   QUEUE-ALL1 01 C-2(판정보다 큰 이펙트): 땅 치기는 부위 자리에서 약 4.35 × S × size까지 퍼진다(네온 조각 1.2 + 속도 7 × 0.45초 · 고리 3.2). 원 판정 보스 스킬은
--   부위 거리 + 퍼짐 ≤ max(판정 × 1.1, 몸 도달)로 맞춤 - slam(수호자 강공격 14 · 서리 빙결 강타 18) 1.1 → 0.26 · 원 안 강공격(smash_in · punch_in) 0.26.
D.impacts = {
	slam = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 0.26, shake = 1.0, heavy = true },
	slam_wide = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 1.1, shake = 1.0 }, -- 심해 군주 sweep(원 24 - 옛 크기 그대로 1.11)
	smash_in = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 0.26, shake = 1.0, heavy = true },
	punch_in = { kind = "ground", parts = { "Hand_R" }, size = 0.26, shake = 0.6, heavy = true },
	quake_finish = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 1.3, shake = 1.2 },
	stomp = { kind = "ground", parts = { "Foot_R" }, size = 0.9, shake = 0.8 },
	hopSlam = { kind = "ground", parts = { "Foot_L", "Foot_R" }, size = 1.0, shake = 1.0 },
	punch = { kind = "ground", parts = { "Hand_R" }, size = 0.8, shake = 0.6 },
	swipe = { kind = "whoosh", parts = { "Hand_R" }, size = 1.0 },
	basic_R = { kind = "whoosh", parts = { "Hand_R" }, size = 0.55 },
	basic_L = { kind = "whoosh", parts = { "Hand_L" }, size = 0.55 },
	cast = { kind = "spark", parts = { "Hand_R" }, size = 0.8 },
	beam = { kind = "spark", parts = { "Hand_R", "Hand_L" }, size = 0.7 },
	orgel = { kind = "spark", parts = { "Hand_R" }, size = 0.9 },
	vortex = { kind = "spark", parts = { "Hand_R", "Hand_L" }, size = 0.8 },
	roar = { kind = "roar", parts = { "Head" }, size = 1.0, shake = 0.7 },
	hiss = { kind = "roar", parts = { "Head" }, size = 0.8, shake = 0.4 },
	tailSweep = { kind = "whoosh", parts = { "Tail5", "Tail6" }, size = 1.2, floorDust = true },
	clawSweep = { kind = "whoosh", parts = { "Pincer_R", "Pincer_L" }, size = 1.0, floorDust = true },
	sting = { kind = "ground", parts = { "Tail2_8" }, size = 0.6, shake = 0.5 },
	throw_overhead = { kind = "whoosh", parts = { "Hand_R", "Hand_L" }, size = 1.0 },
	throw_spin = { kind = "whoosh", parts = { "Hand_R" }, size = 1.1 },
	throw_tail = { kind = "whoosh", parts = { "Tail6", "Tail1_8" }, size = 1.1 },
	throw_push = { kind = "spark", parts = { "Hand_R", "Hand_L" }, size = 0.9 },
	throw_staff = { kind = "whoosh", parts = { "Hand_R" }, size = 1.0 },
}
-- QUEUE-ALL4 A4(ALL2 결정 7): heavy = true 땅 치기의 무게감(client/BossBodyFx.heavyGround - 판정 무관 · 가로 퍼짐 debrisSide stud/초 이하 = 판정 원 밖으로 안 나감 · 바깥 고리 없음)
--   개수 × 연출 세기 · 크기 × 보스 S · 소리 = 기존 시트 큐(새 에셋 없음) · 흔들림 = 짧게(shakeSeconds · 설정 · 3초 규칙 따름)
D.heavyGround = {
	debris = 10, debrisUp = { 18, 26 }, debrisSide = 1.6, debrisSize = { 0.2, 0.34 }, debrisLife = { 0.9, 1.2 },
	column = 5, columnStep = 0.55, columnJitter = 0.25, columnSize = { 0.7, 1.0 }, columnRise = { 6, 10 }, columnLife = 0.45,
	sound = "hurt_big", soundPitch = 0.75, soundVolume = 0.9, soundMinInterval = 0.15,
	shakeWeight = 1.0, shakeSeconds = 0.1,
}

-- A2-M1 분노(체력이 phaseAt 아래로 - 모든 보스 공통 겉모습 · 판정 무관): 한 번 포효 효과 + 빛나는 부위(수정 · 룬 · 눈)가 위험색 쪽으로 짙어진다(tint - UIColors.danger로 섞는 비율)
D.enrage = { phaseAt = 0.5, tint = 0.45, eyeTint = 0.7, seconds = 0.6 }

-- A2-M1 무거운 발걸음(클라): 보스 무게(rig.weight) ≥ minWeight면 발 디딤마다 먼지 · 가까우면(nearStuds) 작은 흔들림(설정 존중)
D.footsteps = { dustWeight = 0.9, shakeWeight = 1.25, nearStuds = 38, shakeScale = 0.35 }

-- 무게(4b-2 무게감): 보스 rig.weight × 이 값으로 히트스톱 · 몸 눌림을 키운다
D.weightScale = { hitstop = 1, squash = 1 }

-- QUEUE-ALL1 01 C-2(STATUS ⑥ "꼬리가 대상 쪽으로 최대 0.9만 나옴"): 꼬리로 대상 쪽 판정을 치는 스킬 id = 그 동작 동안 보이는 몸을 180° 돌린다(client/BossAnimator)
D.tailToTarget = { tailSweep = true }
return D
