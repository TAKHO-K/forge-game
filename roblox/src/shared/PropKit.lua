-- M1-4 소품 배치(순수 - Instance를 만들지 않는다). 틀 = data/PropData · 라이브러리 · 복제 = server/PropLibrary.
-- 맵 코드는 소품을 도형으로 풀지 않고 "이름 · cf · 배율"만 목록에 넣는다(PropKit.place) - 서버 빌더(WorldMap)가 라이브러리 모델을 복제한다.
-- 검사(빈 공간 · 둥지 보호 부피 침범 · 지면)는 PropKit.expand로 틀 도형을 월드 상자로 풀어 쓴다(틀 = 크기 · 충돌 계약).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PropData = require(ReplicatedStorage.Shared.data.PropData)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)

local PropKit = {}
PropKit.data = PropData

local function vec(t)
	return Vector3.new(t[1], t[2], t[3])
end

function PropKit.template(name)
	local t = PropData.templates[name]
	assert(t, "소품 틀 없음: " .. tostring(name))
	return t
end

function PropKit.color(part)
	local c = part.c or { 160, 160, 160 }
	if type(c) == "string" then
		c = TerrainGenData.materialColors[c] or { 160, 160, 160 }
	end
	local k = 1 - (part.dk or 0)
	return { math.floor(c[1] * k + 0.5), math.floor(c[2] * k + 0.5), math.floor(c[3] * k + 0.5) }
end

-- 틀 로컬 도형 → (배율 적용) 로컬 cf · 크기. 배율 = 틀 축(x, y, z)마다 - 회전한 도형은 제 축 방향의 배율을 쓴다(축 정렬 회전이면 정확).
function PropKit.scaledLocal(part, scale)
	local r = part.r or { 0, 0, 0 }
	local rot = CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
	local p = vec(part.p or { 0, 0, 0 }) * scale
	local size = vec(part.s)
	local function k(axis)
		local u = rot * axis -- 회전만(원점 cf)
		return math.sqrt((u.X * scale.X) ^ 2 + (u.Y * scale.Y) ^ 2 + (u.Z * scale.Z) ^ 2)
	end
	local s = Vector3.new(size.X * k(Vector3.new(1, 0, 0)), size.Y * k(Vector3.new(0, 1, 0)), size.Z * k(Vector3.new(0, 0, 1)))
	return CFrame.new(p) * rot, s
end

local function toScale(scale)
	if scale == nil then
		return Vector3.one
	elseif type(scale) == "number" then
		return Vector3.new(scale, scale, scale)
	elseif typeof(scale) == "Vector3" or (type(scale) == "table" and scale.X ~= nil) then
		return scale
	end
	return vec(scale)
end
PropKit.toScale = toScale

-- 틀에 충돌 도형이 있는가(지면 폴더 · 검사 대상)
local collideCache = {}
function PropKit.collides(name)
	if collideCache[name] == nil then
		local any = false
		for _, part in ipairs(PropKit.template(name).parts) do
			if part.col ~= false then
				any = true
			end
		end
		collideCache[name] = any
	end
	return collideCache[name]
end

-- 배치 한 줄: 목록에 소품 항목 { model, name, prop, cf(바닥 가운데), scale(Vector3), collide, attrs, size(배율 적용 경계 - 검사용) } 을 넣는다.
function PropKit.place(list, model, name, cf, scale, opts)
	local s = toScale(scale)
	local lo, hi = PropKit.bounds(name, s)
	local entry = { model = model, name = name, prop = name, cf = cf, scale = s, collide = PropKit.collides(name), attrs = opts and opts.attrs, size = hi - lo, boundsLo = lo, boundsHi = hi,
		snap = opts and opts.snap } -- snap = 부팅 때 지형에 레이캐스트로 붙인다(재굽기 뒤 자동 재배치 - server/PropLibrary.snap)
	table.insert(list, entry)
	return entry
end

-- 틀 도형을 월드로 풀기(cf = 배치 cf · scale = Vector3) → { { name, size, cf, color, material, shape, collide, transparency, mesh, attrs } }
function PropKit.expand(name, cf, scale)
	local s = toScale(scale)
	local out = {}
	for _, part in ipairs(PropKit.template(name).parts) do
		local lcf, size = PropKit.scaledLocal(part, s)
		table.insert(out, {
			name = part.n, size = size, cf = cf * lcf, color = PropKit.color(part), material = part.m or "SmoothPlastic", shape = part.sh or "Block",
			collide = part.col ~= false, transparency = part.tr, mesh = part.mesh, attrs = part.a,
		})
	end
	return out
end

-- 로컬 경계 상자(배율 적용) - 반환 lo, hi(Vector3)
function PropKit.bounds(name, scale)
	local s = toScale(scale)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(PropKit.template(name).parts) do
		local lcf, size = PropKit.scaledLocal(part, s)
		for _, sx in ipairs({ -0.5, 0.5 }) do
			for _, sy in ipairs({ -0.5, 0.5 }) do
				for _, sz in ipairs({ -0.5, 0.5 }) do
					local q = (lcf * CFrame.new(size.X * sx, size.Y * sy, size.Z * sz)).Position
					lo = Vector3.new(math.min(lo.X, q.X), math.min(lo.Y, q.Y), math.min(lo.Z, q.Z))
					hi = Vector3.new(math.max(hi.X, q.X), math.max(hi.Y, q.Y), math.max(hi.Z, q.Z))
				end
			end
		end
	end
	return lo, hi
end

-- 발자국 반경(수평 - 경계 상자 모서리까지) · 높이
function PropKit.footprint(entry)
	local lo, hi = entry.boundsLo, entry.boundsHi
	local r = math.max(math.abs(lo.X), math.abs(hi.X), 0) ^ 2 + math.max(math.abs(lo.Z), math.abs(hi.Z), 0) ^ 2
	return math.sqrt(r), hi.Y
end

return PropKit
