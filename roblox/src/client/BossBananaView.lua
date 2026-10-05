-- GUARDIAN-V3 바나나 투사체 그림(판정 무관 - 자리 · 방향은 서버 projSpawn/projSync가 정하고 BossBR1View가 움직인다).
--   acquire() → 풀에서 바나나 한 개(메시 = 교체 슬롯 GuardianBanana → BossFrameworkData.meshSlots → 메시 캐시 · 캐시가 없으면 파트 바나나) · release(part) = 풀로(파괴 없음).
--   hold(data) = 던지기 예비(0.45초) 동안 보스 오른손에 든 바나나가 빛난다(같은 풀 · 끝나면 돌려놓는다).
--   꼬리 = Trail(풀 파트에 붙은 채 다시 쓴다 - 꺼낼 때 Clear). 색 = 노랑 몸 + 보라 빛(BossFxData.guardianBanana).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
local BossFrameworkData = require(ReplicatedStorage.Shared.data.BossFrameworkData)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)

local B = BossFxData.guardianBanana
local BossBananaView = {}

local FAR = CFrame.new(0, -5000, 0)
local folder = nil
local pool = {}
local made = 0

-- 메시 캐시의 첫 MeshPart(없으면 nil - 아트 스위치 끔 · 아직 못 불러옴)
local function meshTemplate()
	local key = BossFrameworkData.meshSlots.GuardianBanana
	local model = key and ArtMeshKit.get(key)
	if not model then
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("MeshPart") then
			return d
		end
	end
	return nil
end

local function build()
	local template = meshTemplate()
	local part
	if template then
		part = template:Clone()
		part:ClearAllChildren()
		local s = part.Size
		part.Size = s * (B.lengthStuds / math.max(s.X, s.Y, s.Z))
		part.Color = B.color -- 메시는 색 없음(임시 자수정 바나나 - 각진 면) → 노랑 Neon + 보라 빛
		part.Material = Enum.Material.Neon
	else
		-- 파트 바나나(캐시 없음): 노랑 원통 + 보라 빛
		part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(B.lengthStuds, 1.1, 1.1)
		part.Color = B.color
		part.Material = Enum.Material.Neon
	end
	part.Name = "GuardianBanana"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = B.glow, 10, 2
	light.Parent = part
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.4, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.4, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = B.trail.lifetime
	trail.WidthScale = NumberSequence.new(B.trail.width0, B.trail.width1)
	trail.Color = ColorSequence.new(B.color, B.glow)
	trail.Transparency = NumberSequence.new(B.trail.transparency0, 1)
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = part
	part.CFrame = FAR
	part.Parent = folder
	made += 1
	return part
end

function BossBananaView.acquire()
	if not (folder and folder.Parent) then
		folder = Instance.new("Folder")
		folder.Name = "BossBananaPool"
		folder.Parent = Workspace
		pool, made = {}, 0
	end
	local part = table.remove(pool)
	if not part then
		if made >= B.poolMax then
			return nil -- 풀 상한(파티 4 × 3갈래) - 넘으면 그 한 발은 안 그린다(판정은 서버)
		end
		part = build()
	end
	part.Transparency = 0
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail:Clear()
		trail.Enabled = true
	end
	return part
end

function BossBananaView.release(part)
	if not part then
		return
	end
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = false
	end
	part.CFrame = FAR
	table.insert(pool, part)
end

-- 날아가는 바나나 자세(부메랑처럼 돈다)
function BossBananaView.pose(part, position, now)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, now * B.spinHz * 2 * math.pi, math.rad(90))
end

-- 던지기 예비(near = 보스 자리 - 가장 가까운 손 있는 보스): 보스 오른손(Hand_R)에 든 바나나가 0 → 1로 빛난다(seconds 뒤 풀로 - 실제 투사체는 projSpawn이 새로 꺼낸다)
function BossBananaView.hold(near, seconds)
	local model, best = nil, math.huge
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("Monster")) do
		local root = m.PrimaryPart
		if root and m:FindFirstChild("Hand_R") and (root.Position - near).Magnitude < best then
			model, best = m, (root.Position - near).Magnitude
		end
	end
	local hand = model and model:FindFirstChild("Hand_R")
	if not (hand and hand:IsA("BasePart")) then
		return
	end
	local part = BossBananaView.acquire()
	if not part then
		return
	end
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = false
	end
	local light = part:FindFirstChildOfClass("PointLight")
	local start = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local u = (os.clock() - start) / math.max(seconds, 0.05)
		if u >= 1 or not hand.Parent then
			conn:Disconnect()
			if light then
				light.Brightness = 2
			end
			BossBananaView.release(part)
			return
		end
		part.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.45, 0) * CFrame.Angles(0, 0, math.rad(90))
		if light then
			light.Brightness = 1 + 5 * u
			light.Range = 8 + 8 * u
		end
	end)
end

function BossBananaView.stats()
	return { made = made, idle = #pool }
end

return BossBananaView
