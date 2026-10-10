-- UI-1 7b단계 HUD 편집 배치 규칙(순수 · 서버 SettingsService · 클라 HudEdit · HudLayoutApply · 하네스 hud_edit가 같이 읽는다).
--   값 = "id:x,y;…"(기준 px 왼쪽 위 - PC 1920 × 1080 · 폰 800 × 360) · 요소 = UiLayoutData.hudEdit.v7.elements(id 화이트리스트) · 크기 = hud.v6 사각형.
--   거절: 모르는 id · 같은 id 두 번 · 화면 밖 · 상단 바(58) · 로블록스 버튼 자리와 겹침 · 형식 틀림. 겹침(요소끼리)은 경고만(저장 가능 - spec §6).
local HudPlace = require(script.Parent.HudPlace)
local UiLayoutData = require(script.Parent.data.UiLayoutData)

local HudEditRules = {}
local E = UiLayoutData.hudEdit.v7
local V6 = UiLayoutData.hud.v6

local function rectOf(spec, device)
	if type(spec) == "string" then
		local r = V6[device][spec]
		return r and { r[1], r[2], r[3], r[4] } or nil, r and r.anchor
	elseif type(spec) == "table" then
		return { spec[1], spec[2], spec[3], spec[4] }, spec.anchor
	end
	return nil
end

-- 이 기기의 옮길 요소: { id, label, rect = 기준 사각형, anchor, paths, ghost }
function HudEditRules.elements(device)
	local out = {}
	for _, e in ipairs(E.elements) do
		local spec = e.rect[device]
		local rect, anchor = rectOf(spec, device)
		if rect then
			local extra = e.extra and e.extra[device] and rectOf(e.extra[device], device)
			if extra then -- 체력바 + 상태 아이콘 줄 = 한 덩어리(둘을 감싸는 사각형)
				local x1, y1 = math.min(rect[1], extra[1]), math.min(rect[2], extra[2])
				local x2, y2 = math.max(rect[1] + rect[3], extra[1] + extra[3]), math.max(rect[2] + rect[4], extra[2] + extra[4])
				rect = { x1, y1, x2 - x1, y2 - y1 }
			end
			table.insert(out, { id = e.id, label = e.label, rect = rect, anchor = anchor or "TL", paths = e.paths[device] or {}, ghost = e.ghost })
		end
	end
	return out
end

function HudEditRules.byId(device)
	local m = {}
	for _, e in ipairs(HudEditRules.elements(device)) do
		m[e.id] = e
	end
	return m
end

-- 금지 자리(기준 px 사각형 목록)
function HudEditRules.forbidden(device)
	local out = {}
	for _, name in ipairs(E.forbidden) do
		local r = (E[name] and E[name][device]) or V6[device][name]
		if r then
			table.insert(out, { r[1], r[2], r[3], r[4] })
		end
	end
	return out
end

local function hit(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end
HudEditRules.hit = hit

-- 한 요소의 자리(x, y)가 놓일 수 있나: 화면 안 · 상단 바 아래 · 금지 자리와 안 겹침
function HudEditRules.placeOk(device, rect, x, y)
	local b = HudPlace.base[device]
	if x ~= x or y ~= y or x < 0 or y < HudPlace.topBarPx or x + rect[3] > b.w or y + rect[4] > b.h then
		return false
	end
	local r = { x, y, rect[3], rect[4] }
	for _, f in ipairs(HudEditRules.forbidden(device)) do
		if hit(r, f) then
			return false
		end
	end
	return true
end

function HudEditRules.parse(value)
	local out = {}
	if type(value) ~= "string" or value == "" then
		return out
	end
	for entry in (value .. ";"):gmatch("([^;]*);") do
		local id, x, y = entry:match("^([%w_]+):(%-?%d+),(%-?%d+)$")
		if id then
			out[id] = { tonumber(x), tonumber(y) }
		end
	end
	return out
end

function HudEditRules.serialize(positions, device)
	local parts = {}
	for _, e in ipairs(HudEditRules.elements(device)) do
		local p = positions[e.id]
		if p then
			table.insert(parts, ("%s:%d,%d"):format(e.id, math.floor(p[1] + 0.5), math.floor(p[2] + 0.5)))
		end
	end
	return table.concat(parts, ";")
end

-- 서버 검증: 맞으면 true(빈 글 = 처음 위치 = 맞음)
function HudEditRules.validate(device, value)
	if device ~= "pc" and device ~= "phone" then
		return false
	end
	if type(value) ~= "string" or #value > 400 then
		return false
	end
	if value == "" then
		return true
	end
	local byId = HudEditRules.byId(device)
	local seen = {}
	for entry in (value .. ";"):gmatch("([^;]*);") do
		local id, x, y = entry:match("^([%w_]+):(%-?%d+),(%-?%d+)$")
		if not id or not byId[id] or seen[id] then
			return false
		end
		seen[id] = true
		if not HudEditRules.placeOk(device, byId[id].rect, tonumber(x), tonumber(y)) then
			return false
		end
	end
	return true
end

-- 요소끼리 겹침(경고) 목록: { { a, b } }
function HudEditRules.overlaps(device, positions)
	local list = HudEditRules.elements(device)
	local out = {}
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			local pa, pb = positions[a.id] or { a.rect[1], a.rect[2] }, positions[b.id] or { b.rect[1], b.rect[2] }
			if hit({ pa[1], pa[2], a.rect[3], a.rect[4] }, { pb[1], pb[2], b.rect[3], b.rect[4] }) then
				table.insert(out, { a.id, b.id })
			end
		end
	end
	return out
end

return HudEditRules
