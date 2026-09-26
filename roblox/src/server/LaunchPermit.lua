-- 발사 허가(M1-2c - 수직 발사 요소 공용). 수치 = MovementConfig.permit.
--   클라가 발판(나무 점프대 · 통통 열매 · 보스 도움 발판)을 밟아 스스로 튀어 오르면 LaunchPermitRequest(발판 파트)를 보낸다 →
--   서버가 "최근 historySeconds 동안 이 사람 루트가 그 발판 기둥 안에 있었는가"를 자기 위치 기록으로 확인하고(요청이 도착한 순간의 거리가 아니다 - 빠르게 떠오르는 중이라
--   도착 시각 거리는 지연 · 접근 방향에 따라 10을 넘는다: M1-2c 원인) → HeightGuard.grant(설계 정점).
--   요청이 위치 기록보다 먼저 오면 pendingSeconds 동안 새 기록으로 다시 본다. 사람마다 cooldownSeconds · 허가는 가장 최근 것만(HeightGuard).
--   발판 등록 = register(part, spec) · spec = { top(윗면 Y), center(Vector3 - 윗면 가운데 XZ), radius, apexFeetY(설계 발 정점 - 공중 점프 몫 포함), seconds?, source }.
--   서버가 직접 보내는 보스 발사(넉백 등)는 이 모듈이 아니라 HeightGuard.grantLaunch(보낸 쪽이 사실을 안다).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local HeightGuard = require(script.Parent.HeightGuard)

local PERMIT = MovementConfig.permit
local ROOT_ABOVE = MovementConfig.rootAboveFeetStuds

local LaunchPermit = {}
LaunchPermit.stats = { granted = 0, rejected = 0, deferred = 0, last = nil }

-- 강한 표(M1-2c 첫 Play X: 약한 키 표는 Lua 참조가 없는 인스턴스 프록시를 거둬 가 등록이 전부 사라졌다) - 지울 때는 Destroying · PlayerRemoving으로.
local sources = {} -- [BasePart] = spec
local history = {} -- [Player] = { { t, pos }, … }(오래된 것부터)
local pending = {} -- [Player] = { part, untilAt }
local lastGrantAt = {}
local lastRequestAt = {}

function LaunchPermit.register(part, spec)
	if not sources[part] then
		part.Destroying:Connect(function()
			sources[part] = nil
		end)
	end
	sources[part] = spec
end

-- M1-3 둥지 줍기 검증이 같은 서버 위치 기록을 읽는다(순간이동 줍기 차단). 반환: { { t, pos } } - 오래된 것부터(복사 아님 - 읽기만)
function LaunchPermit.recentSamples(player)
	return history[player] or {}
end

function LaunchPermit.specOf(part)
	return sources[part]
end

-- 순수: 루트 위치 하나가 발판 위(밟는 자리)인가 - 반경 + 여유 · 발 = 윗면 − belowSlack ~ 윗면 + aboveSlack(리뷰 2: 정점까지의 기둥 전체를 받으면 공중에서 되풀이 요청으로 허가를 이어 받았다)
function LaunchPermit.inColumn(spec, rootPos)
	local flat = Vector3.new(rootPos.X - spec.center.X, 0, rootPos.Z - spec.center.Z).Magnitude
	local feet = rootPos.Y - ROOT_ABOVE
	return flat <= spec.radius + PERMIT.reachSlackStuds and feet >= spec.top - PERMIT.belowSlackStuds and feet <= spec.top + PERMIT.aboveSlackStuds
end

-- 순수: 위치 기록(samples = { { t, pos } }) 중 now − historySeconds 뒤의 표본이 기둥 안인가. 반환: ok, 가장 가까운 표본의 평면 거리(로그)
function LaunchPermit.checkHistory(spec, samples, now)
	local nearest = math.huge
	for i = #samples, 1, -1 do
		local s = samples[i]
		if now - s.t > PERMIT.historySeconds then
			break
		end
		if LaunchPermit.inColumn(spec, s.pos) then
			return true, 0
		end
		nearest = math.min(nearest, Vector3.new(s.pos.X - spec.center.X, 0, s.pos.Z - spec.center.Z).Magnitude)
	end
	return false, nearest
end

local function record(player, now)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local list = history[player]
	if not list then
		list = {}
		history[player] = list
	end
	table.insert(list, { t = now, pos = root.Position })
	while #list > 0 and now - list[1].t > PERMIT.historySeconds + PERMIT.historyKeepExtraSeconds do
		table.remove(list, 1)
	end
end

local function grant(player, part, spec, now, deferred)
	lastGrantAt[player] = now
	pending[player] = nil
	HeightGuard.grant(player, spec.apexFeetY, spec.seconds or PERMIT.padSeconds, spec.source or part.Name)
	LaunchPermit.stats.granted += 1
	if deferred then
		LaunchPermit.stats.deferred += 1
	end
	LaunchPermit.stats.last = { userId = player.UserId, source = spec.source or part.Name, at = now, deferred = deferred }
end

-- 요청 한 번(서버 이벤트 · 검증). 반환: "granted" | "pending" | 거절 이유
function LaunchPermit.request(player, part, now)
	now = now or os.clock()
	local spec = typeof(part) == "Instance" and sources[part]
	if not spec or not part.Parent then
		LaunchPermit.stats.rejected += 1
		return "unknown"
	end
	if now - (lastRequestAt[player] or -math.huge) < PERMIT.requestGapSeconds then
		return "too_fast" -- 리뷰 4: 요청 폭주 제한(기록은 Heartbeat만 쌓는다)
	end
	lastRequestAt[player] = now
	if now - (lastGrantAt[player] or -math.huge) < PERMIT.cooldownSeconds then
		return "cooldown"
	end
	if LaunchPermit.checkHistory(spec, history[player] or {}, now) then
		grant(player, part, spec, now, false)
		return "granted"
	end
	pending[player] = { part = part, untilAt = now + PERMIT.pendingSeconds }
	return "pending"
end

function LaunchPermit.start()
	if LaunchPermit.started then
		return
	end
	LaunchPermit.started = true
	local remote = Instance.new("RemoteEvent")
	remote.Name = "LaunchPermitRequest"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player, part)
		LaunchPermit.request(player, part)
	end)
	Players.PlayerRemoving:Connect(function(player)
		history[player], pending[player], lastGrantAt[player], lastRequestAt[player] = nil, nil, nil, nil
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			record(player, now)
			local p = pending[player]
			if p then
				local spec = p.part.Parent and sources[p.part]
				if spec and LaunchPermit.checkHistory(spec, history[player] or {}, now) then
					grant(player, p.part, spec, now, true)
				elseif now > p.untilAt or not spec then
					pending[player] = nil
					LaunchPermit.stats.rejected += 1
					local _, nearest = LaunchPermit.checkHistory(spec or { center = Vector3.zero, radius = 0, top = 0, apexFeetY = 0 }, history[player] or {}, now)
					print(("[forge-game] 발사 허가 거절: %s - %s(최근 %.1f초 기둥 밖 · 가장 가까운 평면 거리 %.1f)"):format(player.Name, p.part.Name, PERMIT.historySeconds, nearest))
				end
			end
		end
	end)
end

return LaunchPermit
