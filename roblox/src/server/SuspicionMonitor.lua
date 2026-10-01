-- QUEUE-ALL6 F2 탐지(서버 · 조용히 기록 · 자동 처벌 없음): 플레이어별 분 단위 지표가 기준(SecurityOpsConfig.detect)을 넘으면 의심 기록.
--   기록 입구 = AcquisitionAudit.flag(kind, detail) - 검토 대기 저장소(AuditReview_v1 · userId · 시각 · 지표 · 값)를 그대로 쓴다(개인 식별 최소).
--   지표: 이동 되돌림(HeightGuard 수평 · 높이 - 이동 능력 · 대시 · 활강 · 순간이동 허가는 HeightGuard가 이미 뺀다) · 골드/분(잡몹 몇 마리 몫) ·
--         명중/분(서버 피해 계산 횟수) · 공통 요청 제한 버림/분 · 보스 처치 시간(진입 무적 직후). 처치/분 · 태초 운(포아송)은 AcquisitionAudit 기존 검사.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.data.SecurityOpsConfig)
local D = C.detect

local SuspicionMonitor = {}
local stats = {} -- [Player] = { gold, hits, drops, reverts0, flaggedAt = { [kind] = os.clock() } } · QUEUE-ALL6 I 리뷰: 약한 키 표는 Player 항목이 조용히 사라져(M1-2c 실측) 강한 표 + 퇴장 때 지움
Players.PlayerRemoving:Connect(function(player)
	stats[player] = nil
end)

local function st(player)
	local s = stats[player]
	if not s then
		s = { gold = 0, hits = 0, drops = 0, flaggedAt = {} }
		stats[player] = s
	end
	return s
end
SuspicionMonitor.stateOf = st -- 검증

-- 잡몹 1마리 골드(계정 최고 스테이지) - 골드 지표 · 감사 기록 "큰 골드" 단위
function SuspicionMonitor.goldPerKill(player)
	local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
	local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
	local stage = require(script.Parent.PlayerProfile).getAccountBestStage(player) or 1
	return math.max(1, InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, stage))
end

function SuspicionMonitor.noteGold(player, amount)
	if typeof(player) ~= "Instance" or type(amount) ~= "number" or amount <= 0 then
		return
	end
	local per = SuspicionMonitor.goldPerKill(player)
	st(player).gold += amount / per
	if amount / per >= require(ReplicatedStorage.Shared.data.SecurityOpsConfig).trail.bigGoldKillEq then
		require(script.Parent.AuditTrail).note(player, "bigGold", ("%.0f(잡몹 %.0f마리 몫)"):format(amount, amount / per))
	end
end

function SuspicionMonitor.noteHit(player)
	if typeof(player) == "Instance" then
		st(player).hits += 1
	end
end

function SuspicionMonitor.noteGateDrop(player)
	if typeof(player) == "Instance" then
		st(player).drops += 1
	end
end

local function flag(player, kind, detail, now)
	local s = st(player)
	if now - (s.flaggedAt[kind] or -math.huge) < D.cooldownSeconds then
		return false
	end
	s.flaggedAt[kind] = now
	require(script.Parent.AcquisitionAudit).flag(player, kind, detail)
	return true
end
SuspicionMonitor.flag = flag

-- 보스 처치 시간: 진입 연출(무적)이 끝난 뒤 bossMinFightSeconds 안에 죽으면 기록
function SuspicionMonitor.noteBossClear(player, fightSeconds, stage)
	if typeof(player) ~= "Instance" or type(fightSeconds) ~= "number" then
		return
	end
	if fightSeconds < D.bossMinFightSeconds then
		flag(player, "suspect_boss_time", ("스테이지 %s 보스 %.2f초 처치(하한 %.1f)"):format(tostring(stage), fightSeconds, D.bossMinFightSeconds), os.clock())
	end
end

-- 순수: 한 창(windowSeconds)의 값 → 넘은 지표 목록 { { kind, detail } }
function SuspicionMonitor.evaluate(window)
	local out = {}
	if window.reverts >= D.moveRevertsPerMin then
		table.insert(out, { "suspect_move", ("이동 되돌림 분당 %d(기준 %d)"):format(window.reverts, D.moveRevertsPerMin) })
	end
	if window.gold >= D.goldKillEqPerMin then
		table.insert(out, { "suspect_gold", ("골드 분당 잡몹 %.0f마리 몫(기준 %d)"):format(window.gold, D.goldKillEqPerMin) })
	end
	if window.hits >= D.hitsPerMin then
		table.insert(out, { "suspect_hits", ("명중 분당 %d(기준 %d)"):format(window.hits, D.hitsPerMin) })
	end
	if window.drops >= D.gateDropsPerMin then
		table.insert(out, { "suspect_requests", ("요청 제한 버림 분당 %d(기준 %d)"):format(window.drops, D.gateDropsPerMin) })
	end
	return out
end

local function moveReverts(player)
	local hs = require(script.Parent.HeightGuard).getState(player)
	return hs and ((hs.reverts or 0) + (hs.hReverts or 0)) or 0
end

-- 한 사람 창 마감(분마다): 값 → 판정 → 기록 → 초기화
function SuspicionMonitor.closeWindow(player, now)
	local s = st(player)
	local reverts = moveReverts(player)
	local window = { reverts = reverts - (s.reverts0 or reverts), gold = s.gold, hits = s.hits, drops = s.drops }
	s.reverts0, s.gold, s.hits, s.drops = reverts, 0, 0, 0
	local flagged = {}
	for _, f in ipairs(SuspicionMonitor.evaluate(window)) do
		if flag(player, f[1], f[2], now) then
			table.insert(flagged, f[1])
		end
	end
	return window, flagged
end

function SuspicionMonitor.start()
	task.spawn(function()
		while true do
			task.wait(D.windowSeconds)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(SuspicionMonitor.closeWindow, player, now)
			end
		end
	end)
end

return SuspicionMonitor
