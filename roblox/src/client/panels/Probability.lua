-- QUEUE-10h Q13 P4b 확률 공개 창(퀘스트 창 [확률 공개] 줄이 연다). 값 = shared/Disclosure.build(서버 굴림과 같은 표 · 함수 - 클라가 직접 계산해도 서버와 같다) · 문구 = TextData(prob.*).
--   ① 잡몹 장비 등급(티어별) ② 보스 첫 클리어 · 토벌 · 반짝이 ③ 강화(+0 ~ +29 결과 5종) ④ 옵션 리롤(내 직업 풀 - 비활성 스위치 반영) ⑤ 스킬 변형(내 직업) ⑥ 부화(부화 레벨 × 알 등급) · 표 버전.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local SkillVariantData = require(ReplicatedStorage.Shared.data.SkillVariantData)
local Disclosure = require(ReplicatedStorage.Shared.Disclosure)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)
local GradeFrame = require(script.Parent.Parent.GradeFrame) -- A2-N2 2-5: 등급 이름을 등급 색으로(ArtStyleV1 스위치 뒤)

local ProbabilityPanel = {}
ProbabilityPanel.id = "probability"

local PANEL_SIZE = Vector2.new(560, 420)
local PAD = 12

local built
local order = 0

local function line(text, sizeName, colorName)
	order += 1
	local label = Theme.label(built.scroll, text, sizeName, colorName)
	label.Name = "Line" .. order
	label.LayoutOrder = order
	label.TextWrapped = true
	label.RichText = GradeFrame.isOn() -- 등급 이름 색(<font>) - 확률 문구에는 < > 가 없다
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, Theme.textSize(sizeName) + 6)
	return label
end

local function pct(x) -- 리뷰: 아주 작은 확률(초월 1e-7 등)도 0으로 안 보이게 유효숫자로
	local v = x * 100
	if v == 0 then
		return "0%"
	elseif v >= 1 then
		return ("%.2f%%"):format(v)
	end
	return ("%.3g%%"):format(v)
end

local function gradeRowsText(rows)
	local parts = {}
	for _, r in ipairs(rows) do
		local g = ArmorData.grades[r.id]
		local name = g and Text.name(g.displayName) or r.id
		if GradeFrame.isOn() then
			name = ('<font color="#%s"><b>%s</b></font>'):format(GradeFrame.colorOf(r.id):ToHex(), name)
		end
		table.insert(parts, ("%s %s"):format(name, pct(r.chance)))
	end
	return table.concat(parts, " · ")
end

local function optionName(id)
	local def = OptionData.options[id]
	if def and def.displayName then
		return Text.name(def.displayName)
	end
	local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
	local s = def and def.classId and SkillData[def.classId] and SkillData[def.classId][def.slot]
	return s and Text.name(s.name) or id
end

local function render()
	if not built then
		return
	end
	for _, c in ipairs(built.scroll:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	order = 0
	local d = Disclosure.build()
	local classId = Players.LocalPlayer:GetAttribute("ClassId")
	if d.drop.riftBoost then -- QUEUE-ALL1 P3 §3: 균열 중 = 아래 표가 균열 표(서버 굴림과 같다)
		local parts = {}
		for _, gradeId in ipairs(require(ReplicatedStorage.Shared.data.ArmorData).gradeOrder) do
			local m = d.drop.riftBoost[gradeId]
			if m then
				table.insert(parts, ("%s ×%g"):format(Text.name(require(ReplicatedStorage.Shared.data.ArmorData).grades[gradeId].displayName), m))
			end
		end
		local ruleKey = require(ReplicatedStorage.Shared.DropTable).gainOnly and "ui.prob.riftGainOnly" or "ui.prob.riftBelow" -- QUEUE-ALL1 R1
		line(Text.get(ruleKey, { list = table.concat(parts, " · ") }), "body", "textPrimary")
	end
	line(Text.get("prob.field"), "body", "textPrimary")
	for tier, rows in ipairs(d.drop.field) do
		line(("T%d: %s"):format(tier, gradeRowsText(rows)), "caption", "textSecondary")
	end
	line(Text.get("prob.boss"), "body", "textPrimary")
	line(Text.get("prob.firstClear") .. gradeRowsText(d.drop.firstClear), "caption", "textSecondary")
	if d.firstBossMinGrade then -- QUEUE-ALL1 P3: 그 직업의 첫 보스 첫 클리어 = 이 등급 이상 확정(굴림이 아래면 올린다)
		local g = require(ReplicatedStorage.Shared.data.ArmorData).grades[d.firstBossMinGrade]
		line(Text.get("ui.prob.firstBossMin", { grade = g and g.displayName or d.firstBossMinGrade }), "caption", "textSecondary")
	end
	line(Text.get("prob.raid", { sec = tostring(require(ReplicatedStorage.Shared.data.DropTableData).raidTimeFairness.referenceSeconds) }) .. gradeRowsText(d.drop.raid), "caption", "textSecondary")
	line(Text.get("prob.sparkle") .. gradeRowsText(d.drop.sparkle), "caption", "textSecondary")
	line(Text.get("prob.enhance"), "body", "textPrimary")
	for _, r in ipairs(d.enhance) do
		line(Text.get("ui.prob.enhanceRow", { from = ("%d"):format(r.level), to = ("%d"):format(r.level + 1), success = pct(r.success), maintain = pct(r.maintain), down1 = pct(r.down1), down2 = pct(r.down2), reset = pct(r.reset) }), "caption", "textSecondary")
	end
	line(Text.get("prob.option"), "body", "textPrimary")
	local pool = d.options[classId] or Disclosure.optionPool(nil) -- 직업 없음 = 공통 풀(실제 rollFor(nil)과 같음)
	local names = {}
	for _, r in ipairs(pool or {}) do
		table.insert(names, ("%s %s"):format(optionName(r.id), pct(r.chance)))
	end
	line(table.concat(names, " · "), "caption", "textSecondary")
	local off = {}
	for id in pairs(d.optionDisabled or {}) do
		table.insert(off, optionName(id))
	end
	if #off > 0 then
		line(Text.get("prob.optionOff", { list = table.concat(off, " · ") }), "caption", "textSecondary")
	end
	line(Text.get("prob.variant", { appear = pct(d.variants.appearChance), kills = tostring(d.variantRerollKills) }), "body", "textPrimary")
	for _, r in ipairs(d.variants.classes[classId] or {}) do
		local t = SkillVariantData.templates[r.id]
		line(("%s %s %s"):format(r.slot, t and Text.name(t.name) or r.id, pct(r.chance)), "caption", "textSecondary")
	end
	line(Text.get("prob.hatch"), "body", "textPrimary")
	for _, lv in ipairs(d.hatch.levels) do
		local parts = {}
		for _, eggGrade in ipairs(EggData.gradeOrder) do
			local t = lv.byEgg[eggGrade]
			table.insert(parts, ("%s %.1f/%.1f/%.1f/%.1f"):format(Text.name(EggData.gradeNames[eggGrade]), t.common, t.uncommon, t.rare, t.epic))
		end
		line(Text.get("ui.prob.hatchRow", { level = ("%d"):format(lv.level), hatches = ("%d"):format(lv.hatches), list = table.concat(parts, " · ") }), "caption", "textSecondary")
	end
	line(Text.get("prob.version", { version = d.version }), "caption", "textTertiary")
end

local function build()
	local panel = Panel.create({ id = ProbabilityPanel.id, kind = "window", title = Text.get("prob.title"), size = PANEL_SIZE })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.color("rim")
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = panel.content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, PAD), UDim.new(0, PAD + 4), UDim.new(0, PAD), UDim.new(0, PAD)
	pad.Parent = scroll
	built = { panel = panel, scroll = scroll }
end

function ProbabilityPanel.open()
	if not built then
		build()
	end
	render()
	UIManager.switchTo(ProbabilityPanel.id)
end

function ProbabilityPanel.debugRefs()
	return built
end

return ProbabilityPanel
