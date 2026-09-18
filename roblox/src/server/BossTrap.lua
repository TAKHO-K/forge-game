-- 잡힘/구출 상태(29-1, PRD 20.73 [2-8] A-2). 보스 기믹에 실패한 플레이어는 "잡힌다" - 이동·점프·
-- 평타·스킬·대시가 전부 막히고 피해는 면역이다. 파티원이 구출하면 바로 풀리고, 혼자면
-- autoReleaseSeconds 뒤 저절로 풀린다. 이 모듈은 6종 공통 뼈대만 갖는다:
--   · 진입(trap) / 해제(release) / 자동 해제 타이머
--   · 구출 진행도(addRescueProgress) - 0에서 1까지 차면 해제. 보스별 구출 동작(때리기·곁에 머물기·
--     밀기·닿기·진짜 찾기)은 rescueType별 핸들러가 "언제 얼마나 채우는가"만 정해 이 함수를 부른다
--     (registerRescueHandler - 보스 이름이 들어간 함수는 만들지 않는다, CLAUDE.md 조각 조합 규칙).
--   · 규칙: 이미 잡힌 사람은 다시 안 잡힌다(타이머 연장 없음) / 구출자가 잡히면 그 사람이 쌓던
--     구출 진행만 사라진다 / 구출 시도는 자동 해제 타이머를 늦추지도 멈추지도 않는다(최악 = 솔로)
--     / 전원이 잡혀도 전멸이 아니다 - 각자 타이머가 그대로 돈다.
-- 진실의 출처는 이 파일의 records다. PlayerState.setTrapped는 피해·행동 거절 경로가 읽는 사본이고,
-- Attribute(BossTrapKind 등)는 클라 UI(BossTrapView)용 사본이다.
--
-- 구출에는 보상이 없다(경험치·골드·기여도 0) - 이 파일은 보상 모듈을 아무것도 require하지 않는다.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local PlayerState = require(script.Parent.PlayerState)

local BossTrap = {}

-- [Player] = { kind, rescueType, startedAt(os.clock), releaseAt, progressBy = { [rescuer] = 0~1 }, context }
local records = {}
-- rescueType → { tick = function(trappedPlayer, record, members, dt) } (보스별 세션에서 꽂는다)
local rescueHandlers = {}
local releasedListeners = {}

local function isRealPlayer(player)
	return typeof(player) == "Instance"
end

local function setAnchored(player, anchored)
	if not isRealPlayer(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = anchored
	end
end

local function syncAttributes(player, record)
	if not isRealPlayer(player) or not player.Parent then
		return
	end
	player:SetAttribute("BossTrapKind", record and record.kind or nil)
	player:SetAttribute("BossTrapRescueType", record and record.rescueType or nil)
	-- 클라 막대는 서버 시계로 그린다(전조의 serverStart와 같은 관례).
	player:SetAttribute("BossTrapStartedAt", record and record.serverStartedAt or nil)
	player:SetAttribute("BossTrapReleaseAt", record and record.serverReleaseAt or nil)
	player:SetAttribute("BossTrapRescue", record and 0 or nil)
end

local function totalProgress(record)
	local total = 0
	for _, amount in pairs(record.progressBy) do
		total += amount
	end
	return math.min(total, 1)
end

function BossTrap.isTrapped(player)
	return records[player] ~= nil
end

function BossTrap.getRecord(player)
	return records[player]
end

-- members 중 살아 있는(호출부 기준) 전원이 잡혀 있는가. 빈 목록은 false.
function BossTrap.allTrapped(members)
	if #members == 0 then
		return false
	end
	for _, member in ipairs(members) do
		if not records[member] then
			return false
		end
	end
	return true
end

function BossTrap.onReleased(fn)
	table.insert(releasedListeners, fn)
end

-- reason: "auto"(자동 해제) / "rescued"(구출) / "reset"(전멸 리셋·보스전 종료·리스폰·퇴장) / "debug"
function BossTrap.release(player, reason)
	local record = records[player]
	if not record then
		return false
	end
	records[player] = nil
	PlayerState.setTrapped(player, nil)
	setAnchored(player, false)
	syncAttributes(player, nil)
	print(("[forge-game] 잡힘 해제: %s - %s(%s), %.2f초 만에"):format(
		tostring(player.Name), record.kind, reason or "?", os.clock() - record.startedAt))
	for _, fn in ipairs(releasedListeners) do
		task.spawn(fn, player, record, reason)
	end
	return true
end

-- def = { kind, rescueType, autoReleaseSeconds(생략하면 BossData.mechanics.trap), context(핸들러용 자유 필드) }
-- 반환: 잡혔으면 true. 이미 잡혀 있으면 false(타이머를 늘리지 않는다).
function BossTrap.trap(player, def)
	if records[player] then
		return false
	end
	local trapConfig = BossData.mechanics.trap
	local seconds = def.autoReleaseSeconds or trapConfig.autoReleaseSeconds
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local record = {
		kind = def.kind,
		rescueType = def.rescueType,
		startedAt = now,
		releaseAt = now + seconds,
		serverStartedAt = serverNow,
		serverReleaseAt = serverNow + seconds,
		progressBy = {},
		context = def.context,
	}
	records[player] = record

	-- 이 사람이 남을 구출하던 중이었으면 그 진행은 사라진다.
	BossTrap.clearRescueBy(player)

	PlayerState.setTrapped(player, trapConfig.damageTakenMultiplier)
	if isRealPlayer(player) then
		PlayerState.clearChanneling(player) -- 채널링 중에 잡히면 채널링도 끊긴다
	end
	setAnchored(player, true)
	syncAttributes(player, record)
	print(("[forge-game] 잡힘: %s - %s(구출 %s, 자동 해제 %.1f초)"):format(
		tostring(player.Name), tostring(def.kind), tostring(def.rescueType), seconds))

	task.delay(seconds, function()
		if records[player] == record then
			BossTrap.release(player, "auto")
		end
	end)
	return true
end

-- 구출 진행을 amount(0~1)만큼 채운다. 합이 1에 닿으면 해제한다. 잡힌 사람은 구출자가 될 수 없다.
-- 반환: 이번 호출로 풀려났으면 true.
function BossTrap.addRescueProgress(trappedPlayer, rescuer, amount)
	local record = records[trappedPlayer]
	if not record or rescuer == trappedPlayer or records[rescuer] then
		return false
	end
	record.progressBy[rescuer] = math.min((record.progressBy[rescuer] or 0) + amount, 1)
	local total = totalProgress(record)
	if isRealPlayer(trappedPlayer) and trappedPlayer.Parent then
		trappedPlayer:SetAttribute("BossTrapRescue", total)
	end
	if total >= 1 then
		BossTrap.release(trappedPlayer, "rescued")
		return true
	end
	return false
end

-- rescuer가 쌓던 구출 진행을 전부 지운다(구출자가 잡혔을 때, 곁에 머무는 구출에서 벗어났을 때).
-- trappedPlayer를 주면 그 한 사람 것만.
function BossTrap.clearRescueBy(rescuer, trappedPlayer)
	for player, record in pairs(records) do
		if (trappedPlayer == nil or player == trappedPlayer) and record.progressBy[rescuer] then
			record.progressBy[rescuer] = nil
			if isRealPlayer(player) and player.Parent then
				player:SetAttribute("BossTrapRescue", totalProgress(record))
			end
		end
	end
end

-- 구출 상호작용 훅 - 보스별 구출 동작이 여기에 꽂힌다. handler.tick(trappedPlayer, record, members, dt)가
-- 매 보스 틱마다 불려 조건이 맞으면 addRescueProgress를 부른다(때리기처럼 틱이 필요 없는 종류는
-- 타격 경로에서 addRescueProgress를 직접 부르면 된다 - 핸들러 등록은 선택이다).
function BossTrap.registerRescueHandler(rescueType, handler)
	rescueHandlers[rescueType] = handler
end

-- 보스 한 마리의 틱(BossMechanics.tick) - 그 보스전 멤버 중 잡힌 사람마다 구출 핸들러를 돌린다.
function BossTrap.tick(members, dt)
	for _, member in ipairs(members) do
		local record = records[member]
		local handler = record and rescueHandlers[record.rescueType]
		if handler and handler.tick then
			handler.tick(member, record, members, dt)
		end
	end
end

-- 보스전 종료·전멸 리셋 - 멤버 전원을 푼다.
function BossTrap.releaseAll(members, reason)
	for _, member in ipairs(members) do
		BossTrap.release(member, reason or "reset")
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		BossTrap.release(player, "reset") -- 새 캐릭터는 고정돼 있지 않다 - 기록·Attribute만 정리된다
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	BossTrap.clearRescueBy(player)
	BossTrap.release(player, "reset")
end)

return BossTrap
