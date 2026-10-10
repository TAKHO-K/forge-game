-- UI-1b 0절(VERIFY-5 상3): 실제 화면 겹침 판정(순수 함수 - 하네스 hud_layout에서 같은 함수를 돌린다).
--   rects = { { id, x, y, w, h } … }(AbsolutePosition 공통 좌표 = 상단 바 아래가 y 0) · view = { w, h }(상단 바 아래 화면 크기)
--   돌려줌 = { overlaps = { { a, b, w, h } … }, offscreen = { id … }, topbar = { id … } }
local HudRealRules = {}

local function allowed(allow, a, b)
	for _, pair in ipairs(allow or {}) do
		if (a:find(pair[1], 1, true) == 1 and b:find(pair[2], 1, true) == 1) or (a:find(pair[2], 1, true) == 1 and b:find(pair[1], 1, true) == 1) then
			return true
		end
	end
	return false
end

function HudRealRules.check(rects, view, allow)
	local out = { overlaps = {}, offscreen = {}, topbar = {} }
	for i, r in ipairs(rects) do
		if r.y < 0 then
			table.insert(out.topbar, r.id)
		end
		if r.x < 0 or r.x + r.w > view.w + 0.5 or r.y + r.h > view.h + 0.5 then
			table.insert(out.offscreen, r.id)
		end
		for j = i + 1, #rects do
			local q = rects[j]
			local ow = math.min(r.x + r.w, q.x + q.w) - math.max(r.x, q.x)
			local oh = math.min(r.y + r.h, q.y + q.h) - math.max(r.y, q.y)
			if ow >= 1 and oh >= 1 and not allowed(allow, r.id, q.id) then
				table.insert(out.overlaps, { r.id, q.id, math.floor(ow), math.floor(oh) })
			end
		end
	end
	return out
end

return HudRealRules
