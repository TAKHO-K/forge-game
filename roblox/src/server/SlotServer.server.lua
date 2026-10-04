-- QUEUE-MENU2 D · E: 캐릭터 칸 원격 입구(RemoteFunction SlotRequest) - list · play(칸) · new · archive(칸) · restore(보관 번호) · toMenu. 처리 = SlotSwitch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlotSaveData = require(ReplicatedStorage.Shared.data.SlotSaveData)
local RequestGate = require(script.Parent.RequestGate)
local SlotSwitch = require(script.Parent.SlotSwitch)

local remote = Instance.new("RemoteFunction")
remote.Name = "SlotRequest"
remote.Parent = ReplicatedStorage

remote.OnServerInvoke = function(player, action, arg)
	return RequestGate.invoke(player, "SlotRequest", tostring(action) .. ":" .. tostring(arg), function()
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
