Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
-- QUEUE-6h-b R5 다인원 규칙 하네스(서버 가짜 참가자 2 ~ 4명 · 실제 모듈 경로). 모의 전용 분기 = 가짜 Player 표(Character · HumanoidRootPart 스탠드인)뿐 - 게임 코드에 모의 분기 추가 없음.
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[R5] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function fakePlayer(name, uid, opts)
	opts = opts or {}
	local attrs = {}
	local root = { Position = opts.pos or Vector3.new(0, 0, 0) }
	local character = setmetatable({}, { __index = function(_, k)
		if k == "FindFirstChild" then return function(_, n) if n == "HumanoidRootPart" then return root end return nil end end
		if k == "FindFirstChildOfClass" then return function() return nil end end
		return nil
	end })
	local p = { Name = name, UserId = uid, Parent = true, Character = character, level = opts.level, rebirth = opts.rebirth, party = opts.party }
	return setmetatable(p, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		return nil
	end })
end
local ok, err = pcall(function()
	local SoulService = MODS.SoulService
	local PlayerState = MODS.PlayerState
	local BossEncounter = MODS.BossEncounter
	local BossPatterns = MODS.BossPatterns
	local MobShare = MODS.MobShare
	local MonsterState = MODS.MonsterState
	local A, B, C, D = fakePlayer("A", 1), fakePlayer("B", 2), fakePlayer("C", 3), fakePlayer("D", 4)
	for _, p in ipairs({ A, B, C, D }) do
		PlayerState.init(p)
	end
	local enc = { id = "e1", model = {}, members = { A, B, C } }
	local other = { id = "e2", model = {}, members = { D } }

	-- ① 전멸 판정: 3인 중 2 영혼 → 산 사람 1 · 3 영혼 → 0
	SoulService.onDied(A, enc, Vector3.new(0, 0, 0)); SoulService.consumePending(A, enc)
	SoulService.onDied(B, enc, Vector3.new(100, 0, 0)); SoulService.consumePending(B, enc)
	local alive1 = BossEncounter.livingMemberCount(enc)
	SoulService.onDied(C, enc, Vector3.new(3, 0, 0))
	PlayerState.setHp(C, 0) -- 죽은 순간(리스폰 대기)
	local alive0 = BossEncounter.livingMemberCount(enc)
	check("전멸 판정: 영혼 2 + 산 사람 1 → 1 · 마지막 사람 사망 → 0(= 옛 실패 흐름)", alive1 == 1 and alive0 == 0, ("%d → %d"):format(alive1, alive0))

	-- ② 기믹 대상(대공 잡기 · 끌림 · 표적 = BossPatterns.kit.victims): 영혼 · 죽은 사람 제외
	local vs = BossPatterns.kit.victims({ members = { A, B, C, D }, zoneKey = "bossArena1" })
	local names = {}
	for _, v in ipairs(vs) do table.insert(names, v.player.Name) end
	check("기믹 대상 = 산 사람만(영혼 A · B · 사망 C 제외 → D)", #vs == 1 and vs[1].player == D, table.concat(names, ","))

	-- ③ 성역 끝 부활: 시전자 보스전 · 성역 안 · 성역 동안 죽은 사람만(영혼 = 즉시 · 리스폰 대기 C = 리스폰 때)
	SoulService.onDied(D, other, Vector3.new(1, 0, 0)); SoulService.consumePending(D, other)
	local sanct = { center = Vector3.new(0, 0, 0), radius = 16, startedAt = os.clock() - 5 }
	local n = SoulService.reviveSanctuary(sanct, enc)
	PlayerState.setHp(C, 50)
	local cSoul = SoulService.consumePending(C, enc)
	check("성역 끝: A 부활(안) · B 그대로(밖 100) · C 리스폰 때 부활 · 다른 보스전 D 그대로", n == 2 and not SoulService.isSoul(A) and SoulService.isSoul(B) and not cSoul and not SoulService.isSoul(C) and SoulService.isSoul(D), ("부활 %d"):format(n))

	-- ④ 구원의 기도 = SoulService.revive 입구(치유사 R - SkillServer가 반경 안 영혼에 부른다) · 부활 체력 30%
	PlayerState.setHp(B, 1)
	local rv = SoulService.revive(B, "구원의 기도")
	local hpB = PlayerState.getHp(B)
	local maxB = PlayerState.getMaxHp(B)
	check("기도 부활: 영혼 풀림 · 체력 = 최대 × 0.3", rv and not SoulService.isSoul(B) and math.abs(hpB - maxB * 0.3) < 1e-6, ("%.1f / %.1f"):format(hpB, maxB))
	check("살아 있는 사람 부활 요청 = 거부", SoulService.revive(A, "기도") == false)

	-- ⑤ 튕김 → 재접속: 기록 → 같은 UserId 새 Player가 되찾음 · 한 번만
	SoulService.onDied(A, enc, Vector3.new(0, 0, 0)); SoulService.consumePending(A, enc)
	SoulService.noteDisconnect(A, enc)
	local A2 = fakePlayer("A", 1)
	local rec = SoulService.takeRejoin(A2)
	local again = SoulService.takeRejoin(A2)
	check("튕김 재접속: 같은 보스전 기록 되찾음 · 두 번째 없음 · 옛 Player 영혼 풀림", rec ~= nil and rec.encounter == enc and again == nil and not SoulService.isSoul(A))

	-- ⑥ 파티 보상 기여 · 스틸 규칙(MobShare = MonsterState가 잡몹 entry에 쓰는 규칙)
	local now = os.clock()
	local P1 = { level = 50, rebirth = 1, party = 7 }
	local P2 = { level = 20, rebirth = 1, party = 7 }
	local X = { level = 90, rebirth = 3, party = 0 }
	local mob = MobShare.fresh({})
	MobShare.touch(mob, P1, 100, now)
	MobShare.applyRatio(mob, P1, 0.5, now)
	MobShare.touch(mob, P2, 100, now)
	MobShare.applyRatio(mob, P2, 0.2, now)
	local e1, e2 = MobShare.eligible(mob, P1, 100), MobShare.eligible(mob, P2, 100)
	check("파티 기여: 두 사람 다 기여 ≥ 문턱 · 같은 스테이지 → 보상 자격", e1 and e2)
	local blockedX = MobShare.isBlocked(mob, X, 300, now)
	check("스틸: 훨씬 높은 사람(스테이지 300 · 환생 3)이 남의 몹에 새로 닿으면 막힘", blockedX == true)
	local e3 = MobShare.eligible(mob, P1, 101)
	check("스테이지를 옮긴 사람 = 보상 자격 없음(stage_changed)", e3 == false)

	-- ⑦ 재접속 기여 인계: 전멸 리셋 세대가 바뀌면 옛 기여 무효(MonsterState)
	check("재접속 기여 인계 입구 존재(MonsterState.takeCarriedContribution · resetGen)", type(MonsterState.takeCarriedContribution) == "function")
end)
if not ok then print("[R5] 하네스 에러 " .. tostring(err)) end
print(("[R5] 끝 %d/%d"):format(pass, total))
