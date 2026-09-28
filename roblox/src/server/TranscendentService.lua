-- C5-7 초월 특수 옵션 · 아슬아슬 회피(서버 판정 - docs/design/transcendent-tier.md §4 · §5). 수치 = shared/data/TranscendentData.
--   위험 범위 등록(registerDanger - BossPatterns 원형 패턴이 전조를 보낼 때) → 전조 종료 window 전 표본(안에 있던 사람) → 적중 뒤 grace 안 피해 0 + 밖이면 회피 이벤트.
--   회피 이벤트 → 강탈(파편 저장) · 비상(공중 행동 초기화). 강공격 적중 → 강탈 변환 · 역전 기절 · 비상 초기화. 보스 피해 +15% · Q 강화판은 훅(MonsterState.bossDamageHook · SkillStats).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local AirState = require(script.Parent.AirState)
local Reach = require(ReplicatedStorage.Shared.Reach)

local T = {}

local event = Instance.new("RemoteEvent")
event.Name = "TranscendentEvent" -- 서버 → 클라: { kind = "closeDodge" | "fragment" | "fragmentUsed" | "surge" | "airReset", ... }
event.Parent = ReplicatedStorage

local lastDamagedAt = {} -- [Player] = os.clock() (PlayerDamage.takeDamage가 부른다)
local fragments = {} -- [Player] = { key, fragment, at, bossModel }
local lastAirReset = {} -- [Player] = os.clock()
local stats = { registered = 0, sampled = 0, dodges = 0, hits = 0 } -- 검증 · 오판정 실측(/gg c5 dodge)
T.stats = stats
T.onCloseDodge = {} -- 검증 훅 목록(player, key)

function T.specialOf(player, part)
	local item = PlayerProfile.getEquipped(player, part)
	if type(item) ~= "table" or item.grade ~= TranscendentData.gradeId then
		return nil
	end
	return item.special or TranscendentData.specialByPart[part]
end

function T.hasSpecial(player, name)
	for part, special in pairs(TranscendentData.specialByPart) do
		if special == name and T.specialOf(player, part) == name then
			return true
		end
	end
	return false
end

-- 착용 중인 초월 부위 수(보스전 오라 - Player Attribute TranscendentParts).
function T.equippedCount(player)
	local n = 0
	for part in pairs(TranscendentData.specialByPart) do
		if T.specialOf(player, part) then
			n += 1
		end
	end
	return n
end

function T.noteDamaged(player)
	lastDamagedAt[player] = os.clock()
end

local function hpFraction(player)
	local hp, maxHp = PlayerState.getHp(player) or 0, PlayerState.getMaxHp(player) or 1
	return maxHp > 0 and hp / maxHp or 1
end

-- 역전: HP ≤ 50%(강공격 기절 · 보스 +15%) / ≤ 20%(Q 강화판)
function T.reversalActive(player)
	return T.hasSpecial(player, "reversal") and hpFraction(player) <= TranscendentData.reversal.stunThreshold
end

function T.surgeActive(player)
	return T.hasSpecial(player, "reversal") and hpFraction(player) <= TranscendentData.reversal.surgeThreshold
end

function T.bossDamageMultiplier(player)
	return T.reversalActive(player) and (1 + TranscendentData.reversal.bossBonus) or 1
end

function T.qCoefficientScale(player)
	return T.surgeActive(player) and TranscendentData.reversal.surgeCoefficient or 1
end

function T.qCooldownScale(player)
	return T.surgeActive(player) and TranscendentData.reversal.surgeCooldownScale or 1
end

-- 비상: 공중 행동 초기화(쿨 4초). 최고 높이 상한은 HeightGuard가 그대로 잰다(세션 정점은 안 건드린다).
local function airReset(player, why)
	if not T.hasSpecial(player, "soar") then
		return false
	end
	local now = os.clock()
	if lastAirReset[player] and now - lastAirReset[player] < TranscendentData.soar.resetCooldownSeconds then
		return false
	end
	local session = AirState.session(player)
	if not session then
		return false
	end
	lastAirReset[player] = now
	session.airAttacks, session.airDashes = 0, 0
	session.ledgeUsed = false
	player:SetAttribute("AirJumpsUsed", 0) -- 클라 공중 점프 충전 표시(DoubleJumpInput이 읽는다 - 없으면 무시)
	event:FireClient(player, { kind = "airReset", why = why })
	return true
end

local function grantFragment(player, key, bossModel)
	if not T.hasSpecial(player, "plunder") then
		return false
	end
	local fragment = TranscendentData.plunder.fragments[key] or TranscendentData.plunder.fallback
	fragments[player] = { key = key, fragment = fragment, at = os.clock(), bossModel = bossModel }
	player:SetAttribute("Fragment", fragment.kind)
	event:FireClient(player, { kind = "fragment", fragment = fragment.kind, label = fragment.label })
	return true
end

function T.fragmentOf(player)
	local f = fragments[player]
	if not f then
		return nil
	end
	-- 보스전 끝(모델 사라짐) 뒤 holdSeconds 지나면 소멸
	if (not f.bossModel or not f.bossModel.Parent) and os.clock() - f.at > TranscendentData.plunder.holdSeconds then
		fragments[player] = nil
		player:SetAttribute("Fragment", nil)
		return nil
	end
	return f
end

local function fireDodge(player, key, bossModel)
	stats.dodges += 1
	player:SetAttribute("CloseDodges", (player:GetAttribute("CloseDodges") or 0) + 1)
	event:FireClient(player, { kind = "closeDodge", key = key })
	grantFragment(player, key, bossModel)
	airReset(player, "dodge")
	for _, fn in ipairs(T.onCloseDodge) do
		task.spawn(fn, player, key)
	end
end

-- 위험 범위 등록(원형): members = 보스전 인원 · center · radius(· inner) · endsAt = 적중 시각(os.clock) · key = 패턴 primitive(파편 표 키) · bossModel.
--   inside(pos) = 수평 거리로 판정(호출부 판정과 같은 Reach.horizontalDistance).
function T.registerDanger(members, center, radius, inner, endsAt, key, bossModel)
	if type(members) ~= "table" or type(center) ~= "userdata" or type(radius) ~= "number" then
		return
	end
	local rule = TranscendentData.closeDodge
	local sampleAt = endsAt - rule.windowSeconds
	stats.registered += 1
	local function inside(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return false
		end
		local d = Reach.horizontalDistance(root.Position, center)
		return d <= radius and d >= (inner or 0)
	end
	task.delay(math.max(sampleAt - os.clock(), 0), function()
		local wasInside = {}
		for _, player in ipairs(members) do
			if player.Parent and inside(player) then
				wasInside[player] = true
				stats.sampled += 1
			end
		end
		if next(wasInside) == nil then
			return
		end
		task.delay(math.max(endsAt + rule.graceSeconds - os.clock(), 0), function()
			for player in pairs(wasInside) do
				if player.Parent then
					local damagedAt = lastDamagedAt[player]
					if not inside(player) and (not damagedAt or damagedAt < endsAt - 0.05) then
						fireDodge(player, key, bossModel)
					else
						stats.hits += 1
					end
				end
			end
		end)
	end)
end

-- 강공격(3타) 적중 뒤(AttackServer): 강탈 변환 · 역전 잡몹 기절 · 비상 공중 초기화. 반환 = 추가 타격 수(검증).
function T.onHeavyHit(player, target, attackerStage, atk, isAir, isBoss)
	local extra = 0
	local MonsterState = require(script.Parent.MonsterState)
	if T.reversalActive(player) and not isBoss and target and target.Parent then
		target:SetAttribute("StunUntil", os.clock() + TranscendentData.reversal.stunSeconds) -- MonsterAI가 읽는다(추격 · 평타 멈춤)
	end
	local f = T.fragmentOf(player)
	if f and target and target.PrimaryPart then
		local center = target.PrimaryPart.Position
		for _, model in ipairs(MonsterState.getAllModels()) do
			if model.PrimaryPart and Reach.horizontalDistance(model.PrimaryPart.Position, center) <= f.fragment.radius then
				MonsterState.applyDamage(model, atk * f.fragment.multiplier, attackerStage, player)
				extra += 1
			end
		end
		fragments[player] = nil
		player:SetAttribute("Fragment", nil)
		event:FireClient(player, { kind = "fragmentUsed", fragment = f.fragment.kind, center = center, radius = f.fragment.radius })
	end
	if isAir then
		airReset(player, "airHeavy")
	end
	return extra
end

-- 보스전 오라(타인에게 보임): Player Attribute TranscendentParts(0 ~ 3) - CombatPowerSync가 1초마다 갱신한다.
function T.syncAura(player)
	local n = T.equippedCount(player)
	if player:GetAttribute("TranscendentParts") ~= n then
		player:SetAttribute("TranscendentParts", n)
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastDamagedAt[player], fragments[player], lastAirReset[player] = nil, nil, nil
end)

-- 검증 · 개발 명령용
function T.debugGrantFragment(player, key)
	return grantFragment(player, key, nil)
end

function T.debugFireDodge(player, key)
	fireDodge(player, key, nil)
end

if RunService:IsStudio() then
	T.debugAirReset = airReset
end

return T
