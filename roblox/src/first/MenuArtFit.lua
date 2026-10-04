-- QUEUE-UI2 UI2-3 메인 메뉴 키 아트 배치(순수 - 하네스가 그대로 부른다) = 01 v3 spec "키 아트 초점".
--   두 장(L/R)은 원본 비율 부모 틀 하나 안에 원본 픽셀 비율대로 붙어 있고(menu_keyart_v2.meta.json - L 0 ~ 770 · R 766 ~ 1536) 이 함수는 부모 틀만 놓는다.
--   크기 s = 화면 높이 / 원본 높이(높이 꽉) · 빈 구역 = [가장 넓은 UI 오른쪽 + margin, 화면 오른쪽 − margin] · 지킬 영역 가운데 = 빈 구역 가운데.
--   그림이 화면 오른쪽을 못 덮으면 오른쪽에 붙임. 빈 구역이 지킬 영역보다 좁으면 좁은 창 모드(이어하기 = 메뉴 숨김 + 창 왼쪽) → 빈 구역 왼쪽 = 좁은 창 오른쪽 기준.
--   uiRight · uiRightNarrow = 화면 px(UiRoot 배율 적용 뒤 - 메뉴가 알려 줌). nil = 아직 모름 → 오른쪽 붙임.
--   → { s, x, w, h, narrow, zoneLeft, keepScreen = { x0, y0, x1, y1 } }
local MenuArtFit = {}

function MenuArtFit.place(viewW, viewH, imgW, imgH, keep, margin, uiRight, uiRightNarrow)
	local s = viewH / imgH
	local w, h = imgW * s, viewH
	local narrow = false
	local x
	local zoneLeft = nil
	if uiRight then
		zoneLeft = uiRight + margin
		local zoneRight = viewW - margin
		if zoneRight - zoneLeft < (keep[3] - keep[1]) * s then
			narrow = true
			zoneLeft = (uiRightNarrow or uiRight) + margin
		end
		x = (zoneLeft + zoneRight) / 2 - (keep[1] + keep[3]) / 2 * s
		if x + w < viewW then
			x = viewW - w
		end
	else
		x = viewW - w
	end
	return { s = s, x = x, w = w, h = h, narrow = narrow, zoneLeft = zoneLeft, keepScreen = { x + keep[1] * s, keep[2] * s, x + keep[3] * s, keep[4] * s } }
end

return MenuArtFit
