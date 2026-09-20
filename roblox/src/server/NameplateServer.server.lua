-- 기본 머리 위 이름표를 끈다(S12b D). 커스텀 이름표("★n Lv.35 표시이름")는 client/Nameplate.client.lua가 그린다 - 기본 이름표가 같이 뜨면 이름이 두 번 나온다.
-- 서버에서 한 번 꺼 두면 모든 클라에 복제된다(접속 · 리스폰 · 나중에 들어온 사람 모두).

local Players = game:GetService("Players")

local function hideDefaultName(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function watch(player)
	if player.Character then
		task.spawn(hideDefaultName, player.Character)
	end
	player.CharacterAdded:Connect(hideDefaultName)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
