-- QUEUE-ALL6 자동 검증(나) - docs/phase/QUEUE-ALL6-report.md. 블록 id "ALL6(나)"(VerifyOnly로 단독 실행 - 무거운 블록과 같은 Play 금지).
--   G: 판 털기 로켓(첫 털기 · 활성 중 진입 · 25% 1회 · 무적 · 표적 제외 · 재발사 없음 · 반대쪽 착지).
--   B2: 체크포인트 강제 발견 → 전투 중 요청 = 거절(combat) · 정신 집중 중 피격 = 취소(hit) · 거절 · 취소는 체크포인트 쿨을 쓰지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local QueueAll6Verify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[ALL6][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return passCount, totalCount
	end
	return r
end
QueueAll6Verify.newRecorder = newRecorder

-- B2: 체크포인트 거절 · 취소 · 쿨 미소모
local function checkpointSection(r, player)
	local Travel = require(script.Parent.Travel)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local PlayerState = require(script.Parent.PlayerState)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	local CP = WorldMapData.checkpoints
	local rec = PlayerProfile.getCheckpoints(player)
	local oldFound = table.clone(rec.found)
	local oldAttr = workspace:GetAttribute(CP.attribute)
	workspace:SetAttribute(CP.attribute, true)
	-- 개발 명령 /gg cp all과 같은 일(강제 발견)
	table.clear(rec.found)
	local target
	for _, cp in ipairs(CP.list) do
		table.insert(rec.found, cp.id)
		if cp.hub then
			target = target or cp.id -- 허브 체크포인트(구역 잠금과 무관)
		end
	end
	target = target or CP.list[1].id
	Travel.onCheckpointsLoaded(player)
	local hp0 = PlayerState.getHp(player)
	PlayerState.setIncomingDamageMultiplierUntil(player, 1, 60, "all6cp") -- 다른 출처의 피해 배율(god 등)이 남아 있어도 이 시험 동안 실제 피해
	-- ① 전투 중(방금 피격) 요청 = 거절
	PlayerDamage.takeDamage(player, math.max(1, (PlayerState.getMaxHp(player) or 100) * 0.05), {})
	task.wait(0.6) -- Travel 0.25초 순회가 피격(hurtAt)을 기록
	local ok1, why1 = Travel.requestCheckpoint(player, target)
	r.check(("① 전투 중 체크포인트 요청: %s(%s) · 기대 false · combat"):format(tostring(ok1), tostring(why1)), ok1 == false and why1 == "combat")
	-- ② 전투가 끝난 뒤(가상 시각 +9초 = combatLockSeconds 8 밖) = 정신 집중 시작
	local future = os.clock() + WorldMapData.travel.combatLockSeconds + 1
	local ok2, why2 = Travel.requestCheckpoint(player, target, future)
	r.check(("② 전투 뒤 요청 = 정신 집중: %s(%s)"):format(tostring(ok2), tostring(why2)), ok2 == true and why2 == "casting")
	-- ③ 정신 집중 중 피격 = 취소(hit) · 순간이동 없음
	PlayerDamage.takeDamage(player, math.max(1, (PlayerState.getMaxHp(player) or 100) * 0.05), {})
	local result = Travel.pollRecall(player, future + 0.5)
	task.wait(0.3)
	r.check(("③ 집중 중 피격 = 취소: poll %s · 시전 중 %s(기대 hit · false)"):format(tostring(result), tostring(player:GetAttribute("RecallCastUntil") ~= nil)),
		(result == "hit" or result == nil) and player:GetAttribute("RecallCastUntil") == nil and player:GetAttribute("RecallCastUntil") == nil)
	-- ④ 거절 · 취소는 쿨을 안 쓴다: 다시 요청(전투 밖 가상 시각) = 쿨이 아니라 정신 집중
	local ok4, why4 = Travel.requestCheckpoint(player, target, os.clock() + WorldMapData.travel.combatLockSeconds + 2)
	r.check(("④ 거절 · 취소 뒤 다시 요청 = %s(%s) · 기대 casting(cooldown 아님)"):format(tostring(ok4), tostring(why4)), ok4 == true and why4 == "casting")
	Travel.cancelRecall(player, "key")
	-- 되돌리기
	PlayerState.clearIncomingDamageMultiplierSource(player, "all6cp")
	if hp0 then
		PlayerState.setHp(player, hp0)
	end
	table.clear(rec.found)
	for _, id in ipairs(oldFound) do
		table.insert(rec.found, id)
	end
	Travel.onCheckpointsLoaded(player)
	workspace:SetAttribute(CP.attribute, oldAttr)
	r.check(("되돌림: 찾은 체크포인트 %d개(원래 %d) · 시전 없음"):format(#rec.found, #oldFound), #rec.found == #oldFound and player:GetAttribute("RecallCastUntil") == nil)
end

function QueueAll6Verify.runLive(player, env)
	print("===ALL6 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	r.section("B2 체크포인트", function()
		checkpointSection(r, player)
	end)
	for _, extra in ipairs(QueueAll6Verify.extraSections) do
		r.section(extra.name, function()
			extra.fn(r, player, env)
		end)
	end
	env.restore(player)
	local pass, total = r.summary()
	print(("===ALL6 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

-- 다른 항목(F · G 등)이 붙이는 절(같은 Play · 같은 블록) - { name, fn(r, player, env) }
QueueAll6Verify.extraSections = {}

-- G: 심해 군주 판 털기 = 로켓단(실제 Player + 스탠드인 · 실제 BossEnvironment step)
local function rocketSection(r, player, env)
	local BossData = require(ReplicatedStorage.Shared.data.BossData)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local BossEnvironment = require(script.Parent.BossEnvironment)
	local BossPatterns = require(script.Parent.BossPatterns)
	local MonsterState = require(script.Parent.MonsterState)
	local PlayerState = require(script.Parent.PlayerState)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	local rocketCfg = BossData.bosses.abyssal_lord.environment.onStart.rocket
	local stage = BossData.stageInterval * 3
	BossEncounter.despawnFor(player)
	env.applyStage(player, stage)
	BossEncounter.setDebugForcedBoss(player, "abyssal_lord")
	BossArenaMap.debugNextSeed = 6101
	BossEncounter.spawnFor(player, stage)
	local model = BossEncounter.getActive(player)
	assert(model, "심해 군주 스폰 실패")
	local st = MonsterState.getBossPatternState(model)
	local root = player.Character.HumanoidRootPart
	local events = {}
	BossPatterns.debugEventHook = function(kind, rec)
		if kind == "rocket" then
			table.insert(events, rec)
		end
	end
	-- 스탠드인(활성 중에 털리는 쪽으로 걸어 들어오는 사람)
	local fakeRoot = { Position = root.Position + Vector3.new(0, 0, 0) }
	local fake = { Name = "RocketWalker", UserId = -9800, Parent = workspace }
	fake.Character = { FindFirstChild = function(_, c) return c == "HumanoidRootPart" and fakeRoot or nil end, FindFirstChildOfClass = function() return nil end }
	function fake:SetAttribute() end
	function fake:GetAttribute() return nil end
	PlayerState.init(fake)
	BossEncounter.debugAddMember(model, fake)
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	st.env = { phase = "armed", phaseEndsAt = 0, taken = {} }
	st.graceUntil = os.clock() + 999 -- 기본 패턴은 멈춘다(환경만)
	local t0 = os.clock()
	while (st.env.phase ~= "telegraph") and os.clock() - t0 < 6 do
		task.wait(0.1)
	end
	local z = st.env.zones and st.env.zones[1]
	assert(z, "판 털기 전조 없음")
	local arena = BossEncounter.getEncounter(player)
	-- 실제 Player = 털리는 절반 가운데(고정) · 스탠드인 = 반대쪽(처음엔 밖)
	root.Anchored = true
	root.CFrame = CFrame.new(Vector3.new(z.center.X, st.floorY + 3, z.center.Z))
	local away = Vector3.new(z.center.X, 0, z.center.Z)
	fakeRoot.Position = Vector3.new(-away.X, st.floorY + 3, -away.Z) -- 대칭 = 안전한 쪽(아레나 중심이 원점이 아니면 아래에서 다시)
	local center = require(script.Parent.MonsterState).getSpawnPosition(model) or Vector3.zero
	fakeRoot.Position = Vector3.new(2 * center.X - z.center.X, st.floorY + 3, 2 * center.Z - z.center.Z)
	local maxHp = PlayerState.getMaxHp(player)
	while st.env.phase ~= "active" and os.clock() - t0 < 12 do
		task.wait(0.05)
	end
	task.wait(0.2)
	local hpAfter = PlayerState.getHp(player)
	local mine = events[1]
	r.check(("① 첫 털기: 판 위 실제 Player 로켓 %s · 피해 %.1f%%(기대 25%%) · 최고 높이 = 바닥 + %d(%.1f)"):format(tostring(mine ~= nil), (maxHp - hpAfter) / maxHp * 100, rocketCfg.peakStuds, mine and (mine.peakY - st.floorY) or -1),
		mine ~= nil and math.abs((maxHp - hpAfter) / maxHp - 0.25) < 0.02 and mine and math.abs(mine.peakY - st.floorY - rocketCfg.peakStuds) < 0.01)
	r.check(("② 나는 동안: 표적 제외 %s · 무적(피해 시도 → %.0f)"):format(tostring(BossEnvironment.isRocketing(player)), (function()
		local before = PlayerState.getHp(player)
		PlayerDamage.takeDamage(player, maxHp * 0.3, {})
		return before - PlayerState.getHp(player)
	end)()), BossEnvironment.isRocketing(player) and BossEncounter.nearestLivingMember(model, root.Position) ~= player)
	local landOk = mine and (Vector3.new(mine.land.X, 0, mine.land.Z) - Vector3.new(z.center.X, 0, z.center.Z)).Magnitude > z.halfLength
	r.check(("③ 착지 = 털리지 않는 쪽(털린 절반 가운데에서 %.0f stud)"):format(mine and (Vector3.new(mine.land.X, 0, mine.land.Z) - Vector3.new(z.center.X, 0, z.center.Z)).Magnitude or -1), landOk == true)
	-- ④ 활성 중 걸어 들어오면 같다(스탠드인을 털리는 절반으로)
	local n0 = #events
	fakeRoot.Position = Vector3.new(z.center.X, st.floorY + 3, z.center.Z) + Vector3.new(4, 0, 0)
	task.wait(0.4)
	r.check(("④ 판이 빈 동안 들어온 사람도 로켓: 새 로켓 %d"):format(#events - n0), #events - n0 == 1)
	-- ⑤ 같은 발동에서 두 번 없음(실제 Player는 계속 그 자리 - 고정)
	task.wait(0.6)
	local mineCount = 0
	for _, e in ipairs(events) do
		mineCount += e.player == player and 1 or 0
	end
	r.check(("⑤ 같은 발동 재발사 없음: 실제 Player 로켓 %d번"):format(mineCount), mineCount == 1)
	-- ⑥ 끝: 서버 도착 확인(고정 루트는 곡선을 못 그림 → 서버가 착지 자리로 옮긴다)
	task.wait(rocketCfg.upSeconds + rocketCfg.hangSeconds + rocketCfg.downSeconds + 0.6)
	local d = mine and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(mine.land.X, 0, mine.land.Z)).Magnitude or 999
	r.check(("⑥ 끝: 착지 자리와 %.1f stud(≤ %d) · 로켓 끝 %s"):format(d, rocketCfg.landToleranceStuds, tostring(not BossEnvironment.isRocketing(player))), d <= rocketCfg.landToleranceStuds and not BossEnvironment.isRocketing(player))
	BossPatterns.debugEventHook = nil
	root.Anchored = false
	BossEncounter.despawnFor(player)
	BossEncounter.setDebugForcedBoss(player, nil)
	PlayerState.clearIncomingDamageMultiplierSource(player, "bossRocket")
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	r.check("되돌림: 보스 정리 · 체력 가득", BossEncounter.getActive(player) == nil)
end
table.insert(QueueAll6Verify.extraSections, { name = "G 판 털기 로켓", fn = rocketSection })

-- F: 운영 명령(OpsHook = 실제 채팅 경로와 같은 Ops.handle) · 탐지 창 마감
local function opsSection(r, player)
	local hook = game:GetService("ServerStorage"):FindFirstChild("OpsHook")
	assert(hook, "OpsHook 없음(Studio 전용)")
	local OpsConfig = require(script.Parent.OpsConfig)
	local allowed = table.find(OpsConfig.userIds, player.UserId) ~= nil
	if not allowed then
		r.check("운영 허용 계정 아님(개발 계정) - 운영 절 건너뜀", true)
		return
	end
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local uid = tostring(player.UserId)
	local inspect = hook:Invoke(player, "/ops inspect " .. uid)
	r.check(("inspect: %s"):format(tostring(inspect):sub(1, 90)), type(inspect) == "string" and inspect:find("프로필", 1, true) ~= nil)
	local g0 = PlayerProfile.getGold(player)
	local rv = hook:Invoke(player, "/ops revoke " .. uid .. " gold 7")
	local g1 = PlayerProfile.getGold(player)
	PlayerProfile.addGold(player, g0 - g1) -- 되돌림
	r.check(("revoke gold 7: %s · %d → %d(되돌림 %d)"):format(tostring(rv), g0, g1, PlayerProfile.getGold(player)), g0 - g1 == math.min(7, g0) and PlayerProfile.getGold(player) == g0)
	local bad = hook:Invoke(player, "/ops revoke " .. uid .. " gold -5")
	r.check(("revoke 음수 = 거절: %s"):format(tostring(bad)), bad == "bad_args")
	local preview = hook:Invoke(player, "/ops rollback " .. uid .. " 1")
	r.check(("rollback 미리보기(실행 안 함): %s"):format(tostring(preview):sub(1, 80)), type(preview) == "string" and (preview:find("미리보기", 1, true) or preview == "no_version" or preview:find("failed", 1, true)) ~= nil)
	local noConfirm = hook:Invoke(player, "/ops rollback confirm 000000")
	r.check(("없는 확인 번호 = 실행 안 함: %s"):format(tostring(noConfirm)), tostring(noConfirm):find("no_pending", 1, true) ~= nil)
	local banBad = hook:Invoke(player, "/ops ban " .. uid .. " 2y 시험")
	r.check(("ban 잘못된 기간 = 거절(실제 차단 없음): %s"):format(tostring(banBad)), banBad == "bad_args")
	-- 탐지: 창 값을 기준 위로 넣고 마감 → 의심 기록
	local SM = require(script.Parent.SuspicionMonitor)
	local s = SM.stateOf(player)
	s.hits = require(ReplicatedStorage.Shared.data.SecurityOpsConfig).detect.hitsPerMin + 1
	s.flaggedAt.suspect_hits = nil
	local window, flagged = SM.closeWindow(player, os.clock())
	r.check(("탐지: 명중 %d/분 → 기록 %s(처벌 없음 · 접속 유지 %s)"):format(window.hits, table.concat(flagged, ","), tostring(player.Parent ~= nil)), table.find(flagged, "suspect_hits") ~= nil and player.Parent ~= nil)
end
table.insert(QueueAll6Verify.extraSections, { name = "F 운영 명령", fn = opsSection })

return QueueAll6Verify
