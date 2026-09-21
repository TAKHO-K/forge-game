local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local Loot = require(ReplicatedStorage.Shared.Loot)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Gem = require(ReplicatedStorage.Shared.Gem)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Layout = require(script.Parent.Layout)

-- 상세(S20b: InventoryUI 분할) - PC는 하단 상세 바(104), 폰은 아래에서 올라오는 시트(선택이 있을 때만 · 닫기 44). 이름 · 메타 · 옵션 줄 · 잠금 / 판매 / 분해 / 착용 / 리롤 버튼과 그 서버 요청, refreshDetail이 전부 여기 있다.
local DetailSheet = {}

function DetailSheet.create(S, R)
local player = S.player
local content = R.content
local equipRequest = ReplicatedStorage:WaitForChild("EquipRequest")
local sellRequest = ReplicatedStorage:WaitForChild("SellRequest")
local lockRequest = ReplicatedStorage:WaitForChild("LockRequest")
local dismantleRequest = ReplicatedStorage:WaitForChild("DismantleRequest")
local gemRerollRequest = ReplicatedStorage:WaitForChild("GemRerollRequest")

-- ═══ 하단 상세바 ═══
local detail = Instance.new("Frame")
detail.Name = "Detail"
detail.AnchorPoint = Vector2.new(0, 1)
detail.Position = UDim2.new(0, 0, 1, 0)
detail.Size = UDim2.new(1, 0, 0, Layout.pcDetailHeight)
detail.BackgroundColor3 = Color3.new(0, 0, 0)
detail.BackgroundTransparency = 0.74
detail.ZIndex = 10 -- 폰: 시트가 본문(스크롤 프레임) 위에 얹힌다
detail.Parent = content
R.detail = detail

local detailTopLine = Instance.new("Frame")
detailTopLine.Size = UDim2.new(1, 0, 0, 1)
detailTopLine.BackgroundColor3 = UIColors.rim
detailTopLine.BackgroundTransparency = UIColors.rimTransparency
detailTopLine.BorderSizePixel = 0
detailTopLine.Parent = detail

local detailPadding = Instance.new("UIPadding")
detailPadding.PaddingLeft = UDim.new(0, 16)
detailPadding.PaddingRight = UDim.new(0, 16)
detailPadding.Parent = detail

-- 헤더와 같은 이유로 UIListLayout 하나에 flex 스페이서를 넣지 않는다 - dpic·dinfo는
-- 왼쪽에 절대 위치로, 버튼 3개(dact)는 오른쪽에 붙는 별도 그룹으로 나눈다.
local dpic = Instance.new("Frame")
dpic.AnchorPoint = Vector2.new(0, 0.5)
dpic.Position = UDim2.new(0, 0, 0.5, 0)
dpic.Size = UDim2.new(0, 56, 0, 56)
dpic.BackgroundColor3 = UIColors.slot
dpic.BackgroundTransparency = UIColors.slotTransparency
dpic.Parent = detail
local dpicCorner = Instance.new("UICorner")
dpicCorner.CornerRadius = UDim.new(0, 8)
dpicCorner.Parent = dpic
local dpicStroke = Instance.new("UIStroke")
dpicStroke.Thickness = 1.5
dpicStroke.Color = UIColors.rim
dpicStroke.Transparency = UIColors.rimTransparency
dpicStroke.Parent = dpic

local dinfo = Instance.new("Frame")
dinfo.Position = UDim2.new(0, 70, 0, 0)
dinfo.Size = UDim2.new(1, -260, 1, 0)
dinfo.BackgroundTransparency = 1
dinfo.Parent = detail

local dname = Instance.new("TextLabel")
dname.Position = UDim2.new(0, 0, 0, 14)
dname.Size = UDim2.new(1, 0, 0, 18)
dname.BackgroundTransparency = 1
dname.Font = Enum.Font.GothamBold
dname.TextSize = Theme.textSize("body")
dname.TextXAlignment = Enum.TextXAlignment.Left
dname.TextColor3 = UIColors.textPrimary
dname.Text = "선택된 아이템 없음"
dname.Parent = dinfo

local dmeta = Instance.new("TextLabel")
dmeta.Position = UDim2.new(0, 0, 0, 36)
dmeta.Size = UDim2.new(1, 0, 0, 16)
dmeta.BackgroundTransparency = 1
dmeta.Font = Enum.Font.Gotham
dmeta.TextSize = Theme.textSize("caption") -- 16-6 [4]: 12px 미만 금지.
dmeta.TextXAlignment = Enum.TextXAlignment.Left
dmeta.TextColor3 = UIColors.textTertiary
dmeta.Text = ""
dmeta.Parent = dinfo

-- 버튼 3개 묶음 - 화면 오른쪽에 붙는다.
local dact = Instance.new("Frame")
dact.AnchorPoint = Vector2.new(1, 0.5)
dact.Position = UDim2.new(1, 0, 0.5, 0)
dact.AutomaticSize = Enum.AutomaticSize.X
dact.Size = UDim2.new(0, 0, 0, 34)
dact.BackgroundTransparency = 1
dact.Parent = detail

local dactLayout = Instance.new("UIListLayout")
dactLayout.FillDirection = Enum.FillDirection.Horizontal
dactLayout.VerticalAlignment = Enum.VerticalAlignment.Center
dactLayout.Padding = UDim.new(0, 7)
dactLayout.SortOrder = Enum.SortOrder.LayoutOrder
dactLayout.Parent = dact

local function makeActionButton(order, width, style)
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = order
	btn.Text = ""
	btn.Size = UDim2.new(0, width, 0, 34)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = Theme.textSize("body")
	btn.Parent = dact

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Parent = btn

	if style == "primary" then
		btn.BackgroundColor3 = UIColors.ember
		btn.BackgroundTransparency = 0.72
		btn.TextColor3 = Color3.fromRGB(255, 217, 191)
		stroke.Color = UIColors.ember
		stroke.Transparency = 0.38
	elseif style == "sell" then
		btn.BackgroundColor3 = UIColors.panel
		btn.BackgroundTransparency = UIColors.panelTransparency
		btn.TextColor3 = UIColors.gold
		stroke.Color = UIColors.gold
		stroke.Transparency = 0.58
	else
		btn.BackgroundColor3 = UIColors.panel
		btn.BackgroundTransparency = UIColors.panelTransparency
		btn.TextColor3 = UIColors.textPrimary
		stroke.Color = UIColors.rim
		stroke.Transparency = UIColors.rimTransparency
	end

	return btn, stroke
end

local lockButton = makeActionButton(1, 36, "lock")
local lockIconHolder = Instance.new("Frame")
lockIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
lockIconHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
lockIconHolder.Size = UDim2.new(0, 14, 0, 14)
lockIconHolder.BackgroundTransparency = 1
lockIconHolder.Parent = lockButton
ItemIcons.lock(lockIconHolder, 14, UIColors.xp)

local sellButton = makeActionButton(2, 76, "sell")
sellButton.Text = "판매"

-- 분해(23-2, PRD 20.38 [3] 확장) - 상위 5등급(영웅~태초)만 대상. 판매와 자리를 나란히
-- 두되 서로 다른 결과를 준다(분해=보석만, 판매=골드만, PlayerProfile.dismantleItem 주석
-- 참고) - 같은 "sell" 스타일(금색 테두리)을 재사용한다(새 색을 안 만든다는 지시).
local dismantleButton = makeActionButton(3, 60, "sell")
dismantleButton.Text = "분해"

local equipButton = makeActionButton(4, 84, "primary")
equipButton.Text = "착용"

-- 리롤(26-3, PRD 20.67 [10] "장비 3부위도 옵션 변환권으로 리롤할 수 있다") - 보석 탭
-- rerollButton과 같은 자리(gold 테두리, "sell" 스타일 재사용 - 새 색을 안 만든다).
-- 고대·태초 등급의 가방/착용 아이템에서만 보인다(Gem.isRerollableGrade).
local rerollDetailButton = makeActionButton(5, 70, "sell")
-- ═══ 옵션 줄(26-3, PRD 20.67 [12]) ═══
-- 26-3 실기 검증 중 발견: 이 파일이 이미 Luau 최상위 레지스터 200개 한계에 가까웠다
-- ("Out of local registers ... exceeded limit 200"로 실제 실패) - setupGemTab/
-- setupPartyTab과 같은 이유로 함수 하나로 감싸 내부 로컬(게이지 부품들)이 최상위
-- 레지스터를 안 먹게 한다. 밖에서 실제로 쓰는 건 refreshOptionRow 하나뿐이다(optionRow
-- 자체는 26-3 수정으로 이 함수 내부 전용이 됐다 - 밖에서는 refreshOptionRow(nil)로
-- 숨긴다).
local refreshOptionRow

local function setupOptionRow()
	-- 26-3 수정: OptionData/Option/SkillData도 여기서만 쓰므로 여기서 require한다(최상위
	-- 레지스터를 아끼기 위함 - 위 InfiniteStage 주석 참고).
	local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
	local Option = require(ReplicatedStorage.Shared.Option)
	local optionRow

	-- "폭 120×높이 6, 트랙 UIColors.slot, 채움은 등급색으로 롤 위치까지, 중앙(기댓값)에
	-- rimHi 눈금 1×10px. 양끝에 최소·최대 숫자" - 명세 그대로. compact(치명 전용 절반
	-- 폭)는 최소·최대 숫자를 생략한다(한 줄에 게이지 두 개가 들어가야 해서 자리가 없다).
	local function buildOptionGauge(parent, compact)
		local wrap = Instance.new("Frame")
		wrap.BackgroundTransparency = 1
		wrap.Size = UDim2.new(1, 0, 1, 0)
		wrap.Parent = parent

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = wrap

		local valueText = Instance.new("TextLabel")
		valueText.LayoutOrder = 1
		valueText.BackgroundTransparency = 1
		valueText.Size = UDim2.new(0, compact and 96 or 130, 1, 0)
		valueText.Font = Enum.Font.GothamBold
		valueText.TextSize = Theme.textSize("caption") -- 16-6 [4]: 12px 미만 금지.
		valueText.TextXAlignment = Enum.TextXAlignment.Left
		valueText.TextColor3 = UIColors.textPrimary
		valueText.TextTruncate = Enum.TextTruncate.AtEnd
		valueText.Text = ""
		valueText.Parent = wrap

		local minText = Instance.new("TextLabel")
		minText.LayoutOrder = 2
		minText.Visible = not compact
		minText.BackgroundTransparency = 1
		minText.Size = UDim2.new(0, 26, 1, 0)
		minText.Font = Enum.Font.Gotham
		minText.TextSize = Theme.textSize("caption")
		minText.TextXAlignment = Enum.TextXAlignment.Right
		minText.TextColor3 = UIColors.textTertiary
		minText.Text = ""
		minText.Parent = wrap

		local track = Instance.new("Frame")
		track.LayoutOrder = 3
		track.Size = UDim2.new(0, compact and 44 or 120, 0, 6)
		track.BackgroundColor3 = UIColors.slot
		track.BorderSizePixel = 0
		track.Parent = wrap
		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = UIColors.textPrimary
		fill.BorderSizePixel = 0
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		-- 기댓값(중앙) 눈금 - 항상 트랙 정중앙(롤 U[0.875,1.125]의 중앙=1.0이 기댓값이다).
		local tick = Instance.new("Frame")
		tick.Name = "Tick"
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.new(0.5, 0, 0.5, 0)
		tick.Size = UDim2.new(0, 1, 0, 10)
		tick.BackgroundColor3 = UIColors.rimHi
		tick.BackgroundTransparency = UIColors.rimHiTransparency
		tick.BorderSizePixel = 0
		tick.ZIndex = 2
		tick.Parent = track

		local maxText = Instance.new("TextLabel")
		maxText.LayoutOrder = 4
		maxText.Visible = not compact
		maxText.BackgroundTransparency = 1
		maxText.Size = UDim2.new(0, 30, 1, 0)
		maxText.Font = Enum.Font.Gotham
		maxText.TextSize = Theme.textSize("caption")
		maxText.TextXAlignment = Enum.TextXAlignment.Left
		maxText.TextColor3 = UIColors.textTertiary
		maxText.Text = ""
		maxText.Parent = wrap

		return { wrap = wrap, valueText = valueText, minText = minText, track = track, fill = fill, maxText = maxText }
	end

	optionRow = Instance.new("Frame")
	optionRow.Name = "OptionRow"
	optionRow.Position = UDim2.new(0, 0, 0, 58)
	optionRow.Size = UDim2.new(1, 0, 0, 18)
	optionRow.BackgroundTransparency = 1
	optionRow.Visible = false
	optionRow.Parent = dinfo

	local optionRowLayout = Instance.new("UIListLayout")
	optionRowLayout.FillDirection = Enum.FillDirection.Horizontal
	optionRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	optionRowLayout.Padding = UDim.new(0, 10)
	optionRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionRowLayout.Parent = optionRow

	local optionGaugeA = buildOptionGauge(optionRow, false)
	local optionGaugeB = buildOptionGauge(optionRow, true)
	optionGaugeA.wrap.LayoutOrder = 1
	optionGaugeB.wrap.LayoutOrder = 2
	optionGaugeB.wrap.Visible = false

	-- 게이지 하나에 값·범위·롤 위치를 채운다. p(0~1)는 (roll-rollMin)/(rollMax-rollMin) -
	-- [12] "값 텍스트 색: p≥0.75 success, p≤0.25 textSecondary, 그 외 textPrimary".
	-- accent(S13) = 직업 특화 옵션이 내 직업과 맞을 때의 직업색(글씨색). 회색(dim)이 우선, 그 밖의 옵션은 nil이라 기존 규칙 그대로.
	local function applyOptionGauge(gauge, text, minText, maxText, p, fillColor, dim, accent)
		p = math.clamp(p, 0, 1)
		gauge.valueText.Text = text
		gauge.valueText.TextColor3 = dim and UIColors.textTertiary
			or accent
			or (p >= 0.75 and UIColors.success or (p <= 0.25 and UIColors.textSecondary or UIColors.textPrimary))
		gauge.minText.Text = minText or ""
		gauge.maxText.Text = maxText or ""
		gauge.fill.Size = UDim2.new(p, 0, 1, 0)
		gauge.fill.BackgroundColor3 = dim and UIColors.textTertiary or fillColor
	end

	-- item(장비 아이템 또는 보석)의 option을 읽어 옵션 줄을 채운다. option이 없으면
	-- 숨긴다. classId는 지금 활성 직업(Attribute "ClassId") - 직업 특화 옵션의 불일치
	-- 판정에 쓰인다.
	refreshOptionRow = function(item)
		if not item or not item.option then
			optionRow.Visible = false
			return
		end
		local classId = player:GetAttribute("ClassId")
		local optionId = item.option.id
		local def = OptionData.options[optionId]
		if not def then
			optionRow.Visible = false
			return
		end
		local gradeVisual = ItemVisualData.gradeVisuals[item.grade]
		local fillColor = (gradeVisual and not gradeVisual.rainbow) and gradeVisual.color or UIColors.textPrimary
		-- 글 · 회색(직업 불일치) · 직업색은 ItemDescribe가 준다(S20 - 툴팁 · 장비 보기와 같은 문구).
		local lines = ItemDescribe.optionLines(item, classId)

		optionRow.Visible = true
		local rollSpan = OptionData.rollMax - OptionData.rollMin

		if optionId == "crit" then
			optionGaugeB.wrap.Visible = true
			local pRate = (item.option.roll - OptionData.rollMin) / rollSpan
			local pDmg = ((item.option.roll2 or item.option.roll) - OptionData.rollMin) / rollSpan
			applyOptionGauge(optionGaugeA, lines[1].text, nil, nil, pRate, fillColor, lines[1].dim)
			applyOptionGauge(optionGaugeB, lines[2].text, nil, nil, pDmg, fillColor, lines[2].dim)
		else
			optionGaugeB.wrap.Visible = false
			local range = Option.rangeOf(optionId, item.grade, item.itemLevel, classId)
			local p = (item.option.roll - OptionData.rollMin) / rollSpan
			local accent = lines[1].accentClassId and UIColors.classAccent[lines[1].accentClassId] or nil
			applyOptionGauge(optionGaugeA, lines[1].text, ("%.1f"):format(range.min * 100), ("%.1f"):format(range.max * 100), p, fillColor, lines[1].dim, accent)
		end
	end
end
setupOptionRow()
-- ═══ 상세바 갱신 ═══


local function clearDetail()
	dname.Text = "선택된 아이템 없음"
	dname.TextColor3 = UIColors.textTertiary
	dmeta.Text = ""
	for _, child in ipairs(dpic:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	dpicStroke.Color = UIColors.rim
	dpicStroke.Transparency = UIColors.rimTransparency

	lockButton.AutoButtonColor = false
	lockButton.Active = false
	lockIconHolder.Visible = false
	sellButton.AutoButtonColor = false
	sellButton.Active = false
	sellButton.TextTransparency = 0.6
	dismantleButton.AutoButtonColor = false
	dismantleButton.Active = false
	dismantleButton.TextTransparency = 0.6
	equipButton.AutoButtonColor = false
	equipButton.Active = false
	equipButton.TextTransparency = 0.6
	equipButton.Text = "착용"
	refreshOptionRow(nil) -- 26-3 수정: optionRow는 이제 setupOptionRow 내부 전용이다.
	rerollDetailButton.Visible = false
	rerollDetailButton.AutoButtonColor = false
	rerollDetailButton.Active = false
end

local function setDpicIcon(partId, color)
	for _, child in ipairs(dpic:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local builder = ItemIcons.byPart[partId] or ItemIcons.byPart.armor
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	holder.Size = UDim2.new(0, 28, 0, 28)
	holder.BackgroundTransparency = 1
	holder.Parent = dpic
	builder(holder, 28, color)
end

-- 26-3: 리롤 버튼(Detail, bag·equip 전용 - gemSlot/gemBag은 보석 탭 자체 행 버튼이 이미
-- 있어 여기선 숨긴다, 중복 UI를 만들지 않는다는 지시). eligible이 아니면 숨긴다.
local function setRerollDetailButton(eligible, gradeId)
	rerollDetailButton.Visible = eligible ~= nil
	rerollDetailButton.AutoButtonColor = eligible == true
	rerollDetailButton.Active = eligible == true
	rerollDetailButton.TextTransparency = eligible and 0 or 0.6
	if eligible then
		local tickets = (S.gemState().rerollTickets and S.gemState().rerollTickets[gradeId]) or 0
		rerollDetailButton.Text = ("리롤(%d장)"):format(tickets)
	elseif eligible == false then
		rerollDetailButton.Text = "리롤"
	end
end

local function refreshDetailBody()
	if S.selectedKind == "bag" then
		local item = S.inventory[S.selectedValue]
		if not item then
			S.selectedKind, S.selectedValue = nil, nil
			clearDetail()
			return
		end
		local visual = ItemVisualData.gradeVisuals[item.grade]
		local color = visual and visual.color or UIColors.textPrimary
		local described = ItemDescribe.item(item, player:GetAttribute("ClassId"))
		dname.Text = described.title
		dname.TextColor3 = color
		dmeta.Text = ("%s · 판매가 %s"):format(described.meta, NumberFormat.format(Loot.getSellPrice(item)))
		setDpicIcon(item.part or "armor", color)
		dpicStroke.Color = color
		dpicStroke.Transparency = 0
		refreshOptionRow(item)

		lockButton.AutoButtonColor = true
		lockButton.Active = true
		lockIconHolder.Visible = true
		sellButton.AutoButtonColor = true
		sellButton.Active = true
		sellButton.TextTransparency = item.locked and 0.6 or 0
		local dismantleEligible = not item.locked and S.isDismantleEligibleGrade(item.grade)
		dismantleButton.AutoButtonColor = dismantleEligible
		dismantleButton.Active = dismantleEligible
		dismantleButton.TextTransparency = dismantleEligible and 0 or 0.6
		equipButton.AutoButtonColor = true
		equipButton.Active = true
		equipButton.TextTransparency = 0
		equipButton.Text = "착용"
		setRerollDetailButton(Gem.isRerollableGrade(item.grade), item.grade)
	elseif S.selectedKind == "equip" and S.selectedValue ~= "weapon" and S.equippedByPart()[S.selectedValue] then
		local part = S.selectedValue
		local item = S.equippedByPart()[part]
		local visual = ItemVisualData.gradeVisuals[item.grade]
		local color = visual and visual.color or UIColors.textPrimary
		local described = ItemDescribe.item(item, player:GetAttribute("ClassId"))
		dname.Text = described.title .. " (착용 중)"
		dname.TextColor3 = color
		dmeta.Text = described.meta
		setDpicIcon(item.part or part, color)
		dpicStroke.Color = color
		dpicStroke.Transparency = 0
		refreshOptionRow(item)

		lockButton.AutoButtonColor = false
		lockButton.Active = false
		lockIconHolder.Visible = false
		sellButton.AutoButtonColor = false
		sellButton.Active = false
		sellButton.TextTransparency = 0.6
		dismantleButton.AutoButtonColor = false
		dismantleButton.Active = false
		dismantleButton.TextTransparency = 0.6
		equipButton.AutoButtonColor = true
		equipButton.Active = true
		equipButton.TextTransparency = 0
		equipButton.Text = "해제"
		setRerollDetailButton(Gem.isRerollableGrade(item.grade), item.grade)
	elseif S.selectedKind == "equip" and S.selectedValue == "weapon" then
		local weaponLevel = player:GetAttribute("WeaponLevel") or 0
		local gradeId = S.weaponGradeId()
		local visual = gradeId and ItemVisualData.gradeVisuals[gradeId]
		local color = visual and visual.color or UIColors.textPrimary
		-- 이름에 등급을 붙인다(20-1 [2] 판단) - 갑옷·장갑·신발도 "등급 부위" 형식이라 무기만 색으로만 표시하면 이 창 안에서 두 가지 규칙이
		-- 섞인다. 강화 단계(+N)는 기존처럼 dmeta 줄에 그대로 둔다(부위별 레벨 표시와 동일). 문구는 ItemDescribe.weapon(S20).
		local described = ItemDescribe.weapon(gradeId, weaponLevel)
		dname.Text = described.title
		dname.TextColor3 = color
		dmeta.Text = described.meta .. " · 강화대에서 강화"
		setDpicIcon("weapon", color)
		dpicStroke.Color = color
		dpicStroke.Transparency = 0
		refreshOptionRow(nil) -- 무기는 옵션 개념이 없다(20.67 [1] - 무기는 강화만 대상).

		lockButton.AutoButtonColor = false
		lockButton.Active = false
		lockIconHolder.Visible = false
		sellButton.AutoButtonColor = false
		sellButton.Active = false
		sellButton.TextTransparency = 0.6
		dismantleButton.AutoButtonColor = false
		dismantleButton.Active = false
		dismantleButton.TextTransparency = 0.6
		equipButton.AutoButtonColor = false
		equipButton.Active = false
		equipButton.TextTransparency = 0.6
		equipButton.Text = "착용"
		setRerollDetailButton(nil)
	elseif S.selectedKind == "gemSlot" and type(S.selectedValue) == "number" and Gem.isFilled(S.gemState().gems, S.selectedValue) then
		local gem = S.gemState().gems[S.selectedValue]
		local visual = ItemVisualData.gradeVisuals[gem.grade]
		local color = visual and visual.color or UIColors.textPrimary
		dname.Text = ("%d번 홈 - %s"):format(S.selectedValue, ItemDescribe.gem(gem).title)
		dname.TextColor3 = color
		dmeta.Text = ("상한 %s"):format(ArmorData.grades[Gem.gradeCapForSlot(S.selectedValue)].displayName)
		setDpicIcon("weapon", color)
		dpicStroke.Color = color
		dpicStroke.Transparency = 0
		refreshOptionRow(gem)

		lockButton.AutoButtonColor = false
		lockButton.Active = false
		lockIconHolder.Visible = false
		sellButton.AutoButtonColor = false
		sellButton.Active = false
		sellButton.TextTransparency = 0.6
		dismantleButton.AutoButtonColor = false
		dismantleButton.Active = false
		dismantleButton.TextTransparency = 0.6
		equipButton.AutoButtonColor = false
		equipButton.Active = false
		equipButton.TextTransparency = 0.6
		equipButton.Text = "착용"
		setRerollDetailButton(nil) -- 이 슬롯의 리롤 버튼은 보석 탭 행 자체에 있다(중복 방지).
	elseif S.selectedKind == "gemBag" and type(S.selectedValue) == "number" and S.gemState().gemInventory[S.selectedValue] then
		local gem = S.gemState().gemInventory[S.selectedValue]
		local visual = ItemVisualData.gradeVisuals[gem.grade]
		local color = visual and visual.color or UIColors.textPrimary
		dname.Text = ItemDescribe.gem(gem).title
		dname.TextColor3 = color
		dmeta.Text = "보유 보석 - 드래그로 홈에 장착"
		setDpicIcon("weapon", color)
		dpicStroke.Color = color
		dpicStroke.Transparency = 0
		refreshOptionRow(gem)

		lockButton.AutoButtonColor = false
		lockButton.Active = false
		lockIconHolder.Visible = false
		sellButton.AutoButtonColor = false
		sellButton.Active = false
		sellButton.TextTransparency = 0.6
		dismantleButton.AutoButtonColor = false
		dismantleButton.Active = false
		dismantleButton.TextTransparency = 0.6
		equipButton.AutoButtonColor = false
		equipButton.Active = false
		equipButton.TextTransparency = 0.6
		equipButton.Text = "착용"
		setRerollDetailButton(nil)
	else
		clearDetail()
	end
end

lockButton.Activated:Connect(function()
	if S.selectedKind ~= "bag" then
		return
	end
	local item = S.inventory[S.selectedValue]
	if not item then
		return
	end
	lockRequest:FireServer(S.selectedValue, not item.locked)
end)

sellButton.Activated:Connect(function()
	if S.selectedKind ~= "bag" then
		return
	end
	local item = S.inventory[S.selectedValue]
	if not item or item.locked then
		return
	end
	sellRequest:FireServer("sell", S.selectedValue)
end)

dismantleButton.Activated:Connect(function()
	if S.selectedKind ~= "bag" then
		return
	end
	local item = S.inventory[S.selectedValue]
	if not item or item.locked or not S.isDismantleEligibleGrade(item.grade) then
		return
	end
	dismantleRequest:FireServer(S.selectedValue)
end)

equipButton.Activated:Connect(function()
	if S.selectedKind == "bag" then
		equipRequest:FireServer("equip", S.selectedValue)
	elseif S.selectedKind == "equip" and S.selectedValue ~= "weapon" then
		-- 16-6: 어느 부위를 벗을지 서버에 같이 알려야 한다(갑옷 하나였을 땐 필요 없었다).
		equipRequest:FireServer("unequip", S.selectedValue)
	end
end)

-- 26-3(PRD 20.67 [10]) - 가방·착용 장비 리롤. GemServer.server.lua의 (kind, key) 프로토콜
-- 그대로("bag"=인벤토리 index, "equipped"=부위명).
rerollDetailButton.Activated:Connect(function()
	if S.selectedKind == "bag" then
		gemRerollRequest:FireServer("bag", S.selectedValue)
	elseif S.selectedKind == "equip" and S.selectedValue ~= "weapon" then
		gemRerollRequest:FireServer("equipped", S.selectedValue)
	end
end)


-- 폰 시트: 선택이 없으면 숨는다(PC 바는 항상 보인다). refreshDetail이 끝날 때마다 다시 정한다.
local function applySheetVisibility()
	detail.Visible = S.mode ~= "phone" or S.selectedKind ~= nil
end

local function refreshDetail()
	refreshDetailBody()
	applySheetVisibility()
end
S.refreshDetail = refreshDetail

-- 시트 닫기(폰): 선택을 비운다. 가방 셀의 선택 테두리가 rebuildGrid에서 같이 꺼진다.
local sheetClose = Instance.new("TextButton")
sheetClose.Name = "SheetClose"
sheetClose.Text = ""
sheetClose.AutoButtonColor = false
sheetClose.BackgroundColor3 = UIColors.panel
sheetClose.BackgroundTransparency = UIColors.panelTransparency
sheetClose.Visible = false
sheetClose.Parent = detail
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = sheetClose
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Parent = sheetClose
	for _, rotation in ipairs({ 45, -45 }) do -- 헤더 닫기와 같은 X 모양(회전한 막대 2개)
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(0.5, 0, 0.5, 0)
		bar.Size = UDim2.new(0, 13, 0, 2)
		bar.Rotation = rotation
		bar.BackgroundColor3 = UIColors.textSecondary
		bar.BorderSizePixel = 0
		bar.Parent = sheetClose
	end
end
sheetClose.Activated:Connect(function()
	S.selectedKind, S.selectedValue = nil, nil
	S.rebuildGrid()
end)
R.sheetClose = sheetClose

-- 배치(S20b): PC = 원래 하단 바 · 폰 = 시트(넓으면 한 줄: 정보 + 버튼 + 닫기 · 좁으면 두 줄: 정보 위 · 버튼 아래). 버튼은 폰에서 높이 44 이상 · 폭 44 이상.
local actionButtons = { lockButton, sellButton, dismantleButton, equipButton, rerollDetailButton }
local ACTION_WIDTHS = { 36, 76, 60, 84, 70 }
local ACTION_GAP = 7
table.insert(R.layouts, function(L)
	local phone = L.mode == "phone"
	detail.Size = UDim2.new(1, 0, 0, L.detailH)
	local groupWidth = -ACTION_GAP
	for i, button in ipairs(actionButtons) do
		local width = phone and math.max(ACTION_WIDTHS[i], 44) or ACTION_WIDTHS[i]
		button.Size = UDim2.new(0, width, 0, L.actionH)
		groupWidth += width + ACTION_GAP
	end
	dact.Size = UDim2.new(0, 0, 0, L.actionH)
	sheetClose.Visible = phone
	sheetClose.Size = UDim2.new(0, 44, 0, 44)
	if not phone then
		dpic.AnchorPoint, dpic.Position, dpic.Size = Vector2.new(0, 0.5), UDim2.new(0, 0, 0.5, 0), UDim2.new(0, 56, 0, 56)
		dinfo.Position, dinfo.Size = UDim2.new(0, 70, 0, 0), UDim2.new(1, -260, 1, 0)
		dact.AnchorPoint, dact.Position = Vector2.new(1, 0.5), UDim2.new(1, 0, 0.5, 0)
	elseif L.sheetWide then
		dpic.AnchorPoint, dpic.Position, dpic.Size = Vector2.new(0, 0.5), UDim2.new(0, 0, 0.5, 0), UDim2.new(0, 48, 0, 48)
		dinfo.Position = UDim2.new(0, 60, 0, 0)
		dinfo.Size = UDim2.new(1, -(60 + groupWidth + 8 + 52), 1, 0)
		dact.AnchorPoint, dact.Position = Vector2.new(1, 0.5), UDim2.new(1, -52, 0.5, 0)
		sheetClose.AnchorPoint, sheetClose.Position = Vector2.new(1, 0.5), UDim2.new(1, 0, 0.5, 0)
	else
		dpic.AnchorPoint, dpic.Position, dpic.Size = Vector2.new(0, 0), UDim2.new(0, 0, 0, 8), UDim2.new(0, 48, 0, 48)
		dinfo.Position, dinfo.Size = UDim2.new(0, 60, 0, 0), UDim2.new(1, -(60 + 52), 0, 80)
		dact.AnchorPoint, dact.Position = Vector2.new(1, 1), UDim2.new(1, 0, 1, -8)
		sheetClose.AnchorPoint, sheetClose.Position = Vector2.new(1, 0), UDim2.new(1, 0, 0, 8)
	end
	applySheetVisibility()
end)
end

return DetailSheet
