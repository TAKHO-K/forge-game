-- 보스 첫 클리어 보상 띠(30-0 S11, PRD 20.73 [4-2]) - 스테이지 선택 패널(StageSelectPanel)이 그리드와 페이지 버튼 사이에 끼우는 고정 크기 부품.
-- 보스 칸을 누르면(선택) 그 보스의 이름 · 첫 클리어 보상(직업 / 계정 구분) · 매번 받는 것 · 도감이 보이고, [도전]을 눌러야 이동 요청이 나간다(파티 전원 텔레포트를 일으키는 클릭이라 확인 단계).
-- **문자열은 데이터에서 만든다**(숫자를 여기 적지 않는다): 20마리분 = BossData의 hpMultiplier · Lv 범위 = 스테이지 + ArmorData.bossItemLevelDelta의 최소 ~ 최대 · 강화석 ≈ dropChancePerKill × hpMultiplier
-- (minStage 미만이면 그 항목이 없다) · "영웅 이상" = 확정 장비 등급표에서 확률 > 0인 가장 낮은 등급(환생 0회 = 상향표, 1회 이상 = 기본표 - Loot.rollBossFirstClearDrop과 같은 분기) · 방지권 = Enhance.getBossGrant.
-- 받을 것 / 받은 것 / 스테이지 없음("none")은 서버 응답(BossRewardPreview)이 정한다 - 클라는 판정하지 않는다. 받은 줄은 지우지 않고 textTertiary + "✓ 받음"으로 남긴다.
-- 고정 크기만(AutomaticSize 없음). 글씨 12 미만 금지(Theme.textSize). 최상위 local 120개 이하.
--
-- 순수 함수(StageRewardBand.describe · gradeRows)는 클라 모듈 안에 둔다(shared/에 두지 않는다 - 지시). 서버 (가)는 같은 값의 "데이터 식"만 검증하고, 이 파일의 문자열은 selfTest([S11][UI])가 본다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local Button = require(script.Parent.ui.kit.Button)
local HelpToggle = require(script.Parent.ui.kit.HelpToggle)
local Theme = require(script.Parent.ui.kit.Theme)

local StageRewardBand = {}

local MAX_ROWS = 4 -- 첫 클리어(장비) · 방지권 · 매번(골드 · 경험치 · 장비) · 매번(강화석)
local CODEX_DOT = 22 -- 도감 점 한 칸의 폭(PC)

-- BossRules.isBossStage와 같은 식이다(BossRules는 무거운 shared 모듈을 여럿 끌어와 클라 패널이 안 부른다).
function StageRewardBand.isBossStage(stage)
	return stage >= BossData.stageInterval and stage % BossData.stageInterval == 0
end

-- 확정 장비 등급표: 환생 0회 = 상향표, 1회 이상 = 기본표(Loot.rollBossFirstClearDrop과 같은 분기).
local function firstClearGradeTable(rebirthCount)
	if rebirthCount and rebirthCount > 0 then
		return MonsterData.bossFirstClearGradeTable
	end
	return MonsterData.bossFirstClearUpgradedGradeTable
end

local function percentText(chance)
	return ("%g%%"):format(math.floor(chance * 1000 + 0.5) / 10)
end

-- 확률 > 0인 등급을 낮은 등급부터: { { id, name, chance }... }.
function StageRewardBand.gradeRows(rebirthCount)
	local gradeTable = firstClearGradeTable(rebirthCount)
	local rows = {}
	for _, gradeId in ipairs(ArmorData.gradeOrder) do
		local chance = gradeTable[gradeId]
		if chance and chance > 0 then
			table.insert(rows, { id = gradeId, name = ArmorData.grades[gradeId].displayName, chance = chance })
		end
	end
	return rows
end

function StageRewardBand.gradeHelpText(rebirthCount)
	local lines = {}
	for _, row in ipairs(StageRewardBand.gradeRows(rebirthCount)) do
		table.insert(lines, ("%s %s"):format(row.name, percentText(row.chance)))
	end
	return table.concat(lines, "\n"), #lines
end

local function itemLevelDeltaRange()
	local low, high = math.huge, -math.huge
	for _, entry in ipairs(ArmorData.bossItemLevelDelta) do
		low, high = math.min(low, entry.delta), math.max(high, entry.delta)
	end
	return low, high
end

-- 받을 것이 하나라도 남았는가(★). entry = 서버 응답의 스테이지 한 칸.
function StageRewardBand.hasRemaining(entry)
	return entry ~= nil and (not entry.gearClaimed or entry.dropTicket == "available" or entry.resetTicket == "available")
end

local function colored(text, colorName)
	return ('<font color="%s">%s</font>'):format(Theme.colorHex(colorName), text)
end

local function plainOf(richText)
	return (richText:gsub("<[^>]+>", ""))
end

-- 순수: 스테이지 하나의 띠 내용. entry = { bossId, gearClaimed, dropTicket, resetTicket }. 반환 { title, rows = { { head, text(RichText), plain, claimed, isGear } }, help(등급 확률 줄바꿈), helpLines }.
function StageRewardBand.describe(stage, entry, rebirthCount)
	local boss = BossData.bosses[entry.bossId]
	local units = boss.hpMultiplier
	local rows = {}

	local grades = StageRewardBand.gradeRows(rebirthCount)
	local low, high = itemLevelDeltaRange()
	local gearBody = ("장비 1개 확정(%s 이상 · Lv %d~%d) [직업]"):format(grades[1].name, stage + low, stage + high)
	if entry.gearClaimed then
		gearBody = colored(gearBody .. " ✓ 받음", "textTertiary")
	else
		gearBody = colored(gearBody, "textPrimary")
	end
	table.insert(rows, { head = "첫 클리어", text = gearBody, claimed = entry.gearClaimed, isGear = true })

	local dropCount, resetCount = Enhance.getBossGrant(stage)
	local ticketParts, claimedCount = {}, 0
	for _, spec in ipairs({
		{ state = entry.dropTicket, text = ("하락 방지권 ×%d"):format(dropCount) },
		{ state = entry.resetTicket, text = ("초기화 방지권 ×%d"):format(resetCount) },
	}) do
		if spec.state ~= "none" then
			table.insert(ticketParts, { text = spec.text, claimed = spec.state == "claimed" })
			if spec.state == "claimed" then
				claimedCount += 1
			end
		end
	end
	if #ticketParts > 0 then
		local allClaimed = claimedCount == #ticketParts
		local segments = {}
		for _, part in ipairs(ticketParts) do
			table.insert(segments, (part.claimed and not allClaimed) and colored(part.text .. " ✓", "textTertiary") or part.text)
		end
		local body = table.concat(segments, " · ") .. " [계정]"
		if allClaimed then
			body = colored(plainOf(body) .. " ✓ 받음", "textTertiary")
		else
			body = colored(body, "textPrimary")
		end
		table.insert(rows, { head = "", text = body, claimed = allClaimed })
	end

	table.insert(rows, { head = "매번", text = colored(("골드·경험치 %d마리분 · 장비 1"):format(units), "textPrimary"), claimed = false })
	local stones = {}
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		local material = EnhanceMaterialData.materials[materialId]
		if stage >= material.minStage then
			table.insert(stones, ("%s ≈%g"):format(material.displayName, material.dropChancePerKill * units))
		end
	end
	if #stones > 0 then
		table.insert(rows, { head = "", text = colored(table.concat(stones, " · "), "textPrimary"), claimed = false })
	end

	for _, row in ipairs(rows) do
		row.plain = plainOf(row.text)
	end
	local help, helpLines = StageRewardBand.gradeHelpText(rebirthCount)
	return { title = ("스테이지 %d 보스 · %s"):format(stage, boss.displayName), rows = rows, help = help, helpLines = helpLines }
end

-- 띠를 짓는다. props = { parent, position, width, onChallenge(stage) }. 반환 refs = { root, height, update(stage, entry, rebirthCount, codex), setChallengeEnabled }.
--   update(stage, entry, ...): stage = nil → 빈 띠("보스 칸을 누르면 보상이 보입니다") · entry = nil → 아직 응답 전("불러오는 중").
function StageRewardBand.build(props)
	local width = props.width
	local titleHeight = Theme.textSize("body") + 4
	local pitch = Theme.textSize("caption") + 2
	local headWidth = Theme.isMobile and 70 or 62
	local rowsTop = titleHeight + 2
	local codexTop = rowsTop + pitch * MAX_ROWS + 4
	local codexHeight = math.max(28, Theme.buttonHeight)
	local height = codexTop + codexHeight

	local root = Instance.new("Frame")
	root.Name = "RewardBand"
	root.Position = props.position
	root.Size = UDim2.new(0, width, 0, height)
	root.BackgroundTransparency = 1
	root.Parent = props.parent

	local title = Theme.label(root, "", "body", "textPrimary")
	title.Name = "Title"
	title.Font = Theme.font
	title.Size = UDim2.new(1, 0, 0, titleHeight)

	local rowViews = {}
	for index = 1, MAX_ROWS do
		local y = rowsTop + pitch * (index - 1)
		local head = Theme.label(root, "", "caption", "textSecondary")
		head.Name = "RowHead" .. index
		head.Position = UDim2.new(0, 0, 0, y)
		head.Size = UDim2.new(0, headWidth, 0, pitch)
		local body = Theme.label(root, "", "caption", "textPrimary")
		body.Name = "RowBody" .. index
		body.RichText = true
		body.Position = UDim2.new(0, headWidth + 4, 0, y)
		body.Size = UDim2.new(1, -(headWidth + 4) - (index == 1 and 26 or 0), 0, pitch) -- 첫 줄은 오른쪽 끝에 도움말 토글 자리
		rowViews[index] = { head = head, body = body }
	end

	-- 등급 확률 도움말(첫 클리어 줄 끝 - 누르면 열리고 다시 누르면 닫힌다. hover 아님).
	local help = HelpToggle.build({ parent = root, text = "", position = UDim2.new(0, width - 10, 0, rowsTop + pitch / 2), panelSide = "left" })
	help.root.Name = "GradeHelp"
	local helpPanel, helpText = help.root:FindFirstChild("HelpPanel"), nil
	for _, descendant in ipairs(help.root:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			helpText = descendant
		end
	end
	help.root.Visible = false

	-- 도감: 점 6개(BossData 선언 순) + 눌린 점의 보스 이름 한 줄 + [도전].
	local codexLabel = Theme.label(root, "도감", "caption", "textSecondary")
	codexLabel.Position = UDim2.new(0, 0, 0, codexTop)
	codexLabel.Size = UDim2.new(0, 34, 0, codexHeight)
	local codexBossIds = BossData.pools[1].bossIds
	local dots = {}
	local nameLabel = Theme.label(root, "", "caption", "textPrimary")
	nameLabel.Name = "CodexName"
	local dotsLeft = 36
	nameLabel.Position = UDim2.new(0, dotsLeft + CODEX_DOT * #codexBossIds + 6, 0, codexTop)
	nameLabel.Size = UDim2.new(0, width - (dotsLeft + CODEX_DOT * #codexBossIds + 6) - 96, 0, codexHeight)
	for index, bossId in ipairs(codexBossIds) do
		local dot = Instance.new("TextButton")
		dot.Name = "CodexDot" .. index
		dot.BackgroundTransparency = 1
		dot.AutoButtonColor = false
		dot.Font = Theme.font
		dot.TextSize = Theme.textSize("body")
		dot.Text = "○"
		dot.Position = UDim2.new(0, dotsLeft + CODEX_DOT * (index - 1), 0, codexTop)
		dot.Size = UDim2.new(0, CODEX_DOT, 0, codexHeight)
		dot.Parent = root
		dot.Activated:Connect(function()
			nameLabel.Text = BossData.bosses[bossId].displayName
		end)
		dots[index] = dot
	end

	local selectedStage = nil
	local challenge = Button.build({
		parent = root,
		name = "ChallengeButton",
		kind = "primary",
		text = "도전",
		width = 88,
		height = codexHeight,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, codexTop),
		onActivated = function()
			if selectedStage and props.onChallenge then
				props.onChallenge(selectedStage)
			end
		end,
	})
	challenge.setEnabled(false)

	local refs = { root = root, height = height }

	local function setCodex(codex)
		for index, bossId in ipairs(codexBossIds) do
			local stamped = codex ~= nil and codex[bossId] == true
			dots[index].Text = stamped and "●" or "○"
			dots[index].TextColor3 = stamped and UIColors.gold or UIColors.textTertiary
		end
	end

	local function clearRows()
		for _, view in ipairs(rowViews) do
			view.head.Text = ""
			view.body.Text = ""
		end
		help.root.Visible = false
	end

	function refs.update(stage, entry, rebirthCount, codex)
		selectedStage = stage
		challenge.setEnabled(stage ~= nil)
		setCodex(codex)
		clearRows()
		if stage == nil then
			title.Text = "보스 칸을 누르면 보상이 보입니다"
			title.TextColor3 = UIColors.textSecondary
			return
		end
		title.TextColor3 = UIColors.textPrimary
		if entry == nil then
			title.Text = ("스테이지 %d 보스"):format(stage)
			rowViews[1].body.Text = "보상을 불러오는 중…"
			return
		end
		local described = StageRewardBand.describe(stage, entry, rebirthCount)
		title.Text = described.title
		for index, row in ipairs(described.rows) do
			rowViews[index].head.Text = row.head
			rowViews[index].body.Text = row.text
		end
		help.root.Visible = true
		if helpText then
			helpText.Text = described.help
		end
		if helpPanel then
			helpPanel.Size = UDim2.new(0, helpPanel.Size.X.Offset, 0, described.helpLines * pitch + 18)
		end
	end
	refs.update(nil, nil, 0, nil)
	return refs
end

-- ── 클라 자체 점검(순수 함수 - 서버 없이): [S11][UI]. Studio에서 DevToolsConfig.verify에 S11(가)가 있을 때 StageSelectPanel이 접속 뒤 돌린다. ──
function StageRewardBand.selfTest(report)
	local dim = Theme.colorHex("textTertiary")
	local function entryOf(gear, drop, reset)
		return { bossId = "frost_giant", gearClaimed = gear, dropTicket = drop, resetTicket = reset }
	end
	local function rowsOf(stage, entry, rebirth)
		return StageRewardBand.describe(stage, entry, rebirth or 0)
	end
	local function joined(described)
		local texts = {}
		for _, row in ipairs(described.rows) do
			table.insert(texts, row.plain)
		end
		return table.concat(texts, " | ")
	end
	local function has(text, needle)
		return string.find(text, needle, 1, true) ~= nil
	end

	local d45, d50, d75, d100 = rowsOf(45, entryOf(false, "none", "none")), rowsOf(50, entryOf(false, "available", "none")), rowsOf(75, entryOf(false, "available", "none")), rowsOf(100, entryOf(false, "available", "available"))
	local t45, t50, t75, t100 = joined(d45), joined(d50), joined(d75), joined(d100)
	report(("방지권 표시 45 / 50 / 75 / 100 = 없음 / 하락 / 하락 / 둘 다: [%s] [%s] [%s] [%s]"):format(t45, t50, t75, t100),
		not has(t45, "방지권") and has(t50, "하락 방지권 ×1") and not has(t50, "초기화") and has(t75, "하락 방지권 ×1") and not has(t75, "초기화")
			and has(t100, "하락 방지권 ×1") and has(t100, "초기화 방지권 ×1"))
	report(("강화석 항목 45 / 50 / 75 / 100 = 없음 / ≈5 / ≈5 + 상급 ≈5 / 같음: 45 %s · 50 %s · 75 %s · 100 %s"):format(
		tostring(has(t45, "강화석")), tostring(has(t50, "강화석 ≈5")), tostring(has(t75, "강화석 ≈5 · 상급 강화석 ≈5")), tostring(has(t100, "강화석 ≈5 · 상급 강화석 ≈5"))),
		not has(t45, "강화석") and has(t50, "강화석 ≈5") and not has(t50, "상급") and has(t75, "강화석 ≈5 · 상급 강화석 ≈5") and has(t100, "강화석 ≈5 · 상급 강화석 ≈5"))
	report(("제목 · 매번 · Lv 범위: [%s] · 50: [%s] (기대 '스테이지 50 보스 · 서리 거인' · '20마리분' · 'Lv 50~52' · '???' 없음)"):format(d50.title, t50),
		d50.title == "스테이지 50 보스 · 서리 거인" and has(t50, "골드·경험치 20마리분") and has(t50, "Lv 50~52") and not has(d50.title .. t50, "???"))
	local r0, r1 = rowsOf(50, entryOf(false, "available", "none"), 0), rowsOf(50, entryOf(false, "available", "none"), 1)
	report(("등급 이상 표기 · 확률 줄 수: 환생 0회 [%s] %d줄(기대 영웅 이상 · 5줄) / 환생 1회 [%s] %d줄(기대 희귀 이상 · 6줄)"):format(
		string.match(r0.rows[1].plain, "%((%S+) 이상") or "?", r0.helpLines, string.match(r1.rows[1].plain, "%((%S+) 이상") or "?", r1.helpLines),
		has(r0.rows[1].plain, "영웅 이상") and r0.helpLines == 5 and has(r1.rows[1].plain, "희귀 이상") and r1.helpLines == 6)
	-- 직업 / 계정은 다른 축: 장비는 이 직업 기준, 방지권은 계정 기준 - 한 줄이 받은 것이어도 다른 줄은 밝다.
	local axes = rowsOf(50, entryOf(false, "claimed", "none"))
	local gearRow, ticketRow = axes.rows[1], axes.rows[2]
	report(("직업 · 계정 축 분리(장비 미수령 · 방지권 수령): 장비 줄 흐림 %s(기대 false) · 방지권 줄 흐림 %s · '✓ 받음' %s(기대 true · true) · 꼬리표 [직업] %s · [계정] %s"):format(
		tostring(has(gearRow.text, dim)), tostring(has(ticketRow.text, dim)), tostring(has(ticketRow.plain, "✓ 받음")), tostring(has(gearRow.plain, "[직업]")), tostring(has(ticketRow.plain, "[계정]"))),
		not gearRow.claimed and not has(gearRow.text, dim) and ticketRow.claimed and has(ticketRow.text, dim) and has(ticketRow.plain, "✓ 받음") and has(gearRow.plain, "[직업]") and has(ticketRow.plain, "[계정]"))
	local done = rowsOf(50, entryOf(true, "claimed", "none"))
	local mixed = rowsOf(100, entryOf(true, "claimed", "available"))
	report(("받은 줄은 지워지지 않고 흐려진다: 장비 줄 '✓ 받음' %s · 흐림 %s(기대 true · true) · 줄 수 %d(기대 4 - 그대로) / 방지권이 하나만 받음 → '✓' %s · 줄 흐림 %s(기대 true · false)"):format(
		tostring(has(done.rows[1].plain, "✓ 받음")), tostring(has(done.rows[1].text, dim)), #done.rows, tostring(has(mixed.rows[2].plain, "하락 방지권 ×1 ✓")), tostring(has(mixed.rows[2].text, colored("하락 방지권 ×1 ✓ · 초기화 방지권 ×1 [계정]", "textTertiary")))),
		has(done.rows[1].plain, "✓ 받음") and has(done.rows[1].text, dim) and #done.rows == 4 and has(mixed.rows[2].plain, "하락 방지권 ×1 ✓") and not mixed.rows[2].claimed)
	report(("남은 것 판정(★): 미수령 %s · 장비만 받음 %s · 방지권만 남음 %s · 전부 받음 %s · 방지권 없는 스테이지 장비 받음 %s(기대 true true true false false)"):format(
		tostring(StageRewardBand.hasRemaining(entryOf(false, "available", "none"))), tostring(StageRewardBand.hasRemaining(entryOf(true, "available", "none"))),
		tostring(StageRewardBand.hasRemaining(entryOf(true, "available", "available"))), tostring(StageRewardBand.hasRemaining(entryOf(true, "claimed", "claimed"))), tostring(StageRewardBand.hasRemaining(entryOf(true, "none", "none")))),
		StageRewardBand.hasRemaining(entryOf(false, "available", "none")) and StageRewardBand.hasRemaining(entryOf(true, "available", "none")) and StageRewardBand.hasRemaining(entryOf(true, "available", "available"))
			and not StageRewardBand.hasRemaining(entryOf(true, "claimed", "claimed")) and not StageRewardBand.hasRemaining(entryOf(true, "none", "none")))
end

return StageRewardBand
