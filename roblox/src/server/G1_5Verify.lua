-- G1-5 자동 검증(docs/phase/G1-5-report.md) - 보스 생존 중 포기 · 파티 탈퇴 → 도전 스테이지 − 1 + 마을.
--   (나)만 - 솔로 포기(BossLinger.giveUp) · 파티(실제 Player 리더 + 스탠드인) 보스전 중 탈퇴 · 잔류 중에는 포기 대상 아님.
--   이동 제한(StageServer boss_alive) · 재접속 −1 · 초대 수락 · 견습 차단은 서버 Script 안의 판정이라 여기서 부를 수 없다 - 코드 경로 + 보고서.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)

local G1_5Verify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[G1-5][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

function G1_5Verify.runLive(player, env)
	print("===G1-5 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossLinger = require(script.Parent.BossLinger)
	local PartyState = require(script.Parent.PartyState)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local MonsterState = require(script.Parent.MonsterState)
	local STAGE = BossData.stageInterval * 2

	local function spawn()
		BossEncounter.despawnFor(player)
		env.applyStage(player, STAGE)
		BossEncounter.spawnFor(player, STAGE)
		return BossEncounter.getEncounter(player)
	end

	r.section("솔로 포기", function()
		spawn()
		local ok, result = BossLinger.giveUp(player)
		r.check(("솔로 포기: %s(%s) · 보스전 %s(기대 nil) · 스테이지 %d(기대 %d = 도전 − 1)"):format(tostring(ok), tostring(result), tostring(BossEncounter.getEncounter(player)),
			PlayerProfile.getInfiniteStage(player), STAGE - 1),
			ok and BossEncounter.getEncounter(player) == nil and PlayerProfile.getInfiniteStage(player) == STAGE - 1)
		local none, why = BossLinger.giveUp(player)
		r.check(("보스전 밖 포기: %s(%s - 기대 false · no_boss)"):format(tostring(none), tostring(why)), none == false and why == "no_boss")
	end)

	r.section("파티 탈퇴", function()
		local encounter = spawn()
		local stand = { Name = "G15Stand", UserId = -9801, Parent = workspace }
		PartyState.create(player)
		local party = PartyState.getParty(player)
		PartyState.attachMember(party, stand)
		encounter.party = party -- 솔로 보스전을 이 파티의 보스전으로(스탠드인은 보스전 멤버가 아니다 - 리더 탈퇴만 본다)
		PartyState.leave(player, "leave")
		r.check(("보스 생존 중 파티 탈퇴: 보스전 %s(기대 nil) · 스테이지 %d(기대 %d)"):format(tostring(BossEncounter.getEncounter(player)), PlayerProfile.getInfiniteStage(player), STAGE - 1),
			BossEncounter.getEncounter(player) == nil and PlayerProfile.getInfiniteStage(player) == STAGE - 1)
		if PartyState.getParty(stand) then
			PartyState.leave(stand, "leave")
		end
	end)

	BossEncounter.despawnFor(player)
	env.restore(player)
	local orphan = 0
	for _, m in ipairs(MonsterState.getAllModels()) do
		local d = MonsterState.getData(m)
		if d and d.isBoss and not BossEncounter.getEncounterByModel(m) then
			orphan += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d"):format(orphan), orphan == 0)
	local pass, count = r.summary()
	print(("===G1-5 검증 끝(나)=== %d/%d 통과"):format(pass, count))
end

return G1_5Verify
