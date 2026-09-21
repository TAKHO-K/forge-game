-- 보석 장착 입력의 공통 통로(S20c). PC 더블클릭 · 우클릭 · 드래그 · 홈 먼저 고르기 · [장착] 버튼 · 폰 탭 - 어떤 입력이든 결국 GemActions.equip(slot, index) 하나를 부르고 같은 서버 요청(GemEquipRequest)을 쓴다.
-- 서버 규칙은 그대로다(PlayerProfile.equipGem = 항상 "교체": 기존 보석은 보석칸으로 돌아오고 비용 · 파괴가 없다. "해제"는 서버에 없다). 이 모듈은 입력 · 미리 보이기 · 거절 연출만 맡는다.
--   · 미리 보이기(blockReason / autoTarget)는 shared/Gem의 판정(socketBlockReason · autoSlot)을 읽는다 - 서버가 같은 규칙으로 다시 검증한다(판정은 서버 권위).
--   · 요청 중 입력 잠금: 장착마다 보석칸 index가 밀린다(교체된 보석이 맨 끝으로 간다) - 결과(GemEquipResult)가 오기 전에 다음 입력이 같은 index로 나가면 다른 보석이 끼워진다. 결과를 기다리는 동안 새 입력을 무시한다.
--   · 거절(클라 미리 판정이든 서버 결과든) = 같은 연출: 보석 유령이 원래 칸으로 returnTweenSeconds(0.2초) 동안 돌아가고 + 이유 토스트 1줄.
-- GemActions.create(deps) -> { equip, autoEquip, autoTarget, blockReason, isPending, makeGhost, ... }
--   deps: screenGui(유령이 붙는 곳) · getState() = 보석 상태 스냅샷 · isNear() = 강화대 근처인가(강화 패널과 같은 값) · slotCenter(slot) = 그 홈의 화면 중심(ScreenGui 좌표) · onEquipped(slot) = 성공 알림 · onPending() = 잠금 상태가 바뀔 때
--   ctx(입력이 넘기는 연출 정보): originPos = 돌아갈 자리(원래 보석 칸 중심) · fromPos = 거절 유령의 출발점(없으면 유령 없이 토스트만) · proxy = 이미 있는 드래그 유령(넘기면 이 모듈이 넘겨받아 정리한다)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local Gem = require(ReplicatedStorage.Shared.Gem)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)

local gemEquipRequest = ReplicatedStorage:WaitForChild("GemEquipRequest")
local gemEquipResult = ReplicatedStorage:WaitForChild("GemEquipResult")

local GemActions = {}

local function gradeName(gradeId)
	local info = ArmorData.grades[gradeId]
	return info and info.displayName or tostring(gradeId)
end

-- 이유 코드 → 토스트 문구. slot = 요청한 홈(자동 장착이면 nil). 이유 코드는 서버 GemEquipResult의 것과 같다(far · slot_locked · grade_too_high · not_found · no_class · invalid) + 클라 미리 판정의 no_slot_open.
function GemActions.reasonText(reason, gemGradeId, slot)
	if reason == "far" then
		return "강화대 근처에서만 보석을 장착할 수 있습니다"
	elseif reason == "slot_locked" then
		return ("%d번 홈은 환생 %d회 뒤에 열립니다"):format(slot or 0, GemData.slotUnlockRequiredRebirth[slot or 1] or 0)
	elseif reason == "grade_too_high" then
		if slot then
			return ("%d번 홈은 %s 이하 보석만 받습니다"):format(slot, gradeName(Gem.gradeCapForSlot(slot)))
		end
		return ("%s 등급은 %s 이상 홈에만 장착할 수 있습니다"):format(gradeName(gemGradeId), gradeName(gemGradeId))
	elseif reason == "no_slot_open" then
		return "열린 홈이 없습니다 - 환생하면 홈이 열립니다"
	elseif reason == "not_found" then
		return "보석을 찾을 수 없습니다"
	elseif reason == "no_class" then
		return "직업을 먼저 고르세요"
	end
	return "보석을 장착할 수 없습니다"
end

-- 보석 등급의 표시 색(무지개 등급은 흰색 - 기존 무기 아이콘과 같은 처리).
function GemActions.gradeColor(gradeId)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	if not visual then
		return Color3.new(1, 1, 1)
	end
	return visual.rainbow and Color3.new(1, 1, 1) or visual.color
end

-- 드래그 · 거절 유령(30px 원). pos = ScreenGui 좌표 중심.
function GemActions.makeGhost(screenGui, pos, gradeId)
	local ghost = Instance.new("Frame")
	ghost.Name = "GemDragProxy"
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.Size = UDim2.new(0, 30, 0, 30)
	ghost.Position = UDim2.new(0, pos.X, 0, pos.Y)
	ghost.BackgroundColor3 = GemActions.gradeColor(gradeId)
	ghost.ZIndex = 1000
	ghost.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ghost
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = ghost
	return ghost
end

function GemActions.create(deps)
	local self = {}
	local pending -- { slot, index, ctx, gem } - 서버 결과를 기다리는 요청 하나

	local function notifyPending()
		if deps.onPending then
			deps.onPending()
		end
	end

	-- 거절 연출: 유령이 원래 칸으로 돌아간다(0.2초). 유령이 없고 출발점도 없으면 토스트만.
	local function bounce(ctx, gradeId)
		local ghost = ctx.proxy
		if not (ghost and ghost.Parent) then
			ghost = ctx.fromPos and GemActions.makeGhost(deps.screenGui, ctx.fromPos, gradeId) or nil
		end
		if not ghost then
			return
		end
		local target = ctx.originPos
		if not target then
			ghost:Destroy()
			return
		end
		local seconds = GemData.ui.returnTweenSeconds
		local tween = TweenService:Create(ghost, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0, target.X, 0, target.Y) })
		tween:Play()
		task.delay(seconds + 0.05, function()
			ghost:Destroy()
		end)
	end

	local function reject(reason, gem, slot, ctx)
		Toast.push("TC", { text = GemActions.reasonText(reason, gem and gem.grade, slot), colorName = "danger", grade = "notice", seconds = 2.5, groupKey = "gemEquipReject" })
		bounce(ctx or {}, gem and gem.grade)
	end

	function self.isPending()
		return pending ~= nil
	end

	-- 미리 보이기: 이 보석(index)을 이 홈(slot)에 끼울 수 없는 이유(nil = 끼울 수 있다). 강화대에서 멀면 "far"(서버 규칙 - 서버가 같은 이유로 거절한다).
	function self.blockReason(slot, index)
		local state = deps.getState()
		local gem = state.gemInventory[index]
		if not gem then
			return "not_found"
		end
		local reason = Gem.socketBlockReason(state.slotUnlocked, slot, gem.grade)
		if reason then
			return reason
		end
		if not deps.isNear() then
			return "far"
		end
		return nil
	end

	-- 자동 장착 대상(가장 낮은 상한의 열린 홈). 반환: slot 또는 nil + 이유.
	function self.autoTarget(index)
		local state = deps.getState()
		local gem = state.gemInventory[index]
		if not gem then
			return nil, "not_found"
		end
		return Gem.autoSlot(state.slotUnlocked, state.gems, gem.grade)
	end

	-- [장착] 버튼 · 강조용: 지금 자동 장착이 되는가. 반환: true 또는 false + 이유.
	function self.canAutoEquip(index)
		if pending then
			return false, "busy"
		end
		local slot, reason = self.autoTarget(index)
		if not slot then
			return false, reason
		end
		if not deps.isNear() then
			return false, "far"
		end
		return true
	end

	-- 모든 입력이 지나는 유일한 장착 함수. 반환: 요청을 보냈으면 true.
	function self.equip(slot, index, ctx)
		ctx = ctx or {}
		if pending then -- 결과를 기다리는 중 - 새 입력은 무시(넘겨받은 드래그 유령은 정리)
			if ctx.proxy then
				ctx.proxy:Destroy()
			end
			return false
		end
		local state = deps.getState()
		local gem = state.gemInventory[index]
		local reason = self.blockReason(slot, index)
		if reason then
			reject(reason, gem, slot, ctx)
			return false
		end
		local mine = { slot = slot, index = index, ctx = ctx, gem = gem }
		pending = mine
		notifyPending()
		gemEquipRequest:FireServer(slot, index)
		task.delay(GemData.ui.resultTimeoutSeconds, function()
			if pending == mine then -- 결과가 안 왔다(서버가 못 받았거나 지연) - 잠금을 푼다
				pending = nil
				if mine.ctx.proxy then
					mine.ctx.proxy:Destroy()
				end
				notifyPending()
			end
		end)
		return true
	end

	-- 자동 장착(더블클릭 · 우클릭 · [장착] · 폰 [장착]): 대상 홈을 정해 equip을 부른다. 연출의 출발점은 그 홈 중심.
	function self.autoEquip(index, ctx)
		ctx = ctx or {}
		if pending then
			return false
		end
		local slot, reason = self.autoTarget(index)
		if not slot then
			local gem = deps.getState().gemInventory[index]
			reject(reason, gem, nil, ctx)
			return false
		end
		ctx.fromPos = ctx.fromPos or deps.slotCenter(slot)
		return self.equip(slot, index, ctx)
	end

	gemEquipResult.OnClientEvent:Connect(function(success, reason, slot)
		local mine = pending
		if not mine then
			return
		end
		pending = nil
		if success then
			if mine.ctx.proxy then
				mine.ctx.proxy:Destroy()
			end
			deps.onEquipped(mine.slot)
		else
			reject(reason, mine.gem, slot or mine.slot, mine.ctx)
		end
		notifyPending()
	end)

	return self
end

return GemActions
