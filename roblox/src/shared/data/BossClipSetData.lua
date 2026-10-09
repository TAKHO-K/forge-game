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
	-- BOSS-NIGHT-2 3 진동파 찍기(사용자 · 설계 검수: 파동 간격 1.5초라 착지 직후 또 점프 = "연속 점프처럼 보임" → v3.hopHeight 0 + 제자리 두 주먹 내려치기) · forms.*.hop
	--   두 주먹을 머리 위로 모아 몸을 젖힘(예비 = 파동 사이 시간) → 두 주먹으로 땅을 내려침(짧은 멈춤) → 회복. 판정 · 파동 시각 그대로(서버 hop 시각 = 내려치는 순간).
	C.k_hop = {
		pre = {
			{ f = 0.35, ease = "out", pose = FISTS_UP },
			{ f = 1.0, ease = "in", pose = merge(FISTS_UP, { Waist = { 24, 0, 0 }, Shoulder_L = { 165, 0, 16 }, Shoulder_R = { 165, 0, -16 } }) },
		},
		post = { { s = 0.06, ease = "in", pose = SLAM_LOW }, { s = 0.3, ease = "out", pose = merge(SLAM_LOW, { Waist = { -42, 0, 0 } }) }, { s = 0.9, ease = "inout", pose = REST_POSE } },
		hitstop = 0.1, squash = 0.25, endFade = 0.5,
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
				motions = MOTIONS, skills = SKILLS, env = "k_env", throw = "k_throw", hop = "k_hop",
			},
			after = {
				gait = "biped", guard = UPRIGHT, stance = CRYSTAL_BROKEN,
				walk = { stride = 0.6, knee = 30, arm = 12, bob = 0.05, lean = 5, twist = 4, turnLean = 6, runAt = 1.6 },
				motions = MOTIONS, skills = SKILLS_AFTER, env = "k_env", throw = "k_throw", hop = "k_hop",
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
			k_hop = { kind = "ground", parts = { "Hand_L", "Hand_R" }, size = 1.0, shake = 1.0, heavy = true },
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
			m_slam = { kind = "ground", parts = FRONT_FEET, size = 0.3, shake = 1.1, heavy = true, crack = 9 },
			m_icefall = { kind = "spark", parts = { "BackIce" }, size = 1.1 },
			m_spike = { kind = "ground", parts = TUSKS, size = 0.8, shake = 0.6, floorDust = true },
			m_swipe = { kind = "whoosh", parts = { "Tusk_R" }, size = 1.2 },
			m_mirror = { kind = "spark", parts = { "Fur2" }, size = 1.0 },
			m_inner = { kind = "ground", parts = FRONT_FEET, size = 0.28, shake = 1.0, heavy = true },
			m_stomp = { kind = "ground", parts = { "Hand_R" }, size = 0.4, shake = 1.2, heavy = true, crack = 9 },
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


-- ═══════════════════════════ 폭풍 군주 v2 — 폭풍 기사 · 50% 비행 변신(BOSS-NIGHT-1 2 · Meshy 몸 + 부품 · 바이블 §2-5 · §10) ═══════════════════════════
-- 리그 = BossRigV2Data storm_lord_v2(A-포즈 팔 = 기준 자세 · 지팡이 = 오른손 자식 · 2폼 부품 = 날개 · 왕관 · 가슴 코어 · 2폼 어깨 · 건틀릿).
--   1폼 = 지팡이 기사(망토 휘날림 · 걸음) · 2폼 = 떠서(hover) 주먹 번개(바이블 §10 · STORM-PARTS "2폼은 주먹 번개 위주"). 부품 숨김 · 후광 · 파편 · 구름 보주 = formParts · formFx(client/BossFormFxView).
--   변신 = 지팡이 수평 → 망토가 펼쳐지며 떠오름 → 세트 교체 순간(switchAt) 2폼 부품이 바깥에서 날아와 붙는다(관절 이동 → 0).
do
	local REST_POSE = {}
	local function crouch(drop, pitch)
		local a = math.deg(math.acos(math.clamp(1 - drop / 1.6, -1, 1)))
		return { RootJoint = { pitch or 0, 0, 0, 0, -drop, 0 }, Hip_L = { a, 0, 0 }, Hip_R = { a, 0, 0 }, Knee_L = { -2 * a, 0, 0 }, Knee_R = { -2 * a, 0, 0 }, Ankle_L = { a, 0, 0 }, Ankle_R = { a, 0, 0 } }
	end
	local function cape(rx, rz)
		local p = {}
		for _, t in ipairs({ "A", "B", "C", "D" }) do
			local side = (t == "A" or t == "B") and -1 or 1
			for i = 1, 4 do
				p["Cape" .. t .. i] = { rx * (i == 1 and 1 or 0.5), 0, side * (rz or 0) * (i == 1 and 1 or 0.4) }
			end
		end
		return p
	end
	-- 1폼 기본: 오른손이 지팡이를 세워 쥠(팔꿈치 굽힘 · 손목이 지팡이를 수직으로) · 왼팔 내림
	local STAFF_HOLD = { Shoulder_R = { 22, 0, -22 }, Elbow_R = { 52, 0, 0 }, Wrist_R = { -70, 0, 0 }, Shoulder_L = { 6, 0, 26 }, Elbow_L = { 18, 0, 0 } }
	-- 2폼 기본: 떠서 두 주먹을 가슴 앞에(권투 자세) · 다리 늘어뜨림 · 날개 조금 펼침
	local FIST_GUARD = { Shoulder_R = { 40, 0, -10 }, Elbow_R = { 95, 0, 0 }, Shoulder_L = { 40, 0, 10 }, Elbow_L = { 95, 0, 0 }, Waist = { -6, 0, 0 }, Neck = { 4, 0, 0 },
		Hip_L = { 14, 0, -4 }, Knee_L = { -34, 0, 0 }, Ankle_L = { 30, 0, 0 }, Hip_R = { 6, 0, 4 }, Knee_R = { -18, 0, 0 }, Ankle_R = { 26, 0, 0 },
		Wing_L1 = { 0, -12, 6 }, Wing_R1 = { 0, 12, -6 } }
	-- BOSS-NIGHT-2 2-1(사용자: 첫 대면 때 무기를 거꾸로 듦): 팔을 머리 위로 들면 손목 기준 지팡이가 뒤집혀 보주가 아래(FK 세로 −0.98) → 지팡이 관절을 쥔 자리 기준 180° 돌림(그립 반전 - 보주가 위 · 드는 동안 지팡이가 반 바퀴 돈다)
	local GRIP_FLIP = { Staff = { 180, 0, 0 } }
	-- BOSS-NIGHT-2(사용자: 실제 싸움처럼): 2폼 전투 준비 = 낮게 떠서 권투 자세(오른 주먹 앞 · 왼 주먹 턱 앞 · 몸 살짝 틀기 · 앞무릎 들기) - forms.after.guard · 떠 있기는 낮고 빠르게 통통
	local FIGHT = merge(FIST_GUARD, { RootJoint = { 2, 0, 0, 0, -0.25, 0 }, Waist = { -4, 18, 0 }, Neck = { 4, -14, 0 }, Shoulder_R = { 58, 0, -12 }, Elbow_R = { 72, 0, 0 },
		Shoulder_L = { 36, 0, 16 }, Elbow_L = { 118, 0, 0 }, Hip_L = { 34, 0, -4 }, Knee_L = { -58, 0, 0 }, Ankle_L = { 26, 0, 0 }, Hip_R = { -14, 0, 4 }, Knee_R = { -34, 0, 0 }, Ankle_R = { 20, 0, 0 } })
	local STAFF_UP = merge(STAFF_HOLD, { Shoulder_R = { 165, 0, -12 }, Elbow_R = { 12, 0, 0 }, Wrist_R = { -10, 0, 0 }, Waist = { 10, 0, 0 }, Neck = { 14, 0, 0 } }, cape(-12), GRIP_FLIP)
	local STAFF_SLAM = merge(crouch(0.25, 8), { Shoulder_R = { 55, 0, -18 }, Elbow_R = { 20, 0, 0 }, Wrist_R = { -55, 0, 0 }, Waist = { -18, 0, 0 }, Neck = { -6, 0, 0 } }, cape(10), GRIP_FLIP) -- 그립 반전 유지(드는 자세 ↔ 찍기 사이에 지팡이가 반 바퀴 돌지 않게 - 보주 쪽으로 땅을 찍음)
	local FISTS_UP = merge(FIST_GUARD, { Shoulder_R = { 165, 0, -15 }, Elbow_R = { 20, 0, 0 }, Shoulder_L = { 165, 0, 15 }, Elbow_L = { 20, 0, 0 }, Waist = { 12, 0, 0 }, Neck = { 14, 0, 0 }, Wing_L1 = { 0, -25, 14 }, Wing_R1 = { 0, 25, -14 } })
	-- BOSS-NIGHT-2 2-7 · 3(근접 높이 규칙 §13 · 사용자: 높이 뜬 채 내리치니 앞으로 너무 쏠림 → 실제 싸움처럼): 2폼은 주먹을 칠 때 내려앉아 쭈그리며(다리 = 지면 위 약 1.8 stud)
	--   몸은 20°만 숙이고 사선 아래로 뻗는다 → 주먹 끝 = 지면 위 약 8 stud(FK) · 끝에서 지면까지 번개(impacts bolt) + 바닥 충격 원
	local SQUAT = { Hip_L = { 90, 0, -6 }, Knee_L = { -140, 0, 0 }, Ankle_L = { 56, 0, 0 }, Hip_R = { 40, 0, 6 }, Knee_R = { -120, 0, 0 }, Ankle_R = { 42, 0, 0 } }
	local KNEEL = { Hip_L = { 85, 0, -6 }, Knee_L = { -140, 0, 0 }, Ankle_L = { 65, 0, 0 }, Hip_R = { -10, 0, 6 }, Knee_R = { -100, 0, 0 }, Ankle_R = { 20, 0, 0 } } -- 앞무릎 세움 · 뒷무릎 꿇음(땅 치기 착지)
	local FISTS_DOWN = merge(FIST_GUARD, SQUAT, { Shoulder_R = { 32, 0, -8 }, Elbow_R = { 4, 0, 0 }, Shoulder_L = { 32, 0, 8 }, Elbow_L = { 4, 0, 0 }, Waist = { -16, 0, 0 }, Neck = { 12, 0, 0 }, RootJoint = { -14, 0, 0, 0, -1.2, 0 } })
	local PUNCH_R = merge(FIST_GUARD, { Waist = { -6, -30, 0 }, Shoulder_R = { 88, 0, -4 }, Elbow_R = { 4, 0, 0 }, Neck = { 0, 20, 0 } })
	local PUNCH_L = merge(FIST_GUARD, { Waist = { -6, 30, 0 }, Shoulder_L = { 88, 0, 4 }, Elbow_L = { 4, 0, 0 }, Neck = { 0, -20, 0 } })
	local WIND_R = merge(FIST_GUARD, { Waist = { 0, 34, 0 }, Shoulder_R = { 40, 0, -50 }, Elbow_R = { 110, 0, 0 }, Neck = { 0, -16, 0 } })
	local WIND_L = merge(FIST_GUARD, { Waist = { 0, -34, 0 }, Shoulder_L = { 40, 0, 50 }, Elbow_L = { 110, 0, 0 }, Neck = { 0, 16, 0 } })

	local C = {}
	-- ── 1폼(지팡이) ──
	-- 방전 고리 discharge · 천둥 고리 thunderRing: 지팡이를 높이 → 땅 찍기(천둥 = 3번)
	-- BOSS-NIGHT-2 2-4(사용자: 방전 때 앞치마는 가만 · 상체만 으쓱): 골반(RootJoint)도 같이 젖혔다 숙이고 로브 앞/뒤가 허리 동작을 따라 늦게 흔들림
	local function robe(f, b)
		return { RobeF = { f, 0, 0 }, RobeB = { b, 0, 0 } }
	end
	C.s_discharge = {
		pre = { { f = 0.45, ease = "inout", pose = merge(STAFF_UP, robe(-10, 8), { RootJoint = { -6, 0, 0, 0, 0.08, 0.05 } }) },
			{ f = 1.0, ease = "in", pose = merge(STAFF_UP, robe(-14, 12), { Shoulder_R = { 172, 0, -8 }, RootJoint = { -9, 0, 0, 0, 0.12, 0.07 } }) } },
		post = { { s = 0.08, ease = "in", pose = merge(STAFF_SLAM, robe(18, -6), { RootJoint = { 14, 0, 0, 0, -0.3, -0.05 } }) }, { s = 0.25, ease = "out", pose = merge(STAFF_SLAM, robe(26, -12), { Waist = { -20, 0, 0 }, RootJoint = { 16, 0, 0, 0, -0.32, -0.06 } }) },
			{ s = 0.55, ease = "inout", pose = merge(STAFF_SLAM, robe(8, -2), { Waist = { -22, 0, 0 } }) }, { s = 1.2, ease = "inout", pose = REST_POSE } },
		hitstop = 0.07, squash = 0.2,
	}
	local STAFF_REUP = merge(STAFF_UP, { Shoulder_R = { 135, 0, -14 }, Elbow_R = { 30, 0, 0 }, Waist = { 4, 0, 0 } })
	C.s_thunder = {
		pre = { { f = 0.5, ease = "inout", pose = STAFF_UP }, { f = 1.0, ease = "in", pose = merge(STAFF_UP, { Shoulder_R = { 172, 0, -8 } }) } },
		post = {
			{ s = 0.08, ease = "in", pose = STAFF_SLAM }, { s = 0.9, ease = "inout", pose = STAFF_REUP }, { s = 1.6, ease = "in", pose = STAFF_SLAM },
			{ s = 2.5, ease = "inout", pose = STAFF_REUP }, { s = 3.2, ease = "in", pose = STAFF_SLAM }, { s = 4.1, ease = "inout", pose = REST_POSE }, -- BOSS-NIGHT-2: 다시 드는 높이 낮춤(그립 반전으로 보주 호가 커져 급정지 = 튐)
		},
		hitstop = 0.07, squash = 0.2, extraStrikes = { post = { 1.6, 3.2 } }, endFade = 0.8, -- 스킬이 클립 중간에 끝나면 그립 반전 지팡이가 기본 자세로 천천히
	}
	-- BOSS-NIGHT-2 2b 지진파 찍기(사용자: 첫 지진파 뒤 점프만 해서 어색함 - 세트에 hopSlam이 없어 공통 맨손 점프가 덮었다) · forms.*.hop
	--   서버가 파동마다 몸을 든다(hop · hit = 착지 = 파동 시작) → 웅크림(예비) → 도약 → 착지 충격 순서로만. 판정 · 시간 그대로.
	--   1폼(사용자: 점프보다 지팡이로 내려찍기 - v3.hopHeight 0 = 몸을 들지 않음): 지팡이를 두 손으로 쥠 → 머리 위로 크게 들어 올림(발끝 · 몸 젖힘) → 두 손으로 땅에 내리꽂음(짧은 멈춤) → 회복
	local STAFF2_UP = merge(STAFF_UP, { Shoulder_L = { 160, 0, 18 }, Elbow_L = { 22, 0, 0 } })
	local STAFF2_SLAM = merge(STAFF_SLAM, crouch(0.45, 14), { Shoulder_L = { 58, 0, 16 }, Elbow_L = { 26, 0, 0 }, Waist = { -24, 0, 0 } })
	local HOP_TUCK = { Hip_L = { 30, 0, -6 }, Hip_R = { 30, 0, 6 }, Knee_L = { -55, 0, 0 }, Knee_R = { -55, 0, 0 }, Ankle_L = { 20, 0, 0 }, Ankle_R = { 20, 0, 0 } } -- 2폼 떠오를 때 다리 접기
	C.s_hop = {
		pre = {
			{ f = 0.3, ease = "inout", pose = merge(STAFF_HOLD, crouch(0.2, 6), { Shoulder_L = { 40, 0, -10 }, Elbow_L = { 70, 0, 0 }, Waist = { -8, 0, 0 } }) },
			{ f = 0.75, ease = "out", pose = merge(STAFF2_UP, { RootJoint = { 0, 0, 0, 0, 0.15, 0 } }) },
			{ f = 1.0, ease = "in", pose = merge(STAFF2_UP, { Shoulder_R = { 178, 0, -10 }, Shoulder_L = { 175, 0, 14 }, Waist = { 16, 0, 0 }, RootJoint = { 0, 0, 0, 0, 0.2, 0 } }) },
		},
		post = { { s = 0.06, ease = "in", pose = STAFF2_SLAM }, { s = 0.32, ease = "out", pose = merge(STAFF2_SLAM, { Waist = { -26, 0, 0 } }) }, { s = 1.0, ease = "inout", pose = REST_POSE } },
		hitstop = 0.1, squash = 0.2, endFade = 0.6,
	}
	--   2폼(떠 있음): 두 주먹을 머리 위로 모으며 떠오름 → 내려오며 착지해 두 주먹으로 땅을 찍음(앞무릎 · 뒷무릎) → 충격파 → 다시 떠오름(호버 자세로)
	local GROUND_FISTS = merge(FIST_GUARD, KNEEL, { RootJoint = { -40, 0, 0, 0, -1.6, 0 }, Waist = { -30, 0, 0 }, Shoulder_R = { 55, 0, -6 }, Elbow_R = { 4, 0, 0 }, Shoulder_L = { 55, 0, 6 }, Elbow_L = { 4, 0, 0 }, Neck = { 35, 0, 0 } })
	C.f_hop = {
		pre = {
			-- 파동 간격 1.6초 = 앞 찍기 착지 직후 다음 찍기가 시작된다(Studio 실측: 착지 자세가 0.1초 만에 튀어 오름) → 쭈그린 채 주먹을 거두며 밀고 떠오름(웅크림 예비 = 첫 찍기도 같음)
			{ f = 0.3, ease = "out", pose = merge(GROUND_FISTS, { RootJoint = { -20, 0, 0, 0, -1.3, 0 }, Waist = { -20, 0, 0 }, Shoulder_R = { 100, 0, -10 }, Elbow_R = { 60, 0, 0 }, Shoulder_L = { 100, 0, 10 }, Elbow_L = { 60, 0, 0 } }) },
			{ f = 0.62, ease = "out", pose = merge(FISTS_UP, HOP_TUCK) },
			{ f = 1.0, ease = "in", pose = merge(FISTS_UP, { Waist = { -10, 0, 0 }, Shoulder_R = { 150, 0, -10 }, Shoulder_L = { 150, 0, 10 }, RootJoint = { -12, 0, 0, 0, -0.6, 0 } }) },
		},
		post = { { s = 0.06, ease = "in", pose = GROUND_FISTS }, { s = 0.35, ease = "out", pose = merge(GROUND_FISTS, { Waist = { -32, 0, 0 } }) }, { s = 1.2, ease = "inout", pose = REST_POSE } },
		hitstop = 0.1, squash = 0.2, endFade = 0.6,
		airborne = { from = 0.1, to = 1.0 },
	}
	-- 회오리 whirl: 망토를 펼치고 한 바퀴 돈다(지팡이 수평)
	local WHIRL = merge(STAFF_HOLD, { Shoulder_R = { 85, 0, -70 }, Elbow_R = { 5, 0, 0 }, Wrist_R = { 0, 0, -80 }, Shoulder_L = { 80, 0, 70 }, Elbow_L = { 5, 0, 0 } }, cape(-35, 25))
	C.s_whirl = {
		pre = { { f = 0.35, ease = "inout", pose = WHIRL }, { f = 0.7, ease = "inout", pose = merge(WHIRL, { RootJoint = { 0, 180, 0 } }) }, { f = 1.0, ease = "out", pose = merge(WHIRL, { RootJoint = { 0, 359, 0 } }) } },
		post = { { s = 0.02, ease = "out", pose = WHIRL }, { s = 0.9, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05, extraStrikes = { pre = { 0.35, 0.7 } }, -- 한 바퀴 돌기(의도된 빠른 회전 - 망토 끝)
	}
	-- 낙뢰 strike(2번): 지팡이를 하늘로 → 아래로 겨눔(둘째 = 1.5초 뒤)
	local POINT = merge(STAFF_HOLD, { Shoulder_R = { 110, 0, -8 }, Elbow_R = { 0, 0, 0 }, Wrist_R = { 30, 0, 0 }, Neck = { -4, 0, 0 } })
	C.s_strike = {
		pre = { { f = 0.6, ease = "inout", pose = STAFF_UP }, { f = 1.0, ease = "in", pose = merge(STAFF_UP, { Shoulder_R = { 178, 0, -4 }, Neck = { 22, 0, 0 } }) } },
		post = { { s = 0.08, ease = "out", pose = POINT }, { s = 0.9, ease = "inout", pose = STAFF_UP }, { s = 1.5, ease = "out", pose = POINT }, { s = 2.4, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, extraStrikes = { post = { 0.9, 1.5 } },
	}
	-- 번개 조준경 rods(전멸기): 지팡이로 표적을 지목하고 버팀(떨림)
	C.s_rods = {
		pre = { { f = 1.0, ease = "inout", pose = POINT } },
		post = { { s = 0.15, ease = "out", pose = merge(POINT, { Waist = { 6, 0, 0 } }) } },
		loop = { period = 0.4, poses = { POINT, merge(POINT, { Shoulder_R = { 114, 0, -6 }, Waist = { 8, 4, 0 } }) } },
		tremble = { from = 0.2, amp = 2, joints = { "Shoulder_R" } },
	}
	-- 강화 평타 swipe: 지팡이를 뒤로 감아 → 가로로 크게 휘두름(지팡이 번쩍)
	-- BOSS-NIGHT-2 2-5 · 3(근접 높이 규칙 §13): 지팡이를 오른쪽 뒤 위로 감았다가 → 앞을 가로질러 왼쪽 아래로 비스듬히 쓸기(보주가 지면 ~ 플레이어 키 높이를 지나감)
	local SWING_UP = merge(STAFF_HOLD, crouch(0.1), { Waist = { 8, 40, 0 }, Shoulder_R = { 150, 0, -50 }, Elbow_R = { 30, 0, 0 }, Wrist_R = { -20, 0, 0 }, Neck = { 0, -20, 0 } }, GRIP_FLIP)
	local SWING_LOW = merge(STAFF_HOLD, crouch(0.3, 10), { Waist = { -35, -36, 0 }, Shoulder_R = { 40, 0, -50 }, Elbow_R = { 0, 0, 0 }, Wrist_R = { 0, 0, -30 }, Neck = { -8, 22, 0 } }, GRIP_FLIP, cape(10, 18)) -- 접촉: 보주 = 몸 앞 지면 위 약 4.6 stud(FK)
	C.s_swipe = {
		pre = { { f = 0.45, ease = "inout", pose = merge(SWING_UP, { Shoulder_R = { 140, 0, -45 } }) }, { f = 1.0, ease = "out", pose = SWING_UP } },
		post = { { s = 0.08, ease = "out", pose = SWING_LOW }, { s = 0.26, ease = "back", pose = merge(SWING_LOW, { Waist = { -36, -44, 0 }, Shoulder_R = { 36, 0, -44 } }) }, { s = 0.95, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, tremble = { from = 0.6, amp = 3, joints = { "Shoulder_R" } },
	}
	-- BOSS-NIGHT-2 2-6 검기 swordWave(1폼 원거리 반응 · 예비 0.5초 = 무기 번개 발광): 짧게 감았다가 같은 낮은 사선 쓸기로 초승달 칼날을 바닥으로 날림
	C.s_wave = {
		pre = { { f = 1.0, ease = "inout", pose = SWING_UP } },
		post = { { s = 0.07, ease = "out", pose = SWING_LOW }, { s = 0.25, ease = "back", pose = merge(SWING_LOW, { Waist = { -36, -46, 0 } }) }, { s = 0.9, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05,
	}
	-- 회오리 이동 tornado: 지팡이를 머리 위에서 돌려 → 앞으로 내밀어 보냄
	C.s_tornado = {
		pre = { { f = 0.35, ease = "inout", pose = merge(STAFF_UP, { Wrist_R = { 0, 0, 40 } }) }, { f = 0.7, ease = "inout", pose = merge(STAFF_UP, { Wrist_R = { 0, 0, -40 } }) }, { f = 1.0, ease = "inout", pose = merge(STAFF_UP, { Wrist_R = { 0, 0, 40 } }) } },
		post = { { s = 0.1, ease = "out", pose = POINT }, { s = 1.0, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05, extraStrikes = { pre = { 0.35, 0.7 } },
	}
	-- 뇌격 창 boltSpear(2발): 왼손에 번개 창 → 던짐 × 2
	local THROW_BACK = merge(STAFF_HOLD, { Waist = { 0, -24, 0 }, Shoulder_L = { 150, 0, 40 }, Elbow_L = { 70, 0, 0 }, Neck = { 0, 14, 0 } })
	local THROW_FWD = merge(STAFF_HOLD, { Waist = { -10, 26, 0 }, Shoulder_L = { 95, 0, -10 }, Elbow_L = { 4, 0, 0 }, Neck = { -4, -12, 0 } })
	C.s_bolt = {
		pre = { { f = 1.0, ease = "inout", pose = THROW_BACK } },
		post = { { s = 0.08, ease = "out", pose = THROW_FWD }, { s = 0.22, ease = "inout", pose = THROW_BACK }, { s = 0.38, ease = "out", pose = THROW_FWD }, { s = 1.1, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05, extraStrikes = { post = { 0.22, 0.38 } },
	}
	-- 번개 결계 mirror: 망토로 몸을 감싸며 웅크림(지팡이 앞에 세움)
	local WRAP = merge(crouch(0.2, 6), STAFF_HOLD, { Waist = { -14, 0, 0 }, Neck = { -18, 0, 0 }, Shoulder_L = { 60, 0, -20 }, Elbow_L = { 70, 0, 0 } }, cape(40, -30))
	C.s_mirror = {
		pre = { { f = 1.0, ease = "inout", pose = WRAP } },
		post = { { s = 0.1, ease = "out", pose = WRAP } },
		loop = { period = 0.7, poses = { WRAP, merge(WRAP, cape(46, -34)) } },
		hitstop = 0.05,
	}
	-- 원 안 낙뢰 innerSmash: 지팡이를 거꾸로 들어 발치에 내리꽂음
	C.s_inner = {
		pre = { { f = 0.5, ease = "inout", pose = merge(STAFF_HOLD, { Shoulder_R = { 140, 0, -10 }, Elbow_R = { 40, 0, 0 }, Wrist_R = { 110, 0, 0 } }) },
			{ f = 1.0, ease = "in", pose = merge(STAFF_HOLD, { Shoulder_R = { 158, 0, -6 }, Elbow_R = { 26, 0, 0 }, Wrist_R = { 120, 0, 0 }, Neck = { 12, 0, 0 } }) } },
		post = { { s = 0.07, ease = "in", pose = merge(crouch(0.35, 12), { Shoulder_R = { 40, 0, -10 }, Elbow_R = { 20, 0, 0 }, Wrist_R = { 120, 0, 0 }, Waist = { -26, 0, 0 } }) },
			{ s = 0.35, ease = "out", pose = merge(crouch(0.4, 14), { Shoulder_R = { 36, 0, -10 }, Wrist_R = { 120, 0, 0 }, Waist = { -30, 0, 0 } }) }, { s = 1.1, ease = "inout", pose = REST_POSE } },
		hitstop = 0.08, squash = 0.25,
	}
	-- ── 2폼(주먹 번개 · 떠서) ──
	C.f_discharge = {
		pre = { { f = 0.5, ease = "inout", pose = FISTS_UP }, { f = 1.0, ease = "in", pose = merge(FISTS_UP, { RootJoint = { -6, 0, 0, 0, 0.25, 0 } }) } },
		post = { { s = 0.08, ease = "in", pose = FISTS_DOWN }, { s = 0.45, ease = "out", pose = merge(FISTS_DOWN, { Waist = { -30, 0, 0 } }) }, { s = 1.2, ease = "inout", pose = REST_POSE } },
		hitstop = 0.07, squash = 0.2,
	}
	C.f_thunder = {
		pre = { { f = 1.0, ease = "in", pose = FISTS_UP } },
		post = {
			{ s = 0.08, ease = "in", pose = FISTS_DOWN }, { s = 0.9, ease = "inout", pose = FISTS_UP }, { s = 1.6, ease = "in", pose = FISTS_DOWN },
			{ s = 2.5, ease = "inout", pose = FISTS_UP }, { s = 3.2, ease = "in", pose = FISTS_DOWN }, { s = 4.1, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.07, extraStrikes = { post = { 1.6, 3.2 } },
	}
	local SPREAD = merge(FIST_GUARD, { Shoulder_R = { 80, 0, -80 }, Elbow_R = { 10, 0, 0 }, Shoulder_L = { 80, 0, 80 }, Elbow_L = { 10, 0, 0 }, Wing_L1 = { 0, -30, 20 }, Wing_R1 = { 0, 30, -20 }, Wing_L2 = { 0, -10, 10 }, Wing_R2 = { 0, 10, -10 } })
	C.f_whirl = {
		pre = { { f = 0.35, ease = "inout", pose = SPREAD }, { f = 0.7, ease = "inout", pose = merge(SPREAD, { RootJoint = { 0, 180, 0 } }) }, { f = 1.0, ease = "out", pose = merge(SPREAD, { RootJoint = { 0, 359, 0 } }) } },
		post = { { s = 0.02, ease = "out", pose = SPREAD }, { s = 0.9, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05, extraStrikes = { pre = { 0.35, 0.7 } },
	}
	local FIST_POINT = merge(FIST_GUARD, { Shoulder_R = { 100, 0, -6 }, Elbow_R = { 0, 0, 0 }, Neck = { -6, 0, 0 } })
	C.f_strike = {
		pre = { { f = 0.6, ease = "inout", pose = FISTS_UP }, { f = 1.0, ease = "in", pose = merge(FISTS_UP, { Neck = { 24, 0, 0 } }) } },
		post = { { s = 0.08, ease = "out", pose = FIST_POINT }, { s = 0.9, ease = "inout", pose = FISTS_UP }, { s = 1.5, ease = "out", pose = FIST_POINT }, { s = 2.4, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, extraStrikes = { post = { 0.9, 1.5 } },
	}
	C.f_rods = {
		pre = { { f = 1.0, ease = "inout", pose = FIST_POINT } },
		post = { { s = 0.15, ease = "out", pose = FIST_POINT } },
		loop = { period = 0.4, poses = { FIST_POINT, merge(FIST_POINT, { Shoulder_R = { 104, 0, -4 }, Waist = { 4, 4, 0 } }) } },
		tremble = { from = 0.2, amp = 2, joints = { "Shoulder_R" } },
	}
	-- BOSS-NIGHT-2 2-7 2폼 강화 평타 = 살짝 떠올라 오른 주먹을 뒤로 당겼다가 → 내려앉으며 체중을 실어 사선 아래로 "번개 주먹"(대상 지점 지면 강타 + 작은 충격 원)
	local FIST_HIGH_R = merge(FIST_GUARD, { RootJoint = { 4, 0, 0, 0, 0.75, 0 }, Waist = { 6, 30, 0 }, Shoulder_R = { 120, 0, -35 }, Elbow_R = { 100, 0, 0 }, Shoulder_L = { 50, 0, 20 }, Elbow_L = { 110, 0, 0 }, Neck = { 6, -18, 0 } })
	-- BOSS-NIGHT-2 2b(사용자: 주먹 8.6 ~ 9.5 stud = §13 위반 → 주먹 끝이 지면에): 앞무릎 세우고 뒷무릎 꿇어 내려앉으며 몸을 깊이 숙여 땅을 친다(FK 격자 탐색 - 주먹 박스 바닥 ≈ 0.7 stud · 다리 지면 −0.5 안)
	local DIVE_PUNCH_R = merge(FIST_GUARD, KNEEL, { RootJoint = { -55, 0, 0, 0, -1.9, 0 }, Waist = { -40, -24, 0 }, Shoulder_R = { 80, 0, -4 }, Elbow_R = { 4, 0, 0 }, Shoulder_L = { 45, 0, 18 }, Elbow_L = { 110, 0, 0 }, Neck = { 35, 22, 0 } })
	C.f_swipe = {
		pre = { { f = 0.45, ease = "inout", pose = merge(FIST_HIGH_R, { Shoulder_R = { 150, 0, -24 } }) }, { f = 1.0, ease = "out", pose = FIST_HIGH_R } },
		post = { { s = 0.08, ease = "in", pose = DIVE_PUNCH_R }, { s = 0.28, ease = "back", pose = merge(DIVE_PUNCH_R, { Waist = { -38, -22, 0 } }) }, { s = 1.0, ease = "inout", pose = REST_POSE } },
		hitstop = 0.07, squash = 0.12, tremble = { from = 0.6, amp = 3, joints = { "Shoulder_R", "Elbow_R" } },
		endFade = 0.7, -- Studio 실측: 동작이 접촉 + 0.1초에 끝나 내리꽂은 자세가 0.15초 만에 풀렸다 → 쭈그린 타격 자세를 천천히 푼다(보이기만)
	}
	-- 2폼 평타 = 좌/우 교대 작은 내리꽂기(forms.after.basicClips)
	local jabR = { post = { { s = 0.07, ease = "in", pose = merge(FIGHT, { RootJoint = { -8, 0, 0, 0, -0.35, 0 }, Waist = { -10, -22, 0 }, Shoulder_R = { 48, 0, -8 }, Elbow_R = { 6, 0, 0 } }) },
		{ s = 0.17, ease = "back", pose = merge(FIGHT, { RootJoint = { -9, 0, 0, 0, -0.38, 0 }, Waist = { -11, -24, 0 }, Shoulder_R = { 44, 0, -8 }, Elbow_R = { 8, 0, 0 } }) }, { s = 0.6, ease = "inout", pose = REST_POSE } }, hitstop = 0.05 }
	C.f_basic_R = jabR
	C.f_basic_L = { post = { { s = 0.07, ease = "in", pose = mirror(jabR.post[1].pose) }, { s = 0.17, ease = "back", pose = mirror(jabR.post[2].pose) }, { s = 0.6, ease = "inout", pose = REST_POSE } }, hitstop = 0.05 }
	local fprepR = merge(FIST_GUARD, { Waist = { 8, 18, 0 }, Shoulder_R = { 130, 0, -20 }, Elbow_R = { 80, 0, 0 } })
	-- BOSS-NIGHT-2 2-8 유도 전류 구슬 stormOrbs(2폼 원거리 반응): 두 팔을 넓게 벌려 주먹에 전류를 모았다가 → 앞으로 내밀어 구슬을 날림
	local ORB_CALL = merge(FIST_GUARD, { Shoulder_R = { 70, 0, -75 }, Elbow_R = { 30, 0, 0 }, Shoulder_L = { 70, 0, 75 }, Elbow_L = { 30, 0, 0 }, Waist = { 10, 0, 0 }, Neck = { 12, 0, 0 }, Wing_L1 = { 0, -25, 14 }, Wing_R1 = { 0, 25, -14 } })
	local ORB_PUSH = merge(FIST_GUARD, { Shoulder_R = { 95, 0, -12 }, Elbow_R = { 0, 0, 0 }, Shoulder_L = { 95, 0, 12 }, Elbow_L = { 0, 0, 0 }, Waist = { -10, 0, 0 } })
	C.f_orbs = {
		pre = { { f = 1.0, ease = "inout", pose = ORB_CALL } },
		post = { { s = 0.08, ease = "out", pose = ORB_PUSH }, { s = 0.3, ease = "back", pose = merge(ORB_PUSH, { Waist = { -12, 0, 0 } }) }, { s = 1.0, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05,
	}
	C.f_tornado = {
		pre = { { f = 0.35, ease = "inout", pose = WIND_R }, { f = 0.7, ease = "inout", pose = WIND_L }, { f = 1.0, ease = "inout", pose = WIND_R } },
		post = { { s = 0.1, ease = "out", pose = merge(FIST_GUARD, { Shoulder_R = { 90, 0, -10 }, Elbow_R = { 0, 0, 0 }, Shoulder_L = { 90, 0, 10 }, Elbow_L = { 0, 0, 0 } }) }, { s = 1.0, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05, extraStrikes = { pre = { 0.35, 0.7 } },
	}
	C.f_bolt = { -- 왼 · 오른 번갈아 번개 주먹(번개 창 2발)
		pre = { { f = 1.0, ease = "inout", pose = WIND_L } },
		post = { { s = 0.08, ease = "out", pose = PUNCH_L }, { s = 0.22, ease = "inout", pose = WIND_R }, { s = 0.38, ease = "out", pose = PUNCH_R }, { s = 1.1, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05, extraStrikes = { post = { 0.22, 0.38 } },
	}
	local WING_WRAP = merge(FIST_GUARD, { Shoulder_R = { 70, 0, 30 }, Elbow_R = { 100, 0, 0 }, Shoulder_L = { 70, 0, -30 }, Elbow_L = { 100, 0, 0 }, Waist = { -14, 0, 0 }, Neck = { -16, 0, 0 },
		Wing_L1 = { 0, 60, 0 }, Wing_R1 = { 0, -60, 0 }, Wing_L2 = { 0, 40, 0 }, Wing_R2 = { 0, -40, 0 } })
	C.f_mirror = {
		pre = { { f = 1.0, ease = "inout", pose = WING_WRAP } },
		post = { { s = 0.1, ease = "out", pose = WING_WRAP } },
		loop = { period = 0.7, poses = { WING_WRAP, merge(WING_WRAP, { Wing_L1 = { 0, 64, 0 }, Wing_R1 = { 0, -64, 0 } }) } },
		hitstop = 0.05,
	}
	C.f_inner = { -- 두 주먹 해머
		pre = { { f = 0.5, ease = "inout", pose = FISTS_UP }, { f = 1.0, ease = "in", pose = merge(FISTS_UP, { Shoulder_R = { 172, 0, 4 }, Shoulder_L = { 172, 0, -4 } }) } },
		post = { { s = 0.07, ease = "in", pose = FISTS_DOWN }, { s = 0.35, ease = "out", pose = merge(FISTS_DOWN, { Waist = { -34, 0, 0 } }) }, { s = 1.1, ease = "inout", pose = REST_POSE } },
		hitstop = 0.08, squash = 0.25,
	}
	-- 환경(돌풍 - 50% 뒤라 2폼): 두 팔 · 날개를 크게 펼쳐 바람을 일으킴
	C.f_env = {
		pre = { { f = 0.5, ease = "inout", pose = WING_WRAP }, { f = 1.0, ease = "out", pose = merge(SPREAD, { Wing_L1 = { 0, -40, 28 }, Wing_R1 = { 0, 40, -28 }, Neck = { 18, 0, 0 } }) } },
		post = { { s = 0.1, ease = "out", pose = merge(SPREAD, { Wing_L1 = { 0, -44, 30 }, Wing_R1 = { 0, 44, -30 } }) }, { s = 1.4, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06,
	}
	-- 잡기 흐름(바람 손 - 왼손으로 끌어올림)
	local GRAB_UP = merge(STAFF_HOLD, { Shoulder_L = { 150, 0, 30 }, Elbow_L = { 30, 0, 0 }, Neck = { 18, 0, 0 } }, cape(-15))
	C.grab_tele = {
		pre = { { f = 0.8, ease = "inout", pose = GRAB_UP }, { f = 1.0, ease = "inout", pose = merge(GRAB_UP, { Shoulder_L = { 156, 0, 34 } }) } },
		post = { { s = 0.15, ease = "out", pose = GRAB_UP } },
		tremble = { from = 0.75, amp = 2.5, joints = { "Shoulder_L" } },
	}
	local REACH = merge(STAFF_HOLD, { Shoulder_L = { 90, 0, 10 }, Elbow_L = { 4, 0, 0 }, Waist = { -10, 0, 0 } })
	C.grab_reach = { post = { { s = 0.15, ease = "out", pose = REACH } }, loop = { period = 0.32, poses = { REACH, merge(REACH, { Shoulder_L = { 94, 0, 14 } }) } }, upper = true }
	local HOLD = merge(STAFF_HOLD, { Shoulder_L = { 130, 0, 10 }, Elbow_L = { 20, 0, 0 }, Neck = { 14, 0, 0 } })
	C.grab_hold = { post = { { s = 0.25, ease = "out", pose = HOLD } }, loop = { period = 0.5, poses = { HOLD, merge(HOLD, { Shoulder_L = { 126, 0, 14 } }) } } }
	C.grab_snatch = { post = { { s = 0.06, ease = "out", pose = { Elbow_L = { 20, 0, 0 } } }, { s = 0.5, ease = "inout", pose = {} } }, hitstop = 0.05 }
	C.s_throw = {
		pre = { { f = 1.0, ease = "inout", pose = merge(STAFF_HOLD, { Shoulder_L = { 165, 0, 20 }, Elbow_L = { 50, 0, 0 }, Waist = { 14, -10, 0 } }) } },
		post = { { s = 0.08, ease = "out", pose = merge(STAFF_HOLD, { Shoulder_L = { 70, 0, -10 }, Elbow_L = { 4, 0, 0 }, Waist = { -20, 16, 0 } }) }, { s = 0.8, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06,
	}
	-- 포효(등장): 지팡이를 들어 올리며 고개를 젖힘
	local ROAR = merge(STAFF_UP, { Neck = { 24, 0, 0 }, Shoulder_L = { 60, 0, 60 }, Elbow_L = { 20, 0, 0 } }, cape(-20, 14))
	C.roar = { pre = { { f = 1.0, ease = "inout", pose = merge(crouch(0.2), STAFF_HOLD, { Neck = { -14, 0, 0 } }) } }, post = { { s = 0.15, ease = "out", pose = ROAR } },
		loop = { period = 0.18, poses = { ROAR, merge(ROAR, { Neck = { 26, 0, 2 } }) } } }
	-- 50% 변신: 지팡이 수평 → 망토가 펼쳐지며 떠오름 → (switchAt) 2폼 부품이 바깥에서 날아와 붙음 → 주먹 자세
	local LEVEL = merge(STAFF_HOLD, { Shoulder_R = { 90, 0, -40 }, Elbow_R = { 20, 0, 0 }, Wrist_R = { 0, 0, -75 }, Shoulder_L = { 80, 0, 50 }, Elbow_L = { 30, 0, 0 }, Neck = { 16, 0, 0 } }, cape(-60, 40))
	-- BOSS-NIGHT-2 2-2(사용자: 아이언맨처럼 · 붙기 전 감속 + 철컥 · 그동안 팔을 크게 벌려 맞이): 0.3초 웅크림 → 세트 교체(switchAt 0.3) → 팔을 크게 벌리고 가슴을 펴 버팀
	--   (부품 = 클라 BossFormFxView가 보스 뒤 70 stud · 위 25 stud에서 번개 꼬리를 달고 날려 transform.assemble 시각에 붙임 - 빠르게 오다 끝에서 감속) → 날개 펼침 → 번개 폭발 + 떠오름
	local WELCOME = merge(FIST_GUARD, { Shoulder_R = { 30, 0, 72 }, Elbow_R = { 18, 0, 0 }, Shoulder_L = { 30, 0, -72 }, Elbow_L = { 18, 0, 0 }, Waist = { 10, 0, 0 }, Neck = { 16, 0, 0 },
		RootJoint = { 6, 0, 0, 0, 0.35, 0 }, Wing_L1 = { 0, 70, 0 }, Wing_R1 = { 0, -70, 0 }, Wing_L2 = { 0, 50, 0 }, Wing_R2 = { 0, -50, 0 } }) -- 날개는 접힌 채(망토처럼) - 마지막에 펼침
	local WINGS_OPEN = merge(WELCOME, { RootJoint = { -4, 0, 0, 0, 1.0, 0 }, Neck = { 18, 0, 0 }, Wing_L1 = { 0, -30, 20 }, Wing_R1 = { 0, 30, -20 }, Wing_L2 = { 0, -12, 10 }, Wing_R2 = { 0, 12, -10 } })
	C.s_transform = {
		pre = { { f = 1.0, ease = "inout", pose = merge(crouch(0.3, 10), STAFF_HOLD, { Waist = { -20, 0, 0 }, Neck = { -12, 0, 0 } }) } },
		post = {
			{ s = 0.25, ease = "out", pose = WELCOME },
			{ s = 0.95, ease = "inout", pose = merge(WELCOME, { Waist = { 12, 0, 0 }, RootJoint = { 6, 0, 0, 0, 0.42, 0 } }) },
			{ s = 1.65, ease = "inout", pose = merge(WELCOME, { Waist = { 14, 0, 0 }, Neck = { 20, 0, 0 }, RootJoint = { 7, 0, 0, 0, 0.48, 0 } }) },
			{ s = 2.1, ease = "inout", pose = merge(WELCOME, { Neck = { 22, 0, 0 } }) },
			{ s = 2.35, ease = "inout", pose = merge(WELCOME, { Wing_L1 = { 0, 20, 8 }, Wing_R1 = { 0, -20, -8 }, Wing_L2 = { 0, 20, 4 }, Wing_R2 = { 0, -20, -4 }, RootJoint = { 2, 0, 0, 0, 0.7, 0 } }) },
			{ s = 2.6, ease = "inout", pose = WINGS_OPEN }, -- 망토 → 날개 펼침(두 단계) + 번개 폭발 + 떠오름(assemble.burst)
			{ s = 3.1, ease = "inout", pose = REST_POSE },
		},
		hitstop = 0.06, align = false,
	}
	-- 평타: 1폼 = 지팡이 짧게 찌르기 · 2폼 = 잽(번갈아)
	local basicR = { post = { { s = 0.07, ease = "out", pose = { Waist = { -6, -20, 0 }, Shoulder_R = { 70, 0, -10 }, Elbow_R = { 6, 0, 0 } } }, { s = 0.17, ease = "back", pose = { Waist = { -8, -24, 0 }, Shoulder_R = { 72, 0, -8 } } }, { s = 0.6, ease = "inout", pose = REST_POSE } }, hitstop = 0.04 }
	C.basic_R = basicR
	C.basic_L = { post = { { s = 0.07, ease = "out", pose = mirror(basicR.post[1].pose) }, { s = 0.17, ease = "back", pose = mirror(basicR.post[2].pose) }, { s = 0.6, ease = "inout", pose = REST_POSE } }, hitstop = 0.04 }
	local prepR = { Waist = { 4, 20, 0 }, Shoulder_R = { 50, 0, -40 }, Elbow_R = { 60, 0, 0 } }

	local SIT = merge(crouch(0.9, -6), { Waist = { 10, 0, 0 }, Neck = { -18, 0, 0 }, Shoulder_L = { -10, 0, 30 }, Shoulder_R = { -10, 0, -30 } })
	local STAGGER = merge(crouch(0.2), { Waist = { -12, 0, 12 }, Neck = { -14, 0, 14 }, RootJoint = { 0, 0, 10, 0.05, -0.2, 0 } })
	local planPatch = {
		introCrouch = merge(crouch(0.5, 10), STAFF_HOLD, { Waist = { -30, 0, 0 }, Neck = { -20, 0, 0 } }, cape(20)),
		introRoar = "roar",
		flinch = { seconds = 0.3, pose = { Waist = { 7, 0, 4 }, Neck = { 9, 0, 0 }, RootJoint = { 0, 0, 0, 0, 0, 0.06 } } },
		stun = { stagger = STAGGER, sit = SIT, staggerSeconds = 0.5, riseSeconds = 0.8, wobble = { hz = 0.9, neck = 12, waist = 5 }, eyes = { 0, 0, 0 } },
		death = {
			keys = {
				{ s = 0.3, ease = "out", pose = STAGGER },
				{ s = 0.8, ease = "inout", pose = merge(STAGGER, { Waist = { -10, 0, -12 }, RootJoint = { 0, 0, -10, -0.05, -0.3, 0 } }) },
				{ s = 1.3, ease = "in", pose = SIT },
				{ s = 1.6, ease = "out", pose = merge(SIT, { Waist = { -24, 0, 0 }, Neck = { -30, 0, 0 } }) },
			},
			hitstopAt = 1.3, fadeFrom = 2.0, fadeSeconds = 0.5, scatterFrom = 1.75, eyes = { 0, 0, 0 }, stars = true, slowSeconds = 0.8, slowRate = 0.4,
		},
		basicPrep = { R = prepR, L = mirror(prepR) },
	}

	local SK1 = { discharge = "s_discharge", whirl = "s_whirl", strike = "s_strike", rods = "s_rods", swipe = "s_swipe", grab = "@grab", tornado = "s_tornado", thunderRing = "s_thunder",
		boltSpear = "s_bolt", mirror = "s_mirror", innerSmash = "s_inner", swordWave = "s_wave", stormOrbs = "f_orbs" }
	local SK2 = { discharge = "f_discharge", whirl = "f_whirl", strike = "f_strike", rods = "f_rods", swipe = "f_swipe", grab = "@grab", tornado = "f_tornado", thunderRing = "f_thunder",
		boltSpear = "f_bolt", mirror = "f_mirror", innerSmash = "f_inner", swordWave = "s_wave", stormOrbs = "f_orbs" }
	local MOTIONS1 = { idle = "gait", walk = "gait", intro = "plan:introCrouch", death = "plan:death", env = "f_env", flinch = "plan:flinch", stun = "plan:stun" }
	local FORM1_PARTS = { "Crown", "ChestCore", "Pauldron2_L", "Pauldron2_R", "Gauntlet_L", "Gauntlet_R", "Wing_L1", "Wing_L2", "Wing_R1", "Wing_R2" } -- 1폼에서 숨김
	local FORM2_PARTS = { "Plume", "LeftPauldron", "RightPauldron", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R", "Staff", "StaffOrb" } -- 2폼에서 숨김
	for _, t in ipairs({ "A", "B", "C", "D" }) do
		for i = 1, 4 do
			table.insert(FORM2_PARTS, "Cape" .. t .. i)
		end
	end
	local FISTS = { "Gauntlet_R", "Gauntlet_L" }
	D.storm_lord_v2 = {
		plan = "biped",
		planPatch = planPatch,
		stunStars = true,
		forms = {
			before = {
				gait = "biped", stance = STAFF_HOLD, guard = STAFF_HOLD,
				walk = { stride = 0.55, knee = 30, arm = 10, bob = 0.05, lean = 5, twist = 5, turnLean = 6, runAt = 1.6 },
				motions = MOTIONS1, skills = SK1, env = "f_env", throw = "s_throw", hop = "s_hop",
			},
			after = {
				gait = "hover", stance = FIST_GUARD, guard = FIGHT, hover = { height = 0.55, bob = 0.1, period = 1.4 },
				walk = { stride = 0.55, knee = 20, arm = 6, bob = 0.03, lean = 10 },
				motions = MOTIONS1, skills = SK2, env = "f_env", throw = "s_throw", hop = "f_hop",
				-- 2폼 때리는 부위 = 건틀릿 주먹(지팡이 숨김)
				flash = { discharge = FISTS, whirl = { "Wing_L2", "Wing_R2" }, strike = { "Gauntlet_R" }, rods = { "Gauntlet_R" }, swipe = { "Gauntlet_R" }, grab = { "Gauntlet_L" },
					tornado = FISTS, thunderRing = FISTS, boltSpear = FISTS, mirror = { "Wing_L1", "Wing_R1" }, innerSmash = FISTS },
				basicParts = { R = "Gauntlet_R", L = "Gauntlet_L" },
				basicClips = { R = "f_basic_R", L = "f_basic_L" }, basicPrep = { R = fprepR, L = mirror(fprepR) }, -- BOSS-NIGHT-2 2-7: 좌/우 교대 내리꽂는 주먹
			},
		},
		formParts = { before = FORM1_PARTS, after = FORM2_PARTS },
		-- BOSS-NIGHT-2 2: 후광 at z 6.5 → −6.5(보이는 머리 부위의 +Z = 얼굴 쪽이라 고리가 얼굴 앞에 노란 막대로 보였다 - Studio 변신 촬영)
		-- 2폼 후광(머리 뒤 고리 2개 반대 회전) · 허리 파편 · 구름 보주 3개(두 폼 - 공전) - 단위 stud(BossFormFxView)
		formFx = {
			halo = { form = "after", part = "Head", at = { 0, 2.0, -6.5 }, radius = { 5.5, 7.0 }, count = 10, thickness = 0.45, colors = { Color3.fromRGB(255, 225, 90), Color3.fromRGB(90, 210, 255) }, speeds = { 1.4, -1.0 } },
			shards = { form = "after", part = "Hips", radius = 6.5, count = 6, size = Vector3.new(0.7, 1.8, 0.7), color = Color3.fromRGB(90, 210, 255), speed = 0.9 },
			orbs = { slot = "StormOrb", count = 3, radius = 19, height = { before = 12, after = 16 }, size = 3.6, speed = 0.45, bob = 1.0 },
		},
		-- BOSS-NIGHT-2 2-2: hit = 웅크림 끝(0.3) · switchAt = 그 순간 2폼 세트(부품은 날아오는 동안 BossFormFxView가 숨김 → assemble 시각에 붙음 - 1폼 부품은 짝이 붙을 때 사라짐)
		--   assemble(초 = 변신 시작부터): 건틀릿 L → R → 어깨 L/R → 가슴 코어 → 왕관 → 날개(망토 4갈래 → 날개) · 비행 flySeconds(빠르게 → 끝에서 감속 easeOut) · 붙을 때 흰 번쩍 0.1 + 철컥 + 작은 흔들림
		transform = { clip = "s_transform", hit = 0.3, switchAt = 0.3, seconds = 3.4,
			assemble = {
				fromStuds = 70, upStuds = 25, flySeconds = 0.55, flashSeconds = 0.1, sound = "protect_ticket", shake = 0.25, trailColor = Color3.fromRGB(255, 230, 90),
				dropAt = 0.3, drop = { "Staff", "StaffOrb" }, -- 지팡이 = 웅크림 끝에 번개로 흩어짐
				steps = {
					{ at = 0.95, parts = { "Gauntlet_L" }, hide = { "Forearm_L", "Hand_L" } },
					{ at = 1.3, parts = { "Gauntlet_R" }, hide = { "Forearm_R", "Hand_R" } },
					{ at = 1.65, parts = { "Pauldron2_L", "Pauldron2_R" }, hide = { "LeftPauldron", "RightPauldron" } },
					{ at = 2.0, parts = { "ChestCore" } },
					{ at = 2.35, parts = { "Crown" }, hide = { "Plume" } },
					{ at = 2.65, wings = true, hide = "cape" }, -- 날개는 몸에서 펼침(날아오지 않음) · 망토 4갈래 사라짐
				},
				burst = 2.85, -- 번개 폭발(떠오름 = 클립)
			} },
		intro = { style = "rise", depth = 1.6, riseFrac = 0.44, riseEase = "out" },
		signature = { "discharge", "strike", "whirl", "thunderRing", "boltSpear", "tornado", "swipe", "innerSmash", "rods", "mirror" },
		flash = {
			discharge = { "Staff" }, whirl = { "Staff" }, strike = { "StaffOrb" }, rods = { "StaffOrb" }, swipe = { "Staff" }, grab = { "Hand_L" }, tornado = { "StaffOrb" }, thunderRing = { "Staff" },
			boltSpear = { "Hand_L" }, mirror = { "CapeB1", "CapeC1" }, innerSmash = { "Staff" },
		},
		impacts = {
			s_discharge = { kind = "ground", parts = { "Staff" }, size = 0.9, shake = 0.8 }, s_thunder = { kind = "ground", parts = { "Staff" }, size = 0.9, shake = 0.8 },
			s_whirl = { kind = "whoosh", parts = { "Staff" }, size = 1.2 }, s_strike = { kind = "spark", parts = { "StaffOrb" }, size = 1.0 }, s_rods = { kind = "spark", parts = { "StaffOrb" }, size = 0.8 },
			s_swipe = { kind = "whoosh", parts = { "Staff" }, size = 1.1 }, s_tornado = { kind = "whoosh", parts = { "StaffOrb" }, size = 1.0 }, s_bolt = { kind = "spark", parts = { "Hand_L" }, size = 0.9 },
			s_mirror = { kind = "spark", parts = { "Body" }, size = 1.0 }, s_inner = { kind = "ground", parts = { "Staff" }, size = 0.28, shake = 1.0, heavy = true },
			f_discharge = { kind = "ground", parts = FISTS, size = 1.0, shake = 0.8, bolt = true }, f_thunder = { kind = "ground", parts = FISTS, size = 1.0, shake = 0.8, bolt = true },
			f_whirl = { kind = "whoosh", parts = { "Wing_L2", "Wing_R2" }, size = 1.3 }, f_strike = { kind = "spark", parts = { "Gauntlet_R" }, size = 1.0 }, f_rods = { kind = "spark", parts = { "Gauntlet_R" }, size = 0.8 },
			f_swipe = { kind = "ground", parts = { "Gauntlet_R" }, size = 0.7, shake = 0.5, bolt = true }, f_tornado = { kind = "whoosh", parts = FISTS, size = 1.0 }, f_bolt = { kind = "spark", parts = FISTS, size = 0.9 },
			f_mirror = { kind = "spark", parts = { "Wing_L1", "Wing_R1" }, size = 1.0 }, f_inner = { kind = "ground", parts = FISTS, size = 0.28, shake = 1.0, heavy = true, bolt = true },
			f_env = { kind = "roar", parts = { "Body" }, size = 1.3, shake = 0.9 }, s_throw = { kind = "whoosh", parts = { "Hand_L" }, size = 1.0 },
			s_transform = { kind = "roar", parts = { "Body" }, size = 1.3, shake = 0.9 }, roar = { kind = "roar", parts = { "Head" }, size = 1.0, shake = 0.7 },
			basic_R = { kind = "whoosh", parts = { "Hand_R" }, size = 0.55 }, basic_L = { kind = "whoosh", parts = { "Hand_L" }, size = 0.55 },
			s_wave = { kind = "whoosh", parts = { "StaffOrb" }, size = 1.2, floorDust = true }, f_orbs = { kind = "spark", parts = FISTS, size = 1.0 },
			s_hop = { kind = "ground", parts = { "Staff" }, size = 1.0, shake = 1.0, heavy = true }, f_hop = { kind = "ground", parts = FISTS, size = 1.0, shake = 1.0, heavy = true, bolt = true },
		},
		clips = C,
	}
end


-- ═══════════════════════════ 심해 군주 v2 — 나가(BOSS-NIGHT-1 3 · Meshy 몸 + 삼지창 · 바이블 §2-3) ═══════════════════════════
-- 리그 = BossRigV2Data abyssal_lord_v2(상체 A-포즈 · 꼬리 12마디가 바닥에 감김 · 삼지창 = 오른손 자식). 보행 = 뱀(꼬리 S자 파동 - BossMotion baseSerpent · 꼬리 마디 ry).
--   꼬리 마디 각: ry = 옆으로 휨(파동과 같은 축) · rx = 위아래. 변신(50% 판 털기 전) = 꼬리를 들어 올리며 포효 → 분노 세트(상체 숙임 · 꼬리 높게).
do
	local REST_POSE = {}
	local function tail(ry, rx, from, to)
		local p = {}
		for i = from or 1, to or 12 do
			p["Tail" .. i] = { rx or 0, ry, 0 }
		end
		return p
	end
	local HOLD = { Shoulder_R = { 26, 0, -20 }, Elbow_R = { 48, 0, 0 }, Wrist_R = { -60, 0, 0 }, Shoulder_L = { 10, 0, 22 }, Elbow_L = { 20, 0, 0 } } -- 삼지창을 세워 쥠
	local ANGRY = merge(HOLD, { Waist = { -10, 0, 0 }, Neck = { 6, 0, 0 }, Crest = { -12, 0, 0 } }, tail(0, -6, 10, 12))
	local TRI_UP = merge(HOLD, { Shoulder_R = { 165, 0, -10 }, Elbow_R = { 10, 0, 0 }, Wrist_R = { -10, 0, 0 }, Waist = { 10, 0, 0 }, Neck = { 14, 0, 0 } })
	local TRI_POINT = merge(HOLD, { Shoulder_R = { 95, 0, -6 }, Elbow_R = { 0, 0, 0 }, Wrist_R = { 70, 0, 0 }, Waist = { -6, 0, 0 } }) -- 창끝을 대상 쪽으로
	local RISE = { RootJoint = { -6, 0, 0, 0, 0.4, 0 }, Tail1 = { -20, 0, 0 }, Tail2 = { -14, 0, 0 } } -- 꼬리로 서서 높아짐
	local C = {}
	-- 꼬리 휩쓸기 sweep(도넛 안 9 · 밖 24): 몸을 감고(꼬리 오른쪽으로 감음) → 몸을 한 바퀴 돌리며 꼬리로 휩쓸기
	C.n_sweep = {
		pre = { { f = 0.5, ease = "inout", pose = merge(HOLD, { Waist = { -10, 30, 0 } }, tail(14)) }, { f = 1.0, ease = "in", pose = merge(HOLD, { Waist = { -12, 40, 0 } }, tail(20)) } },
		post = { { s = 0.08, ease = "out", pose = merge(HOLD, { Waist = { -10, -50, 0 } }, tail(-24)) }, { s = 0.35, ease = "out", pose = merge(HOLD, { Waist = { -8, -60, 0 } }, tail(-28)) },
			{ s = 0.6, ease = "inout", pose = merge(HOLD, { Waist = { -6, -30, 0 } }, tail(-10)) }, { s = 1.3, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, extraStrikes = { post = { 0.35, 0.6 } },
	}
	-- 해일 tide(고리 3번 - 1.5초 간격): 꼬리로 높이 서서 삼지창 자루로 수면 내리침 × 3
	local SLAM = merge(HOLD, { RootJoint = { 10, 0, 0, 0, -0.1, 0 }, Waist = { -24, 0, 0 }, Shoulder_R = { 60, 0, -10 }, Elbow_R = { 20, 0, 0 }, Wrist_R = { -40, 0, 0 } })
	C.n_tide = {
		pre = { { f = 0.5, ease = "inout", pose = merge(TRI_UP, RISE) }, { f = 1.0, ease = "in", pose = merge(TRI_UP, RISE, { Shoulder_R = { 172, 0, -6 } }) } },
		post = { { s = 0.08, ease = "in", pose = SLAM }, { s = 0.8, ease = "inout", pose = merge(TRI_UP, RISE) }, { s = 1.5, ease = "in", pose = SLAM },
			{ s = 2.3, ease = "inout", pose = merge(TRI_UP, RISE) }, { s = 3.0, ease = "in", pose = SLAM }, { s = 3.8, ease = "inout", pose = REST_POSE } },
		hitstop = 0.07, squash = 0.2, extraStrikes = { post = { 1.5, 3.0 } },
	}
	-- BOSS-NIGHT-2 3 해일 찍기(설계 검수: 공통 사람형 점프 클립 + 서버 4 stud 들기 = 뱀 몸이 이유 없이 떠오름 → v3.hopHeight 0 + 전용) · forms.*.hop
	--   꼬리로 몸을 세우며 삼지창을 두 손으로 머리 위로 → 내려꽂기(짧은 멈춤) → 회복. 판정 · 파동 시각 그대로.
	-- 손목 = FK 격자(삼지창 쥔 방향 때문에 TRI_UP · SLAM 그대로면 들 때 창끝이 아래 · 꽂을 때 위였다): 들기 창끝 위 34.6 stud · 꽂기 창끝 지면 1.2 stud
	local TRI_UP2 = merge(TRI_UP, RISE, { Shoulder_L = { 160, 0, 14 }, Elbow_L = { 20, 0, 0 }, Wrist_R = { -130, 0, 45 } })
	local SLAM2 = merge(SLAM, { Shoulder_L = { 62, 0, 10 }, Elbow_L = { 26, 0, 0 }, Waist = { -30, 0, 0 }, Wrist_R = { 80, 0, 0 } })
	C.n_hop = {
		pre = {
			{ f = 0.35, ease = "out", pose = TRI_UP2 },
			{ f = 1.0, ease = "in", pose = merge(TRI_UP2, { Shoulder_R = { 175, 0, -6 }, Shoulder_L = { 172, 0, 10 }, Waist = { 12, 0, 0 } }) },
		},
		post = { { s = 0.06, ease = "in", pose = SLAM2 }, { s = 0.3, ease = "out", pose = merge(SLAM2, { Waist = { -32, 0, 0 } }) }, { s = 0.9, ease = "inout", pose = REST_POSE } },
		hitstop = 0.1, squash = 0.2, endFade = 0.5,
	}
	-- 물기둥 spout(5번 차례로): 삼지창으로 대상을 겨눔(겨눌 때마다 찌름)
	C.n_spout = {
		pre = { { f = 1.0, ease = "inout", pose = TRI_POINT } },
		post = { { s = 0.08, ease = "out", pose = merge(TRI_POINT, { Shoulder_R = { 100, 0, -6 } }) }, { s = 0.55, ease = "inout", pose = TRI_POINT }, { s = 1.05, ease = "out", pose = merge(TRI_POINT, { Shoulder_R = { 102, 0, -2 } }) },
			{ s = 1.6, ease = "inout", pose = TRI_POINT }, { s = 2.1, ease = "out", pose = merge(TRI_POINT, { Shoulder_R = { 100, 0, -8 } }) }, { s = 3.0, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05, extraStrikes = { post = { 1.05, 2.1 } },
	}
	-- 색 맞추기 colors(전멸기): 삼지창을 높이 들고 버팀(머리 위 표시)
	C.n_colors = { pre = { { f = 1.0, ease = "inout", pose = merge(TRI_UP, RISE) } }, post = { { s = 0.2, ease = "out", pose = merge(TRI_UP, RISE) } },
		loop = { period = 1.2, poses = { merge(TRI_UP, RISE), merge(TRI_UP, RISE, { RootJoint = { -6, 0, 0, 0, 0.45, 0 } }) } } }
	-- 강화 평타 swipe: 삼지창 가로 베기(창날 번쩍)
	C.n_swipe = {
		pre = { { f = 0.45, ease = "inout", pose = merge(HOLD, { Waist = { 0, 36, 0 }, Shoulder_R = { 75, 0, -70 }, Elbow_R = { 30, 0, 0 }, Wrist_R = { 0, 0, -70 } }) },
			{ f = 1.0, ease = "out", pose = merge(HOLD, { Waist = { 0, 44, 0 }, Shoulder_R = { 78, 0, -78 }, Elbow_R = { 34, 0, 0 }, Wrist_R = { 0, 0, -75 } }) } },
		post = { { s = 0.08, ease = "out", pose = merge(HOLD, { Waist = { 0, -40, 0 }, Shoulder_R = { 85, 0, 30 }, Elbow_R = { 8, 0, 0 }, Wrist_R = { 0, 0, -75 } }) },
			{ s = 0.26, ease = "back", pose = merge(HOLD, { Waist = { 0, -46, 0 }, Shoulder_R = { 85, 0, 38 }, Wrist_R = { 0, 0, -75 } }) }, { s = 0.95, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, tremble = { from = 0.6, amp = 3, joints = { "Shoulder_R" } },
	}
	-- 꼬리 감기 grab: 꼬리 끝을 높이 쳐들어 경고 → 꼬리로 감아 들고 → 던짐
	local TAIL_UP = merge(HOLD, tail(0, -22, 8, 12))
	C.grab_tele = { pre = { { f = 0.8, ease = "inout", pose = TAIL_UP }, { f = 1.0, ease = "inout", pose = merge(TAIL_UP, tail(0, -26, 9, 12)) } }, post = { { s = 0.15, ease = "out", pose = TAIL_UP } },
		tremble = { from = 0.75, amp = 2.5, joints = { "Tail10", "Tail11" } } }
	local REACH = merge(HOLD, tail(-12, -10, 6, 12))
	C.grab_reach = { post = { { s = 0.15, ease = "out", pose = REACH } }, loop = { period = 0.32, poses = { REACH, merge(REACH, tail(-16, -12, 6, 12)) } }, upper = true }
	local COIL = merge(HOLD, tail(18, -24, 8, 12))
	C.grab_hold = { post = { { s = 0.25, ease = "out", pose = COIL } }, loop = { period = 0.5, poses = { COIL, merge(COIL, tail(22, -26, 8, 12)) } } }
	C.grab_snatch = { post = { { s = 0.06, ease = "out", pose = tail(8, -6, 9, 12) }, { s = 0.5, ease = "inout", pose = {} } }, hitstop = 0.05 }
	C.n_throw = { pre = { { f = 1.0, ease = "inout", pose = merge(HOLD, tail(26, -28, 7, 12)) } },
		post = { { s = 0.1, ease = "out", pose = merge(HOLD, tail(-28, -10, 7, 12)) }, { s = 0.9, ease = "inout", pose = REST_POSE } }, hitstop = 0.06 }
	-- 물의 장막 mirror: 두 팔로 물을 감아 소용돌이 장막(삼지창 세움 · 꼬리 몸 둘레)
	local CURTAIN = merge(HOLD, { Shoulder_L = { 110, 0, 40 }, Elbow_L = { 60, 0, 0 }, Waist = { -6, 0, 0 } }, tail(10))
	C.n_mirror = { pre = { { f = 1.0, ease = "inout", pose = CURTAIN } }, post = { { s = 0.1, ease = "out", pose = CURTAIN } },
		loop = { period = 0.7, poses = { CURTAIN, merge(CURTAIN, { Shoulder_L = { 120, 0, 30 } }, tail(14)) } }, hitstop = 0.05 }
	-- 꼬리 반원 tailSweep(180° - 보이는 몸이 대상 반대로 돌아 꼬리가 대상 쪽 · BossMotionData.tailToTarget): 꼬리를 감았다가 반원으로 휘두름(꼬리 끝 번쩍)
	C.n_tailsweep = {
		pre = { { f = 0.5, ease = "inout", pose = merge(HOLD, tail(16, -8)) }, { f = 1.0, ease = "in", pose = merge(HOLD, tail(24, -10)) } },
		post = { { s = 0.08, ease = "out", pose = merge(HOLD, tail(-22, -6)) }, { s = 0.3, ease = "back", pose = merge(HOLD, tail(-26, -4)) }, { s = 1.0, ease = "inout", pose = REST_POSE } },
		hitstop = 0.07, squash = 0.15,
	}
	-- 소용돌이 vortex(끌림 5.3초): 꼬리로 나선을 그리며 몸을 흔듦(삼지창 돌림)
	local SPIN_A = merge(TRI_UP, { Waist = { 0, 40, 0 } }, tail(20))
	local SPIN_B = merge(TRI_UP, { Waist = { 0, -40, 0 } }, tail(-20))
	C.n_vortex = { pre = { { f = 0.3, ease = "inout", pose = SPIN_A }, { f = 0.6, ease = "inout", pose = SPIN_B }, { f = 1.0, ease = "inout", pose = SPIN_A } },
		post = { { s = 0.1, ease = "out", pose = merge(SLAM, tail(-10)) }, { s = 1.0, ease = "inout", pose = REST_POSE } }, hitstop = 0.06, extraStrikes = { pre = { 0.3, 0.6 } } }
	-- 거품탄 bubbles: 고개를 들고 입으로 거품(왼손을 입 앞에)
	C.n_bubbles = { pre = { { f = 1.0, ease = "inout", pose = merge(HOLD, { Neck = { 18, 0, 0 }, Shoulder_L = { 110, 0, -10 }, Elbow_L = { 90, 0, 0 } }) } },
		post = { { s = 0.08, ease = "out", pose = merge(HOLD, { Neck = { 8, 0, 0 }, Waist = { -10, 0, 0 } }) }, { s = 0.9, ease = "inout", pose = REST_POSE } }, hitstop = 0.05 }
	-- 삼지창 던지기 tridentThrow(전용 - 옛 기본 돌진 클립 고침): 삼지창을 어깨 뒤로 → 던짐(창은 그림이 따로 날아갔다 돌아옴)
	C.n_trident = {
		pre = { { f = 1.0, ease = "inout", pose = merge(HOLD, { Waist = { 8, -26, 0 }, Shoulder_R = { 160, 0, -30 }, Elbow_R = { 80, 0, 0 }, Wrist_R = { 0, 0, 0 }, Neck = { 0, 16, 0 } }) } },
		post = { { s = 0.08, ease = "out", pose = merge(HOLD, { Waist = { -12, 26, 0 }, Shoulder_R = { 90, 0, -6 }, Elbow_R = { 4, 0, 0 }, Wrist_R = { 30, 0, 0 } }) },
			{ s = 0.6, ease = "inout", pose = merge(HOLD, { Shoulder_R = { 80, 0, -20 }, Elbow_R = { 40, 0, 0 } }) }, { s = 1.3, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06,
	}
	-- 환경(판 털기 50% 뒤): 꼬리로 높이 서서 꼬리 끝을 휘감아 올림 → 내리침
	C.n_env = { pre = { { f = 0.5, ease = "inout", pose = merge(TRI_UP, RISE, tail(0, -20, 8, 12)) }, { f = 1.0, ease = "in", pose = merge(TRI_UP, RISE, tail(0, -30, 8, 12)) } },
		post = { { s = 0.08, ease = "in", pose = merge(SLAM, tail(0, 10, 8, 12)) }, { s = 1.3, ease = "inout", pose = REST_POSE } }, hitstop = 0.08, squash = 0.25 }
	-- 50% 변신(겉모습 격노): 꼬리로 높이 서며 삼지창을 들어 포효 → 분노 세트
	local ROAR = merge(TRI_UP, RISE, { Neck = { 24, 0, 0 }, Shoulder_L = { 60, 0, 60 }, Elbow_L = { 20, 0, 0 } })
	C.n_transform = { pre = { { f = 1.0, ease = "inout", pose = ROAR } },
		post = { { s = 0.0, ease = "out", pose = ROAR }, { s = 0.6, ease = "inout", pose = merge(ROAR, { Neck = { 26, 0, 3 } }) }, { s = 1.6, ease = "inout", pose = ANGRY } }, hitstop = 0.06, align = false }
	C.roar = { pre = { { f = 1.0, ease = "inout", pose = merge(HOLD, { Neck = { -14, 0, 0 }, Waist = { -14, 0, 0 } }) } }, post = { { s = 0.15, ease = "out", pose = ROAR } },
		loop = { period = 0.18, poses = { ROAR, merge(ROAR, { Neck = { 26, 0, 2 } }) } } }
	local basicR = { post = { { s = 0.07, ease = "out", pose = { Waist = { -6, -20, 0 }, Shoulder_R = { 75, 0, -10 }, Elbow_R = { 6, 0, 0 }, Wrist_R = { 60, 0, 0 } } },
		{ s = 0.17, ease = "back", pose = { Waist = { -8, -24, 0 }, Shoulder_R = { 78, 0, -8 }, Wrist_R = { 60, 0, 0 } } }, { s = 0.6, ease = "inout", pose = REST_POSE } }, hitstop = 0.04 }
	C.basic_R = basicR
	C.basic_L = { post = { { s = 0.07, ease = "out", pose = mirror(basicR.post[1].pose) }, { s = 0.17, ease = "back", pose = mirror(basicR.post[2].pose) }, { s = 0.6, ease = "inout", pose = REST_POSE } }, hitstop = 0.04 }
	local prepR = { Waist = { 4, 20, 0 }, Shoulder_R = { 50, 0, -40 }, Elbow_R = { 60, 0, 0 } }
	local SLUMP = merge(HOLD, { RootJoint = { 6, 0, 0, 0, -0.35, 0 }, Waist = { -20, 0, 0 }, Neck = { -20, 0, 0 }, Shoulder_L = { -10, 0, 30 } })
	local STAGGER = merge(HOLD, { Waist = { -12, 0, 12 }, Neck = { -14, 0, 14 }, RootJoint = { 0, 0, 10, 0.05, -0.1, 0 } }, tail(6))
	local planPatch = {
		introCrouch = merge(HOLD, { RootJoint = { 0, 0, 0, 0, -0.5, 0 }, Waist = { -30, 0, 0 }, Neck = { -24, 0, 0 } }),
		introRoar = "roar",
		flinch = { seconds = 0.3, pose = { Waist = { 7, 0, 4 }, Neck = { 9, 0, 0 }, RootJoint = { 0, 0, 0, 0, 0, 0.06 } } },
		stun = { stagger = STAGGER, sit = SLUMP, staggerSeconds = 0.5, riseSeconds = 0.8, wobble = { hz = 0.9, neck = 12, waist = 5 }, eyes = { 0, 0, 0 } },
		death = {
			keys = { { s = 0.3, ease = "out", pose = STAGGER }, { s = 0.8, ease = "inout", pose = merge(STAGGER, { Waist = { -10, 0, -12 } }) }, { s = 1.3, ease = "in", pose = SLUMP },
				{ s = 1.6, ease = "out", pose = merge(SLUMP, { Waist = { -30, 0, 0 }, Neck = { -30, 0, 0 } }) } },
			hitstopAt = 1.3, fadeFrom = 2.0, fadeSeconds = 0.5, scatterFrom = 1.75, eyes = { 0, 0, 0 }, stars = true, slowSeconds = 0.8, slowRate = 0.4,
		},
		basicPrep = { R = prepR, L = mirror(prepR) },
	}
	local SK = { sweep = "n_sweep", tide = "n_tide", spout = "n_spout", colors = "n_colors", swipe = "n_swipe", grab = "@grab", tailSweep = "n_tailsweep", vortex = "n_vortex",
		bubbles = "n_bubbles", mirror = "n_mirror", tridentThrow = "n_trident" }
	local MOTIONS = { idle = "gait", walk = "gait", intro = "plan:introCrouch", death = "plan:death", env = "n_env", flinch = "plan:flinch", stun = "plan:stun" }
	local TAIL_TIP = { "Tail10", "Tail11", "Tail12" }
	D.abyssal_lord_v2 = {
		plan = "biped",
		planPatch = planPatch,
		stunStars = true,
		forms = {
			before = { gait = "serpent", stance = HOLD, guard = HOLD, contacts = { "Tail5", "Tail6", "Tail7" }, walk = { stride = 0.6, wave = 12, waves = 1, phaseStep = 0.6, runAt = 1.6 }, motions = MOTIONS, skills = SK, env = "n_env", throw = "n_throw", hop = "n_hop" },
			after = { gait = "serpent", stance = ANGRY, guard = ANGRY, contacts = { "Tail5", "Tail6", "Tail7" }, walk = { stride = 0.65, wave = 14, waves = 1.0, phaseStep = 0.6, runAt = 1.6 }, motions = MOTIONS, skills = SK, env = "n_env", throw = "n_throw", hop = "n_hop" },
		},
		transform = { clip = "n_transform", hit = 1.0, switchAt = 1.6, seconds = 2.6 },
		intro = { style = "emerge", depth = 3.0, riseFrac = 0.46, riseEase = "sine" },
		signature = { "tailSweep", "sweep", "tide", "vortex", "spout", "tridentThrow", "bubbles", "swipe", "colors", "mirror" },
		flash = {
			sweep = TAIL_TIP, tide = { "TridentHead" }, spout = { "TridentHead" }, colors = { "TridentHead" }, swipe = { "TridentHead" }, grab = TAIL_TIP, tailSweep = TAIL_TIP,
			vortex = TAIL_TIP, bubbles = { "Head" }, mirror = { "Hand_L" }, tridentThrow = { "TridentHead" },
		},
		impacts = {
			n_sweep = { kind = "whoosh", parts = TAIL_TIP, size = 1.3, floorDust = true }, n_tide = { kind = "ground", parts = { "TridentHead" }, size = 1.0, shake = 0.8 }, n_hop = { kind = "ground", parts = { "TridentHead" }, size = 1.0, shake = 0.9, heavy = true },
			n_spout = { kind = "spark", parts = { "TridentHead" }, size = 0.9 }, n_swipe = { kind = "whoosh", parts = { "TridentHead" }, size = 1.1 },
			n_tailsweep = { kind = "whoosh", parts = TAIL_TIP, size = 1.3, floorDust = true }, n_vortex = { kind = "whoosh", parts = TAIL_TIP, size = 1.2 },
			n_bubbles = { kind = "spark", parts = { "Head" }, size = 0.8 }, n_mirror = { kind = "spark", parts = { "Hand_L" }, size = 1.0 }, n_trident = { kind = "whoosh", parts = { "Hand_R" }, size = 1.1 },
			n_env = { kind = "ground", parts = TAIL_TIP, size = 1.3, shake = 1.2 }, n_throw = { kind = "whoosh", parts = TAIL_TIP, size = 1.0 },
			n_transform = { kind = "roar", parts = { "Head" }, size = 1.2, shake = 0.8 }, roar = { kind = "roar", parts = { "Head" }, size = 1.0, shake = 0.7 },
			basic_R = { kind = "whoosh", parts = { "TridentHead" }, size = 0.55 }, basic_L = { kind = "whoosh", parts = { "Hand_L" }, size = 0.55 },
		},
		clips = C,
	}
end

-- ═══════════════════════════ 수정 여왕 v2 — 수정 나비 여왕(BOSS-NIGHT-1 4 · Meshy 몸 + 날개 + 홀 · 바이블 §2-2 · §8) ═══════════════════════════
-- 리그 = BossRigV2Data crystal_queen_v2(A-포즈 · 닫힌 종 치마 · 날개 4장 × 2마디 · 홀 = 오른손 자식). 보행 = 떠 있기(hover - 발 접지 끔 · 치마 끝이 바닥 위로 뜬다).
--   날개 관절 ry = 펼침/접힘(mirror로 좌우) · 변신(50%) = 날개를 활짝 펴며 높이 떠오름 → 분노 세트(더 높이 · 날개 들림 · 홀을 앞으로).
--   §9 물풍선 전투는 만들지 않는다 - 일반 보스 틀(기존 11스킬 + 환경 + 변신)만.
do
	local REST_POSE = {}
	local function wings(f, b, rx)
		return { WingF_R1 = { rx or 0, f, 0 }, WingF_R2 = { 0, f * 0.6, 0 }, WingB_R1 = { rx or 0, b, 0 }, WingB_R2 = { 0, b * 0.6, 0 },
			WingF_L1 = { rx or 0, -f, 0 }, WingF_L2 = { 0, -f * 0.6, 0 }, WingB_L1 = { rx or 0, -b, 0 }, WingB_L2 = { 0, -b * 0.6, 0 } }
	end
	local HOLD = { Shoulder_R = { 20, 0, -12 }, Elbow_R = { 42, 0, 0 }, Wrist_R = { -52, 0, 0 }, Shoulder_L = { 8, 0, 16 }, Elbow_L = { 24, 0, 0 } } -- 홀을 세워 쥠
	local ANGRY = merge(HOLD, { Waist = { -6, 0, 0 }, Neck = { 4, 0, 0 } }, wings(-16, -10, -8))
	local SC_UP = merge(HOLD, { Shoulder_R = { 165, 0, -8 }, Elbow_R = { 10, 0, 0 }, Wrist_R = { -10, 0, 0 }, Waist = { 8, 0, 0 }, Neck = { 12, 0, 0 } }) -- 홀을 머리 위로
	local SC_POINT = merge(HOLD, { Shoulder_R = { 92, 0, -4 }, Elbow_R = { 0, 0, 0 }, Wrist_R = { 72, 0, 0 }, Waist = { -6, 0, 0 } }) -- 보석을 대상 쪽으로
	local LIFT = { RootJoint = { -4, 0, 0, 0, 0.5, 0 } } -- 더 떠오름(보이는 몸만)
	local C = {}
	-- 파편 폭발 burst(안 원 → 바깥 도넛): 홀을 치켜들고 보석에 빛을 모음 → 내리찍기 × 2(두 번째 = 바깥 도넛)
	local SLAM = merge(HOLD, { RootJoint = { 8, 0, 0, 0, -0.15, 0 }, Waist = { -20, 0, 0 }, Shoulder_R = { 55, 0, -8 }, Elbow_R = { 18, 0, 0 }, Wrist_R = { -30, 0, 0 } }, wings(14, 10))
	C.q_burst = {
		pre = { { f = 0.5, ease = "inout", pose = merge(SC_UP, LIFT, wings(-12, -8)) }, { f = 1.0, ease = "in", pose = merge(SC_UP, LIFT, wings(-18, -12), { Shoulder_R = { 172, 0, -4 } }) } },
		post = { { s = 0.08, ease = "in", pose = SLAM }, { s = 0.45, ease = "inout", pose = merge(SC_UP, LIFT) }, { s = 0.75, ease = "in", pose = SLAM }, { s = 1.6, ease = "inout", pose = REST_POSE } },
		hitstop = 0.07, squash = 0.15, extraStrikes = { post = { 0.75 } },
	}
	-- 수정 낙하 drop: 왼손을 하늘로 → 대상 쪽으로 내리그음(수정이 떨어진다)
	local SKY = merge(HOLD, { Shoulder_L = { 170, 0, 10 }, Elbow_L = { 8, 0, 0 }, Neck = { 18, 0, 0 } }, wings(-10, -6))
	C.q_drop = { pre = { { f = 1.0, ease = "inout", pose = SKY } },
		post = { { s = 0.08, ease = "out", pose = merge(HOLD, { Shoulder_L = { 70, 0, 6 }, Elbow_L = { 4, 0, 0 }, Waist = { -10, 0, 0 } }) }, { s = 0.9, ease = "inout", pose = REST_POSE } }, hitstop = 0.05 }
	-- 에네르기파 energyBeam(예비 2.5초 → 540° 3.6초): 두 손으로 홀 보석에 빛을 모음(날개 접힘) → 보석을 앞으로 겨눈 채 버팀(몸 회전은 빔 그림 · 보이는 몸 = 바라보기)
	local CHARGE = merge(HOLD, { Shoulder_R = { 60, 0, 10 }, Elbow_R = { 70, 0, 0 }, Wrist_R = { -20, 0, 0 }, Shoulder_L = { 60, 0, -14 }, Elbow_L = { 70, 0, 0 }, Waist = { 6, 0, 0 } }, wings(14, 10))
	local BEAM = merge(SC_POINT, { Shoulder_L = { 80, 0, -20 }, Elbow_L = { 20, 0, 0 } }, wings(-18, -12))
	C.q_beam = { pre = { { f = 0.7, ease = "inout", pose = CHARGE }, { f = 1.0, ease = "in", pose = merge(CHARGE, { Waist = { 12, 0, 0 } }) } },
		post = { { s = 0.1, ease = "out", pose = BEAM } }, loop = { period = 0.5, poses = { BEAM, merge(BEAM, { Shoulder_R = { 94, 0, -2 }, Waist = { -8, 0, 0 } }) } }, hitstop = 0.05,
		tremble = { from = 0.6, amp = 2, joints = { "Shoulder_R", "Shoulder_L" } } }
	-- 수정 오르골 orgel(전멸기): 두 손을 왕관에 대고 들어 올린 채 버팀(머리 위 표시)
	local CROWN = merge(HOLD, { Shoulder_L = { 150, 0, 30 }, Elbow_L = { 70, 0, 0 }, Shoulder_R = { 150, 0, -30 }, Elbow_R = { 70, 0, 0 }, Wrist_R = { -20, 0, 0 }, Neck = { 10, 0, 0 } }, LIFT, wings(-14, -10))
	C.q_orgel = { pre = { { f = 1.0, ease = "inout", pose = CROWN } }, post = { { s = 0.2, ease = "out", pose = CROWN } },
		loop = { period = 1.4, poses = { CROWN, merge(CROWN, { RootJoint = { -4, 0, 0, 0, 0.6, 0 } }, wings(-6, -4)) } } }
	-- 강화 평타 swipe: 홀 가로 베기(보석 번쩍)
	C.q_swipe = {
		pre = { { f = 0.45, ease = "inout", pose = merge(HOLD, { Waist = { 0, 34, 0 }, Shoulder_R = { 75, 0, -70 }, Elbow_R = { 30, 0, 0 }, Wrist_R = { 0, 0, -70 } }) },
			{ f = 1.0, ease = "out", pose = merge(HOLD, { Waist = { 0, 42, 0 }, Shoulder_R = { 78, 0, -78 }, Elbow_R = { 34, 0, 0 }, Wrist_R = { 0, 0, -75 } }) } },
		post = { { s = 0.08, ease = "out", pose = merge(HOLD, { Waist = { 0, -38, 0 }, Shoulder_R = { 85, 0, 30 }, Elbow_R = { 8, 0, 0 }, Wrist_R = { 0, 0, -75 } }, wings(10, 6)) },
			{ s = 0.26, ease = "back", pose = merge(HOLD, { Waist = { 0, -44, 0 }, Shoulder_R = { 85, 0, 38 }, Wrist_R = { 0, 0, -75 } }) }, { s = 0.95, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, tremble = { from = 0.6, amp = 3, joints = { "Shoulder_R" } },
	}
	-- 수정 손 잡기 grab: 왼손을 높이 들어 경고 → 왼손을 뻗어 잡음 → 들고 → 던짐
	local GRAB_UP = merge(HOLD, { Shoulder_L = { 140, 0, 40 }, Elbow_L = { 40, 0, 0 } })
	C.grab_tele = { pre = { { f = 0.8, ease = "inout", pose = GRAB_UP }, { f = 1.0, ease = "inout", pose = merge(GRAB_UP, { Shoulder_L = { 150, 0, 44 } }) } }, post = { { s = 0.15, ease = "out", pose = GRAB_UP } },
		tremble = { from = 0.75, amp = 2.5, joints = { "Shoulder_L" } } }
	local REACH = merge(HOLD, { Shoulder_L = { 90, 0, 0 }, Elbow_L = { 4, 0, 0 }, Waist = { -10, 0, 0 } })
	C.grab_reach = { post = { { s = 0.15, ease = "out", pose = REACH } }, loop = { period = 0.32, poses = { REACH, merge(REACH, { Shoulder_L = { 96, 0, -4 } }) } }, upper = true }
	local HOLDUP = merge(HOLD, { Shoulder_L = { 130, 0, 10 }, Elbow_L = { 30, 0, 0 } })
	C.grab_hold = { post = { { s = 0.25, ease = "out", pose = HOLDUP } }, loop = { period = 0.5, poses = { HOLDUP, merge(HOLDUP, { Shoulder_L = { 136, 0, 14 } }) } } }
	C.grab_snatch = { post = { { s = 0.06, ease = "out", pose = { Shoulder_L = { 100, 0, 0 } } }, { s = 0.5, ease = "inout", pose = {} } }, hitstop = 0.05 }
	C.q_throw = { pre = { { f = 1.0, ease = "inout", pose = merge(HOLD, { Shoulder_L = { 160, 0, 30 }, Elbow_L = { 60, 0, 0 }, Waist = { 8, -20, 0 } }) } },
		post = { { s = 0.1, ease = "out", pose = merge(HOLD, { Shoulder_L = { 60, 0, -10 }, Elbow_L = { 6, 0, 0 }, Waist = { -10, 20, 0 } }) }, { s = 0.9, ease = "inout", pose = REST_POSE } }, hitstop = 0.06 }
	-- 수정 가시 spikes(대상 발밑 십자): 홀 끝으로 바닥을 찍음
	local STAB = merge(HOLD, { RootJoint = { 6, 0, 0, 0, -0.2, 0 }, Waist = { -16, 0, 0 }, Shoulder_R = { 40, 0, -6 }, Elbow_R = { 10, 0, 0 }, Wrist_R = { -70, 0, 0 } })
	C.q_spikes = { pre = { { f = 1.0, ease = "inout", pose = merge(SC_UP, { Shoulder_R = { 130, 0, -8 } }) } },
		post = { { s = 0.08, ease = "in", pose = STAB }, { s = 1.0, ease = "inout", pose = REST_POSE } }, hitstop = 0.06, squash = 0.1 }
	-- 파편 날리기 shards(4발 0.15초 간격): 왼손을 앞으로 내밀며 연속 뿌림
	local FLICK = merge(HOLD, { Shoulder_L = { 85, 0, -10 }, Elbow_L = { 6, 0, 0 }, Waist = { -4, 14, 0 } })
	C.q_shards = { pre = { { f = 1.0, ease = "inout", pose = merge(HOLD, { Shoulder_L = { 60, 0, 40 }, Elbow_L = { 90, 0, 0 }, Waist = { 4, -20, 0 } }) } },
		post = { { s = 0.06, ease = "out", pose = FLICK }, { s = 0.2, ease = "out", pose = merge(FLICK, { Waist = { -4, 4, 0 } }) }, { s = 0.36, ease = "out", pose = merge(FLICK, { Waist = { -4, -6, 0 } }) },
			{ s = 0.5, ease = "out", pose = merge(FLICK, { Waist = { -4, -14, 0 } }) }, { s = 1.1, ease = "inout", pose = REST_POSE } }, hitstop = 0.04, extraStrikes = { post = { 0.2, 0.36, 0.5 } } }
	-- BOSS-NIGHT-2 3 마법 미사일 magicMissiles(사용자: 기본 평타 = 5연발 · 예비 0.35초 홀 발광 · 0.1초 간격): 홀을 대상 쪽으로 겨눠 다섯 번 튕김(발사마다 손목 · 어깨)
	local AIM = merge(HOLD, { Shoulder_R = { 92, 0, -6 }, Elbow_R = { 12, 0, 0 }, Wrist_R = { -20, 0, 0 }, Waist = { 0, 12, 0 }, Neck = { 0, 8, 0 } })
	local AIM_FLICK = merge(AIM, { Shoulder_R = { 102, 0, -6 }, Wrist_R = { -38, 0, 0 } })
	C.q_missile = { pre = { { f = 1.0, ease = "inout", pose = merge(AIM, { Shoulder_R = { 82, 0, -6 }, Wrist_R = { -5, 0, 0 } }) } },
		post = { { s = 0.04, ease = "out", pose = AIM_FLICK }, { s = 0.09, ease = "out", pose = AIM }, { s = 0.14, ease = "out", pose = AIM_FLICK }, { s = 0.19, ease = "out", pose = AIM },
			{ s = 0.24, ease = "out", pose = AIM_FLICK }, { s = 0.29, ease = "out", pose = AIM }, { s = 0.34, ease = "out", pose = AIM_FLICK }, { s = 0.39, ease = "out", pose = AIM },
			{ s = 0.44, ease = "out", pose = AIM_FLICK }, { s = 0.9, ease = "inout", pose = REST_POSE } }, hitstop = 0.02, extraStrikes = { post = { 0.14, 0.24, 0.34, 0.44 } } } -- 다섯 발 = 의도된 빠른 연타
	-- 분신 돌격 mirrorDash(예비 2.2초 · 분신 3이 달려갔다 돌아옴): 날개를 활짝 → 앞으로 숙여 날개 쳐 내보냄
	C.q_mdash = { pre = { { f = 0.6, ease = "inout", pose = merge(HOLD, LIFT, wings(-22, -16)) }, { f = 1.0, ease = "in", pose = merge(HOLD, LIFT, wings(-28, -20), { Waist = { 8, 0, 0 } }) } },
		post = { { s = 0.08, ease = "out", pose = merge(HOLD, wings(20, 14), { Waist = { -16, 0, 0 }, Shoulder_L = { 70, 0, 30 } }) }, { s = 1.2, ease = "inout", pose = REST_POSE } }, hitstop = 0.06 }
	-- 거울 mirror: 두 손을 앞에 모아 수정 거울을 세움(날개 감쌈)
	local GUARD = merge(HOLD, { Shoulder_L = { 100, 0, -30 }, Elbow_L = { 60, 0, 0 }, Shoulder_R = { 90, 0, 26 }, Elbow_R = { 60, 0, 0 }, Wrist_R = { -40, 0, 0 } }, wings(24, 18))
	C.q_mirror = { pre = { { f = 1.0, ease = "inout", pose = GUARD } }, post = { { s = 0.1, ease = "out", pose = GUARD } },
		loop = { period = 0.8, poses = { GUARD, merge(GUARD, wings(18, 12)) } }, hitstop = 0.05 }
	-- 환경(수정 부수기 50% 뒤 · 손): 두 팔을 들어 수정을 띄움(3초) - 날개 활짝 · 높이 떠오름
	local RAISE = merge(HOLD, { Shoulder_L = { 160, 0, 40 }, Elbow_L = { 10, 0, 0 }, Shoulder_R = { 160, 0, -40 }, Elbow_R = { 10, 0, 0 }, Wrist_R = { -10, 0, 0 }, Neck = { 16, 0, 0 } }, LIFT, wings(-24, -18))
	C.q_env = { pre = { { f = 0.5, ease = "inout", pose = RAISE }, { f = 1.0, ease = "in", pose = merge(RAISE, { RootJoint = { -4, 0, 0, 0, 0.8, 0 } }) } },
		post = { { s = 0.1, ease = "out", pose = RAISE }, { s = 1.4, ease = "inout", pose = REST_POSE } }, hitstop = 0.08, squash = 0.1 }
	-- 50% 변신: 날개를 접어 웅크렸다 → 활짝 펴며 높이 떠올라 홀을 듦 → 분노 세트
	local BLOOM = merge(SC_UP, LIFT, wings(-30, -22, -10), { Neck = { 20, 0, 0 }, Shoulder_L = { 60, 0, 60 }, Elbow_L = { 20, 0, 0 } })
	C.q_transform = { pre = { { f = 0.4, ease = "inout", pose = merge(HOLD, wings(26, 20), { Waist = { -20, 0, 0 }, Neck = { -16, 0, 0 } }) }, { f = 0.7, ease = "inout", pose = merge(HOLD, LIFT, wings(-10, -8), { Shoulder_R = { 95, 0, -10 }, Elbow_R = { 26, 0, 0 } }) }, { f = 1.0, ease = "inout", pose = BLOOM } },
		post = { { s = 0.0, ease = "out", pose = BLOOM }, { s = 0.6, ease = "inout", pose = merge(BLOOM, { Neck = { 22, 0, 3 } }) }, { s = 1.6, ease = "inout", pose = ANGRY } }, hitstop = 0.06, align = false }
	C.roar = { pre = { { f = 1.0, ease = "inout", pose = merge(HOLD, { Neck = { -12, 0, 0 }, Waist = { -12, 0, 0 } }) } }, post = { { s = 0.15, ease = "out", pose = BLOOM } },
		loop = { period = 0.18, poses = { BLOOM, merge(BLOOM, { Neck = { 22, 0, 2 } }) } } }
	local basicR = { post = { { s = 0.07, ease = "out", pose = { Waist = { -6, -20, 0 }, Shoulder_R = { 75, 0, -10 }, Elbow_R = { 6, 0, 0 }, Wrist_R = { 60, 0, 0 } } },
		{ s = 0.17, ease = "back", pose = { Waist = { -8, -24, 0 }, Shoulder_R = { 78, 0, -8 }, Wrist_R = { 60, 0, 0 } } }, { s = 0.6, ease = "inout", pose = REST_POSE } }, hitstop = 0.04 }
	C.basic_R = basicR
	C.basic_L = { post = { { s = 0.07, ease = "out", pose = mirror(basicR.post[1].pose) }, { s = 0.17, ease = "back", pose = mirror(basicR.post[2].pose) }, { s = 0.6, ease = "inout", pose = REST_POSE } }, hitstop = 0.04 }
	local prepR = { Waist = { 4, 20, 0 }, Shoulder_R = { 50, 0, -40 }, Elbow_R = { 60, 0, 0 } }
	local SLUMP = merge(HOLD, { RootJoint = { 6, 0, 0, 0, -0.5, 0 }, Waist = { -20, 0, 0 }, Neck = { -20, 0, 0 }, Shoulder_L = { -10, 0, 30 } }, wings(20, 16, 10))
	local STAGGER = merge(HOLD, { Waist = { -12, 0, 12 }, Neck = { -14, 0, 14 }, RootJoint = { 0, 0, 10, 0.05, -0.1, 0 } }, wings(10, 8))
	local planPatch = {
		introCrouch = merge(HOLD, { RootJoint = { 0, 0, 0, 0, -0.4, 0 }, Waist = { -26, 0, 0 }, Neck = { -22, 0, 0 } }, wings(26, 20)),
		introRoar = "roar",
		flinch = { seconds = 0.3, pose = { Waist = { 7, 0, 4 }, Neck = { 9, 0, 0 }, RootJoint = { 0, 0, 0, 0, 0, 0.06 } } },
		stun = { stagger = STAGGER, sit = SLUMP, staggerSeconds = 0.5, riseSeconds = 0.8, wobble = { hz = 0.9, neck = 12, waist = 5 }, eyes = { 0, 0, 0 } },
		death = {
			keys = { { s = 0.3, ease = "out", pose = STAGGER }, { s = 0.8, ease = "inout", pose = merge(STAGGER, { Waist = { -10, 0, -12 } }) }, { s = 1.3, ease = "in", pose = SLUMP },
				{ s = 1.6, ease = "out", pose = merge(SLUMP, { Waist = { -30, 0, 0 }, Neck = { -30, 0, 0 } }) } },
			hitstopAt = 1.3, fadeFrom = 2.0, fadeSeconds = 0.5, scatterFrom = 1.75, eyes = { 0, 0, 0 }, stars = true, slowSeconds = 0.8, slowRate = 0.4,
		},
		basicPrep = { R = prepR, L = mirror(prepR) },
	}
	local SK = { burst = "q_burst", drop = "q_drop", energyBeam = "q_beam", orgel = "q_orgel", swipe = "q_swipe", grab = "@grab", spikes = "q_spikes", shards = "q_shards",
		mirrorDash = "q_mdash", mirror = "q_mirror", magicMissiles = "q_missile" }
	local MOTIONS = { idle = "gait", walk = "gait", intro = "plan:introCrouch", death = "plan:death", env = "q_env", flinch = "plan:flinch", stun = "plan:stun" }
	local GEM = { "ScepterGem" }
	D.crystal_queen_v2 = {
		plan = "biped",
		planPatch = planPatch,
		stunStars = true,
		forms = {
			before = { gait = "hover", stance = HOLD, guard = HOLD, hover = { height = 0.5, bob = 0.12, period = 2.6 }, walk = { stride = 0.5, knee = 10, arm = 6, bob = 0.03, lean = 8 },
				motions = MOTIONS, skills = SK, env = "q_env", throw = "q_throw" },
			after = { gait = "hover", stance = ANGRY, guard = ANGRY, hover = { height = 0.9, bob = 0.16, period = 2.0 }, walk = { stride = 0.5, knee = 10, arm = 6, bob = 0.03, lean = 12 },
				motions = MOTIONS, skills = SK, env = "q_env", throw = "q_throw" },
		},
		transform = { clip = "q_transform", hit = 1.0, switchAt = 1.6, seconds = 2.6 },
		intro = { style = "rise", depth = 1.6, riseFrac = 0.44, riseEase = "out" },
		signature = { "burst", "drop", "energyBeam", "spikes", "shards", "mirrorDash", "swipe", "orgel", "mirror" },
		flash = {
			magicMissiles = GEM, burst = GEM, drop = { "Hand_L" }, energyBeam = GEM, orgel = { "Crown" }, swipe = GEM, grab = { "Hand_L" }, spikes = GEM, shards = { "Hand_L" },
			mirrorDash = { "WingF_L2", "WingF_R2" }, mirror = { "Hand_L" },
		},
		impacts = {
			q_burst = { kind = "ground", parts = GEM, size = 1.0, shake = 0.8 }, q_drop = { kind = "spark", parts = { "Hand_L" }, size = 0.9 }, q_beam = { kind = "spark", parts = GEM, size = 1.1 },
			q_swipe = { kind = "whoosh", parts = GEM, size = 1.1 }, q_spikes = { kind = "ground", parts = GEM, size = 0.8, shake = 0.5 }, q_shards = { kind = "spark", parts = { "Hand_L" }, size = 0.7 }, q_missile = { kind = "spark", parts = GEM, size = 0.5 },
			q_mdash = { kind = "whoosh", parts = { "WingF_L2", "WingF_R2" }, size = 1.3 }, q_mirror = { kind = "spark", parts = { "Hand_L" }, size = 1.0 },
			q_env = { kind = "roar", parts = { "Body" }, size = 1.3, shake = 0.9 }, q_throw = { kind = "whoosh", parts = { "Hand_L" }, size = 1.0 },
			q_transform = { kind = "roar", parts = { "Head" }, size = 1.2, shake = 0.8 }, roar = { kind = "roar", parts = { "Head" }, size = 1.0, shake = 0.7 },
			basic_R = { kind = "whoosh", parts = GEM, size = 0.55 }, basic_L = { kind = "whoosh", parts = { "Hand_L" }, size = 0.55 },
		},
		clips = C,
	}
end

-- ═══════════════════════════ 전갈 여왕 v2(BOSS-NIGHT-2 1 · Meshy 몸 · 다리 4쌍 · 바이블 §2-4 + MAMMOTH-SCORPION-NOTES) ═══════════════════════════
-- 리그 = BossRigV2Data scorpion_queen_v2(관절 이름 = 옛 전갈). 보행 = hexapod(BossMotion baseScorpion · 다리 4쌍 · groupA = 1·3 / 2·4 교대 - 왼 1 · 3 + 오른 2 · 4 ↔ 반대).
--   관절 뜻(오른쪽 기준 · 왼쪽 = mirror): 어깨 rx + = 집게를 안쪽으로 휘두름 · ry − = 집게 끝 들기 · rz + = 팔 전체 들기 / 팔꿈치 · 손목 rx + = 집게 끝 들기 · rz + = 바깥으로 /
--   집게(가시) rz + = 벌림 / 꼬리 마디 rx + = 뒤로 당김 · − = 앞으로 내리꽂음 / 다리 = 옛 전갈 틀(rz + x = 들기). 동작 끝 = 빈 자세({}) → 세트 기본 자세로.
do
	local REST_POSE = {}
	local function legs(f)
		local out = {}
		for k = 1, 4 do
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
	local function sym(p) -- 오른쪽 자세 → 좌우 둘 다
		return merge(p, mirror(p))
	end
	local STANCE = merge(sym({ Shoulder_R = { 0, -4, 4 } }), tails(function(_, i)
		return i <= 2 and { -4, 0, 0 } or nil
	end))
	local GUARD = merge(STANCE, sym({ Shoulder_R = { 0, -8, 8 }, Pincer_R = { 0, 0, 14 } }))
	-- 분노(50% 뒤): 집게 더 높이 · 꼬리 곧추 · 몸 조금 듦
	local ANGRY = merge(GUARD, sym({ Shoulder_R = { 0, -14, 14 }, Elbow_R = { 10, 0, 0 }, Pincer_R = { 0, 0, 24 } }), tails(function(_, i)
		return i <= 2 and { -10, 0, 0 } or nil
	end), { RootJoint = { 4, 0, 0, 0, 0.06, 0 } })
	local CLAWS_UP = merge(GUARD, sym({ Shoulder_R = { 0, -28, 28 }, Elbow_R = { 30, 0, 0 }, Wrist_R = { 20, 0, 0 }, Pincer_R = { 0, 0, 45 } }), { RootJoint = { 10, 0, 0, 0, 0.12, 0.1 }, Neck = { 8, 0, 0 } })
	local CLAWS_DOWN = merge(GUARD, sym({ Shoulder_R = { 6, 14, -4 }, Elbow_R = { -14, 0, 0 }, Wrist_R = { -10, 0, 0 }, Pincer_R = { 0, 0, 0 } }), { RootJoint = { -8, 0, 0, 0, -0.12, -0.1 }, Neck = { -6, 0, 0 } })
	-- 휘두르기(오른 집게): 바깥 · 뒤로 감았다가 앞을 가로질러 안쪽으로(집게가 바닥 가까이 지나감 - 근접 높이 규칙)
	local WIND_R = merge(GUARD, { Shoulder_R = { -40, -10, 16 }, Elbow_R = { 10, 0, 14 }, Pincer_R = { 0, 0, 45 }, RootJoint = { 0, -16, 0, 0, -0.04, 0 } })
	local HIT_R = merge(GUARD, { Shoulder_R = { 44, 6, 4 }, Elbow_R = { -6, 0, -14 }, Pincer_R = { 0, 0, 4 }, RootJoint = { 0, 18, 0, 0, -0.08, 0 } })
	local WIND_L, HIT_L = merge(GUARD, mirror(WIND_R)), merge(GUARD, mirror(HIT_R))
	local function tailPose(base, step, yaw)
		return tails(function(t, i)
			return { i == 1 and base or step, i == 1 and (yaw or 0) * (t - 2) or 0, 0 }
		end)
	end
	local C = {}
	-- 집게 강타 claw(직선 3갈래 · 1.5초): 두 집게를 치켜들고 뒷다리로 일어섬 → 두 집게로 땅을 내리찍음
	C.s_claw = {
		pre = { { f = 0.5, ease = "inout", pose = CLAWS_UP }, { f = 1.0, ease = "in", pose = merge(CLAWS_UP, sym({ Shoulder_R = { 0, -34, 32 } }), { RootJoint = { 12, 0, 0, 0, 0.16, 0.12 } }) } },
		post = { { s = 0.07, ease = "out", pose = CLAWS_DOWN }, { s = 0.25, ease = "back", pose = merge(CLAWS_DOWN, { RootJoint = { -10, 0, 0, 0, -0.14, -0.12 } }) }, { s = 1.0, ease = "inout", pose = REST_POSE } },
		hitstop = 0.07, squash = 0.12, tremble = { from = 0.7, amp = 3, joints = { "Shoulder_R", "Shoulder_L" } },
	}
	-- 두 집게 휩쓸기 clawSweep(부채 150° × 2볼리 · 1.5초 간격): 오른 집게 크게 감았다 휩쓸기 → 왼 집게(60° 돌린 둘째)
	C.s_sweep = {
		pre = { { f = 0.5, ease = "inout", pose = merge(GUARD, { Shoulder_R = { -28, -8, 12 }, Pincer_R = { 0, 0, 40 }, RootJoint = { 0, -10, 0, 0, -0.03, 0 } }) }, { f = 1.0, ease = "in", pose = WIND_R } },
		post = { { s = 0.08, ease = "out", pose = HIT_R }, { s = 0.3, ease = "back", pose = merge(HIT_R, { Shoulder_R = { 50, 6, 4 } }) }, { s = 0.9, ease = "inout", pose = WIND_L },
			{ s = 1.5, ease = "in", pose = HIT_L }, { s = 1.72, ease = "back", pose = merge(HIT_L, { Shoulder_L = { 50, -6, -4 } }) }, { s = 2.5, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, squash = 0.08, extraStrikes = { post = { 1.5 } }, tremble = { from = 0.6, amp = 3, joints = { "Shoulder_R" } },
	}
	-- 강화 평타 swipe(집게 찰싹): 오른 집게 손등 휘두르기(Hand_R 번쩍)
	C.s_swipe = {
		pre = { { f = 0.4, ease = "inout", pose = merge(GUARD, { Shoulder_R = { -30, -8, 12 }, Pincer_R = { 0, 0, 40 }, RootJoint = { 0, -12, 0, 0, -0.04, 0 } }) }, { f = 1.0, ease = "out", pose = WIND_R } },
		post = { { s = 0.08, ease = "out", pose = HIT_R }, { s = 0.22, ease = "back", pose = merge(HIT_R, { Shoulder_R = { 52, 6, 4 }, RootJoint = { 0, 24, 0, 0, -0.08, 0 } }) }, { s = 0.8, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, squash = 0.06, tremble = { from = 0.6, amp = 4, joints = { "Shoulder_R", "Pincer_R" } },
	}
	-- 독침 낙하 sting(대상 둘레 3곳 · 1.2초): 세 꼬리를 뒤로 당겼다가 앞으로 튕겨 독침을 쏨
	C.s_sting = {
		pre = { { f = 0.5, ease = "inout", pose = merge(GUARD, tailPose(16, 5, 6), { RootJoint = { 6, 0, 0, 0, -0.04, 0.08 } }) }, { f = 1.0, ease = "in", pose = merge(GUARD, tailPose(24, 7, 8), { RootJoint = { 8, 0, 0, 0, -0.06, 0.1 } }) } },
		post = { { s = 0.08, ease = "out", pose = merge(GUARD, tailPose(-22, -8), { RootJoint = { -8, 0, 0, 0, -0.12, -0.1 } }) }, { s = 0.25, ease = "back", pose = merge(GUARD, tailPose(-26, -9), { RootJoint = { -10, 0, 0, 0, -0.14, -0.12 } }) },
			{ s = 0.85, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, squash = 0.1,
	}
	-- 3연 찌르기 stingJab(직선 · 0.9 · 0.9 · 1.3 - 셋째가 큼): 가운데 꼬리로 세 번 찌름(옆 꼬리는 반만)
	local function jab(base, step)
		return tails(function(t, i)
			local k = t == 2 and 1 or 0.45
			return { (i == 1 and base or step) * k, 0, 0 }
		end)
	end
	local JAB_BACK, JAB = merge(GUARD, jab(18, 7), { RootJoint = { 6, 0, 0, 0, -0.03, 0.06 } }), merge(GUARD, jab(-24, -9), { RootJoint = { -8, 0, 0, 0, -0.1, -0.1 } })
	C.s_jab = {
		pre = { { f = 1.0, ease = "inout", pose = JAB_BACK } },
		post = { { s = 0.08, ease = "out", pose = JAB }, { s = 0.5, ease = "inout", pose = JAB_BACK }, { s = 0.9, ease = "in", pose = JAB }, { s = 1.45, ease = "inout", pose = merge(GUARD, jab(26, 9), { RootJoint = { 8, 0, 0, 0, -0.03, 0.08 } }) },
			{ s = 2.2, ease = "in", pose = merge(GUARD, jab(-30, -11), { RootJoint = { -12, 0, 0, 0, -0.14, -0.14 } }) }, { s = 2.45, ease = "back", pose = merge(JAB, { RootJoint = { -12, 0, 0, 0, -0.15, -0.15 } }) }, { s = 3.2, ease = "inout", pose = REST_POSE } },
		hitstop = 0.06, squash = 0.08, extraStrikes = { post = { 0.9, 2.2 } },
	}
	-- 땅 파기(잠행 찌르기 · 모래 잠복 · 진짜 찾기 시작): 몸을 낮추고 다리를 벌려 모래를 판다(다리 끝 모래 속 = 의도 · 발 접지 끔)
	local DIG = merge(GUARD, legs(function(_, x)
		return { 0, 0, x * 18 }, { 0, 0, -x * 10 }
	end), sym({ Shoulder_R = { -10, 22, -4 }, Elbow_R = { -10, 0, 0 } }), { RootJoint = { -6, 0, 0, 0, -0.55, 0 } })
	C.s_dig = {
		pre = { { f = 0.25, ease = "inout", pose = merge(DIG, { RootJoint = { -6, 0, 4, 0, -0.45, 0 } }) }, { f = 0.5, ease = "inout", pose = merge(DIG, { RootJoint = { -6, 0, -4, 0, -0.5, 0 } }) },
			{ f = 0.75, ease = "inout", pose = merge(DIG, { RootJoint = { -6, 0, 4, 0, -0.55, 0 } }) }, { f = 1.0, ease = "inout", pose = DIG } },
		post = { { s = 0.1, ease = "out", pose = DIG } },
		loop = { period = 0.3, poses = { merge(DIG, { RootJoint = { -6, 0, 3, 0, -0.55, 0 } }), merge(DIG, { RootJoint = { -6, 0, -3, 0, -0.55, 0 } }) } },
		airborne = { from = 0, to = 1000 }, buried = true,
	}
	-- 아르마딜로 태세(반사): 다리 오므리고 꼬리로 등을 덮고 집게로 얼굴을 가림
	local CURL = merge(legs(function(_, x)
		return { 0, 0, -x * 22 }, { 0, 0, x * 18 }
	end), tails(function(_, i)
		return { i == 1 and -22 or -12, 0, 0 }
	end), sym({ Shoulder_R = { 30, 10, -4 }, Elbow_R = { -10, 0, -20 }, Pincer_R = { 0, 0, 0 } }), { RootJoint = { -10, 0, 0, 0, -0.4, 0 }, Neck = { -18, 0, 0 } })
	C.s_curl = {
		pre = { { f = 1.0, ease = "inout", pose = CURL } },
		post = { { s = 0.1, ease = "out", pose = CURL } },
		loop = { period = 0.8, poses = { CURL, merge(CURL, { RootJoint = { -11, 0, 1, 0, -0.42, 0 } }) } },
		airborne = { from = 0, to = 1000 }, buried = true,
	}
	-- 집게 낚아채기(대공 잡기): 전조 = 집게 · 꼬리를 하늘로 / 들기 = 꼬리 셋에 한 명씩 / 던지기 = 꼬리 투석
	local S_UP = merge(CLAWS_UP, tails(function(_, i)
		return { i == 1 and 10 or 4, 0, 0 }
	end))
	C.grab_tele = { pre = { { f = 0.2, ease = "out", pose = S_UP }, { f = 1.0, ease = "inout", pose = merge(S_UP, { RootJoint = { 6, 0, 0, 0, 0.04, 0.05 } }) } }, tremble = { from = 0.75, amp = 3, joints = { "Shoulder_R", "Shoulder_L" } } }
	local S_REACH = merge(GUARD, sym({ Shoulder_R = { 14, -16, 16 }, Elbow_R = { 20, 0, 0 }, Pincer_R = { 0, 0, 45 } }))
	C.grab_reach = { post = { { s = 0.15, ease = "out", pose = S_REACH } }, loop = { period = 0.3, poses = { S_REACH, merge(S_REACH, sym({ Pincer_R = { 0, 0, 36 } })) } }, upper = true }
	C.grab_snatch = {
		post = { { s = 0.0, ease = "out", pose = merge(tails(function(_, i)
			return { i == 1 and 18 or 6, 0, 0 }
		end), { Pincer_R = { 0, 0, 45 } }) }, { s = 0.1, ease = "in", pose = merge(tails(function(_, i)
			return { i == 1 and -14 or -6, 0, 0 }
		end), { Pincer_R = { 0, 0, 0 }, Jaw = { 0, 0, 0, 0, -0.06, 0 } }) }, { s = 0.6, ease = "inout", pose = {} } },
		hitstop = 0.07, face = true,
	}
	local S_HOLD = merge(GUARD, tails(function(t, i)
		return { i == 1 and 6 or 2, i == 1 and (t - 2) * 16 or 0, 0 }
	end), { RootJoint = { 4, 0, 0, 0, 0, 0 } })
	C.grab_hold = { post = { { s = 0.25, ease = "out", pose = S_HOLD } }, loop = { period = 0.45, poses = { S_HOLD, merge(S_HOLD, { RootJoint = { 5, 3, 2, 0, 0, 0 } }) } } }
	C.s_throw = {
		pre = { { f = 1.0, ease = "inout", pose = merge(S_HOLD, tails(function(t, i)
			return { i == 1 and 24 or 7, (t - 2) * 10, 0 }
		end), { RootJoint = { 10, 0, 0, 0, -0.1, 0.1 } }) } },
		post = { { s = 0.09, ease = "out", pose = merge(GUARD, tailPose(-28, -10), { RootJoint = { -12, 0, 0, 0, -0.16, -0.14 } }) },
			{ s = 0.3, ease = "back", pose = merge(GUARD, tailPose(-32, -11), { RootJoint = { -13, 0, 0, 0, -0.18, -0.16 } }) }, { s = 1.0, ease = "inout", pose = REST_POSE } },
		hitstop = 0.07, squash = 0.1,
	}
	-- 환경(50% 개미지옥): 일어서 두 집게로 모래를 연달아 내리쳐 구덩이를 만든다
	C.s_env = {
		pre = { { f = 0.4, ease = "inout", pose = CLAWS_UP }, { f = 1.0, ease = "in", pose = merge(CLAWS_UP, sym({ Shoulder_R = { 0, -34, 32 } }), { RootJoint = { 14, 0, 0, 0, 0.18, 0.14 } }) } },
		post = { { s = 0.08, ease = "out", pose = CLAWS_DOWN }, { s = 0.45, ease = "inout", pose = merge(CLAWS_UP, { RootJoint = { 8, 0, 0, 0, 0.08, 0.06 } }) }, { s = 0.75, ease = "in", pose = CLAWS_DOWN },
			{ s = 1.5, ease = "inout", pose = REST_POSE } },
		hitstop = 0.08, squash = 0.2, extraStrikes = { post = { 0.75 } },
	}
	-- 쉭(등장 · 포효 자리): 집게 · 꼬리를 치켜들고 떨기
	local HISS = merge(CLAWS_UP, tails(function(_, i)
		return { i == 1 and 14 or 6, 0, 0 }
	end), { Jaw = { 0, 0, 0, 0, -0.06, 0 } })
	C.s_hiss = {
		pre = { { f = 1.0, ease = "inout", pose = merge(GUARD, { RootJoint = { -4, 0, 0, 0, -0.08, 0 } }) } },
		post = { { s = 0.12, ease = "out", pose = HISS }, { s = 0.3, ease = "back", pose = merge(HISS, sym({ Pincer_R = { 0, 0, 55 } })) } },
		loop = { period = 0.14, poses = { HISS, merge(HISS, { RootJoint = { 10, 0, 1, 0, 0.12, 0.1 } }) } },
		hitstop = 0.05, tremble = { from = 0.6, amp = 3, joints = { "Shoulder_R", "Shoulder_L" } },
	}
	C.roar = C.s_hiss
	-- 50% 변신(겉모습 격노): 웅크렸다가 크게 일어서 집게 · 꼬리를 활짝(쉭) → 분노 세트
	local FAN = merge(CLAWS_UP, tails(function(t, i)
		return { i == 1 and 6 or 2, i == 1 and (t - 2) * 14 or 0, 0 }
	end), { RootJoint = { 14, 0, 0, 0, 0.2, 0.14 }, Neck = { 14, 0, 0 } })
	C.s_transform = { pre = { { f = 1.0, ease = "inout", pose = merge(CURL, { RootJoint = { -8, 0, 0, 0, -0.3, 0 } }) } },
		post = { { s = 0.0, ease = "out", pose = FAN }, { s = 0.6, ease = "inout", pose = merge(FAN, { Neck = { 16, 0, 3 } }) }, { s = 1.6, ease = "inout", pose = ANGRY } }, hitstop = 0.06, align = false }
	-- 평타(집게 찰싹 앞으로) · 예비(집게를 옆으로 벌려 뒤로 당김)
	local basicR = { post = { { s = 0.06, ease = "out", pose = merge(GUARD, { Shoulder_R = { 28, 8, 4 }, Elbow_R = { -10, 0, -6 }, Pincer_R = { 0, 0, 0 }, RootJoint = { 0, 8, 0, 0, -0.06, -0.06 } }) },
		{ s = 0.16, ease = "back", pose = merge(GUARD, { Shoulder_R = { 32, 10, 4 }, Elbow_R = { -12, 0, -6 }, Pincer_R = { 0, 0, -4 }, RootJoint = { 0, 10, 0, 0, -0.07, -0.07 } }) }, { s = 0.5, ease = "inout", pose = REST_POSE } },
		hitstop = 0.05 }
	C.basic_R = basicR
	C.basic_L = { post = { { s = 0.06, ease = "out", pose = merge(GUARD, mirror(basicR.post[1].pose)) }, { s = 0.16, ease = "back", pose = merge(GUARD, mirror(basicR.post[2].pose)) }, { s = 0.5, ease = "inout", pose = REST_POSE } }, hitstop = 0.05 }
	local prepR = merge(GUARD, { Shoulder_R = { -24, -8, 12 }, Elbow_R = { 14, 0, 10 }, Pincer_R = { 0, 0, 42 }, RootJoint = { 0, -8, 0, 0, -0.04, 0 } })
	local STAGGER = merge(legs(function(k, x)
		return { 0, (k - 2.5) * 8, x * 10 }, { 0, 0, -x * 6 }
	end), { RootJoint = { 0, 0, 14, 0, -0.2, 0 }, Neck = { -10, 0, 10 } })
	local SIT = merge(legs(function(_, x)
		return { 0, 0, x * 32 }, { 0, 0, -x * 24 }
	end), tails(function(_, i)
		return { i == 1 and 36 or 10, 0, 0 }
	end), sym({ Shoulder_R = { -10, 20, -6 } }), { RootJoint = { 0, 0, 0, 0, -0.72, 0 }, Neck = { -18, 0, 0 } })
	local planPatch = {
		introCrouch = merge(legs(function(_, x)
			return { 0, 0, -x * 20 }, { 0, 0, x * 18 }
		end), tails(function(_, i)
			return { i == 1 and -18 or -10, 0, 0 }
		end), sym({ Shoulder_R = { 20, 12, -4 } }), { RootJoint = { -10, 0, 0, 0, -0.35, 0 } }),
		introRoar = "s_hiss",
		flinch = { seconds = 0.24, pose = { RootJoint = { 6, 0, 3, 0, 0.05, 0.06 }, Neck = { 10, 0, 0 } } },
		stun = { stagger = STAGGER, sit = SIT, staggerSeconds = 0.5, riseSeconds = 0.7, wobble = { hz = 1.1, neck = 10, waist = 0 }, eyes = { 0, 0, 0 } },
		death = {
			keys = { { s = 0.3, ease = "out", pose = STAGGER }, { s = 1.25, ease = "in", pose = SIT }, { s = 1.45, ease = "out", pose = merge(SIT, { RootJoint = { 0, 0, 0, 0, -0.8, 0 } }) } },
			hitstopAt = 1.25, fadeFrom = 2.0, fadeSeconds = 0.5, scatterFrom = 1.75, eyes = { 0, 0, 0 }, stars = true, slowSeconds = 0.8, slowRate = 0.4,
		},
		basicPrep = { R = prepR, L = merge(GUARD, mirror(prepR)) },
		holdPose = S_HOLD,
	}
	local SK = { claw = "s_claw", clawSweep = "s_sweep", swipe = "s_swipe", sting = "s_sting", stingJab = "s_jab", stab = "s_dig", ambush = "s_dig", sandSearch = "s_dig", armadillo = "s_curl", grab = "@grab" }
	local MOTIONS = { idle = "gait", walk = "gait", intro = "plan:introCrouch", death = "plan:death", env = "s_env", flinch = "plan:flinch", stun = "plan:stun" }
	local WALK = { stride = 0.55, swing = 22, lift = 18, bob = 0.04, runAt = 1.6, turnLean = 4, groupA = { "1_L", "3_L", "2_R", "4_R" } }
	local CLAWS, TIPS = { "Hand_R", "Hand_L" }, { "Tail1_8", "Tail2_8", "Tail3_8" }
	local FEET = { "Shin1_L", "Shin2_L", "Shin3_L", "Shin4_L", "Shin1_R", "Shin2_R", "Shin3_R", "Shin4_R" }
	D.scorpion_queen_v2 = {
		plan = "scorpion",
		planPatch = planPatch,
		stunStars = true,
		forms = {
			before = { gait = "hexapod", contacts = FEET, stance = STANCE, guard = GUARD, walk = WALK, motions = MOTIONS, skills = SK, env = "s_env", throw = "s_throw" },
			after = { gait = "hexapod", contacts = FEET, stance = merge(STANCE, { RootJoint = { 4, 0, 0, 0, 0.06, 0 } }), guard = ANGRY, walk = merge(WALK, { stride = 0.6, lift = 20 }), motions = MOTIONS, skills = SK, env = "s_env", throw = "s_throw" },
		},
		transform = { clip = "s_transform", hit = 1.0, switchAt = 1.6, seconds = 2.6 },
		intro = { style = "burrow", depth = 2.2, riseFrac = 0.36, riseEase = "back" },
		signature = { "clawSweep", "stab", "stingJab", "claw", "sting", "ambush", "armadillo", "swipe", "sandSearch" },
		flash = {
			claw = CLAWS, clawSweep = CLAWS, swipe = { "Hand_R" }, sting = TIPS, stingJab = { "Tail2_8" }, stab = TIPS, ambush = TIPS, sandSearch = { "Tail2_8" }, armadillo = { "Body" }, grab = CLAWS,
		},
		impacts = {
			s_claw = { kind = "ground", parts = CLAWS, size = 1.0, shake = 0.7, crack = 9 }, s_sweep = { kind = "whoosh", parts = CLAWS, size = 1.2, floorDust = true }, s_swipe = { kind = "whoosh", parts = { "Hand_R" }, size = 1.1 },
			s_sting = { kind = "spark", parts = TIPS, size = 0.9 }, s_jab = { kind = "spark", parts = { "Tail2_8" }, size = 0.9 }, s_dig = { kind = "ground", parts = { "Body" }, size = 1.0, shake = 0.4 },
			s_curl = { kind = "spark", parts = { "Body" }, size = 1.0 }, s_throw = { kind = "whoosh", parts = TIPS, size = 1.0 }, s_env = { kind = "ground", parts = CLAWS, size = 1.3, shake = 1.0 },
			s_transform = { kind = "roar", parts = { "Head" }, size = 1.2, shake = 0.8 }, s_hiss = { kind = "roar", parts = { "Head" }, size = 1.0, shake = 0.6 }, roar = { kind = "roar", parts = { "Head" }, size = 1.0, shake = 0.6 },
			basic_R = { kind = "whoosh", parts = { "Hand_R" }, size = 0.55 }, basic_L = { kind = "whoosh", parts = { "Hand_L" }, size = 0.55 },
		},
		clips = C,
	}
end

-- ═══════════════════════════ BOSS-NIGHT-2 3 근접 높이 규칙(바이블 §13): 근접 타격 부위의 가장 낮은 점 = 지면 ~ 8 stud
-- 접촉 키(post 1 · 2)에 더하는 값(각도 · 루트 내림 - 겉모습만 · 판정 · 시각 무변경). 수치 = 오프라인 FK 격자 탐색(발 지면 −0.7 위 · 다른 부위가 원래보다 0.3 넘게 박히지 않음 · 보정 최소).
--   높이 = 접촉 순간 ~ +0.12초(접촉 · 유지 키)의 타격 부위 최저점(예비 → 접촉 보간 중 잠깐 스치는 점은 세지 않음 - 그걸 세면 무기가 접촉 때 위로 서 있어도 통과했다).
--   bend(a) = 다리 굽힘(엉덩이 +a · 무릎 −2a · 발목 +a - 루트를 내릴 때 발이 땅에 박히지 않게). 자세 표는 복사해서 쓴다(다른 키 · 동작과 같은 표를 건드리지 않음).
do
	local function bend(a)
		return { Hip_L = { a }, Hip_R = { a }, Knee_L = { -2 * a }, Knee_R = { -2 * a }, Ankle_L = { a }, Ankle_R = { a } }
	end
	local function addPose(pose, delta)
		local out = table.clone(pose)
		for joint, d in pairs(delta) do
			local cur = out[joint] and table.clone(out[joint]) or { 0, 0, 0, 0, 0, 0 }
			for i = 1, #d do
				cur[i] = (cur[i] or 0) + d[i]
			end
			out[joint] = cur
		end
		return out
	end
	local function tailTip(rx) -- 나가 꼬리 6 ~ 12마디 위아래(rx)
		local p = {}
		for i = 6, 12 do
			p["Tail" .. i] = { rx }
		end
		return p
	end
	local MELEE_LOW = {
		section_guardian_v2 = { k_swipe = { Shoulder_R = { -40 } }, basic_R = { Shoulder_R = { -60 } }, basic_L = { Shoulder_L = { -60 } } }, -- 강화 평타 12.9 → 6.0 · 평타 12.7 ~ 15.1 → 6.3 ~ 6.7
		frost_giant_v2 = { m_swipe = { Neck = { -20 } }, basic_R = { Neck = { -20 } }, basic_L = { Neck = { -20 } } }, -- 상아: 고개 숙여 · 9.8 → 5.4 · 평타 10.0 → 6.2
		storm_lord_v2 = {
			s_inner = merge({ RootJoint = { -10, 0, 0, 0, -0.8, 0 } }, bend(20)), -- 원 안 낙뢰: 10.7 → 6.7
			basic_R = merge({ RootJoint = { -30, 0, 0, 0, -0.8, 0 }, Waist = { -30 }, Shoulder_R = { -60 } }, bend(40)), -- 1폼 오른손 평타(지팡이 보주): 24.2 → 8.5(격자 최저 - 규칙 경계)
			basic_L = merge({ RootJoint = { -50, 0, 0, 0, -0.8, 0 }, Waist = { -30 } }, bend(20)), -- 1폼 왼손 평타(빈손): 18.1 → 6.6
			f_basic_L = merge({ RootJoint = { -40, 0, 0, 0, -0.8, 0 } }, bend(20)), -- 2폼 잽: 11.6 → 6.6
			f_basic_R = merge({ RootJoint = { -50, 0, 0, 0, -0.6, 0 }, Waist = { -30 } }, bend(20)), -- 11.6 → 6.1(앞다리가 달라 왼쪽과 값이 다름)
		},
		abyssal_lord_v2 = {
			n_swipe = { RootJoint = { -15 }, Waist = { -30 }, Shoulder_R = { -80 }, Wrist_R = { -60, 0, 110 } }, -- 삼지창: 팔 내려 손목을 눕혀 창끝 앞-아래로 · 19.5 → 7.0
			basic_L = { RootJoint = { -30, 0, 0, 0, -0.3, 0 }, Waist = { -30 }, Shoulder_L = { -30 } }, -- 왼손 평타: 16.0 → 7.0
			n_sweep = tailTip(30), n_tailsweep = tailTip(-30), -- 꼬리 휩쓸기 · 꼬리 반원: 접촉 때 꼬리 끝이 들려 있었다(19.0 · 16.8) → 끝 7마디를 눌러 지면 쪽으로 6.8 · 2.5
		},
		crystal_queen_v2 = {
			q_burst = { Waist = { -35 }, Shoulder_R = { -40 }, Wrist_R = { 0, 0, -75 } }, -- 폭발: 허리 숙여 홀을 아래로 · 18.8 → 5.7
			q_swipe = { RootJoint = { -20, 0, 0, 0, -0.2, 0 }, Waist = { -80 }, Shoulder_R = { -60 }, Wrist_R = { 60, 0, -40 } }, -- 강화 평타: 깊이 숙여 쓸기 · 22.3 ~ 23.8 → 7.2
			basic_R = { RootJoint = { -10 }, Waist = { -35 }, Shoulder_R = { -40 }, Wrist_R = { 60, 0, 60 } }, -- 오른손 평타(홀): 15.8 → 6.2
			basic_L = { RootJoint = { -20, 0, 0, 0, -0.2, 0 }, Waist = { -35 }, Shoulder_L = { -40 }, Wrist_L = { -60, 0, 30 } }, -- 왼손 평타(빈손): 21.8 → 10.3 = 떠 있는 몸 + 종 치마가 땅에 박히지 않는 한도의 최저(바이블 §13 예외)
		},
	}
	for rigKey, list in pairs(MELEE_LOW) do
		for name, delta in pairs(list) do
			local clip = D[rigKey].clips[name]
			for i = 1, 2 do
				clip.post[i] = table.clone(clip.post[i])
				clip.post[i].pose = addPose(clip.post[i].pose, delta)
			end
		end
	end
end

return D
