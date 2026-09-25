-- 3타 강타 표시(G1-1 · D0 결정 6 A + C). 옛 표시(체력바 위 점 3개)는 시선이 캐릭터 ↔ 화면 아래를 오가서, 내 발밑 3칸 고리로 옮겼다(로컬 전용 - 남에게 안 보인다).
--   A: 발밑(카메라 쪽 반원)에 칸 3개 - 이번 3타 사이클의 몇 번째인지 채운다. 서버 ComboUpdate(comboCount 누적값)를 comboHitEvery로 감싼다.
--   C: 다음 타가 강타(2칸 찬 상태)면 조준 대상의 외곽선 색을 바꾼다(AimTarget.setHeavyReady - 추가 UI 없음).
--   리셋: 서버 규칙(마지막 공격 뒤 comboResetWindowSeconds)과 같은 시간이 지나면 클라도 끈다 - 옛 점은 쉬고 나도 켜진 채 남았다(D0 (i)).
-- 판정은 건드리지 않는다(표시만). 칸은 기본 Part(Neon 원판) - 새 에셋 없음.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local AimTarget = require(script.Parent.AimTarget)

local ComboRing = {}

local COUNT = CombatConfig.comboHitEvery
local RADIUS = 2.4 -- 발 중심에서 칸까지(캐릭터 반폭 1 + 여유)
local SPREAD_DEG = 34 -- 칸 사이 각(카메라 쪽 반원 가운데를 기준으로 좌우로 편다)
local DISC_SIZE = 0.8
local OFF_COLOR = Color3.fromRGB(255, 255, 255)
local OFF_TRANSPARENCY = 0.7
local ON_COLOR = UIColors.ember
local HEAVY_COLOR = Color3.fromRGB(255, 230, 90) -- 옛 강타 점과 같은 값

local player = Players.LocalPlayer
local discs = {}
local filled, heavyShown, lastComboAt = 0, false, 0

local function build()
	for i = 1, COUNT do
		local disc = Instance.new("Part")
		disc.Name = "ComboRingDisc" .. i
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.08, DISC_SIZE, DISC_SIZE)
		disc.Material = Enum.Material.Neon
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanQuery = false
		disc.CanTouch = false
		disc.CastShadow = false
		disc.Parent = Workspace.CurrentCamera
		discs[i] = disc
	end
end

local function paint()
	for i, disc in ipairs(discs) do
		local on = i <= filled
		disc.Color = on and (heavyShown and HEAVY_COLOR or ON_COLOR) or OFF_COLOR
		disc.Transparency = on and 0 or OFF_TRANSPARENCY
	end
	AimTarget.setHeavyReady(filled == COUNT - 1) -- 다음 타가 강타
end

-- 서버 ComboUpdate 한 번. comboCount = 누적값 · isHeavyHit = 이번 타가 강타였는가.
function ComboRing.onCombo(comboCount, isHeavyHit)
	filled = ((comboCount - 1) % COUNT) + 1
	heavyShown = isHeavyHit == true
	lastComboAt = os.clock()
	paint()
end

function ComboRing.reset()
	filled, heavyShown = 0, false
	paint()
end

build()
paint()

RunService.RenderStepped:Connect(function()
	if filled > 0 and os.clock() - lastComboAt > CombatConfig.comboResetWindowSeconds then
		ComboRing.reset()
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local visible = root ~= nil and humanoid ~= nil and humanoid.Health > 0
	if not visible then
		for _, disc in ipairs(discs) do
			disc.Transparency = 1
		end
		return
	end
	local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 - 0.06, 0)
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local toward = Vector3.new(-look.X, 0, -look.Z)
	toward = toward.Magnitude > 1e-3 and toward.Unit or Vector3.new(0, 0, 1)
	local base = math.atan2(toward.Z, toward.X)
	for i, disc in ipairs(discs) do
		local angle = base + math.rad((i - (COUNT + 1) / 2) * SPREAD_DEG)
		local at = feet + Vector3.new(math.cos(angle) * RADIUS, 0, math.sin(angle) * RADIUS)
		disc.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
		disc.Transparency = i <= filled and 0 or OFF_TRANSPARENCY
	end
end)

return ComboRing
