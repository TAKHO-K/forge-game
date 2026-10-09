-- BOSS-NIGHT-2 3 발생 지점 표(자동 생성 - tools/harness/boss_origin_dump.luau → boss_origin_gen.py · 손으로 고치지 말 것)
-- [리그][스킬] = { kind = "ground"(그 부위 아래 바닥 - 파동 · 균열선 · 지면 투사체) | "launch"(부위 가운데 - 투사체), part = 부위, contact = 접촉 프레임(초 · 동작 시작부터),
--   before / after = { x(오른쪽), y(지면 위), z(앞 = −) } 리그 단위 = 접촉 프레임의 보스 루트 기준 오프라인 FK + Studio 실측 보정(tuned = 표본 수 · boss_origin_tune.json) } · 월드 = × 크기(sizeScale × rig.scale) · 대상 쪽 방향으로 돌림(shared/BossOrigin)
-- 서버는 애니메이션을 재생하지 않아 부위 자리를 그 프레임에 읽을 수 없다(②안) - 클라 그림도 서버가 보낸 같은 자리를 쓴다(예고 = 판정 = 이펙트).
return {
	abyssal_lord_v2 = {
		bubbles = { kind = "launch", part = "Head", contact = 1.21, tuned = 2, after = { -0.042, 6.092, -1.616 }, before = { -0.042, 6.092, -1.616 }, },
		tide = { kind = "ground", part = "TridentHead", contact = 1.53, tuned = 9, after = { 3.632, 0.454, -1.485 }, before = { 3.632, 0.454, -1.485 }, },
		tridentThrow = { kind = "launch", part = "TridentHead", contact = 1.01, tuned = 2, after = { 2.776, 3.622, -2.103 }, before = { 2.776, 3.622, -2.103 }, },
	},
	crystal_queen_v2 = {
		magicMissiles = { kind = "launch", part = "ScepterGem", contact = 0.61, tuned = 35, after = { 2.041, 6.804, -0.355 }, before = { 2.041, 6.373, -0.355 }, },
		shards = { kind = "launch", part = "Hand_L", contact = 1.01, tuned = 2, after = { -1.985, 5.716, -1.093 }, before = { -1.985, 5.399, -1.093 }, },
	},
	frost_giant_v2 = {
		slam = { kind = "ground", part = "Hand_L,Hand_R", contact = 2.38, tuned = 3, after = { -0.034, -0.024, -0.354 }, before = { -0.034, -0.024, -0.354 }, },
		snowball = { kind = "launch", part = "Trunk6", contact = 1.51, tuned = 4, after = { 0.009, 0.296, -1.916 }, before = { 0.009, 0.296, -1.916 }, },
		spike = { kind = "ground", part = "Tusk_L,Tusk_R", contact = 1.51, tuned = 3, after = { -0.029, 0.546, -1.227 }, before = { -0.029, 0.546, -1.227 }, },
		stomp = { kind = "ground", part = "Hand_R", contact = 1.81, tuned = 4, after = { 0.411, -0.033, -0.294 }, before = { 0.411, -0.033, -0.294 }, },
		tuskShot = { kind = "launch", part = "Tusk_L,Tusk_R", contact = 1.41, tuned = 2, after = { -0.010, 1.199, -1.545 }, before = { -0.010, 1.199, -1.545 }, },
	},
	scorpion_queen_v2 = {
		claw = { kind = "ground", part = "Hand_R,Hand_L", contact = 1.51, tuned = 6, after = { 0.000, -0.647, -1.787 }, before = { 0.000, -0.647, -1.787 }, },
	},
	section_guardian_v2 = {
		banana = { kind = "launch", part = "Hand_R", contact = 0.46, tuned = 2, after = { 2.827, 1.972, -1.405 }, before = { 2.827, 1.900, -1.386 }, },
		cross = { kind = "ground", part = "Hand_L,Hand_R", contact = 1.51, tuned = 4, after = { 0.012, -0.691, -2.056 }, before = { 0.012, -0.691, -2.056 }, },
		heavy = { kind = "ground", part = "Hand_L,Hand_R", contact = 2.13, tuned = 5, after = { 0.004, -0.594, -2.143 }, before = { 0.004, -0.594, -2.143 }, },
		orbs = { kind = "launch", part = "Crystal2,Crystal3", contact = 1.21, tuned = 1, after = { 0.196, 3.252, 1.408 }, before = { 0.226, 3.032, 1.408 }, },
		shockwave = { kind = "ground", part = "Hand_L,Hand_R", contact = 1.53, tuned = 10, after = { 0.005, -0.805, -2.127 }, before = { 0.005, -0.805, -2.127 }, },
	},
	storm_lord_v2 = {
		boltSpear = { kind = "launch", part = "Hand_L", contact = 1.01, tuned = 5, after = { -0.854, 4.791, -1.087 }, before = { -2.602, 5.184, -0.619 }, },
		discharge = { kind = "ground", part = "Staff", contact = 1.53, tuned = 5, after = { 0.000, 0.165, -1.080 }, before = { 1.247, 1.425, -1.266 }, },
		stormOrbs = { kind = "launch", part = "Gauntlet_R,Gauntlet_L", contact = 0.71, after = { 0.000, 4.879, -1.773 }, before = { -0.003, 4.977, -1.816 }, },
		swordWave = { kind = "ground", part = "StaffOrb", contact = 0.51, tuned = 2, after = { 0.436, 0.193, -1.786 }, before = { 0.496, 0.193, -1.716 }, },
		thunderRing = { kind = "ground", part = "Staff", contact = 1.53, tuned = 9, after = { 0.000, 0.165, -1.080 }, before = { 1.451, 1.425, -1.525 }, },
		tornado = { kind = "ground", part = "StaffOrb", contact = 1.31, tuned = 1, after = { 0.000, 4.473, -1.656 }, before = { 2.323, 3.655, 0.085 }, },
	},
}
