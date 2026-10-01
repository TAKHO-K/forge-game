-- QUEUE-ALL6 G 판 털기 로켓단(클라 그림): 서버 BossEnvironment 로켓 → "rocket"(나만 - 내 캐릭터가 곡선을 그린다) · "rocketTwinkle"(아레나 멤버 전원 - 꼭대기 반짝 별 + 효과음).
--   곡선 = 오름(upSeconds · 빠르게 감속) → 꼭대기 멈춤(hangSeconds · 반짝) → 반대쪽 절반으로 천천히 내려옴(downSeconds · 부드럽게). 높이 = 서버가 준 같은 값(편차 없음).
--   그동안 조작 잠금(PlatformStand) · 내 캐릭터 물리 = 나라서 남의 화면에도 그대로 보인다. 무적 · 표적 제외 · 도착 확인은 서버.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SoundSheet = require(script.Parent.SoundSheet)

local BossRocketView = {}
local player = Players.LocalPlayer
local flying = nil

local function easeOut(t)
	return 1 - (1 - t) ^ 2
end
local function smooth(t)
	return t * t * (3 - 2 * t)
end

-- 순수: t초(시작부터)의 자리 - 검증 · 그림 같은 식
function BossRocketView.positionAt(data, t)
	local from, land = data.from, data.land
	local mid = Vector3.new((from.X + land.X) / 2, data.peakY, (from.Z + land.Z) / 2)
	if t <= data.up then
		local u = easeOut(t / data.up)
		local xz = from:Lerp(mid, u * 0.5)
		return Vector3.new(xz.X, from.Y + (data.peakY - from.Y) * u, xz.Z)
	elseif t <= data.up + data.hang then
		local xz = from:Lerp(mid, 0.5)
		return Vector3.new(xz.X, data.peakY + math.sin((t - data.up) / data.hang * math.pi) * 0.6, xz.Z)
	end
	local u = smooth(math.clamp((t - data.up - data.hang) / data.down, 0, 1))
	local start = from:Lerp(mid, 0.5)
	local xz = Vector3.new(start.X, 0, start.Z):Lerp(Vector3.new(land.X, 0, land.Z), u)
	return Vector3.new(xz.X, data.peakY + (land.Y - data.peakY) * u, xz.Z)
end

function BossRocketView.rocket(data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	if flying then
		flying:Disconnect()
	end
	local total = data.up + data.hang + data.down
	local started = os.clock()
	humanoid.PlatformStand = true
	player:SetAttribute("BossRocketing", true)
	local facing = root.CFrame.Rotation
	flying = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= total or not root.Parent then
			flying:Disconnect()
			flying = nil
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(data.land) * facing
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			player:SetAttribute("BossRocketing", nil)
			return
		end
		root.AssemblyLinearVelocity = Vector3.zero
		local spin = t <= data.up + data.hang and CFrame.Angles(0, t * 9, 0) or CFrame.identity -- 올라가며 빙글(내려올 땐 바로)
		root.CFrame = CFrame.new(BossRocketView.positionAt(data, t)) * facing * spin
	end)
end

-- 꼭대기 반짝(별 네 갈래 + 가운데 빛 · 0.7초) + 효과음 - 사람마다 따로(여럿이 동시에 날아가도 겹쳐 보인다)
function BossRocketView.twinkle(data)
	task.delay(data.delay or 0, function()
		local parts = {}
		for i = 1, 3 do
			local p = Instance.new("Part")
			p.Name = i < 3 and "RocketStarRay" or "RocketStarCore"
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Material = Enum.Material.Neon
			p.Color = i < 3 and Color3.fromRGB(255, 225, 90) or Color3.new(1, 1, 1)
			p.Shape = i < 3 and Enum.PartType.Block or Enum.PartType.Ball
			p.Transparency = 1
			p.Parent = Workspace
			parts[i] = p
		end
		local mine = data.userId == player.UserId
		SoundSheet.play(data.sound, { other = not mine }) -- QUEUE-ALL7 E3: T3(SoundMixData) · 남의 로켓 = 남의 소리 배율
		local started = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - started) / 0.7
			if t >= 1 then
				connection:Disconnect()
				for _, p in ipairs(parts) do
					p:Destroy()
				end
				return
			end
			local scale = math.sin(t * math.pi) * 2.6 + 0.2
			local facing = CFrame.new(data.position) * Workspace.CurrentCamera.CFrame.Rotation
			for i = 1, 2 do
				parts[i].Size = Vector3.new(0.6 * scale, 7 * scale, 0.6 * scale)
				parts[i].CFrame = facing * CFrame.Angles(0, 0, t * math.pi * 1.5 + (i - 1) * math.pi / 2)
				parts[i].Transparency = t * 0.6
			end
			parts[3].Size = Vector3.one * 1.8 * scale
			parts[3].CFrame = CFrame.new(data.position)
			parts[3].Transparency = t * 0.5
		end)
	end)
end

return BossRocketView
