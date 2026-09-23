-- S08 자동 검증(PRD 20.72 [1-9] · 30-0 S08) - 강화 이펙트 표 · 사거리 · 20강+ 성공 공지.
--   (가) 순수 함수 - 서버 시작 때(플레이어 없이): 표 검사(임계 10개 · 색 키 · 누적 규칙 · 단계 복귀) · 사거리(활 15 → 19.5 → 24.0 · 상한 24.6 · 백스텝샷과 겹침).
--   (나) 실제 Player - 보스 검증 체인의 끝에서: 무기 단계를 5 · 10 · 15 · 19 · 20 · 22 · 25로 바꿔 가며 서버가 쓰는 사거리 값 · 실제 EnhanceService.handleRequest 경로의 공지 발신 횟수.
-- env = { ensureBackup, restore } - DevTools의 로컬 헬퍼. 검증이 바꾼 것(직업 · 무기 단계 · 게이지 · 골드 · 재료 · 위치 · EnhanceService의 RemoteEvent 연결)은 (나)가 끝날 때 전부 되돌린다.
-- 이펙트 인스턴스 자체(빛 · 파티클 · 외곽선)와 스크린샷은 클라 몫이라 별도 Play에서 클라 execute_luau · 화면 캡처로 확인한다(PRD 20.NN).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local EnhanceVisualData = require(ReplicatedStorage.Shared.data.EnhanceVisualData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local EnhanceEffect = require(ReplicatedStorage.Shared.EnhanceEffect)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local EnhanceService = require(script.Parent.EnhanceService)
local PlayerProfile = require(script.Parent.PlayerProfile)

local EnhanceEffectVerify = {}

local EPSILON = 1e-9

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S08][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function near(a, b)
	return math.abs(a - b) < EPSILON
end

-- 표 안의 색 키 전부(steps의 light · particle(color · colorTo) · highlight · tint · trailColor).
local function collectColorKeys()
	local keys = {}
	local function add(key)
		if key then
			table.insert(keys, key)
		end
	end
	for _, step in ipairs(EnhanceVisualData.steps) do
		add(step.light and step.light.color)
		add(step.particle and step.particle.color)
		add(step.particle and step.particle.colorTo)
		add(step.highlight and step.highlight.color)
		add(step.tint and step.tint.color)
		add(step.trailColor)
	end
	return keys
end

local function lightText(state)
	local light = state.light
	if not light then
		return "빛 없음"
	end
	return ("빛 %s %s/%s%s"):format(tostring(light.color), tostring(light.brightness), tostring(light.range), light.pulse and " 맥동" or "")
end

-- 직업별 기대 사거리(PRD 20.72 [1-9]: 활 +30% · 대검 · 쌍검 +10% · 힐러 +20%가 +15와 +20에서 한 번씩) - 기본 사거리 = 10 × 직업 배율(대검 13 · 쌍검 10 · 활 15 · 힐러 15).
local EXPECTED_RANGE = {
	bow = { [5] = 15, [10] = 15, [15] = 19.5, [19] = 19.5, [20] = 24.0, [22] = 24.0, [25] = 24.0 },
	greatsword = { [5] = 13, [10] = 13, [15] = 14.3, [19] = 14.3, [20] = 15.6, [22] = 15.6, [25] = 15.6 },
	dualblade = { [5] = 10, [10] = 10, [15] = 11, [19] = 11, [20] = 12, [22] = 12, [25] = 12 },
	healer = { [5] = 15, [10] = 15, [15] = 18, [19] = 18, [20] = 21, [22] = 21, [25] = 21 },
}
local SAMPLE_LEVELS = { 5, 10, 15, 19, 20, 22, 25 }

function EnhanceEffectVerify.runPure()
	print("===S08 검증 시작(가: 이펙트 표 · 사거리)===")
	local r = newRecorder("가")

	r.section("[1] 표 형태", function()
		local levels = {}
		for _, step in ipairs(EnhanceVisualData.steps) do
			table.insert(levels, step.level)
		end
		local expected = { 5, 10, 15, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 } -- P2.5a: +26 ~ +30 칭호 줄
		local same = #levels == #expected
		for index, level in ipairs(expected) do
			same = same and levels[index] == level
		end
		r.check(("임계 %d개: %s(기대 5 · 10 · 15 · 19 · 20 · 21 · 22 · 23 · 24 · 25 ~ 30 - 오름차순 · 15개)"):format(#levels, table.concat(levels, " · ")), same)
	end)

	r.section("[2] 색 키", function()
		local keys = collectColorKeys()
		local missing = {}
		for _, key in ipairs(keys) do
			if typeof(UIColors[key]) ~= "Color3" then
				table.insert(missing, key)
			end
		end
		r.check(("표의 색 키 %d개 전부 UIColors의 Color3(없는 키 %d개%s)"):format(#keys, #missing, #missing > 0 and (": " .. table.concat(missing, " · ")) or ""), #keys > 0 and #missing == 0)
	end)

	r.section("[3] 누적 규칙", function()
		local s4, s5, s9, s10, s15, s18 = EnhanceEffect.resolveVisual(4), EnhanceEffect.resolveVisual(5), EnhanceEffect.resolveVisual(9), EnhanceEffect.resolveVisual(10),
			EnhanceEffect.resolveVisual(15), EnhanceEffect.resolveVisual(18)
		r.check(("0 ~ 4강은 빈 모습 · +5 = %s · +9는 +5와 같음"):format(lightText(s5)),
			next(s4) == nil and s5.light.color == "textPrimary" and s5.light.brightness == 0.6 and s5.light.range == 6 and not s5.particle and not s5.highlight
				and s9.light.color == s5.light.color and s9.light.range == 6 and s9.trailWidthScale == nil)
		r.check(("+10 = %s · Trail 폭 ×%s(기대 textPrimary 0.6/8 · ×1.25)"):format(lightText(s10), tostring(s10.trailWidthScale)),
			s10.light.color == "textPrimary" and s10.light.brightness == 0.6 and s10.light.range == 8 and s10.trailWidthScale == 1.25)
		r.check(("+15 = %s · 몸체 색 gold %s%%(기대 gold 0.6/8 · 25%%) · +18은 +15와 같음"):format(lightText(s15), s15.tint and tostring(s15.tint.alpha * 100) or "없음"),
			s15.light.color == "gold" and s15.light.range == 8 and s15.tint and s15.tint.color == "gold" and s15.tint.alpha == 0.25
				and s18.light.color == "gold" and s18.tint.alpha == 0.25 and not s18.particle)
		local s19, s20, s21, s22, s23, s24, s25 = EnhanceEffect.resolveVisual(19), EnhanceEffect.resolveVisual(20), EnhanceEffect.resolveVisual(21), EnhanceEffect.resolveVisual(22),
			EnhanceEffect.resolveVisual(23), EnhanceEffect.resolveVisual(24), EnhanceEffect.resolveVisual(25)
		r.check(("+19 = 파티클 %s rate %s(기대 gold 6)"):format(tostring(s19.particle and s19.particle.color), tostring(s19.particle and s19.particle.rate)),
			s19.particle and s19.particle.color == "gold" and s19.particle.rate == 6 and s19.light.color == "gold")
		r.check(("+20 = %s · 맥동 %s ~ %s / %s초(기대 ember · 0.8 ~ 1.4 / 1.5초) · 파티클은 그대로 gold 6"):format(lightText(s20), tostring(s20.light.pulse and s20.light.pulse.min),
			tostring(s20.light.pulse and s20.light.pulse.max), tostring(s20.light.pulse and s20.light.pulse.periodSeconds)),
			s20.light.color == "ember" and s20.light.pulse and s20.light.pulse.min == 0.8 and s20.light.pulse.max == 1.4 and s20.light.pulse.periodSeconds == 1.5
				and s20.particle.rate == 6 and s20.particle.color == "gold")
		r.check(("+21 = 파티클 %s rate %s(기대 ember 12)"):format(tostring(s21.particle.color), tostring(s21.particle.rate)),
			s21.particle.color == "ember" and s21.particle.rate == 12 and s21.particle.colorTo == nil)
		r.check(("+22 = 외곽선 %s · 채움 투명 %s(기대 ember · 1)"):format(tostring(s22.highlight and s22.highlight.color), tostring(s22.highlight and s22.highlight.fillTransparency)),
			s22.highlight and s22.highlight.color == "ember" and s22.highlight.fillTransparency == 1 and s21.highlight == nil)
		r.check(("+23 = 파티클 %s → %s rate %s(기대 ember → danger 18)"):format(tostring(s23.particle.color), tostring(s23.particle.colorTo), tostring(s23.particle.rate)),
			s23.particle.color == "ember" and s23.particle.colorTo == "danger" and s23.particle.rate == 18)
		r.check(("+24 = %s · Trail 색 %s(기대 danger 범위 12 · 맥동 유지 · Trail danger)"):format(lightText(s24), tostring(s24.trailColor)),
			s24.light.color == "danger" and s24.light.range == 12 and s24.light.pulse ~= nil and s24.trailColor == "danger" and s23.trailColor == nil)
		r.check(("+25 = 무지개 %s · 칭호 %s · 도달 순간 빛기둥 %s초(기대 true · +25 · 3초 - +24 도달은 %s)"):format(tostring(s25.rainbow), tostring(s25.title and s25.title.text),
			tostring(EnhanceEffect.getArrivalPillarSeconds(25)), tostring(EnhanceEffect.getArrivalPillarSeconds(24))),
			s25.rainbow == true and s25.title and s25.title.text == "+25" and EnhanceEffect.getArrivalPillarSeconds(25) == 3 and EnhanceEffect.getArrivalPillarSeconds(24) == nil and s24.rainbow == nil)
	end)

	r.section("[4] 단계 복귀 · 데이터 보호", function()
		local s12, s10 = EnhanceEffect.resolveVisual(12), EnhanceEffect.resolveVisual(10)
		r.check(("25 → 12강: 빛만 남는다 - %s · 파티클 %s · 외곽선 %s · 칭호 %s · 무지개 %s · 몸체 색 %s(기대 +10과 같은 빛, 나머지 없음)"):format(lightText(s12), tostring(s12.particle), tostring(s12.highlight),
			tostring(s12.title), tostring(s12.rainbow), tostring(s12.tint)),
			s12.light.color == s10.light.color and s12.light.range == s10.light.range and s12.particle == nil and s12.highlight == nil and s12.title == nil and s12.rainbow == nil and s12.tint == nil
				and s12.light.pulse == nil)
		local mutated = EnhanceEffect.resolveVisual(25)
		mutated.light.color = "tampered"
		mutated.title.text = "tampered"
		r.check("돌려준 표를 고쳐도 데이터 표는 그대로(다음 호출 +25 빛 색 · 칭호 = danger · +25)",
			EnhanceEffect.resolveVisual(25).light.color == "danger" and EnhanceEffect.resolveVisual(25).title.text == "+25")
	end)

	r.section("[5] 사거리", function()
		local safeMax = WorldConfig.aggro.rangeStuds - CombatConfig.rangeBuffAggroMarginStuds
		r.check(("상한 = 어그로 범위 %s - 여유 %s = %s(기대 24.6)"):format(tostring(WorldConfig.aggro.rangeStuds), tostring(CombatConfig.rangeBuffAggroMarginStuds), tostring(safeMax)), near(safeMax, 24.6))
		local bow = function(level)
			return PlayerCombat.getAttackRange("bow", level)
		end
		r.check(("궁수: +14 = %.2f · +15 = %.2f · +19 = %.2f · +20 = %.2f · +25 = %.2f · 단계 없음 = %.2f(기대 15 · 19.5 · 19.5 · 24.0 · 24.0 · 15)"):format(bow(14), bow(15), bow(19), bow(20), bow(25), PlayerCombat.getAttackRange("bow")),
			near(bow(14), 15) and near(bow(15), 19.5) and near(bow(19), 19.5) and near(bow(20), 24.0) and near(bow(25), 24.0) and near(PlayerCombat.getAttackRange("bow"), 15))

		local rangeSummary = {}
		local allMatch, allInside, allMonotonic, buffInside = true, true, true, true
		for classId, expectedByLevel in pairs(EXPECTED_RANGE) do
			local previous = 0
			for level = 0, EnhanceConfig.maxLevel do
				local range = PlayerCombat.getAttackRange(classId, level)
				allInside = allInside and range <= safeMax + EPSILON
				allMonotonic = allMonotonic and range >= previous - EPSILON
				previous = range
				if expectedByLevel[level] then
					allMatch = allMatch and near(range, expectedByLevel[level])
				end
				-- 백스텝샷(사거리 2배 · SkillData)과 겹쳐도, 배율이 1이어도 같은 상한에서 잘린다.
				buffInside = buffInside and PlayerCombat.getBuffedAttackRange(classId, 2, level) <= safeMax + EPSILON and near(PlayerCombat.getBuffedAttackRange(classId, 1, level), range)
			end
			table.insert(rangeSummary, ("%s %.1f→%.1f"):format(classId, PlayerCombat.getAttackRange(classId, 0), PlayerCombat.getAttackRange(classId, 25)))
		end
		table.sort(rangeSummary)
		r.check(("4직업 × +0 ~ +25: 표 값과 일치=%s · 전부 상한 24.6 이하=%s · 단계가 오르면 줄지 않음=%s (%s)"):format(tostring(allMatch), tostring(allInside), tostring(allMonotonic), table.concat(rangeSummary, " · ")),
			allMatch and allInside and allMonotonic)
		r.check(("백스텝샷(×2) × 4직업 × +0 ~ +25: 전부 24.6 이하=%s · 배율 1 = 버프 없음과 같음 · 궁수 +20 ×2 = %.2f(기대 24.6)"):format(tostring(buffInside), PlayerCombat.getBuffedAttackRange("bow", 2, 20)),
			buffInside and near(PlayerCombat.getBuffedAttackRange("bow", 2, 20), 24.6) and near(PlayerCombat.getBuffedAttackRange("bow", 2, 0), 24.6))
		local legacyOk = true
		for _, classId in ipairs(ClassData.order) do
			legacyOk = legacyOk and near(PlayerCombat.getAttackRange(classId), CombatConfig.attackRangeStuds * ClassData.classes[classId].rangeMultiplier)
		end
		r.check("단계를 안 넘기는 기존 호출(BalanceSim)은 기본 사거리 그대로(10 × 직업 배율)", legacyOk)
	end)

	r.check(("공지 임계 announceFromLevel = %s(기대 20)"):format(tostring(EnhanceConfig.announceFromLevel)), EnhanceConfig.announceFromLevel == 20)

	local pass, total = r.summary()
	print(("===S08 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function EnhanceEffectVerify.runLive(player, env)
	print("===S08 검증 시작(나: 실제 Player · 실제 EnhanceService 경로)===")
	local r = newRecorder("나")
	local root = rootOf(player)
	if not PlayerProfile.getProfile(player) or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S08 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player) -- classes(직업 · 무기 단계 · 게이지) · gold · 재료는 env.restore가 되돌린다
	local savedCFrame = root.CFrame
	local savedClassId = PlayerProfile.getClassId(player)
	local realResult = ReplicatedStorage:FindFirstChild("EnhanceResult")
	local realAnnounce = ReplicatedStorage:FindFirstChild("EnhanceAnnounce")

	r.section("[1] 서버가 쓰는 사거리", function()
		-- AttackServer가 부르는 것과 같은 식: getBuffedAttackRange(classId, 배율, 프로필의 무기 단계). 단계는 실제 프로필(PlayerProfile.setWeaponLevel) · Attribute(클라 조준 AimTarget이 읽는다)로 바꾼다.
		local mismatches, attributeMismatches, lines = 0, 0, {}
		for _, classId in ipairs(ClassData.order) do
			PlayerProfile.setClassId(player, classId)
			local values = {}
			for _, level in ipairs(SAMPLE_LEVELS) do
				PlayerProfile.setWeaponLevel(player, level)
				local weapon = PlayerProfile.getWeapon(player)
				local range = PlayerCombat.getBuffedAttackRange(classId, 1, weapon.level)
				table.insert(values, ("+%d=%.1f"):format(level, range))
				if not near(range, EXPECTED_RANGE[classId][level]) then
					mismatches += 1
				end
				if player:GetAttribute("WeaponLevel") ~= level then
					attributeMismatches += 1
				end
			end
			table.insert(lines, ("%s %s"):format(classId, table.concat(values, " ")))
		end
		r.check(("서버가 보는 사거리(직업 4 × 단계 7): 어긋난 칸 %d · WeaponLevel Attribute가 프로필과 다른 칸 %d(기대 0 · 0) - %s"):format(mismatches, attributeMismatches, table.concat(lines, " / ")),
			mismatches == 0 and attributeMismatches == 0)
	end)

	r.section("[2] 20강+ 성공 공지", function()
		local announced = {}
		local fakeAnnounce = {
			FireAllClients = function(_, displayName, level)
				table.insert(announced, { name = displayName, level = level })
			end,
		}
		local fakeResult = { FireClient = function() end }
		EnhanceService.init(fakeResult, fakeAnnounce)

		root.Anchored = true -- 옮긴 자리의 지형이 아직 스트리밍되지 않았을 때 추락하는 일을 막는다(S03 (나)와 같다)
		root.CFrame = CFrame.new(WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset + Vector3.new(0, 3, 0))
		PlayerProfile.addGold(player, 4000000000 * GoldCost.scale(PlayerProfile.getAccountBestStage(player), "enhance")) -- P2 C1: 계정 최고 > 100이면 비용이 커진다 · 아래 시도가 쓰는 골드 · 재료를 넉넉히 준다(env.restore가 되돌린다)
		for _, materialId in ipairs(EnhanceMaterialData.order) do
			PlayerProfile.addMaterial(player, materialId, 1000)
		end
		PlayerProfile.setClassId(player, ClassData.order[1])

		-- 불씨가 가득이면 다음 시도는 성공 100%다(천장) - 성공을 강제한다. 결과 단계 = 시도 단계 + 1.
		local function forcedSuccess(fromLevel)
			task.wait(EnhanceService.requestCooldownSeconds + 0.1)
			PlayerProfile.setWeaponLevel(player, fromLevel)
			PlayerProfile.setEnhanceGauge(player, EnhanceConfig.gauge.max)
			local before = #announced
			local payload = EnhanceService.handleRequest(player)
			return payload, #announced - before
		end
		local p19, n19 = forcedSuccess(18) -- 18 → 19
		local p20, n20 = forcedSuccess(19) -- 19 → 20
		local p25, n25 = forcedSuccess(24) -- 24 → 25
		r.check(("성공 18→19: 결과 %s · 공지 %d회(기대 success · 0) / 19→20: %s · %d회(기대 success · 1) / 24→25: %s · %d회(기대 success · 1)"):format(
			p19 and p19.result or "응답 없음", n19, p20 and p20.result or "응답 없음", n20, p25 and p25.result or "응답 없음", n25),
			p19 ~= nil and p19.result == "success" and p19.level == 19 and n19 == 0 and p20 ~= nil and p20.result == "success" and p20.level == 20 and n20 == 1
				and p25 ~= nil and p25.result == "success" and p25.level == 25 and n25 == 1)
		local first, second = announced[1], announced[2]
		r.check(("공지 내용: %s / %s(기대 %s · 20 / %s · 25 - 표시 이름 · 새 단계)"):format(first and ("%s · %d"):format(tostring(first.name), first.level) or "없음",
			second and ("%s · %d"):format(tostring(second.name), second.level) or "없음", player.DisplayName, player.DisplayName),
			first ~= nil and first.name == player.DisplayName and first.level == 20 and second ~= nil and second.name == player.DisplayName and second.level == 25)

		-- 실패 · 유지에는 공지가 없다: +21에서 불씨 0으로 12번 시도(성공률 18% - 한 번도 안 실패할 확률 약 1e-9) - 공지 횟수 = 성공 횟수여야 한다.
		announced = {}
		local successes, failures, attempts = 0, 0, 0
		for _ = 1, 12 do
			task.wait(EnhanceService.requestCooldownSeconds + 0.1)
			PlayerProfile.setWeaponLevel(player, 21)
			PlayerProfile.setEnhanceGauge(player, 0)
			local payload = EnhanceService.handleRequest(player)
			if payload then
				attempts += 1
				if payload.result == "success" then
					successes += 1
				else
					failures += 1
				end
			end
		end
		r.check(("+21 시도 %d회(불씨 0): 성공 %d · 실패 %d · 공지 %d회(기대 공지 = 성공 · 실패가 1회 이상)"):format(attempts, successes, failures, #announced),
			attempts == 12 and failures >= 1 and #announced == successes)
	end)

	-- 되돌리기: EnhanceService의 RemoteEvent 연결 · 직업 · 골드 · 재료 · 단계 · 위치. 검증이 만든 것은 없어야 한다.
	EnhanceService.init(realResult, realAnnounce)
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.Anchored = false
		currentRoot.CFrame = savedCFrame
	end
	r.check(("검증 뒤 되돌림: 직업 %s → %s · EnhanceResult · EnhanceAnnounce 연결 복구(RemoteEvent 존재 %s · %s)"):format(tostring(savedClassId), tostring(PlayerProfile.getClassId(player)),
		tostring(realResult ~= nil), tostring(realAnnounce ~= nil)), PlayerProfile.getClassId(player) == savedClassId and realResult ~= nil and realAnnounce ~= nil)

	local pass, total = r.summary()
	print(("===S08 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return EnhanceEffectVerify
