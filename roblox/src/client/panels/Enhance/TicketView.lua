-- 방지 옵션 줄(QUEUE-ALL9B G - 사용자 10-03: 방지권 폐지 → "하락 방지" · "초기화 방지" 켜기/끄기 · 켜면 그 시도 비용 × k). 종류마다 한 줄 [토글] <이름(비용 ×k)>.
-- 인스턴스 만들기(build)와 값 채우기(update)만 한다 - 값은 Controller가 준다. 이 단계에서 못 켜는 방지 · 불씨 가득이면 토글은 비활성 + 이유 한 줄(Toggle이 토글 아래에 그린다).

local Text = require(game:GetService("ReplicatedStorage").Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Toggle = require(script.Parent.Parent.Parent.ui.kit.Toggle)

local TicketView = {}

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

-- parent 안 (x, y)에 폭 width로 kinds(방지권 종류 목록)마다 한 줄을 짓는다. handlers = { onToggle(kind, value) }. 반환 refs = { kind -> { toggle } }.
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
		refs[kind] = { toggle = toggle }
	end
	return refs
end

-- state = Controller.getState()의 결과(state.tickets).
function TicketView.update(refs, state)
	for kind, row in pairs(refs) do
		local ticket = state.tickets[kind]
		row.toggle.setText(ticket.label)
		row.toggle.setValue(ticket.want, true)
		row.toggle.setEnabled(ticket.enabled, ticket.reason)
	end
end

return TicketView
