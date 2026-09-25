-- 보스 6종 공통 뼈대(29-1, PRD 20.73 [2-8]) 중 "기믹 실패 피해"와 "파훼 게이트". 잡힘/구출은
-- BossTrap.lua, 스케줄(priority·firstAtSeconds)과 기믹 패턴의 예고→판정 흐름은 BossPatterns.lua.
--
-- A-1 %최대체력 피해 문(門): 보스가 주는 방어 무시 피해는 전부 여기로 들어온다.
--   · applyGimmickDamage - 스킬의 %최대체력 피해 전부(기믹 실패·돌진 - 29-2부터 돌진도 여기로 온다). "스킬 1회
--     발동에서 한 사람이 받는 %피해 합 ≤ BossData.mechanics.gimmickFailMaxHpFraction"을 여기서 자른다 - "실수 한
--     번으로 죽지 않는다"가 보스별 수치가 아니라 구조로 보장된다. 누적은 beginActivation이 발동마다 비운다.
--   · applyMaxHpDamage - 상한 없는 날 경로(구출 "닿기"의 구출자 피해처럼 스킬 발동 밖에서 주는 %피해용).
--   둘 다 PlayerDamage.applyMaxHpFraction을 탄다 - 받는 피해 배율(대시 50%)은 그대로 곱해지고
--   ("방어 무관이지 감소 무관이 아니다", 21-3), 잡힌 사람은 면역이다(PlayerDamage).
--
-- A-3 파훼 게이트: 보스의 받는 피해 배율(MonsterState.setDamageTakenMultiplier).
--   ① 첫 기믹 예고와 함께 선다(×g, g = BossRules.gateDamageTakenMultiplier ≈ 0.487).
--   ② 그 뒤로는 기믹 판정 순간에만 바뀐다 - 멤버 1명 이상이 성공하면 열리고(×1, breakWindow가
--      있으면 그 시간 동안 그 배율), 전원 실패면 선다.  ③ 전멸 리셋이면 처음 상태(안 선 상태)로.
--   파훼 조건은 보스마다 다르다 - registerJudge(kind, fn)로 꽂는다(파훼 판정 훅). fn(model, data,
--   victim) → true면 그 사람은 성공. 등록된 판정이 없는 kind는 전원 성공으로 친다(덜 만든 보스가
--   플레이어를 벌주지 않게).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local BossTrap = require(script.Parent.BossTrap)

local BossMechanics = {}

-- [Model] = { gateStarted, gateArmed, windowToken, gimmickDamage = { [Player] = 누적 fraction } }
-- 약한 키 - 보스 모델이 사라지면 같이 사라진다.
local states = setmetatable({}, { __mode = "k" })
local judges = {}

local function stateOf(model)
	local st = states[model]
	if not st then
		st = { gateStarted = false, gateArmed = false, windowToken = 0, gimmickDamage = {}, gimmickRounds = {} }
		states[model] = st
	end
	return st
end

-- ─────────────────────────── 파훼 게이트 ───────────────────────────

-- window(선택) = { seconds, damageTakenMultiplier } - 파훼 직후의 기회 창(보스별 데이터).
local function setGate(model, armed, window)
	local st = stateOf(model)
	if armed and not st.gateArmed then
		st.armedSince = os.clock()
	elseif not armed then
		st.armedSince = nil
	end
	st.gateArmed = armed
	st.windowToken += 1
	local multiplier = 1
	if armed then
		multiplier = BossRules.gateDamageTakenMultiplier()
	elseif window then
		multiplier = window.damageTakenMultiplier
		local token = st.windowToken
		task.delay(window.seconds, function()
			if states[model] == st and st.windowToken == token then
				MonsterState.setDamageTakenMultiplier(model, 1)
			end
		end)
	end
	MonsterState.setDamageTakenMultiplier(model, multiplier)
	if model.Parent then
		model:SetAttribute("GateArmed", armed) -- 클라(BossGateView)가 보스 머리 위 표시를 그린다
	end
end

function BossMechanics.isGateArmed(model)
	return stateOf(model).gateArmed
end

-- 게이트가 이어서 서 있은 시간(초). 안 서 있으면 0 - 스킬 발동 조건 gateArmedFor가 읽는다(29-2).
function BossMechanics.gateArmedSeconds(model)
	local st = stateOf(model)
	return st.armedSince and (os.clock() - st.armedSince) or 0
end

-- 스킬 하나가 시작될 때(BossPatterns.startSkill) - %최대체력 피해의 발동당 1인 누적을 비운다(29-2: 기믹뿐 아니라
-- 돌진 같은 %최대체력 스킬도 같은 상한 아래 있다).
function BossMechanics.beginActivation(model)
	stateOf(model).gimmickDamage = {}
end

-- 기믹 패턴이 시작될 때(BossPatterns) - 1인 누적 %피해를 비우고, 첫 기믹이면 게이트를 세운다.
function BossMechanics.onGimmickStart(model)
	local st = stateOf(model)
	st.gimmickDamage = {}
	st.zoneSteps = nil -- 29-4: 시한 안전 구역의 멤버별 기록은 기믹마다 새로 잰다
	if not st.gateStarted then
		st.gateStarted = true
		setGate(model, true)
		print(("[forge-game] 파훼 게이트: 섰다(받는 피해 ×%.3f)"):format(BossRules.gateDamageTakenMultiplier()))
	end
end

-- 29-4: 게이트의 판정이 기믹 스킬이 아니라 일반 스킬인 보스(폭풍 군주의 낙뢰 - skill.gate). 규칙은 같다: 첫 판정 스킬의
-- 예고와 함께 서고(armGateOnce), 그 뒤로는 판정 순간에만 바뀐다(judgeGate). 실패해도 %피해·잡힘은 없다 - 게이트만 남는다.
function BossMechanics.armGateOnce(model)
	local st = stateOf(model)
	if not st.gateStarted then
		st.gateStarted = true
		setGate(model, true)
		print(("[forge-game] 파훼 게이트: 섰다(받는 피해 ×%.3f)"):format(BossRules.gateDamageTakenMultiplier()))
	end
end

function BossMechanics.judgeGate(model, broken, window, kind)
	setGate(model, not broken, broken and window or nil)
	print(("[forge-game] 게이트 판정: %s - %s → 게이트 %s(받는 피해 ×%.3f)"):format(
		tostring(kind), broken and "성공" or "실패", broken and "열림" or "유지", MonsterState.getDamageTakenMultiplier(model)))
end

-- ─────────────────────────── 탱커 대비 훅(29-5, PRD 20.80 [F]) ───────────────────────────
-- 탱커 직업은 아직 없다 - 아래 둘은 자리만 있다(값은 늘 기본값이고, 버퍼는 아무도 채우지 않는다).

-- ③ 넉백·띄우기의 무게 계수. 1 = 기준, 클수록 무겁다(낮게·짧게 뜬다 - BossPatterns.runHitEffects가 나눈다). 무게 시스템
-- (PRD 20.80 [G])이 생기면 여기서 그 플레이어의 장비 무게를 읽는다. 지금은 전원 BossData.mechanics.tank.defaultWeightFactor.
function BossMechanics.weightFactorOf(_player)
	return BossData.mechanics.tank.defaultWeightFactor
end

-- ④ 반사 누적 버퍼 - "반사 대 반사"(탱커의 반사 ↔ 보스의 반사 태세)가 겹치는 동안 보스에게 들어가려던 피해가 쌓이는 곳.
--   { total = 쌓인 피해(보스 HP 눈금), byPlayer = { [때린 사람] = 피해 }, bounces = 오간 횟수, owner = 반사를 켠 탱커, startedAt }
-- 먼저 끝난 쪽이 total을 받는다(탱커의 반사가 먼저 끝나면 탱커가, 보스의 태세가 먼저 끝나면 보스가). 튕김은 피해가 아니라 연출의
-- 횟수라 서버가 도는 루프는 없다(bounces ≤ 태세 시간 ÷ reflect.windowSeconds). 지금은 아무도 add를 부르지 않는다.
function BossMechanics.reflectBufferOf(model)
	return stateOf(model).reflectBuffer
end

function BossMechanics.addToReflectBuffer(model, owner, attacker, damage)
	local st = stateOf(model)
	local buffer = st.reflectBuffer
	if not buffer then
		buffer = { total = 0, byPlayer = {}, bounces = 0, owner = owner, startedAt = os.clock() }
		st.reflectBuffer = buffer
	end
	buffer.total += damage
	buffer.byPlayer[attacker] = (buffer.byPlayer[attacker] or 0) + damage
	return buffer
end

-- 반환: 비우기 전의 버퍼(없었으면 nil) - 받는 쪽이 total을 읽는다.
function BossMechanics.clearReflectBuffer(model)
	local st = stateOf(model)
	local buffer = st.reflectBuffer
	st.reflectBuffer = nil
	return buffer
end

-- 전멸 리셋(BossPatterns.reset) - 처음 상태로.
function BossMechanics.reset(model)
	local st = stateOf(model)
	st.reflectBuffer = nil
	st.gateStarted = false
	st.gimmickDamage = {}
	st.gimmickRounds = {} -- BR1: 전멸 리셋 = 처음부터(첫 기믹 실패는 다시 55%)
	st.zoneSteps = nil
	st.reflect = nil
	MonsterState.setHitListener(model, nil)
	setGate(model, false)
end

-- DevTools "/gg boss gate on|off" 전용.
function BossMechanics.debugSetGate(model, armed)
	stateOf(model).gateStarted = true
	setGate(model, armed)
end

-- ─────────────────────────── %최대체력 피해 ───────────────────────────

function BossMechanics.applyMaxHpDamage(player, fraction, label)
	return PlayerDamage.applyMaxHpFraction(player, fraction, label)
end

-- 반환: 실제 들어간 피해, 이번에 적용된 fraction(상한에 잘렸으면 요청보다 작다).
function BossMechanics.applyGimmickDamage(model, player, fraction, label)
	local st = stateOf(model)
	local cap = BossData.mechanics.gimmickFailMaxHpFraction
	local taken = st.gimmickDamage[player] or 0
	local applied = math.min(fraction, cap - taken)
	if applied <= 0 then
		return 0, 0
	end
	st.gimmickDamage[player] = taken + applied
	local dealt = PlayerDamage.applyMaxHpFraction(player, applied, label)
	if dealt > 0 then
		BossTrap.noteSkillHit(player) -- 29-5: 예고가 있는 피격(기믹 실패·돌진·구덩이·반사)은 누르고 있던 구출을 처음으로 돌린다
	end
	return dealt, applied
end

-- BR1 핵심 기믹 실패(BossData.mechanics.gimmickFail - 85% · 쉴드 무시). 발동당 누적 상한도 그 값이다(같은 발동에서 먼저 받은 %피해만큼 줄어든다).
-- firstTime(BR1 조정): 그 보스전에서 이 기믹을 처음 판정하는 회차면 firstMaxHpFraction(55% - 배우는 한 번).
function BossMechanics.applyGimmickFailDamage(model, player, label, firstTime)
	local fail = BossData.mechanics.gimmickFail
	local st = stateOf(model)
	local taken = st.gimmickDamage[player] or 0
	local fraction = firstTime and fail.firstMaxHpFraction or fail.maxHpFraction
	local applied = math.min(fraction, fraction - taken)
	if applied <= 0 then
		return 0, 0
	end
	st.gimmickDamage[player] = taken + applied
	local dealt = PlayerDamage.applyMaxHpFraction(player, applied, label, { ignoresShield = fail.ignoresShield })
	if dealt > 0 then
		BossTrap.noteSkillHit(player)
	end
	return dealt, applied
end

-- 기믹 실패 1인분 = %피해 + 잡힘. fraction을 생략하면 전체 실패(BR1: gimmickFail 85% · 쉴드 무시).
-- 잡힘 종류는 그 보스의 data.mechanics(BossData SPECIES_MECHANICS) - 없으면 피해만.
function BossMechanics.failGimmick(model, data, player, label, fraction, firstTime)
	local damage
	if fraction then
		damage = BossMechanics.applyGimmickDamage(model, player, fraction, label)
	else
		damage = BossMechanics.applyGimmickFailDamage(model, player, label, firstTime)
	end
	BossMechanics.trapMember(model, data, player)
	return damage
end

-- 그 보스의 잡힘 종류로 잡는다(29-3: 기믹 실패와 마무리 일격이 같이 쓴다). 잡힌 자리와 아레나를 같이 남긴다 - 구출
-- 핸들러가 읽는다(얼음 덩어리를 세울 자리, 모래 무덤의 중심, 밀어도 벽 밖으로 안 나가게 하는 경계).
function BossMechanics.trapMember(model, data, player)
	local species = data.mechanics
	if not (species and species.trapKind) then
		return false
	end
	local character = player.Character -- 스탠드인(테이블 Player)도 자리를 남긴다
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return BossTrap.trap(player, {
		kind = species.trapKind, rescueType = species.rescueType,
		context = { origin = root and root.Position or nil, zoneKey = MonsterState.getZoneKey(model) },
	})
end

-- ─────────────────────────── 반사 태세(29-3) ───────────────────────────
-- 보스가 "태세"인 동안(전갈 여왕의 갑각) 받는 피해 배율이 stance.damageTakenMultiplier(0)가 되고, 그동안 보스를 때린
-- 사람에게 부분 실패 피해(gimmickFailMaxHpFraction ÷ partialFailDivisor)가 돌아간다.
--   · 누가: **때린 사람만**. 파티의 다른 멤버는 아무것도 받지 않는다(한 사람의 실수가 남에게 번지지 않는다).
--   · 몇 번: BossData.mechanics.reflect.windowSeconds(0.75초)에 한 번 - 그 사이 몇 번을 때려도 1회다. 합계는 발동당
--     1인 상한(applyGimmickDamage, 55%)에서 잘린다.
--   · 무엇이: **태세가 선 뒤에 시작한 직접 공격만**. 공격을 시작한 시각(hitInfo.committedAt - 평타·즉발 스킬은 맞은
--     순간, 투사체는 쏜 순간, 채널링은 시전 순간)이 태세 시작보다 이르면 반사하지 않는다 - 날아가던 화살·이미 돌던
--     회전베기는 0 피해로 끝날 뿐이다. 지연 폭발(꽂힌 화살)은 언제 꽂았든 반사하지 않는다(hitInfo.indirect).
--     플레이어가 막을 수 없는 반사는 반사가 아니라 벌이다.
-- 타격은 전부 MonsterState.applyDamage 한 곳을 지나므로 거기에 듣는 귀 하나만 단다(setHitListener).
function BossMechanics.beginReflect(model, stance, label, onReflected)
	local st = stateOf(model)
	local reflect = { startedAt = os.clock(), lastAt = {}, count = {} }
	st.reflect = reflect
	st.windowToken += 1 -- 지난 기회 창의 복귀 타이머가 태세 중에 배율을 1로 되돌리지 못하게
	MonsterState.setDamageTakenMultiplier(model, stance.damageTakenMultiplier)
	local mechanics = BossData.mechanics
	local fraction = mechanics.gimmickFailMaxHpFraction / mechanics.partialFailDivisor
	MonsterState.setHitListener(model, function(player, hitInfo)
		if hitInfo and hitInfo.indirect then
			return
		end
		local now = os.clock()
		if ((hitInfo and hitInfo.committedAt) or now) < reflect.startedAt then
			return
		end
		local last = reflect.lastAt[player]
		if last and now - last < mechanics.reflect.windowSeconds then
			return
		end
		reflect.lastAt[player] = now
		reflect.count[player] = (reflect.count[player] or 0) + 1
		BossMechanics.applyGimmickDamage(model, player, fraction, label)
		if onReflected then
			onReflected(player)
		end
	end)
end

-- 태세 끝(판정 직전·중단). 받는 피해 배율을 게이트 상태로 되돌린다 - 판정(resolveGimmick)이 곧바로 다시 정한다.
function BossMechanics.endReflect(model)
	local st = stateOf(model)
	MonsterState.setHitListener(model, nil)
	MonsterState.setDamageTakenMultiplier(model, st.gateArmed and BossRules.gateDamageTakenMultiplier() or 1)
end

-- ─────────────────────────── 시한 안전 구역(29-4) ───────────────────────────
-- 심해 군주의 단: 기믹이 도는 동안 **멤버마다** "그 구역을 처음 밟은 순간부터 언제까지 안전한가"를 적는다(BossPatterns가
-- 밟는 순간을 보고 적고, 파훼 판정 "onZone"이 읽는다). 한 사람의 시계는 다른 사람의 구역에 아무 영향이 없다.
-- 기록은 기믹이 시작될 때마다 비운다(onGimmickStart) - 범람마다 모든 단이 전원에게 새것이다.
-- beginZones(deadline): deadline = 판정(방전)이 예정된 시각. "버틴다"는 그 시각과 비교한다 - 판정 틱의 실제 시각(한두
-- 프레임 늦다)과 비교하면 정확히 제때 밟은 사람이 1/60초 차로 진다.
local ZONE_EDGE_SECONDS = 0.05 -- 가장자리는 플레이어에게 유리하게(3틱)

function BossMechanics.beginZones(model, deadline)
	local st = stateOf(model)
	st.zoneSteps = {}
	st.zoneDeadline = deadline
end

-- 반환: 이번 호출이 첫 밟기였으면 true.
function BossMechanics.noteZoneStep(model, player, zoneIndex, expiresAt)
	local st = stateOf(model)
	st.zoneSteps = st.zoneSteps or {}
	local mine = st.zoneSteps[player]
	if not mine then
		mine = {}
		st.zoneSteps[player] = mine
	end
	if mine[zoneIndex] then
		return false
	end
	mine[zoneIndex] = expiresAt
	return true
end

-- 이 사람에게 그 구역이 가라앉는 시각(os.clock 기준). 아직 안 밟았으면 nil.
function BossMechanics.zoneExpiresAt(model, player, zoneIndex)
	local steps = stateOf(model).zoneSteps
	return steps and steps[player] and steps[player][zoneIndex] or nil
end

-- 그 구역이 이 사람에게 판정 시각까지 버티는가. 아직 안 밟은 구역은 버틴다(방금 올라선 사람).
function BossMechanics.zoneHolds(model, player, zoneIndex)
	local expiresAt = BossMechanics.zoneExpiresAt(model, player, zoneIndex)
	local deadline = stateOf(model).zoneDeadline
	return expiresAt == nil or deadline == nil or expiresAt >= deadline - ZONE_EDGE_SECONDS
end

-- P3d B 검증: 이번 발동에서 이 사람에게 들어간 %최대체력 누적(기믹 누적 - 맵 이탈 복귀가 바꾸지 않는지 잰다).
function BossMechanics.gimmickDamageOf(model, player)
	return (stateOf(model).gimmickDamage or {})[player] or 0
end

-- 이번(마지막) 태세에서 이 사람이 반사를 받은 횟수 - 파훼 판정 "noHit"이 읽는다.
function BossMechanics.reflectCount(model, player)
	local reflect = stateOf(model).reflect
	return reflect and reflect.count[player] or 0
end

-- ─────────────────────────── 파훼 판정 ───────────────────────────

function BossMechanics.registerJudge(kind, fn)
	judges[kind] = fn
end

-- 기믹 패턴의 예고가 끝나는 순간(BossPatterns) - victims = { { player, root }, ... }.
-- 사람마다 판정해 실패자에게 failGimmick을 넣고, 한 명이라도 성공했으면 게이트를 연다. 판정 함수는
-- fn(model, data, victim, cfg)를 받는다(29-3: cfg = 그 기믹 스킬 - 어느 지형이 안전지대인가 같은 것을 데이터에서 읽는다).
-- 반환: broken(bool), 성공 인원, 실패 인원.
function BossMechanics.resolveGimmick(model, data, cfg, victims, label)
	local judge = judges[cfg.kind]
	local safeCount, failCount = 0, 0
	-- BR1: 이 기믹을 이 보스전에서 몇 번째 판정하는가(첫 회차 = 실패 55%, 그 뒤 85%). 전멸 리셋(reset)이면 다시 처음이다.
	local rounds = stateOf(model).gimmickRounds
	rounds[cfg] = (rounds[cfg] or 0) + 1
	local firstTime = rounds[cfg] == 1
	for _, v in ipairs(victims) do
		-- 이미 잡혀 있는 사람은 판정 밖이다(면역이고, 성공으로도 세지 않는다).
		if not BossTrap.isTrapped(v.player) then
			local safe = true
			if judge then
				safe = judge(model, data, v, cfg) == true
			end
			if safe then
				safeCount += 1
			else
				failCount += 1
				-- cfg.failPenalty == false: 실패의 대가를 판정 밖에서 이미 치렀다(갑각 반사 - 때릴 때마다 받았다). 게이트만 남는다.
				-- cfg.failTraps == false(29-5 파편 폭풍): %피해만 - 이 보스의 잡힘은 판정이 아니라 분신을 때린 순간에 온다.
				if cfg.failPenalty ~= false and cfg.failTraps == false then
					BossMechanics.applyGimmickFailDamage(model, v.player, label, firstTime) -- BR1: 첫 회차 55% · 그 뒤 85% · 쉴드 무시
				elseif cfg.failPenalty ~= false then
					BossMechanics.failGimmick(model, data, v.player, label, nil, firstTime)
				end
			end
		end
	end
	-- cfg.judgesGate == false(29-4 과충전): 이 기믹은 게이트를 바꾸지 않는다 - 피했다고 장막이 걷히지 않는다(걷는 것은 낙뢰뿐).
	local broken = safeCount > 0 and cfg.judgesGate ~= false
	if cfg.judgesGate ~= false then
		setGate(model, not broken, broken and cfg.breakWindow or nil)
	end
	print(("[forge-game] 기믹 판정: %s - 성공 %d명·실패 %d명 → 게이트 %s(받는 피해 ×%.3f)"):format(
		tostring(cfg.kind), safeCount, failCount, broken and "열림" or "유지", MonsterState.getDamageTakenMultiplier(model)))
	return broken, safeCount, failCount
end

-- 매 보스 틱(BossPatterns.step) - 잡힌 멤버의 구출 핸들러를 돌린다.
function BossMechanics.tick(members, dt)
	BossTrap.tick(members, dt)
end

return BossMechanics
