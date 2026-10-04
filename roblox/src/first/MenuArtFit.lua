-- QUEUE-UI2 UI2-3 메인 메뉴 키 아트 맞춤(순수 - 하네스가 그대로 부른다). 두 장(L/R)은 원본 비율 부모 틀 하나 안에 원본 픽셀 비율대로 붙어 있고 이 함수는 부모 틀만 놓는다.
--   cover = 화면을 빈틈 없이 덮는 가장 작은 크기 → 초점(원본 비율 좌표 · 전사 얼굴)이 목표 화면 위치(메뉴 반대쪽)에 오게 옮긴다(빈틈이 생기지 않는 범위 안에서만).
--   목표가 덮기 크기로는 닿지 않으면(폰처럼 가로가 넓어 그림 폭 = 화면 폭) maxZoom까지만 키운다.
--   → { w, h, x, y }(화면 px · 부모 틀 왼쪽 위) · focusScreen = 초점이 실제로 놓인 화면 비율 { x, y }
local MenuArtFit = {}

--   keepRight = 원본 가로 비율(가장 오른쪽 인물 얼굴 끝) - 확대해도 이 점은 화면 안에 남긴다(4명 얼굴 · 01 checklist 1).
--   mode = "anchorRight"(옛 v2: 화면 높이 꽉 · 오른쪽 붙임 · 왼쪽 남는 곳 = 남색 바탕 + 그림 왼쪽 페이드) - 덮기로는 조건을 못 맞추는 비율(폰)용.
function MenuArtFit.fit(viewW, viewH, aspect, focus, target, maxZoom, keepRight, mode)
	if mode == "anchorRight" then
		local w = viewH * aspect
		local x = viewW - w
		return { w = w, h = viewH, x = x, y = 0, focusScreen = { (x + focus[1] * w) / viewW, focus[2] } }
	end
	local coverW = math.max(viewW, viewH * aspect)
	local fx, fy = focus[1], focus[2]
	local tx, ty = target[1] * viewW, target[2] * viewH
	-- 초점이 목표에 오려면 x = tx − fx·W ∈ [viewW − W, 0] → W ≥ tx / fx · W ≥ (viewW − tx) / (1 − fx) (세로도 같은 식)
	local need = math.max(coverW, tx / math.max(fx, 1e-6), (viewW - tx) / math.max(1 - fx, 1e-6))
	local needH = math.max(ty / math.max(fy, 1e-6), (viewH - ty) / math.max(1 - fy, 1e-6))
	need = math.max(need, needH * aspect)
	local cap = coverW * (maxZoom or 1)
	if keepRight and keepRight > focus[1] then -- x = tx − fx·W 일 때 x + kr·W ≤ viewW → W ≤ (viewW − tx) / (kr − fx)
		cap = math.min(cap, (viewW - tx) / (keepRight - focus[1]))
	end
	local w = math.max(coverW, math.min(need, cap))
	local h = w / aspect
	local x = math.clamp(tx - fx * w, viewW - w, 0)
	local y = math.clamp(ty - fy * h, viewH - h, 0)
	return { w = w, h = h, x = x, y = y, focusScreen = { (x + fx * w) / viewW, (y + fy * h) / viewH } }
end

return MenuArtFit
