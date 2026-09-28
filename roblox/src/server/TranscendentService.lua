-- C5-7 초월 특수 옵션(서버 판정 - docs/design/transcendent-tier.md §4). 수치 = shared/data/TranscendentData.
--   C5-7b(사용자 결정): 아슬아슬 회피 · 강탈 · 역전 폐기 → 환영(장갑) · 광폭(갑옷) · 비상(신발 - 초기화 조건 = 공중 강공격 적중만).
--   환영 = AttackServer가 기본 공격 적중 뒤 rollPhantom → 추가타(피해 계산은 AttackServer - 평타와 같은 식). 광폭 = 전투 중 Attribute(FrenzyActive · FrenzyAttackBonus) → 이속(PlayerProfile) · 공속(AttackServer · 클라 예측) · 대시(DashServer) · 돌진형 스킬(SkillStats).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local AirState = require(script.Parent.AirState)

local T = {}

local event = Instance.new("RemoteEvent")
event.Name = "TranscendentEvent" -- 서버 → 클라: { kind = "airReset" | "phantom", ... }
event.Parent = ReplicatedStorage

local lastAirReset = {} -- [Player] = os.clock()
local phantomCounts = {} -- [Player] = 환영 추가타 수(heavyEvery번째 = 강공격 · 메모리만)
local rng = Random.new()
T.rng = rng -- 검증(표본 굴림)이 같은 굴림 경로를 쓴다

-- 부위 고정 옵션: 옛 item.special(plunder · reversal - v47)은 읽지 않는다(저장 구조 그대로 · 표가 정한다).
function T.specialOf(player, part)
	local item = PlayerProfile.getEquipped(player, part)
	if type(item) ~= "table" or item.grade ~= TranscendentData.gradeId then
		return nil
	end
	return TranscendentData.specialByPart[part]
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

-- ── 환영(장갑) ──
-- 공격 요청 1회당 한 번만 부른다(AttackServer). 반환 = nil(안 나감) | isHeavy(true = heavyEvery번째 → 강공격).
function T.rollPhantom(player)
	if not T.hasSpecial(player, "phantom") then
		return nil
	end
	local rule = TranscendentData.phantom
	if rng:NextNumber() >= rule.chance then
		return nil
	end
	local n = (phantomCounts[player] or 0) + 1
	phantomCounts[player] = n
	return n % rule.heavyEvery == 0
end

-- 추가타 연출(곁의 사람에게 - 판정과 무관한 표시 신호).
function T.firePhantomFx(player, position, isHeavy)
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude <= TranscendentData.phantom.sendStuds then
			event:FireClient(other, { kind = "phantom", owner = player, position = position, heavy = isHeavy })
		end
	end
end

-- ── 광폭(갑옷) ──
function T.frenzyActive(player)
	if not T.hasSpecial(player, "frenzy") then
		return false
	end
	local last = PlayerState.getLastCombatActionAt(player)
	return last ~= nil and os.clock() - last <= TranscendentData.frenzy.combatWindowSeconds
end

-- 대시 · 돌진형 스킬 쿨 배율(발동 중 0.8).
function T.dashCooldownScale(player)
	return T.frenzyActive(player) and TranscendentData.frenzy.dashCooldownScale or 1
end

-- 상태가 바뀐 순간만 Attribute · 이속을 다시 맞춘다(공격 · 피격 직후 AttackServer · PlayerDamage가 부르고, CombatPowerSync 1초 루프가 만료를 잡는다).
function T.syncFrenzy(player)
	local active = T.frenzyActive(player)
	if (player:GetAttribute("FrenzyActive") == true) ~= active then
		player:SetAttribute("FrenzyActive", active or nil)
		player:SetAttribute("FrenzyAttackBonus", active and TranscendentData.frenzy.attackSpeedBonus or nil) -- 클라 공속 예측(AttackInput · WeaponVisual)도 같은 값을 더한다
		PlayerProfile.refreshMovementSpeed(player)
	end
end

-- ── 비상(신발): 공중 강공격 적중 → 공중 행동 초기화(쿨 4초). 최고 높이 상한은 HeightGuard가 그대로 잰다(세션 정점은 안 건드린다). ──
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
	player:SetAttribute("AirJumpsUsed", 0) -- 클라 공중 점프 충전 표시(없으면 무시)
	event:FireClient(player, { kind = "airReset", why = why })
	return true
end

-- 강공격(3타)이 적에게 적중한 뒤(AttackServer - 근접 · 원거리 도달). 비상 초기화는 공중 강공격만.
function T.onHeavyHit(player, isAir)
	if isAir then
		return airReset(player, "airHeavy")
	end
	return false
end

-- 보스전 오라(타인에게 보임): Player Attribute TranscendentParts(0 ~ 3) - CombatPowerSync가 1초마다 갱신한다. 환영 표시 = PhantomGloves.
function T.syncAura(player)
	local n = T.equippedCount(player)
	if player:GetAttribute("TranscendentParts") ~= n then
		player:SetAttribute("TranscendentParts", n)
	end
	local phantom = T.hasSpecial(player, "phantom")
	if (player:GetAttribute("PhantomGloves") == true) ~= phantom then
		player:SetAttribute("PhantomGloves", phantom or nil)
	end
	T.syncFrenzy(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastAirReset[player], phantomCounts[player] = nil, nil
end)

if RunService:IsStudio() then -- 검증 · 개발 명령용
	T.debugAirReset = airReset
	function T.debugResetPhantom(player)
		phantomCounts[player] = nil
	end
end

return T
