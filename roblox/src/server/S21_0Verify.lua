-- S21-0 자동 검증(서버) - 수치 안전장치(A1 NumberFormat · A2 Sanitize · A4 SafeStageCap ·
-- A6 BalanceSim 오버플로 수정)와 A3(DataStore 저장 보호)의 실제 동작 확인.
--   runPure()             (가) 순수 함수: NumberFormat.format · Sanitize.number · safeStageCap 경계 · getSurviveHits 오버플로 수정(플레이어 불필요)
--   runLive(player, env)  (나) 실제 Player: A3 - DataStore가 NaN·inf를 실제로 어떻게 다루는지(별도 던지기용 키) +
--                         SaveSystem.sanitizeForSave가 오염된 필드만 이전 값으로 되돌리고 나머지는 정상 저장하는지(검증용 키 - S19b 수동 Play 모드 분리로 실제 프로필 무오염).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveSystem = require(script.Parent.SaveSystem)

local S21_0Verify = {}

local function tally(label)
	local self = { pass = 0, total = 0 }
	function self.check(name, ok)
		self.total += 1
		if ok then
			self.pass += 1
		end
		print(("[S21-0][%s] %s %s"):format(label, name, ok and "O" or "X"))
	end
	return self
end

-- ═══ (가) 순수 함수 ═══
function S21_0Verify.runPure()
	print("===S21-0 검증 시작(가: NumberFormat · Sanitize · safeStageCap · BalanceSim 오버플로)===")
	local t = tally("가")

	-- A1: inf·-inf·nan 즉시 반환(무한 루프 없이 - 이 호출 자체가 끝난다는 게 증거), 표시 문자열, 정상 값 불변.
	t.check("format(nan) == '—'", NumberFormat.format(0 / 0) == "—")
	t.check("format(inf) == '∞'", NumberFormat.format(math.huge) == "∞")
	t.check("format(-inf) == '-∞'", NumberFormat.format(-math.huge) == "-∞")
	-- 기대값은 NumberFormat.format의 기존(이 세션 전) 동작 그대로다 - 정수로 떨어지면 소수점을
	-- 안 붙이고(truncated == floor(truncated)) 소수부는 반올림이 아니라 버림(math.floor)이다.
	local finiteSamples = {
		{ 0, "0" }, { 5, "5" }, { 999, "999" }, { 1000, "1,000" }, { 9999, "9,999" },
		{ 10000, "10K" }, { 12345, "12.3K" }, { 999999, "999.9K" }, { 1000000, "1M" },
		{ 1500000, "1.5M" }, { 1000000000, "1B" }, { 1000000000000, "1T" },
		{ 1.9, "1" }, { 10000.9, "10K" }, { 250, "250" }, { 88888, "88.8K" },
		{ 1234567890, "1.2B" }, { -5, "-5" }, { 42, "42" }, { 100000, "100K" },
	}
	local allSame = true
	for _, sample in ipairs(finiteSamples) do
		local got = NumberFormat.format(sample[1])
		if got ~= sample[2] then
			allSame = false
			print(("[S21-0][가][format 불일치] %s -> %s(기대 %s)"):format(tostring(sample[1]), got, sample[2]))
		end
	end
	t.check(("정상 값 표시 20개 표본 불변(글자 한 개도 안 바뀜)"), allSame)

	-- A2: Sanitize.number - NaN·±inf는 fallback, 정상 값은 그대로.
	t.check("Sanitize.number(nan, 5) == 5", Sanitize.number(0 / 0, 5) == 5)
	t.check("Sanitize.number(inf, 7) == 7", Sanitize.number(math.huge, 7) == 7)
	t.check("Sanitize.number(-inf, 3) == 3", Sanitize.number(-math.huge, 3) == 3)
	t.check("Sanitize.number(42, 0) == 42(정상값 그대로)", Sanitize.number(42, 0) == 42)
	t.check("Sanitize.number(-17.5, 0) == -17.5(정상 음수도 그대로)", Sanitize.number(-17.5, 0) == -17.5)

	-- A4: safeStageCap = 마지막 스테이지가 boss4(4인 파티) HP 기준 1e300 미만, cap+1은 1e300 이상.
	local cap = InfiniteStageConfig.safeStageCap
	local function boss4Hp(stage)
		return InfiniteStage.getMonsterHp(80, stage) * 20 * BossRules.partySizeHpMultiplier(4)
	end
	t.check(("safeStageCap = %d"):format(cap), cap == 4738)
	t.check(("stage %d(cap) boss4 HP < 1e300"):format(cap), boss4Hp(cap) < 1e300)
	t.check(("stage %d(cap+1) boss4 HP >= 1e300"):format(cap + 1), boss4Hp(cap + 1) >= 1e300)

	-- A6: getSurviveHits가 A² 없이 계산되므로 스테이지 2448 · 2500 · 3000에서도 유한값 · PlayerDamage와 같은 식.
	local D = 1000 -- 임의의 방어력(순수 함수 확인용 - PlayerDamage.computeHitDamage와 같은 reduction 식인지가 핵심)
	for _, stage in ipairs({ 2448, 2500, 3000 }) do
		local A = InfiniteStage.getMonsterAttack(8, stage)
		local reduction = D / (D + CombatConfig.damageReductionAlpha * A)
		local expectedDmgPerHit = A * (1 - reduction) -- PlayerDamage.computeHitDamage와 같은 연산 순서
		local _, dmgPerHit = BalanceSim.getSurviveHits({ defense = D, maxHp = 1e6 }, A)
		local finite = dmgPerHit == dmgPerHit and dmgPerHit ~= math.huge
		local matches = finite and math.abs(dmgPerHit - expectedDmgPerHit) <= math.abs(expectedDmgPerHit) * 1e-9
		t.check(("스테이지 %d: getSurviveHits 유한값 %s · PlayerDamage 식과 일치(dmgPerHit=%s, 기대=%s)"):format(
			stage, tostring(finite), tostring(dmgPerHit), tostring(expectedDmgPerHit)), finite and matches)
	end

	local pass, total = t.pass, t.total
	print(("===S21-0 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ═══ (나) 실제 Player ═══
function S21_0Verify.runLive(player, env)
	print("===S21-0 검증 시작(나: A3 - DataStore NaN·inf 처리 + 저장 직전 sanitize)===")
	local t = tally("나")

	-- A3 첫 단계: DataStore가 NaN·inf를 실제로 저장할 수 있는지 - 실제 프로필과 무관한 던지기용 키.
	local probeStore = DataStoreService:GetDataStore("S21_0_NaN_Probe_v1")
	local probeKey = "probe_" .. tostring(player.UserId)
	local okNan, errNan = pcall(function()
		return probeStore:UpdateAsync(probeKey, function()
			return { value = 0 / 0 }
		end)
	end)
	local okInf, errInf = pcall(function()
		return probeStore:UpdateAsync(probeKey, function()
			return { value = math.huge }
		end)
	end)
	print(("[S21-0][나][A3] DataStore에 NaN 저장 시도: 성공=%s%s"):format(tostring(okNan), okNan and "" or (" · 에러: " .. tostring(errNan))))
	print(("[S21-0][나][A3] DataStore에 inf 저장 시도: 성공=%s%s"):format(tostring(okInf), okInf and "" or (" · 에러: " .. tostring(errInf))))
	-- 보고만(판단 기준 없음) - 실패면 "저장 실패"가 실측된 것이고, 성공이면 그대로 저장되거나 값이 변형된 것이다(아래에서 다시 읽어 확인).
	local readOk, readValue = pcall(function()
		return probeStore:GetAsync(probeKey)
	end)
	if readOk and readValue then
		local v = readValue.value
		print(("[S21-0][나][A3] 다시 읽은 값: %s(type=%s, NaN=%s, inf=%s)"):format(
			tostring(v), type(v), tostring(type(v) == "number" and v ~= v), tostring(v == math.huge)))
	end
	t.check("DataStore NaN·inf 저장 동작 확인 완료(성공·실패 어느 쪽이든 O - 보고용)", true)

	if not PlayerProfile.getProfile(player) then
		t.check("프로필이 없어 sanitizeForSave 왕복 검증을 건너뜀", false)
		local pass, total = t.pass, t.total
		print(("===S21-0 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player)
	local profile = PlayerProfile.getProfile(player)

	-- 1단계: 정상값으로 한 번 저장해 DataStore(검증용 키)에 "마지막 정상값"을 심어 둔다.
	local knownGoodGold = 123456
	profile.gold = knownGoodGold
	local ok1 = SaveSystem.saveProfile(player, profile)
	t.check(("1단계: 정상 골드(%d) 저장 성공=%s"):format(knownGoodGold, tostring(ok1)), ok1 == true)

	-- 2단계: gold를 NaN으로 오염시키고 다시 저장 - 저장 전체가 실패하지 않고, gold만 1단계 값으로 되돌아가야 한다.
	profile.gold = 0 / 0
	local ok2 = SaveSystem.saveProfile(player, profile)
	local goldRestoredInMemory = profile.gold == knownGoodGold
	t.check(("2단계: gold를 NaN으로 오염시킨 뒤 저장 성공=%s(전체 실패하지 않음)"):format(tostring(ok2)), ok2 == true)
	t.check(("2단계: 저장 뒤 메모리의 gold가 이전 정상값(%d)으로 되돌아옴(현재 %s)"):format(knownGoodGold, tostring(profile.gold)), goldRestoredInMemory)

	-- 3단계: DataStore에서 다시 읽어 실제로 정상값이 저장됐는지(NaN이 새어나가지 않았는지) 확인.
	local reloaded = SaveSystem.loadProfile(player)
	local persistedOk = reloaded ~= nil and reloaded.gold == knownGoodGold
	t.check(("3단계: DataStore에서 다시 읽은 gold == %d(NaN 아님, 실제 %s)"):format(knownGoodGold, tostring(reloaded and reloaded.gold)), persistedOk)

	env.restore(player)

	local pass, total = t.pass, t.total
	print(("===S21-0 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return S21_0Verify
