-- SEC-FIX-1 5 구역 밖 사냥 · 공격 재현 하네스(실제 MonsterState · UltimateService · AttackZone + 보스전 대역).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py AttackZone,UltimateService,MonsterState) ECON_RES=res_seczone.txt python build_run.py sec_zone_test.luau
-- 옛 코드 실패 확인 = ECON_SRC=<옛 src>(옛 = AttackZone 없음 → 옛 판정 ZoneBounds.isInside(공격자, 대상 zoneKey) 그대로 · 화살비 = 조준점 기준 후보).
-- 묶음: 보스 아레나 밖(비멤버) · 구역 담장 밖 조준(화살비) · 보물상자 흡혈 · 충전 - 끝 줄 "[SECZONE] 끝 n/m".
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[SECZONE] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local ENC = {} -- [model] = encounter
typeof = function(v) -- prelude typeof = type → Vector3도 "table"이라 조준 검사가 늘 거절됐다(Vector3만 알아본다)
	if type(v) == "table" and getmetatable(v) == V3MT then
		return "Vector3"
	end
	return type(v)
end
LOADERS["BossEncounter"] = function()
	return {
		getEncounterByModel = function(m) return ENC[m] end,
		getEncounter = function() return nil end,
		getActive = function() return nil end,
		classChangeBlocked = function() return false end,
	}
end
local okRun, err = pcall(function()
	local MonsterState, ZoneBounds, WorldConfig = MODS.MonsterState, MODS.ZoneBounds, MODS.WorldConfig
	local AZ = LOADERS["AttackZone"] and MODS.AttackZone or nil
	-- 옛 코드 = AttackZone 없음: 옛 판정(공격자 위치가 대상 zoneKey 구역 안 - zoneKey 없으면 통과)을 그대로 쓴다
	local canHit = AZ and AZ.canHit or function(_, pos, model) return ZoneBounds.isInside(pos, MonsterState.getZoneKey(model)) end
	local zoneKey, zone
	for k, z in pairs(WorldConfig.zones) do
		if z.role == "tier" and z.center then
			zoneKey, zone = k, z
			break
		end
	end
	check("시험 구역 있음(사냥 구역 원)", zone ~= nil, tostring(zoneKey))
	local R = zone.radius or zone.halfSize
	local inside = zone.center + Vector3.new(R - 6, 0, 0) -- 경계 바로 안(담장 너머 조준 거리 안)
	local outside = zone.center + Vector3.new(R + 6, 0, 0) -- 경계 바로 밖
	local function mkModel(name, pos)
		return { Name = name, Parent = true, PrimaryPart = { Position = pos }, SetAttribute = function() end, GetAttribute = function() return nil end }
	end
	local attrs = {}
	local member = { Name = "Member", UserId = 1, Parent = true, SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end }
	local outsider = { Name = "Outsider", UserId = 2, Parent = true, SetAttribute = function() end, GetAttribute = function() return nil end }

	-- ═══ 보스(아레나 = zoneKey 없음) - 비멤버가 벽 너머에서 ═══
	local boss = mkModel("Boss", Vector3.new(5000, 0, 5000))
	MonsterState.init(boss, { isBoss = true, hp = 1000 }, boss.PrimaryPart.Position, nil, {})
	ENC[boss] = { members = { member }, model = boss }
	check("5 보스 = 보스전 멤버는 맞힘", canHit(member, boss.PrimaryPart.Position, boss) == true)
	check("5 보스 = 비멤버(아레나 벽 너머)는 못 맞힘(옛 = zoneKey 없어 항상 통과)", canHit(outsider, Vector3.new(4900, 0, 5000), boss) == false)

	-- ═══ 잡몹 = 공격자가 구역 안이어야 ═══
	local mob = mkModel("Mob", inside)
	MonsterState.init(mob, { isBoss = false, hp = 100 }, inside, zoneKey, {})
	check("5 잡몹 = 구역 안 공격자 O · 담장 밖 공격자 X", canHit(member, inside, mob) == true and canHit(member, outside, mob) == false)
	check("5 조준점 = 시전자와 같은 구역이어야(AttackZone.sameArea)", AZ ~= nil and AZ.sameArea(inside, inside + Vector3.new(3, 0, 0)) and not AZ.sameArea(outside, inside))

	-- ═══ 화살비(UltimateService - 실제 발동 · 조준점 vs 시전자 구역) ═══
	local U = MODS.UltimateService
	local struck = {}
	U.register(function(_, _, target) table.insert(struck, target) return {} end, function(position, player)
		-- SkillServer가 거는 후보 함수와 같은 계약(옛 = 위치 하나 · 새 = 캐스터 위치 + 사람)
		local all = MonsterState.getAllModels()
		if AZ then
			return AZ.filter(player, position, all)
		end
		local out = {}
		for _, m in ipairs(all) do
			if ZoneBounds.isInside(position, MonsterState.getZoneKey(m)) then table.insert(out, m) end
		end
		return out
	end)
	local MAX = MODS.UltimateData.max
	U.set(member, MAX)
	local rootOut = { Position = outside, CFrame = { LookVector = Vector3.new(1, 0, 0) } }
	local okRain, why = U.cast(member, "bow", rootOut, inside) -- 담장 밖에서 구역 안쪽 조준
	local hitMob = false
	for _, t in ipairs(struck) do hitMob = hitMob or t == mob end
	check("5 화살비 = 담장 밖에서 안쪽 조준 거절 · 몹 안 맞음(옛 = 조준점 기준 후보라 맞음)", not okRain and not hitMob, ("발동 %s(%s) · 맞음 %s"):format(tostring(okRain), tostring(why), tostring(hitMob)))
	check("5 화살비 거절 = 게이지 그대로(안 씀)", U.get(member) == MAX, tostring(U.get(member)))
	struck = {}
	local rootIn = { Position = inside - Vector3.new(2, 0, 0), CFrame = { LookVector = Vector3.new(1, 0, 0) } }
	U.set(member, MAX)
	local okRain2, why2 = U.cast(member, "bow", rootIn, inside)
	hitMob = false
	for _, t in ipairs(struck) do hitMob = hitMob or t == mob end
	check("5 화살비 = 구역 안에서 조준 = 몹 맞음(정상 경로 그대로)", okRain2 and hitMob, ("발동 %s(%s) · 맞음 %s"):format(tostring(okRain2), type(why2) == "string" and why2 or "", tostring(hitMob)))

	-- ═══ 보물상자(AUDIT1 #19) - 세지 않은 연타 = 피해 0 · 상자 타격 = 충전 0 ═══
	local chest = mkModel("Chest", inside)
	MonsterState.init(chest, { isBoss = false, hp = 1 }, inside, zoneKey, { isChest = true })
	local _, d1 = MonsterState.applyDamage(chest, 500, 1, member)
	local _, d2 = MonsterState.applyDamage(chest, 500, 1, member) -- 간격 안 연타(세지 않음)
	check("5 상자 간격 안 연타 = 들어간 피해 0(옛 = 500 → 흡혈 · 충전)", d2 == 0, ("첫 %s · 연타 %s"):format(tostring(d1), tostring(d2)))
	U.set(member, 0)
	U.onDealt(member, "greatsword", 5, 0, false, 0, chest) -- 스킬 경로 = 계수(units)로 충전
	U.onDealt(member, "dualblade", 1, 0, true, 0, chest)
	check("5 상자 타격 = 궁극기 충전 0(옛 = 계수 · 타수로 충전)", U.get(member) == 0, tostring(U.get(member)))
	U.onDealt(member, "dualblade", 1, 100, false, 0, mob)
	check("5 정상 몹 타격 = 충전 그대로", U.get(member) > 0, tostring(U.get(member)))
end)
if not okRun then print("[SECZONE] 하네스 에러 " .. tostring(err)) end
print(("[SECZONE] 끝 %d/%d"):format(pass, total))
