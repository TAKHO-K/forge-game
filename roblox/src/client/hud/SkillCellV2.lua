-- UI-1 2단계 B v2 스킬 칸(08 v5-auto-boss §10 + F v2 §1 정본 · mockups/pc_10): SkillSlots 칸(TextButton/Frame) 위에 겉모습만 씌운다(입력 · 쿨 상태는 SkillSlots 그대로).
--   판 = btn-plate(PC 사각) · btn-combat(폰 · 대시 원) · 덮개 = A v2 sweep(UiParts.cooldown clear) · 쿨 중 그림 회색 0.6 + 밝기 0.75 ·
--   단축키 판 = 칸 안 왼쪽 위 칸 × 0.3(`#0E1120` 85% · 흰 숫자 글꼴) · 대시 = 위 가운데 "SHIFT" · 폰 = 위 가운데 작게(키보드 있을 때만) · **맨 위 층**(숫자 + 2) ·
--   남은 초 = 칸 × 0.56 · 왼쪽 12% · 위 20% 비우고 가운데(오른쪽 아래로) · 2자리 이상 0.8배 · 1초 미만 소수 1자리 · 흰 + 외곽선 5 · 기절 = 오른쪽 위(−8, −8) 상태 아이콘.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local V6 = require(ReplicatedStorage.Shared.data.UiLayoutData).hud.v6
local Parts = require(ReplicatedStorage.Shared.data.UiPartsData)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local UiParts = require(script.Parent.Parent.ui.v2.UiParts)
local Theme = require(script.Parent.Parent.ui.kit.Theme)

local SkillCellV2 = {}
local K = V6.skill
local cells = {} -- 기절 표시 갱신용

local function plateKey(round)
	return round and "ui/ds/btn-combat-normal" or "ui/ds/btn-plate-normal"
end

-- 옛 금속 겉모습 끄기(지우지 않음 - 스위치를 끄면 그대로 돌아온다)
local function hideOldLook(slot)
	slot.BackgroundTransparency = 1
	for _, d in ipairs(slot:GetChildren()) do
		if d:IsA("UIStroke") or d:IsA("UIGradient") then
			d.Enabled = false
		elseif d.Name == "InnerHighlight" or d.Name == "CooldownOverlay" or d.Name == "KeyPill" or d.Name == "CooldownLabel" then
			d.Visible = false
		elseif d:IsA("Frame") and d.Size.X.Offset == 3 and d.Size.Y.Offset == 6 and #d:GetChildren() == 0 then
			d.Visible = false -- 옛 쿨다운 링 눈금(HudIcons.buildCooldownRing)
		end
	end
end

-- opts = { key = "Q" | "SHIFT" | nil, round = bool, keyOnly = bool(궁 칸 - 그림 · 덮개는 UltGauge가) }
function SkillCellV2.decorate(slot, opts)
	opts = opts or {}
	local phone = Theme.isMobile
	local self = { slot = slot }
	if not opts.keyOnly then
		hideOldLook(slot)
		local plate = Instance.new("ImageLabel")
		plate.Name = "PlateV2"
		plate.BackgroundTransparency = 1
		plate.Image = ArtImage.get(plateKey(opts.round)) or ""
		if not opts.round then
			plate.ScaleType = Enum.ScaleType.Slice
			plate.SliceCenter = Rect.new(32, 32, 64, 64)
			plate.SliceScale = 0.5
		end
		plate.Size = UDim2.fromScale(1, 1)
		plate.ZIndex = 0
		plate.Parent = slot
		self.cover = UiParts.cooldown(slot, { mode = "clear", circle = opts.round, zIndex = 2 })
		self.cover.set(1)
		local sec = Instance.new("TextLabel")
		sec.Name = "SecondsV2"
		sec.BackgroundTransparency = 1
		sec.Position = UDim2.fromScale(K.secondsLeft, K.secondsTop)
		sec.Size = UDim2.fromScale(1 - K.secondsLeft, 1 - K.secondsTop)
		sec.Font = Enum.Font.FredokaOne
		sec.TextColor3 = Color3.new(1, 1, 1)
		sec.Text = ""
		sec.ZIndex = 6
		sec.Parent = slot
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromHex(K.keyBg)
		st.Thickness = K.secondsStroke * 0.5
		st.Parent = sec
		self.seconds = sec
		local stun = Instance.new("ImageLabel")
		stun.Name = "StunV2"
		stun.BackgroundTransparency = 1
		stun.Image = ArtImage.get("ui/ds/status-stun") or ""
		stun.AnchorPoint = Vector2.new(0.5, 0.5)
		stun.Position = UDim2.new(1, -K.stunInset, 0, K.stunInset)
		stun.Size = UDim2.fromScale(K.stunRatio, K.stunRatio)
		stun.ZIndex = 7
		stun.Visible = false
		stun.Parent = slot
		self.stun = stun
	end
	if opts.key and (not phone or UserInputService.KeyboardEnabled) then
		local badge = Instance.new("TextLabel")
		badge.Name = "KeyV2"
		badge.BackgroundColor3 = Color3.fromHex(K.keyBg)
		badge.BackgroundTransparency = K.keyBgTransparency
		badge.TextColor3 = Color3.new(1, 1, 1)
		badge.Font = Enum.Font.FredokaOne
		badge.TextScaled = true
		badge.Text = opts.key
		badge.ZIndex = 8 -- 맨 위 층(숫자 6 + 2)
		local wide = #opts.key > 1
		if phone then
			badge.AnchorPoint = Vector2.new(0.5, 0)
			badge.Position = UDim2.new(0.5, 0, 0, 2)
			badge.Size = UDim2.fromOffset(K.keyPhone[1] * (wide and 2.4 or 1), K.keyPhone[2])
		elseif wide then -- 대시 SHIFT = 위 가운데
			badge.AnchorPoint = Vector2.new(0.5, 0)
			badge.Position = UDim2.new(0.5, 0, 0, 3)
			badge.Size = UDim2.new(0.62, 0, K.keyRatio * 0.72, 0)
		else
			badge.Position = UDim2.fromOffset(4, 4)
			badge.Size = UDim2.fromScale(K.keyRatio, K.keyRatio)
		end
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.25, 0)
		c.Parent = badge
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0), UDim.new(0.1, 0), UDim.new(0.1, 0)
		pad.Parent = badge
		badge.Parent = slot
		self.key = badge
	end
	-- 남은 초 · 덮개 · 그림 색: remaining · total(초) · iconImage = 스킬 그림(ImageLabel)
	function self.set(remaining, total, iconImage)
		if not self.cover then
			return
		end
		local cooling = remaining > 0 and total > 0
		self.cover.set(cooling and (1 - remaining / total) or 1)
		local text = cooling and UiParts.secondsText(remaining) or ""
		self.seconds.Text = text
		local px = slot.AbsoluteSize.X > 0 and slot.AbsoluteSize.X or 72
		local digits = #(text:gsub("%.", ""))
		self.seconds.TextSize = math.floor(px * K.secondsRatio * (digits >= 2 and K.twoDigitScale or 1))
		if iconImage then
			iconImage.ImageColor3 = self.stunned and Color3.fromHex(Parts.cooldown.disabledIconColor) or (cooling and Color3.fromRGB(136, 136, 136) or Color3.new(1, 1, 1)) -- 회색 0.6 · 밝기 0.75
		end
	end
	function self.flash(iconHolder)
		if self.cover then
			self.cover.flash(iconHolder)
		end
	end
	if self.stun then
		table.insert(cells, self)
	end
	return self
end

-- 기절 = 모든 칸 오른쪽 위 상태 아이콘 + 그림 회색(쓸 수 없음 · 02 v6 §7)
do
	local player = Players.LocalPlayer
	local function refresh()
		local on = player:GetAttribute("BossStunned") == true
		for _, c in ipairs(cells) do
			c.stunned = on
			if c.stun.Parent then
				c.stun.Visible = on
			end
		end
	end
	player:GetAttributeChangedSignal("BossStunned"):Connect(refresh)
end

return SkillCellV2
