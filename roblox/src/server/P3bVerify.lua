-- P3b 자동 검증 - 장비 보기 비교(B) · 순위 창 서버 응답(A) · 스킬 툴팁 수치 = 실제 피해(D3). DevTools.server.lua가 부른다(docs/phase/P3b-log.md).
--   (가) runPure = 순수 함수(서버 시작 때): EquipCompare 줄 · 요약 · 카드 비공개 칸 · 굴림 위치 / SkillTooltipText 8종 글(수치는 합성 info).
--   (나) runLive = 실제 Player(보스 검증 체인 끝 - 무거운 P3a(가C2) 앞): 순위 창 board 응답(이름 표 · 내 줄) · 자기 장비 비교(차이 0) ·
--        **D3: 스킬 4개 표본을 실제 시전 경로(SkillServer handleSkill - Studio 전용 SkillCastDebug)로 쓰고 툴팁 수치(SkillStats.info = 툴팁 Remote와 같은 함수)와 실제 피해 · 회복량을 대조**.
--        직업은 검증 동안만 바꾸고 env.restore로 되돌린다. 검증이 만든 잡몹은 끝에서 전부 지운다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local EquipCompare = require(ReplicatedStorage.Shared.EquipCompare)
local SkillTooltipText = require(ReplicatedStorage.Shared.SkillTooltipText)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local Inherit = require(ReplicatedStorage.Shared.Inherit)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

local P3bVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[P3b][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function recorder.section(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			recorder.check(("%s 실행 중 에러: %s"):format(label, tostring(err)), false)
		end
	end
	function recorder.summary()
		return passCount, totalCount
	end
	return recorder
end

local function relNear(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= 1e-6 * math.max(1, math.abs(b))
end

local function findLine(lines, label)
	for _, entry in ipairs(lines) do
		if entry.label == label then
			return entry
		end
	end
	return nil
end

-- 툴팁 수치 표시 형식(SkillTooltipText.num과 같은 규칙 - 글에 그 값이 들어 있는지 대조용).
local function shown(value)
	if value < 100 then
		return (("%.1f"):format(value):gsub("%.0$", ""))
	end
	return NumberFormat.format(value)
end

-- ═══ (가) ═══

function P3bVerify.runPure()
	print("===P3b 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("B EquipCompare", function()
		local theirs = { classId = "greatsword", weapon = { gradeId = "legendary", level = 20, gems = { { grade = "epic", itemLevel = 40, option = { id = "attackPercent", roll = 1.1 } }, false, { grade = "rare", itemLevel = 30, option = { id = "crit", roll = 0.9, roll2 = 1.0 } }, false, false } },
			equipment = { gloves = { grade = "legendary", part = "gloves", itemLevel = 60, option = { id = "attackPercent", roll = 1.0 } } } }
		local mine = { classId = "greatsword", weapon = { gradeId = "epic", level = 15, gems = { { grade = "epic", itemLevel = 40, option = { id = "attackPercent", roll = 0.9 } }, false, false, false, false } },
			equipment = { gloves = { grade = "epic", part = "gloves", itemLevel = 50, option = { id = "attackPercent", roll = 1.0 } } } }
		local lines = EquipCompare.lines("weapon", theirs.weapon, mine.weapon, "greatsword", "greatsword", true)
		local grade, level, mult, gems = findLine(lines, "등급"), findLine(lines, "강화"), findLine(lines, "무기 배율"), findLine(lines, "보석")
		local expectT = PlayerCombat.gradeMultiplier(3) * Enhance.getTotalMultiplier(20)
		local expectM = PlayerCombat.gradeMultiplier(2) * Enhance.getTotalMultiplier(15)
		r.check(("B1 무기 비교: 등급 %s → %s(%s) · 강화 %s(%s) · 배율 %s vs %s 차이 %s(기대 %+.1f%%) · 보석 %s(%s)"):format(grade.theirs, grade.mine, grade.diff, level.diff, tostring(level.sign), mult.theirs, mult.mine, mult.diff,
			(expectT / expectM - 1) * 100, gems.theirs, gems.diff),
			grade.diff == "+1단계" and grade.sign == 1 and level.diff == "+5" and level.sign == 1 and relNear(EquipCompare.weaponMultiplier(theirs.weapon), expectT)
				and mult.diff == ("%+.1f%%"):format((expectT / expectM - 1) * 100) and mult.sign == 1 and gems.theirs == "2 / 5칸" and gems.diff == "+1")
		local glove = EquipCompare.lines("gloves", theirs.equipment.gloves, mine.equipment.gloves, "greatsword", "greatsword", true)
		local base, option, roll = findLine(glove, "기본 효과"), findLine(glove, "옵션"), findLine(glove, "굴림 위치")
		local baseDelta = Inherit.baseStat(theirs.equipment.gloves) - Inherit.baseStat(mine.equipment.gloves)
		r.check(("B2 장갑 비교: 기본 효과 %s vs %s 차이 %s(기대 %+.1f%%p = Inherit.baseStat) · 옵션 %s vs %s 차이 %s · 굴림 %s vs %s"):format(base.theirs, base.mine, base.diff, baseDelta * 100,
			option.theirs, option.mine, tostring(option.diff), roll.theirs, roll.mine),
			base.diff == ("%+.1f%%p"):format(baseDelta * 100) and base.sign == 1 and option.sign ~= nil and roll.theirs == "50%" and roll.mine == "50%" and roll.sign == 0)
		local noCompare = EquipCompare.lines("gloves", theirs.equipment.gloves, nil, "greatsword", nil, false)
		local anyMine = false
		for _, entry in ipairs(noCompare) do
			anyMine = anyMine or entry.mine ~= nil or entry.diff ~= nil
		end
		r.check(("B3 비교 끔: 줄 %d개 · 나 · 차이 칸 비어 있음 %s"):format(#noCompare, tostring(not anyMine)), #noCompare >= 5 and not anyMine)
		local crit = EquipCompare.lines("gem3", theirs.weapon.gems[3], nil, "greatsword", nil, false)
		local critLines = 0
		for _, entry in ipairs(crit) do
			if entry.label == "옵션" then
				critLines += 1
			end
		end
		r.check(("B4 치명 보석: 옵션 줄 %d개(기대 2 - 치확 · 치피) · 빈 칸 gem2 = %s"):format(critLines, tostring((EquipCompare.slotItem(theirs, "gem2")))), critLines == 2 and EquipCompare.slotItem(theirs, "gem2") == nil)
		local card = { classId = "bow", weapon = theirs.weapon }
		local _, hiddenArmor = EquipCompare.slotItem(card, "armor")
		local weaponItem, hiddenWeapon = EquipCompare.slotItem(card, "weapon")
		local gemItem = EquipCompare.slotItem(card, "gem1")
		r.check(("B5 리더보드 카드: 갑옷 비공개 %s · 무기 공개 %s · 보석 공개 %s"):format(tostring(hiddenArmor), tostring(weaponItem ~= nil and not hiddenWeapon), tostring(gemItem ~= nil)),
			hiddenArmor == true and weaponItem ~= nil and not hiddenWeapon and gemItem ~= nil)
		local summary, sign = EquipCompare.summary("weapon", theirs.weapon, mine.weapon, "greatsword", "greatsword")
		local rollLow, rollMid, rollHigh = EquipCompare.rollPercent(OptionData.rollMin), EquipCompare.rollPercent(1), EquipCompare.rollPercent(OptionData.rollMax)
		r.check(("B6 요약(무기 = 무기 배율 차이) %s(%s) · 굴림 위치 최소/중앙/최대 %.0f/%.0f/%.0f%%(기대 0/50/100)"):format(tostring(summary), tostring(sign), rollLow, rollMid, rollHigh),
			summary == mult.diff and sign == 1 and rollLow == 0 and math.abs(rollMid - 50) < 1e-9 and rollHigh == 100)
	end)

	r.section("D SkillTooltipText", function()
		local problems, built, labelsOk = {}, 0, 0
		for _, classId in ipairs(ClassData.order) do
			for _, slot in ipairs({ "Q", "E" }) do
				local def = SkillData[classId][slot]
				local hits = def.tickCount or 1
				local stats = { cooldown = def.cooldownSeconds, optionBonus = 0, hits = hits, speedMultiplier = 1.2, arrowDamage = 80, bonusDamage = 500, duration = 5, heal = 300, critHealMultiplier = 2,
					investmentScale = 1, attackMultiplier = 1.574, drainPerSecond = 0.012, active = false }
				if def.coefficient then
					stats.hitCoefficient = def.coefficient / hits
					stats.hitDamage = 1000 * stats.hitCoefficient
					stats.critHitDamage = stats.hitDamage * 2
					stats.castCoefficient = def.coefficient
					stats.castDamage = stats.hitDamage * hits
				end
				local info = { classId = classId, attack = 1000, critRate = 0.2, critDmg = 2, healerBuff = 0.25, slots = { [slot] = stats } }
				local result = SkillTooltipText.build(classId, slot, info)
				if not result then
					table.insert(problems, classId .. slot .. " 없음")
					continue
				end
				built += 1
				local has = {}
				for _, entry in ipairs(result.lines) do
					has[entry.label] = entry.text
					if type(entry.text) ~= "string" or entry.text:find("nil", 1, true) or entry.text == "" then
						table.insert(problems, ("%s%s %s = %s"):format(classId, slot, entry.label, tostring(entry.text)))
					end
				end
				local need = { "설명", "쿨타임", "발동" }
				if def.coefficient then
					table.insert(need, "계수")
					table.insert(need, "예상 피해")
					table.insert(need, "치명")
					table.insert(need, "최종 데미지")
					table.insert(need, "치유모드")
					table.insert(need, "최대 타격")
					table.insert(need, "관통")
					table.insert(need, "사거리 · 범위")
				end
				local ok = true
				for _, label in ipairs(need) do
					ok = ok and has[label] ~= nil
				end
				if def.coefficient then
					local pctText = (("%.1f"):format(def.coefficient * 100):gsub("%.0$", "")) .. "%"
					ok = ok and has["계수"]:find(pctText, 1, true) ~= nil and has["예상 피해"]:find(shown(stats.hitDamage), 1, true) ~= nil and has["예상 피해"]:find(shown(stats.critHitDamage), 1, true) ~= nil
				end
				if ok then
					labelsOk += 1
				else
					table.insert(problems, classId .. slot .. " 줄 부족")
				end
			end
		end
		r.check(("D1 툴팁 글 8종: 만들어짐 %d · 필수 줄(설명 · 쿨타임 · 발동 + 피해 스킬은 계수 · 예상 피해 · 사거리 · 최대 타격 · 관통 · 치명 · 최종 데미지 · 치유모드) 통과 %d · 문제 [%s]"):format(built, labelsOk, table.concat(problems, " / ")),
			built == 8 and labelsOk == 8 and #problems == 0)
		local loading = SkillTooltipText.build("greatsword", "Q", nil)
		r.check(("D2 수치 없음(서버 응답 전): 예상 피해 = %s"):format(findLine(loading.lines, "예상 피해").text), findLine(loading.lines, "예상 피해").text == "불러오는 중…")
	end)

	local passCount, totalCount = r.summary()
	print(("===P3b 검증 끝(가)=== %d/%d 통과"):format(passCount, totalCount))
end

-- ═══ (나) ═══

function P3bVerify.runLive(player, env)
	print("===P3b 검증 시작(나)===")
	local r = newRecorder("나")
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local Leaderboard = require(script.Parent.Leaderboard)
	local PlayerInspect = require(script.Parent.PlayerInspect)
	local SkillStats = require(script.Parent.SkillStats)
	local BuffState = require(script.Parent.BuffState)
	local MonsterSpawner = require(script.Parent.MonsterSpawner)
	local MonsterState = require(script.Parent.MonsterState)
	local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
	env.ensureBackup(player)
	local originalClass = PlayerProfile.getClassId(player)

	r.section("A 순위 창 board 응답", function()
		Leaderboard.debugResetRateLimit(player)
		local response = Leaderboard.handle(player, "board", "personal")
		local rank = Leaderboard.rankInCache("personal", player.UserId)
		local namedCount, entryCount = 0, #(response.entries or {})
		for _ in pairs(response.names or {}) do
			namedCount += 1
		end
		r.check(("A1 board(personal) 응답: 줄 %d · 이름 %d · 시즌 %s · 내 줄 %s(캐시 순위 %s) · 모드 %s · 가짜 채우기(검증 모드) %d(기대 0)"):format(entryCount, namedCount, tostring(response.season and response.season.id),
			response.mine and tostring(response.mine.rank) or "없음", tostring(rank), Leaderboard.writeMode(), Leaderboard.debugFill(player)),
			response.ok == true and type(response.names) == "table" and response.season ~= nil and ((rank == nil and response.mine == nil) or (response.mine and response.mine.rank == rank))
				and (entryCount == 0 or namedCount >= 1) and Leaderboard.debugFill(player) == 0)
		Leaderboard.debugResetRateLimit(player)
	end)

	r.section("B 자기 장비 비교", function()
		local result = PlayerInspect.handle(player, player.UserId)
		local data = result.ok and result.data
		local nonZero, checked = 0, 0
		for _, slotName in ipairs(EquipCompare.slotOrder) do
			local item = data and EquipCompare.slotItem(data, slotName)
			if item then
				for _, entry in ipairs(EquipCompare.lines(slotName, item, item, data.classId, data.classId, true)) do
					if entry.sign ~= nil then
						checked += 1
						if entry.sign ~= 0 then
							nonZero += 1
						end
					end
				end
			end
		end
		r.check(("B7 실제 스냅샷 자기 비교: 비교 줄 %d · 차이가 0이 아닌 줄 %d(기대 0)"):format(checked, nonZero), data ~= nil and checked >= 4 and nonZero == 0)
	end)

	r.section("D3 툴팁 = 실제 피해", function()
		local debugCast = ServerStorage:WaitForChild("SkillCastDebug", 5)
		assert(debugCast, "SkillCastDebug 없음")
		-- D3 동안 개발 캐릭터가 받는 피해 0(Play 3: 옆에 스폰한 잡몹이 대기 0.2초 사이에 캐릭터를 죽여 시전이 에러로 끝났다). 40초 뒤 저절로 풀린다(PlayerState 만료).
		require(script.Parent.PlayerState).setIncomingDamageMultiplierUntil(player, 0, 40)
		-- 5번째 = 난무 + 분신 확정 치명(첫 타가 치명 경로 - 툴팁 "치명" 값과 대조).
		local samples = { { "greatsword", "Q" }, { "greatsword", "E" }, { "dualblade", "E" }, { "healer", "Q" }, { "dualblade", "E", crit = true } }
		local spawned = {}
		local monstersBefore = {} -- 잡은 잡몹은 5초 뒤 같은 자리(플레이어 옆)에 리스폰한다(MonsterSpawner.despawn) - 끝에서 새로 생긴 것을 전부 지운다(Play 1: 안 지워 개발 캐릭터가 5초마다 죽었다)
		for _, model in ipairs(MonsterState.getAllModels()) do
			monstersBefore[model] = true
		end
		for _, sample in ipairs(samples) do
			local classId, slot = sample[1], sample[2]
			PlayerProfile.setClassId(player, classId)
			for _, buffId in ipairs({ "healerBuff", "guaranteedCrit", "dealingMode", "backstepShotBuff", "quickShot" }) do
				BuffState.clear(player, buffId)
			end
			if sample.crit then
				BuffState.apply(player, "guaranteedCrit", { durationSeconds = 5, displayName = "검증", colorName = "success" })
			end
			task.wait(0.1)
			local info = SkillStats.info(player) -- 툴팁 Remote(SkillInfoRequest)가 돌려주는 것과 같은 함수
			local stats = info.slots[slot]
			local text = SkillTooltipText.build(classId, slot, info)
			local models = {}
			-- 표본마다 지금 캐릭터를 다시 읽는다(Play 2: 표본 사이에 캐릭터가 죽어 리스폰했는데 옛 위치에 잡몹을 놓아 난무가 "대상 없음"이었다).
			local character = player.Character or player.CharacterAdded:Wait()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health <= 0 then
				character = player.CharacterAdded:Wait()
			end
			local root = character:WaitForChild("HumanoidRootPart", 5)
			assert(root, "캐릭터 없음")
			if SkillData[classId][slot].coefficient then
				local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
				look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
				for i = 1, 3 do
					local model = MonsterSpawner.spawn(MonsterData.tier1, root.Position + look * (4 + i * 2), nil, {})
					table.insert(models, model)
					table.insert(spawned, model)
				end
				task.wait(0.2)
			end
			local captured = debugCast:Invoke(player, slot)
			local hits, rows, allMatch = 0, {}, true
			if captured and captured.error then
				table.insert(rows, "시전 에러: " .. captured.error) -- 에러 글을 버리지 않는다(Play 3에서 "0개 []"로만 보였다)
				allMatch = false
			end
			local healAmount
			for _, event in ipairs(captured or {}) do
				local payload = event.payload
				if payload.ok == false then
					table.insert(rows, "거부 " .. tostring(payload.reason))
					allMatch = false
				end
				for _, hit in ipairs(payload.hits or {}) do
					if table.find(models, hit.target) then
						hits += 1
						local expected = hit.isCrit and stats.critHitDamage or stats.hitDamage
						local match = relNear(hit.damage, expected)
						allMatch = allMatch and match
						if #rows < 3 then
							table.insert(rows, ("%s %s(툴팁 %s)"):format(hit.isCrit and "치명" or "일반", shown(hit.damage), shown(expected)))
						end
					end
				end
				if payload.self then
					healAmount = payload.self.healAmount
					local expected = payload.self.isCrit and stats.heal * stats.critHealMultiplier or stats.heal
					local match = relNear(healAmount, expected)
					allMatch = allMatch and match
					table.insert(rows, ("회복 %s %s(툴팁 %s)"):format(payload.self.isCrit and "치명" or "일반", shown(healAmount), shown(expected)))
				end
			end
			local shownDamage = findLine(text.lines, stats.hitDamage and "예상 피해" or "회복량")
			local textOk = shownDamage ~= nil and shownDamage.text:find(shown(stats.hitDamage or stats.heal), 1, true) ~= nil
			local needHits = stats.hitDamage and 1 or 0
			BuffState.clear(player, "guaranteedCrit")
			r.check(("D3 %s %s(%s)%s: 툴팁 1타 %s · 치명 %s · 글 [%s] · 실제 타격 %d개 [%s] · 쿨 %s초"):format(ClassData.classes[classId].displayName, slot, SkillData[classId][slot].name, sample.crit and " + 확정 치명" or "",
				stats.hitDamage and shown(stats.hitDamage) or shown(stats.heal), stats.critHitDamage and shown(stats.critHitDamage) or shown(stats.heal * stats.critHealMultiplier),
				shownDamage and shownDamage.text or "-", hits, table.concat(rows, " · "), shown(stats.cooldown)),
				allMatch and textOk and hits >= needHits and (stats.hitDamage ~= nil or healAmount ~= nil) and (not sample.crit or table.concat(rows, " "):find("치명", 1, true) ~= nil))
			for _, model in ipairs(models) do
				if model.Parent then
					MonsterState.clear(model)
					model:Destroy()
				end
			end
		end
		task.wait(require(ReplicatedStorage.Shared.data.WorldConfig).zoneMonsterGrid.respawnDelaySeconds + 1)
		local respawned = 0
		for _, model in ipairs(MonsterState.getAllModels()) do
			if not monstersBefore[model] then
				respawned += 1
				MonsterState.clear(model)
				if model.Parent then
					model:Destroy()
				end
			end
		end
		local left = 0
		for _, model in ipairs(spawned) do
			if model.Parent then
				left += 1
			end
		end
		local leftNew = 0
		for _, model in ipairs(MonsterState.getAllModels()) do
			if not monstersBefore[model] then
				leftNew += 1
			end
		end
		r.check(("D4 검증 잡몹 %d마리 · 리스폰분 %d마리 정리 뒤 남은 것 %d · 새 몬스터 %d(기대 0 · 0)"):format(#spawned, respawned, left, leftNew), left == 0 and leftNew == 0)
	end)

	PlayerProfile.setClassId(player, originalClass)
	env.restore(player)
	local passCount, totalCount = r.summary()
	print(("===P3b 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

return P3bVerify
