-- 도움말 토글(30-0 S06, PRD 20.81 [D-3]). 20px 원 "?" - **누르면 열리고 다시 누르면 닫힌다**(hover 경로를 쓰지 않는다 - PC · 모바일 같은 동작).
-- 내용 패널은 기존 client/HelpTooltip을 감싼다(HelpTooltip.attach의 toggleOnly 옵션). 패널당 하나, 제목줄의 X 왼쪽.
-- HelpToggle.build(props) -> refs. props = { parent, text, position(UDim2 - 버튼 중심), panelSide("left"|"right") }. refs = { root }.

local HelpTooltip = require(script.Parent.Parent.Parent.HelpTooltip)
local Theme = require(script.Parent.Theme)

local HelpToggle = {}

HelpToggle.size = 20

function HelpToggle.build(props)
	local button = HelpTooltip.attach(props.parent, props.position or UDim2.new(0, 0, 0, 0), props.text or "", props.panelSide or "left", {
		toggleOnly = true,
		buttonSize = HelpToggle.size,
		buttonTextSize = Theme.textSize("caption"), -- 12 미만 금지(기존 HelpTooltip 버튼의 11은 그대로 두고 이 부품만 12)
		panelSize = Vector2.new(Theme.isMobile and 260 or 240, Theme.isMobile and 110 or 88),
		panelTextSize = Theme.textSize("caption"),
	})
	button.Name = "HelpToggle"
	return { root = button }
end

return HelpToggle
