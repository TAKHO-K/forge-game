-- K1 궁극기(T) - 게이지 · 충전 · 발동 상태(수치 = shared/data/UltimateData). 서버만 게이지를 가진다(클라 표시 = Player Attribute UltGauge · 요청 = SkillRequest "T").
--   충전 훅: AttackServer(평타 적중) · SkillServer(스킬 타격 · strikeTarget) · PlayerDamage.takeDamage(받은 피해) · SkillServer 치유 → onDealt / onTaken / onHeal.
--   보스 입장 = 0(BossEncounter.onEncounterStarted 멤버 전원) · 사냥 중 충전 × huntChargeScale.
--   타격 함수(strike)는 SkillServer가 register로 넘긴다(스킬과 같은 피해 경로 - 치명 · 힐러 버프 · 처치 보상 · 피해 숫자).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UltimateData = require(ReplicatedStorage.Shared.data.UltimateData)
local SkillCombat = require(ReplicatedStorage.Shared.SkillCombat)
local PlayerState = require(script.Parent.PlayerState)
local MonsterState = require(script.Parent.MonsterState)

local U = {}

local gauge = {} -- [Player] = 0 ~ max
local transformUntil = {} -- [Player] = os.clock() 만료(대검)
local marks = {} -- [Player] = { target, untilAt, stored }(쌍검)
local sanctuaries = {} -- { caster, center, radius, untilAt }(치유사)
local candidatesAt -- function(position) → 같은 구역 몹 목록(SkillServer filterSameZone - 리뷰 1)
local striker -- function(player, classId, target, coefficient, extraDamage) → hit(SkillServer - extraDamage = 계수 피해에 더할 고정 피해)
local stats = { casts = 0, rejects = {} } -- 검증 · 개발 명령

local function isBossFight(player)
	local BossEncounter = require(script.Parent.BossEncounter)
	return BossEncounter.getActive(player) ~= nil
end

local function publish(player)
	if typeof(player) == "Instance" and player:IsA("Player") then
		player:SetAttribute("UltGauge", math.floor((gauge[player] or 0) * 10 + 0.5) / 10)
	end
end

function U.register(strikeFn, candidatesFn)
	striker = strikeFn
	candidatesAt = candidatesFn
end

local function candidates(position)
	return candidatesAt and candidatesAt(position) or MonsterState.getAllModels()
end

function U.get(player)
	return gauge[player] or 0
end

function U.set(player, value)
	gauge[player] = math.clamp(value, 0, UltimateData.max)
	publish(player)
end

-- 충전(보스 밖이면 사냥 배율)
function U.add(player, amount)
	if not amount or amount <= 0 or amount ~= amount then
		return
	end
	local scale = isBossFight(player) and 1 or UltimateData.huntChargeScale
	U.set(player, U.get(player) + amount * scale)
end

-- 준 피해: units = 타 단위(atk로 나눈 계수) · dealt = 실제 피해 · distance = 시전자 ↔ 대상(활)
function U.onDealt(player, classId, units, dealt, isCrit, distance, target)
	local c = UltimateData.charge[classId]
	if c then
		if classId == "greatsword" or classId == "healer" then
			U.add(player, (units or 0) * c.perDamageUnit)
		elseif classId == "dualblade" then
			U.add(player, c.perHit * (isCrit and c.critWeight or 1))
		elseif classId == "bow" then
			U.add(player, c.perHit * ((distance or 0) >= c.farStuds and c.farWeight or 1))
		end
	end
	-- 쌍검 표식: 표식 대상에게 준 피해의 storeFraction을 모은다
	local mark = marks[player]
	if mark and target == mark.target and os.clock() < mark.untilAt then
		mark.stored += (dealt or 0) * UltimateData.skills.dualblade.storeFraction
	end
end

function U.onTaken(player, damage)
	local c = UltimateData.charge.greatsword
	if typeof(player) ~= "Instance" or player:GetAttribute("ClassId") ~= "greatsword" then
		return
	end
	local maxHp = PlayerState.getMaxHp(player) or 0
	if maxHp > 0 then
		U.add(player, damage / maxHp * c.perTakenMaxHp)
	end
end

function U.onHeal(player, amount, targetMaxHp)
	if typeof(player) ~= "Instance" or player:GetAttribute("ClassId") ~= "healer" or not targetMaxHp or targetMaxHp <= 0 then
		return
	end
	U.add(player, amount / targetMaxHp * UltimateData.charge.healer.perHealMaxHp)
end

-- 대검 변신: 최종 피해 배율 · 넉백 · 경직 면역
function U.damageMultiplier(player)
	return (transformUntil[player] or 0) > os.clock() and (1 + UltimateData.skills.greatsword.attackBonus) or 1
end

function U.isUnstoppable(player)
	return (transformUntil[player] or 0) > os.clock()
end

-- 치유사 성역: 이 사람이 성역 안인가(시전자 본인 · 같은 파티)
function U.hasHpFloor(player)
	local now = os.clock()
	local character = typeof(player) == "Instance" and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local PartyState = require(script.Parent.PartyState)
	for _, s in ipairs(sanctuaries) do
		if now < s.untilAt then
			local dx, dz = root.Position.X - s.center.X, root.Position.Z - s.center.Z
			local sameTeam = s.caster == player or (PartyState.getParty(player) ~= nil and PartyState.getParty(player) == PartyState.getParty(s.caster))
			if sameTeam and dx * dx + dz * dz <= s.radius * s.radius then
				return true
			end
		end
	end
	return false
end

-- 대검 변신 중 평타 적중 → 앞쪽 원 충격파(평타 대상 제외)
function U.onBasicHit(player, classId, rootPart, primaryTarget)
	if classId ~= "greatsword" or not U.isUnstoppable(player) or not striker or not rootPart then
		return
	end
	local def = UltimateData.skills.greatsword.shockwave
	local center = rootPart.Position + rootPart.CFrame.LookVector * def.forwardStuds
	for _, target in ipairs(SkillCombat.hitsInCircle(center, def.radiusStuds, candidates(center))) do
		if target ~= primaryTarget then
			striker(player, classId, target, def.coefficient)
		end
	end
end

local function reject(player, reason)
	stats.rejects[reason] = (stats.rejects[reason] or 0) + 1
	print(("[K1] 궁극기 거부: %s - %s(게이지 %.1f)"):format(player.Name, reason, U.get(player)))
	return false, reason
end

-- 발동(SkillServer handleSkill "T"). aimPoint = 클라가 보낸 클릭 지점(활만 - 거리 검사). 반환: ok, reason | 결과 표
function U.cast(player, classId, rootPart, aimPoint)
	local def = UltimateData.skills[classId]
	if not def then
		return reject(player, "no_skill")
	end
	if U.get(player) < UltimateData.max then
		return reject(player, "gauge")
	end
	if not striker then
		return reject(player, "not_ready")
	end
	local now = os.clock()
	if def.shape == "ultRain" then
		if typeof(aimPoint) ~= "Vector3" or aimPoint ~= aimPoint or (aimPoint - rootPart.Position).Magnitude > def.maxCastStuds then
			return reject(player, "aim")
		end
	end
	local markTarget
	if def.shape == "ultMark" then
		local best, bestD = nil, def.rangeStuds
		for _, model in ipairs(candidates(rootPart.Position)) do
			local root = model.PrimaryPart
			local data = MonsterState.getData(model)
			if root and data and not data.isChest and not data.isRescueTarget then
				local d = (root.Position - rootPart.Position).Magnitude
				if d <= bestD then
					best, bestD = model, d
				end
			end
		end
		if not best then
			return reject(player, "no_target") -- 대상이 없으면 게이지를 쓰지 않는다
		end
		markTarget = best
	end

	U.set(player, 0)
	stats.casts += 1
	print(("[K1] 궁극기 발동: %s - %s(%s)"):format(player.Name, def.name, def.shape))

	if def.shape == "ultTransform" then
		transformUntil[player] = now + def.durationSeconds
		player:SetAttribute("UltTransform", def.bodyScale)
		task.delay(def.durationSeconds, function()
			if (transformUntil[player] or 0) > os.clock() + 0.05 then
				return -- 리뷰 8: 그 사이 다시 변신했다 - 뒤의 변신이 끝낸다
			end
			transformUntil[player] = nil
			if player.Parent then
				player:SetAttribute("UltTransform", nil)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					for _, target in ipairs(SkillCombat.hitsInCircle(root.Position, def.finale.radiusStuds, candidates(root.Position))) do
						striker(player, classId, target, def.finale.coefficient)
					end
				end
			end
		end)
		return true, { kind = "ultTransform", seconds = def.durationSeconds }
	elseif def.shape == "ultRain" then
		local center = Vector3.new(aimPoint.X, aimPoint.Y, aimPoint.Z)
		player:SetAttribute("UltRain", ("%.1f,%.1f,%.1f|%d"):format(center.X, center.Y, center.Z, math.random(1, 1e6)))
		task.spawn(function()
			local interval = def.durationSeconds / def.tickCount
			for _ = 1, def.tickCount do
				task.wait(interval)
				if not player.Parent then
					return
				end
				for _, target in ipairs(SkillCombat.hitsInCircle(center, def.radiusStuds, candidates(center))) do
					striker(player, classId, target, def.coefficient / def.tickCount)
				end
			end
		end)
		return true, { kind = "ultRain", center = center, radiusStuds = def.radiusStuds, seconds = def.durationSeconds }
	elseif def.shape == "ultMark" then
		local mark = { target = markTarget, untilAt = now + def.durationSeconds, stored = 0 }
		marks[player] = mark
		markTarget:SetAttribute("UltMarkBy", player.UserId)
		task.spawn(function()
			while os.clock() < mark.untilAt do
				task.wait(0.1)
				if not markTarget.Parent or not MonsterState.getData(markTarget) then -- 표식 중 처치 → 게이지 반환
					if marks[player] == mark then
						marks[player] = nil
					end
					if player.Parent then
						U.set(player, U.get(player) + def.killRefund)
						print(("[K1] 죽음의 계약: 표식 대상 처치 → 게이지 +%d"):format(def.killRefund))
					end
					return
				end
			end
			if marks[player] == mark then
				marks[player] = nil
			end
			markTarget:SetAttribute("UltMarkBy", nil)
			if player.Parent and markTarget.Parent and MonsterState.getData(markTarget) then
				striker(player, classId, markTarget, def.burstCoefficient, mark.stored) -- 모은 피해를 폭발 기본 피해에 더한다(폭발 자체의 치명 굴림은 그대로)
				print(("[K1] 죽음의 계약 폭발: 모은 피해 %.1f + 기본 계수 %.1f"):format(mark.stored, def.burstCoefficient))
			end
		end)
		return true, { kind = "ultMark", target = markTarget, seconds = def.durationSeconds }
	elseif def.shape == "ultSanctuary" then
		local s = { caster = player, center = rootPart.Position, radius = def.radiusStuds, untilAt = now + def.durationSeconds }
		table.insert(sanctuaries, s)
		player:SetAttribute("UltSanctuary", ("%.1f,%.1f,%.1f|%d"):format(s.center.X, s.center.Y, s.center.Z, math.random(1, 1e6)))
		task.spawn(function()
			local PartyState = require(script.Parent.PartyState)
			while os.clock() < s.untilAt do
				task.wait(1)
				local members = PartyState.getParty(player) and PartyState.getMemberPlayers(PartyState.getParty(player)) or { player }
				for _, member in ipairs(members) do
					local character = typeof(member) == "Instance" and member.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					local hp, maxHp = PlayerState.getHp(member), PlayerState.getMaxHp(member)
					if root and hp and hp > 0 and maxHp and (Vector3.new(root.Position.X - s.center.X, 0, root.Position.Z - s.center.Z)).Magnitude <= s.radius then
						PlayerState.setHp(member, math.min(hp + maxHp * def.healPerSecondMaxHp, maxHp))
						require(script.Parent.PlayerDamage).syncHud(member)
					end
				end
			end
			local index = table.find(sanctuaries, s)
			if index then
				table.remove(sanctuaries, index)
			end
		end)
		return true, { kind = "ultSanctuary", center = s.center, radiusStuds = s.radius, seconds = def.durationSeconds }
	end
	return reject(player, "no_shape")
end

function U.stats()
	return stats
end

-- 검증 · 개발 명령(/gg ult selftest): 이 사람 자리에 성역을 편다(치유사가 아니어도)
function U.debugSanctuary(player, seconds)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		table.insert(sanctuaries, { caster = player, center = root.Position, radius = UltimateData.skills.healer.radiusStuds, untilAt = os.clock() + seconds })
	end
end

-- 보스 입장 = 0(파티 전원)
task.defer(function()
	local BossEncounter = require(script.Parent.BossEncounter)
	BossEncounter.onEncounterStarted(function(encounter)
		for _, member in ipairs(encounter.members or {}) do
			if typeof(member) == "Instance" and member:IsA("Player") then
				U.set(member, 0)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	gauge[player], transformUntil[player], marks[player] = nil, nil, nil
end)

return U
