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
workspace = setmetatable({ GetAttribute = function(_, k) return ATTR[k] end }, { __index = function() return P end }) -- 옛 `workspace = P`는 P 정의 전이라 nil이었다(Text.devOverride가 workspace:GetAttribute를 부른다)
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
Vector3.xAxis = Vector3.new(1,0,0)
Vector3.yAxis = Vector3.new(0,1,0)
Vector3.zAxis = Vector3.new(0,0,1)
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local UDim2 = { new = function() return {} end, fromScale = function() return {} end, fromOffset = function() return {} end }
local NumberSequence = { new = function() return {} end }
local ColorSequence = { new = function() return {} end }
local ColorSequenceKeypoint = { new = function() return {} end }
local NumberSequenceKeypoint = { new = function() return {} end }
local NumberRange = { new = function() return {} end }
local CFrame = { new = function() return {} end, fromMatrix = function() return {} end, Angles = function() return {} end, fromEulerAnglesXYZ = function() return {} end, fromEulerAnglesYXZ = function() return {} end, fromAxisAngle = function() return {} end, lookAt = function() return {} end }
CFrame.identity = CFrame.new()
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
