-- QUEUE-UI UI-0 화면 루트: 기준 해상도 Frame(PC 1920×1080 · 폰 800×360) + UIScale = min(화면W/기준W, 화면H/기준H) · 왼쪽 붙임 · 세로 가운데.
--   자식은 기준 px 좌표(UiLayoutData)로 놓으면 실제 화면에 맞춰진다. 폰 판정 = kit/Theme.isMobile 한 곳(터치 + 키보드 없음 · Studio ForceTouchLayout).
--   UiRoot.new(screenGui, name) → { frame, scale, isPhone, base, layout(screenKey) } · 화면 크기가 바뀌면 배율을 다시 계산한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.data.UiLayoutData)
local Theme = require(script.Parent.Parent.kit.Theme)

local UiRoot = {}

UiRoot.fit = require(ReplicatedStorage.Shared.UiModel).fit -- 순수(하네스) - 화면 크기 · 폰 여부 → 기준 크기 · 배율

function UiRoot.new(screenGui, name)
	Theme.recompute()
	local isPhone = Theme.isMobile
	local frame = Instance.new("Frame")
	frame.Name = name or "UiRoot"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0, 0.5) -- 왼쪽 붙임 · 세로 가운데(넓은 화면 = 오른쪽이 남음 - 키 아트가 오른쪽에 붙어 그 자리를 채운다)
	frame.Position = UDim2.fromScale(0, 0.5)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	frame.Parent = screenGui
	local self = { frame = frame, scale = scale, isPhone = isPhone }
	local function refit()
		local view = screenGui.AbsoluteSize
		if view.X <= 0 or view.Y <= 0 then
			return
		end
		local base, s = UiRoot.fit(view.X, view.Y, isPhone)
		self.base = base
		frame.Size = UDim2.fromOffset(base.w, base.h)
		scale.Scale = s
	end
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()
	function self.layout(screenKey)
		local screen = Layout[screenKey]
		assert(screen, "UiRoot.layout: UiLayoutData에 없는 화면 - " .. tostring(screenKey))
		return isPhone and screen.phone or screen.pc
	end
	return self
end

return UiRoot
