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
			{ s = 0.08, ease = "out", pose = merge(crouch(0.2), { Waist = { -14, -38, 0 }, Neck = { 6, 22, 0 }, Shoulder_R = { 40, 0, 40 }, Elbow_R = { 96, 0, 0 }, Shoulder_L = { 20, 0, 6 } }) }, -- 손등 = 부채 r14 + 몸 가장자리 안(V2 FK 15.8 stud · V3 크기 × 2.0 = 팔꿈치 86 → 96)
			{ s = 0.24, ease = "back", pose = merge(crouch(0.2), { Waist = { -14, -46, 0 }, Neck = { 6, 26, 0 }, Shoulder_R = { 42, 0, 50 }, Elbow_R = { 80, 0, 0 } }) },
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
	-- GUARDIAN-V3 반응 스킬 ① 바나나 던지기(예비 0.45 = 오른팔 머리 뒤로 · 바나나 발광 → 놓는 순간 = 판정 시작 → 앞으로 내던짐)
	C.k_banana = {
		pre = {
			{ f = 0.55, ease = "inout", pose = merge(crouch(0.1), { Waist = { 10, 22, 0 }, Neck = { 8, -16, 0 }, Shoulder_R = { 165, 0, -25 }, Elbow_R = { 80, 0, 0 }, Shoulder_L = { 40, 0, 25 } }) },
			{ f = 1.0, ease = "in", pose = merge(crouch(0.12), { Waist = { 16, 30, 0 }, Neck = { 10, -20, 0 }, Shoulder_R = { 175, 0, -30 }, Elbow_R = { 95, 0, 0 }, Shoulder_L = { 50, 0, 30 } }) },
		},
		post = {
			{ s = 0.07, ease = "out", pose = merge(crouch(0.2, 6), { Waist = { -22, -24, 0 }, Neck = { 16, 14, 0 }, Shoulder_R = { 70, 0, -8 }, Elbow_R = { 8, 0, 0 }, Shoulder_L = { 20, 0, 10 } }) },
			{ s = 0.6, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.05,
	}
	-- GUARDIAN-V3 반응 스킬 ② 도약(준비 1.1(V3.1) = 깊이 웅크림 + 등 수정 발광 → 판정 시각 = 이륙 · 비행 0.8 = 두 팔 머리 위 → 내려오며 두 주먹 해머 → 착지)
	local LEAP_CROUCH = merge(crouch(0.5, 14), { Waist = { -30, 0, 0 }, Neck = { 22, 0, 0 }, Shoulder_L = { -25, 0, 20 }, Shoulder_R = { -25, 0, -20 }, Elbow_L = { 25, 0, 0 }, Elbow_R = { 25, 0, 0 },
		Crystal1 = { -6, 0, 0 }, Crystal2 = { 0, 0, 6 }, Crystal3 = { 0, 0, -6 } })
	local LEAP_AIR = merge(crouch(0.25), { Waist = { 14, 0, 0 }, Neck = { 6, 0, 0 }, Shoulder_L = { 160, 0, 25 }, Shoulder_R = { 160, 0, -25 }, Elbow_L = { 30, 0, 0 }, Elbow_R = { 30, 0, 0 } })
	C.k_leap = {
		pre = {
			{ f = 0.6, ease = "inout", pose = LEAP_CROUCH },
			{ f = 1.0, ease = "in", pose = merge(LEAP_CROUCH, { RootJoint = { 6, 0, 0, 0, -0.55, 0 } }) },
		},
		post = {
			{ s = 0.2, ease = "out", pose = LEAP_AIR },
			{ s = 0.55, ease = "inout", pose = merge(LEAP_AIR, { Waist = { 20, 0, 0 }, Shoulder_L = { 170, 0, 15 }, Shoulder_R = { 170, 0, -15 }, Elbow_L = { 50, 0, 0 }, Elbow_R = { 50, 0, 0 } }) },
			{ s = 0.8, ease = "in", pose = SLAM }, -- 착지 = 두 주먹 땅(서버 착지 판정과 같은 시각)
			{ s = 1.5, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0, squash = 0.2,
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
		banana = "k_banana", leap = "k_leap", -- GUARDIAN-V3 반응 스킬(새 몸 - BossFrameworkData.v3)
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
			banana = { "Hand_R" }, leap = { "Crystal1", "Crystal2", "Crystal3" }, -- GUARDIAN-V3 반응 스킬(바나나 = 던지는 손 · 도약 = 등 수정)
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
			k_banana = { kind = "whoosh", parts = { "Hand_R" }, size = 1.0 }, -- GUARDIAN-V3(도약 착지 먼지 = BossQuakeView.leapImpact)
			k_transform = { kind = "roar", parts = { "Body" }, size = 1.2, shake = 0.8 },
			roar = { kind = "roar", parts = { "Head" }, size = 1.0, shake = 0.7 },
			basic_R = { kind = "whoosh", parts = { "Hand_R" }, size = 0.55 },
			basic_L = { kind = "whoosh", parts = { "Hand_L" }, size = 0.55 },
		},
		clips = C,
	}
end


-- ═══════════════════════════ 빙하 매머드 "빙하 엄니" v2(BOSS-NIGHT-1 1 · Meshy 몸 · 네 발 · 바이블 §2-6 + MAMMOTH-SCORPION-NOTES) ═══════════════════════════
-- 리그 = BossRigV2Data frost_giant_v2(다리 = 아래로 곧게 · 코 = 아래로 늘어짐 · 상아 = 앞으로). 부호: 다리 rx + = 앞으로 듦 · 무릎/팔꿈치 rx − = 접음 ·
--   RootJoint rx + = 코가 아래(앞으로 숙임) · − = 뒷다리로 일어섬 · Waist(엉덩이 → 앞몸) rx − = 앞몸 숙임 · Neck rx − = 고개 숙임 · 코 마디 rx + = 앞 · 위로 말아 올림 · rz = 옆으로.
-- 동작 마지막 키 = 빈 자세({}) → 세트 기본 자세로. 앞발이 들리면 발 접지 보정(가장 낮은 발 = 땅)이 뒷발을 땅에 둔다.
do
	local REST_POSE = {}
	local function trunk(a, side)
		local z = (side or 0) * 0.7 -- 사슬 끝은 마디 각이 쌓인다(코끝 각속도 - 튐 검사) → 마디마다 작게
		return { Trunk1 = { a * 0.45, 0, z }, Trunk2 = { a * 0.65, 0, z }, Trunk3 = { a * 0.7, 0, z }, Trunk4 = { a * 0.7, 0, z }, Trunk5 = { a * 0.7, 0, z }, Trunk6 = { a * 0.6, 0, z } }
	end
	-- 뒷다리로 일어섬(앞발 듦 · 뒷다리는 몸 기울기만큼 되돌려 땅을 짚음)
	local function rear(pitch, front)
		return merge({ RootJoint = { -pitch, 0, 0, 0, 0.12 * pitch / 30, 0.18 * pitch / 30 }, Hip_L = { pitch, 0, 0 }, Hip_R = { pitch, 0, 0 }, Neck = { 12, 0, 0 },
			Shoulder_L = { front, 0, 0 }, Shoulder_R = { front, 0, 0 }, Elbow_L = { -front * 0.8, 0, 0 }, Elbow_R = { -front * 0.8, 0, 0 } }, trunk(14))
	end
	local REAR = rear(28, 70)
	local REAR_HI = merge(rear(34, 80), trunk(20))
	-- 앞발로 내리찍음(코 · 머리 숙임)
	local SLAM = merge({ RootJoint = { 10, 0, 0, 0, -0.06, -0.05 }, Hip_L = { -10, 0, 0 }, Hip_R = { -10, 0, 0 }, Neck = { -18, 0, 0 }, Shoulder_L = { -8, 0, 0 }, Shoulder_R = { -8, 0, 0 },
		Ear_L = { 0, 0, -18 }, Ear_R = { 0, 0, 18 } }, trunk(-6))
	local SLAM_LOW = merge(SLAM, { RootJoint = { 13, 0, 0, 0, -0.1, -0.06 }, Neck = { -24, 0, 0 } })
	local CROUCH = { RootJoint = { 6, 0, 0, 0, -0.08, 0 }, Hip_L = { -6, 0, 0 }, Hip_R = { -6, 0, 0 }, Neck = { -10, 0, 0 } }
	local HEAD_DOWN = merge({ RootJoint = { 8, 0, 0, 0, -0.05, 0 }, Hip_L = { -8, 0, 0 }, Hip_R = { -8, 0, 0 }, Neck = { -30, 0, 0 } }, trunk(-8))
	-- 변신 뒤(분노): 고개를 낮추고 상아를 앞으로 · 귀 펼침 · 코 살짝 말림
	local ANGRY = merge({ Neck = { -10, 0, 0 }, Ear_L = { 0, 0, -16 }, Ear_R = { 0, 0, 16 }, Fur1 = { -6, 0, 0 }, Fur2 = { -6, 0, 0 } }, trunk(6))

	local C = {}
	-- 1 빙결 강타 slam(원 r18 · 2.25초): 웅크림 → 뒷다리로 일어서 앞발 높이 → 내리찍기(앞발 번쩍)
	C.m_slam = {
		pre = {
			{ f = 0.22, ease = "inout", pose = CROUCH },
			{ f = 0.66, ease = "inout", pose = REAR },
			{ f = 1.0, ease = "in", pose = REAR_HI },
		},
		post = {
			{ s = 0.1, ease = "in", pose = SLAM },
			{ s = 0.4, ease = "out", pose = SLAM_LOW },
			{ s = 1.4, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06, squash = 0.3,
	}
	-- 2 낙빙 icefall: 몸을 부르르 털어 등 얼음 조각을 날림(등 얼음이 흔들렸다 솟음)
	local SHAKE_L = merge(CROUCH, { RootJoint = { 4, 0, 9, 0, -0.05, 0 }, Neck = { -6, 10, 6 }, Fur1 = { 0, 0, 10 }, Fur2 = { 0, 0, 12 }, BackIce = { 0, 0, 10 }, Ear_L = { 0, 0, -20 } })
	local SHAKE_R = merge(CROUCH, { RootJoint = { 4, 0, -9, 0, -0.05, 0 }, Neck = { -6, -10, -6 }, Fur1 = { 0, 0, -10 }, Fur2 = { 0, 0, -12 }, BackIce = { 0, 0, -10 }, Ear_R = { 0, 0, 20 } })
	C.m_icefall = {
		pre = {
			{ f = 0.3, ease = "inout", pose = CROUCH },
			{ f = 0.5, ease = "inout", pose = SHAKE_L },
			{ f = 0.7, ease = "inout", pose = SHAKE_R },
			{ f = 1.0, ease = "out", pose = merge(rear(10, 20), { BackIce = { 0, 0, 0, 0, 0.12, 0 }, Fur2 = { 8, 0, 0 } }) },
		},
		post = {
			{ s = 0.12, ease = "inout", pose = SHAKE_L },
			{ s = 0.3, ease = "inout", pose = SHAKE_R },
			{ s = 1.0, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.05,
		extraStrikes = { pre = { 0.5, 0.7 }, post = { 0.12, 0.3 } },
	}
	-- 3 얼음 가시 spike(직선): 상아를 낮춰 땅을 갈며 앞으로 밀어냄
	C.m_spike = {
		pre = {
			{ f = 0.4, ease = "inout", pose = HEAD_DOWN },
			{ f = 1.0, ease = "in", pose = merge(HEAD_DOWN, { Neck = { -40, 0, 0 }, RootJoint = { 12, 0, 0, 0, -0.08, 0.05 } }) },
		},
		post = {
			{ s = 0.1, ease = "out", pose = merge(HEAD_DOWN, { Neck = { -34, 0, 0 }, RootJoint = { 10, 0, 0, 0, -0.06, -0.12 } }) },
			{ s = 0.6, ease = "inout", pose = merge(HEAD_DOWN, { Neck = { -26, 0, 0 } }) },
			{ s = 1.4, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06, squash = 0.15,
	}
	-- 4 눈보라 포효 roar(전멸기 · 등장): 코를 치켜들고 숨 들이쉼 → 포효(틱마다 코 떨림)
	local ROAR = merge(rear(8, 10), { Neck = { 26, 0, 0 }, Ear_L = { 0, 0, -28 }, Ear_R = { 0, 0, 28 } }, trunk(26))
	C.roar = {
		pre = {
			{ f = 0.6, ease = "inout", pose = merge(CROUCH, { Neck = { -16, 0, 0 } }, trunk(-4)) },
			{ f = 1.0, ease = "inout", pose = merge(rear(6, 6), { Neck = { 18, 0, 0 } }, trunk(18)) },
		},
		post = { { s = 0.14, ease = "out", pose = ROAR } },
		loop = { period = 0.16, poses = { ROAR, merge(ROAR, { Neck = { 28, 0, 2 } }, trunk(30, 3)) } },
	}
	-- 5 강화 평타 swipe(부채 r14): 머리를 오른쪽으로 감았다가 상아로 크게 휘두름(상아 번쩍)
	C.m_swipe = {
		pre = {
			{ f = 0.45, ease = "inout", pose = merge(CROUCH, { Waist = { 0, 14, 0 }, Neck = { -12, 34, 8 } }, trunk(4, 10)) },
			{ f = 1.0, ease = "out", pose = merge(CROUCH, { Waist = { 0, 18, 0 }, Neck = { -14, 44, 12 } }, trunk(6, 14)) },
		},
		post = {
			{ s = 0.08, ease = "out", pose = merge(CROUCH, { Waist = { 0, -16, 0 }, Neck = { -16, -40, -12 } }, trunk(2, -16)) },
			{ s = 0.26, ease = "back", pose = merge(CROUCH, { Waist = { 0, -20, 0 }, Neck = { -16, -46, -12 } }, trunk(2, -20)) },
			{ s = 0.95, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06, squash = 0.06,
		tremble = { from = 0.6, amp = 3, joints = { "Neck" } },
	}
	-- 6 서리 손아귀 grab: 코를 높이 쳐들어 경고 → 코로 감아 들어 한 바퀴 돌려 던지기(잡기 흐름)
	local TRUNK_UP = merge(rear(8, 8), { Neck = { 20, 0, 0 } }, trunk(30))
	C.grab_tele = {
		pre = {
			{ f = 0.2, ease = "out", pose = HEAD_DOWN },
			{ f = 0.8, ease = "inout", pose = TRUNK_UP },
			{ f = 1.0, ease = "inout", pose = merge(TRUNK_UP, trunk(34)) },
		},
		post = { { s = 0.15, ease = "out", pose = merge(TRUNK_UP, { Neck = { 10, 0, 0 } }) } },
		tremble = { from = 0.75, amp = 2.5, joints = { "Trunk2", "Trunk3" } },
	}
	local REACH = merge({ Neck = { -6, 0, 0 }, RootJoint = { 5, 0, 0, 0, -0.03, -0.06 } }, trunk(18))
	C.grab_reach = {
		post = { { s = 0.15, ease = "out", pose = REACH } },
		loop = { period = 0.32, poses = { REACH, merge(REACH, trunk(22, 4)) } },
		upper = true,
	}
	local HOLD = merge({ Neck = { 22, 0, 0 } }, trunk(40))
	C.grab_hold = {
		post = { { s = 0.25, ease = "out", pose = HOLD } },
		loop = { period = 0.5, poses = { HOLD, merge(HOLD, { Neck = { 22, 6, 2 } }, trunk(42, 4)) } },
	}
	C.grab_snatch = {
		post = {
			{ s = 0.06, ease = "out", pose = trunk(10) },
			{ s = 0.5, ease = "inout", pose = {} },
		},
		hitstop = 0.05,
	}
	C.m_throw = { -- 한 바퀴 돌려(몸 비틀기) 내던짐
		pre = {
			{ f = 0.5, ease = "inout", pose = merge(HOLD, { Waist = { 0, 30, 0 }, Neck = { 18, 40, 0 } }, trunk(44, 20)) },
			{ f = 1.0, ease = "inout", pose = merge(HOLD, { Waist = { 0, 34, 0 }, Neck = { 20, 50, 0 } }, trunk(46, 24)) },
		},
		post = {
			{ s = 0.1, ease = "out", pose = merge({ Waist = { 0, -26, 0 }, Neck = { -6, -36, 0 } }, trunk(10, -20)) },
			{ s = 0.85, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06,
	}
	-- 7 얼음 거울 mirror: 웅크리고 털이 얼어붙음(등 털 · 얼음 맥박)
	local HUNKER = merge(CROUCH, { RootJoint = { 2, 0, 0, 0, -0.14, 0 }, Neck = { -22, 0, 0 }, Ear_L = { 0, 0, 10 }, Ear_R = { 0, 0, -10 }, Fur1 = { 0, 0, 0, 0, 0.04, 0 }, Fur2 = { 0, 0, 0, 0, 0.05, 0 }, Fur3 = { 0, 0, 0, 0, 0.04, 0 } }, trunk(-10))
	C.m_mirror = {
		pre = {
			{ f = 0.5, ease = "inout", pose = CROUCH },
			{ f = 1.0, ease = "out", pose = HUNKER },
		},
		post = { { s = 0.1, ease = "out", pose = merge(HUNKER, { BackIce = { 0, 0, 0, 0, 0.06, 0 } }) } },
		loop = { period = 0.6, poses = { HUNKER, merge(HUNKER, { BackIce = { 0, 0, 0, 0, 0.08, 0 }, Fur2 = { 0, 0, 0, 0, 0.08, 0 } }) } },
		hitstop = 0.05,
	}
	-- 8 원 안 짓밟기 innerSmash: 반쯤 일어서 두 앞발로 발치를 짓밟음
	local REAR_MID = rear(18, 48)
	C.m_inner = {
		pre = {
			{ f = 0.4, ease = "inout", pose = CROUCH },
			{ f = 1.0, ease = "in", pose = REAR_MID },
		},
		post = {
			{ s = 0.07, ease = "in", pose = SLAM },
			{ s = 0.3, ease = "out", pose = SLAM_LOW },
			{ s = 1.0, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.07, squash = 0.25,
	}
	-- 9 발 구르기 stomp(r30 · 점프로 넘기): 몸을 왼쪽으로 실어 오른 앞발을 높이 → 쿵
	local STOMP_UP = merge({ RootJoint = { -8, 0, -6, 0, 0.04, 0 }, Hip_L = { 8, 0, 0 }, Hip_R = { 8, 0, 0 }, Shoulder_R = { 80, 0, -6 }, Elbow_R = { -70, 0, 0 }, Neck = { 10, 10, 0 } }, trunk(10))
	C.m_stomp = {
		pre = {
			{ f = 0.4, ease = "inout", pose = { RootJoint = { 0, 0, -6, 0, 0, 0 }, Neck = { -6, 0, 0 } } },
			{ f = 1.0, ease = "in", pose = STOMP_UP },
		},
		post = {
			{ s = 0.07, ease = "in", pose = merge({ RootJoint = { 6, 0, 2, 0, -0.06, 0 }, Shoulder_R = { -6, 0, 0 }, Elbow_R = { 0, 0, 0 }, Neck = { -16, 0, 0 } }, trunk(-6)) },
			{ s = 0.35, ease = "out", pose = merge(SLAM, { RootJoint = { 8, 0, 0, 0, -0.08, 0 } }) },
			{ s = 1.1, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.08, squash = 0.3,
	}
	-- 10 눈덩이 snowball: 코를 땅에 대고 둥글게 굴려 → 앞으로 밀어 보냄(2개 = 좌우)
	C.m_snowball = {
		pre = {
			{ f = 0.45, ease = "inout", pose = merge(HEAD_DOWN, trunk(-14, 12)) },
			{ f = 1.0, ease = "inout", pose = merge(HEAD_DOWN, { Neck = { -24, 0, 0 } }, trunk(-18, -12)) },
		},
		post = {
			{ s = 0.1, ease = "out", pose = merge({ RootJoint = { 6, 0, 0, 0, -0.03, -0.1 }, Neck = { -12, 0, 0 } }, trunk(24)) },
			{ s = 0.95, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.05,
	}
	-- 11 얼음 상아 발사 tuskShot(얼음 창 대체): 머리 숙임 → 상아에 얼음이 자람(1.4초 · 상아 발광) → 고개를 쳐들며 왼 · 오른 2발(0.4초 간격)
	C.m_tusk = {
		pre = {
			{ f = 0.45, ease = "inout", pose = HEAD_DOWN },
			{ f = 1.0, ease = "in", pose = merge(HEAD_DOWN, { Neck = { -34, 8, 0 } }) },
		},
		post = {
			{ s = 0.08, ease = "out", pose = merge({ Neck = { 8, 14, 0 }, RootJoint = { -4, 0, 0, 0, 0.02, 0.04 } }, trunk(8)) }, -- 왼 상아 발사
			{ s = 0.3, ease = "inout", pose = merge(HEAD_DOWN, { Neck = { -20, -8, 0 } }) },
			{ s = 0.48, ease = "out", pose = merge({ Neck = { 8, -14, 0 }, RootJoint = { -4, 0, 0, 0, 0.02, 0.04 } }, trunk(8)) }, -- 오른 상아 발사
			{ s = 1.2, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.05,
		extraStrikes = { post = { 0.48 } },
	}
	-- 12 코 채찍 trunkWhip(앞 140° 부채): 코를 오른쪽으로 감아 들었다가 왼쪽으로 크게 휘두름(코 끝 3마디 번쩍)
	C.m_trunk = {
		pre = {
			{ f = 0.45, ease = "inout", pose = merge(CROUCH, { Neck = { -6, 24, 0 }, Waist = { 0, 8, 0 } }, trunk(20, 18)) },
			{ f = 1.0, ease = "out", pose = merge(CROUCH, { Neck = { -4, 32, 0 }, Waist = { 0, 12, 0 } }, trunk(26, 24)) },
		},
		post = {
			{ s = 0.08, ease = "out", pose = merge(CROUCH, { Neck = { -10, -30, 0 }, Waist = { 0, -12, 0 } }, trunk(14, -26)) },
			{ s = 0.28, ease = "back", pose = merge(CROUCH, { Neck = { -10, -36, 0 }, Waist = { 0, -14, 0 } }, trunk(10, -30)) },
			{ s = 1.0, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06,
		tremble = { from = 0.65, amp = 3, joints = { "Trunk3", "Trunk4" } },
	}
	-- 13 상아 돌진 gore: 고개 숙이고 앞발로 땅 긁기 2번 → 웅크림 → 상아 앞세워 질주(접촉부터 다리 = 네 발 보행 주기)
	local GORE = merge(HEAD_DOWN, { Neck = { -26, 0, 0 }, Ear_L = { 0, 0, -20 }, Ear_R = { 0, 0, 20 } })
	C.m_gore = {
		pre = {
			{ f = 0.3, ease = "inout", pose = GORE },
			{ f = 0.45, ease = "out", pose = merge(GORE, { Shoulder_R = { 30, 0, 0 }, Elbow_R = { -30, 0, 0 } }) },
			{ f = 0.58, ease = "in", pose = merge(GORE, { Shoulder_R = { -12, 0, 0 } }) },
			{ f = 0.72, ease = "out", pose = merge(GORE, { Shoulder_R = { 30, 0, 0 }, Elbow_R = { -30, 0, 0 } }) },
			{ f = 0.85, ease = "in", pose = merge(GORE, { Shoulder_R = { -12, 0, 0 } }) },
			{ f = 1.0, ease = "inout", pose = merge(GORE, { RootJoint = { 12, 0, 0, 0, -0.1, 0.05 } }) },
		},
		post = { { s = 0.08, ease = "out", pose = { Neck = { -26, 0, 0 }, RootJoint = { 8, 0, 0, 0, -0.04, 0 } } } },
		loop = { period = 0.3, poses = { { Neck = { -26, 0, 0 } }, { Neck = { -22, 0, 0 } } } },
		upper = true, glare = true, hitstop = 0.05,
		extraStrikes = { pre = { 0.45, 0.58, 0.72, 0.85 } },
	}
	-- 14 뒷발차기 backKick(반응 · 뒤 120°): 앞발 버티고 엉덩이를 들어 → 두 뒷다리로 뒤를 걷어참(뒷발 번쩍)
	local KICK_LOAD = { RootJoint = { 14, 0, 0, 0, -0.04, -0.06 }, Hip_L = { 22, 0, 0 }, Hip_R = { 22, 0, 0 }, Knee_L = { -40, 0, 0 }, Knee_R = { -40, 0, 0 }, Neck = { -16, 0, 0 }, Shoulder_L = { -12, 0, 0 }, Shoulder_R = { -12, 0, 0 } }
	local KICK = { RootJoint = { 20, 0, 0, 0, -0.06, -0.1 }, Hip_L = { -62, 0, 0 }, Hip_R = { -62, 0, 0 }, Knee_L = { -6, 0, 0 }, Knee_R = { -6, 0, 0 }, Ankle_L = { -20, 0, 0 }, Ankle_R = { -20, 0, 0 },
		Neck = { -20, 0, 0 }, Shoulder_L = { -16, 0, 0 }, Shoulder_R = { -16, 0, 0 }, Tail1 = { 30, 0, 0 } }
	C.m_kick = {
		pre = {
			{ f = 0.45, ease = "inout", pose = merge(CROUCH, { Neck = { -10, 0, 0 } }) },
			{ f = 1.0, ease = "in", pose = KICK_LOAD },
		},
		post = {
			{ s = 0.07, ease = "out", pose = KICK },
			{ s = 0.3, ease = "out", pose = merge(KICK, { Hip_L = { -55, 0, 0 }, Hip_R = { -55, 0, 0 } }) },
			{ s = 1.0, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06, squash = 0.2,
	}
	-- 환경(빙하 균열 · 50% 뒤 두 번째 시계): 포효하듯 크게 일어서 두 앞발로 땅을 내리찍음
	C.m_env = {
		pre = {
			{ f = 0.25, ease = "inout", pose = CROUCH },
			{ f = 0.7, ease = "inout", pose = merge(REAR_HI, { Neck = { 22, 0, 0 } }, trunk(28)) },
			{ f = 1.0, ease = "in", pose = merge(rear(38, 86), trunk(30)) },
		},
		post = {
			{ s = 0.08, ease = "in", pose = SLAM_LOW },
			{ s = 0.45, ease = "out", pose = merge(SLAM_LOW, { Neck = { -30, 0, 0 } }) },
			{ s = 1.4, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.08, squash = 0.3,
	}
	-- 50% 변신(겉모습 격노): 웅크림 → 크게 일어서 포효(등 얼음이 솟음) → 쿵 → 분노 세트(고개 낮춤 · 귀 펼침)
	C.m_transform = {
		pre = {
			{ f = 0.35, ease = "inout", pose = merge(CROUCH, { Neck = { -20, 0, 0 } }) },
			{ f = 1.0, ease = "out", pose = merge(REAR_HI, { Neck = { 28, 0, 0 }, BackIce = { 0, 0, 0, 0, 0.1, 0 } }, trunk(30)) },
		},
		post = {
			{ s = 0.0, ease = "out", pose = merge(REAR_HI, { Neck = { 30, 0, 0 }, BackIce = { 0, 0, 0, 0, 0.14, 0 }, Ear_L = { 0, 0, -30 }, Ear_R = { 0, 0, 30 } }, trunk(32)) },
			{ s = 0.5, ease = "inout", pose = merge(REAR_HI, { Neck = { 26, 0, 2 }, BackIce = { 0, 0, 0, 0, 0.12, 0 } }, trunk(28, 4)) },
			{ s = 0.9, ease = "in", pose = merge(SLAM_LOW, ANGRY) },
			{ s = 1.6, ease = "inout", pose = ANGRY },
		},
		hitstop = 0.06, align = false,
	}
	-- 평타(상아 짧게 찌르기 - 좌우 번갈아)
	local basicR = {
		post = {
			{ s = 0.08, ease = "out", pose = { Neck = { -14, -22, -8 }, RootJoint = { 4, 0, 0, 0, 0, -0.05 } } },
			{ s = 0.18, ease = "back", pose = { Neck = { -16, -26, -8 } } },
			{ s = 0.65, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.04,
	}
	C.basic_R = basicR
	C.basic_L = { post = { { s = 0.08, ease = "out", pose = mirror(basicR.post[1].pose) }, { s = 0.18, ease = "back", pose = mirror(basicR.post[2].pose) }, { s = 0.65, ease = "inout", pose = REST_POSE } }, hitstop = 0.04 }
	local prepR = { Neck = { -6, 18, 6 }, Waist = { 0, 6, 0 } }

	-- plan 덮어쓰기(직립 plan 값 대신 네 발 값): 등장 웅크림 · 피격 · 기절(배를 깔고 주저앉음 + 별) · 처치(옆으로 쓰러짐) · 평타 예비
	local SIT = merge({ RootJoint = { 4, 0, 0, 0, -0.18, 0 }, Shoulder_L = { 40, 0, 10 }, Shoulder_R = { 40, 0, -10 }, Elbow_L = { -50, 0, 0 }, Elbow_R = { -50, 0, 0 },
		Hip_L = { -30, 0, -10 }, Hip_R = { -30, 0, 10 }, Knee_L = { -20, 0, 0 }, Knee_R = { -20, 0, 0 }, Neck = { -18, 0, 0 }, Ear_L = { 0, 0, 12 }, Ear_R = { 0, 0, -12 } }, trunk(-10))
	local STAGGER = merge({ RootJoint = { 4, 0, 10, 0.04, -0.06, 0 }, Neck = { -14, 14, 10 }, Shoulder_L = { 14, 0, -8 }, Hip_R = { -8, 0, 8 } }, trunk(-4, 10))
	local planPatch = {
		introCrouch = merge(CROUCH, { RootJoint = { 6, 0, 0, 0, -0.16, 0 }, Neck = { -30, 0, 0 } }, trunk(-10)),
		introRoar = "roar",
		flinch = { seconds = 0.3, pose = { Neck = { 8, 0, 4 }, RootJoint = { -3, 0, 0, 0, 0, 0.04 }, Ear_L = { 0, 0, -8 }, Ear_R = { 0, 0, 8 } } },
		stun = { stagger = STAGGER, sit = SIT, staggerSeconds = 0.5, riseSeconds = 0.9, wobble = { hz = 0.8, neck = 10, waist = 3 }, eyes = { 0, 0, 0 } },
		death = {
			keys = {
				{ s = 0.3, ease = "out", pose = STAGGER },
				{ s = 0.8, ease = "inout", pose = merge(STAGGER, { RootJoint = { 4, 0, -8, -0.03, -0.08, 0 } }) },
				{ s = 1.3, ease = "in", pose = SIT }, -- 털썩 주저앉음
				{ s = 1.6, ease = "out", pose = merge(SIT, { RootJoint = { 6, 0, 22, 0, -0.26, 0 }, Neck = { -28, 0, 16 } }, trunk(-14)) }, -- 옆으로 기울며 고개 떨굼
			},
			hitstopAt = 1.3, fadeFrom = 2.1, fadeSeconds = 0.5, scatterFrom = 1.85, eyes = { 0, 0, 0 }, stars = true, slowSeconds = 0.8, slowRate = 0.4,
		},
		basicPrep = { R = prepR, L = mirror(prepR) },
	}

	local SKILLS = {
		slam = "m_slam", icefall = "m_icefall", spike = "m_spike", roar = "roar", swipe = "m_swipe", grab = "@grab", mirror = "m_mirror", innerSmash = "m_inner",
		spear = "m_tusk", stomp = "m_stomp", snowball = "m_snowball",
		tuskShot = "m_tusk", trunkWhip = "m_trunk", gore = "m_gore", backKick = "m_kick", -- BOSS-NIGHT-1 새 몸 신규 4패턴(BossFrameworkData.v3.frost_giant · 얼음 창 spear = 옛 스킬표 자리 - 새 몸에선 빠짐)
	}
	local MOTIONS = { idle = "gait", walk = "gait", intro = "plan:introCrouch", death = "plan:death", env = "m_env", flinch = "plan:flinch", stun = "plan:stun" }
	local TUSKS, FRONT_FEET = { "Tusk_L", "Tusk_R" }, { "Hand_L", "Hand_R" }
	D.frost_giant_v2 = {
		plan = "biped",
		planPatch = planPatch,
		stunStars = true,
		forms = {
			before = {
				gait = "quad", stance = {}, guard = {}, contacts = { "Foot_L", "Foot_R", "Hand_L", "Hand_R" },
				walk = { stride = 0.5, knee = 18, arm = 0, bob = 0.03, lean = 3, twist = 2, turnLean = 3, runAt = 1.6, armSwing = 1.0, armLift = 18, legLift = 20 },
				motions = MOTIONS, skills = SKILLS, env = "m_env", throw = "m_throw",
			},
			after = {
				gait = "quad", stance = ANGRY, guard = ANGRY, contacts = { "Foot_L", "Foot_R", "Hand_L", "Hand_R" },
				walk = { stride = 0.56, knee = 20, arm = 0, bob = 0.04, lean = 4, twist = 3, turnLean = 4, runAt = 1.6, armSwing = 1.0, armLift = 20, legLift = 22 },
				motions = MOTIONS, skills = SKILLS, env = "m_env", throw = "m_throw",
			},
		},
		transform = { clip = "m_transform", hit = 1.0, switchAt = 1.6, seconds = 2.8 },
		intro = { style = "iceBreak", depth = 0.9, riseFrac = 0.4, riseEase = "back" },
		signature = { "slam", "roar", "gore", "tuskShot", "stomp", "trunkWhip", "backKick", "icefall", "spike", "snowball", "innerSmash", "mirror" },
		flash = {
			slam = FRONT_FEET, icefall = { "BackIce" }, spike = TUSKS, roar = { "Head" }, swipe = TUSKS, grab = { "Trunk5", "Trunk6" }, mirror = { "Fur2" }, innerSmash = FRONT_FEET,
			spear = TUSKS, stomp = { "Hand_R" }, snowball = { "Trunk6" },
			tuskShot = TUSKS, trunkWhip = { "Trunk4", "Trunk5", "Trunk6" }, gore = { "Tusk_L", "Tusk_R", "Head" }, backKick = { "Foot_L", "Foot_R" },
		},
		impacts = {
			m_slam = { kind = "ground", parts = FRONT_FEET, size = 0.3, shake = 1.1, heavy = true },
			m_icefall = { kind = "spark", parts = { "BackIce" }, size = 1.1 },
			m_spike = { kind = "ground", parts = TUSKS, size = 0.8, shake = 0.6, floorDust = true },
			m_swipe = { kind = "whoosh", parts = { "Tusk_R" }, size = 1.2 },
			m_mirror = { kind = "spark", parts = { "Fur2" }, size = 1.0 },
			m_inner = { kind = "ground", parts = FRONT_FEET, size = 0.28, shake = 1.0, heavy = true },
			m_stomp = { kind = "ground", parts = { "Hand_R" }, size = 0.4, shake = 1.2, heavy = true },
			m_snowball = { kind = "whoosh", parts = { "Trunk6" }, size = 1.0, floorDust = true },
			m_tusk = { kind = "spark", parts = TUSKS, size = 1.0 },
			m_trunk = { kind = "whoosh", parts = { "Trunk6" }, size = 1.2 },
			m_gore = { kind = "roar", parts = { "Head" }, size = 0.8, shake = 0.5 },
			m_kick = { kind = "ground", parts = { "Foot_L", "Foot_R" }, size = 0.5, shake = 0.8 },
			m_env = { kind = "ground", parts = FRONT_FEET, size = 1.3, shake = 1.3 },
			m_throw = { kind = "whoosh", parts = { "Trunk6" }, size = 1.0 },
			m_transform = { kind = "roar", parts = { "Head" }, size = 1.3, shake = 0.9 },
			roar = { kind = "roar", parts = { "Head" }, size = 1.2, shake = 0.8 },
			basic_R = { kind = "whoosh", parts = { "Tusk_R" }, size = 0.6 },
			basic_L = { kind = "whoosh", parts = { "Tusk_L" }, size = 0.6 },
		},
		clips = C,
	}
end

return D
