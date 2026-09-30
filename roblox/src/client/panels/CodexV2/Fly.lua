-- QUEUE-ALL3 Q1 받기 연출: 보상 그림이 재화 표시(오른쪽 위 칩 스택 PlayerGui.TopChipsGui.TopChipsRow - 골드는 GoldChip)로 0.4초 날아간다.
--   부드러운 이동(Quad Out) + 조금 작아지며 흐려짐 · 번쩍임 없음(피로 금지 기준). 창보다 위에 그리려고 전용 ScreenGui(DisplayOrder 260 - overlay 대역 위)를 쓴다.
--   Fly.capture(row) = 누른 순간 보상 줄 아이콘 자리 · 그림 기록 → Fly.launch(items) = 서버가 받음을 확인한 뒤 날린다.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Fly = {}

local SECONDS = 0.4
local gui, root

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "CodexFlyGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 260
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
end

-- 보상 줄(RewardIcons.row 결과) → { { key, image, center(Vector2 절대), size } }
function Fly.capture(row)
	local items = {}
	if not row or not row.Parent then
		return items
	end
	for _, cell in ipairs(row:GetChildren()) do
		local icon = cell:IsA("Frame") and cell:FindFirstChild("Icon")
		if icon and icon:IsA("ImageLabel") and icon.Image ~= "" then
			table.insert(items, { key = cell.Name:gsub("^R_", ""), image = icon.Image, center = icon.AbsolutePosition + icon.AbsoluteSize / 2, size = icon.AbsoluteSize.X })
		end
	end
	return items
end

local function targetFor(key)
	local chips = Players.LocalPlayer.PlayerGui:FindFirstChild("TopChipsGui")
	local row = chips and chips:FindFirstChild("TopChipsRow", true)
	if not row then
		return nil
	end
	local t = row
	if key == "gold" or key == "goldKills" then
		t = row:FindFirstChild("GoldChip", true) or row
	end
	return t.AbsolutePosition + t.AbsoluteSize / 2
end

function Fly.launch(items)
	if not items or #items == 0 then
		return
	end
	ensureGui()
	local origin = root.AbsolutePosition
	for i, it in ipairs(items) do
		local to = targetFor(it.key)
		if to then
			local img = Instance.new("ImageLabel")
			img.Name = "Fly_" .. it.key
			img.BackgroundTransparency = 1
			img.Image = it.image
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Size = UDim2.fromOffset(it.size, it.size)
			img.Position = UDim2.fromOffset(it.center.X - origin.X, it.center.Y - origin.Y)
			img.Parent = root
			local tw = TweenService:Create(img, TweenInfo.new(SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, (i - 1) * 0.05), {
				Position = UDim2.fromOffset(to.X - origin.X, to.Y - origin.Y),
				Size = UDim2.fromOffset(it.size * 0.7, it.size * 0.7),
				ImageTransparency = 0.35,
			})
			tw.Completed:Connect(function()
				img:Destroy()
			end)
			tw:Play()
		end
	end
end

return Fly
