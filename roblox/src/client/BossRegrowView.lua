-- 지형 재생성 · 끼임 연출(P3d D - 판정 없음, 서버 BossPatterns · BossArenaMap이 보내는 사실만 그린다).
--   telegraph(regrowTelegraph): 솟을 자리마다 그림자(어두운 원판이 자란다) + 위험색 테두리 + 금 가는 빛(흰 금이 길어진다) - 전조 seconds 동안. 전조 조각은 상한에 안 걸린다(essential).
--     그림자 반경 = 충돌 원 반경(보이는 것 = 판정 - 몸이 닿으면 맞는다).
--   spawn(regrowSpawn): 솟는 순간 둘레 흙먼지 · 튀는 조각 · 흰 고리 + 가까우면 짧은 흔들림.
--   끼임(BossArenaEncase): 끼인 사람 머리 위 "탈출! n타" + 남은 시간 막대. 친구 화면에도 뜬다(부수러 올 수 있게). n = 0이면 지운다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
local BossFx = require(script.Parent.BossFx)

local BossRegrowView = {}

local DANGER_COLOR = UIColors.danger
local SHADOW_COLOR = Color3.fromRGB(20, 18, 24)
local GLOW_COLOR = Color3.new(1, 1, 1)
local DUST_COLOR = Color3.fromRGB(235, 228, 214)

local rng = Random.new()

function BossRegrowView.telegraph(data)
	local seconds = data.seconds or 1.5
	for _, c in ipairs(data.colliders or {}) do
		local base = Vector3.new(c.center.X, (data.floorY or c.center.Y) + 0.14, c.center.Z)
		-- 그림자: 반경 0.5r → r로 자라며 짙어진다
		BossFx.spawn({ essential = true, shape = "cylinder", position = base, rotation = CFrame.Angles(0, 0, math.rad(90)),
			size0 = Vector3.new(0.1, c.r, c.r), size1 = Vector3.new(0.1, c.r * 2, c.r * 2), color = SHADOW_COLOR,
			transparency0 = 0.75, transparency1 = BossFxData.regrow.shadowTransparency, life = seconds })
		-- 테두리(위험색) - 판정 원 그대로
		BossFx.spawn({ essential = true, shape = "cylinder", position = base - Vector3.new(0, 0.02, 0), rotation = CFrame.Angles(0, 0, math.rad(90)),
			size0 = Vector3.new(0.08, c.r * 2 + 0.6, c.r * 2 + 0.6), color = DANGER_COLOR, material = Enum.Material.Neon,
			transparency0 = 0.6, transparency1 = 0.25, life = seconds })
		-- 금 가는 빛: 흰 금이 가운데서 바깥으로 길어진다
		local lines = math.max(3, math.floor(c.r * 1.5))
		for k = 1, lines do
			local angle = (k / lines) * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local length = c.r * rng:NextNumber(0.7, 1)
			BossFx.spawn({ essential = true, shape = "block", position = base + Vector3.new(0, 0.03, 0) + dir * length / 2, rotation = CFrame.lookAt(Vector3.zero, dir).Rotation,
				size0 = Vector3.new(0.18, 0.06, 0.2), size1 = Vector3.new(0.3, 0.06, length), color = GLOW_COLOR, material = Enum.Material.Neon,
				transparency0 = 0.4, transparency1 = 0, life = seconds })
		end
	end
end

function BossRegrowView.spawn(data)
	for _, c in ipairs(data.colliders or {}) do
		local base = Vector3.new(c.center.X, (data.floorY or c.center.Y) + 0.3, c.center.Z)
		local count = math.max(4, math.floor(c.r * 3))
		for k = 1, count do
			local angle = (k / count) * 2 * math.pi
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			BossFx.puff(base + dir * (c.r + 0.3), rng:NextNumber(1.4, 2.2), DUST_COLOR, 0.5, dir * 6 + Vector3.new(0, 1.5, 0))
			if k % 2 == 0 then
				BossFx.chunk(base + dir * c.r * 0.8 + Vector3.new(0, (c.h or 3) * 0.6, 0), dir * 5 + Vector3.new(0, 14, 0), 0.6, data.color or DUST_COLOR, 0.5)
			end
		end
		BossFx.ring(base - Vector3.new(0, 0.15, 0), c.r * 0.8, c.r + 3, GLOW_COLOR, 0.3, 0.35)
		BossFx.shake(base, 0.6)
	end
end

-- ─────────────────────────── 끼임 "탈출! n타" ───────────────────────────
local marks = {} -- [구조물 id] = { [userId] = { gui, label, bar, token } }

local function characterOf(userId)
	local other = Players:GetPlayerByUserId(userId)
	return other and other.Character
end

local function clearMarks(id)
	for _, entry in pairs(marks[id] or {}) do
		entry.gui:Destroy()
	end
	marks[id] = nil
end

local function markFor(userId)
	local head = characterOf(userId) and characterOf(userId):FindFirstChild("Head")
	if not head then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossEncaseMark"
	gui.Size = UDim2.new(0, 120, 0, 44)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 300
	gui.Adornee = head
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 0, 32)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = DANGER_COLOR
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0.1, 0, 0, 34)
	track.Size = UDim2.new(0.8, 0, 0, 6)
	track.BackgroundColor3 = Color3.new(0, 0, 0)
	track.BackgroundTransparency = 0.4
	track.BorderSizePixel = 0
	track.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.BackgroundColor3 = DANGER_COLOR
	bar.BorderSizePixel = 0
	bar.Parent = track
	return { gui = gui, label = label, bar = bar }
end

-- data = { id, userIds, hitsLeft, seconds }
function BossRegrowView.encase(data)
	if (data.hitsLeft or 0) <= 0 or #(data.userIds or {}) == 0 then
		clearMarks(data.id)
		return
	end
	marks[data.id] = marks[data.id] or {}
	local deadline = os.clock() + (data.seconds or 0)
	for _, userId in ipairs(data.userIds) do
		local entry = marks[data.id][userId] or markFor(userId)
		if entry then
			marks[data.id][userId] = entry
			entry.label.Text = ("탈출! %d타"):format(data.hitsLeft)
			entry.deadline = deadline
			entry.total = entry.total or math.max(data.seconds or 1, 0.1)
		end
	end
end

function BossRegrowView.clear()
	for id in pairs(marks) do
		clearMarks(id)
	end
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, byUser in pairs(marks) do
		for _, entry in pairs(byUser) do
			if entry.deadline and entry.gui.Parent then
				entry.bar.Size = UDim2.new(math.clamp((entry.deadline - now) / entry.total, 0, 1), 0, 1, 0)
			end
		end
	end
end)

ReplicatedStorage:WaitForChild("BossArenaEncase").OnClientEvent:Connect(BossRegrowView.encase)

return BossRegrowView
