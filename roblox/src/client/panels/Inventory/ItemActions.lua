-- 장비(갑옷 · 장갑 · 신발) 착용 · 해제 입력의 공통 통로(S20d - GemActions와 같은 자리 · 같은 규칙). PC 더블클릭 · 우클릭 · 상세의 [장착] / [해제] 버튼(폰 탭 선택 → 버튼) - 어떤 입력이든 결국
-- ItemActions.equip(index) / unequip(part) 둘 중 하나를 부르고 같은 서버 요청(EquipRequest)을 쓴다.
-- 서버 규칙은 그대로다(PlayerProfile.equipItem = 항상 "교체": 기존 장비는 가방 끝으로 · unequipItem = 가방에 빈 칸이 있을 때만). 이 모듈은 입력 · 미리 보이기 · 거절 연출만 맡는다.
--   · 미리 보이기(equipBlockReason / unequipBlockReason)는 shared/Equip의 판정을 읽는다 - 서버가 같은 함수로 다시 검증한다(판정은 서버 권위 · 이유 코드는 서버 EquipResult와 같다).
--   · 요청 중 입력 잠금: 착용 · 해제마다 가방 index가 밀린다(교체된 장비가 맨 끝으로 간다) - 결과(EquipResult)가 오기 전에 다음 입력이 같은 index로 나가면 다른 아이템이 착용된다. 결과를 기다리는 동안 새 입력을 무시한다.
--   · 거절(클라 미리 판정이든 서버 결과든) = 보석과 같은 연출: 유령이 원래 칸으로 returnTweenSeconds(0.2초) 동안 돌아가고 + 이유 토스트 1줄(GemActions.bounce). 입력 규칙 시간(더블클릭 · 트윈 · 결과 대기)은 GemData.ui를 그대로 쓴다(단일 출처).
-- ItemActions.create(deps) -> { equip, unequip, canEquip, canUnequip, equipBlockReason, unequipBlockReason, isPending }
--   deps: screenGui(유령이 붙는 곳) · getState() = { inventory = 가방 배열, equipped = 부위 -> 착용 중 아이템 표, slots = 가방 칸 수 } · hasClass() = 직업을 골랐는가 ·
--         onPending() = 잠금 상태가 바뀔 때 · onDone(action, part) = 성공 알림(action = "equip" | "unequip" · part = 착용한 / 해제한 부위) · send(action, arg) = 요청 보내기(자체 점검이 서버 없이 잠금을 재려고 바꿔 끼운다 - 기본은 EquipRequest)
--   ctx(입력이 넘기는 연출 정보): originPos = 돌아갈 자리 · fromPos = 거절 유령의 출발점(없으면 유령 없이 토스트만)
-- ItemActions.attach(S, R) - 장비창에 붙인다: S.itemActions · S.equipFromBag(index) · S.unequipToBag(part)(모든 입력이 부르는 두 함수)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemData = require(ReplicatedStorage.Shared.data.GemData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local Equip = require(ReplicatedStorage.Shared.Equip)
local GemActions = require(script.Parent.GemActions)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)

local equipRequest = ReplicatedStorage:WaitForChild("EquipRequest")
local equipResult = ReplicatedStorage:WaitForChild("EquipResult")

local ItemActions = {}

-- 이유 코드 → 문구(서버 EquipResult의 코드 + 클라 미리 판정과 같다).
function ItemActions.reasonText(reason)
	if reason == "full" then
		return "가방이 가득 차 해제할 수 없습니다 - 칸을 비우세요"
	elseif reason == "no_class" then
		return "직업을 먼저 고르세요"
	elseif reason == "not_found" then
		return "장비를 찾을 수 없습니다"
	elseif reason == "not_equipped" then
		return "착용 중인 장비가 아닙니다"
	end
	return "장비를 바꿀 수 없습니다"
end

-- 더블클릭 판정기: 같은 key를 doubleClickSeconds(0.35초) 안에 다시 누르면 true. 판정이 나면 기록을 비운다(세 번째 클릭이 또 더블이 되지 않게).
function ItemActions.doubleClickTracker()
	local last = { key = nil, at = 0 }
	return function(key)
		local now = os.clock()
		local double = last.key == key and now - last.at <= GemData.ui.doubleClickSeconds
		last.key, last.at = (not double) and key or nil, now
		return double
	end
end

function ItemActions.create(deps)
	local self = {}
	local pending -- { action, arg, part, item, ctx } - 서버 결과를 기다리는 요청 하나

	local function notifyPending()
		if deps.onPending then
			deps.onPending()
		end
	end

	local function reject(reason, item, ctx)
		Toast.push("TC", { text = ItemActions.reasonText(reason), colorName = "danger", grade = "notice", seconds = 2.5, groupKey = "itemEquipReject" })
		GemActions.bounce(deps.screenGui, ctx or {}, item and item.grade)
	end

	function self.isPending()
		return pending ~= nil
	end

	-- 미리 보이기: 이 가방 index의 장비를 착용할 수 없는 이유(nil = 착용할 수 있다).
	function self.equipBlockReason(index)
		return Equip.equipBlockReason(deps.getState().inventory, index, deps.hasClass())
	end

	-- 이 부위를 해제할 수 없는 이유(nil = 해제할 수 있다). 가방이 가득 차면 "full".
	function self.unequipBlockReason(part)
		local state = deps.getState()
		return Equip.unequipBlockReason(state.equipped, part, #state.inventory, state.slots, deps.hasClass())
	end

	-- [장착] / [해제] 버튼 · 표시용: 지금 누를 수 있는가. 반환: true 또는 false + 이유("busy" = 요청 중).
	function self.canEquip(index)
		if pending then
			return false, "busy"
		end
		local reason = self.equipBlockReason(index)
		return reason == nil, reason
	end

	function self.canUnequip(part)
		if pending then
			return false, "busy"
		end
		local reason = self.unequipBlockReason(part)
		return reason == nil, reason
	end

	local function send(action, arg, part, item, ctx)
		local mine = { action = action, arg = arg, part = part, item = item, ctx = ctx }
		pending = mine
		notifyPending()
		if deps.send then
			deps.send(action, arg)
		else
			equipRequest:FireServer(action, arg)
		end
		task.delay(GemData.ui.resultTimeoutSeconds, function()
			if pending == mine then -- 결과가 안 왔다(서버가 못 받았거나 지연) - 잠금을 푼다
				pending = nil
				notifyPending()
			end
		end)
	end

	-- 착용(가방 index → 그 아이템의 부위. 찬 부위면 교체). 반환: 요청을 보냈으면 true. 요청 중이면 조용히 무시.
	function self.equip(index, ctx)
		if pending then
			return false
		end
		local item = deps.getState().inventory[index]
		local reason = self.equipBlockReason(index)
		if reason then
			reject(reason, item, ctx)
			return false
		end
		send("equip", index, item.part, item, ctx or {})
		return true
	end

	-- 해제(부위 → 가방으로). 가방이 가득 차면 서버도 거절한다(장비 소실 없음).
	function self.unequip(part, ctx)
		if pending then
			return false
		end
		local item = deps.getState().equipped[part]
		local reason = self.unequipBlockReason(part)
		if reason then
			reject(reason, item, ctx)
			return false
		end
		send("unequip", part, part, item, ctx or {})
		return true
	end

	equipResult.OnClientEvent:Connect(function(success, reason)
		local mine = pending
		if not mine then
			return
		end
		pending = nil
		if success then
			deps.onDone(mine.action, mine.part)
		else
			reject(reason, mine.item, mine.ctx)
		end
		notifyPending()
	end)

	return self
end

-- 장비창에 붙인다(InventoryUI가 Shell.create 뒤 · GearTab / BagTab / DetailSheet 앞에서 부른다). 그 셋은 S.equipFromBag · S.unequipToBag만 부른다.
function ItemActions.attach(S, R)
	local player = Players.LocalPlayer
	local actions = ItemActions.create({
		screenGui = R.screenGui,
		getState = function()
			return { inventory = S.inventory, equipped = S.equippedByPart(), slots = SaveConfig.defaultInventorySlots }
		end,
		hasClass = function()
			local classId = player:GetAttribute("ClassId")
			return classId ~= nil and classId ~= ""
		end,
		onPending = function()
			S.refreshDetail() -- 버튼이 요청 중에는 잠긴다
		end,
		onDone = function(action, part)
			-- 성공: 선택을 그 아이템이 옮겨 간 자리로 잇는다(착용 = 그 부위 칸 · 해제 = 가방 맨 끝 - 교체 · 해제된 장비는 항상 끝에 붙는다). 서버 스냅샷(InventorySync)이 결과보다 먼저 와 있다.
			if action == "equip" then
				S.selectedKind, S.selectedValue = "equip", part
			else
				S.selectedKind, S.selectedValue = "bag", #S.inventory
			end
			S.rebuildGearSlots()
			S.rebuildGrid()
		end,
	})
	S.itemActions = actions

	-- 모든 입력이 지나는 두 함수. 연출 좌표: 착용 = 가방 칸에서 그 부위 칸으로(거절이면 가방 칸으로 되돌아온다) · 해제 = 부위 칸에서 가방으로.
	function S.equipFromBag(index)
		local item = S.inventory[index]
		return actions.equip(index, { originPos = S.bagCellCenter(index), fromPos = item and S.gearSlotCenter(item.part) or nil })
	end

	function S.unequipToBag(part)
		return actions.unequip(part, { originPos = S.gearSlotCenter(part), fromPos = S.bagAreaCenter() })
	end
end

return ItemActions
