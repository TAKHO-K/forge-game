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

-- ═══════════════════════════ 구간 수호자 v2 - 너클 보행 수정 골렘(GUARDIAN-V2 · Meshy 몸 · 바이블 §2-1 전용 동작 전부) ═══════════════════════════
-- 리그 = BossRigV2Data(A-포즈 팔 = 기준 자세 · 손이 원래 땅 가까이). 자세 수치 = 오프라인 FK로 손 · 발 밑점을 맞춤(boss_framework_test 접지 · 접촉 줄).
--   동작은 마지막 키 = 빈 자세({}) → 그 순간의 세트 기본 자세(변신 전 너클 · 뒤 직립)로 부드럽게 돌아간다(관절 가중치 → 0) - 한 동작이 두 세트에 다 맞는다(돌진만 세트별).
--   옛 직립(plan) 동작 빌림 0개: 평타 · 잡기 흐름 · 지진파 뛰어오름 · 마무리 · 숨 고르기 · 포효 · 등장 웅크림 · 피격 · 기절 · 처치까지 전부 이 표(planPatch = plan 값 덮어쓰기).
do
	-- 다리 굽힘(루트 내림 drop 단위 → 엉덩이 · 무릎 · 발목 각 - 다리 길이 0.8: drop ≈ 0.8 × (1 − cos a))
	local function crouch(drop, pitch)
		local a = math.deg(math.acos(math.clamp(1 - drop / 0.8, -1, 1)))
		return { RootJoint = { pitch or 0, 0, 0, 0, -drop, 0 }, Hip_L = { a, 0, -4 }, Hip_R = { a, 0, 4 }, Knee_L = { -2 * a, 0, 0 }, Knee_R = { -2 * a, 0, 0 }, Ankle_L = { a, 0, 0 }, Ankle_R = { a, 0, 0 } }
	end
	-- 변신 전 너클: 루트 −20%(0.2) · 허리 숙임 · 주먹 바닥(FK 손 밑점 −1.51 · 발 −1.51) · 고개 들어 앞을 봄
	local KNUCKLE = merge(crouch(0.2), { Waist = { -12, 0, 0 }, Neck = { 10, 0, 0 }, Shoulder_L = { 15, 0, 0 }, Shoulder_R = { 15, 0, 0 }, Elbow_L = { 10, 0, 0 }, Elbow_R = { 10, 0, 0 },
		Wrist_L = { -10, 0, 0 }, Wrist_R = { -10, 0, 0 } })
	-- 변신 뒤: 등 수정이 터져 밑동 쪽으로 짧게 남음(수정 축 방향으로 들어감 - 부모 축 이동) · 직립(가슴 폄 · 팔은 손이 땅에서 뜨게 팔꿈치 굽힘)
	local CRYSTAL_BROKEN = { Crystal1 = { 0, 0, 0, 0, -0.36, -0.13 }, Crystal2 = { 0, 0, 0, 0.17, -0.44, -0.1 }, Crystal3 = { 0, 0, 0, -0.27, -0.38, -0.08 },
		Crystal4 = { 0, 0, 0, 0, -0.08, -0.1 }, Crystal5 = { 0, 0, 0, 0, -0.08, -0.1 } }
	local UPRIGHT = { Waist = { 8, 0, 0 }, Neck = { -4, 0, 0 }, Shoulder_L = { 2, 0, 0 }, Shoulder_R = { 2, 0, 0 }, Elbow_L = { 20, 0, 0 }, Elbow_R = { 20, 0, 0 } }
	local STAND = merge(UPRIGHT, { Waist = { 14, 0, 0 }, Neck = { 14, 0, 0 } })

	-- 공용 자세 조각
	local REAR = merge(crouch(0.1), { RootJoint = { -8, 0, 0, 0, 0.05, 0.25 }, Waist = { 14, 0, 0 }, Neck = { 6, 0, 0 }, -- 뒷다리로 일어서 두 주먹 머리 위(FK 손 y 3.6)
		Shoulder_L = { 140, 0, 25 }, Shoulder_R = { 140, 0, -25 }, Elbow_L = { 20, 0, 0 }, Elbow_R = { 20, 0, 0 }, Wrist_L = { 0, 0, 0 }, Wrist_R = { 0, 0, 0 } })
	local SLAM = merge(crouch(0.35, 12), { RootJoint = { 12, 0, 0, 0, -0.35, -0.2 }, Waist = { -35, 0, 0 }, Neck = { 28, 0, 0 }, -- 두 주먹 땅(FK 손 (±1.24, −1.47, −2.37))
		Shoulder_L = { 38, 0, 15 }, Shoulder_R = { 38, 0, -15 }, Elbow_L = { 20, 0, 0 }, Elbow_R = { 20, 0, 0 }, Wrist_L = { -20, 0, 0 }, Wrist_R = { -20, 0, 0 } })
	local SLAM_LOW = merge(SLAM, { Waist = { -40, 0, 0 }, RootJoint = { 14, 0, 0, 0, -0.42, -0.22 } })
	-- 가슴 치기(주먹이 가슴 룬 앞 - 팔을 안으로 · 팔꿈치 접기)
	local BEAT_L = merge(STAND, { Shoulder_L = { 72, 0, 42 }, Elbow_L = { 95, 0, 0 }, Shoulder_R = { 40, 0, 20 }, Elbow_R = { 60, 0, 0 } })
	local BEAT_R = merge(STAND, { Shoulder_R = { 72, 0, -42 }, Elbow_R = { 95, 0, 0 }, Shoulder_L = { 40, 0, -20 }, Elbow_L = { 60, 0, 0 } })
	local FISTS_UP = merge(STAND, { Waist = { 18, 0, 0 }, Neck = { 22, 0, 0 }, Shoulder_L = { 150, 0, 20 }, Shoulder_R = { 150, 0, -20 }, Elbow_L = { 25, 0, 0 }, Elbow_R = { 25, 0, 0 } })
	local REST_POSE = {} -- 세트 기본 자세로(가중치 → 0)

	local C = {}
	-- 1 강공격 heavy(원 r14): 웅크려 힘 모음 → 뒷다리로 일어서 두 주먹 머리 위 → 앞으로 엎어지며 내려찍기(두 주먹 번쩍) → 기본 자세
	C.k_heavy = {
		pre = {
			{ f = 0.22, ease = "inout", pose = merge(crouch(0.3, 8), { Waist = { -22, 0, 0 }, Neck = { 16, 0, 0 }, Shoulder_L = { -10, 0, -6 }, Shoulder_R = { -10, 0, 6 }, Elbow_L = { 20, 0, 0 }, Elbow_R = { 20, 0, 0 } }) },
			{ f = 0.62, ease = "inout", pose = REAR },
			{ f = 0.9, ease = "inout", pose = merge(REAR, { Waist = { 18, 0, 0 }, Shoulder_L = { 150, 0, 22 }, Shoulder_R = { 150, 0, -22 } }) },
			{ f = 1.0, ease = "in", pose = merge(REAR, { Waist = { 20, 0, 0 }, Shoulder_L = { 154, 0, 20 }, Shoulder_R = { 154, 0, -20 }, RootJoint = { -10, 0, 0, 0, 0.08, 0.28 } }) },
		},
		post = {
			{ s = 0.1, ease = "in", pose = SLAM }, -- 접촉 = 판정 시각(BossActHit)
			{ s = 0.34, ease = "out", pose = SLAM_LOW },
			{ s = 1.25, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.08, squash = 0.3,
	}
	-- 2 진동파 shockwave(고리): 일어서 가슴 치기 2번 → 두 주먹 땅 내리치기(첫 파동) · 파동마다 뛰어올라 찍기(hopSlam) · 마무리 강타 · 숨 고르기
	C.k_shock = {
		pre = {
			{ f = 0.18, ease = "out", pose = STAND },
			{ f = 0.34, ease = "inout", pose = BEAT_L },
			{ f = 0.5, ease = "inout", pose = BEAT_R },
			{ f = 0.66, ease = "inout", pose = BEAT_L },
			{ f = 0.8, ease = "inout", pose = BEAT_R },
			{ f = 1.0, ease = "in", pose = FISTS_UP },
		},
		post = {
			{ s = 0.08, ease = "in", pose = SLAM },
			{ s = 0.4, ease = "out", pose = SLAM_LOW },
			{ s = 1.1, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.07, squash = 0.25,
		extraStrikes = { pre = { 0.34, 0.5, 0.66, 0.8 } }, -- 가슴 치기 4번(의도된 빠른 타격 - 하네스 튐 검사가 첫 타격과 같은 창으로 뺀다)
	}
	local HOP_AIR = merge(FISTS_UP, { Hip_L = { 50, 0, -6 }, Hip_R = { 50, 0, 6 }, Knee_L = { -80, 0, 0 }, Knee_R = { -80, 0, 0 }, Ankle_L = { 25, 0, 0 }, Ankle_R = { 25, 0, 0 } })
	C.hopSlam = { -- 서버 BossHopAt · 뛰는 시간 = 착지 = 파동
		pre = {
			{ f = 0.2, ease = "out", pose = merge(crouch(0.38, 10), { Waist = { -30, 0, 0 }, Shoulder_L = { -15, 0, -6 }, Shoulder_R = { -15, 0, 6 }, Elbow_L = { 25, 0, 0 }, Elbow_R = { 25, 0, 0 } }) },
			{ f = 0.55, ease = "out", pose = HOP_AIR },
			{ f = 1.0, ease = "in", pose = merge(HOP_AIR, { Waist = { 22, 0, 0 }, Shoulder_L = { 160, 0, 18 }, Shoulder_R = { 160, 0, -18 } }) },
		},
		post = {
			{ s = 0.07, ease = "in", pose = SLAM_LOW },
			{ s = 0.5, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06, squash = 0.25,
		airborne = { from = 0.2, to = 1.0 },
	}
	C.quake_finish = { -- 마무리 강타(피해 없음): 크게 일어서 두 주먹 → 거칠게 내려찍고 부르르
		pre = { { f = 1.0, ease = "out", pose = merge(REAR, { Waist = { 22, 0, 0 }, Shoulder_L = { 158, 0, 18 }, Shoulder_R = { 158, 0, -18 } }) } },
		post = {
			{ s = 0.07, ease = "in", pose = merge(SLAM_LOW, { Waist = { -46, 0, 0 } }) },
			{ s = 0.3, ease = "back", pose = merge(SLAM_LOW, { Waist = { -42, 0, 4 } }) },
		},
		hitstop = 0.08, squash = 0.3, finishHit = 0.35,
	}
	local PANT = merge(KNUCKLE, crouch(0.3, 6), { Waist = { -26, 0, 0 }, Neck = { -6, 0, 0 }, Shoulder_L = { 10, 0, 0 }, Shoulder_R = { 10, 0, 0 }, Elbow_L = { 5, 0, 0 }, Elbow_R = { 5, 0, 0 } })
	C.rest = { -- 숨 고르기: 주먹 짚고 고개 떨군 채 어깨로 헐떡임(가까이 와 때릴 틈)
		post = { { s = 0.35, ease = "inout", pose = PANT } },
		loop = { period = 0.9, poses = { PANT, merge(PANT, { Waist = { -21, 0, 0 }, Neck = { 0, 0, 0 }, RootJoint = { 6, 0, 0, 0, -0.25, 0 }, Pauldron_L = { 0, 0, 0, 0, 0.04, 0 }, Pauldron_R = { 0, 0, 0, 0, 0.04, 0 } }) } },
	}
	-- 3 낙석 meteor: 오른손으로 땅을 파 바위를 뜯어 → 머리 위로 → 던짐(접촉 = 던진 뒤 자세 · 판정 시각에 바위가 떨어짐)
	local DIG = merge(crouch(0.3, 8), { Waist = { -30, -20, 0 }, Neck = { 10, 15, 0 }, Shoulder_R = { 20, 0, -10 }, Elbow_R = { 5, 0, 0 }, Wrist_R = { -25, 0, 0 }, Shoulder_L = { 20, 0, 0 } })
	C.k_meteor = {
		pre = {
			{ f = 0.25, ease = "inout", pose = DIG },
			{ f = 0.38, ease = "out", pose = merge(DIG, { Waist = { -34, -24, 0 }, Wrist_R = { -40, 0, 0 } }) }, -- 손가락을 박음
			{ f = 0.62, ease = "inout", pose = merge(crouch(0.15), { Waist = { -6, -10, 0 }, Neck = { 12, 5, 0 }, Shoulder_R = { 75, 0, -10 }, Elbow_R = { 70, 0, 0 }, Shoulder_L = { 25, 0, 0 } }) }, -- 뜯어 올림
			{ f = 1.0, ease = "in", pose = merge(crouch(0.1), { RootJoint = { -6, 0, 0, 0, -0.1, 0.12 }, Waist = { 16, 30, 0 }, Neck = { 14, -15, 0 }, Shoulder_R = { 170, 0, -12 }, Elbow_R = { 45, 0, 0 }, Shoulder_L = { 60, 0, 10 } }) }, -- 머리 뒤로 젖혀 감음
		},
		post = {
			{ s = 0.08, ease = "out", pose = merge(crouch(0.25, 10), { Waist = { -26, -25, 0 }, Neck = { 18, 15, 0 }, Shoulder_R = { 55, 0, -8 }, Elbow_R = { 0, 0, 0 }, Wrist_R = { -30, 0, 0 }, Shoulder_L = { 10, 0, 0 } }) },
			{ s = 0.32, ease = "back", pose = merge(crouch(0.25, 10), { Waist = { -30, -30, 0 }, Shoulder_R = { 40, 0, -4 }, Wrist_R = { -20, 0, 0 } }) },
			{ s = 1.1, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.05,
	}
	-- 4 돌진 charge: 변신 전 = 네 발 질주(고릴라 돌진 - 접촉부터 팔다리는 너클 보행 주기가 그린다 · 몸통만 낮게) · 변신 뒤 = 어깨 들이받기
	C.k_charge = {
		pre = {
			{ f = 0.3, ease = "inout", pose = merge(KNUCKLE, crouch(0.3, 8), { Waist = { -22, 0, 0 }, Neck = { 22, 0, 0 } }) }, -- 낮게 노려봄
			{ f = 0.5, ease = "out", pose = merge(KNUCKLE, crouch(0.3, 8), { Waist = { -20, 0, 0 }, Neck = { 20, 0, 0 }, Shoulder_R = { 70, 0, 0 }, Elbow_R = { 40, 0, 0 } }) }, -- 오른 주먹 들어
			{ f = 0.62, ease = "in", pose = merge(KNUCKLE, crouch(0.3, 8), { Waist = { -24, 0, 0 }, Neck = { 22, 0, 0 } }) }, -- 쾅(땅 긁기)
			{ f = 1.0, ease = "inout", pose = merge(KNUCKLE, crouch(0.4, 12), { Waist = { -28, 0, 0 }, Neck = { 30, 0, 0 } }) }, -- 웅크려 튀어나갈 준비
		},
		post = {
			{ s = 0.08, ease = "out", pose = { Waist = { -26, 0, 0 }, Neck = { 30, 0, 0 }, Brow = { -10, 0, 0 } } },
		},
		loop = { period = 0.3, poses = { { Waist = { -26, 0, 0 }, Neck = { 30, 0, 0 } }, { Waist = { -22, 0, 0 }, Neck = { 26, 0, 0 } } } },
		upper = true, glare = true, hitstop = 0.05,
		extraStrikes = { pre = { 0.5, 0.62 } }, -- 주먹 들어 땅 긁기
	}
	local BASH = merge(crouch(0.2, 10), { Waist = { -22, -38, 0 }, Neck = { 6, 36, 0 }, Shoulder_R = { 15, 0, -20 }, Elbow_R = { 70, 0, 0 }, Shoulder_L = { 55, 0, 25 }, Elbow_L = { 60, 0, 0 } })
	C.u_charge = {
		pre = {
			{ f = 0.4, ease = "inout", pose = merge(BASH, { Waist = { -10, -30, 0 } }) }, -- 어깨를 앞으로 돌려 노려봄
			{ f = 0.7, ease = "inout", pose = merge(BASH, crouch(0.3, 10), { Waist = { -14, -36, 0 } }) },
			{ f = 1.0, ease = "inout", pose = merge(BASH, crouch(0.35, 12), { Waist = { -18, -40, 0 } }) },
		},
		post = { { s = 0.08, ease = "out", pose = { Waist = { -24, -40, 0 }, Neck = { 8, 38, 0 }, Shoulder_R = { 15, 0, -20 }, Elbow_R = { 70, 0, 0 }, Shoulder_L = { 55, 0, 25 }, Elbow_L = { 60, 0, 0 } } } },
		loop = { period = 0.32, poses = { { Waist = { -24, -40, 0 }, Neck = { 8, 38, 0 } }, { Waist = { -20, -36, 0 }, Neck = { 6, 34, 0 } } } },
		upper = true, glare = true, hitstop = 0.05,
	}
	-- 5 십자 화염 cross: 두 주먹 X자로 땅 찍기 → 4방향 수정 줄기 · 둘째 볼리 = 몸 45° 돌려 다시(판정 = 첫 볼리 · 둘째 = 전조 1.5초 뒤)
	local X_UP = merge(STAND, { Waist = { 16, 0, 0 }, Neck = { 18, 0, 0 }, Shoulder_L = { 150, 0, -12 }, Shoulder_R = { 150, 0, 12 }, Elbow_L = { 30, 0, 0 }, Elbow_R = { 30, 0, 0 } })
	local X_HIT = merge(SLAM, { Shoulder_L = { 32, 0, 38 }, Shoulder_R = { 32, 0, -38 }, Elbow_L = { 25, 0, 0 }, Elbow_R = { 25, 0, 0 } }) -- 손목이 몸 앞에서 엇갈림
	local function turned(p, deg)
		local r = p.RootJoint or { 0, 0, 0, 0, 0, 0 }
		return merge(p, { RootJoint = { r[1], deg, r[3], r[4] or 0, r[5] or 0, r[6] or 0 } })
	end
	C.k_cross = {
		pre = {
			{ f = 0.35, ease = "inout", pose = merge(STAND, { Shoulder_L = { 80, 0, 50 }, Shoulder_R = { 80, 0, -50 }, Elbow_L = { 40, 0, 0 }, Elbow_R = { 40, 0, 0 } }) }, -- 팔을 가슴 앞 X
			{ f = 1.0, ease = "in", pose = X_UP },
		},
		post = {
			{ s = 0.08, ease = "in", pose = X_HIT },
			{ s = 0.45, ease = "out", pose = merge(X_HIT, { Waist = { -38, 0, 0 } }) },
			{ s = 0.85, ease = "inout", pose = turned(X_UP, 45) }, -- 45° 돌며 다시 들어 올림(둘째 볼리 전조)
			{ s = 1.5, ease = "in", pose = turned(X_HIT, 45) }, -- 둘째 볼리 판정(첫 판정 + 전조 1.5초)
			{ s = 1.85, ease = "out", pose = turned(merge(X_HIT, { Waist = { -38, 0, 0 } }), 45) },
			{ s = 2.6, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.07, squash = 0.2,
		extraStrikes = { post = { 0.85, 1.5 } }, -- 둘째 볼리(45° 돌며 다시 들어 찍기)
	}
	-- 6 강화 평타 swipe(부채 r14): 오른팔을 몸 앞으로 감아 떨다가 손등으로 바깥으로 휘두름(Hand_R 번쩍)
	C.k_swipe = {
		pre = {
			{ f = 0.45, ease = "inout", pose = merge(crouch(0.15), { Waist = { -10, 30, 0 }, Neck = { 6, -20, 0 }, Shoulder_R = { 70, 0, -45 }, Elbow_R = { 75, 0, 0 }, Shoulder_L = { 20, 0, -10 } }) },
			{ f = 1.0, ease = "out", pose = merge(crouch(0.2), { Waist = { -12, 40, 0 }, Neck = { 8, -26, 0 }, Shoulder_R = { 76, 0, -55 }, Elbow_R = { 85, 0, 0 }, Shoulder_L = { 24, 0, -12 } }) },
		},
		post = {
			{ s = 0.08, ease = "out", pose = merge(crouch(0.2), { Waist = { -14, -38, 0 }, Neck = { 6, 22, 0 }, Shoulder_R = { 40, 0, 40 }, Elbow_R = { 86, 0, 0 }, Shoulder_L = { 20, 0, 6 } }) }, -- 손등 = 부채 r14 + 몸 가장자리 안(FK 15.8 stud)
			{ s = 0.24, ease = "back", pose = merge(crouch(0.2), { Waist = { -14, -46, 0 }, Neck = { 6, 26, 0 }, Shoulder_R = { 42, 0, 50 }, Elbow_R = { 72, 0, 0 } }) },
			{ s = 0.9, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06, squash = 0.06,
		tremble = { from = 0.6, amp = 3.5, joints = { "Shoulder_R", "Elbow_R" } },
	}
	-- 7 움켜쥐기 grab: 손 뻗어 쥐기 → 머리 위로 들기 → 던지기(서버 잡기 흐름 grab_tele · grab_reach · grab_hold · 낚아챔 · 던지기 = 이 세트 것)
	local GRAB_UP = merge(crouch(0.15), { Waist = { 8, 0, 0 }, Neck = { 22, 0, 0 }, Shoulder_L = { 130, 0, -30 }, Shoulder_R = { 130, 0, 30 }, Elbow_L = { 30, 0, 0 }, Elbow_R = { 30, 0, 0 }, Brow = { -10, 0, 0 } })
	C.grab_tele = {
		pre = {
			{ f = 0.15, ease = "out", pose = merge(KNUCKLE, crouch(0.3, 6), { Waist = { -20, 0, 0 }, Neck = { 24, 0, 0 } }) },
			{ f = 0.8, ease = "inout", pose = GRAB_UP }, -- 두 손을 크게 벌려 듦("점프하지 마")
			{ f = 1.0, ease = "inout", pose = merge(GRAB_UP, { Shoulder_L = { 135, 0, -34 }, Shoulder_R = { 135, 0, 34 } }) },
		},
		post = { { s = 0.15, ease = "out", pose = merge(GRAB_UP, { Waist = { -14, 0, 0 } }) } },
		tremble = { from = 0.75, amp = 2.5, joints = { "Shoulder_R", "Shoulder_L" } },
	}
	local REACH = { Waist = { -24, 0, 0 }, Neck = { 22, 0, 0 }, Shoulder_L = { 85, 0, 18 }, Shoulder_R = { 85, 0, -18 }, Elbow_L = { 12, 0, 0 }, Elbow_R = { 12, 0, 0 }, Wrist_L = { 20, 0, 0 }, Wrist_R = { 20, 0, 0 } }
	C.grab_reach = {
		post = { { s = 0.15, ease = "out", pose = REACH } },
		loop = { period = 0.32, poses = { REACH, merge(REACH, { Shoulder_L = { 90, 0, 14 }, Shoulder_R = { 80, 0, -22 }, Waist = { -26, 3, 0 } }) } },
		upper = true,
	}
	local HOLD = merge(crouch(0.1), { Waist = { 6, 0, 0 }, Neck = { 16, 0, 0 }, Shoulder_L = { 120, 0, 20 }, Shoulder_R = { 120, 0, -20 }, Elbow_L = { 25, 0, 0 }, Elbow_R = { 25, 0, 0 } }) -- 몸 앞 위로 들어 매단다
	C.grab_hold = {
		post = { { s = 0.25, ease = "out", pose = HOLD } },
		loop = { period = 0.5, poses = { HOLD, merge(HOLD, { Waist = { 7, 4, 2 }, Shoulder_L = { 116, 0, 22 }, Shoulder_R = { 124, 0, -18 } }) } },
	}
	C.grab_snatch = { -- 낚아챔(더하는 층 - 손이 확 오므라듦 · 눈썹 내림)
		post = {
			{ s = 0.06, ease = "out", pose = { Waist = { -6, 0, 0 }, Elbow_L = { 18, 0, 0 }, Elbow_R = { 18, 0, 0 }, Brow = { -8, 0, 0 } } },
			{ s = 0.5, ease = "inout", pose = {} },
		},
		hitstop = 0.05,
	}
	C.k_throw = { -- 던지기: 머리 뒤로 감았다가 앞으로 내던짐(전조 = plan throwWindup)
		pre = { { f = 1.0, ease = "inout", pose = merge(crouch(0.1), { RootJoint = { -6, 0, 0, 0, -0.1, 0.15 }, Waist = { 18, 0, 0 }, Neck = { 12, 0, 0 }, Shoulder_L = { 170, 0, 15 }, Shoulder_R = { 170, 0, -15 }, Elbow_L = { 55, 0, 0 }, Elbow_R = { 55, 0, 0 } }) } },
		post = {
			{ s = 0.08, ease = "out", pose = merge(crouch(0.25, 10), { Waist = { -28, 0, 0 }, Neck = { 22, 0, 0 }, Shoulder_L = { 70, 0, 10 }, Shoulder_R = { 70, 0, -10 }, Elbow_L = { 5, 0, 0 }, Elbow_R = { 5, 0, 0 } }) },
			{ s = 0.8, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06,
	}
	-- 8 방패 거울 mirror: 웅크리고 팔로 몸을 감싼 채 등 수정이 돔처럼 빛남(반사 자세 동안 수정이 맥박)
	local HUNCH = merge(crouch(0.4, 12), { Waist = { -34, 0, 0 }, Neck = { -18, 0, 0 }, Shoulder_L = { 55, 0, 40 }, Shoulder_R = { 55, 0, -40 }, Elbow_L = { 70, 0, 0 }, Elbow_R = { 70, 0, 0 },
		Crystal1 = { -8, 0, 0 }, Crystal2 = { 0, 0, 8 }, Crystal3 = { 0, 0, -8 } })
	C.k_mirror = {
		pre = {
			{ f = 0.5, ease = "inout", pose = merge(HUNCH, { Waist = { -26, 0, 0 } }) },
			{ f = 1.0, ease = "out", pose = HUNCH },
		},
		post = { { s = 0.1, ease = "out", pose = merge(HUNCH, { Crystal1 = { -12, 0, 0, 0, 0.06, 0 }, Crystal2 = { 0, 0, 12, 0, 0.06, 0 }, Crystal3 = { 0, 0, -12, 0, 0.06, 0 } }) } },
		loop = { period = 0.6, poses = { HUNCH, merge(HUNCH, { Waist = { -32, 0, 0 }, Crystal1 = { -12, 0, 0, 0, 0.06, 0 }, Crystal2 = { 0, 0, 12, 0, 0.06, 0 }, Crystal3 = { 0, 0, -12, 0, 0.06, 0 } }) } },
		hitstop = 0.05,
	}
	-- 9 원 안 내려찍기 innerSmash(원 r12 - 발치): 두 주먹을 깍지 껴 머리 위 → 발치에 해머
	local HAMMER_UP = merge(STAND, { Waist = { 12, 0, 0 }, Neck = { 10, 0, 0 }, Shoulder_L = { 160, 0, -6 }, Shoulder_R = { 160, 0, 6 }, Elbow_L = { 20, 0, 0 }, Elbow_R = { 20, 0, 0 } })
	local HAMMER_HIT = merge(crouch(0.3, 10), { Waist = { -24, 0, 0 }, Neck = { -6, 0, 0 }, Shoulder_L = { 32, 0, 30 }, Shoulder_R = { 32, 0, -30 }, Elbow_L = { 10, 0, 0 }, Elbow_R = { 10, 0, 0 }, Wrist_L = { -25, 0, 0 }, Wrist_R = { -25, 0, 0 } })
	C.k_inner = {
		pre = {
			{ f = 0.5, ease = "inout", pose = merge(HAMMER_UP, { Shoulder_L = { 130, 0, -6 }, Shoulder_R = { 130, 0, 6 } }) },
			{ f = 1.0, ease = "in", pose = HAMMER_UP },
		},
		post = {
			{ s = 0.07, ease = "in", pose = HAMMER_HIT },
			{ s = 0.3, ease = "out", pose = merge(HAMMER_HIT, { Waist = { -28, 0, 0 } }) },
			{ s = 1.0, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.08, squash = 0.25,
	}
	-- 10 쌍권 연타 fists(연발 원 4 - 판정 1.1 · 2.2 · 3.4 · 4.95): 좌우 번갈아 땅 치기 → 마지막 = 두 주먹(큰 원)
	local PUNCH_R_UP = merge(crouch(0.15), { Waist = { 6, 18, 0 }, Neck = { 10, -10, 0 }, Shoulder_R = { 150, 0, -10 }, Elbow_R = { 35, 0, 0 }, Shoulder_L = { 20, 0, 0 } })
	local PUNCH_R = merge(crouch(0.35, 10), { Waist = { -32, -14, 0 }, Neck = { 22, 8, 0 }, Shoulder_R = { 32, 0, -10 }, Elbow_R = { 15, 0, 0 }, Wrist_R = { -20, 0, 0 }, Shoulder_L = { 35, 0, 0 }, Elbow_L = { 30, 0, 0 } })
	local PUNCH_L_UP, PUNCH_L = mirror(PUNCH_R_UP), mirror(PUNCH_R)
	C.k_fists = {
		pre = { { f = 1.0, ease = "in", pose = PUNCH_R_UP } },
		post = {
			{ s = 0.07, ease = "in", pose = PUNCH_R },
			{ s = 0.6, ease = "inout", pose = PUNCH_L_UP },
			{ s = 1.1, ease = "in", pose = PUNCH_L },
			{ s = 1.7, ease = "inout", pose = PUNCH_R_UP },
			{ s = 2.3, ease = "in", pose = PUNCH_R },
			{ s = 3.1, ease = "inout", pose = FISTS_UP },
			{ s = 3.85, ease = "in", pose = SLAM_LOW },
			{ s = 4.6, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06, squash = 0.15,
		extraStrikes = { post = { 0.6, 1.1, 1.7, 2.3, 3.1, 3.85 } }, -- 둘째 ~ 넷째 판정(연발 원 - 판정 1.1 · 2.2 · 3.4 · 4.95 근처)
	}
	-- 11 추적 광구 orbs: 등을 웅크려 수정 2개를 빛내다(전조) → 몸을 젖히며 수정에서 광구 발사(수정이 튀어 올랐다 돌아옴)
	C.k_orbs = {
		pre = {
			{ f = 0.5, ease = "inout", pose = merge(crouch(0.3, 8), { Waist = { -28, 0, 0 }, Neck = { -10, 0, 0 }, Shoulder_L = { 30, 0, 20 }, Shoulder_R = { 30, 0, -20 }, Elbow_L = { 40, 0, 0 }, Elbow_R = { 40, 0, 0 },
				Crystal2 = { 0, 0, 10, 0, -0.05, 0 }, Crystal3 = { 0, 0, -10, 0, -0.05, 0 } }) },
			{ f = 1.0, ease = "out", pose = merge(crouch(0.35, 10), { Waist = { -34, 0, 0 }, Neck = { -14, 0, 0 }, Shoulder_L = { 34, 0, 24 }, Shoulder_R = { 34, 0, -24 }, Elbow_L = { 50, 0, 0 }, Elbow_R = { 50, 0, 0 },
				Crystal2 = { 0, 0, 14, 0, -0.08, 0 }, Crystal3 = { 0, 0, -14, 0, -0.08, 0 } }) },
		},
		post = {
			{ s = 0.08, ease = "out", pose = merge(STAND, { Waist = { 18, 0, 0 }, Neck = { 20, 0, 0 }, Shoulder_L = { 40, 0, -40 }, Shoulder_R = { 40, 0, 40 }, Elbow_L = { 10, 0, 0 }, Elbow_R = { 10, 0, 0 },
				Crystal2 = { 0, 0, -18, -0.12, 0.3, 0.1 }, Crystal3 = { 0, 0, 18, 0.12, 0.3, 0.1 } }) },
			{ s = 0.4, ease = "back", pose = merge(STAND, { Waist = { 12, 0, 0 }, Crystal2 = { 0, 0, -6, 0, 0.05, 0 }, Crystal3 = { 0, 0, 6, 0, 0.05, 0 } }) },
			{ s = 1.1, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.05,
	}
	-- 12 대지 가르기 earthSplit(반원 r40): 오른손을 땅에 대고 오른쪽 뒤에서 왼쪽 앞으로 반원 긁기(손이 땅에 붙은 채 몸을 돌린다 · Hand_R 번쩍)
	local SCRAPE = merge(crouch(0.4, 12), { Waist = { -30, 0, 0 }, Neck = { 16, 0, 0 }, Shoulder_R = { 45, 0, 10 }, Elbow_R = { 5, 0, 0 }, Wrist_R = { -30, 0, 0 }, Shoulder_L = { 40, 0, -10 }, Elbow_L = { 40, 0, 0 } })
	C.k_split = {
		pre = {
			{ f = 0.35, ease = "inout", pose = merge(SCRAPE, { Waist = { -26, 60, 0 }, Neck = { 14, -40, 0 } }) }, -- 오른쪽으로 비틀어 손을 땅에
			{ f = 1.0, ease = "out", pose = merge(SCRAPE, { Waist = { -32, 70, 0 }, Neck = { 16, -46, 0 }, RootJoint = { 12, 10, 0, 0, -0.4, 0 } }) },
		},
		post = {
			{ s = 0.08, ease = "out", pose = merge(SCRAPE, { Waist = { -32, 30, 0 }, Neck = { 16, -20, 0 }, RootJoint = { 12, 6, 0, 0, -0.4, 0 } }) }, -- 판정 = 긁기 시작
			{ s = 0.55, ease = "inout", pose = merge(SCRAPE, { Waist = { -30, -70, 0 }, Neck = { 16, 40, 0 }, RootJoint = { 12, -12, 0, 0, -0.4, 0 } }) }, -- 반원 끝까지
			{ s = 1.4, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06,
		tremble = { from = 0.7, amp = 2.5, joints = { "Shoulder_R", "Waist" } },
	}
	-- 환경(지반 붕괴 - 50% 뒤 두 번째 시계): 일어서 가슴 치기 → 두 주먹을 높이 → 땅을 내려쳐 무너뜨림
	C.k_env = {
		pre = {
			{ f = 0.2, ease = "out", pose = STAND },
			{ f = 0.38, ease = "inout", pose = BEAT_L },
			{ f = 0.56, ease = "inout", pose = BEAT_R },
			{ f = 1.0, ease = "in", pose = FISTS_UP },
		},
		post = {
			{ s = 0.08, ease = "in", pose = SLAM_LOW },
			{ s = 0.45, ease = "out", pose = merge(SLAM_LOW, { Waist = { -46, 0, 0 } }) },
			{ s = 1.3, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.08, squash = 0.3,
		extraStrikes = { pre = { 0.38, 0.56 } }, -- 가슴 치기 2번
	}
	-- 포효(등장 · 짧은 등장): 숨 들이마심 → 가슴을 펴고 두 팔 벌려 포효(입 없음 - 눈 · 눈썹 표정이 받는다) · 떨림 되풀이
	local ROAR = merge(STAND, { Waist = { 22, 0, 0 }, Neck = { 30, 0, 0 }, Shoulder_L = { 60, 0, -50 }, Shoulder_R = { 60, 0, 50 }, Elbow_L = { 40, 0, 0 }, Elbow_R = { 40, 0, 0 }, Brow = { -12, 0, 0 } })
	C.roar = {
		pre = { { f = 1.0, ease = "inout", pose = merge(KNUCKLE, crouch(0.3, 6), { Waist = { -20, 0, 0 }, Neck = { -10, 0, 0 } }) } },
		post = { { s = 0.12, ease = "out", pose = ROAR } },
		loop = { period = 0.16, poses = { ROAR, merge(ROAR, { Waist = { 24, 0, 2 }, Neck = { 33, 0, -3 } }) } },
	}
	-- 평타(좌우 번갈아 - 손등 짧게): 준비 자세 → 빠른 한 방 → 기본 자세
	local basicR = {
		post = {
			{ s = 0.07, ease = "out", pose = { Waist = { -10, -26, 0 }, Shoulder_R = { 60, 0, 40 }, Elbow_R = { 10, 0, 0 }, Neck = { -2, 12, 0 } } },
			{ s = 0.17, ease = "back", pose = { Waist = { -12, -32, 0 }, Shoulder_R = { 55, 0, 50 }, Elbow_R = { 6, 0, 0 }, Neck = { -4, 14, 0 } } },
			{ s = 0.62, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.04,
	}
	C.basic_R = basicR
	C.basic_L = { post = { { s = 0.07, ease = "out", pose = mirror(basicR.post[1].pose) }, { s = 0.17, ease = "back", pose = mirror(basicR.post[2].pose) }, { s = 0.62, ease = "inout", pose = REST_POSE } }, hitstop = 0.04 }
	local prepR = { Waist = { 4, 22, 0 }, Shoulder_R = { 70, 0, -40 }, Elbow_R = { 70, 0, 0 }, Neck = { 2, -8, 0 } }
	-- 50% 변신(지반 붕괴와 함께): 웅크림 → 일어서며 가슴 치기 2번 → 등 수정 폭발(수정이 위 · 바깥으로 솟았다가 밑동만 남음) → 직립 세트
	local BURST = merge(STAND, { Waist = { 26, 0, 0 }, Neck = { 34, 0, 0 }, Shoulder_L = { 50, 0, -70 }, Shoulder_R = { 50, 0, 70 }, Elbow_L = { 20, 0, 0 }, Elbow_R = { 20, 0, 0 }, Brow = { -14, 0, 0 },
		Crystal1 = { -25, 0, 0, 0, 0.5, 0.25 }, Crystal2 = { 0, 0, 30, -0.35, 0.45, 0.2 }, Crystal3 = { 0, 0, -30, 0.35, 0.45, 0.2 }, Crystal4 = { 0, 0, 30, -0.2, 0.2, 0.15 }, Crystal5 = { 0, 0, -30, 0.2, 0.2, 0.15 } })
	C.k_transform = {
		pre = {
			{ f = 0.35, ease = "inout", pose = merge(KNUCKLE, crouch(0.35, 8), { Waist = { -26, 0, 0 }, Neck = { 0, 0, 0 } }) },
			{ f = 1.0, ease = "out", pose = STAND },
		},
		post = {
			{ s = 0.0, ease = "out", pose = BEAT_L },
			{ s = 0.18, ease = "inout", pose = BEAT_R },
			{ s = 0.36, ease = "in", pose = BEAT_L },
			{ s = 0.54, ease = "inout", pose = BEAT_R },
			{ s = 0.74, ease = "out", pose = BURST },
			{ s = 1.05, ease = "back", pose = merge(BURST, CRYSTAL_BROKEN, { Waist = { 18, 0, 0 } }) },
			{ s = 1.6, ease = "inout", pose = merge(UPRIGHT, CRYSTAL_BROKEN) },
		},
		hitstop = 0.06, align = false,
	}

	-- plan 덮어쓰기(BossMotion.context가 세트 plan 표에 얹는다 - 옛 직립 값 대신): 등장 웅크림 · 피격 · 기절(엉덩방아 + 별) · 처치 · 전투 준비 · 평타 예비
	local SIT = merge({ RootJoint = { -10, 0, 0, 0, -0.62, 0.1 }, Waist = { 6, 0, 0 }, Neck = { -14, 0, 0 }, Hip_L = { 80, 0, -14 }, Hip_R = { 80, 0, 14 }, Knee_L = { -14, 0, 0 }, Knee_R = { -20, 0, 0 },
		Ankle_L = { -16, 0, 0 }, Ankle_R = { -16, 0, 0 }, Shoulder_L = { -6, 0, -24 }, Shoulder_R = { -6, 0, 24 }, Elbow_L = { 10, 0, 0 }, Elbow_R = { 10, 0, 0 }, Brow = { 10, 0, 0 } })
	local STAGGER = merge(crouch(0.15), { Waist = { -14, 0, 12 }, Neck = { -16, 0, 14 }, Shoulder_L = { 30, 0, -20 }, Shoulder_R = { 10, 0, 30 }, RootJoint = { 0, 0, 10, 0.05, -0.15, 0 }, Brow = { 10, 0, 0 } })
	local planPatch = {
		introCrouch = merge(crouch(0.55, 14), { Waist = { -46, 0, 0 }, Neck = { -24, 0, 0 }, Shoulder_L = { 40, 0, 30 }, Shoulder_R = { 40, 0, -30 }, Elbow_L = { 70, 0, 0 }, Elbow_R = { 70, 0, 0 } }),
		introRoar = "roar",
		flinch = { seconds = 0.3, pose = { Waist = { 7, 0, 4 }, Neck = { 9, 0, 0 }, RootJoint = { 0, 0, 0, 0, 0, 0.06 }, Brow = { 6, 0, 0 } } },
		stun = { stagger = STAGGER, sit = SIT, staggerSeconds = 0.5, riseSeconds = 0.8, wobble = { hz = 0.9, neck = 12, waist = 5 }, eyes = { 0, 0, 0 } },
		death = {
			keys = {
				{ s = 0.3, ease = "out", pose = merge(STAGGER, { Waist = { -18, 0, 14 }, Neck = { -20, 0, 16 } }) },
				{ s = 0.75, ease = "inout", pose = merge(STAGGER, { Waist = { -10, 0, -12 }, Neck = { -14, 0, -14 }, RootJoint = { 0, 0, -10, -0.05, -0.25, 0 } }) },
				{ s = 1.25, ease = "in", pose = SIT }, -- 털썩 엉덩방아
				{ s = 1.45, ease = "out", pose = merge(SIT, { RootJoint = { -14, 0, 0, 0, -0.68, 0.1 }, Waist = { -24, 0, 0 }, Neck = { -30, 0, 0 } }) }, -- 고개 떨굼
			},
			hitstopAt = 1.25, fadeFrom = 2.0, fadeSeconds = 0.5, scatterFrom = 1.75, eyes = { 0, 0, 0 }, stars = true, slowSeconds = 0.8, slowRate = 0.4,
		},
		basicPrep = { R = prepR, L = mirror(prepR) },
	}

	local SKILLS = {
		heavy = "k_heavy", shockwave = "k_shock", meteor = "k_meteor", charge = "k_charge", cross = "k_cross", swipe = "k_swipe", grab = "@grab", mirror = "k_mirror",
		innerSmash = "k_inner", fists = "k_fists", orbs = "k_orbs", earthSplit = "k_split",
	}
	local SKILLS_AFTER = table.clone(SKILLS)
	SKILLS_AFTER.charge = "u_charge" -- 변신 뒤 = 어깨 들이받기
	local MOTIONS = { idle = "gait", walk = "gait", intro = "plan:introCrouch", death = "plan:death", env = "k_env", flinch = "plan:flinch", stun = "plan:stun" }
	D.section_guardian_v2 = {
		plan = "biped",
		planPatch = planPatch, -- GUARDIAN-V2: plan 값 덮어쓰기(BossMotion.context) - 위 "plan:" 동작도 이 값
		stunStars = true, -- 기절(돌진 뒤 헤롱) = 엉덩방아 + 머리 위 별
		face = { eyes = { normal = "Eyes", angry = "Eyes_Angry", dazed = "Eyes_Dazed" }, brow = { angry = -14, dazed = 10 } }, -- 표정(입 없음 - 눈 Neon 모양 + 눈썹 바위)
		forms = {
			before = {
				gait = "knuckle", stance = KNUCKLE, guard = KNUCKLE, contacts = { "Foot_L", "Foot_R", "Hand_L", "Hand_R" },
				walk = { stride = 0.8, knee = 26, arm = 0, bob = 0.04, lean = 4, twist = 3, turnLean = 5, runAt = 1.6, armSwing = 1.0, armLift = 20, legLift = 24 },
				motions = MOTIONS, skills = SKILLS, env = "k_env", throw = "k_throw",
			},
			after = {
				gait = "biped", guard = UPRIGHT, stance = CRYSTAL_BROKEN,
				walk = { stride = 0.6, knee = 30, arm = 12, bob = 0.05, lean = 5, twist = 4, turnLean = 6, runAt = 1.6 },
				motions = MOTIONS, skills = SKILLS_AFTER, env = "k_env", throw = "k_throw",
			},
		},
		transform = { clip = "k_transform", hit = 1.0, switchAt = 1.3, seconds = 2.7 },
		intro = { style = "rise", depth = 2.2, riseFrac = 0.44, riseEase = "out" },
		signature = { "heavy", "charge", "shockwave", "meteor", "cross", "innerSmash", "fists", "orbs", "earthSplit", "mirror" },
		flash = {
			heavy = { "Hand_L", "Hand_R" }, shockwave = { "Hand_L", "Hand_R" }, meteor = { "Hand_R" }, charge = { "Head", "RightPauldron", "LeftPauldron" }, cross = { "Hand_L", "Hand_R" },
			swipe = { "Hand_R" }, grab = { "Hand_L", "Hand_R" }, mirror = { "Crystal1", "Crystal2", "Crystal3" }, innerSmash = { "Hand_L", "Hand_R" }, fists = { "Hand_R" },
			orbs = { "Crystal2", "Crystal3" }, earthSplit = { "Hand_R" },
		},
		impacts = {
			k_heavy = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 0.26, shake = 1.0, heavy = true },
			k_shock = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 0.26, shake = 1.0, heavy = true },
			hopSlam = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 1.0, shake = 1.0 },
			quake_finish = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 1.3, shake = 1.2 },
			k_meteor = { kind = "whoosh", parts = { "Hand_R" }, size = 1.1 },
			k_charge = { kind = "roar", parts = { "Head" }, size = 0.8, shake = 0.5 },
			u_charge = { kind = "whoosh", parts = { "RightPauldron" }, size = 1.2 },
			k_cross = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 0.9, shake = 0.8 },
			k_swipe = { kind = "whoosh", parts = { "Hand_R" }, size = 1.1 },
			k_mirror = { kind = "spark", parts = { "Crystal1" }, size = 1.0 },
			k_inner = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 0.26, shake = 1.0, heavy = true },
			k_fists = { kind = "ground", parts = { "Hand_R" }, size = 0.8, shake = 0.6 },
			k_orbs = { kind = "spark", parts = { "Crystal2", "Crystal3" }, size = 0.9 },
			k_split = { kind = "whoosh", parts = { "Hand_R" }, size = 1.2, floorDust = true },
			k_env = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 1.3, shake = 1.2 },
			k_throw = { kind = "whoosh", parts = { "Hand_R", "Hand_L" }, size = 1.0 },
			k_transform = { kind = "roar", parts = { "Body" }, size = 1.2, shake = 0.8 },
			roar = { kind = "roar", parts = { "Head" }, size = 1.0, shake = 0.7 },
			basic_R = { kind = "whoosh", parts = { "Hand_R" }, size = 0.55 },
			basic_L = { kind = "whoosh", parts = { "Hand_L" }, size = 0.55 },
		},
		clips = C,
	}
end

return D
