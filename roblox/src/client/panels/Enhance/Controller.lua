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
local Text = require(ReplicatedStorage.Shared.Text)
local Confirm = require(script.Parent.Parent.Parent.ui.kit.Confirm)

local Controller = {}

local player = Players.LocalPlayer
local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
local enhanceRequest = ReplicatedStorage:WaitForChild("EnhanceRequest")
local enhanceResult = ReplicatedStorage:WaitForChild("EnhanceResult")
-- 방지 옵션 줄(QUEUE-ALL9B G - 사용자 10-03: 방지권 폐지 → 강화 창 "하락 방지" · "초기화 방지" 켜기/끄기 · 켜면 그 시도 비용 = 기본 × k(골드만)).
Controller.ticketKinds = { "drop", "reset" }
local toggles = { drop = false, reset = false } -- 클라가 기억하는 토글(요청에 싣는다 - 서버가 다시 검증한다)

local confirmedZones = {} -- "drop" / "reset" -> true(이 세션에서 그 구간 진입 확인을 이미 봤다 - "다시 보지 않기"는 없고 구간당 세션 1회)

-- 서버 PlayerProfile의 재료 Attribute 이름과 같은 규칙: "Material" + 재료 id의 첫 글자를 대문자로.
local function materialAttributeName(materialId)
	return "Material" .. materialId:sub(1, 1):upper() .. materialId:sub(2)
end

-- 이 패널이 읽는 Attribute 이름 전부(바뀌면 화면을 다시 그린다).
function Controller.attributeNames()
	local names = { "WeaponLevel", "WeaponGrade", "Gold", "EnhanceGauge", "AccountBestStage" } -- P2 C1: 강화 비용이 계정 최고 스테이지를 따른다
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		table.insert(names, materialAttributeName(materialId))
	end
	return names
end

function Controller.setToggle(kind, value)
	toggles[kind] = value == true
end

-- 이 방지(kind)를 켤 수 있는 첫 단계(guardBands에서) - 안내 문구용.
local function firstGuardLevel(kind)
	for _, band in ipairs(EnhanceConfig.guardBands) do
		if band.guards[kind] then
			return band.fromLevel
		end
	end
	return EnhanceConfig.maxLevel
end

-- 방지 옵션 한 줄의 상태. 비활성 이유 = 상한 → 이 단계 구간에 그 방지가 없음(+19 전 · +26 이상 하락) → 불씨 가득(같은 조건을 서버 resolveProtectionFlags가 다시 본다).
local function optionState(kind, level, gaugeFull, maxed)
	local band = Enhance.getGuardBand(level)
	local reason
	if maxed then
		reason = Text.get("forge.err.maxed")
	elseif not band or not band.guards[kind] then
		local from = firstGuardLevel(kind)
		reason = level < from and Text.get("forge.enhance.ticket.fromLevel", { level = ("%d"):format(from) })
			or Text.get("forge.enhance.guard.noDrop", { level = ("%d"):format(level) })
	elseif gaugeFull then
		reason = Text.get("forge.enhance.ticket.gaugeFull")
	end
	local k = band and band.guards[kind] and band.costMultiplier
	return { label = Text.get(kind == "drop" and "forge.enhance.guard.dropToggle" or "forge.enhance.guard.toggle", { k = k and ("%.1f"):format(k) or "-" }),
		want = toggles[kind], enabled = reason == nil, reason = reason }
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
	local stage = player:GetAttribute("AccountBestStage") or 1 -- P2 C1: 서버(EnhanceService)와 같은 기준 스테이지

	local useDrop, useReset = Enhance.resolveProtectionFlags(level, gaugeFull, toggles.drop, toggles.reset)
	local outcomes = Enhance.getOutcomeTable(level, gaugeFull, useDrop, useReset)
	local cost = Enhance.getCost(level, stage, useDrop, useReset) -- QUEUE-ALL9B G: 방지 켬 = 기본 × k
	local band = Enhance.getGuardBand(level)

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
		-- QUEUE-ALL9B G: 방지 구간 = 이번 시도 비용(방지 끔 · 켬) · 초기화 확률(방지 없는 표)
		guardInfo = band and {
			off = Enhance.getCost(level, stage, false, false), on = Enhance.getCost(level, stage, band.guards.drop, band.guards.reset),
			resetChance = Enhance.getOutcomeTable(level, false, false, false).reset,
		} or nil,
	}
	for _, kind in ipairs(Controller.ticketKinds) do
		state.tickets[kind] = optionState(kind, level, gaugeFull, cost == nil)
	end

	local materialCost = EnhanceMaterialData.costByLevel[level]
	if cost and materialCost then
		local material = EnhanceMaterialData.materials[materialCost.id]
		state.material = {
			id = materialCost.id,
			name = material and Text.name(material.displayName) or materialCost.id,
			need = materialCost.count,
			have = player:GetAttribute(materialAttributeName(materialCost.id)) or 0,
		}
	end

	-- 버튼 비활성 이유(서버가 다시 검증한다 - 화면 안내일 뿐이다). 검사 순서는 서버와 같다: 골드 → 재료.
	if cost and gold < cost then
		state.canAfford = false
		state.shortReason = Text.get("forge.err.noGold")
	elseif state.material and state.material.have < state.material.need then
		state.canAfford = false
		state.shortReason = Text.get("forge.enhance.short.material", { name = state.material.name })
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
		return Text.get("forge.enhance.zone.drop", { level = ("%d"):format(Enhance.getWorstLevel(level)) })
	end
	local outcomes = Enhance.getOutcomeTable(level, false, false, false)
	return Text.get("forge.enhance.zone.reset", { level = ("%d"):format(Enhance.getResetToLevel(level) or level), chance = formatPercent(outcomes.reset) }) -- QUEUE-ALL9B G1
end

-- 서버로 보내는 요청 - 인자는 방지권 토글 2개뿐이다(서버 EnhanceService가 보유 · 구간 · 불씨를 다시 검증해 안 되는 것만 조용히 뗀다).
local function fireEnhance()
	enhanceRequest:FireServer(toggles.drop, toggles.reset) -- QUEUE-ALL9B G: 하락 · 초기화 방지 옵션
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
		title = Text.get("forge.enhance.zone.title"),
		body = zoneConfirmBody(zone, state.level, formatPercent),
		primaryText = Text.get("forge.enhance.button"),
		secondaryText = Text.get("forge.cancel"),
		parentId = parentId,
	}, function(accepted)
		if accepted then
			confirmedZones[zone] = true
			fireEnhance()
		end
	end)
end

return Controller
