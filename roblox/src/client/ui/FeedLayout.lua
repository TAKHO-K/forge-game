-- 드랍 피드 자리 계산(30-0 S10 보완, 사용자 결정 2026-09-20 - PRD 20.93 미결 1 · 2 닫음).
-- 피드 줄 수 = 칩 스택 아래 끝 ~ 그 아래 첫 HUD(가방 버튼 · 투표 패널 · 모바일 터치 구역 · 중앙 금지 구역) 위 끝 사이에 들어가는 줄 수(최대 3). 창 크기가 바뀌거나
-- 칩 · 투표 패널이 생기고 사라질 때마다 다시 잰다(bind가 그 인스턴스들의 크기 · 위치 · Visible을 감시한다). 0줄이면 화면 상단 가운데 띠(1줄)로 옮긴다 -
-- 태초 배너가 떠 있으면 배너 바로 아래.
-- 무엇이 "피드를 막는 HUD"인지는 이 파일이 아니라 ScreenMap 슬롯의 blocksDropFeed 표시가 정한다(HUD가 늘면 표에 표시만 한다).
-- 이 파일은 좌표만 계산한다 - 줄을 세우고 밀어내는 일은 Toast가 한다.

local Players = game:GetService("Players")

local ScreenMap = require(script.Parent.ScreenMap)
local Theme = require(script.Parent.kit.Theme)

local FeedLayout = {}

-- 순수 함수: top(피드의 위 끝 y) · left ~ right(피드의 가로 범위)에서 아래로 rowHeight짜리 줄이 gap 간격으로 몇 줄 들어가는가(0 ~ maxRows).
-- blockers = { { min = Vector2, max = Vector2 }, ... }. 가로가 안 겹치거나 이미 지나간(아래 끝이 top 이상이 아닌) 것은 무시한다.
-- top이 어떤 blocker 안에 있으면(위 끝 <= top < 아래 끝) 그 blocker의 위 끝이 top 이하라 0줄이다.
function FeedLayout.fitRows(top, left, right, rowHeight, gap, maxRows, blockers)
	local limit = math.huge
	for _, rect in ipairs(blockers) do
		if rect.min.X < right and left < rect.max.X and rect.max.Y > top then
			limit = math.min(limit, rect.min.Y)
		end
	end
	local rows = math.floor((limit - top + gap) / (rowHeight + gap))
	return math.clamp(rows, 0, maxRows)
end

local cache = {} -- 이름 -> 인스턴스(한 번 찾으면 재사용 - 가방 창은 자손이 수백 개라 매번 FindFirstChild(재귀)를 하지 않는다)

local function locate(root, name)
	local inst = cache[name]
	if inst and inst.Parent then
		return inst
	end
	inst = root:FindFirstChild(name, true)
	cache[name] = inst
	return inst
end

local function isShown(inst)
	local node = inst
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

local function rectOf(inst)
	return { min = inst.AbsolutePosition, max = inst.AbsolutePosition + inst.AbsoluteSize }
end

-- 피드가 피해야 하는 자리들(label 포함 - 검사 · 로그용). screen = ScreenGui 크기(Vector2).
function FeedLayout.blockers(root, screen)
	local list = {}
	for zone, name, slot in ScreenMap.each() do
		if slot.blocksDropFeed then
			local inst = locate(root, slot.instanceName)
			if inst and isShown(inst) and inst.AbsoluteSize.X > 0 and inst.AbsoluteSize.Y > 0 then
				local rect = rectOf(inst)
				rect.label = zone .. "." .. name
				table.insert(list, rect)
			end
		end
	end
	if Theme.isMobile then
		for zone, fractions in pairs(ScreenMap.mobileReserved) do
			local rect = ScreenMap.rectFromFractions(fractions, screen)
			rect.label = "터치 " .. zone
			table.insert(list, rect)
		end
	end
	local center = ScreenMap.centerRect(screen)
	center.label = "중앙 금지 구역"
	table.insert(list, center)
	table.insert(list, { min = Vector2.new(0, screen.Y), max = Vector2.new(screen.X, screen.Y + 1), label = "화면 아래" })
	return list
end

-- 지금 피드가 놓일 자리. spec = { rowHeight, gap, maxRows, bannerBottom(태초 배너가 떠 있으면 그 아래 끝 y, 없으면 nil) }.
-- 반환 { rows, strip, anchor, position }: strip = true면 상단 가운데 띠(rows = 1).
function FeedLayout.measure(root, screen, spec)
	local slot = ScreenMap.slot("TR", "dropFeed")
	local chipSlot = ScreenMap.slot(slot.below.zone, slot.below.slot)
	local chips = locate(root, chipSlot.instanceName)
	local top = slot.position.Y.Offset -- 칩이 0개일 때의 자리
	if chips and chips.AbsoluteSize.Y > 0 then
		top = chips.AbsolutePosition.Y + chips.AbsoluteSize.Y + slot.below.gap
	end
	local right = screen.X * slot.position.X.Scale + slot.position.X.Offset
	local left = right - slot.size.X.Offset
	local rows = FeedLayout.fitRows(top, left, right, spec.rowHeight, spec.gap, spec.maxRows, FeedLayout.blockers(root, screen))
	if rows > 0 then
		return { rows = rows, strip = false, anchor = slot.anchor, position = UDim2.new(slot.position.X.Scale, slot.position.X.Offset, 0, top) }
	end
	local strip = ScreenMap.slot(slot.fallback.zone, slot.fallback.slot)
	local y = strip.position.Y.Offset
	if spec.bannerBottom then
		y = spec.bannerBottom + slot.fallback.gap
	end
	return { rows = 1, strip = true, anchor = strip.anchor, position = UDim2.new(strip.position.X.Scale, strip.position.X.Offset, 0, y) }
end

-- 칩 스택 · 막는 HUD · 화면 크기가 바뀔 때마다 onChange()를 부른다. 아직 없는 인스턴스는 생기는 순간 붙는다.
function FeedLayout.bind(root, gui, onChange)
	local slot = ScreenMap.slot("TR", "dropFeed")
	local names = { [ScreenMap.slot(slot.below.zone, slot.below.slot).instanceName] = true }
	for _zone, _name, other in ScreenMap.each() do
		if other.blocksDropFeed then
			names[other.instanceName] = true
		end
	end

	local function watch(inst)
		for _, property in ipairs({ "AbsoluteSize", "AbsolutePosition", "Visible" }) do
			inst:GetPropertyChangedSignal(property):Connect(onChange)
		end
	end
	local pending = {}
	for name in pairs(names) do
		local inst = locate(root, name)
		if inst then
			watch(inst)
		else
			pending[name] = true
		end
	end
	if next(pending) then
		local connection
		connection = root.DescendantAdded:Connect(function(added)
			if pending[added.Name] and added:IsA("GuiObject") then
				pending[added.Name] = nil
				cache[added.Name] = added
				watch(added)
				onChange()
				if not next(pending) then
					connection:Disconnect()
				end
			end
		end)
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(onChange)
	-- Studio에서 ForceTouchLayout(폰 흉내)이 바뀌면 터치 구역이 달라진다.
	Players.LocalPlayer:GetAttributeChangedSignal("ForceTouchLayout"):Connect(function()
		Theme.recompute()
		onChange()
	end)
end

return FeedLayout
