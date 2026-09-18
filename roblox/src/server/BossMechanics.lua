-- 보스 6종 공통 뼈대(29-1, PRD 20.73 [2-8]) 중 "기믹 실패 피해"와 "파훼 게이트". 잡힘/구출은
-- BossTrap.lua, 스케줄(priority·firstAtSeconds)과 기믹 패턴의 예고→판정 흐름은 BossPatterns.lua.
--
-- A-1 %최대체력 피해 문(門): 보스가 주는 방어 무시 피해는 전부 여기로 들어온다.
--   · applyMaxHpDamage - 기믹형 패턴(돌진). 값은 패턴 데이터 그대로.
--   · applyGimmickDamage - 기믹 실패. "기믹 1회 발동에서 한 사람이 받는 %피해 합 ≤
--     BossData.mechanics.gimmickFailMaxHpFraction"을 여기서 자른다 - "기믹 실패 1회로 죽지 않는다"가
--     보스별 수치가 아니라 구조로 보장된다. 누적은 onGimmickStart가 발동마다 비운다.
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
		st = { gateStarted = false, gateArmed = false, windowToken = 0, gimmickDamage = {} }
		states[model] = st
	end
	return st
end

-- ─────────────────────────── 파훼 게이트 ───────────────────────────

-- window(선택) = { seconds, damageTakenMultiplier } - 파훼 직후의 기회 창(보스별 데이터).
local function setGate(model, armed, window)
	local st = stateOf(model)
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

-- 기믹 패턴이 시작될 때(BossPatterns) - 1인 누적 %피해를 비우고, 첫 기믹이면 게이트를 세운다.
function BossMechanics.onGimmickStart(model)
	local st = stateOf(model)
	st.gimmickDamage = {}
	if not st.gateStarted then
		st.gateStarted = true
		setGate(model, true)
		print(("[forge-game] 파훼 게이트: 섰다(받는 피해 ×%.3f)"):format(BossRules.gateDamageTakenMultiplier()))
	end
end

-- 전멸 리셋(BossPatterns.reset) - 처음 상태로.
function BossMechanics.reset(model)
	local st = stateOf(model)
	st.gateStarted = false
	st.gimmickDamage = {}
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
	return PlayerDamage.applyMaxHpFraction(player, applied, label), applied
end

-- 기믹 실패 1인분 = %피해 + 잡힘. fraction을 생략하면 전체 실패(gimmickFailMaxHpFraction).
-- 잡힘 종류는 그 보스의 data.mechanics(BossData SPECIES_MECHANICS) - 없으면 피해만.
function BossMechanics.failGimmick(model, data, player, label, fraction)
	local damage = BossMechanics.applyGimmickDamage(model, player, fraction or BossData.mechanics.gimmickFailMaxHpFraction, label)
	local species = data.mechanics
	if species and species.trapKind then
		BossTrap.trap(player, { kind = species.trapKind, rescueType = species.rescueType })
	end
	return damage
end

-- ─────────────────────────── 파훼 판정 ───────────────────────────

function BossMechanics.registerJudge(kind, fn)
	judges[kind] = fn
end

-- 기믹 패턴의 예고가 끝나는 순간(BossPatterns) - victims = { { player, root }, ... }.
-- 사람마다 판정해 실패자에게 failGimmick을 넣고, 한 명이라도 성공했으면 게이트를 연다.
-- 반환: broken(bool), 성공 인원, 실패 인원.
function BossMechanics.resolveGimmick(model, data, cfg, victims, label)
	local judge = judges[cfg.kind]
	local safeCount, failCount = 0, 0
	for _, v in ipairs(victims) do
		-- 이미 잡혀 있는 사람은 판정 밖이다(면역이고, 성공으로도 세지 않는다).
		if not BossTrap.isTrapped(v.player) then
			local safe = true
			if judge then
				safe = judge(model, data, v) == true
			end
			if safe then
				safeCount += 1
			else
				failCount += 1
				BossMechanics.failGimmick(model, data, v.player, label)
			end
		end
	end
	local broken = safeCount > 0
	setGate(model, not broken, broken and cfg.breakWindow or nil)
	print(("[forge-game] 기믹 판정: %s - 성공 %d명·실패 %d명 → 게이트 %s(받는 피해 ×%.3f)"):format(
		tostring(cfg.kind), safeCount, failCount, broken and "열림" or "유지", MonsterState.getDamageTakenMultiplier(model)))
	return broken, safeCount, failCount
end

-- 매 보스 틱(BossPatterns.step) - 잡힌 멤버의 구출 핸들러를 돌린다.
function BossMechanics.tick(members, dt)
	BossTrap.tick(members, dt)
end

return BossMechanics
