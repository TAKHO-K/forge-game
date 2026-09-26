-- M1-3 둥지 · 알 클라 상태(NestView가 채우고 알 정보창 · 칩 버튼이 읽는다). 서버 NestSync 한 번 = 통째로 바꾼다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NestData = require(ReplicatedStorage.Shared.data.NestData)

local NestState = {
	nests = {}, -- [id] = { next = unix, grade }
	eggs = {}, -- { { zone, grade, species, nest, at } }
	dex = 0,
	cap = NestData.eggCap,
	unixOffset = 0, -- 서버 unix − 클라 os.time
}
local changed = Instance.new("BindableEvent")
NestState.changed = changed.Event

local specs = {}
for _, s in ipairs(NestData.nests) do
	specs[s.id] = s
end
function NestState.spec(id)
	return specs[id]
end

function NestState.serverUnix()
	return os.time() + NestState.unixOffset
end

function NestState.apply(payload)
	if type(payload) ~= "table" then
		return
	end
	NestState.nests = payload.nests or {}
	NestState.eggs = payload.eggs or {}
	NestState.dex = payload.dex or 0
	NestState.cap = payload.cap or NestState.cap
	if payload.unix then
		NestState.unixOffset = payload.unix - os.time()
	end
	changed:Fire()
end

return NestState
