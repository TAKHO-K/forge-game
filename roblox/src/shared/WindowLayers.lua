-- UI-1b 1-b 10(버그: 장비창이 다른 GUI 뒤에 열림): 창 · HUD DisplayOrder = 데이터 표 하나(UiLayoutData.layers) · "나중에 연 창이 위"(순수 함수 - 하네스 window_layers).
--   옛 원인 = 창 대역(100 ~ 149)보다 HUD 메뉴(150)가 위 + 출석 · 보스 관문 창만 160으로 따로 올림 → 그 뒤에 연 장비창(101 ~)이 그 아래로 깔림.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local L = require(ReplicatedStorage.Shared.data.UiLayoutData).layers

local WindowLayers = {}
WindowLayers.L = L

-- 열림 스택(맨 뒤 = 맨 위)의 kind 목록 → 같은 순서의 DisplayOrder 목록(종류 대역 안에서 연 순서대로 +1 · 대역 상한 넘지 않음)
function WindowLayers.stackOrders(kinds)
	local rank, out = {}, {}
	for i, kind in ipairs(kinds) do
		rank[kind] = (rank[kind] or 0) + 1
		local base, cap = L[kind], L[kind .. "Max"]
		out[i] = math.min(base + rank[kind], cap or math.huge)
	end
	return out
end

return WindowLayers
