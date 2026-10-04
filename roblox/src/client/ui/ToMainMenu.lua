-- QUEUE-MENU2 C · D: 게임 안 [메인 메뉴로] 한 곳(설정 [게임] · 캐릭터 창의 직업 변경 자리).
--   확인 창 "메인 메뉴로 이동합니다. 진행 상황은 저장되고 파티에서 나가게 됩니다." → SlotRequest toMenu(서버: 금지 상태 · 저장 · 파티 해제 · 캐릭터 빼기) → 메인 메뉴 다시 열기(MainMenu OpenMainMenu).
--   금지 상태(보스전 · 토벌 · 잔류 = BossEncounterId) = 버튼 회색 + 이유 1줄 · 서버도 같은 판정(SlotSwitch.blockReason)으로 거절한다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local SlotSaveData = require(ReplicatedStorage.Shared.data.SlotSaveData)
local Confirm = require(script.Parent.kit.Confirm)
local Toast = require(script.Parent.kit.Toast)

local player = Players.LocalPlayer
local ToMainMenu = {}

function ToMainMenu.available()
	return SlotSaveData.enabled and ReplicatedStorage:FindFirstChild("SlotRequest") ~= nil
end

-- 화면 쪽 금지 사유(nil = 됨) - 서버가 최종 판정
function ToMainMenu.blockReason()
	if player:GetAttribute("BossEncounterId") then
		return "boss"
	end
	return nil
end

local function openMenu()
	local menu = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("MainMenu", true)
	local signal = menu and menu:FindFirstChild("OpenMainMenu")
	if signal then
		signal:Fire()
	end
end

-- 거절 이유 글(메뉴 이동 전용 → 칸 공용 → 기본)
function ToMainMenu.errText(why)
	if SlotSaveData.blockReasons[why] then
		return Text.get("menu.toMenuBlocked." .. why)
	end
	return Text.get(SlotSaveData.errorReasons[why] and ("menu.slot.err." .. why) or "menu.slot.err.default")
end

local function toast(text)
	Toast.push("TC", { richParts = { { text = text, colorName = "textPrimary", bold = true } }, seconds = 3, fadeSeconds = 0.3 })
end

function ToMainMenu.request(parentId)
	local reason = ToMainMenu.blockReason()
	Confirm.ask({
		title = Text.get("menu.toMenu"), body = Text.get("menu.toMenuConfirm"),
		primaryText = Text.get("menu.slot.confirm"), secondaryText = Text.get("menu.slot.cancel"),
		parentId = parentId, primaryEnabled = reason == nil, reason = reason and Text.get("menu.toMenuBlocked." .. reason) or nil,
	}, function(accepted)
		if not accepted then
			return
		end
		local remote = ReplicatedStorage:FindFirstChild("SlotRequest")
		local ok, res = pcall(function()
			return remote:InvokeServer("toMenu")
		end)
		if ok and res and res.ok then
			require(script.Parent.Parent.UIManager).closeAll()
			openMenu()
		else
			toast(ToMainMenu.errText(ok and res and res.reason))
		end
	end)
end

-- 버튼 상태(회색 + 이유) 다시 그리기 - button = Button.build 결과(setEnabled가 없으면 root.Active/투명도), reasonLabel = TextLabel
function ToMainMenu.bindState(buttonRefs, reasonLabel)
	local function paint()
		local reason = ToMainMenu.blockReason()
		local root = buttonRefs.root or buttonRefs
		if buttonRefs.setEnabled then
			buttonRefs.setEnabled(reason == nil)
		else
			root.AutoButtonColor = reason == nil
			root.BackgroundTransparency = reason and 0.6 or 0
		end
		if reasonLabel then
			reasonLabel.Text = reason and Text.get("menu.toMenuBlocked." .. reason) or ""
			reasonLabel.Visible = reason ~= nil
		end
	end
	player:GetAttributeChangedSignal("BossEncounterId"):Connect(paint)
	paint()
end

return ToMainMenu
