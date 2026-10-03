-- QUEUE-N1004 C-1 ALL10-P1 초월 계승 오버레이(설계 · 시뮬 전용 - 게임은 이 모듈을 읽지 않는다). 입력 = EconSim.runProgress의 청크 기록(기준선) · 매개변수 = EconSimConfig.all10.
--   계승 = 태초 무기 +30(같은 직업)이 처음 된 청크에서 초월 무기 +0으로 바꾼다. 그 뒤 각 청크마다:
--   ① 새 성장 요소 = 항목별 분리 배수(초월 무기 기본 · 초월 강화(5칸 분할 납입) · 고급 수련 51 ~ 100 · 초월 보석) → 기준선 빌드 대비 공격 배수 M.
--   ② 몹 HP(스테이지 2,500 위는 구간 배율 상수라 1.02^s만 남는다) = 기준선 × 전역 재조정 C(s) × 그 사람의 돌파 계수 B(s − 계승 스테이지):
--      ln C = kappa · ln1.02 · max(0, s − curveStart) / ln B = −(1 − 1/breakR) · ln1.02 · min(s − S0, breakL).
--      처치 시간 목표가 같다는 EconSim 사냥 규칙 그대로 → 새 스테이지 s = (s − s_기준) · ln1.02 + ln C + ln B = ln M을 푼다.
--   ③ 골드 = 기준선 청크 수입 · 지출 × 1.001^(s − s_기준)(처치당 골드 비) · 새 소모처는 처치 환산(kills) × 그때 처치당 골드 - 가장 싼 것부터 살 수 있을 때마다.
--      고급 수련 상한 = 50 + (s − advCapStart) ÷ advCapStep(15,000에 100 - 지금 수련의 "스테이지 연동 상한"과 같은 꼴) · 방어 수련 = defUnlock부터(처치 속도엔 영향 없음 - 생존 축).
--   원형 = 세션 스크래치패드 all10.py(같은 식 - 하네스가 같은 결과인지 확인한다). 기본 꺼짐: EconSimConfig.all10.enabled = false면 run은 nil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconSimConfig = require(ReplicatedStorage.Shared.data.EconSimConfig)

local EconSimAll10 = {}

local LN = math.log(1.02)
local GOLD = math.log(1.001)

local function solveStage(sb, lnM, S0, P)
	local beta = 1 - 1 / P.breakR
	local function f(s)
		local x = math.clamp(s - S0, 0, P.breakL)
		local lnB = -beta * LN * x
		local lnC = P.curveKappa * LN * math.max(0, s - P.curveStart)
		return (s - sb) * LN + lnC + lnB - lnM
	end
	local lo, hi = sb - 3000, sb + 6000
	for _ = 1, 60 do
		local mid = (lo + hi) / 2
		if f(mid) > 0 then
			hi = mid
		else
			lo = mid
		end
	end
	return (lo + hi) / 2
end
EconSimAll10.solveStage = solveStage

-- 항목별 공격 배수(태초 +30 빌드 = 1) - 제안서 곱셈 표가 같은 함수를 쓴다
function EconSimAll10.attackParts(P, transSteps, advLevel)
	return {
		weapon = P.weaponBase,
		transEnhance = 1 + transSteps / P.transSub * P.transPerLevel,
		advTraining = 1 + (advLevel - 50) * P.advPerLevel,
		gem = P.gem,
	}
end

-- chunks = EconSim.runProgress(...).chunks · tutorialSeconds · params = nil이면 EconSimConfig.all10 · enable = false면 기준선 그대로(비교용)
function EconSimAll10.overlay(run, params, enable)
	local P = params or EconSimConfig.all10
	local cap = P.cap or 25300
	local rows, t = {}, run.tutorialSeconds or 0
	local prevBal, prevSp = 0, 0
	for _, c in ipairs(run.chunks) do
		local sec = c.seconds + c.bossSeconds
		t += sec
		local sp = 0
		for _, v in pairs(c.spend) do
			sp += v
		end
		table.insert(rows, { t = t / 3600, reach = c.reach, bal = c.goldBalance, inc = (c.goldBalance - prevBal) + (sp - prevSp), spend = sp - prevSp, perKill = c.goldPerKill or 0, wlv = c.weaponLevel or 0, grade = c.weaponGrade or 0 })
		prevBal, prevSp = c.goldBalance, sp
	end
	local i30
	for i, r in ipairs(rows) do
		if r.wlv >= 30 and r.grade >= 6 then
			i30 = i
			break
		end
	end
	local out = { i30 = i30, track = {}, reached = {}, spendNew = { trans = 0, adv = 0, dfn = 0 } }
	if not i30 then
		return out
	end
	local S0, t0 = rows[i30].reach, rows[i30].t
	local trans, adv, dfn = 0, 50, 0
	local bal = rows[i30].bal
	for i = i30, #rows do
		local r = rows[i]
		local sb = r.reach
		local s, M = sb, 1
		if enable ~= false then
			local parts = EconSimAll10.attackParts(P, trans, adv)
			M = parts.weapon * parts.transEnhance * parts.advTraining * parts.gem
			s = solveStage(sb, math.log(M), S0, P)
		end
		s = math.min(s, cap)
		local factor = math.exp(GOLD * (s - sb))
		local inc, sp, perKill = r.inc * factor, r.spend * factor, r.perKill * factor
		bal += inc - sp
		local newSp = 0
		if enable ~= false then
			local bought = true
			while bought do
				bought = false
				local opts = {}
				if trans < 20 * P.transSub then
					table.insert(opts, { "trans", P.transKills / P.transSub })
				end
				local advCap = math.min(100, 50 + math.max(0, (s - P.advCapStart) // P.advCapStep))
				if adv < advCap then
					table.insert(opts, { "adv", P.advK0 * P.advR ^ (adv - 50) })
				end
				if s >= P.defUnlock and dfn < P.defLevels then
					table.insert(opts, { "dfn", P.defK0 * P.defR ^ dfn })
				end
				table.sort(opts, function(a, b)
					return a[2] < b[2]
				end)
				for _, o in ipairs(opts) do
					local cost = o[2] * perKill
					if bal >= cost then
						bal -= cost
						newSp += cost
						out.spendNew[o[1]] += cost
						if o[1] == "trans" then
							trans += 1
							if trans == 20 * P.transSub then
								out.transDoneAt = { r.t, s }
							end
						elseif o[1] == "adv" then
							adv += 1
							if adv == 100 then
								out.advDoneAt = { r.t, s }
							end
						else
							dfn += 1
						end
						bought = true
						break
					end
				end
			end
		end
		for _, m in ipairs({ 1000, 5000, 10000, 12000, 15000, 20000, 25300 }) do
			if out.reached[m] == nil and s >= m then
				out.reached[m] = r.t
			end
		end
		table.insert(out.track, { t = r.t, s = s, sb = sb, inc = inc, spend = sp + newSp, bal = bal, M = M, trans = trans, adv = adv, dfn = dfn })
		if s >= cap then
			break
		end
	end
	out.S0, out.t0, out.final = S0, t0, { trans = trans / P.transSub, adv = adv, dfn = dfn }
	return out
end

-- 스위치(EconSimConfig.all10.enabled)가 꺼져 있으면 nil(기본) - 켜면 runProgress 뒤 오버레이 결과
function EconSimAll10.runIfEnabled(run)
	if not EconSimConfig.all10.enabled then
		return nil
	end
	return EconSimAll10.overlay(run, EconSimConfig.all10, true)
end

return EconSimAll10
