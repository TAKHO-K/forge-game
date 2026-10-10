-- M1-3 알 가방 · 알 정보창(오른쪽 칩 스택의 [알] 버튼이 연다). 본문 = 스크롤(폰에서도 글씨 실효 12 이상).
--   ① 알 목록(최근 것부터): 알 색 견본(구역 = 관문 색) · 구역 알 이름 · 등급 · 개체 후보 2(반반)
--   ② 부화 결과 확률(사전 고지 - EggData.hatch · 알 등급별 표) ③ 비밀 둥지 발견 수.
--   Q11: 알마다 [부화] · 부화 중(남은 시간 · [받기]) · 펫 목록([데리고 다니기]) · 부화 레벨 확률표(Pet.hatchTable - 서버 굴림과 같은 함수).
-- 값 = NestState(서버 NestSync) · PetSync(서버 PetService) · 문구 = TextData(egg.* · pet.*).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggData = require(ReplicatedStorage.Shared.data.EggData)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)
local NestState = require(script.Parent.Parent.NestState)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Pet = require(ReplicatedStorage.Shared.Pet)
local PetData = require(ReplicatedStorage.Shared.data.PetData)

local REST = require(ReplicatedStorage.Shared.data.UiV2Flags).rest -- UI-1 7c(H v1 · v1.1): 확률 = 막대 + 숫자 4칸 · 펫 잠금 · 놓아주기 2단계 · 알 없음 = 할 일
local HU = require(ReplicatedStorage.Shared.data.UiLayoutData).petUi.v1
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local petView = nil -- 서버 PetService.view(PetSync)
local petRequest = ReplicatedStorage:WaitForChild("PetRequest", 10)
local petSync = ReplicatedStorage:WaitForChild("PetSync", 10)

local EggInfoPanel = {}
EggInfoPanel.id = "eggInfo"

local PANEL_SIZE = Vector2.new(520, 400)
local PAD = 12
local ROW_H = 46

local built
local order = 0

local function clearBody()
	for _, c in ipairs(built.scroll:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	order = 0
end

local function line(text, sizeName, colorName, name)
	order += 1
	local label = Theme.label(built.scroll, text, sizeName, colorName)
	label.Name = name or ("Line" .. order)
	label.LayoutOrder = order
	label.TextWrapped = true
	label.Size = UDim2.new(1, 0, 0, Theme.textSize(sizeName) + 8)
	return label
end

local function swatch(parent, color, grade)
	local egg = Instance.new("Frame")
	egg.Name = "EggSwatch"
	egg.Size = UDim2.new(0, 22, 0, 30)
	egg.Position = UDim2.new(0, 6, 0.5, -15)
	egg.BackgroundColor3 = color
	egg.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = egg
	local look = EggData.look[grade] or EggData.look.normal
	local dark = Color3.new(color.R * EggData.look.patternDarken, color.G * EggData.look.patternDarken, color.B * EggData.look.patternDarken)
	for k = 1, look.pattern do
		local band = Instance.new("Frame")
		band.Name = "Band"
		band.BorderSizePixel = 0
		band.BackgroundColor3 = grade == "rare" and Color3.new(1, 1, 1) or dark
		band.Size = UDim2.new(1, 0, 0, 3)
		band.Position = UDim2.new(0, 0, (k + 0.5) / (look.pattern + 2), 0)
		band.Parent = egg
	end
	if look.glow then
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 2.5
		stroke.Transparency = 0.1
		stroke.Parent = egg
	end
	return egg
end

local function eggRow(egg, i)
	order += 1
	local frame = Instance.new("Frame")
	frame.Name = "EggRow" .. i
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, ROW_H)
	frame.BackgroundColor3 = Theme.color("slot")
	frame.BackgroundTransparency = 0.4
	frame.Parent = built.scroll
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	swatch(frame, NestState.zoneColor and NestState.zoneColor(egg.zone) or Color3.new(1, 1, 1), egg.grade)
	local zoneName = EggData.zones[egg.zone] and EggData.zones[egg.zone].name or tostring(egg.zone)
	local name = Theme.label(frame, Text.get("egg.row", { egg = zoneName, grade = EggData.gradeNames[egg.grade] or egg.grade }), "body", "textPrimary")
	name.Name = "EggName"
	name.Position = UDim2.new(0, 38, 0, 3)
	name.Size = UDim2.new(1, -44, 0, 20)
	local cand = Theme.label(frame, Text.get("egg.candidates", { a = EggData.species[egg.species[1]] or "?", b = EggData.species[egg.species[2]] or "?" }), "caption", "textSecondary")
	cand.Name = "EggCandidates"
	cand.Position = UDim2.new(0, 38, 0, 24)
	cand.Size = UDim2.new(1, -150, 0, 18)
	if petRequest and PetData.enabled then -- Q11 부화
		local b = Button.build({ parent = frame, kind = "primary", text = Text.get("pet.hatch"), width = 96, position = UDim2.new(1, -6, 0.5, 0), anchorPoint = Vector2.new(1, 0.5), onActivated = function()
			petRequest:FireServer("hatch", i, egg.at) -- 서버가 같은 알인지 대조
		end })
		b.root.Name = "HatchButton"
	end
end

local function petRow(text, sub, buttonText, onPress, name)
	order += 1
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, ROW_H)
	frame.BackgroundColor3 = Theme.color("slot")
	frame.BackgroundTransparency = 0.4
	frame.Parent = built.scroll
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	local a = Theme.label(frame, text, "body", "textPrimary")
	a.Position = UDim2.new(0, 10, 0, 3)
	a.Size = UDim2.new(1, -130, 0, 20)
	local b = Theme.label(frame, sub, "caption", "textSecondary")
	b.Position = UDim2.new(0, 10, 0, 24)
	b.Size = UDim2.new(1, -130, 0, 18)
	if buttonText then
		local btn = Button.build({ parent = frame, kind = "primary", text = buttonText, width = 110, position = UDim2.new(1, -6, 0.5, 0), anchorPoint = Vector2.new(1, 0.5), onActivated = onPress })
		btn.root.Name = "ActionButton"
	end
end

-- Q11: 부화 중 · 펫 · 부화 레벨 확률표
local function petSection()
	if not petView then
		return
	end
	local unixNow = os.time() + (petView.unix and (petView.unix - (petView.clientAt or os.time())) or 0)
	line(Text.get("pet.hatchingHeader", { n = #petView.hatching, cap = petView.queueCap }), "body", "textPrimary", "HatchingHeader")
	for _, h in ipairs(petView.hatching) do
		local left = math.max(0, h.doneAt - unixNow)
		local zoneName = EggData.zones[h.zone] and EggData.zones[h.zone].name or tostring(h.zone)
		petRow(Text.get("egg.row", { egg = zoneName, grade = EggData.gradeNames[h.grade] or h.grade }),
			left > 0 and Text.get("pet.left", { s = tostring(left) }) or Text.get("pet.ready"),
			left <= 0 and Text.get("pet.claim") or nil, function()
				petRequest:FireServer("claim", h.index)
			end, "Hatching" .. h.index)
	end
	line(Text.get("pet.listHeader", { n = #petView.pets, cap = petView.petCap, auto = petView.autoPickup and Text.get("pet.autoOn") or Text.get("pet.autoOff", { level = tostring(petView.unlocks.autoPickup) }) }), "body", "textPrimary", "PetHeader")
	for _, p in ipairs(petView.pets) do
		if REST then
			EggInfoPanel.petRowV7(p)
		else
			petRow(("%s · %s"):format(Text.name(p.name), Text.name(EggData.hatchGradeNames[p.grade] or p.grade)), Text.name(PetData.bodyNames[p.body] or p.body),
				p.equipped and Text.get("pet.unequip") or Text.get("pet.equip"), function()
					petRequest:FireServer("equip", (not p.equipped) and p.index or nil)
				end, "Pet" .. p.index)
		end
	end
	if REST and #petView.pets == 0 then
		line(Text.get("ui1.pet.noPet"), "caption", "textSecondary", "NoPet")
	end
	line(Text.get("pet.levelHeader", { level = petView.hatchLevel, count = petView.hatchCount }), "body", "textPrimary", "HatchLevel")
	for level, row in ipairs(PetData.levels) do
		local parts = {}
		for _, eggGrade in ipairs(EggData.gradeOrder) do
			local t = Pet.hatchTable(eggGrade, level)
			table.insert(parts, ("%s %.1f/%.1f/%.1f/%.1f"):format(Text.name(EggData.gradeNames[eggGrade]), t.common, t.uncommon, t.rare, t.epic))
		end
		line(Text.get("pet.levelRow", { level = level, hatches = row.hatches, rows = table.concat(parts, " · ") }), "caption", level == petView.hatchLevel and "textPrimary" or "textSecondary", "LevelRow" .. level)
	end
end

-- UI-1 7c 확률 표(H §1-1 · v1.1 §1): 줄 = 알 등급 · 쌓인 막대(등급색) + 숫자 4칸(등급색 · 일반 = 밝은 회색) · 값 = 지금 부화 레벨의 Pet.hatchTable(서버 굴림과 같은 함수 · 합 100 = 하네스 pet_ui)
local function fmtPct(v)
	return (math.abs(v - math.floor(v + 0.5)) < 1e-6) and ("%d%%"):format(math.floor(v + 0.5)) or ("%.1f%%"):format(v)
end
local function hatchTableV7()
	local phone = Theme.isMobile
	line(Text.get("egg.hatchHeader"), "body", "textPrimary", "HatchHeader")
	line(Text.get("ui1.pet.oddsNote"), "caption", "textSecondary", "OddsNote")
	order += 1
	local legend = Instance.new("Frame") -- 범례 = 색 네모 + 등급 이름
	legend.Name = "OddsLegend"
	legend.LayoutOrder = order
	legend.BackgroundTransparency = 1
	legend.Size = UDim2.new(1, 0, 0, 20)
	legend.Parent = built.scroll
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.Padding = UDim.new(0, 10)
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = legend
	for i, g in ipairs(EggData.hatchGrades) do
		local sq = Instance.new("Frame")
		sq.BackgroundColor3 = Color3.fromHex(HU.gradeColors[g])
		sq.Size = UDim2.fromOffset(12, 12)
		sq.LayoutOrder = i * 2
		sq.Parent = legend
		local t = Theme.label(legend, Text.name(EggData.hatchGradeNames[g]), "caption", "textSecondary")
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromOffset(0, 20)
		t.LayoutOrder = i * 2 + 1
	end
	local level = petView and petView.hatchLevel or 1
	local nameW, numW = phone and HU.phone.nameW or HU.pc.nameW, phone and HU.phone.numW or HU.pc.numW
	for _, eggGrade in ipairs(EggData.gradeOrder) do
		local t = Pet.hatchTable(eggGrade, level)
		order += 1
		local row = Instance.new("Frame")
		row.Name = "OddsRow_" .. eggGrade
		row.LayoutOrder = order
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, phone and HU.phone.rowH or HU.pc.rowH)
		row.Parent = built.scroll
		local n = Theme.label(row, Text.name(EggData.gradeNames[eggGrade]), "caption", "textPrimary")
		n.Font = Enum.Font.GothamBold
		n.Size = UDim2.new(0, nameW, 1, 0)
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BackgroundColor3 = Theme.color("slot")
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.new(0, nameW, 0.5, 0)
		bar.Size = UDim2.new(1, -(nameW + numW * 4 + 6), 0, phone and HU.phone.barH or HU.pc.barH)
		bar.ClipsDescendants = true
		bar.Parent = row
		local x = 0
		for _, g in ipairs(EggData.hatchGrades) do
			local seg = Instance.new("Frame")
			seg.Name = "Seg_" .. g
			seg.BorderSizePixel = 0
			seg.BackgroundColor3 = Color3.fromHex(HU.gradeColors[g])
			seg.Position = UDim2.fromScale(x / 100, 0)
			seg.Size = UDim2.fromScale((t[g] or 0) / 100, 1)
			seg.Parent = bar
			x += t[g] or 0
		end
		for i, g in ipairs(EggData.hatchGrades) do -- 숫자 열(폰도 네 등급 전부 - 작은 값도 읽힘)
			local num = Theme.label(row, fmtPct(t[g] or 0), "caption", "textPrimary")
			num.Name = "Num_" .. g
			num.Font = Enum.Font.GothamBold
			num.TextXAlignment = Enum.TextXAlignment.Right
			num.TextColor3 = Color3.fromHex(g == "common" and HU.commonText or HU.gradeColors[g])
			num.AnchorPoint = Vector2.new(1, 0)
			num.Position = UDim2.new(1, -(4 - i) * numW, 0, 0)
			num.Size = UDim2.new(0, numW, 1, 0)
		end
	end
	line(Text.get("ui1.pet.rules"), "caption", "textSecondary", "HatchRules")
end

-- 부화 결과 확률 표: 열 = 알 등급(보통 · 좋은 · 희귀) · 줄 = 결과 등급(일반 · 희귀 · 영웅 · 전설 - 표시 이름 = EggData.hatchGradeNames)
local function hatchTable()
	if REST then
		return hatchTableV7()
	end
	line(Text.get("egg.hatchHeader"), "body", "textPrimary", "HatchHeader")
	order += 1
	local grid = Instance.new("Frame")
	grid.Name = "HatchTable"
	grid.LayoutOrder = order
	grid.BackgroundTransparency = 1
	local rows = #EggData.hatchGrades + 1
	local cellH = Theme.textSize("caption") + 10
	grid.Size = UDim2.new(1, 0, 0, rows * cellH)
	grid.Parent = built.scroll
	local cols = #EggData.gradeOrder + 1
	for c = 1, cols do
		for r = 1, rows do
			local text
			if r == 1 and c == 1 then
				text = ""
			elseif r == 1 then
				text = Text.get("egg.hatchCol", { grade = EggData.gradeNames[EggData.gradeOrder[c - 1]] })
			elseif c == 1 then
				text = Text.name(EggData.hatchGradeNames[EggData.hatchGrades[r - 1]])
			else
				local v = EggData.hatch[EggData.gradeOrder[c - 1]][EggData.hatchGrades[r - 1]]
				text = (v % 1 == 0) and ("%d%%"):format(v) or ("%.1f%%"):format(v)
			end
			local cell = Theme.label(grid, text, "caption", (r == 1 or c == 1) and "textSecondary" or "textPrimary")
			cell.Name = ("Cell_%d_%d"):format(r, c)
			cell.Position = UDim2.new((c - 1) / cols, 0, 0, (r - 1) * cellH)
			cell.Size = UDim2.new(1 / cols, -4, 0, cellH)
			cell.TextXAlignment = c == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		end
	end
end

local function render()
	if not built then
		return
	end
	built.panel.titleLabel.Text = Text.get("egg.title", { count = #NestState.eggs, cap = NestState.cap })
	clearBody()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = built.scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, PAD), UDim.new(0, PAD + 4), UDim.new(0, PAD), UDim.new(0, PAD)
	pad.Parent = built.scroll
	if #NestState.eggs == 0 and REST then -- UI-1 7c 빈 상태 = 할 일 3 + [지도에서 둥지 보기]
		line(Text.get("ui1.pet.noEggTitle"), "body", "textPrimary", "Empty")
		for i = 1, 3 do
			line(("%d. %s"):format(i, Text.get("ui1.pet.noEggTodo" .. i)), "caption", "textSecondary", "Todo" .. i)
		end
		order += 1
		local holder = Instance.new("Frame")
		holder.Name = "NestMapRow"
		holder.LayoutOrder = order
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, 0, 0, 48)
		holder.Parent = built.scroll
		local b = Button.build({ parent = holder, kind = "secondary", text = Text.get("ui1.pet.nestMap"), width = 220, height = 44, onActivated = function()
			UIManager.close(EggInfoPanel.id)
			UIManager.openLazy("worldMap")
		end })
		b.root.Name = "NestMapButton"
	elseif #NestState.eggs == 0 then
		line(Text.get("egg.empty"), "body", "textSecondary", "Empty")
	else
		for i = #NestState.eggs, 1, -1 do
			eggRow(NestState.eggs[i], i)
		end
	end
	hatchTable()
	petSection()
	line(Text.get("egg.dex", { count = NestState.dex }), "caption", "textSecondary", "Dex")
end

local function build()
	local panel = Panel.create({
		id = EggInfoPanel.id,
		kind = "window",
		title = Text.get("egg.title", { count = 0, cap = NestState.cap }),
		size = PANEL_SIZE,
	})
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
	built = { panel = panel, scroll = scroll }
	NestState.changed:Connect(render)
end

if petSync then
	petSync.OnClientEvent:Connect(function(view)
		if type(view) == "table" then
			view.clientAt = os.time()
			petView = view
			render()
		end
	end)
end

function EggInfoPanel.toggle()
	if not built then
		build()
	end
	if petRequest then
		petRequest:FireServer("view")
	end
	render()
	UIManager.switchTo(EggInfoPanel.id)
end

-- UI-1 7c 펫 줄(H v1.1 §2): [잠금 56] [놓아주기](보조 · 데리고 다님 · 잠금 = 흐림 + 이유 · 누르면 같은 이유 토스트) [데리고 다니기](노랑)
local confirmBox = nil
local function releaseConfirm(p)
	if confirmBox then
		confirmBox:Destroy()
	end
	local f = Instance.new("Frame")
	f.Name = "ReleaseConfirm"
	f.BackgroundColor3 = Color3.fromHex(HU.confirm.bg)
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 50
	f.Active = true
	f.Parent = built.panel.content
	confirmBox = f
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromHex(HU.confirm.stroke)
	st.Thickness = 3
	st.Parent = f
	local title = Theme.label(f, "", "header", "textPrimary")
	title.Position, title.Size = UDim2.fromOffset(PAD, PAD), UDim2.new(1, -PAD * 2, 0, 30)
	local card = Theme.label(f, ("%s · %s"):format(Text.name(p.name), Text.name(EggData.hatchGradeNames[p.grade] or p.grade)), "body", "textPrimary")
	card.Position, card.Size = UDim2.fromOffset(PAD, PAD + 40), UDim2.new(1, -PAD * 2, 0, 24)
	card.TextColor3 = Color3.fromHex(HU.gradeColors[p.grade] or "FFFFFF")
	local warn = Theme.label(f, "▼ " .. Text.get("ui1.pet.releaseWarn"), "caption", "textSecondary")
	warn.Position, warn.Size = UDim2.fromOffset(PAD, PAD + 70), UDim2.new(1, -PAD * 2, 0, 20)
	warn.TextColor3 = Color3.fromHex(HU.confirm.warn)
	local step = 1
	local go
	local function show()
		title.Text = Text.get(step == 1 and "ui1.pet.release1" or "ui1.pet.release2")
		warn.Visible = step == 2
		go.setText(Text.get(step == 1 and "ui1.set.next" or "ui1.pet.release"))
	end
	Button.build({ parent = f, kind = "buy", name = "Cancel", text = Text.get("ui1.set.cancel"), width = 150, height = 44, position = UDim2.new(1, -PAD - 310, 1, -PAD - 44), onActivated = function()
		f:Destroy()
		confirmBox = nil
	end })
	go = Button.build({ parent = f, kind = "secondary", name = "Go", text = "", width = 150, height = 44, position = UDim2.new(1, -PAD - 150, 1, -PAD - 44), onActivated = function()
		if step == 1 then
			step = 2
			show()
		else
			petRequest:FireServer("release", { index = p.index, at = p.at })
			Toast.push("TC", { text = Text.get("ui1.pet.released", { name = Text.name(p.name) }), colorName = "textPrimary" })
			f:Destroy()
			confirmBox = nil
		end
	end })
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 51
		end
	end
	show()
end
function EggInfoPanel.petRowV7(p)
	order += 1
	local frame = Instance.new("Frame")
	frame.Name = "Pet" .. p.index
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, HU.petRowH)
	frame.BackgroundColor3 = Theme.color("slot")
	frame.BackgroundTransparency = 0.4
	frame.Parent = built.scroll
	Theme.corner(frame, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Color = p.equipped and Color3.fromHex("FFC83D") or Color3.fromHex(HU.gradeColors[p.grade] or "3A4466")
	stroke.Thickness = p.equipped and 3 or 1.5
	stroke.Parent = frame
	local a = Theme.label(frame, ("%s · %s"):format(Text.name(p.name), Text.name(EggData.hatchGradeNames[p.grade] or p.grade)), "body", "textPrimary")
	a.Position, a.Size = UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 20)
	local reason = p.equipped and Text.get("ui1.pet.whyEquipped") or (p.locked and Text.get("ui1.pet.whyLocked") or nil)
	local sub = Theme.label(frame, reason or Text.name(PetData.bodyNames[p.body] or p.body), "caption", "textSecondary")
	sub.Name = "Reason"
	sub.TextWrapped = true
	sub.Position, sub.Size = UDim2.fromOffset(10, 26), UDim2.new(1, -20, 0, 18)
	local by = HU.petRowH - 50
	local lock = Button.build({ parent = frame, kind = "secondary", name = "LockButton", text = Text.get(p.locked and "ui1.pet.unlock" or "ui1.pet.lock"), width = 96, height = 44, position = UDim2.fromOffset(8, by), onActivated = function()
		petRequest:FireServer("lock", { index = p.index, at = p.at, on = not p.locked })
	end })
	lock.root.Name = "LockButton"
	local rel = Button.build({ parent = frame, kind = "secondary", name = "ReleaseButton", text = Text.get("ui1.pet.release"), width = 120, height = 44, position = UDim2.fromOffset(112, by), onActivated = function()
		if reason then
			Toast.push("TC", { text = reason, colorName = "textPrimary" })
			return
		end
		releaseConfirm(p)
	end })
	if reason then -- 흐림(눌리면 같은 이유 토스트 - setEnabled(false)면 안 눌려서 색만 흐리게)
		rel.root.BackgroundTransparency = 0.6
		rel.root.TextTransparency = 0.5
	end
	local eq = Button.build({ parent = frame, kind = "buy", name = "EquipButton", text = p.equipped and Text.get("ui1.pet.equipping") or Text.get("pet.equip"), width = 150, height = 44,
		position = UDim2.new(1, -8, 0, by), anchorPoint = Vector2.new(1, 0), onActivated = function()
			if not p.equipped then
				petRequest:FireServer("equip", p.index)
			end
		end })
	eq.setEnabled(not p.equipped)
end

function EggInfoPanel.debugRefs()
	return built
end

return EggInfoPanel
