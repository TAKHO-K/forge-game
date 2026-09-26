-- MV1 낙하(사용자 결정 - 불꽃과 낙사). 판정은 서버(FallServer) · 이 스크립트는 ① 자기 착지 속도 보고 ② 그리기(불꽃 꼬리 · 그을림 · "쿵!" 쓰러짐)만 한다. 수치 = MovementConfig.fall.
--   ① 자기 캐릭터: 체공 중 매 프레임 세로 속도를 기억했다가 착지(Landed · Running · 헤엄) 순간 직전 프레임의 아래 속도를 FallLanded로 보낸다(안전 높이의 낙하 속도 이상일 때만).
--      표시 = 물 착지(water) · 사다리에서 떨어짐(ladder - 오르기 상태에서 곧장 공중). 넉백 · 무너짐 잠금(AirLocked)은 보내지 않는다(서버도 발사 허가로 뺀다).
--   ② 불꽃: 예상 피해 flameWarnFraction(50%) 이상인 속도로 떨어지는 모든 캐릭터(내 화면 maxDistance 안)의 루트에 로블록스 기본 Fire + Trail 꼬리(새 에셋 없음 · 색 = UIColors xp → hp) · 활강 · 보스전 · 나무 둘레는 없음.
--      Fire만으로는 초속 300에서 입자가 뒤로 흩어져 안 보였다(MV1 스크린샷) - 몸에 붙어 위로 늘어지는 꼬리(Trail)가 주 모양.
--   ③ 그을림: Character Attribute CharredUntil(서버 시각)까지 어두운 채움 Highlight(charredColor · 채움 = charredBlend).
--   ④ 쓰러짐: Character Attribute FallKnockdown 동안 뒤로 눕는 자세 + 머리 위 "쿵!" + (자기면) 카메라 흔들림.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local AirMotion = require(script.Parent.AirMotion)
local CameraShake = require(script.Parent.CameraShake)

local F = MovementConfig.fall
local SAFE_SPEED, FLAME_SPEED = require(ReplicatedStorage.Shared.MoveRules).fallSpeeds() -- 보고 문턱(안전 높이) · 불꽃 문턱(예상 피해 50%)
local player = Players.LocalPlayer
local fallLanded = ReplicatedStorage:WaitForChild("FallLanded")

local AIR = { [Enum.HumanoidStateType.Jumping] = true, [Enum.HumanoidStateType.Freefall] = true }
local LAND = { [Enum.HumanoidStateType.Landed] = true, [Enum.HumanoidStateType.Running] = true, [Enum.HumanoidStateType.RunningNoPhysics] = true, [Enum.HumanoidStateType.Swimming] = true }

-- ── ① 자기 착지 ──
local track = { airborne = false, lastVy = 0, fromLadder = false, prevState = nil }

local function bindSelf(character)
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	track.airborne, track.lastVy, track.fromLadder = false, 0, false
	humanoid.StateChanged:Connect(function(old, new)
		if AIR[new] and not track.airborne then
			track.airborne = true
			track.fromLadder = old == Enum.HumanoidStateType.Climbing
			track.lastVy = root.AssemblyLinearVelocity.Y
		elseif LAND[new] and track.airborne then
			track.airborne = false
			local speed = -track.lastVy
			character:SetAttribute("MV1LastLandingSpeed", speed) -- 계측(검증)
			if speed >= SAFE_SPEED and not character:GetAttribute("AirLocked") then
				fallLanded:FireServer(speed, { water = new == Enum.HumanoidStateType.Swimming, ladder = track.fromLadder })
			end
		elseif new == Enum.HumanoidStateType.Climbing then
			track.airborne = false
		end
	end)
end
if player.Character then
	task.spawn(bindSelf, player.Character)
end
player.CharacterAdded:Connect(bindSelf)

-- ── ②③④ 모든 캐릭터 그리기 ──
local charred = {} -- [character] = Highlight
local knocked = {} -- [character] = BillboardGui

local function flameExcluded(other, character, root)
	if character:GetAttribute("Gliding") or other:GetAttribute("BossEncounterId") or character:GetAttribute("AirLocked") then
		return true
	end
	return Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude <= WorldMapData.progress.treeRadius
end

local function setCharred(character, on)
	-- 몸 파트 색을 바꾸면 캐릭터의 BodyColors가 덮고 옷(텍스처)은 그대로라 안 보였다(MV1 스크린샷) - 어두운 채움 Highlight 하나(외곽선 없음 · 가려지면 안 보임)로 옷까지 그을린다.
	if on and not charred[character] then
		local h = Instance.new("Highlight")
		h.Name = "MV1Charred"
		h.FillColor = F.charredColor
		h.FillTransparency = 1 - F.charredBlend
		h.OutlineTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = character
		h.Parent = character
		charred[character] = h
	elseif not on and charred[character] then
		charred[character]:Destroy()
		charred[character] = nil
	end
end

local function setKnocked(character, root, on, isSelf)
	if on and not knocked[character] then
		AirMotion.hold(character, "knockdown", -80) -- 뒤로 벌렁
		local gui = Instance.new("BillboardGui")
		gui.Name = "MV1FallThud"
		gui.Size = UDim2.new(0, 120, 0, 56)
		gui.StudsOffset = Vector3.new(0, 4.5, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = root
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "쿵!"
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = UIColors.xp
		label.TextStrokeColor3 = UIColors.panel
		label.TextStrokeTransparency = 0
		label.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		knocked[character] = gui
		if isSelf then
			CameraShake.trigger(0.35, 0.8)
		end
	elseif not on and knocked[character] then
		AirMotion.release(character, "knockdown")
		knocked[character]:Destroy()
		knocked[character] = nil
	end
end

RunService.Heartbeat:Connect(function()
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local serverNow = Workspace:GetServerTimeNow()
	local seen = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			seen[character] = true
			local vy = root.AssemblyLinearVelocity.Y
			if other == player and track.airborne then
				track.lastVy = vy
			end
			local near = myRoot == nil or (root.Position - myRoot.Position).Magnitude <= F.flame.maxDistance
			local fire = root:FindFirstChild("MV1FallFlame")
			local wantFire = near and -vy >= FLAME_SPEED and not flameExcluded(other, character, root)
			if wantFire and not fire then
				fire = Instance.new("Fire")
				fire.Name = "MV1FallFlame"
				fire.Size = F.flame.size
				fire.Heat = F.flame.heat
				fire.Parent = root
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Name, a1.Name = "MV1FlameA0", "MV1FlameA1"
				a0.Position, a1.Position = Vector3.new(-1.3, 0, 0), Vector3.new(1.3, 0, 0)
				a0.Parent, a1.Parent = root, root
				local trail = Instance.new("Trail")
				trail.Name = "MV1FlameTrail"
				trail.Attachment0, trail.Attachment1 = a0, a1
				trail.Lifetime = 0.18
				trail.LightEmission = 0.15 -- 밝은 하늘에서 1은 하얗게 날아갔다(MV1 스크린샷)
				trail.FaceCamera = true
				trail.Color = ColorSequence.new(UIColors.xp, UIColors.hp)
				trail.Transparency = NumberSequence.new(0.05, 1)
				trail.Parent = fire
			elseif not wantFire and fire then
				fire:Destroy()
				for _, n in ipairs({ "MV1FlameA0", "MV1FlameA1" }) do
					local a = root:FindFirstChild(n)
					if a then
						a:Destroy()
					end
				end
			end
			setCharred(character, (character:GetAttribute("CharredUntil") or 0) > serverNow)
			setKnocked(character, root, character:GetAttribute("FallKnockdown") == true, other == player)
		end
	end
	for character in pairs(charred) do
		if not seen[character] then
			charred[character] = nil
		end
	end
	for character, gui in pairs(knocked) do
		if not seen[character] then
			gui:Destroy()
			knocked[character] = nil
		end
	end
end)
