-- C5-4 자동 스테이지 이동(docs/design/growth-curve-v2.md §7 · 수치 = shared/data/AutoStageData). 5초마다 플레이어마다:
--   설정이 끄기가 아니고 · 보스전 중이 아니고 · (파티면 리더만) · 지금 스테이지 비율(전투력 ÷ 권장) ≥ triggerRatio이면
--   "비율 ≥ 설정값인 가장 높은 일반(보스 아님) 스테이지" ≤ 지금 최고(infiniteBest - 최고 기록 · 리더보드 영향 0) · 아직 안 깬 보스 관문 아래로 숫자만 이동(StageServer의 일반 이동 경로 = C1 공유 규칙 그대로).
--   관문(다음 보스 스테이지)이 이동을 막으면 도전 알림 토스트(같은 관문은 bossGateNoticeSeconds마다 1번). 설정 = 클라 → RemoteEvent AutoStageSetting(프리셋 id) → 서버 보관 + Player Attribute AutoStage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AutoStageData = require(ReplicatedStorage.Shared.data.AutoStageData)
local CombatFormula = require(ReplicatedStorage.Shared.CombatFormula)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local Text = require(ReplicatedStorage.Shared.Text)
local PlayerProfile = require(script.Parent.PlayerProfile)
local BossEncounter = require(script.Parent.BossEncounter)
local PartyState = require(script.Parent.PartyState)

local settingRemote = Instance.new("RemoteEvent")
settingRemote.Name = "AutoStageSetting"
settingRemote.Parent = ReplicatedStorage

local notice = ReplicatedStorage:FindFirstChild("SystemNotice") or Instance.new("RemoteEvent")
notice.Name = "SystemNotice"
notice.Parent = ReplicatedStorage

local presetById = {}
for _, preset in ipairs(AutoStageData.presets) do
	presetById[preset.id] = preset
end

local settings = {} -- [Player] = preset id
local lastGateNotice = {} -- [Player] = { stage, at }
local stats = { moves = 0, gateNotices = 0 } -- 검증
local AutoStage = { stats = stats }

local function presetOf(player)
	return presetById[settings[player] or AutoStageData.default] or presetById[AutoStageData.default]
end

settingRemote.OnServerEvent:Connect(function(player, presetId)
	if type(presetId) == "string" and presetById[presetId] then
		settings[player] = presetId
		player:SetAttribute("AutoStage", presetId)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("AutoStage", AutoStageData.default)
end)

Players.PlayerRemoving:Connect(function(player)
	settings[player], lastGateNotice[player] = nil, nil
end)

-- 이 플레이어가 지금 갈 수 있는 자동 이동 목표(nil = 없음). 반환: 목표 스테이지, 막은 관문 스테이지(있으면).
function AutoStage.targetFor(player)
	local preset = presetOf(player)
	if not preset.ratio or not PlayerProfile.getProfile(player) then
		return nil
	end
	if BossEncounter.getActive(player) ~= nil or BossEncounter.getEncounter(player) ~= nil then
		return nil
	end
	local party = PartyState.getParty(player)
	if party and not PartyState.isLeader(player) then
		return nil
	end
	local power = player:GetAttribute("CombatPower")
	local current = PlayerProfile.getInfiniteStage(player) or 1
	if type(power) ~= "number" or power <= 0 or BossRules.isBossStage(current) then
		return nil
	end
	if power / CombatFormula.recommendedPower(current) < AutoStageData.triggerRatio then
		return nil
	end
	local best = PlayerProfile.getInfiniteStageBest(player) or 1
	local clearedBoss = PlayerProfile.getBestBossCleared(player) or 0
	local blockedGate = nil
	local target = nil
	for stage = best, current + 1, -1 do -- 위(지금 최고)에서 내려오며 첫 조건 만족(비율은 스테이지에 단조 감소) - 묶음 A 리뷰: 옛 범위는 current + 1 한 칸만 봤다
		if not BossRules.isBossStage(stage) then
			local gate = BossRules.getBossStageBelow(stage)
			if gate > 0 and gate > clearedBoss then
				blockedGate = blockedGate or gate -- 아직 안 깬 관문 위 = 못 간다(도전 알림)
			elseif power / CombatFormula.recommendedPower(stage) >= preset.ratio then
				target = stage
				break
			end
		end
	end
	if target and target <= current then
		target = nil
	end
	-- 지금 최고에 있고 바로 위가 안 깬 보스 관문이면 도전 알림(자동 이동은 최고 기록을 넘지 않는다 - 묶음 A 리뷰)
	if not target and not blockedGate and current >= best and BossRules.isBossStage(current + 1) and current + 1 > clearedBoss then
		blockedGate = current + 1
	end
	return target, blockedGate
end

local moveHook = ServerStorage:WaitForChild("AutoStageMoveHook", 30)

local function tick()
	for _, player in ipairs(Players:GetPlayers()) do
		local ok, err = pcall(function()
			local target, gate = AutoStage.targetFor(player)
			if target and moveHook then
				local current = PlayerProfile.getInfiniteStage(player) or 1
				local moved = moveHook:Invoke(player, target)
				if moved then
					stats.moves += 1
					notice:FireClient(player, Text.get("autoStage.moved", { from = tostring(current), to = tostring(target) }))
				end
			elseif gate then
				local last = lastGateNotice[player]
				if not last or last.stage ~= gate or os.clock() - last.at >= AutoStageData.bossGateNoticeSeconds then
					lastGateNotice[player] = { stage = gate, at = os.clock() }
					stats.gateNotices += 1
					notice:FireClient(player, Text.get("autoStage.bossGate", { stage = tostring(gate) }))
				end
			end
		end)
		if not ok then
			warn(("[C5-4] 자동 이동 검사 실패: %s - %s"):format(player.Name, tostring(err)))
		end
	end
end

task.spawn(function()
	while true do
		task.wait(AutoStageData.checkSeconds)
		tick()
	end
end)

-- 검증 · 개발 명령: 서버 execute_luau · DevTools가 부른다(ServerStorage.AutoStageHook:Invoke(player) → 목표, 관문 / "tick" → 즉시 검사).
local hook = Instance.new("BindableFunction")
hook.Name = "AutoStageHook"
hook.OnInvoke = function(player, action)
	if action == "tick" then
		tick()
		return stats.moves, stats.gateNotices
	end
	return AutoStage.targetFor(player)
end
hook.Parent = ServerStorage
