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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLabelStyle = require(ReplicatedStorage.Shared.WorldLabelStyle)

local TeleportPad = {}

local TELEPORT_COOLDOWN_SECONDS = 1.5
local lastTeleportAt = setmetatable({}, { __mode = "k" }) -- [Player] = os.clock()

-- 표지판(17-1 후속 - "포탈 표지판을 진짜 표지판으로"). BillboardGui는 항상 카메라를
-- 향해 돌아서 탑다운 시점에서 화면이 난잡해졌다 - 이 게임의 카메라는 수평에서 아래로
-- 약 15도 내려다보는 각도로 고정되어 있으므로(실측), 판자를 그 각도만큼 뒤로 젖혀
-- 세워두면 카메라를 돌리지 않는 한 항상 정면으로 보인다. SurfaceGui로 판자 Part
-- 표면에 직접 그린다 - 판자 자체가 배경이라 반투명 배경 Frame이 필요 없다.
local POST_HEIGHT_STUDS = 3
local BOARD_WIDTH_STUDS = 5.5
local BOARD_HEIGHT_STUDS = 2.6
local BOARD_THICKNESS_STUDS = 0.2
local BOARD_TILT_DEGREES = 20 -- 실측 카메라 각도(15도)보다 약간 크게 잡아 근접 시야에서도 눕지 않게
local SIGN_MAX_DISTANCE_STUDS = 200

-- 판자가 마주볼 수평 방향(플레이어가 다가오는 쪽). 없으면 기본값(-Z)을 쓴다.
local function normalizeFacing(facingDirection)
	if not facingDirection then
		return Vector3.new(0, 0, -1)
	end
	local flat = Vector3.new(facingDirection.X, 0, facingDirection.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

function TeleportPad.create(position, label, color, destination, facingDirection)
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

	local signPost = Instance.new("Part")
	signPost.Name = "SignPost"
	signPost.Size = Vector3.new(0.5, POST_HEIGHT_STUDS, 0.5)
	signPost.Anchored = true
	signPost.CanCollide = false
	signPost.Material = Enum.Material.Metal
	signPost.Color = Color3.fromRGB(60, 60, 65)
	signPost.Position = position + Vector3.new(0, POST_HEIGHT_STUDS / 2, 0)
	signPost.Parent = Workspace

	local facing = normalizeFacing(facingDirection)
	local boardCenter = position + Vector3.new(0, POST_HEIGHT_STUDS + BOARD_HEIGHT_STUDS / 2, 0)

	local board = Instance.new("Part")
	board.Name = "SignBoard"
	board.Size = Vector3.new(BOARD_WIDTH_STUDS, BOARD_HEIGHT_STUDS, BOARD_THICKNESS_STUDS)
	board.Anchored = true
	board.CanCollide = false
	board.Material = Enum.Material.Metal
	board.Color = color
	board.CFrame = CFrame.lookAt(boardCenter, boardCenter + facing) * CFrame.Angles(math.rad(BOARD_TILT_DEGREES), 0, 0)
	board.Parent = Workspace

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.AlwaysOnTop = true
	surfaceGui.Adornee = board
	surfaceGui.Parent = board
	WorldLabelStyle.setupSignSurface(surfaceGui, SIGN_MAX_DISTANCE_STUDS)

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 1, 0)
	text.Text = label
	text.TextColor3 = Color3.fromRGB(245, 245, 245)
	text.TextWrapped = true
	text.Parent = surfaceGui
	WorldLabelStyle.styleSignText(text, 44)

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
