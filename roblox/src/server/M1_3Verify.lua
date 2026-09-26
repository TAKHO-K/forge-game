-- M1-3 자동 검증(대형 지형 · 물 · 신전 · 둥지 + 보스 관문 등록). (가) = 서버 시작 때 순수 계산 · (나) = 검증 체인(실제 서버 경로).
--   (가) 관문 목록(보스 데이터 gate 칸 → 6곳 · 구역 관문 자리 · 색) · 파티 규칙(한 명이라도 등록 = 원격 입장) · 저장 v40 이관
--   (나) 등록 전 = 원격 입장 불가 · 관문 길 안내 / 관문 상호작용 등록 / 등록 뒤 원격 입장(솔로 · 복귀 = 서 있던 자리) / 파티(리더 등록 + 미등록 더미 3) · 리더 미등록 = 관문 안내 /
--        저장 → 다시 읽기 유지
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)

local M1_3Verify = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[M1-3][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[M1-3][%s] %s"):format(tag, label))
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

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- ─────────────────────────── (가) ───────────────────────────
function M1_3Verify.runPure()
	print("===M1-3 검증 시작(가)===")
	local r = newRecorder("가")
	r.section("관문 목록", function()
		local gates = WorldMapLayout.bossGates()
		local rows, ok = {}, #gates == #WorldMapData.zones
		for _, z in ipairs(WorldMapData.zones) do
			local g = WorldMapLayout.bossGate(z.bossId)
			local same = g ~= nil and g.zoneKey == z.key and flat(g.position, WorldMapLayout.gate(z)) < 0.01 and type(g.color) == "table"
			ok = ok and same
			table.insert(rows, ("%s→%s %s"):format(z.key, z.bossId, same and "O" or "X"))
		end
		r.check(("관문 = 보스 데이터 gate 칸 %d곳(구역 관문 자리 · 색): %s"):format(#gates, table.concat(rows, " · ")), ok)
		local G = WorldMapData.bossGate
		r.check(("관문 크기: 폭 %d · 높이 %d(사람 약 5 - 한눈에) · 등록 = F 짧게(누름 0초) · 거리 %d · 안내 %d"):format(G.width, G.height, G.promptDistance, G.hintDistance), G.height >= 40 and G.width >= 36)
	end)
	r.section("파티 규칙", function()
		local BossGate = require(script.Parent.BossGate)
		local a = BossGate.usableFromFlags(false, { true, false, false }) -- 리더 미등록 + 멤버 1 등록 + 2 미등록
		local b = BossGate.usableFromFlags(true, { false, false, false }) -- 리더 등록 + 미등록 3
		local c = BossGate.usableFromFlags(false, { false, false, false })
		r.check(("파티 원격 입장: 멤버 1명 등록 → %s · 리더만 등록 → %s · 아무도 → %s(기대 true · true · false)"):format(tostring(a), tostring(b), tostring(c)), a and b and not c)
	end)
	r.section("저장 v40", function()
		local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
		local SaveSystem = require(script.Parent.SaveSystem)
		local old = { version = 39, world = { portals = { tier1 = true } }, titles = {} }
		local migrated = SaveSystem.migrate and SaveSystem.migrate(old) or nil
		local okMig = migrated ~= nil and type(migrated.world.bossGates) == "table" and next(migrated.world.bossGates) == nil and migrated.world.portals.tier1 == true
		r.check(("SAVE_VERSION %d · v39 → v40 이관 bossGates 빈 표 %s(포탈 유지)"):format(SaveConfig.saveVersion, tostring(okMig)), SaveConfig.saveVersion == 40 and okMig)
	end)
	local pass, total = r.summary()
	print(("===M1-3 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) ───────────────────────────
function M1_3Verify.runLive(player, env)
	print("===M1-3 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossGate = require(script.Parent.BossGate)
	local PartyState = require(script.Parent.PartyState)
	local SaveSystem = require(script.Parent.SaveSystem)
	local HeightGuard = require(script.Parent.HeightGuard)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	assert(root, "캐릭터 없음")
	local guardOff = HeightGuard.debugOff
	HeightGuard.debugOff = true
	local function put(p)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(p)
	end
	local hook = ServerStorage:WaitForChild("StageMoveHook", 5)
	local profile = PlayerProfile.getProfile(player)
	local bossId = "section_guardian"
	local stage = nil
	for s = BossData.stageInterval, 200, BossData.stageInterval do
		if BossRules.bossIdForStage(s) == bossId and s <= PlayerProfile.getInfiniteStageBest(player) + 1 and not stage then
			stage = s
		end
	end
	local gate = WorldMapLayout.bossGate(bossId)
	local fieldSpot = WorldMapLayout.camp(WorldMapLayout.zoneByKey("tier1")) + Vector3.new(0, 4, 0)
	local function leave()
		if BossEncounter.getEncounter(player) then
			BossEncounter.leaveFor(player)
			task.wait(0.4)
		end
	end
	local function request(s)
		PlayerProfile.setInfiniteStage(player, s - 1)
		BossGate.refreshGuide(player)
		hook:Fire(player, s)
		task.wait(1.5)
	end
	r.section("등록 전", function()
		assert(stage and hook, "수호자 보스 스테이지 · StageMoveHook 없음")
		table.clear(profile.world.bossGates)
		BossGate.refreshAttributes(player)
		put(fieldSpot)
		task.wait(0.5)
		request(stage)
		local enc = BossEncounter.getEncounter(player)
		r.check(("등록 전 스테이지 %d 요청 → 보스전 %s(기대 false) · 스테이지 %s · 길 안내 %s · 원격 가능 목록 [%s]"):format(stage, tostring(enc ~= nil), tostring(PlayerProfile.getInfiniteStage(player)),
			tostring(player:GetAttribute("BossGateId")), tostring(player:GetAttribute("BossGatesUsable"))),
			enc == nil and PlayerProfile.getInfiniteStage(player) == stage and player:GetAttribute("BossGateId") == bossId and (player:GetAttribute("BossGatesUsable") or "") == "")
		-- 관문 상호작용 프롬프트(F · 짧게)
		local prompt = nil
		for _, d in ipairs(workspace.Ground:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Parent:GetAttribute("GatePrompt") == bossId then
				prompt = d
			end
		end
		r.check(("관문 등록 프롬프트: %s · 키 %s · 누름 %.1f초 · 거리 %s"):format(tostring(prompt ~= nil), prompt and prompt.KeyboardKeyCode.Name or "-", prompt and prompt.HoldDuration or -1, prompt and tostring(prompt.MaxActivationDistance) or "-"),
			prompt ~= nil and prompt.KeyboardKeyCode == Enum.KeyCode.F and prompt.HoldDuration == 0)
	end)
	r.section("관문 등록", function()
		put(gate.position - gate.dir * WorldMapData.bossGate.promptOffset + Vector3.new(0, 4, 0)) -- 프롬프트 자리(발판 밖)
		task.wait(0.5)
		local first = BossGate.register(player, bossId) -- 프롬프트 Triggered가 부르는 함수(실제 F 누름은 수동 Play 스크린샷에서)
		local second = BossGate.register(player, bossId)
		task.wait(0.3)
		r.check(("관문 앞 등록 → 새 등록 %s · 두 번째 %s(기대 false) · 저장 표 %s · 길 안내 꺼짐 %s · 원격 가능 [%s]"):format(tostring(first), tostring(second), tostring(profile.world.bossGates[bossId]),
			tostring(player:GetAttribute("BossGateId") == nil), tostring(player:GetAttribute("BossGatesUsable"))),
			first and not second and profile.world.bossGates[bossId] == true and player:GetAttribute("BossGateId") == nil and player:GetAttribute("BossGatesUsable") == bossId)
	end)
	r.section("원격 입장(솔로)", function()
		put(fieldSpot)
		task.wait(0.6)
		request(stage)
		local enc = BossEncounter.getEncounter(player)
		r.check(("등록 뒤 캠프에서 스테이지 %d 요청 → 보스전 %s"):format(stage, tostring(enc ~= nil)), enc ~= nil)
		leave()
		r.check(("보스전 이탈 → 서 있던 자리로 복귀(거리 %.0f · 기대 < 8)"):format(flat(root.Position, fieldSpot)), flat(root.Position, fieldSpot) < 8)
		-- 토벌(BR2): 같은 등록 기록을 쓴다 - 지금은 토벌 입장 경로가 없어 기록만(보고서)
	end)
	r.section("원격 입장(파티)", function()
		local ok = PartyState.addDummies(player, 3, function(index)
			return { classId = "bow", level = PlayerProfile.getCharacterLevel(player) or 1, stage = stage, hp = 1, maxHp = 1 }
		end)
		local party = PartyState.getParty(player)
		local size = party and PartyState.getSize(party) or 0
		put(fieldSpot)
		task.wait(0.4)
		request(stage)
		local enc = BossEncounter.getEncounter(player)
		r.check(("파티 %d명(리더 등록 · 더미 3 미등록) → 원격 입장 보스전 %s · 더미는 등록 안 됨(저장 없는 기록)"):format(size, tostring(enc ~= nil)), ok and size == 4 and enc ~= nil)
		leave()
		table.clear(profile.world.bossGates) -- 리더도 미등록 → 관문 안내
		BossGate.refreshAttributes(player)
		request(stage)
		local enc2 = BossEncounter.getEncounter(player)
		r.check(("파티 전원 미등록 → 보스전 %s(기대 false) · 길 안내 %s"):format(tostring(enc2 ~= nil), tostring(player:GetAttribute("BossGateId"))), enc2 == nil and player:GetAttribute("BossGateId") == bossId)
		PartyState.clearDummies(player)
		task.wait(0.3)
	end)
	r.section("저장 · 다시 읽기", function()
		PlayerProfile.registerBossGate(player, bossId)
		local okSave, why = SaveSystem.saveProfile(player, profile)
		local loaded = SaveSystem.loadProfile(player)
		local kept = loaded ~= nil and loaded.world ~= nil and loaded.world.bossGates[bossId] == true
		r.check(("등록 → 저장 %s(%s) → 다시 읽기(검증 키) 등록 유지 %s"):format(tostring(okSave), tostring(why), tostring(kept)), okSave and kept)
	end)
	-- 정리: 스테이지 · 등록 · 위치
	leave()
	PlayerProfile.setInfiniteStage(player, math.max(1, (stage or 2) - 1))
	table.clear(profile.world.bossGates)
	BossGate.refreshAttributes(player)
	BossGate.refreshGuide(player)
	put(WorldMapLayout.spawnPoint() + Vector3.new(0, 5, 0))
	HeightGuard.debugOff = guardOff
	env.restore(player)
	local pass, total = r.summary()
	print(("===M1-3 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return M1_3Verify
