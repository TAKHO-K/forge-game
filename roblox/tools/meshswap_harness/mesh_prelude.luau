-- 최소 스텁: Vector3 · Color3 · game · require(경로 끝 이름)
local V3 = {}
V3.__index = V3
local function v(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return v(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b) if type(a) == "number" then return v(a * b.X, a * b.Y, a * b.Z) end if type(b) == "number" then return v(a.X * b, a.Y * b, a.Z * b) end return v(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
V3.__unm = function(a) return v(-a.X, -a.Y, -a.Z) end
Vector3 = { new = v, zero = v(0, 0, 0), one = v(1, 1, 1) }
Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end, new = function(r, g, b) return { R = r, G = g, B = b } end }
Enum = setmetatable({}, { __index = function(t, k) return setmetatable({}, { __index = function(_, n) return { Name = n } end }) end })
sources = {}
local cache = {}
local function path(name)
	return setmetatable({ __name = name }, { __index = function(t, k) return path(k) end })
end
game = { GetService = function() return path("svc") end }
local rawRequire = require
require = function(tok)
	local name = type(tok) == "table" and rawget(tok, "__name") or tok
	if cache[name] == nil then
		local f = sources[name]
		assert(f, "모듈 없음: " .. tostring(name))
		cache[name] = f()
	end
	return cache[name]
end
-- 쓰지 않는 무거운 데이터 스텁
sources.MonsterSpeciesData = function() return { species = {} } end
sources.CartoonStyleData = function() return { palette = {} } end
