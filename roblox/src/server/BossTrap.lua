-- 잡힘/구출 상태(29-1, PRD 20.73 [2-8] A-2). 보스 기믹에 실패한 플레이어는 "잡힌다" - 이동·점프·
-- 평타·스킬·대시가 전부 막히고 피해는 면역이다. 파티원이 구출하면 바로 풀리고, 혼자면
-- autoReleaseSeconds 뒤 저절로 풀린다. 이 모듈은 6종 공통 뼈대만 갖는다:
--   · 진입(trap) / 해제(release) / 자동 해제 타이머
--   · 구출 진행도(addRescueProgress) - 0에서 1까지 차면 해제.
--   · **구출 입력 = F 홀드(29-5, PRD 20.80 [B])**: 잡힌 사람의 루트에 ProximityPrompt를 단다 - PC는 F, 모바일은 화면 버튼,
--     게임패드는 버튼이 로블록스 기본 UI로 붙는다(직접 입력을 짜지 않는다 - 모바일이 빠지기 쉽다). 프롬프트의 홀드 신호
--     (HoldBegan/HoldEnded/Triggered)는 beginHold/endHold로 들어오고, **진행은 서버가 틱마다 센다**(구출자마다 dt ÷
--     trap.rescueSeconds - 둘이 누르면 절반). 거리(종류별 reachStuds)·생존·잡힘 여부도 서버가 틱마다 다시 본다.
--     예고가 있는 피격을 받은 구출자의 진행은 0으로 돌아간다(noteSkillHit) - 클라의 홀드도 끊는다(BossRescueHoldBroken).
--   · 보스별 차이는 rescueType별 핸들러의 선택 조각으로 남는다(registerRescueHandler - 보스 이름이 들어간 함수는 만들지
--     않는다, CLAUDE.md 조각 조합 규칙): canHold(조건) · onProgress(끌려 나오는 그림) · onComplete(구출자 비용).
--     때리기(빙결의 얼음)처럼 홀드 밖의 길은 타격 경로에서 addRescueProgress를 직접 부른다.
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

-- [Player] = { kind, rescueType, startedAt(os.clock), releaseAt, progressBy = { [rescuer] = 0~1 },
--              holders = { [rescuer] = 홀드를 시작한 os.clock }, prompt, context }
local records = {}
-- rescueType → { canHold?, onProgress?, onComplete?, tick? } (BossGimmicks가 꽂는다)
local rescueHandlers = {}

-- 구출 홀드가 피격으로 끊겼다는 것을 그 구출자의 클라에 알린다 - 클라가 자기 화면의 프롬프트 홀드를 끊는다(BossTrapView).
-- 서버의 진행은 이미 0이다 - 이 신호는 그림을 맞추는 용도다.
local holdBrokenEvent = Instance.new("RemoteEvent")
holdBrokenEvent.Name = "BossRescueHoldBroken"
holdBrokenEvent.Parent = ReplicatedStorage

local PROMPT_NAME = "BossRescuePrompt"
local releasedListeners = {}
local trappedListeners = {}

local function isRealPlayer(player)
	return typeof(player) == "Instance"
end

local function setAnchored(player, anchored)
	if not isRealPlayer(player) then
		return
	end
	PlayerState.setAnchorHold(player, "trap", anchored) -- P3d-F: 출처별 고정(끼임과 서로 풀지 않는다)
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
	-- 29-3: 잡힌 자리(모래 무덤의 중심 - 클라 BossTrapView가 그 자리에 원을 그린다). 자리가 뜻이 없는 종류는 nil.
	player:SetAttribute("BossTrapOrigin", record and record.context and record.context.origin or nil)
end

local function rootOf(player)
	local character = player.Character -- 스탠드인(테이블 Player)도 Character를 가질 수 있다
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function reachOf(record)
	local config = BossData.mechanics.rescue[record.rescueType]
	return config and config.reachStuds
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

-- 29-3: 잡히는 순간 fn(player, record) - 구출 대상(얼음 덩어리)을 세우는 쪽이 듣는다(BossGimmicks).
function BossTrap.onTrapped(fn)
	table.insert(trappedListeners, fn)
end

-- reason: "auto"(자동 해제) / "rescued"(구출) / "reset"(전멸 리셋·보스전 종료·리스폰·퇴장) / "debug"
function BossTrap.release(player, reason)
	local record = records[player]
	if not record then
		return false
	end
	records[player] = nil
	if record.prompt then
		record.prompt:Destroy() -- 누르고 있던 구출자의 홀드도 여기서 끝난다
	end
	PlayerState.setTrapped(player, nil)
	-- 29-3: 풀려난 직후 유예 - 잡힌 동안 시작된 예고는 피할 수 없었다(BossData.mechanics.trap.releaseGraceSeconds).
	-- 보스전이 끝나거나 리셋돼 풀린 것("reset")은 유예가 필요 없다.
	if reason == "auto" or reason == "rescued" then
		local trapConfig = BossData.mechanics.trap
		-- P3d-F B6: 출처별 칸 - 0배(지금 값)면 무적 플래그, 아니면 배율
		if trapConfig.damageTakenMultiplier <= 0 then
			PlayerState.setInvulnerableUntil(player, trapConfig.releaseGraceSeconds, "trapReleaseGrace")
		else
			PlayerState.setIncomingDamageMultiplierUntil(player, trapConfig.damageTakenMultiplier, trapConfig.releaseGraceSeconds, "trapReleaseGrace")
		end
	end
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
		holders = {},
		context = def.context,
	}
	records[player] = record
	record.prompt = BossTrap.createPrompt(player, record)

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

	for _, fn in ipairs(trappedListeners) do
		task.spawn(fn, player, record)
	end

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

-- rescuer가 쌓던 구출 진행(과 누르고 있던 홀드)을 전부 지운다 - 구출자가 잡혔을 때, 손을 뗐을 때, 거리를 벗어났을 때,
-- 예고가 있는 피격을 받았을 때. trappedPlayer를 주면 그 한 사람 것만.
function BossTrap.clearRescueBy(rescuer, trappedPlayer)
	for player, record in pairs(records) do
		if trappedPlayer == nil or player == trappedPlayer then
			record.holders[rescuer] = nil
		end
		if (trappedPlayer == nil or player == trappedPlayer) and record.progressBy[rescuer] then
			record.progressBy[rescuer] = nil
			if isRealPlayer(player) and player.Parent then
				player:SetAttribute("BossTrapRescue", totalProgress(record))
			end
		end
	end
end

-- ─────────────────────────── 구출 입력: F 홀드(29-5) ───────────────────────────

-- 잡힌 사람의 루트에 구출 프롬프트를 단다. 실제 Player에게만(스탠드인에는 루트 Instance가 없다 - 검증은 beginHold/endHold를
-- 직접 부른다: 프롬프트의 신호가 부르는 바로 그 함수다). 잡힌 본인과 다른 잡힌 사람에게는 클라가 자기 화면에서 끈다.
function BossTrap.createPrompt(player, record)
	local reach = reachOf(record)
	local root = isRealPlayer(player) and rootOf(player)
	if not root or not reach then
		return nil -- reachStuds가 없는 종류(결정화 - 진짜를 찾아 때린다)는 홀드로 풀지 않는다
	end
	local hold = BossData.mechanics.rescue.hold
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "구출"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = BossData.mechanics.trap.rescueSeconds
	prompt.KeyboardKeyCode = Enum.KeyCode[hold.keyCode]
	prompt.GamepadKeyCode = Enum.KeyCode[hold.gamepadKeyCode]
	prompt.MaxActivationDistance = reach
	prompt.RequiresLineOfSight = false -- 얼음 덩어리·보스 몸이 가려도 누를 수 있어야 한다
	prompt.PromptButtonHoldBegan:Connect(function(rescuer)
		BossTrap.beginHold(player, rescuer)
	end)
	prompt.PromptButtonHoldEnded:Connect(function(rescuer)
		BossTrap.endHold(player, rescuer)
	end)
	prompt.Triggered:Connect(function(rescuer)
		BossTrap.endHold(player, rescuer)
	end)
	prompt.Parent = root
	return prompt
end

local function canHold(trapped, record, rescuer)
	if rescuer == trapped or records[rescuer] or (PlayerState.getHp(rescuer) or 0) <= 0 then
		return false
	end
	local reach = reachOf(record)
	local root, rescuerRoot = rootOf(trapped), rootOf(rescuer)
	if not (reach and root and rescuerRoot) then
		return false
	end
	local offset = rescuerRoot.Position - root.Position
	if math.sqrt(offset.X * offset.X + offset.Z * offset.Z) > reach + BossData.mechanics.rescue.hold.reachSlackStuds then
		return false
	end
	local handler = rescueHandlers[record.rescueType]
	return not (handler and handler.canHold) or handler.canHold(trapped, record, rescuer)
end

-- 구출자가 홀드를 시작했다. 반환: 받아들였으면 true.
function BossTrap.beginHold(trapped, rescuer)
	local record = records[trapped]
	if not record or not canHold(trapped, record, rescuer) then
		return false
	end
	record.holders[rescuer] = os.clock()
	return true
end

-- 구출자의 홀드가 끝났다(손을 뗐다 · 프롬프트가 다 찼다). 클라의 홀드가 다 찼는데 서버가 센 시간이 지연 몫
-- (completeToleranceSeconds)만큼 모자란 경우는 완료로 친다 - 그보다 일찍 끝났으면 손을 뗀 것이고 진행은 0으로 돌아간다.
function BossTrap.endHold(trapped, rescuer)
	local record = records[trapped]
	local startedAt = record and record.holders[rescuer]
	if not startedAt then
		return false
	end
	record.holders[rescuer] = nil
	local required = BossData.mechanics.trap.rescueSeconds * (1 - totalProgress(record) + (record.progressBy[rescuer] or 0))
	if os.clock() - startedAt >= required - BossData.mechanics.rescue.hold.completeToleranceSeconds and canHold(trapped, record, rescuer) then
		return BossTrap.completeHold(trapped, record, rescuer)
	end
	BossTrap.clearRescueBy(rescuer, trapped)
	return false
end

function BossTrap.completeHold(trapped, record, rescuer)
	local handler = rescueHandlers[record.rescueType]
	if handler and handler.onComplete then
		handler.onComplete(trapped, record, rescuer)
	end
	return BossTrap.addRescueProgress(trapped, rescuer, 1)
end

-- 예고가 있는 피격(스킬·기믹·반사)을 받았다 - 이 사람이 누르고 있던 구출은 처음부터다. 보스 평타는 여기로 오지 않는다
-- (BossData.mechanics.rescue 주석). 반환: 끊긴 홀드가 있었으면 true.
function BossTrap.noteSkillHit(rescuer)
	local broken = false
	for _, record in pairs(records) do
		if record.holders[rescuer] or record.progressBy[rescuer] then
			broken = true
		end
	end
	if broken then
		BossTrap.clearRescueBy(rescuer)
		if isRealPlayer(rescuer) and rescuer.Parent then
			holdBrokenEvent:FireClient(rescuer)
		end
		print(("[forge-game] 구출 홀드 끊김(피격): %s"):format(tostring(rescuer.Name)))
	end
	return broken
end

-- 구출 상호작용 훅 - 보스별 구출의 조건·그림·비용이 여기에 꽂힌다(전부 선택):
--   canHold(trapped, record, rescuer) → 지금 이 사람이 누를 수 있는가 / onProgress(trapped, record, rescuer, amount) → 진행이
--   amount만큼 찼다(끌려 나오는 그림) / onComplete(trapped, record, rescuer) → 풀려나기 직전(구출자 비용) / tick(…) → 홀드 밖의 진행.
function BossTrap.registerRescueHandler(rescueType, handler)
	rescueHandlers[rescueType] = handler
end

-- 보스 한 마리의 틱(BossMechanics.tick) - 그 보스전 멤버 중 잡힌 사람마다, 누르고 있는 구출자의 진행을 채운다.
-- 구출자는 그 보스전의 멤버여야 한다. 조건(거리·생존·잡힘)이 깨진 구출자의 진행은 0으로 돌아간다.
function BossTrap.tick(members, dt)
	local amount = dt / BossData.mechanics.trap.rescueSeconds
	for _, member in ipairs(members) do
		local record = records[member]
		local handler = record and rescueHandlers[record.rescueType]
		if record then
			for rescuer in pairs(record.holders) do
				if not table.find(members, rescuer) or not canHold(member, record, rescuer) then
					BossTrap.clearRescueBy(rescuer, member)
				else
					if handler and handler.onProgress then
						handler.onProgress(member, record, rescuer, amount)
					end
					if totalProgress(record) + amount >= 1 then
						BossTrap.completeHold(member, record, rescuer)
						break
					end
					BossTrap.addRescueProgress(member, rescuer, amount)
				end
			end
		end
		if records[member] == record and handler and handler.tick then
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
