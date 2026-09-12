-- 텔레포트 패드(16-6) - 밟으면 목적지로 순간이동. 리스폰 구역의 tier별 출발 패드 6개와
-- 각 tier 구역 입구의 중앙 복귀 패드가 전부 이 모듈 하나로 만들어진다(지시 - "포탈
-- 패드에 tier 번호와 대표 몬스터 이름을 표시해라. 어디로 가는지 모르면 안 된다" - 라벨
-- 인자를 그대로 BillboardGui 텍스트로 쓴다).
--
-- 걷기 이동을 막지 않는다 - 패드는 구역 사이 통로를 대체하지 않고(통로는 원래 열려
-- 있다), 그 위를 밟았을 때만 추가로 순간이동시키는 지름길이다(지시 그대로).
--
-- 쿨다운은 플레이어별로 공유한다(패드별이 아니라) - 출발 패드를 밟아 도착한 자리가
-- 마침 복귀 패드 바로 옆이라, 패드별로 따로 재면 도착 즉시 되튕겨 나가는 왕복 루프가
-- 생길 수 있다. 같은 플레이어의 모든 패드가 하나의 타이머를 공유하면 이 문제가
-- 구조적으로 없어진다.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TeleportPad = {}

local TELEPORT_COOLDOWN_SECONDS = 1.5
local lastTeleportAt = setmetatable({}, { __mode = "k" }) -- [Player] = os.clock()

function TeleportPad.create(position, label, color, destination)
	local pad = Instance.new("Part")
	pad.Name = "TeleportPad"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(1, 6, 6)
	pad.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	pad.Anchored = true
	pad.CanCollide = false
	pad.Material = Enum.Material.Neon
	pad.Color = color
	pad.Transparency = 0.25
	pad.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(5, 0, 1.8, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = pad
	billboard.Parent = pad

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 1, 0)
	text.Text = label
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.TextWrapped = true
	text.Font = Enum.Font.GothamBold
	text.Parent = billboard

	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if lastTeleportAt[player] and now - lastTeleportAt[player] < TELEPORT_COOLDOWN_SECONDS then
			return
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		lastTeleportAt[player] = now
		root.CFrame = CFrame.new(destination)
	end)

	return pad
end

return TeleportPad
