local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EquipSlots = require(ReplicatedStorage.Shared.data.EquipSlots)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

-- 장비창 공용 상태 · 순수 계산(S20b: InventoryUI를 탭별 파일로 쪼개며 만들었다). 모든 탭 모듈이 이 표 S 하나로 서버 스냅샷 · 선택 · 정렬 상태를 나눈다.
-- 값 저장소이자 헬퍼 모음이다(창 · 칸을 만들지 않는다 - makeSectionLabel만 라벨 하나를 만들어 돌려주는 부품이다). 탭 모듈이 서로 부르는 함수(refreshDetail · refreshStats · rebuildGrid · rebuildGearSlots · gemState)는
-- 각자 정의한 뒤 S에 붙여 둔다(S.refreshDetail = ...) - 서로를 require하지 않는다.
local player = Players.LocalPlayer
local S = {}
S.player = player

-- 서버 상태(InventorySync가 미는 스냅샷 그대로 - 이 배열의 인덱스가 서버 인덱스다).
S.inventory = {}
S.equippedArmor = nil
S.equippedGloves = nil
S.equippedShoes = nil

-- 부위 이름 -> 지금 착용 중인 아이템(nil이면 미착용). rebuildGearSlots/refreshDetail이 armor/gloves/shoes를 하나씩 따로 취급하지 않고 이 표 하나로 조회한다(16-6).
function S.equippedByPart()
	return { armor = S.equippedArmor, gloves = S.equippedGloves, shoes = S.equippedShoes }
end

-- 부위 목록은 EquipSlots.lua 하나에서만 나온다(지시 - "UI가 부위 목록을 하드코딩하면 안 된다"). 장비 패널은 무기도 같이 보여주므로 그 앞에 하나만 덧붙인다 - 무기는
-- 드랍·장착 부위가 아니라서(EquipSlots.lua 주석) 거기 목록엔 없다.
local GEAR_ORDER = { "weapon" }
for _, part in ipairs(EquipSlots.order) do
	table.insert(GEAR_ORDER, part)
end
local PART_ORDER_INDEX = {}
for index, part in ipairs(GEAR_ORDER) do
	PART_ORDER_INDEX[part] = index
end
S.GEAR_ORDER, S.PART_ORDER_INDEX = GEAR_ORDER, PART_ORDER_INDEX

S.sortMode = "grade" -- "grade" | "level" | "part" - 클라 전용 표시 순서, 서버 왕복 없음.
S.SORT_MODES = { "grade", "level", "part" }
S.SORT_LABELS = { grade = "등급순", level = "레벨순", part = "부위순" }

-- 일괄판매 기준 등급 선택지(20-3) - ArmorData.gradeOrder에서 bulkSellMaxGrade까지만 잘라낸다(단일 출처 - 서버도 같은 두 값으로 같은 상한을 강제한다).
local BULK_SELL_GRADE_CHOICES = {}
for _, id in ipairs(ArmorData.gradeOrder) do
	table.insert(BULK_SELL_GRADE_CHOICES, id)
	if id == ArmorData.bulkSellMaxGrade then
		break
	end
end
S.BULK_SELL_GRADE_CHOICES = BULK_SELL_GRADE_CHOICES
-- 서버가 이미 골라 둔 값을 Attribute로 갖고 있으면(재접속) 그걸 초기값으로 쓴다 - 아직 안 왔으면 목록의 가장 낮은 등급으로 시작하고 Attribute가 오는 대로 BulkSell이 맞춘다.
S.bulkSellCutoffGrade = player:GetAttribute("BulkSellCutoffGrade") or BULK_SELL_GRADE_CHOICES[1]
S.bulkSellDropdownOpen = false

-- 선택 상태: kind="bag"이면 value=서버 인덱스, kind="equip"이면 value="weapon"/"armor", kind="gemSlot"이면 value=슬롯(1~5), kind="gemBag"이면 value=gemInventory 인덱스(26-3).
S.selectedKind, S.selectedValue = nil, nil
S.isOpen = false
S.rainbowGradients = {} -- 매 프레임 회전시켜야 하는 태초 등급 테두리 그라디언트 목록.
S.sheetInset = 0 -- 폰: 상세 시트가 올라와 있으면 그 높이(본문 프레임이 그만큼 짧아져 시트와 겹치지 않는다) · 아니면 0
S.mode = "pc" -- Layout.compute의 판정("pc" | "phone") - Shell.applyLayout이 매번 갱신한다.

-- 분해 가능 등급(23-2) - 서버(PlayerProfile.lua DISMANTLE_MIN_GRADE_INDEX)와 같은 문턱(영웅
-- 이상, ArmorData.gradeOrder index 3). 버튼을 활성화할지 미리 판단하는 표시용일 뿐 실제
-- 검증은 서버가 다시 한다(다른 등급 판정과 같은 원칙 - 클라이언트 값을 믿지 않는다).
local function isDismantleEligibleGrade(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i >= 3
		end
	end
	return false
end
S.isDismantleEligibleGrade = isDismantleEligibleGrade

local function makeSectionLabel(parent, text, y)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 14, 0, y)
	label.Size = UDim2.new(1, -28, 0, 14)
	label.Font = Enum.Font.GothamBold
	label.TextSize = Theme.textSize("caption") -- 16-6 [4]: 12px 미만 금지.
	label.TextColor3 = UIColors.textTertiary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end
S.makeSectionLabel = makeSectionLabel

-- ═══ 등급 시각 효과 ═══

-- 등급색 + 발광. 칸 배경은 등급과 무관하게 동일해야 하지만(지시 - "칸 내부 배경은 모든
-- 등급이 동일"), 5% 정도 등급색 쪽으로 당기면 색이 한눈에 더 잘 읽힌다(지시가 준 두
-- 대안 중 "더 간단한 쪽"을 골랐다 - 이중 UIStroke보다 셀 하나에 손대는 쪽이 20칸을
-- 한 번에 그릴 때 더 가볍다). 발광은 ItemVisualData.gradeVisuals.glowBrightness를 그대로
-- 재사용한다(14-1이 이미 정의해 둔 등급별 세기 - 여기서 새 숫자를 만들지 않는다).
local function blendToward(base, target, ratio)
	return Color3.new(
		base.R + (target.R - base.R) * ratio,
		base.G + (target.G - base.G) * ratio,
		base.B + (target.B - base.B) * ratio
	)
end

-- 태초(rainbow=true) 등급 테두리 - 여기서는 로블록스가 CSS보다 유리하다(지시). UIStroke에
-- UIGradient(무지개 ColorSequence)를 붙이고 매 프레임 Rotation을 돌리면 CSS conic-gradient
-- 정지 이미지보다 나은, 실제로 흐르는 테두리가 된다.
local RAINBOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(242, 196, 61)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(95, 211, 107)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(59, 209, 192)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(74, 158, 232)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(169, 123, 232)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 90)),
})

-- cellFrame에 등급 시각 효과를 입힌다. grade가 nil이면(빈 칸) 아무것도 하지 않는다 -
-- 호출부가 이미 점선 빈 칸 스타일을 따로 그렸다.
local function applyGradeVisual(cellFrame, gradeStroke, glowFrame, gradeId)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	if not visual then
		return
	end

	if visual.rainbow then
		gradeStroke.Color = Color3.new(1, 1, 1)
		gradeStroke.Transparency = 0
		local gradient = Instance.new("UIGradient")
		gradient.Color = RAINBOW_SEQUENCE
		gradient.Parent = gradeStroke
		table.insert(S.rainbowGradients, gradient)
		glowFrame.BackgroundTransparency = 0.8
		glowFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		return
	end

	gradeStroke.Color = visual.color
	gradeStroke.Transparency = 0
	cellFrame.BackgroundColor3 = blendToward(UIColors.slot, visual.color, 0.05)

	if gradeId ~= "normal" then
		glowFrame.BackgroundColor3 = visual.color
		glowFrame.BackgroundTransparency = math.clamp(1 - (visual.glowBrightness / 5) * 0.6, 0.4, 0.95)
	end
end
S.applyGradeVisual = applyGradeVisual

-- 정렬은 표시 순서만 바꾼다 - {item, serverIndex} 짝을 유지해서 서버 인덱스는 항상
-- 원본 그대로 남긴다(사용자 지시: "실제 인스턴스를 훑어라" 원칙과 같은 이유로, 표시
-- 순서와 서버 진실을 섞으면 나중에 반드시 잠금/판매가 엉뚱한 칸에 걸리는 버그가 난다).
local function sortedEntries()
	local entries = {}
	for i, item in ipairs(S.inventory) do
		table.insert(entries, { item = item, index = i })
	end

	if S.sortMode == "grade" then
		table.sort(entries, function(a, b)
			local ai, bi = 0, 0
			for i, id in ipairs(ArmorData.gradeOrder) do
				if id == a.item.grade then ai = i end
				if id == b.item.grade then bi = i end
			end
			return ai > bi
		end)
	elseif S.sortMode == "level" then
		table.sort(entries, function(a, b)
			return a.item.itemLevel > b.item.itemLevel
		end)
	elseif S.sortMode == "part" then
		table.sort(entries, function(a, b)
			local ap = PART_ORDER_INDEX[a.item.part or "armor"] or 99
			local bp = PART_ORDER_INDEX[b.item.part or "armor"] or 99
			return ap < bp
		end)
	end

	return entries
end

local function isSellableGrade(gradeId, cutoffId)
	local cutoffIndex
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == cutoffId then
			cutoffIndex = i
		end
	end
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return cutoffIndex ~= nil and i <= cutoffIndex
		end
	end
	return false
end

-- 반환값에 highestSoldGradeId를 더했다(20-3) - 확인창이 "대상에 포함된 최고 등급"을
-- 이름·색으로 보여주려면 기준 등급(S.bulkSellCutoffGrade)이 아니라 실제로 팔릴 아이템 중
-- 가장 높은 등급을 알아야 한다(인벤토리에 그 기준보다 낮은 등급만 있을 수도 있다).
local function bulkSellEstimate()
	local count, total = 0, 0
	local highestSoldGradeId, highestSoldGradeIndex = nil, 0
	for _, item in ipairs(S.inventory) do
		if not item.locked and isSellableGrade(item.grade, S.bulkSellCutoffGrade) then
			count += 1
			total += Loot.getSellPrice(item)
			for i, id in ipairs(ArmorData.gradeOrder) do
				if id == item.grade and i > highestSoldGradeIndex then
					highestSoldGradeId, highestSoldGradeIndex = id, i
				end
			end
		end
	end
	return count, total, highestSoldGradeId
end
S.sortedEntries, S.bulkSellEstimate = sortedEntries, bulkSellEstimate

-- 무기 등급(20-1) - 저장이 아니라 Attribute(WeaponGrade, 0~6)로만 온다. ArmorData.gradeOrder로
-- index->id를 찾는다(등급 데이터의 단일 출처).
local function weaponGradeId()
	local grade = player:GetAttribute("WeaponGrade") or 0
	return ArmorData.gradeOrder[grade + 1]
end
S.weaponGradeId = weaponGradeId

return S
