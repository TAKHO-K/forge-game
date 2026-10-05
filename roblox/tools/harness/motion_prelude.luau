local warn = function(...) print("WARN", ...) end
local LOADERS = {}
local MODS = setmetatable({}, { __index = function(t, k)
	local f = LOADERS[k]
	assert(f, "no module " .. tostring(k))
	local v = f()
	rawset(t, k, v)
	return v
end })
local ATTR = {}
workspace = P
local RaycastParams = { new = function() return {} end }
local OverlapParams = { new = function() return {} end }
local TweenInfo = { new = function() return {} end }
local BrickColor = { new = function() return {} end }
local PhysicalProperties = { new = function() return {} end }
local Ray = { new = function() return {} end }
local Rect = { new = function() return {} end }
local Font = { new = function() return {} end }
local DateTime = { now = function() return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000 } end }
local P
P = setmetatable({}, { __index = function() return P end, __call = function() return P end, __iter = function() return next, {} end, __len = function() return 0 end })
local game = {
	GetService = function(_, name)
		if name == "RunService" then
			return setmetatable({ IsStudio = function() return true end, IsServer = function() return true end, IsRunning = function() return true end }, { __index = function() return P end })
		end
		if name == "ReplicatedStorage" then
			return setmetatable({ GetAttribute = function(_, k) return ATTR[k] end, FindFirstChild = function() return nil end }, { __index = function() return P end })
		end
		if name == "ServerScriptService" or name == "ServerStorage" then return setmetatable({ FindFirstChild = function() return nil end }, { __index = function() return P end }) end
		return P
	end,
}
local script = { Parent = {} }
local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end, new = function(r, g, b) return { R = r, G = g, B = b } end }
local V3MT = {}
local Vector3
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3MT) end }
V3MT.__index = function(v, k) if k == "Dot" then return function(a, b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end if k == "Cross" then return function(a, b) return Vector3.new(a.Y*b.Z-a.Z*b.Y, a.Z*b.X-a.X*b.Z, a.X*b.Y-a.Y*b.X) end end if k == "Lerp" then return function(a, b, t) return a + (b - a) * t end end if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end if k == "Unit" then local m = math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) return Vector3.new(v.X/m, v.Y/m, v.Z/m) end end
V3MT.__add = function(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
V3MT.__sub = function(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
V3MT.__mul = function(a, b) if type(a) == "number" then a, b = b, a end if type(b) == "number" then return Vector3.new(a.X*b, a.Y*b, a.Z*b) end return Vector3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z) end
V3MT.__div = function(a, b) return Vector3.new(a.X/b, a.Y/b, a.Z/b) end
V3MT.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
Vector3.zero = Vector3.new(0,0,0)
Vector3.one = Vector3.new(1,1,1)
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local UDim2 = { new = function() return {} end, fromScale = function() return {} end, fromOffset = function() return {} end }
local NumberSequence = { new = function() return {} end }
local ColorSequence = { new = function() return {} end }
local ColorSequenceKeypoint = { new = function() return {} end }
local NumberSequenceKeypoint = { new = function() return {} end }
local NumberRange = { new = function() return {} end }
-- A2-M1 motion_prelude: server_prelude + 실제 CFrame 수학(위치 + 3×3 회전 - Roblox CFrame.Angles = Rx · Ry · Rz) - 보스 · 캐릭터 FK 모션 하네스용
local CFMT = {}
local CFrame
local function mk(x, y, z, r)
	return setmetatable({ x = x, y = y, z = z, r = r }, CFMT)
end
local I3 = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mul3(a, b)
	return {
		a[1]*b[1]+a[2]*b[4]+a[3]*b[7], a[1]*b[2]+a[2]*b[5]+a[3]*b[8], a[1]*b[3]+a[2]*b[6]+a[3]*b[9],
		a[4]*b[1]+a[5]*b[4]+a[6]*b[7], a[4]*b[2]+a[5]*b[5]+a[6]*b[8], a[4]*b[3]+a[5]*b[6]+a[6]*b[9],
		a[7]*b[1]+a[8]*b[4]+a[9]*b[7], a[7]*b[2]+a[8]*b[5]+a[9]*b[8], a[7]*b[3]+a[8]*b[6]+a[9]*b[9],
	}
end
CFMT.__index = function(c, k)
	if k == "Position" then return Vector3.new(c.x, c.y, c.z) end
	if k == "Inverse" then
		return function(self)
			local r = self.r
			local t = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
			return mk(-(t[1]*self.x+t[2]*self.y+t[3]*self.z), -(t[4]*self.x+t[5]*self.y+t[6]*self.z), -(t[7]*self.x+t[8]*self.y+t[9]*self.z), t)
		end
	end
	if k == "Rotation" then return mk(0, 0, 0, c.r) end
	if k == "LookVector" then return Vector3.new(-c.r[3], -c.r[6], -c.r[9]) end
	if k == "UpVector" then return Vector3.new(c.r[2], c.r[5], c.r[8]) end
	if k == "RightVector" then return Vector3.new(c.r[1], c.r[4], c.r[7]) end
	if k == "PointToWorldSpace" then return function(self, v) return self * v end end
	if k == "VectorToObjectSpace" then return function(self, v) local r = self.r return Vector3.new(r[1]*v.X+r[4]*v.Y+r[7]*v.Z, r[2]*v.X+r[5]*v.Y+r[8]*v.Z, r[3]*v.X+r[6]*v.Y+r[9]*v.Z) end end
	if k == "VectorToWorldSpace" then return function(self, v) local r = self.r return Vector3.new(r[1]*v.X+r[2]*v.Y+r[3]*v.Z, r[4]*v.X+r[5]*v.Y+r[6]*v.Z, r[7]*v.X+r[8]*v.Y+r[9]*v.Z) end end -- BOSS-FRAMEWORK
	if k == "X" then return c.x end
	if k == "Y" then return c.y end
	if k == "Z" then return c.z end
	return nil
end
CFMT.__mul = function(a, b)
	if getmetatable(b) == CFMT then
		local r = a.r
		return mk(a.x + r[1]*b.x + r[2]*b.y + r[3]*b.z, a.y + r[4]*b.x + r[5]*b.y + r[6]*b.z, a.z + r[7]*b.x + r[8]*b.y + r[9]*b.z, mul3(a.r, b.r))
	end
	local r = a.r
	return Vector3.new(a.x + r[1]*b.X + r[2]*b.Y + r[3]*b.Z, a.y + r[4]*b.X + r[5]*b.Y + r[6]*b.Z, a.z + r[7]*b.X + r[8]*b.Y + r[9]*b.Z)
end
CFMT.__add = function(a, v) return mk(a.x + v.X, a.y + v.Y, a.z + v.Z, a.r) end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then return mk(x.X, x.Y, x.Z, I3) end
		return mk(x or 0, y or 0, z or 0, I3)
	end,
	Angles = function(rx, ry, rz)
		local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
		local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
		local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
		local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
		return mk(0, 0, 0, mul3(mul3(Rx, Ry), Rz))
	end,
	-- 두 CFrame 회전 사이 각(도) - 하네스 측정
	angleBetween = function(a, b)
		local ra, rb = a.r, b.r
		local tr = ra[1]*rb[1]+ra[4]*rb[4]+ra[7]*rb[7] + ra[2]*rb[2]+ra[5]*rb[5]+ra[8]*rb[8] + ra[3]*rb[3]+ra[6]*rb[6]+ra[9]*rb[9]
		return math.deg(math.acos(math.clamp((tr - 1) / 2, -1, 1)))
	end,
}
CFrame.lookAt = function(p, t)
	local f = (t - p).Unit
	local up = Vector3.new(0, 1, 0)
	local r = f:Cross(up)
	if r.Magnitude < 1e-6 then
		r = Vector3.new(1, 0, 0)
	end
	r = r.Unit
	local u = r:Cross(f)
	return mk(p.X, p.Y, p.Z, { r.X, u.X, -f.X, r.Y, u.Y, -f.Y, r.Z, u.Z, -f.Z })
end
CFrame.identity = CFrame.new(0, 0, 0)
CFrame.fromEulerAnglesXYZ = CFrame.Angles
local Enum = setmetatable({}, { __index = function(t, k) return setmetatable({}, { __index = function(_, k2) return k .. "." .. k2 end }) end })
REMOTES = {} -- 공격 하네스: 서버가 만든 RemoteEvent · RemoteFunction(이름 → { onEvent, onInvoke })
local Instance = { new = function(className)
	if className == "RemoteEvent" or className == "RemoteFunction" or className == "BindableFunction" or className == "BindableEvent" then
		local rec = {}
		local obj
		obj = setmetatable({ ClassName = className }, {
			__index = function(_, k)
				if k == "OnServerEvent" or k == "Event" then return { Connect = function(_, f) rec.onEvent = f return P end } end
				return P
			end,
			__newindex = function(t, k, v)
				if k == "Name" then REMOTES[v] = rec end
				if k == "OnServerInvoke" or k == "OnInvoke" then rec.onInvoke = v end
				rawset(t, k, v)
			end,
		})
		return obj
	end
	return setmetatable({}, { __index = function() return P end })
end }
local Random = {
	new = function(seed)
		local state = (seed or 12345) % 2147483647
		if state <= 0 then state = 1 end
		local obj = {}
		local function nextRaw()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
		function obj:NextNumber(a, b)
			local u = nextRaw()
			if a then return a + (b - a) * u end
			return u
		end
		function obj:NextInteger(a, b)
			return a + math.floor(nextRaw() * (b - a + 1))
		end
		return obj
	end,
}
local typeof = function(v) return type(v) end
local task = { wait = function() end, spawn = function(f, ...) f(...) end, delay = function() end, defer = function() end, cancel = function() end }
LOADERS["DevToolsConfig"] = function() return { econSim = true, verify = { current = {}, regression = false } } end
LOADERS["PlayerProfile"] = function() return { combineExpMultiplier = function(o, p) return (1 + o) * (1 + p) end } end
LOADERS["PartyState"] = function() return { getExpBonusForCount = function(n) return MODS.PartyConfig.expBonusByMemberCount[n] or 0 end } end
