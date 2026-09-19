-- 강화 패널의 상태 · Remote(28-1 S07, PRD 20.72 [1-8]). 화면은 여기서 만든 state를 그리기만 한다 - 서버 상태의 진실을 갖지 않는다(Attribute · Remote 응답만 읽는다).
-- 확률표는 Enhance.getOutcomeTable(= 서버 판정과 같은 함수)에서 나온다 - 이 파일에도 확률 숫자는 없다.
-- state = { level, gradeName, gold, gauge, gaugeMax, gaugeFull, gaugeGain, maxed, cost, material = { id, name, need, have } | nil, outcomes, canAfford, shortReason }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local Confirm = require(script.Parent.Parent.Parent.ui.kit.Confirm)

local Controller = {}

local player = Players.LocalPlayer
local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
local enhanceRequest = ReplicatedStorage:WaitForChild("EnhanceRequest")
local enhanceResult = ReplicatedStorage:WaitForChild("EnhanceResult")

local confirmedZones = {} -- "drop" / "reset" -> true(이 세션에서 그 구간 진입 확인을 이미 봤다 - "다시 보지 않기"는 없고 구간당 세션 1회)

-- 서버 PlayerProfile의 재료 Attribute 이름과 같은 규칙: "Material" + 재료 id의 첫 글자를 대문자로.
local function materialAttributeName(materialId)
	return "Material" .. materialId:sub(1, 1):upper() .. materialId:sub(2)
end

-- 이 패널이 읽는 Attribute 이름 전부(바뀌면 화면을 다시 그린다).
function Controller.attributeNames()
	local names = { "WeaponLevel", "WeaponGrade", "Gold", "EnhanceGauge" }
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		table.insert(names, materialAttributeName(materialId))
	end
	return names
end

local function gradeDisplayName()
	local grade = player:GetAttribute("WeaponGrade") or 0
	local gradeId = ArmorData.gradeOrder[grade + 1]
	local gradeInfo = gradeId and ArmorData.grades[gradeId]
	return gradeInfo and gradeInfo.displayName or "일반"
end

function Controller.getState()
	local level = player:GetAttribute("WeaponLevel") or 0
	local gold = player:GetAttribute("Gold") or 0
	local gauge = player:GetAttribute("EnhanceGauge") or 0
	local gaugeMax = EnhanceConfig.gauge.max
	local gaugeFull = gauge >= gaugeMax
	local cost = Enhance.getCost(level)

	local state = {
		level = level,
		gradeName = gradeDisplayName(),
		gold = gold,
		gauge = gauge,
		gaugeMax = gaugeMax,
		gaugeFull = gaugeFull,
		gaugeGain = Enhance.getGaugeGain(level),
		maxed = cost == nil,
		cost = cost,
		outcomes = Enhance.getOutcomeTable(level, gaugeFull, false, false),
		canAfford = true,
	}

	local materialCost = EnhanceMaterialData.costByLevel[level]
	if cost and materialCost then
		local material = EnhanceMaterialData.materials[materialCost.id]
		state.material = {
			id = materialCost.id,
			name = material and material.displayName or materialCost.id,
			need = materialCost.count,
			have = player:GetAttribute(materialAttributeName(materialCost.id)) or 0,
		}
	end

	-- 버튼 비활성 이유(서버가 다시 검증한다 - 화면 안내일 뿐이다). 검사 순서는 서버와 같다: 골드 → 재료.
	if cost and gold < cost then
		state.canAfford = false
		state.shortReason = "골드가 부족합니다"
	elseif state.material and state.material.have < state.material.need then
		state.canAfford = false
		state.shortReason = ("%s이 부족합니다"):format(state.material.name)
	end
	return state
end

-- 강화대까지의 거리가 상호작용 범위 안인가(서버 isNearStation과 같은 값).
function Controller.isNear()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	return (root.Position - stationPosition).Magnitude <= WorldConfig.enhance.interactionRangeStuds
end

-- 결과 payload를 받는 쪽을 등록한다(반환: 연결 - 다시 지을 때 끊는다).
function Controller.connectResult(handler)
	return enhanceResult.OnClientEvent:Connect(handler)
end

-- 구간 진입 확인창의 문구. 숫자(18 · 12 · 1%)는 확률표 · EnhanceConfig에서 읽는다. formatPercent는 화면과 같은 표기(OddsView)를 받는다.
local function zoneConfirmBody(zone, level, formatPercent)
	if zone == "drop" then
		return ("여기서부터 실패하면 단계가 내려갈 수 있습니다(최악 %d강)"):format(Enhance.getWorstLevel(level))
	end
	local outcomes = Enhance.getOutcomeTable(level, false, false, false)
	return ("여기서부터 실패하면 %d강으로 초기화될 수 있습니다(%s)"):format(EnhanceConfig.resetToLevel, formatPercent(outcomes.reset))
end

-- 강화를 요청한다. 위험 구간이 시작되는 단계(19 · 22강)의 그 세션 첫 시도에는 확인창을 한 번 띄우고, 확인해야 서버로 보낸다(취소하면 아무 일도 없다).
-- 요청 인자(방지권 토글 2개)는 아직 안 쓴다 - 서버가 없으면 false로 본다.
function Controller.requestEnhance(parentId, formatPercent)
	local state = Controller.getState()
	if state.maxed then
		return
	end
	local dropFrom, resetFrom = Enhance.getRiskStartLevels()
	local zone = (state.level == resetFrom and "reset") or (state.level == dropFrom and "drop") or nil
	if not zone or confirmedZones[zone] then
		enhanceRequest:FireServer()
		return
	end
	Confirm.ask({
		title = "위험 구간 진입",
		body = zoneConfirmBody(zone, state.level, formatPercent),
		primaryText = "강화",
		secondaryText = "취소",
		parentId = parentId,
	}, function(accepted)
		if accepted then
			confirmedZones[zone] = true
			enhanceRequest:FireServer()
		end
	end)
end

return Controller
