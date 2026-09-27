-- W2 자동 검증 - 공격 궤적 · 판정 일치 · 투사체 · 피해 숫자 준비 (+ 파트 0 회오리 지연 되돌림).
--   (가) 순수: 스킨 금지 검사 · 단계 표(스킨 무관) · 궤적 크기 = 판정 함수 · 근접 모션 타격 프레임 = 1프레임 · 서버 판정 시각 불변.
--   (나) 실제 서버: 파트 0 회오리 휘말림 되돌림 0(Play를 지연 0.25로) · W2-3 피해 이벤트 구조(실제 평타 경로) ·
--        클라 표본 창(ReplicatedStorage Attribute W2Phase = "melee" → "bow" → "done"): 가만한 몹 · 움직이는 몹을 세워 두고 클라 기록기(MCP execute_luau)가 실제 클릭으로 친다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local TrailData = require(ReplicatedStorage.Shared.data.TrailData)
local TrailSkin = require(ReplicatedStorage.Shared.TrailSkin)
local MotionTiming = require(ReplicatedStorage.Shared.MotionTiming)
local PlayerMotionData = require(ReplicatedStorage.Shared.data.PlayerMotionData)
local ProjectileConfig = require(ReplicatedStorage.Shared.data.ProjectileConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[W2][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[W2][%s] %s"):format(tag, label))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return pass, total
	end
	return r
end


function V.runPure()
	print("===W2 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("스킨 금지 검사", function()
		for id, skin in pairs(TrailData.skins) do
			local ok, why = TrailSkin.check(skin)
			r.check(("스킨 %s 통과 %s %s"):format(id, tostring(ok), table.concat(why, " · ")), ok)
		end
		local bad = {
			{ "주황", { core = Color3.fromRGB(255, 170, 60), edge = Color3.fromRGB(200, 120, 40) } },
			{ "빨강", { core = Color3.fromRGB(255, 90, 90), edge = Color3.fromRGB(160, 30, 30) } },
			{ "흰 + 자홍", { core = Color3.fromRGB(250, 250, 250), edge = Color3.fromRGB(230, 60, 220) } },
			{ "굵기 칸(모양 바꾸기)", { core = Color3.fromRGB(200, 230, 255), edge = Color3.fromRGB(120, 160, 210), width = 3 } },
		}
		for _, b in ipairs(bad) do
			local ok, why = TrailSkin.check(b[2])
			r.check(("금지 예 %s 거부 %s(%s)"):format(b[1], tostring(not ok), table.concat(why, " · ")), not ok)
		end
		local fallback, fid = TrailSkin.resolve("없는스킨")
		r.check(("없는 스킨 → 기본 %s"):format(fid), fid == TrailData.defaultSkin and fallback == TrailData.skins.default)
	end)

	r.section("리본 규칙(스킨 무관 · 강공격 > 1 · 2타)", function()
		local R, P = TrailData.ribbon, TrailData.projectile
		r.check(("칼날 리본 수명 %.2f(0.15 ~ 0.25) · 시작 투명도 1·2타 %.2f > 강공격 %.2f · 빛남 %.2f < %.2f · 강공격 광택 리본 %.1f stud"):format(R.lifetime, R.startTransparency, R.heavy.startTransparency, R.lightEmission, R.heavy.lightEmission, R.heavy.gloss.outerStuds),
			R.lifetime >= 0.15 and R.lifetime <= 0.25 and R.startTransparency > R.heavy.startTransparency and R.lightEmission < R.heavy.lightEmission and R.heavy.gloss.outerStuds > 0)
		r.check(("리본 직업 = 대검 %s · 쌍검 %s · 활 %s · 지팡이 %s(근접만)"):format(tostring(R.classes.greatsword), tostring(R.classes.dualblade), tostring(R.classes.bow), tostring(R.classes.healer)),
			R.classes.greatsword and R.classes.dualblade and not R.classes.bow and not R.classes.healer)
		r.check(("투사체 꼬리: 화살 %.2f초(0.3 ~ 0.4) · 강공격 %.2f · 구슬 폭 %.2f > 화살 %.2f"):format(P.arrow.lifetime, P.arrow.heavyLifetime, P.orb.width, P.arrow.width),
			P.arrow.lifetime >= 0.3 and P.arrow.lifetime <= 0.4 and P.arrow.heavyLifetime > P.arrow.lifetime and P.orb.heavyLifetime > P.orb.lifetime and P.orb.width > P.arrow.width)
		local leak = {}
		for id, skin in pairs(TrailData.skins) do
			for _, key in ipairs({ "width", "lifetime", "startTransparency", "heavy", "gloss", "widthTaper" }) do
				if skin[key] ~= nil then
					table.insert(leak, id .. "." .. key)
				end
			end
		end
		r.check(("스킨이 너비 · 수명 · 강공격 칸을 안 가짐(%s)"):format(#leak == 0 and "없음" or table.concat(leak, ", ")), #leak == 0)
	end)

	r.section("모션 타격 프레임 = 판정 시각", function()
		local frame = 1 / 60
		for _, classId in ipairs({ "greatsword", "dualblade", "bow", "healer" }) do
			for _, speed in ipairs({ 1, 2.5 }) do
				for _, hit in ipairs({ { "1타", 1 }, { "2타", 2 }, { "3타(강)", 3, true }, { "공중", 1, false, true }, { "공중 3타", 3, true, true } }) do
					local anim = MotionTiming.hitSeconds(classId, hit[2], speed, hit[3], hit[4])
					local server = MotionTiming.serverSeconds(classId, hit[2], speed, hit[3], hit[4])
					r.check(("%s ×%.1f %s: 모션 타격 %.4f · 서버 판정 %.4f(요청 기준 · 비행 제외) · 차이 %.4f ≤ 1프레임"):format(classId, speed, hit[1], anim, server, math.abs(anim - server)), math.abs(anim - server) <= frame + 1e-6)
				end
			end
		end
		r.check(("서버 판정 시각 불변: 근접 0 · 활 %.4f · 지팡이 %.4f(W1 값 0.429 · 0.1925)"):format(PlayerMotionData.rangedReleaseSeconds.bow, PlayerMotionData.rangedReleaseSeconds.healer),
			math.abs(PlayerMotionData.rangedReleaseSeconds.bow - 0.429) < 1e-9 and math.abs(PlayerMotionData.rangedReleaseSeconds.healer - 0.1925) < 1e-9 and MotionTiming.serverSeconds("greatsword", 1, 1) == 0)
		r.check(("투사체 판정 값 불변: 화살 %d · 구슬 %d stud/s · 허용 폭 %d"):format(ProjectileConfig.speedStudsPerSec.arrow, ProjectileConfig.speedStudsPerSec.orb, ProjectileConfig.hitToleranceStuds),
			ProjectileConfig.speedStudsPerSec.arrow == 90 and ProjectileConfig.speedStudsPerSec.orb == 55 and ProjectileConfig.hitToleranceStuds == 6)
	end)

	local pass, total = r.summary()
	print(("===W2 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===W2 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local H = require(script.Parent.BR1Verify).helpers
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local MonsterState = require(script.Parent.MonsterState)
	local MonsterSpawner = require(script.Parent.MonsterSpawner)
	local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
	local HeightGuard = require(script.Parent.HeightGuard)
	local DamageFeed = require(script.Parent.DamageFeed)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local FLOOR = BossArenaMap.floorTopY()
	local dev = ServerStorage:FindFirstChild("DevCommandHook")
	local attackHook = ServerStorage:FindFirstChild("AttackHook")

	r.section("파트 0 회오리 휘말림(실제 Player · 되돌림 0)", function()
		local model, data, encounter = H.spawnBoss(player, env, "storm_lord", 4402, 15)
		assert(model, "보스 스폰 실패")
		local zone = WorldConfig.zones[encounter.zoneKey]
		root.Anchored = false
		character:PivotTo(CFrame.new(zone.center + Vector3.new(12, FLOOR + 3, 0)))
		HeightGuard.reset(player)
		task.wait(1.2)
		HeightGuard.debugOff = false
		local hs = HeightGuard.getState(player)
		local reverts0, h0 = hs and hs.reverts or 0, (hs and hs.hReverts) or 0
		local corrections0 = #require(script.Parent.BossArenaContainment).corrections()
		local since = os.clock()
		local st = MonsterState.getBossPatternState(model)
		st.graceUntil = 0
		local start = root.Position
		BossPatterns.force(model, data, "whirl")
		local maxRise = 0
		H.drive(player, root, model, data, 7, function()
			maxRise = math.max(maxRise, root.Position.Y - start.Y)
			return false
		end)
		local reverts = (hs and hs.reverts or 0) - reverts0
		local hreverts = ((hs and hs.hReverts) or 0) - h0
		local corrections = #require(script.Parent.BossArenaContainment).corrections() - corrections0
		local flagged = HeightGuard.flaggedSince(player, since)
		r.check(("회오리 휘말림: 발사 %s · 최고 +%.1f · 높이 되돌림 %d · 수평 되돌림 %d · 맵 이탈 복귀 %d · 표시 %s(기대 0 0 0 false - Play 지연 설정은 edit IncomingReplicationLag)"):format(
			tostring(st.lastLaunch ~= nil), maxRise, reverts, hreverts, corrections, tostring(flagged)),
			st.lastLaunch ~= nil and maxRise > 3 and reverts == 0 and hreverts == 0 and corrections == 0 and not flagged)
	end)
	HeightGuard.debugOff = true -- 리뷰: 섹션이 중간에 실패해도 정리(보스 남김 · 검사 켜짐 방지)
	BossEncounter.despawnFor(player)

	-- 표본 자리 = 지금 캐릭터 자리(Play 지연 중엔 서버가 옮긴 캐릭터를 클라가 옛 자리로 덮는다 - 옮기지 않는다) · 18 앞까지 가림 없는 방향
	local spawned = {}
	local base, fwd, right
	local function pickSpot()
		root.Anchored = false
		base = root.Position
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		for i = 0, 15 do
			local a = i / 16 * 2 * math.pi
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local clear = true
			for _, off in ipairs({ -6, 0, 6 }) do
				if workspace:Raycast(base + Vector3.new(-d.Z, 0, d.X) * off, d * 18, params) then
					clear = false
				end
			end
			if clear then
				fwd = d
				break
			end
		end
		fwd = fwd or Vector3.new(0, 0, -1)
		right = Vector3.new(-fwd.Z, 0, fwd.X)
	end
	local function spawnMob(position, tag)
		local mob = MonsterSpawner.spawn(MonsterData.tier1, position, nil, {})
		mob.PrimaryPart.Anchored = true
		mob:PivotTo(CFrame.new(position))
		mob:SetAttribute("W2Mob", tag)
		mob.Name = "W2Mob_" .. tag -- 클라 기록기 · MCP 클릭이 이름으로 찾는다
		MonsterState.setDamageTakenMultiplier(mob, 1e-4) -- 표본 동안 안 죽게(맞았는지 = 결과의 missed · 피해 > 0)
		table.insert(spawned, mob)
		return mob
	end

	r.section("W2-3 피해 이벤트 구조(실제 평타 경로 · 서버 확정 값만)", function()
		dev:Invoke(player, "/gg class greatsword")
		task.wait(0.5)
		pickSpot()
		local mob = spawnMob(base + fwd * 7, "feed")
		MonsterState.setDamageTakenMultiplier(mob, 1)
		local got
		DamageFeed.debugHook = function(record)
			got = got or record
		end
		task.wait(0.6)
		attackHook:Invoke(player, mob.PrimaryPart.Position, false)
		task.wait(0.2)
		local near = got and (got.hitPosition - mob.PrimaryPart.Position).Magnitude
		r.check(("이벤트 = 대상 %s · 적중 위치(서버) 어긋남 %s · 확정 피해 %s · 종류 %s · 공격자 %s · 치명 %s(플래그 꺼짐 = 방송 0 · 구조만)"):format(
			tostring(got and got.target == mob), near and ("%.2f"):format(near) or "-", tostring(got and got.amount), tostring(got and got.kind), tostring(got and got.attackerUserId == player.UserId), tostring(got and got.isCrit)),
			got ~= nil and got.target == mob and near < 0.5 and got.amount > 0 and got.kind == "normal" and got.attackerUserId == player.UserId)
	end)
	DamageFeed.debugHook = nil

	r.section("클라 표본 창(근접 궤적 시각 · 투사체 화면 ↔ 서버)", function()
		-- 1) 근접: 가만한 몹 1(사거리 안 7) - 클라 기록기가 실제 클릭으로 치고 궤적 시각(W2TrailDebug) ↔ 서버 판정 시각(Player Attribute W2JudgedAt)을 비교
		dev:Invoke(player, "/gg class greatsword")
		pickSpot()
		local still = spawnMob(base + fwd * 7, "still")
		ReplicatedStorage:SetAttribute("W2Phase", "melee")
		local t0 = os.clock()
		while os.clock() - t0 < 60 and ReplicatedStorage:GetAttribute("W2Phase") == "melee" do -- C2 묶음 Play: 40 → 60(도구 왕복)
			H.fullHeal(player)
			if not still.Parent then -- C2 묶음 Play: 표본이 죽으면 같은 자리에 다시(잡몹은 받는 피해 배율이 안 먹는다 - W2 함정)
				still = spawnMob(base + fwd * 7, "still")
			end
			task.wait(0.2)
		end
		-- 2) 활: 가만한 몹(10 앞) + 움직이는 몹(10 앞 오른쪽 · 반경 4 원 · 초당 8) - 발사 후 비행 중 몹이 움직여 허용 폭 경계를 오간다
		dev:Invoke(player, "/gg class bow")
		still:PivotTo(CFrame.new(base + fwd * 10 - right * 5))
		local center = base + fwd * 10 + right * 6
		local moving = spawnMob(center + right * 4, "moving")
		ReplicatedStorage:SetAttribute("W2Phase", "bow")
		t0 = os.clock()
		local angle = 0
		while os.clock() - t0 < 240 and ReplicatedStorage:GetAttribute("W2Phase") == "bow" do -- C2 묶음 Play: 110 → 240(50발 이상)
			local dt = RunService.Heartbeat:Wait()
			angle += dt * 8 / 4
			if not moving.Parent then
				moving = spawnMob(center + right * 4, "moving")
			end
			if not still.Parent then
				still = spawnMob(base + fwd * 10 - right * 5, "still")
			end
			if moving.Parent then
				moving:PivotTo(CFrame.new(center + right * (math.cos(angle) * 4) + fwd * (math.sin(angle) * 4)))
			end
			H.fullHeal(player)
		end
		r.note(("클라 표본 창 끝: %.0f초(결과 = 클라 기록기 출력 W2CLIENT 줄)"):format(os.clock() - t0))
	end)
	ReplicatedStorage:SetAttribute("W2Phase", "done")
	for _, mob in ipairs(spawned) do
		if mob.Parent then
			MonsterSpawner.despawn(mob)
		end
	end
	HeightGuard.debugOff = true
	if root then
		root.Anchored = false
	end
	env.restore(player)
	local pass, total = r.summary()
	print(("===W2 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
