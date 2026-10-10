-- PROG-2A 시나리오 라이브러리(설계 시뮬 전용 - 하네스 메모리 안에서만 MODS 값 · 함수를 덮는다. 게임 데이터 · 코드 파일은 안 바뀐다).
-- 시나리오 파일 = "PROG2CFG = { ... }" 한 줄 + 이 파일. p2run.py가 테스트 본문 앞에 붙인다.
local C = PROG2CFG or {}
PROG2 = { whatIf = C.whatIf or {}, log = {} }
local M = MODS
local Training, TrainingData, All10, InfiniteStage, GoldCost = M.Training, M.TrainingData, M.All10, M.InfiniteStage, M.GoldCost
local LN1001 = math.log(1.001)

-- ── ① 수입 곡선(골드 배수 M(s) - 몹 골드 · GoldCost 비용이 같은 함수를 쓴다) ──
local curve = C.goldCurve
if curve then
	local lnM = {}
	local CAP = 40000
	if curve == "decay" then -- 구간별 감쇠: 성장률 = ln1.001 × f(s) · f = 1(≤ 5,000) → 0.6(10,000) → 0.4(17,000) → 0.3(25,300) 직선(경계 급변 없음)
		local knots = C.decayKnots or { { 0, 1 }, { 5000, 1 }, { 10000, 0.6 }, { 17000, 0.4 }, { 25300, 0.3 }, { 40000, 0.3 } }
		local function f(s)
			for i = 2, #knots do
				if s <= knots[i][1] then
					local a, b = knots[i - 1], knots[i]
					return a[2] + (b[2] - a[2]) * (s - a[1]) / (b[1] - a[1])
				end
			end
			return knots[#knots][2]
		end
		lnM[1] = 0
		for s = 2, CAP do
			lnM[s] = lnM[s - 1] + LN1001 * f(s - 0.5)
		end
		InfiniteStage.getGoldMultiplier = function(stage)
			local s = math.clamp(math.floor(stage), 1, CAP)
			return math.exp(lnM[s] + LN1001 * f(s) * (stage - s))
		end
	elseif curve == "log" then -- 로그형: M = 1 + a · ln(1 + (s − 1)/b) · 기울기 a/b = 0.001(처음 같은 기울기)
		local b = C.logB or 10000
		local a = b * LN1001
		InfiniteStage.getGoldMultiplier = function(stage)
			return 1 + a * math.log(1 + math.max(0, stage - 1) / b)
		end
	elseif curve == "poly" then -- 지수 1 미만 다항형: M = (1 + (s − 1)/c)^p · 기울기 p/c = ln1.001
		local p = C.polyP or 0.9
		local c = p / LN1001
		InfiniteStage.getGoldMultiplier = function(stage)
			return (1 + math.max(0, stage - 1) / c) ^ p
		end
	elseif curve == "sqrt" then -- GOLD-CURVE-1 C(강한 완만): 1,000까지 지금 식 그대로 · 뒤 = M(1,000) × (s/1,000)^p(p 0.5 = √) - 1,000 → 8,500 수입 약 ×2.9
		local p = C.sqrtP or 0.5
		local m1000 = 1.001 ^ 999
		InfiniteStage.getGoldMultiplier = function(stage)
			if stage <= 1000 then
				return 1.001 ^ (stage - 1)
			end
			return m1000 * (stage / 1000) ^ p
		end
	elseif curve == "powlog" then -- 거듭제곱(로그 축 직선) - 참고: M = (1 + (s − 1)/B)^A · A/B = ln1.001
		local B = C.powB or 4000
		local A = B * LN1001
		InfiniteStage.getGoldMultiplier = function(stage)
			return (1 + math.max(0, stage - 1) / B) ^ A
		end
	end
end
local function Mg(s)
	return InfiniteStage.getGoldMultiplier(s)
end
if C.levelKillsScale then -- GOLD-CURVE-1 하한 맞춤: 초월 강화 한 단계 비용(마리분) 배율
	M.All10Data.transcendEnhance.levelKills *= C.levelKillsScale
end
if C.costGap then -- GOLD-CURVE-1 가설 실험: 비용 기준 스테이지를 costGap칸 내림(= 사냥 스테이지 근처 가격 - 계정 최고 vs 사냥 차이 효과만 따로 잼)
	local oldScale = GoldCost.scale
	GoldCost.scale = function(stage, kind)
		return oldScale(stage and math.max(1, stage - C.costGap) or stage, kind)
	end
end
if C.gapComp then -- GOLD-CURVE-1 "같은 변환": 새 곡선에서도 "계정 최고 vs 사냥 스테이지 차이(gapComp칸)" 비용 몫을 지금 곡선과 같게(1.001^gap) 맞춤
	local oldScale = GoldCost.scale
	local g = C.gapComp
	GoldCost.scale = function(stage, kind)
		local v = oldScale(stage, kind)
		if stage and stage > g + 1 then
			v *= 1.001 ^ g / (Mg(stage) / Mg(stage - g))
		end
		return v
	end
end
if C.incomeScale then -- GOLD-CURVE-1 §5: 수입만 배율(사냥 · 보스 · 판매 = getGoldReward · 보스 첫 클리어 표) - 비용(GoldCost)은 그대로
	local oldReward = InfiniteStage.getGoldReward
	InfiniteStage.getGoldReward = function(baseGold, stage)
		return math.floor(oldReward(baseGold, stage) * C.incomeScale)
	end
end
if C.trainReserve then -- GOLD-CURVE-1 §6-3: 수련 구매 때 남겨 둘 다음 강화 비용 배수(지금 1 · 0 = 남는 골드로 바로 수련)
	M.EconSimConfig.trainingReserveEnhance = C.trainReserve
end
if curve and not C.keepBossTable then -- 보스 첫 클리어 골드 = 옛 곡선으로 구운 숫자표(BossFirstClearGoldData) → 새 곡선 비율로 다시 굽는 것과 같게
	local Enhance = M.Enhance
	local oldGrant = Enhance.getBossGrantGold
	Enhance.getBossGrantGold = function(stage)
		return math.floor(oldGrant(stage) * Mg(stage) / 1.001 ^ (stage - 1))
	end
end

-- ── ② 능력치 수련(A = 1 ~ 50 단계당 1%(공용) + 51 ~ 100 고급 수련 그대로 · B = 1 ~ 100 전부 공용(스테이지 연동) · 고급 수련 없음) ──
local tr = C.training
if tr then
	local stats = {
		{ id = "attack", name = "공격 수련", bucket = "attack", perLevel = 0.01, maxLevel = tr.maxLevel or 50, stagesPerLevel = tr.stagesPerLevel or 20, p2bands = tr.bands },
		{ id = "hp", name = "체력 수련", bucket = "hp", perLevel = 0.01, maxLevel = tr.maxLevel or 50, stagesPerLevel = tr.stagesPerLevel or 20, p2bands = tr.bands },
		{ id = "defense", name = "방어 수련", axis = "defensePercent", perLevel = 0.005, maxLevel = tr.maxLevel or 50, stagesPerLevel = tr.stagesPerLevel or 20, p2bands = tr.bands },
	}
	TrainingData.stats = stats
	local oldKills = Training.killsFor
	Training.killsFor = function(def, level)
		if def.p2bands then -- 구간표: { 시작 단계(다음 단계 번호), 마리분, 구간 안 증가율 } - 25 · 50 · 75에서 계단
			local nextLevel = (level or 0) + 1
			local band = def.p2bands[1]
			for _, b in ipairs(def.p2bands) do
				if nextLevel >= b[1] then
					band = b
				end
			end
			return band[2] * band[3] ^ (nextLevel - band[1])
		end
		return oldKills(def, level)
	end
	if tr.advancedStep then -- A: 고급 수련 76 ~ 100 = 비용 × advancedStep(75에서 계단)
		local oldAdv = All10.advancedCost
		All10.advancedCost = function(level, bestStage)
			local c = oldAdv(level, bestStage)
			return (level + 1 >= 76) and c * tr.advancedStep or c
		end
	end
	if tr.noAdvanced then -- B: 고급 수련 없음(1 ~ 100이 공용)
		All10.advancedCap = function() return 50 end
		All10.advancedBonus = function() return 0 end
	end
end

-- ── ③ 직업 고유 능력(새): 옛 3종 × 50단계 제거 · Lv1 = 환생 n · Lv2 = 골드 · Lv3 = 초월 무기 + 골드. 피해 능력 = 실효 공격 버킷 %(직업별 명목 × 가동률 표 = 문서) ──
local ca = C.classAbility
if ca then
	TrainingData.classAbilities = { greatsword = {}, dualblade = {}, bow = {}, healer = {} }
	local oldBucket = Training.bucketBonus
	Training.bucketBonus = function(training, abilities, classId, bucket)
		local v = oldBucket(training, abilities, classId, bucket)
		local lv = type(abilities) == "table" and abilities.__p2cls or 0
		if bucket == "attack" and lv > 0 then
			v += ca.pct[lv]
		end
		return v
	end
end
local function caCost(lv, reach)
	local base = ca.gold[lv]
	if ca.mode == "scaled" then
		return GoldCost.niceReward(base * Mg(reach) / Mg(ca.anchor or 1000))
	end
	return base
end

-- ── ④ 몹 체력 기준 빌드 보정(중앙값이 가진 새 힘을 몹 HP에 같이 곱한다 - 진행 속도 ∝ 상대 힘) ──
local comp = C.comp
if comp then
	local oldHp = All10.hpCurveFactor
	local function interp(t, s)
		local v = s <= t[1][1] and t[1][2] or t[#t][2]
		for i = 2, #t do
			if s > t[i - 1][1] and s <= t[i][1] then
				return t[i - 1][2] + (t[i][2] - t[i - 1][2]) * (s - t[i - 1][1]) / (t[i][1] - t[i - 1][1])
			end
		end
		return v
	end
	local function refOld(s)
		if comp.oldRef then -- 옛 수련 + 옛 직업 능력의 중앙값 실제 궤적(공격 버킷 값)
			return interp(comp.oldRef, s)
		end
		local evo = 0
		for _, t in ipairs({ 5000, 7500, 10000 }) do
			if s >= t then evo += 10 end
		end
		return 0.001 * math.min(50, math.floor(s / 20)) + 0.000375 * math.min(50 + evo, math.floor(s / 10))
	end
	local function refNew(s)
		local v = 0
		if tr and comp.trainRef then -- 중앙값(일반 프로필) 실제 궤적 { 스테이지, 단계 } 직선 보간(고정점 맞춤)
			local t = comp.trainRef
			local lv = s <= t[1][1] and t[1][2] or t[#t][2]
			for i = 2, #t do
				if s > t[i - 1][1] and s <= t[i][1] then
					lv = t[i - 1][2] + (t[i][2] - t[i - 1][2]) * (s - t[i - 1][1]) / (t[i][1] - t[i - 1][1])
					break
				end
			end
			v += 0.01 * lv
		elseif tr then
			local spl = tr.stagesPerLevel or 20
			v += 0.01 * math.min(tr.maxLevel or 50, math.floor(s / spl))
		else
			v += 0.001 * math.min(50, math.floor(s / 20))
		end
		if ca then
			for i, at in ipairs(comp.caStages or { 450, 1500, 8600 }) do
				if s >= at then v += ca.pct[i] - (ca.pct[i - 1] or 0) end
			end
		else
			v += refOld(s) - 0.001 * math.min(50, math.floor(s / 20))
		end
		return v
	end
	local base = comp.base or 1.05
	local share = comp.share or 1
	All10.hpCurveFactor = function(stage)
		local s = stage or 0
		local ratio = (base + refNew(s)) / (base + refOld(s))
		return oldHp(stage) * (1 + (ratio - 1) * share)
	end
	PROG2.compAt = function(s) return (base + refNew(s)) / (base + refOld(s)) end
end

-- ── ⑤ 청크마다 훅(EconSim.withOverrides 감싸기): 직업 능력 구매 · 소모처 · 새 보상 수입 ──
local inc = C.income or {}
local sink = C.sink
local EconSim = M.EconSim
local oldWO = EconSim.withOverrides
EconSim.withOverrides = function(whatIf, fn, state, ...)
	local r = oldWO(whatIf, fn, state, ...)
	if type(state) ~= "table" or not state.training or type(r) ~= "table" or not r.reach then
		return r
	end
	local hours = state.seconds / 3600
	local earned = (r.gold or 0) + (r.sellGold or 0) + (r.bossGold or 0)
	state.p2earned = (state.p2earned or 0) + earned
	-- 새 보상 수입(골드 = 마리분 × GoldCost 단위 · 날짜 = 누적 플레이 ÷ 하루 시간)
	local hpd = M.EconSimConfig.profiles[P2PROF].hoursPerDay
	local day = math.floor(hours / hpd) + 1
	state.p2day = state.p2day or 0
	while state.p2day < day do
		state.p2day += 1
		local unit = 4.95 * Mg(state.reach)
		local g = 0
		if inc.newUser and inc.newUser[state.p2day] then
			g += GoldCost.niceReward(unit * inc.newUser[state.p2day])
		end
		if inc.oldAttend and inc.oldAttend[state.p2day] then
			g -= GoldCost.niceReward(unit * inc.oldAttend[state.p2day]) -- 지금 7일 출석은 EconSim에 없다(대체분만 차이로 더함)
		end
		if inc.treeKills then
			g += GoldCost.niceReward(unit * inc.treeKills)
		end
		state.gold = math.max(0, state.gold + g)
		state.p2income = (state.p2income or 0) + g
	end
	if inc.petSalePerHour then -- 펫 판매(시간당 마리분 - 알 획득 × 등급 기대 판매가)
		local secs = (r.seconds or 0) + (r.bossSeconds or 0)
		local g = 4.95 * Mg(state.reach) * inc.petSalePerHour * secs / 3600
		state.gold += g
		state.p2pet = (state.p2pet or 0) + g
	end
	-- GOLD-CURVE-1 §3: 강화 한 번 = 사냥 몇 분(그 단계에 처음 닿은 청크 · 다음 1회 비용 ÷ 그 청크 분당 골드)
	do
		local secs = (r.seconds or 0) + (r.bossSeconds or 0)
		local gpm = secs > 0 and earned / (secs / 60) or 0
		PROG2.enh = PROG2.enh or {}
		local function mark(key, cost)
			if not PROG2.enh[key] and gpm > 0 then
				PROG2.enh[key] = true
				PROG2.log["enh_" .. key] = { ("%.2f"):format(hours), state.reach, ("%.4g"):format(cost), ("%.4g"):format(gpm), ("%.2f"):format(cost / gpm) }
			end
		end
		for _, L in ipairs({ 10, 20, 29 }) do
			if not state.transcend and state.weaponLevel >= L and state.weaponLevel < 30 then
				mark(("g%d_+%d"):format(state.weaponGrade, L), M.Enhance.getCost(state.weaponLevel, state.reach) or 0)
			end
		end
		if state.transcend then
			for _, L in ipairs({ 10, 20 }) do
				local lv = state.transcend.level
				if lv >= L and lv < 25 then
					local nxt = lv + 1
					local c = All10.transcendBand(nxt) and All10.transcendAttemptCost(nxt, state.reach) or All10.transcendSlotCost(state.reach)
					mark(("T+%d"):format(L), c)
				end
			end
		end
	end
	-- 직업 능력
	if ca then
		local a = state.abilities
		a.__p2cls = a.__p2cls or 0
		if a.__p2cls == 0 and state.rebirth >= (ca.lv1Rebirth or 3) then
			a.__p2cls = 1
			PROG2.log.ca1 = PROG2.log.ca1 or { hours, state.reach }
		end
		if a.__p2cls == 1 and state.reach >= (ca.lv2Stage or 0) then
			local c = caCost(2, state.reach)
			if state.gold >= c then
				state.gold -= c
				state.spend.ability += c
				a.__p2cls = 2
				PROG2.log.ca2 = { hours, state.reach, c }
			end
		end
		if a.__p2cls == 2 and state.transcend then
			local c = caCost(3, state.reach)
			if state.gold >= c then
				state.gold -= c
				state.spend.ability += c
				a.__p2cls = 3
				PROG2.log.ca3 = { hours, state.reach, c }
			end
		end
	end
	-- 소모처(반복해서 쓰는 유저): ① 보석 홈 등급 올리기(힘) ② 순수 소모(펫 합성 · 보석 다시 굴리기 · 보관함) = 번 골드의 frac
	if sink then
		state.spend.p2sink = state.spend.p2sink or 0
		state.spend.gemHome = state.spend.gemHome or 0
		if sink.home and state.rebirth >= 5 then
			local a = state.abilities
			a.__p2home = a.__p2home or 0
			while a.__p2home < sink.home.steps and state.reach >= sink.home.stageGate * (a.__p2home + 1) do
				local c = 4.95 * Mg(state.reach) * sink.home.kills * sink.home.growth ^ a.__p2home
				if state.gold < c then break end
				state.gold -= c
				state.spend.gemHome += c
				a.__p2home += 1
			end
		end
		if sink.frac and sink.frac > 0 then
			local c = math.min(state.gold, earned * sink.frac)
			state.gold -= c
			state.spend.p2sink += c
		end
	end
	return r
end
if sink and sink.home then
	local prevBucket = Training.bucketBonus
	Training.bucketBonus = function(training, abilities, classId, bucket)
		local v = prevBucket(training, abilities, classId, bucket)
		if bucket == "attack" and type(abilities) == "table" and abilities.__p2home then
			v += sink.home.pctPerStep * abilities.__p2home
		end
		return v
	end
end

PROG2.report = function(run)
	local st = run.final
	for k, v in pairs(PROG2.log) do
		print(("X_LOG|%s|%s"):format(k, table.concat(v, "|")))
	end
	print(("X_INC|earned %.4g|newinc %.4g|pet %.4g|cls %s|home %s"):format(st.p2earned or 0, st.p2income or 0, st.p2pet or 0, tostring(st.abilities.__p2cls), tostring(st.abilities.__p2home)))
	if PROG2.compAt then
		local t = {}
		for _, s in ipairs({ 100, 500, 1000, 2000, 5000, 10000, 20000, 25300 }) do
			table.insert(t, ("%d:%.3f"):format(s, PROG2.compAt(s)))
		end
		print("X_COMP|" .. table.concat(t, " "))
	end
	local t = {}
	for _, s in ipairs({ 100, 1000, 5000, 10000, 17000, 25300 }) do
		table.insert(t, ("%d:%.4g"):format(s, Mg(s)))
	end
	print("X_MG|" .. table.concat(t, " "))
end
