-- 방지권 줄(28-1 S07 후반, PRD 20.72 [1-8] · 20.89 [4] 결정): 종류마다 한 줄 [토글] <이름> ×보유수 [구매]. 인스턴스 만들기(build)와 값 채우기(update)만 한다 - 값은 Controller가 준다.
-- 보유 0 · 사용 불가 구간 · 불씨 가득이면 토글은 비활성 + 이유 한 줄(Toggle이 토글 아래에 그린다). [구매]는 언제나 켜져 있다 - 골드가 모자란 경우는 확인창(Confirm)이 다룬다.
-- 토글 영역은 줄 전체 폭이고 [구매]가 그 오른쪽 끝을 덮는다(나중에 만든 형제가 위 - [구매]를 누르면 토글은 안 바뀐다). 이유 줄이 [구매] 밑까지 넓게 쓰게 하려는 배치다.

local Button = require(script.Parent.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Toggle = require(script.Parent.Parent.Parent.ui.kit.Toggle)

local TicketView = {}

local BUY_WIDTH = 88
local ROW_GAP = 4

local function controlHeight()
	return Theme.buttonHeight -- Toggle 줄 높이(모바일 터치 44 · PC 32)와 같은 값
end

local function rowHeight()
	return controlHeight() + 2 + Theme.textSize("caption") + 2 + ROW_GAP -- 컨트롤 + 이유 줄
end

-- kindCount 줄이 차지하는 세로(위에서부터 쌓는 호출부가 y를 계산하는 데 쓴다).
function TicketView.height(kindCount)
	return rowHeight() * kindCount
end

-- parent 안 (x, y)에 폭 width로 kinds(방지권 종류 목록)마다 한 줄을 짓는다. handlers = { onToggle(kind, value), onBuy(kind) }. 반환 refs = { kind -> { toggle, buy } }.
function TicketView.build(parent, x, y, width, kinds, handlers)
	local refs = {}
	for index, kind in ipairs(kinds) do
		local rowY = y + (index - 1) * rowHeight()
		local toggle = Toggle.build({
			parent = parent,
			name = "Toggle_" .. kind,
			text = "",
			width = width,
			position = UDim2.new(0, x, 0, rowY),
			onChanged = function(value)
				handlers.onToggle(kind, value)
			end,
		})
		local buy = Button.build({
			parent = parent,
			name = "Buy_" .. kind,
			kind = "secondary",
			text = "구매",
			width = BUY_WIDTH,
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(0, x + width, 0, rowY),
			onActivated = function()
				handlers.onBuy(kind)
			end,
		})
		refs[kind] = { toggle = toggle, buy = buy }
	end
	return refs
end

-- state = Controller.getState()의 결과(state.tickets).
function TicketView.update(refs, state)
	for kind, row in pairs(refs) do
		local ticket = state.tickets[kind]
		row.toggle.setText(("%s ×%d"):format(ticket.name, ticket.have))
		row.toggle.setValue(ticket.want, true)
		row.toggle.setEnabled(ticket.enabled, ticket.reason)
	end
end

return TicketView
