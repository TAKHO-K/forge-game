-- QUEUE-ALL1 01 A-4 아이콘 타일 버튼(아트 켬 - ArtStyleV1): 기준 = docs/art/ref/16_ui_hud.png. 버튼(TextButton) 하나를 PNG 타일(icons/hud/<이름> - 색 타일 + 3톤 기호 + 굵은 외곽선)로 바꾼다.
--   PNG가 없거나 아트 끔이면 아무것도 안 한다(false - 부르는 쪽이 옛 모습 그대로). 단축키 칩 = 모서리 어두운 둥근 칩 + 흰 글자(PC만) · 알림 점 = setDot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)
local Theme = require(script.Parent.kit.Theme)

local IconTile = {}

local INK = Color3.fromRGB(30, 27, 46)

function IconTile.image(name)
	local e = ArtAssetIds["icons/hud/" .. name]
	return e and e.image and ("rbxassetid://" .. tostring(e.image)) or nil
end

function IconTile.enabled()
	return Workspace:GetAttribute("ArtStyleV1") == true
end

-- 반환 { image, chip, dot } 또는 nil. keepText = 글씨를 지우지 않는다(귀환 시간 등 - 부르는 쪽이 글씨 자리를 옮긴다)
function IconTile.apply(button, name, hotkeyText, opts)
	opts = opts or {}
	local img = IconTile.image(name)
	if not img or not IconTile.enabled() then
		return nil
	end
	if not opts.keepText then
		button.Text = ""
	end
	button.BackgroundTransparency = 1
	for _, c in ipairs(button:GetChildren()) do
		if c:IsA("UIStroke") then
			c.Enabled = false
		end
	end
	if opts.size then
		button.Size = UDim2.fromOffset(opts.size, opts.size)
	end
	local image = button:FindFirstChild("IconTile") or Instance.new("ImageLabel")
	image.Name = "IconTile"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = img
	image.ZIndex = button.ZIndex
	image.Parent = button
	local chip = button:FindFirstChild("HotkeyChip")
	if hotkeyText and hotkeyText ~= "" and not Theme.isMobile then
		chip = chip or Instance.new("TextLabel")
		chip.Name = "HotkeyChip"
		chip.AnchorPoint = Vector2.new(1, 1)
		chip.Position = UDim2.new(1, 2, 1, 2)
		chip.Size = UDim2.fromOffset(16, 16)
		chip.BackgroundColor3 = INK
		chip.Font = Theme.font
		chip.TextSize = 11
		chip.TextColor3 = Color3.new(1, 1, 1)
		chip.Text = hotkeyText
		chip.ZIndex = button.ZIndex + 2
		chip.Parent = button
		local corner = chip:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = chip
	elseif chip then
		chip:Destroy()
		chip = nil
	end
	return { image = image, chip = chip }
end

-- 알림 빨간 점(오른쪽 위)
function IconTile.setDot(button, on)
	local dot = button:FindFirstChild("AlertDot")
	if on and not dot then
		dot = Instance.new("Frame")
		dot.Name = "AlertDot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(1, -4, 0, 4)
		dot.Size = UDim2.fromOffset(12, 12)
		dot.BackgroundColor3 = Color3.fromRGB(230, 57, 70)
		dot.ZIndex = button.ZIndex + 3
		dot.Parent = button
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 1.5
		stroke.Parent = dot
	end
	if dot then
		dot.Visible = on == true
	end
end

return IconTile
