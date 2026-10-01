-- QUEUE-ALL7 D3: 설정 한 칸 바꾸기(공통 입구) - SettingsData 키의 Attribute를 바로 바꾸고(화면 즉시) 서버 SettingsSave로 저장 요청(재접속 유지).
--   Settings 창 밖에서 바꾸는 설정(미니맵 켜기 · 확대 · 회전 · 지도 첫 안내)이 같은 길을 쓴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsData = require(ReplicatedStorage.Shared.data.SettingsData)

local player = Players.LocalPlayer

return function(key, value)
	local def = SettingsData.keys[key]
	if not def then
		return
	end
	for _, attr in ipairs(def.attrs) do
		player:SetAttribute(attr, value)
	end
	local remote = ReplicatedStorage:FindFirstChild("SettingsSave")
	if remote then
		remote:FireServer(key, value)
	end
end
