-- QUEUE-MENU2 D · E: 캐릭터 칸 전환 · 메인 메뉴로(서버). 원격 입구 = SlotServer.server.lua(SlotRequest).
--   전환 순서: 금지 상태 확인 → 파티 이탈 → 즉시 저장(성공해야 다음) → 새 칸 로드(실패 = 지금 캐릭터 그대로) → 정리(버프 · 화살 · 분신 · 쿨) → 캐릭터 다시 스폰 → 로드 뒤 처리(ProfileBoot · 쿨/게이지/위치 복원).
--   메인 메뉴로 = 금지 상태 확인 → 파티 이탈 → 즉시 저장 → 캐릭터를 월드에서 뺌(InMainMenu) - 이어하기(같은 칸) = 다시 스폰 + 마지막 자리.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlotSaveData = require(ReplicatedStorage.Shared.data.SlotSaveData)
local SlotSave = require(script.Parent.SlotSave)

local SlotSwitch = {}
local busy = {} -- [Player] = true(전환 · 메뉴 이동 중 - 연타 · 중복 요청 1회)
local lastAt = {} -- [Player] = os.clock() 마지막 전환(switchMinSeconds - UpdateAsync 예산)
local heldAtJoin = {} -- [Player] = true(접속해 메뉴에 있고 아직 한 번도 스폰 안 함)
game:GetService("Players").PlayerRemoving:Connect(function(player)
	heldAtJoin[player] = nil
end)

-- 메뉴 이동 · 전환 금지 사유(nil = 됨): 보스전 · 토벌 · 주간 도전 · 잔류(보스방 안) · 계승 저장 대기
function SlotSwitch.blockReason(player)
	if require(script.Parent.BossEncounter).classChangeBlocked(player) then
		return "boss"
	end
	local okT, TranscendService = pcall(require, script.Parent.TranscendService)
	if okT and TranscendService.isBusy and TranscendService.isBusy(player) then
		return "inherit"
	end
	return require(script.Parent.MenuBlock).reason(player) -- 강화 · 재련 · 계승 연출 · 선물 받기 직후(MENU2 판정 4)
end

local function cleanup(player)
	require(script.Parent.BuffState).clearAll(player)
	require(script.Parent.StuckArrowState).clearForPlayer(player)
	require(script.Parent.SummonState).clearAll(player)
	require(script.Parent.SkillCooldowns).clear(player)
end

local function leaveParty(player)
	pcall(function()
		require(script.Parent.PartyState).leave(player, "mainMenu") -- 사용자 확정: 메뉴로 갈 때 파티 해제
	end)
end

local function begin(player)
	if busy[player] then
		return "busy"
	end
	local now = os.clock()
	if lastAt[player] and now - lastAt[player] < SlotSaveData.switchMinSeconds then
		return "too_fast"
	end
	busy[player] = true
	lastAt[player] = now
	return nil
end

-- 칸 목록(메뉴 이어하기 창) - 계정 키 요약만(캐릭터 키를 다 읽지 않는다)
function SlotSwitch.list(player)
	local SaveSystem = require(script.Parent.SaveSystem)
	local sess = SaveSystem.slotSessionOf(player)
	if not sess then
		return { enabled = SlotSaveData.enabled, slots = {} }
	end
	local acc = sess.account
	local slots = {}
	for i = 1, SlotSave.slotCount() do
		local s = acc.slots[i]
		if s then
			local v = table.clone(s)
			v.number = SlotSave.classNumber(acc, i)
			slots[i] = v
		else
			slots[i] = false
		end
	end
	local archive = {}
	for i, s in ipairs(acc.archive or {}) do
		archive[i] = table.clone(s)
	end
	return {
		enabled = true, slots = slots, slotCount = SlotSave.slotCount(), lockedPreview = SlotSaveData.lockedPreviewSlots or 0,
		archive = archive, maxArchive = SlotSaveData.maxArchive, current = sess.slot, lastSlot = acc.lastSlot,
		inMenu = player:GetAttribute("InMainMenu") == true, block = SlotSwitch.blockReason(player),
	}
end

-- target = 칸 번호 | "new"(캐릭터 없음 - 직업 선택이 새 캐릭터)
function SlotSwitch.switch(player, target)
	local SaveSystem = require(script.Parent.SaveSystem)
	local sess = SaveSystem.slotSessionOf(player)
	if not sess then
		return false, "no_session"
	end
	if target ~= "new" then
		target = tonumber(target)
		if not (target and sess.account.slots[target]) then
			return false, "empty"
		end
	elseif not SlotSave.freeSlot(sess.account) then
		return false, "full"
	end
	if target == sess.slot then -- 같은 캐릭터(메뉴에서 이어하기) = 월드에 다시 넣기만
		SlotSwitch.enterWorld(player)
		return true, "same"
	end
	local block = SlotSwitch.blockReason(player)
	if block then
		return false, block
	end
	local why = begin(player)
	if why then
		return false, why
	end
	local SaveCoordinator = require(script.Parent.SaveCoordinator)
	local ok, err = pcall(function()
		leaveParty(player)
		if not require(script.Parent.ImmediateSave).flush(player) then
			error("save_failed", 0)
		end
		SaveCoordinator.setSwitchLocked(player, true) -- SEC-FIX-1 1: 마지막 저장(flush) 뒤 ~ 새 프로필 자리 잡기까지 다른 저장 금지(옛 프로필 · 세션이 계정 키를 쓰면 새 세션이 stale)
		local profile, loadErr = SaveSystem.loadSlotProfile(player, target)
		if not profile then
			error("load_failed:" .. tostring(loadErr), 0) -- 지금 캐릭터(메모리 · 세션)는 그대로
		end
		cleanup(player)
		require(script.Parent.PlayerProfile).clear(player)
		player:SetAttribute("InMainMenu", nil)
		heldAtJoin[player] = nil
		require(script.Parent.ProfileBoot).apply(player, profile, nil, { switch = true }) -- 새 프로필을 먼저(스폰 처리기가 빈 프로필을 보지 않게)
		player:LoadCharacter()
		local cs = profile.classId and profile.classes[profile.classId]
		require(script.Parent.CharacterRuntime).restore(player, cs, true) -- 새 몸 = 그 캐릭터 마지막 자리
	end)
	SaveCoordinator.setSwitchLocked(player, false)
	busy[player] = nil
	if not ok then
		warn(("[SlotSwitch] 전환 실패: %s → %s - %s"):format(player.Name, tostring(target), tostring(err)))
		return false, tostring(err):match("^[%w_]+") or "error"
	end
	print(("[SlotSwitch] 전환: %s → 칸 %s"):format(player.Name, tostring(target)))
	return true, "switched"
end

-- 메인 메뉴 버그(10-05): 접속 = 메뉴에서 시작(캐릭터를 월드에 두지 않는다 - SlotServer가 CharacterAutoLoads를 끄고 여기로).
function SlotSwitch.holdAtJoin(player)
	heldAtJoin[player] = true
	player:SetAttribute("InMainMenu", true)
end

-- 메뉴 → 월드(이어하기 · 같은 칸 · 칸 창이 없는 옛 경로 · 테스트 건너뛰기): 메뉴에 있을 때만 스폰. 접속 직후 = 첫 로드(ProfileBoot)가 이미 쿨 · 위치 복원을 걸어 두었다(스폰을 기다림)
function SlotSwitch.enterWorld(player)
	if not player:GetAttribute("InMainMenu") then
		return false, "in_world"
	end
	player:SetAttribute("InMainMenu", nil)
	local initial = heldAtJoin[player]
	heldAtJoin[player] = nil
	player:LoadCharacter()
	if not initial then
		local profile = require(script.Parent.PlayerProfile).getProfile(player)
		local cs = profile and profile.classId and profile.classes[profile.classId]
		require(script.Parent.CharacterRuntime).restore(player, cs, true)
	end
	return true, "entered"
end

-- 메인 메뉴로(설정 → [메인 메뉴로]): 저장 · 파티 해제 · 캐릭터 빼기
function SlotSwitch.toMenu(player)
	local block = SlotSwitch.blockReason(player)
	if block then
		return false, block
	end
	local why = begin(player)
	if why then
		return false, why
	end
	leaveParty(player)
	local ok = require(script.Parent.ImmediateSave).flush(player)
	busy[player] = nil
	if not ok then
		return false, "save_failed"
	end
	player:SetAttribute("InMainMenu", true)
	local character = player.Character
	if character then
		player.Character = nil
		character:Destroy()
	end
	return true, "menu"
end

-- 보관 · 복구(계정 키 즉시 저장)
function SlotSwitch.archive(player, slot)
	local SaveSystem = require(script.Parent.SaveSystem)
	local sess = SaveSystem.slotSessionOf(player)
	slot = tonumber(slot)
	if not (sess and slot) then
		return false, "no_session"
	end
	if slot == sess.slot then
		return false, "current" -- 지금 캐릭터는 보관 못 함(다른 칸으로 바꾼 뒤)
	end
	local ok, err = SlotSave.archiveSlot(sess.account, slot)
	if not ok then
		return false, err
	end
	require(script.Parent.ImmediateSave).flush(player)
	return true
end

function SlotSwitch.restore(player, index)
	local SaveSystem = require(script.Parent.SaveSystem)
	local sess = SaveSystem.slotSessionOf(player)
	index = tonumber(index)
	if not (sess and index) then
		return false, "no_session"
	end
	local slot, err = SlotSave.restoreArchived(sess.account, index)
	if not slot then
		return false, err
	end
	require(script.Parent.ImmediateSave).flush(player)
	return true, slot
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	busy[player], lastAt[player] = nil, nil
end)

return SlotSwitch
