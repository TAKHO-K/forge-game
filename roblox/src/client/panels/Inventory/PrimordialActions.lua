-- D1 장비 상세의 태초 전용 조각(창 전면 재구성은 U1): [각성] 버튼 · 태초 각인 한 줄 · 잠금 해제 이중 확인 문구.
-- DetailSheet가 만든 버튼 틀(makeActionButton)과 힌트 줄(setHint)을 받아 쓴다 - DetailSheet 최상위 local 수를 늘리지 않으려고 따로 둔다(레지스터 한계).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Awaken = require(ReplicatedStorage.Shared.Awaken)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local PrimordialStamp = require(ReplicatedStorage.Shared.PrimordialStamp)

local PrimordialActions = {}

local player = Players.LocalPlayer

function PrimordialActions.create(makeActionButton, setHint)
	local self = {}
	local button = makeActionButton(2, 96, "awaken") -- QUEUE-ALL2 P2(ref 17): 흰 바탕 각성 버튼
	button.Name = "AwakenButton"
	button.Text = "각성"
	button.Visible = false
	local target -- { kind, key }

	local awakenRequest = ReplicatedStorage:WaitForChild("AwakenRequest")
	local awakenResult = ReplicatedStorage:WaitForChild("AwakenResult")
	awakenResult.OnClientEvent:Connect(function(ok, value)
		if ok then
			setHint(("각성 완료 - 아이템 레벨 %d"):format(value))
		else
			setHint(Awaken.reasonText[value] or tostring(value), true)
		end
	end)
	button.Activated:Connect(function()
		if target and button.Active then
			awakenRequest:FireServer(target.kind, target.key, target.no)
		end
	end)

	-- kind = "bag" | "equip" | nil(숨김). 태초 · 초월이면 각성 버튼.
	function self.refresh(kind, key, item, hintBusy)
		target = nil
		button.Visible = false
		if not kind or not item or (item.grade ~= "primordial" and item.grade ~= "transcendent") then -- C5-7 초월도 각성(무료)
			return
		end
		local best = player:GetAttribute("AccountBestStage") or 1
		local reason = Awaken.blockReason(item, best)
		target = { kind = kind, key = key, no = item.primordial and item.primordial.no }
		button.Visible = true
		button.Active = reason == nil
		button.AutoButtonColor = reason == nil
		button.TextTransparency = reason == nil and 0 or 0.6
		button.Text = reason == nil and (Awaken.cost(best, item) == 0 and "각성(무료)" or ("각성 %s"):format(NumberFormat.format(Awaken.cost(best, item)))) or "각성"
		-- QUEUE-ALL2 P2: 태초 각인 줄(세계 번호 · 최초 획득 · 출처)은 상세 카드의 세계 번호 칸(DetailCard)이 보여 준다 - 이유 줄(hint)에는 더 쓰지 않는다(hintBusy는 옛 호출 모양 유지용).
		local _ = hintBusy
	end

	function self.button()
		return button
	end
	return self
end

-- 잠금 해제 이중 확인 문구(첫째 · 둘째). item.primordial이 있으면 세계 번호를 적는다.
function PrimordialActions.unlockTexts(item)
	local head = PrimordialStamp.numberText(item.primordial) or "태초"
	return ("%s의 잠금을 풀까요? 풀면 분해 · 판매 · 계승 재료로 쓸 수 있어요."):format(head),
		("정말 풀까요? %s은(는) 다시 얻기 매우 어려워요."):format(head)
end

return PrimordialActions
