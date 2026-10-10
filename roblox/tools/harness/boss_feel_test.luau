-- BOSS-NIGHT-3(BOSS-FEEL) 하네스: 실제 서버 핸들러(BossHandlersBR1)를 가짜 kit로 돌린다.
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py BossHandlersBR1) ECON_RES=res_feel.txt python build_run.py boss_feel_test.luau
local FAKE_NOW = 1000
local realos = os
os = setmetatable({ clock = function() return FAKE_NOW end }, { __index = realos }) -- BOSS-NIGHT-3 2단계 CC 시험(가짜 시계 - save_launch_test와 같은 방식)
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then
		pass += 1
	end
	print(("[FEEL] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

local ok, err = pcall(function()
	local H = MODS.BossHandlersBR1
	local BR, BF = MODS.BossRules, MODS.BossFramework
	local walk = MODS.WorldConfig.playerWalkSpeedStuds

	-- 가짜 kit: 피해 호출만 센다
	local hits = {}
	local kit = {
		xz = function(v) return Vector3.new(v.X, 0, v.Z) end,
		zoneOf = function() return nil end,
		clipToZone = function(origin, dir, zone, margin) return 60 end,
		originOf = function() return nil end,
		victims = function(st) return st.fakeVictims end,
		send = function() end,
		judgeBegin = function() end,
		judgeEnd = function() end,
		debugEvent = function() end,
		endSkill = function(model, st) st.ended = true end,
		applySkillDamage = function(model, data, skill, player) table.insert(hits, player) end,
		runHitEffects = function(c, effects, v) for _, e in ipairs(effects or {}) do table.insert(hits, e.type) end end,
	}
	H.register({}, kit)

	-- ① 수정 여왕 분신 돌격: 보스 앞 5 stud(세 줄이 다 겹치는 자리)에 선 근접 유저 1명
	local d = BR.buildInstanceData(100, "crystal_queen", 1)
	local g = BF.applyV3(BF.applyBodyEdge(d, "crystal_queen_v2", walk), "crystal_queen_v2")
	local skill = g.skills.mirrorDash
	local player = { Name = "near" }
	local root = { Position = Vector3.new(5, 0, 0) }
	local st = { floorY = 0, fakeVictims = { { player = player, root = root, groundFeet = Vector3.new(5, 0, 0) } } }
	local c = { st = st, skill = skill, model = {}, data = g, position = Vector3.new(0, 0, 0), targetRoot = root, now = 0 }
	H.boomerang.start(c)
	local t = 0
	while not st.ended and t < 20 do
		t += 1 / 30
		c.now = t
		H.boomerang.step(c)
	end
	local dmg, order = 0, {}
	for _, h in ipairs(hits) do
		if h == player then dmg += 1 end
		table.insert(order, h == player and "hit" or h)
	end
	check("분신 돌격 = 맞을 때 둔화 · 시전 끝난 뒤 수정 표식 1회(분신 피해엔 표식 없음)", table.concat(order, ",") == "hit,slow,hit,slow,crystalMark" and skill.ignoresCrystalMark == true, table.concat(order, ","))
	hits = { player, player }
	check("분신 돌격 3줄 겹침 = 1인 가는 길 1 · 오는 길 1(한 시전 맞음 기록 공유)", dmg == 2, ("줄 %d · 맞음 %d회(옛 = 줄마다 따로 최대 6)"):format(#st.boomLines, #hits))

	-- ② 새 몸이 얹는 스킬도 스테이지 곡선(이속 보정 · 반경 · 개수 · 전조 맞춤) · 수정 미사일 / 얼음 상아 = 개수 유지 + 한 발 피해 비례
	local function inst(id, stage)
		local dd = BR.buildInstanceData(stage, id, 1)
		return BF.applyV3(BF.applyBodyEdge(dd, id .. "_v2", walk), id .. "_v2"), dd
	end
	local q50, q150 = inst("crystal_queen", 50).skills.magicMissiles, inst("crystal_queen", 150).skills.magicMissiles
	check("수정 미사일 5발 유지 · 1 ~ 100단계 합계 0.36(5 × 0.072) · 101+ 0.60", q50.count == 5 and q150.count == 5 and math.abs(q50.count * q50.damage.multiplier - 0.36) < 1e-6 and math.abs(q150.count * q150.damage.multiplier - 0.60) < 1e-6,
		("50: %d × %.3f · 150: %d × %.3f"):format(q50.count, q50.damage.multiplier, q150.count, q150.damage.multiplier))
	local t50 = inst("frost_giant", 50).skills.tuskShot
	check("얼음 상아 2발 유지 · 1 ~ 100단계 한 발 × 1/2", t50.count == 2 and math.abs(t50.damage.multiplier - 1.8 * 0.6 / 2) < 1e-6, ("%d × %.3f"):format(t50.count, t50.damage.multiplier))
	local g100, d100 = inst("section_guardian", 100)
	local banana = g100.skills.banana
	check("바나나 반경 = 이속 보정(skillRangeScale) × 곡선 반경 · 개수 곡선(1)", math.abs(banana.radiusStuds - 2 * d100.skillRangeScale) < 1e-6 and banana.count == 1, ("r %.2f(보정 %.3f)"):format(banana.radiusStuds, d100.skillRangeScale))
	local s600 = inst("storm_lord", 600).skills.swordWave
	check("검기 개수 = 곡선(501+ ×1.5 → 2)", s600.count == 2, ("count %d"):format(s600.count))

	-- ③ 2단계 CC(실제 server/PlayerCC · PlayerStun · PlayerState - 값 = BossData.mechanics.cc)
	local CC, Stun, PS = MODS.PlayerCC, MODS.PlayerStun, MODS.PlayerState
	local cfg = MODS.BossData.mechanics.cc
	local p = { Name = "cc" }
	PS.init(p)
	local function at(dt) FAKE_NOW += dt end
	local s1 = CC.stagger(p)
	local walk0 = PS.getMoveSpeedMultiplier(p)
	at(0.5); local s2 = CC.stagger(p)
	local stunOk = Stun.stun(p, 0.7)
	at(0.51); local s3 = CC.stagger(p) -- 경직 면역(0.2 + 0.8) 끝 · 기절 면역(2.0) 안
	check("경직 = 걷기 0(루트 고정 아님) · 면역 0.8 · 경직 면역은 기절을 안 막음 · 기절 면역은 경직을 안 막음", s1 and walk0 == 0 and not s2 and stunOk and s3 and cfg.stagger.seconds == 0.2,
		("걸림 %s · 걷기 ×%.1f · 0.5초 뒤 %s · 기절 %s · 1.01초 뒤 %s"):format(tostring(s1), walk0, tostring(s2), tostring(stunOk), tostring(s3)))
	check("기절 중 대시 = 거절(stunned)", CC.dashBlockedReason(p) == "stunned", tostring(CC.dashBlockedReason(p)))
	at(3)
	local q = { Name = "launch" }
	PS.init(q)
	local k1 = CC.tryLaunch(q, 4, 1)
	local k2 = CC.tryLaunch(q, 4, 1)
	local a1 = CC.tryLaunch(q, 6, 1) -- 넉백 면역은 띄움을 안 막는다
	local dashEarly = CC.dashBlockedReason(q)
	at(0.31); local dashLate = CC.dashBlockedReason(q)
	local k3 = CC.tryLaunch(q, 3, 1) -- 띄움 면역은 넉백도 막는다
	local esc = CC.tryLaunch(q, 14, 1, true)
	at(1 + 1.0 + 0.01); local a2 = CC.tryLaunch(q, 6, 1)
	check("넉백(높이 < 5)/띄움(≥ 5) 면역 · 띄움 면역 ⊃ 넉백 · 던짐 = 면역 무시", k1 and not k2 and a1 and not k3 and esc and a2,
		("%s %s %s %s %s %s"):format(tostring(k1), tostring(k2), tostring(a1), tostring(k3), tostring(esc), tostring(a2)))
	check("띄워진 뒤 0.3초 전 대시 거절 · 뒤 허용", dashEarly == "launched" and dashLate == nil, ("%s → %s"):format(tostring(dashEarly), tostring(dashLate)))
	local r = { Name = "slow" }
	PS.init(r)
	CC.slow(r)
	local slowMul = PS.getMoveSpeedMultiplier(r)
	CC.crystalMark(r, "crystal_queen")
	local m1, m2 = CC.markMultiplier(r, "crystal_queen"), CC.markMultiplier(r, "storm_lord")
	CC.crystalMark(r, "crystal_queen") -- 새로 고침만
	local m3 = CC.markMultiplier(r, "crystal_queen")
	at(3.01)
	check("둔화 = 걷기 × 0.7(이속 보너스와 따로 - 대시 거리 무관) · 3초", math.abs(slowMul - 0.7) < 1e-9 and PS.getMoveSpeedMultiplier(r) == 1, ("×%.2f → ×%.2f"):format(slowMul, PS.getMoveSpeedMultiplier(r)))
	check("수정 표식 = 건 보스 피해만 × 2 · 겹쳐도 × 2 · 3초 뒤 × 1", m1 == 2 and m2 == 1 and m3 == 2 and CC.markMultiplier(r, "crystal_queen") == 1, ("%d %d %d → %d"):format(m1, m2, m3, CC.markMultiplier(r, "crystal_queen")))
	local qm = inst("crystal_queen", 100).skills.magicMissiles
	check("수정 미사일 마지막 발 = 경직(옛 기절 0.25)", qm.lastOnHit[1].type == "stagger", qm.lastOnHit[1].type)
end)
if not ok then
	print("[FEEL] 하네스 에러 " .. tostring(err))
end
print(("[FEEL] 끝 %d/%d"):format(pass, total))
