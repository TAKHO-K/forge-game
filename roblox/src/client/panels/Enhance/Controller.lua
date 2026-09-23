-- 강화 패널의 상태 · Remote(28-1 S07, PRD 20.72 [1-8]). 화면은 여기서 만든 state를 그리기만 한다 - 서버 상태의 진실을 갖지 않는다(Attribute · Remote 응답만 읽는다).
-- 확률표는 Enhance.getOutcomeTable(= 서버 판정과 같은 함수)에서 나온다 - 이 파일에도 확률 숫자는 없다.
-- state = { level, gradeName, gold, gauge, gaugeMax, gaugeFull, gaugeGain, maxed, cost, material = { id, name, need, have } | nil, outcomes, worstLevel,
--   tickets = { drop = { name, have, want, enabled, reason }, reset = ... }, canAfford, shortReason }.
-- 방지권 토글은 이 파일이 기억한다(toggles) - 표(outcomes)는 서버가 쓰는 함수(resolveProtectionFlags)로 거른 뒤의 플래그로 그린다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Confirm = require(script.Parent.Parent.Parent.ui.kit.Confirm)

local Controller = {}

local player = Players.LocalPlayer
local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
local enhanceRequest = ReplicatedStorage:WaitForChild("EnhanceRequest")
local enhanceResult = ReplicatedStorage:WaitForChild("EnhanceResult")
local ticketBuyRequest = ReplicatedStorage:WaitForChild("ProtectionTicketBuyRequest")
local ticketBuyResult = ReplicatedStorage:WaitForChild("ProtectionTicketBuyResult")
local ticketPriceRequest = ReplicatedStorage:WaitForChild("ProtectionTicketPriceRequest")

-- 방지권 종류(서버 PlayerProfile · ProtectionTickets와 같은 순서 · 이름).
Controller.ticketKinds = { "drop", "reset" }
local toggles = { drop = false, reset = false } -- 클라가 기억하는 토글(요청에 싣는다 - 서버가 다시 검증한다)

local confirmedZones = {} -- "drop" / "reset" -> true(이 세션에서 그 구간 진입 확인을 이미 봤다 - "다시 보지 않기"는 없고 구간당 세션 1회)

-- 서버 PlayerProfile의 재료 Attribute 이름과 같은 규칙: "Material" + 재료 id의 첫 글자를 대문자로.
local function materialAttributeName(materialId)
	return "Material" .. materialId:sub(1, 1):upper() .. materialId:sub(2)
end

-- 서버 PlayerProfile의 방지권 Attribute 이름과 같은 규칙: "Protection" + 종류의 첫 글자를 대문자로(ProtectionDrop · ProtectionReset).
local function ticketAttributeName(kind)
	return "Protection" .. kind:sub(1, 1):upper() .. kind:sub(2)
end

-- 이 패널이 읽는 Attribute 이름 전부(바뀌면 화면을 다시 그린다).
function Controller.attributeNames()
	local names = { "WeaponLevel", "WeaponGrade", "Gold", "EnhanceGauge" }
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		table.insert(names, materialAttributeName(materialId))
	end
	for _, kind in ipairs(Controller.ticketKinds) do
		table.insert(names, ticketAttributeName(kind))
	end
	return names
end

function Controller.setToggle(kind, value)
	toggles[kind] = value == true
end

-- 방지권 한 종류의 토글 상태. 비활성 이유는 보유 0 → 사용 불가 구간 → 불씨 가득 순(같은 조건을 서버 resolveProtectionFlags가 다시 본다).
local function ticketState(kind, level, gaugeFull, maxed)
	local config = EnhanceConfig.protection[kind]
	local have = player:GetAttribute(ticketAttributeName(kind)) or 0
	local reason
	if maxed then
		reason = "최대 강화 단계입니다"
	elseif have < 1 then
		reason = "보유한 방지권이 없습니다"
	elseif level < config.usableFromLevel then
		reason = ("%d강부터 쓸 수 있습니다"):format(config.usableFromLevel)
	elseif gaugeFull then
		reason = "불씨가 가득 차 필요 없습니다"
	end
	return { name = config.displayName, have = have, want = toggles[kind], enabled = reason == nil, reason = reason }
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
	local cost = Enhance.getCost(level, player:GetAttribute("AccountBestStage") or 1) -- P2 C1: 서버(EnhanceService)와 같은 기준 스테이지

	local haveDrop = player:GetAttribute(ticketAttributeName("drop")) or 0
	local haveReset = player:GetAttribute(ticketAttributeName("reset")) or 0
	local useDrop, useReset = Enhance.resolveProtectionFlags(level, gaugeFull, toggles.drop, toggles.reset, haveDrop, haveReset)
	local outcomes = Enhance.getOutcomeTable(level, gaugeFull, useDrop, useReset)

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
		outcomes = outcomes,
		worstLevel = outcomes and Enhance.getWorstLevel(level, outcomes),
		tickets = {},
		canAfford = true,
	}
	for _, kind in ipairs(Controller.ticketKinds) do
		state.tickets[kind] = ticketState(kind, level, gaugeFull, cost == nil)
	end

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

-- 서버로 보내는 요청 - 인자는 방지권 토글 2개뿐이다(서버 EnhanceService가 보유 · 구간 · 불씨를 다시 검증해 안 되는 것만 조용히 뗀다).
local function fireEnhance()
	enhanceRequest:FireServer(toggles.drop, toggles.reset)
end

-- 강화를 요청한다. 위험 구간이 시작되는 단계(19 · 22강)의 그 세션 첫 시도에는 확인창을 한 번 띄우고, 확인해야 서버로 보낸다(취소하면 아무 일도 없다).
function Controller.requestEnhance(parentId, formatPercent)
	local state = Controller.getState()
	if state.maxed then
		return
	end
	local dropFrom, resetFrom = Enhance.getRiskStartLevels()
	local zone = (state.level == resetFrom and "reset") or (state.level == dropFrom and "drop") or nil
	if not zone or confirmedZones[zone] then
		fireEnhance()
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
			fireEnhance()
		end
	end)
end

-- 방지권 구매 결과(ok, kind, price 또는 reason, tickets)를 받는 쪽을 등록한다(반환: 연결).
function Controller.connectBuyResult(handler)
	return ticketBuyResult.OnClientEvent:Connect(handler)
end

-- [구매]를 눌렀다: 서버에서 가격(계정 최고 스테이지 기준)을 받아 확인창을 띄운다. 가격 · 차감 · 근접 확인은 서버가 다시 한다(ProtectionTickets.tryBuy) - 여기엔 가격 숫자가 없다.
-- 골드가 모자라면 [구매]를 비활성하고 이유를 적는다. 확인해야 구매 요청을 보낸다.
function Controller.requestBuy(kind, parentId)
	task.spawn(function()
		local ok, prices = pcall(function()
			return ticketPriceRequest:InvokeServer()
		end)
		if not ok or type(prices) ~= "table" or not prices[kind] then
			return
		end
		local config = EnhanceConfig.protection[kind]
		local price = prices[kind]
		local gold = player:GetAttribute("Gold") or 0
		local canAfford = gold >= price
		Confirm.ask({
			title = config.displayName .. " 구매",
			body = ("%s 1장\n가격 %s 골드 · 보유 %s\n(계정 최고 스테이지 %d 기준 잡몹 %d마리분)"):format(
				config.displayName, NumberFormat.format(price), NumberFormat.format(gold), prices.accountBestStage, config.priceKillEquivalent),
			primaryText = "구매",
			secondaryText = "취소",
			parentId = parentId,
			primaryEnabled = canAfford,
			reason = (not canAfford) and ("골드가 부족합니다 (%s 더 필요)"):format(NumberFormat.format(price - gold)) or nil,
		}, function(accepted)
			if accepted then
				ticketBuyRequest:FireServer(kind)
			end
		end)
	end)
end

return Controller
