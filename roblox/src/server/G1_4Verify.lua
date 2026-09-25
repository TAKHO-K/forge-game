-- G1-4 자동 검증(docs/phase/G1-4-report.md) - 보스맵 잔류 · 다음 / 다시 도전 / 마을 · 90초 자동 이동 · 맡아 둔 드랍.
--   (나)만 - 실제 처치 경로(MonsterState.applyDamage → CombatResolution.resolveHit)로 솔로 보스를 잡는다. 체인이 꺼 둔 잔류(debugLingerOff)를 이 블록에서만 켠다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)

local G1_4Verify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[G1-4][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

function G1_4Verify.runLive(player, env)
	print("===G1-4 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossLinger = require(script.Parent.BossLinger)
	local CombatResolution = require(script.Parent.CombatResolution)
	local MonsterState = require(script.Parent.MonsterState)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local savedOff = BossEncounter.debugLingerOff
	BossEncounter.debugLingerOff = false
	local STAGE = BossData.stageInterval

	local function root()
		local character = player.Character
		return character and character:FindFirstChild("HumanoidRootPart")
	end
	local function spawnAndKill()
		BossEncounter.despawnFor(player)
		env.applyStage(player, STAGE)
		BossEncounter.spawnFor(player, STAGE)
		local model = BossEncounter.getActive(player)
		assert(model, "보스가 안 섰다")
		local isDead = MonsterState.applyDamage(model, 1e12, STAGE, player)
		CombatResolution.resolveHit(player, model, isDead)
		return BossEncounter.getEncounter(player)
	end
	local function inArena(encounter)
		local zone = encounter and WorldConfig.zones[encounter.zoneKey]
		local rp = root()
		return zone ~= nil and rp ~= nil and (Vector3.new(rp.Position.X, 0, rp.Position.Z) - Vector3.new(zone.center.X, 0, zone.center.Z)).Magnitude <= zone.radius
	end

	r.section("잔류 · 다시 도전", function()
		local encounter = spawnAndKill()
		local slot = encounter and encounter.slot
		r.check(("처치 뒤: 잔류 %s · 보스 모델 %s(기대 없음) · 아레나 안 %s · 슬롯 %s 유지 · 남은 %.0f초(기대 %d)"):format(tostring(BossEncounter.isLingering(player)),
			tostring(BossEncounter.getActive(player)), tostring(inArena(encounter)), tostring(slot), encounter and (encounter.lingerUntil - os.clock()) or -1, BossData.lingerSeconds),
			BossEncounter.isLingering(player) and BossEncounter.getActive(player) == nil and inArena(encounter) and slot ~= nil)
		local ok, result = BossLinger.choose(player, "retry")
		local model = BossEncounter.getActive(player)
		local hp, maxHp = 0, 1
		if model then
			hp, maxHp = MonsterState.getBossHp(model)
		end
		r.check(("다시 도전: %s(%s) · 보스 %s · HP %.0f%% · 같은 슬롯 %s · 잔류 %s(기대 false) · 기록 시간 새로 %s"):format(tostring(ok), tostring(result), tostring(model ~= nil),
			hp / math.max(maxHp, 1) * 100, tostring(encounter.slot == slot), tostring(BossEncounter.isLingering(player)), tostring(os.clock() - encounter.startedAt < 1)),
			ok and model ~= nil and hp >= maxHp and encounter.slot == slot and not BossEncounter.isLingering(player) and os.clock() - encounter.startedAt < 1)
	end)

	r.section("마을 · 다음 · 90초", function()
		spawnAndKill()
		local ok, result = BossLinger.choose(player, "town")
		r.check(("마을: %s(%s) · 보스전 %s(기대 nil) · 스테이지 %d(기대 %d 그대로)"):format(tostring(ok), tostring(result), tostring(BossEncounter.getEncounter(player)), PlayerProfile.getInfiniteStage(player), STAGE),
			ok and result == "town" and BossEncounter.getEncounter(player) == nil and PlayerProfile.getInfiniteStage(player) == STAGE)
		spawnAndKill()
		ok, result = BossLinger.choose(player, "next")
		r.check(("다음: %s(%s) · 보스전 %s · 스테이지 %d(기대 %d)"):format(tostring(ok), tostring(result), tostring(BossEncounter.getEncounter(player)), PlayerProfile.getInfiniteStage(player), STAGE + 1),
			ok and result == "next" and BossEncounter.getEncounter(player) == nil and PlayerProfile.getInfiniteStage(player) == STAGE + 1)
		local encounter = spawnAndKill()
		encounter.lingerUntil = os.clock() - 0.1 -- 90초가 지난 것으로
		local waited = 0
		while BossEncounter.getEncounter(player) and waited < 3 do
			waited += task.wait(0.1)
		end
		r.check(("90초 무입력: %.1f초 뒤 보스전 %s · 스테이지 %d(기대 %d - 자동 다음)"):format(waited, tostring(BossEncounter.getEncounter(player)), PlayerProfile.getInfiniteStage(player), STAGE + 1),
			BossEncounter.getEncounter(player) == nil and PlayerProfile.getInfiniteStage(player) == STAGE + 1)
	end)

	r.section("맡아 둔 드랍", function()
		spawnAndKill()
		local flushed = nil
		BossLinger.holdDrops({ { player = player, item = { grade = "normal" } } }, function(entries, position)
			flushed = { count = #entries, position = position }
		end)
		local before = flushed
		BossLinger.choose(player, "town")
		r.check(("가방 가득 드랍: 잔류 중 떨어뜨림 %s(기대 없음) · 마을로 돌아가는 순간 %s개(기대 1)"):format(tostring(before), tostring(flushed and flushed.count)), before == nil and flushed ~= nil and flushed.count == 1)
	end)

	BossEncounter.despawnFor(player)
	BossEncounter.debugLingerOff = savedOff
	env.restore(player)
	task.wait(3) -- 잡힌 보스 사체가 치워질 시간(MonsterSpawner.despawn 사체 유지)
	local orphan = 0
	for _, m in ipairs(MonsterState.getAllModels()) do
		local d = MonsterState.getData(m)
		if d and d.isBoss and not BossEncounter.getEncounterByModel(m) then
			orphan += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d"):format(orphan), orphan == 0)
	local pass, count = r.summary()
	print(("===G1-4 검증 끝(나)=== %d/%d 통과"):format(pass, count))
end

return G1_4Verify
