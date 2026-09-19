-- 확인창(30-0 S06, PRD 20.81 [D-3]). overlay 하나를 만들어 두고 재사용한다 - 환생 확인창 · 강화 구간 진입 · 구매가 같은 부품이다.
-- Confirm.ask({ title, body, primaryText, secondaryText, danger, parentId, primaryEnabled, reason }, callback) : callback(true) = 주 버튼, callback(false) = 보조 버튼 · X · Backspace · 부모 패널이 닫힘.
--   primaryEnabled = false면 주 버튼이 비활성이다(눌러도 답이 안 나간다). reason = 버튼 위에 danger색으로 적는 한 줄(비활성 이유 - 주지 않으면 줄이 없다).
--   danger = true면 주 버튼이 위험(danger) 모양이다. parentId의 패널이 닫히면 이 확인창도 같이 닫힌다(UIManager). 확인창이 떠 있는 동안 뒤의 패널 입력은 딤이 막는다.
-- 처음 ask할 때 만든다(Theme.recompute()를 그때 다시 부르지 않는다 - 전시장이 열릴 때 부르므로 같은 값이다).

local Button = require(script.Parent.Button)
local Panel = require(script.Parent.Panel)
local Theme = require(script.Parent.Theme)
local UIManager = require(script.Parent.Parent.Parent.UIManager)

local Confirm = {}

Confirm.id = "confirm"
local PANEL_SIZE = Vector2.new(380, 210)
local PAD = 16

local built -- { panel = refs, bodyLabel, primary, danger, secondary }
local pending -- 아직 답이 안 나온 callback

-- 답을 한 번만 낸다(닫힘 → onClose → callback(false)이 주 버튼 뒤에 또 불리지 않게).
local function answer(accepted)
	local callback = pending
	pending = nil
	if callback then
		callback(accepted)
	end
end

local function build()
	local panelRefs = Panel.create({
		id = Confirm.id,
		kind = "overlay",
		title = "",
		size = PANEL_SIZE,
		onClose = function()
			answer(false)
		end,
	})
	local content = panelRefs.content

	local bodyLabel = Theme.label(content, "", "body", "textPrimary")
	bodyLabel.Name = "Body"
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextTruncate = Enum.TextTruncate.AtEnd
	bodyLabel.Position = UDim2.new(0, PAD, 0, 12)
	bodyLabel.Size = UDim2.new(1, -PAD * 2, 1, -(12 + Theme.buttonHeight + PAD * 2))

	local function makeButton(kind, name, anchorX, xOffset, onActivated)
		return Button.build({
			parent = content,
			name = name,
			kind = kind,
			text = "",
			width = 120,
			anchorPoint = Vector2.new(anchorX, 1),
			position = UDim2.new(anchorX, xOffset, 1, -PAD),
			onActivated = onActivated,
		})
	end
	local function accept()
		answer(true)
		UIManager.close(Confirm.id)
	end
	local primary = makeButton("primary", "Primary", 1, -PAD, accept)
	local danger = makeButton("danger", "PrimaryDanger", 1, -PAD, accept)
	local secondary = makeButton("secondary", "Secondary", 1, -(PAD + 120 + 8), function()
		UIManager.close(Confirm.id) -- onClose가 callback(false)를 낸다
	end)

	local reasonLabel = Theme.label(content, "", "caption", "danger")
	reasonLabel.Name = "Reason"
	reasonLabel.AnchorPoint = Vector2.new(0, 1)
	reasonLabel.Position = UDim2.new(0, PAD, 1, -(PAD + Theme.buttonHeight + 6))
	reasonLabel.Size = UDim2.new(1, -PAD * 2, 0, Theme.textSize("caption") + 2)
	reasonLabel.Visible = false

	built = { panel = panelRefs, bodyLabel = bodyLabel, reasonLabel = reasonLabel, primary = primary, danger = danger, secondary = secondary }
end

-- 만든 확인창을 지운다(전시장이 Theme(모바일 판정)을 바꿔 다시 지을 때 쓴다).
function Confirm.reset()
	if built then
		UIManager.unregister(Confirm.id)
		built.panel.screenGui:Destroy()
		built = nil
	end
	pending = nil
end

function Confirm.ask(props, callback)
	if not built then
		build()
	end
	if UIManager.isOpen(Confirm.id) then
		UIManager.close(Confirm.id, true) -- 이전 물음은 취소로 끝낸다
	end
	pending = callback

	built.panel.titleLabel.Text = props.title or ""
	built.bodyLabel.Text = props.body or ""
	built.primary.setText(props.primaryText or "확인")
	built.danger.setText(props.primaryText or "확인")
	built.secondary.setText(props.secondaryText or "취소")
	built.primary.root.Visible = props.danger ~= true
	built.danger.root.Visible = props.danger == true
	local primaryEnabled = props.primaryEnabled ~= false
	built.primary.setEnabled(primaryEnabled)
	built.danger.setEnabled(primaryEnabled)
	built.reasonLabel.Text = props.reason or ""
	built.reasonLabel.Visible = props.reason ~= nil and props.reason ~= ""

	if not UIManager.open(Confirm.id, { parentId = props.parentId }) then
		answer(false) -- 열리지 못했다(트윈 중 등) - 물음이 조용히 사라지지 않게 취소로 알린다
	end
end

return Confirm
