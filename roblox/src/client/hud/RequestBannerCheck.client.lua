-- S20(UI) 자체 점검 [S20][UI] - 요청 배너 화면 안전 영역 · 파티 복귀 문구(사전 작업 1 · 2). Studio에서 DevToolsConfig.verify에 "S20(UI)"가 있을 때만(또는 회귀 전체) 돈다.
--   ① 배너 자리 순수 함수(`RequestBanner.placementFor`)를 모바일 기준 해상도 4개(800 × 360 · 667 × 375 · 842 × 388 · 1024 × 768 - 상단 인셋 58을 뺀 ScreenGui 높이)로 불러
--      위 끝 >= 8 · 아래 끝 <= 높이 - 8(화면 밖 0) · 모바일 버튼 44 이상 · 본문 줄 수를 잰다. 폰(모바일 기하) · PC 기하 둘 다.
--   ② 복귀 문구: `PartyAway.reconnectBody` 문구 · 배너에 실제로 밀어 넣어 남은 시간이 0.1초 단위로 줄어드는지(글 · 게이지).
--   ③ 지금 화면에서 실제 배너가 ScreenGui 안에 그려지는지.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S20(UI)")) then
	return
end

local PartyAway = require(script.Parent.PartyAway)
local RequestBanner = require(script.Parent.RequestBanner)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local Loot = require(ReplicatedStorage.Shared.Loot)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)

local player = Players.LocalPlayer
local START_DELAY = 66 -- 다른 클라 점검이 토스트 · 요청 배너를 쓰는 동안이 끝난 뒤
local INSET = 58 -- GetGuiInset 상단(1321 × 542 Play 실측). 해상도별 ScreenGui 높이 = 뷰포트 높이 - INSET.
local SAFE = 8

local RESOLUTIONS = { { 800, 360 }, { 667, 375 }, { 842, 388 }, { 1024, 768 } }

local function run()
	local results, passed = {}, 0
	local function check(label, ok)
		table.insert(results, ok)
		print(("[S20][UI] %s %s"):format(label, ok and "O" or "X"))
		if ok then
			passed += 1
		end
	end
	print("===S20(UI) 검증 시작(요청 배너 안전 영역 · 복귀 문구)===")

	-- ① 자리 순수 함수 - 4 해상도 × (모바일 · PC 기하) × (게이지 있음 · 버튼 있음 = 가장 큰 배너)
	for _, mobile in ipairs({ true, false }) do
		local rows, allInside, buttonsOk, linesText = {}, true, true, {}
		for _, size in ipairs(RESOLUTIONS) do
			local screenHeight = size[2] - INSET
			local lines, top, height = RequestBanner.placementFor(screenHeight, mobile, true, true)
			local inside = top >= SAFE - 1e-6 and top + height <= screenHeight - SAFE + 1e-6
			allInside = allInside and inside
			table.insert(rows, ("%d × %d(ScreenGui 높이 %d) → 위 %.0f · 아래 %.0f · 본문 %d줄 %s"):format(size[1], size[2], screenHeight, top, top + height, lines, inside and "안" or "밖"))
			table.insert(linesText, lines)
		end
		buttonsOk = Theme.buttonHeightFor(mobile) >= (mobile and 44 or 0)
		check(("%s 기하 배너 화면 안(위 여백 %d · 아래 여백 %d): %s · 수락 · 거절 버튼 높이 %d(모바일 기대 44 이상)"):format(mobile and "모바일" or "PC", SAFE, SAFE, table.concat(rows, " / "), Theme.buttonHeightFor(mobile)), allInside and buttonsOk)
	end
	-- 버튼 폭: (배너 폭 224 - 좌우 여백 20 - 버튼 사이 8) ÷ 2
	local buttonWidth = (RequestBanner.width - 20 - 8) / 2
	check(("수락 · 거절 버튼 폭 %.0f(터치 44 이상)"):format(buttonWidth), buttonWidth >= 44)

	-- ② 복귀 문구 · 카운트다운
	local body = PartyAway.reconnectBody("홍길동", 161)
	check(("복귀 문구: '%s'(기대 '홍길동님의 파티로 돌아가기 (남은 시간 2:41)')"):format(body), body == "홍길동님의 파티로 돌아가기 (남은 시간 2:41)")
	RequestBanner.clear()
	RequestBanner.push({
		key = "reconnectCheck",
		title = "파티로 돌아가기",
		bodyFn = function(remaining)
			return PartyAway.reconnectBody("홍길동", remaining)
		end,
		seconds = 3,
		accept = { text = "돌아가기" },
		decline = { text = "나중에" },
	})
	local first = RequestBanner.debugState()
	task.wait(1.3)
	local second = RequestBanner.debugState()
	check(("복귀 배너 카운트다운: 처음 '%s' → 1.3초 뒤 '%s'(기대 0:03 → 0:02 · 게이지 %.2f → %.2f 줄어듦) · 제목 '%s' · 버튼 %s"):format(
		first.body, second.body, first.gaugeValue, second.gaugeValue, second.title, tostring(second.buttonsShown)),
		first.body:find("남은 시간 0:03", 1, true) ~= nil and second.body:find("남은 시간 0:02", 1, true) ~= nil and second.gaugeValue < first.gaugeValue and second.title == "파티로 돌아가기" and second.buttonsShown)

	-- ③ 실제 배너가 지금 ScreenGui 안에 그려진다
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("RequestBannerGui")
	local frame = second.frame
	if gui and frame then
		local position, size, screen = frame.AbsolutePosition, frame.AbsoluteSize, gui.AbsoluteSize
		local inside = position.Y >= SAFE - 0.5 and position.Y + size.Y <= screen.Y - SAFE + 0.5 and position.X >= 0 and position.X + size.X <= screen.X
		check(("실제 배너(지금 화면 %d × %d): 위치 (%d, %d) 크기 %d × %d → 안전 영역 안 %s"):format(screen.X, screen.Y, position.X, position.Y, size.X, size.Y, tostring(inside)), inside)
	else
		check("실제 배너 프레임을 못 찾음", false)
	end
	RequestBanner.clear()

	-- ④ ItemDescribe 대조표(S20 §6-3): 가방 상세가 자기 코드로 만들던 문구(아래 OLD_* = 지운 코드 그대로의 사본)와 ItemDescribe가 만드는 문구가 같은가.
	--    같지 않아야 정상인 것은 "가방 상세 메타(장갑 · 신발)" 둘뿐이다 - 옛 코드가 모든 부위에 갑옷 방어력 식을 썼다(착용 중 상세 · 툴팁은 부위별 스탯이었다). 그 밖에 다르면 X.
	local OLD_PART_META = {
		armor = function(item) return ("%s · Lv.%d · 방어력 %s"):format(ItemVisualData.partDisplayNames.armor, item.itemLevel, NumberFormat.format(Loot.getArmorDefense(item))) end,
		gloves = function(item) return ("%s · Lv.%d · 공격력 +%.0f%%"):format(ItemVisualData.partDisplayNames.gloves, item.itemLevel, Loot.getGlovesAttackPercent(item) * 100) end,
		shoes = function(item) return ("%s · Lv.%d · 이동+공속 +%.0f%%"):format(ItemVisualData.partDisplayNames.shoes, item.itemLevel, Loot.getShoesSpeedPercent(item) * 100) end,
	}
	local function oldName(item)
		local grade = ArmorData.grades[item.grade]
		return (grade and grade.displayName or item.grade) .. " " .. (ItemVisualData.partDisplayNames[item.part or "armor"] or "장비")
	end
	local function oldOptionName(optionId)
		local def = OptionData.options[optionId]
		local name = def and def.displayName
		if not name and def and def.classId then
			local skillDef = SkillData[def.classId] and SkillData[def.classId][def.slot]
			name = skillDef and skillDef.name
		end
		return name or optionId
	end
	local function oldGemName(gem)
		local gradeInfo = ArmorData.grades[gem.grade]
		local gradeName = gradeInfo and gradeInfo.displayName or gem.grade
		if not gem.option then
			return ("%s 보석(옵션 미배정)"):format(gradeName)
		end
		return ("%s %s 보석 · Lv.%d"):format(gradeName, oldOptionName(gem.option.id), gem.itemLevel or 0)
	end
	local classId = "bow"
	local samples = {
		{ grade = "ancient", part = "armor", itemLevel = 50, option = { id = "crit", roll = 1.0, roll2 = 1.05 } },
		{ grade = "relic", part = "gloves", itemLevel = 40, option = { id = "skill_bow_Q", roll = 1.0 } },
		{ grade = "legendary", part = "shoes", itemLevel = 35, option = { id = "skill_healer_Q", roll = 1.0 } },
		{ grade = "epic", part = "armor", itemLevel = 20 },
	}
	local diffs, expectedDiffs, rows = {}, 0, {}
	for _, item in ipairs(samples) do
		local described = ItemDescribe.item(item, classId)
		local sameTitle = described.title == oldName(item)
		local sameEquipMeta = described.meta == OLD_PART_META[item.part](item)
		local oldBagMeta = ("%s · Lv.%d · 방어력 %s"):format(ItemVisualData.partDisplayNames[item.part] or "장비", item.itemLevel, NumberFormat.format(Loot.getArmorDefense(item)))
		local sameBagMeta = described.meta == oldBagMeta
		if not sameBagMeta and item.part ~= "armor" then
			expectedDiffs += 1 -- 의도한 차이(위 설명)
		elseif not sameBagMeta then
			table.insert(diffs, item.part .. " 가방 메타")
		end
		if not sameTitle then
			table.insert(diffs, item.part .. " 이름")
		end
		if not sameEquipMeta then
			table.insert(diffs, item.part .. " 착용 중 메타")
		end
		table.insert(rows, ("%s: 이름 %s · 착용 중 메타 %s · 가방 메타 %s"):format(item.part, sameTitle and "같음" or "다름", sameEquipMeta and "같음" or "다름", sameBagMeta and "같음" or (item.part == "armor" and "다름(X)" or "다름(의도)")))
	end
	-- 무기
	local weapon = ItemDescribe.weapon("legendary", 13)
	local weaponOld = (ArmorData.grades.legendary.displayName or "") .. " " .. WeaponData.weapons[WeaponData.starterId].displayName
	local weaponMetaOld = ("무기 · +%d · 강화대에서 강화"):format(13)
	if weapon.title ~= weaponOld then table.insert(diffs, "무기 이름") end
	if weapon.meta .. " · 강화대에서 강화" ~= weaponMetaOld then table.insert(diffs, "무기 메타") end
	-- 보석
	local gemWith = { grade = "ancient", itemLevel = 30, option = { id = "skill_bow_Q", roll = 1.0 } }
	local gemNone = { grade = "primordial", itemLevel = 30 }
	if ItemDescribe.gem(gemWith, classId).title ~= oldGemName(gemWith) then table.insert(diffs, "보석 이름(옵션 있음)") end
	if ItemDescribe.gem(gemNone, classId).title ~= oldGemName(gemNone) then table.insert(diffs, "보석 이름(옵션 미배정)") end
	-- 옵션 태그 이름(가방 셀 · 착용 칸) + 직업색 규칙
	local tagRows = {}
	for _, item in ipairs(samples) do
		local tag = ItemDescribe.optionTag(item, classId)
		if item.option then
			if not tag or tag.text ~= oldOptionName(item.option.id) then
				table.insert(diffs, item.part .. " 옵션 태그 이름")
			end
			table.insert(tagRows, ("%s → %s%s"):format(item.option.id, tag and tag.text or "?", tag and (tag.mismatched and "(불일치 · 회색)" or (tag.accentClassId and ("(직업색 " .. tag.accentClassId .. ")") or "(공통)")) or ""))
		elseif tag ~= nil then
			table.insert(diffs, item.part .. " 옵션 없는데 태그")
		end
	end
	local bowTag, healerTag, critTag = ItemDescribe.optionTag(samples[2], classId), ItemDescribe.optionTag(samples[3], classId), ItemDescribe.optionTag(samples[1], classId)
	local colorRule = bowTag.accentClassId == "bow" and UIColors.classAccent[bowTag.accentClassId] ~= nil and healerTag.mismatched and healerTag.accentClassId == nil and critTag.accentClassId == nil and not critTag.mismatched
	-- 옵션 줄(가방 상세 옵션 게이지가 받는 text · dim · accent): 일치 · 불일치 · 치명
	local lineBow = ItemDescribe.optionLines(samples[2], classId)[1]
	local lineHealer = ItemDescribe.optionLines(samples[3], classId)[1]
	local lineCrit = ItemDescribe.optionLines(samples[1], classId)
	local lineRule = lineBow.accentClassId == "bow" and not lineBow.dim and lineHealer.dim and lineHealer.accentClassId == nil and lineHealer.text:find("(직업 불일치 · 효과 없음)", 1, true) ~= nil
		and #lineCrit == 2 and lineCrit[1].text:find("^치확 ") ~= nil and lineCrit[2].text:find("^치피 ") ~= nil
	check(("ItemDescribe 대조표: %s · 무기 · 보석 · 옵션 태그 이름 이전과 다른 것 %s(기대 없음) · 의도한 차이(가방 메타 장갑 · 신발) %d건(기대 2)"):format(
		table.concat(rows, " / "), #diffs == 0 and "없음" or table.concat(diffs, ", "), expectedDiffs), #diffs == 0 and expectedDiffs == 2)
	check(("가방 셀 옵션 태그 색 규칙: %s · 직업 특화 일치 = 직업색 · 불일치 = 회색 우선 · 공통 = 기존색 %s · 옵션 줄(상세 게이지) 일치/불일치/치명 %s"):format(
		table.concat(tagRows, " · "), tostring(colorRule), tostring(lineRule)), colorRule == true and lineRule == true)

	print(("===S20(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
end

task.delay(START_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S20][UI] 점검 에러: " .. tostring(err))
		RequestBanner.clear()
	end
end)
