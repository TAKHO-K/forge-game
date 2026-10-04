-- QUEUE-MENU2 D · E: 캐릭터 칸 원격 입구(RemoteFunction SlotRequest) - list · play(칸) · new · archive(칸) · restore(보관 번호) · toMenu. 처리 = SlotSwitch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlotSaveData = require(ReplicatedStorage.Shared.data.SlotSaveData)
local RequestGate = require(script.Parent.RequestGate)
local SlotSwitch = require(script.Parent.SlotSwitch)

-- 메인 메뉴 버그(10-05): 접속 즉시 캐릭터를 월드에 스폰하지 않는다 → 메뉴에서 입장(SlotRequest enterWorld · play · new)할 때 스폰. 자동 스폰을 끈 대신 쓰러짐 뒤 부활은 여기서(Players.RespawnTime 뒤).
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false
local function onJoin(player)
	SlotSwitch.holdAtJoin(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
			task.delay(Players.RespawnTime, function()
				if player.Parent and player.Character == character and not player:GetAttribute("InMainMenu") then
					player:LoadCharacter()
				end
			end)
		end)
	end)
end
Players.PlayerAdded:Connect(onJoin)
for _, player in ipairs(Players:GetPlayers()) do
	onJoin(player)
end

local remote = Instance.new("RemoteFunction")
remote.Name = "SlotRequest"
remote.Parent = ReplicatedStorage

remote.OnServerInvoke = function(player, action, arg)
	return RequestGate.invoke(player, "SlotRequest", tostring(action) .. ":" .. tostring(arg), function()
		if action == "enterWorld" then -- 메인 메뉴 버그(10-05): 메뉴 → 월드(슬롯 스위치와 무관)
			local ok, why = SlotSwitch.enterWorld(player)
			return { ok = ok, reason = why }
		end
		if action == "tutorialReplay" then -- MENU2 판정 3: 설정 [튜토리얼 다시 보기](슬롯 스위치와 무관)
			local ok, why = require(script.Parent.TutorialState).replay(player)
			return { ok = ok, reason = why }
		end
		if not SlotSaveData.enabled then
			return { ok = false, reason = "disabled" }
		end
		if action == "list" then
			return SlotSwitch.list(player)
		elseif action == "play" then
			local ok, why = SlotSwitch.switch(player, arg)
			return { ok = ok, reason = why }
		elseif action == "new" then
			local ok, why = SlotSwitch.switch(player, "new")
			return { ok = ok, reason = why }
		elseif action == "toMenu" then
			local ok, why = SlotSwitch.toMenu(player)
			return { ok = ok, reason = why }
		elseif action == "archive" then
			local ok, why = SlotSwitch.archive(player, arg)
			return { ok = ok, reason = why }
		elseif action == "restore" then
			local ok, slot = SlotSwitch.restore(player, arg)
			return { ok = ok, reason = not ok and slot or nil, slot = ok and slot or nil }
		end
		return { ok = false, reason = "unknown" }
	end)
end
