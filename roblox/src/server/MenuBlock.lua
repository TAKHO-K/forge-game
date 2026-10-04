-- MENU2 판정 4(10-05): 메뉴 이동 · 캐릭터 전환 금지 시간창(강화 · 재련 · 계승 연출 · 선물 받기 직후). 보스전 · 계승 저장 대기는 SlotSwitch.blockReason이 따로 본다.
--   서비스가 처리 끝에 mark(player, kind)만 부른다 - 연출 길이 = SlotSaveData.blockAfterSeconds[kind]. 화면 = 속성 MenuBlock(이유) · MenuBlockUntil(서버 시각).
--   거래(유저 간) = 기능 없음(MonetizationData.gifts.userToUser.enabled = false) - 생기면 진행 중에 mark(player, "trade") 한 줄.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlotSaveData = require(ReplicatedStorage.Shared.data.SlotSaveData)

local MenuBlock = {}
local untilAt = {} -- [Player] = { [kind] = os.clock() 끝 }

function MenuBlock.mark(player, kind)
	local seconds = SlotSaveData.blockAfterSeconds[kind]
	if not seconds then
		return
	end
	untilAt[player] = untilAt[player] or {}
	untilAt[player][kind] = os.clock() + seconds
	if typeof(player) == "Instance" then
		player:SetAttribute("MenuBlock", kind)
		player:SetAttribute("MenuBlockUntil", workspace:GetServerTimeNow() + seconds)
	end
end

-- 지금 막는 이유(nil = 없음) - 끝난 것은 지운다
function MenuBlock.reason(player)
	local t = untilAt[player]
	if not t then
		return nil
	end
	local now = os.clock()
	for kind, at in pairs(t) do
		if at > now then
			return kind
		end
		t[kind] = nil
	end
	return nil
end

function MenuBlock.clear(player)
	untilAt[player] = nil
end

game:GetService("Players").PlayerRemoving:Connect(MenuBlock.clear)

return MenuBlock
