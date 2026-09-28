-- QUEUE-10h Q15 T1 통계 모듈(서버 전용). 데이터 = shared/data/TelemetryData.lua.
--   Telemetry.economy(player, currencyKey, flow "source" | "sink", amount, transaction) · custom(player, name, value) · funnel(player, stepName) - 부르는 곳은 한 줄씩.
--   누적 → flushSeconds마다 · 퇴장 때 전송. Studio(dryRunInStudio) = AnalyticsService를 부르지 않고 [T1] 드라이런 로그.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TelemetryData = require(ReplicatedStorage.Shared.data.TelemetryData)

local Telemetry = {}

local pending = {} -- [Player] = { economy = { [key] = { currency, flow, tx, amount } }, custom = { [name] = value } }
local stats = { economy = 0, custom = 0, funnel = 0, flushes = 0 } -- 검증 · 드라이런 요약
Telemetry.stats = stats

local function dryRun()
	return TelemetryData.dryRunInStudio and RunService:IsStudio()
end

-- 사람 단위 고정 표본(userId 해시 - 같은 사람은 늘 같은 결과)
function Telemetry.sampled(userId, rate)
	if rate >= 1 then
		return true
	end
	local h = (math.abs(math.floor(tonumber(userId) or 0)) * 2654435761) % 4294967296
	return (h % 10000) / 10000 < rate
end

local function allowed(player, category)
	local c = TelemetryData.categories[category]
	return TelemetryData.enabled and c and c.enabled and typeof(player) == "Instance" and Telemetry.sampled(player.UserId, c.sample)
end

local function bucket(value, edges)
	local label = tostring(edges[1])
	for _, edge in ipairs(edges) do
		if (value or 0) >= edge then
			label = tostring(edge)
		end
	end
	return label .. "+"
end
Telemetry.bucket = bucket

-- 커스텀 필드 3(구간값만): 스테이지 구간 · 직업 · 환생 구간
function Telemetry.fields(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local stage = PlayerProfile.getAccountBestStage and PlayerProfile.getAccountBestStage(player) or 1
	local classId = PlayerProfile.getClassId(player) or "none"
	local rebirth = 0
	local facts = PlayerProfile.getQuestFacts and PlayerProfile.getQuestFacts(player)
	if facts and facts.rebirth then
		rebirth = facts.rebirth
	end
	return {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = "stage_" .. bucket(stage, TelemetryData.stageBuckets),
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = "class_" .. classId,
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = "rebirth_" .. bucket(rebirth, TelemetryData.rebirthBuckets),
	}
end

function Telemetry.economy(player, currencyKey, flow, amount, transaction)
	if not allowed(player, "economy") or not TelemetryData.currencies[currencyKey] or type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return
	end
	local p = pending[player] or { economy = {}, custom = {} }
	pending[player] = p
	local key = currencyKey .. "|" .. flow .. "|" .. (transaction or "Gameplay")
	local e = p.economy[key] or { currency = currencyKey, flow = flow, tx = transaction or "Gameplay", amount = 0 }
	e.amount += amount
	p.economy[key] = e
end

function Telemetry.custom(player, name, value)
	if not allowed(player, "custom") or type(name) ~= "string" then
		return
	end
	local p = pending[player] or { economy = {}, custom = {} }
	pending[player] = p
	p.custom[name] = value
end

-- 온보딩 퍼널: 바로 보낸다(사람당 단계마다 한 번 - QuestData.ftue가 한 번씩만 부른다)
function Telemetry.funnel(player, stepName)
	if not allowed(player, "funnel") then
		return
	end
	local step = table.find(TelemetryData.funnelOrder, stepName)
	if not step then
		return
	end
	stats.funnel += 1
	if dryRun() then
		print(("[T1][드라이런] 퍼널 %d %s"):format(step, stepName))
		return
	end
	pcall(function()
		game:GetService("AnalyticsService"):LogOnboardingFunnelStepEvent(player, step, stepName, Telemetry.fields(player))
	end)
end

function Telemetry.flush(player)
	local p = pending[player]
	pending[player] = nil
	if not p or typeof(player) ~= "Instance" then
		return 0
	end
	local fields = Telemetry.fields(player)
	local sent = 0
	local AnalyticsService = not dryRun() and game:GetService("AnalyticsService") or nil
	local PlayerProfile = require(script.Parent.PlayerProfile)
	for _, e in pairs(p.economy) do
		local balance = e.currency == "gold" and (PlayerProfile.getGold and PlayerProfile.getGold(player)) or 0
		sent += 1
		stats.economy += 1
		if AnalyticsService then
			pcall(function()
				AnalyticsService:LogEconomyEvent(player, e.flow == "sink" and Enum.AnalyticsEconomyFlowType.Sink or Enum.AnalyticsEconomyFlowType.Source,
					TelemetryData.currencies[e.currency], e.amount, balance or 0, e.tx, nil, fields)
			end)
		else
			print(("[T1][드라이런] 경제 %s %s %s 합 %.4g · %s · %s · %s"):format(e.currency, e.flow, e.tx, e.amount, fields.CustomField01, fields.CustomField02, fields.CustomField03))
		end
	end
	for name, value in pairs(p.custom) do
		sent += 1
		stats.custom += 1
		if AnalyticsService then
			pcall(function()
				AnalyticsService:LogCustomEvent(player, name, type(value) == "number" and value or 1, fields)
			end)
		else
			print(("[T1][드라이런] 커스텀 %s = %s"):format(name, tostring(value)))
		end
	end
	stats.flushes += 1
	return sent
end

function Telemetry.start()
	Players.PlayerRemoving:Connect(function(player)
		Telemetry.custom(player, "SessionStageBucket", tonumber((Telemetry.fields(player).CustomField01 or ""):match("%d+")) or 0) -- 스테이지 분포(퇴장 때 구간)
		Telemetry.flush(player)
	end)
	task.spawn(function()
		while true do
			task.wait(TelemetryData.flushSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				Telemetry.flush(player)
			end
		end
	end)
end

return Telemetry
