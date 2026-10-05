-- BOSS-FRAMEWORK 2 동작 세트(리그 v2 전용 - 옛 몸은 BossMotionData 그대로). 리그 키("<보스>_v2")마다:
--   forms = { before = 세트, after = 세트 }(50% 변신 전 · 후 - 서버 무변경 · 클라가 겉모습 격노 순간에 변신 동작 1회 후 세트 교체)
--   세트 = {
--     gait = "biped" | "knuckle" | "quad" | "serpent" | "hover" | "hexapod"(이동 속도에 맞춘 보행 주기 - shared/BossMotion) ·
--     stance(선택 - 늘 깔리는 기본 자세: 너클 · 네 발 · 떠 있기) · rootOffset(단위 - 루트 높이 오프셋: 떠 있기 + · 웅크리기 − · 판정 무변경) ·
--     walk(보폭 · 무릎 … - BossMotionData walk 규격 + quad: armLift · legLift) · guard(전투 준비 - 없으면 plan guard) · contacts(발 접지 부위) ·
--     motions = { idle · walk · intro · death · env · flinch · stun = "gait" | "plan:<이름>" | 동작 이름 }(빠짐 검사 대상) ·
--     skills = { [스킬 id] = 동작 이름 | "@grab"(잡기 흐름) }(BossData 스킬표 전부 - 빠지면 실패) · env · throw(동작 이름) }
--   transform = { clip, hit(초 - 동작 시작 → 접촉), switchAt(초 - 이 순간 세트 교체: 동작이 온몸을 덮는 구간) }
--   flash = { [스킬 id] = { 부위 이름 … } }(전조 끝 직전 흰 테 - BossFrameworkData.flash) · impacts = { [동작 이름] = BossMotionData.impacts 규격 }
--   clips = { [동작 이름] = BossMotionData 동작 규격 }(pre · post · loop · hitstop · squash · tremble · flash …). 이름이 없으면 plan(biped) 동작을 빌려 쓴다(빌림 = 검사 표에 "빌림").
-- 모션 부호(A1 실측): 아래로 늘어진 팔 · 다리 rx +θ = 앞으로 든다 · 무릎 굽힘 rx −θ · 허리 앞 숙임 rx −θ · 고개 숙임 rx −θ · 오른팔 rz + = 옆으로 벌림.
local BossMotionData = require(script.Parent.BossMotionData)

local merge, mirror = BossMotionData.merge, BossMotionData.mirror
local B = BossMotionData.biped

local D = {}

-- ═══════════════════════════ 구간 수호자 v2 - 너클 보행 수정 골렘(시험 1세트) ═══════════════════════════
do
	-- 너클 자세: 허리를 크게 숙이고 주먹으로 땅을 짚는다 · 엉덩이 낮춤(루트 −20%) · 고개를 들어 앞을 본다. 수치 = 하네스 FK로 손 · 발 밑점 높이를 맞춤(boss_framework_test 접지 줄).
	local KNUCKLE = {
		RootJoint = { 8, 0, 0, 0, -0.42, 0.12 }, Waist = { -75, 0, 0 }, Neck = { 62, 0, 0 },
		Hip_L = { 50, 0, -6 }, Hip_R = { 50, 0, 6 }, Knee_L = { -67, 0, 0 }, Knee_R = { -67, 0, 0 }, Ankle_L = { 12, 0, 0 }, Ankle_R = { 12, 0, 0 },
		Shoulder_L = { 75, 0, -14 }, Shoulder_R = { 75, 0, 14 }, Elbow_L = { 10, 0, 0 }, Elbow_R = { 10, 0, 0 }, Wrist_L = { -30, 0, 0 }, Wrist_R = { -30, 0, 0 },
		Brow = { 6, 0, 0 },
	}
	-- 변신 뒤 직립: 등 수정이 터져 짧게 남음(밑동 쪽으로 들어감) · 가슴을 편 준비 자세
	local CRYSTAL_BROKEN = { Crystal1 = { 0, 0, 0, 0, -0.55, 0 }, Crystal2 = { 0, 0, 0, 0, -0.4, 0 }, Crystal3 = { 0, 0, 0, 0, -0.4, 0 }, Crystal4 = { 0, 0, 0, 0, -0.22, 0 }, Crystal5 = { 0, 0, 0, 0, -0.22, 0 } }
	local UPRIGHT = merge(B.guard, { Waist = { -2, 0, 0 }, Neck = { -4, 0, 0 } })

	-- 강공격(변신 전): 뒷다리로 일어서 두 주먹을 머리 위로 → 앞으로 엎어지며 내려찍기(두 주먹 = 판정 원 r14 안 바닥) → 너클 자세로
	local REAR_UP = { RootJoint = { -6, 0, 0, 0, 0.1, 0.25 }, Waist = { 12, 0, 0 }, Neck = { 10, 0, 0 }, Jaw = { 0, 0, 0, 0, -0.1, 0 },
		Hip_L = { 18, 0, -6 }, Hip_R = { 18, 0, 6 }, Knee_L = { -26, 0, 0 }, Knee_R = { -26, 0, 0 }, Ankle_L = { 8, 0, 0 }, Ankle_R = { 8, 0, 0 },
		Shoulder_L = { 178, 0, -16 }, Shoulder_R = { 178, 0, 16 }, Elbow_L = { 34, 0, 0 }, Elbow_R = { 34, 0, 0 }, Wrist_L = { 0, 0, 0 }, Wrist_R = { 0, 0, 0 } }
	local K_SLAM = { RootJoint = { 14, 0, 0, 0, -0.62, -0.3 }, Waist = { -62, 0, 0 }, Neck = { 40, 0, 0 },
		Hip_L = { 64, 0, -8 }, Hip_R = { 64, 0, 8 }, Knee_L = { -84, 0, 0 }, Knee_R = { -84, 0, 0 }, Ankle_L = { 16, 0, 0 }, Ankle_R = { 16, 0, 0 },
		Shoulder_L = { 92, 0, -6 }, Shoulder_R = { 92, 0, 6 }, Elbow_L = { 4, 0, 0 }, Elbow_R = { 4, 0, 0 }, Wrist_L = { -10, 0, 0 }, Wrist_R = { -10, 0, 0 } }
	local k_heavy = {
		pre = {
			{ f = 0.22, ease = "inout", pose = merge(KNUCKLE, { RootJoint = { 10, 0, 0, 0, -0.55, 0.15 }, Waist = { -80, 0, 0 }, Shoulder_L = { 62, 0, -14 }, Shoulder_R = { 62, 0, 14 } }) }, -- 웅크려 힘 모음
			{ f = 0.62, ease = "inout", pose = REAR_UP }, -- 뒷다리로 일어섬(inout - 앞 키가 속도 0으로 끝난다)
			{ f = 0.9, ease = "inout", pose = merge(REAR_UP, { Waist = { 18, 0, 0 }, Shoulder_L = { 190, 0, -12 }, Shoulder_R = { 190, 0, 12 } }) },
			{ f = 1.0, ease = "in", pose = merge(REAR_UP, { Waist = { 20, 0, 0 }, Shoulder_L = { 194, 0, -10 }, Shoulder_R = { 194, 0, 10 }, RootJoint = { -8, 0, 0, 0, 0.14, 0.28 } }) },
		},
		post = {
			{ s = 0.1, ease = "in", pose = K_SLAM }, -- 접촉 = 판정 시각(BossActHit)
			{ s = 0.34, ease = "out", pose = merge(K_SLAM, { Waist = { -66, 0, 0 }, RootJoint = { 16, 0, 0, 0, -0.68, -0.32 } }) },
			{ s = 1.25, ease = "inout", pose = KNUCKLE },
		},
		hitstop = 0.08, squash = 0.3,
	}
	-- 변신(겉모습 격노 순간 · 지반 붕괴 직전): 일어서며 가슴 치기 2번 → 등 수정 폭발 → 직립
	local STAND = merge(UPRIGHT, { Waist = { 14, 0, 0 }, Neck = { 22, 0, 0 }, Jaw = { 0, 0, 0, 0, -0.12, 0 }, RootJoint = { 0, 0, 0, 0, 0.05, 0 } })
	local BEAT_IN = merge(STAND, { Shoulder_L = { 70, 0, 40 }, Shoulder_R = { 70, 0, -40 }, Elbow_L = { 100, 0, 0 }, Elbow_R = { 100, 0, 0 } })
	local BEAT_OUT = merge(STAND, { Shoulder_L = { 60, 0, -50 }, Shoulder_R = { 60, 0, 50 }, Elbow_L = { 80, 0, 0 }, Elbow_R = { 80, 0, 0 } })
	local BURST = merge(STAND, { Waist = { 24, 0, 0 }, Neck = { 34, 0, 0 }, Shoulder_L = { 40, 0, -85 }, Shoulder_R = { 40, 0, 85 }, Elbow_L = { 20, 0, 0 }, Elbow_R = { 20, 0, 0 },
		Crystal1 = { -25, 0, 0, 0, 0.6, 0.2 }, Crystal2 = { 0, 0, -30, -0.3, 0.5, 0.2 }, Crystal3 = { 0, 0, 30, 0.3, 0.5, 0.2 }, Crystal4 = { 0, 0, -40, -0.3, 0.3, 0.1 }, Crystal5 = { 0, 0, 40, 0.3, 0.3, 0.1 } })
	local k_transform = {
		pre = {
			{ f = 0.35, ease = "inout", pose = merge(KNUCKLE, { RootJoint = { 12, 0, 0, 0, -0.6, 0.15 }, Waist = { -80, 0, 0 }, Neck = { 50, 0, 0 } }) },
			{ f = 1.0, ease = "out", pose = STAND },
		},
		post = {
			{ s = 0.0, ease = "out", pose = BEAT_IN },
			{ s = 0.18, ease = "inout", pose = BEAT_OUT },
			{ s = 0.34, ease = "in", pose = BEAT_IN },
			{ s = 0.52, ease = "inout", pose = BEAT_OUT },
			{ s = 0.72, ease = "out", pose = BURST },
			{ s = 1.05, ease = "back", pose = merge(BURST, CRYSTAL_BROKEN, { Waist = { 18, 0, 0 } }) },
			{ s = 1.6, ease = "inout", pose = merge(UPRIGHT, CRYSTAL_BROKEN) },
		},
		hitstop = 0.06, align = false,
	}
	local SET_SKILLS_BEFORE = {
		heavy = "k_heavy", shockwave = "stomp", meteor = "cast", charge = "charge", cross = "punch", swipe = "swipe", grab = "@grab", mirror = "cast",
		innerSmash = "smash_in", fists = "punch", orbs = "cast", earthSplit = "punch",
	}
	local SET_SKILLS_AFTER = table.clone(SET_SKILLS_BEFORE)
	SET_SKILLS_AFTER.heavy = "slam" -- 이미 일어선 몸 = 옛 두 손 내려찍기
	D.section_guardian_v2 = {
		plan = "biped",
		forms = {
			before = {
				gait = "knuckle", stance = KNUCKLE, guard = KNUCKLE, contacts = { "Foot_L", "Foot_R", "Hand_L", "Hand_R" },
				walk = { stride = 0.9, knee = 26, arm = 0, bob = 0.05, lean = 4, twist = 3, turnLean = 5, runAt = 1.6, armSwing = 1.0, armLift = 22, legLift = 26 },
				motions = { idle = "gait", walk = "gait", intro = "plan:introCrouch", death = "plan:death", env = "slam", flinch = "plan:flinch", stun = "plan:stun" },
				skills = SET_SKILLS_BEFORE, env = "slam", throw = "throw_overhead",
			},
			after = {
				gait = "biped", guard = UPRIGHT, stance = CRYSTAL_BROKEN,
				walk = { stride = 0.7, knee = 36, arm = 16, bob = 0.07 },
				motions = { idle = "gait", walk = "gait", intro = "plan:introCrouch", death = "plan:death", env = "slam", flinch = "plan:flinch", stun = "plan:stun" },
				skills = SET_SKILLS_AFTER, env = "slam", throw = "throw_overhead",
			},
		},
		transform = { clip = "k_transform", hit = 1.0, switchAt = 1.3, seconds = 2.7 },
		intro = { style = "rise", depth = 3.4, riseFrac = 0.44, riseEase = "out" },
		signature = { "heavy", "charge" },
		flash = {
			heavy = { "Hand_L", "Hand_R" }, shockwave = { "Hand_L", "Hand_R" }, meteor = { "Hand_R" }, charge = { "RightPauldron", "Head" }, cross = { "Hand_L", "Hand_R" },
			swipe = { "Hand_R" }, grab = { "Hand_L", "Hand_R" }, mirror = { "Crystal1", "Crystal2", "Crystal3" }, innerSmash = { "Hand_L", "Hand_R" }, fists = { "Hand_R" },
			orbs = { "Crystal2", "Crystal3" }, earthSplit = { "Hand_R" },
		},
		impacts = {
			k_heavy = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 0.26, shake = 1.0, heavy = true },
			k_transform = { kind = "roar", parts = { "Body" }, size = 1.2, shake = 0.8 },
		},
		clips = { k_heavy = k_heavy, k_transform = k_transform },
	}
end

return D
