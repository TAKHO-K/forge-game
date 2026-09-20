-- 강화 서버 권위 처리 본체(10-2, 28-1 S03에서 EnhanceServer.server.lua의 핸들러 본문을 모듈로 옮겼다). RemoteEvent 연결은 스크립트가 하고, 요청 1건의
-- 처리(강화대 근접 확인 · 상한 확인 · 골드 · 재료 확인/차감 · 확률 판정 · 결과 반영)는 전부 여기 handleRequest 하나다 - 자동 검증(EnhanceVerify)이
-- 스크립트를 require할 수 없어서(Script는 모듈이 아니다) 같은 함수를 바로 부를 수 있게 분리했다. 동작 변경 없음(아래 S03 항목 제외).
--
-- 원자성(PRD 20.18 [3]): 골드 확인/차감부터 결과 반영까지 **yield 지점이 없다** - RemoteEvent 핸들러 하나가 끝까지 실행된 뒤에야 같은 플레이어의
-- 다음 요청이 처리되므로 골드 차감과 결과 반영 사이에 값이 바뀔 여지가 없다(ImmediateSave.request 전까지 yield 금지).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local PlayerProfile = require(script.Parent.PlayerProfile)
local EnhancePolicy = require(script.Parent.EnhancePolicy)
local ImmediateSave = require(script.Parent.ImmediateSave)

local EnhanceService = {}

local enhanceResult -- 결과 RemoteEvent(EnhanceServer.server.lua가 init으로 넘긴다). 없으면 발신만 건너뛴다(검증 하네스).
local enhanceAnnounce -- 20강+ 성공 공지 RemoteEvent(30-0 S08) - 같은 서버 전원에게 FireAllClients. 없으면 공지만 건너뛴다(검증 하네스).

-- 요청 자체의 연타 방지. 결과를 화면에 보여줄 시간도 필요하고, 매크로성 연타로 서버 연산(및 ImmediateSave 타이머 갱신)이 낭비되는 것도 막는다.
local ENHANCE_REQUEST_COOLDOWN_SECONDS = 0.5
EnhanceService.requestCooldownSeconds = ENHANCE_REQUEST_COOLDOWN_SECONDS
local lastRequestTick = setmetatable({}, { __mode = "k" })

-- "강화 중"인가(S12b F - 환생 요청이 이 동안 거절된다). 강화는 한 요청 안에서 끝나는 동기 처리라 진행 중인 구간이 없다 - 마지막 요청 처리 직후 요청 쿨다운(결과를 화면에 보여줄 시간) 안이면 "강화 중"으로 본다.
function EnhanceService.isBusy(player)
	local last = lastRequestTick[player]
	return last ~= nil and os.clock() - last < ENHANCE_REQUEST_COOLDOWN_SECONDS
end

function EnhanceService.init(resultEvent, announceEvent)
	enhanceResult = resultEvent
	enhanceAnnounce = announceEvent
end

local function isNearStation(rootPart)
	local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
	return (rootPart.Position - stationPosition).Magnitude <= WorldConfig.enhance.interactionRangeStuds
end

local function send(player, payload)
	if enhanceResult then
		enhanceResult:FireClient(player, payload)
	end
	return payload
end

-- 반환: 클라에 보낸 결과 payload(요청이 조용히 무시되면 nil). payload = { result, level, cost, gauge, gaugeMax, gaugeGain } - 기존 필드
-- 이름은 그대로고 gauge(다음 게이지) · gaugeMax · gaugeGain(이번 실패가 실제로 채운 양, 성공이면 0)이 S03에서 붙었다.
-- 재료가 모자라면(S04) { result = "insufficient_material", level, cost, materialId, need, have } - 골드도 재료도 안 빠진다.
-- 방지권(S05): useDropTicket · useResetTicket = 클라가 켠 토글(boolean, 없으면 false). 서버가 다시 검증한다(보유 ≥ 1 · 단계 ≥ usableFromLevel · 게이지가 가득이
-- 아님) - 안 되면 그 플래그만 조용히 false로 바꾼다(요청 거절이 아니다). 결과는 원래 확률표로 굴린 뒤 **실제로 막았을 때만** 그 방지권 1장을 차감한다.
-- payload에 blockedBy("drop" / "reset" / nil) · ticketsLeft({ drop, reset } - 남은 장수)가 붙는다. 규제 관문(EnhancePolicy)이 거부하면
-- { result = "paid_random_restricted", level } - 지금은 paidInputIds가 비어 있어 절대 안 탄다.
function EnhanceService.handleRequest(player, useDropTicket, useResetTicket)
	local now = os.clock()
	local last = lastRequestTick[player]
	if last and now - last < ENHANCE_REQUEST_COOLDOWN_SECONDS then
		return nil
	end
	lastRequestTick[player] = now

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not isNearStation(rootPart) then
		return nil -- 강화대 밖 - 공격 헛스윙과 같은 취급으로 조용히 무시
	end

	local weapon = PlayerProfile.getWeapon(player)
	if not weapon then
		return nil -- 프로필 로드가 아직 안 끝났다
	end

	-- [3] 상한 확인 - Enhance.getCost는 상한이면 nil을 돌려준다(Enhance.lua 참고).
	local cost = Enhance.getCost(weapon.level)
	if not cost then
		return send(player, { result = "max", level = weapon.level })
	end

	-- [3] 방지권 플래그 재검증 + 규제 관문(차감 전, 캐시만 읽는다 - yield 없음). 관문에 넘기는 inputIds = 이번 시도가 소모하는 것들의 id.
	local oldGauge = PlayerProfile.getEnhanceGauge(player)
	local useDrop, useReset = Enhance.resolveProtectionFlags(weapon.level, oldGauge >= EnhanceConfig.gauge.max, useDropTicket, useResetTicket,
		PlayerProfile.getProtectionTicket(player, "drop") or 0, PlayerProfile.getProtectionTicket(player, "reset") or 0)
	local materialCost = EnhanceMaterialData.costByLevel[weapon.level]
	local inputIds = { "gold" }
	if materialCost then
		table.insert(inputIds, materialCost.id)
	end
	if useDrop then
		table.insert(inputIds, "dropTicket")
	end
	if useReset then
		table.insert(inputIds, "resetTicket")
	end
	local allowed, reason = EnhancePolicy.canAttempt(player, inputIds)
	if not allowed then
		return send(player, { result = reason, level = weapon.level })
	end

	-- [3] 골드 · 재료를 **둘 다 확인한 뒤** 둘 다 차감한다(하나만 빠지는 경로 0). 확인 ~ 차감 ~ 판정 사이에 yield가 없어 확인이 그대로 유효하다.
	-- 재료는 19 ~ 24강 시도에만 든다(EnhanceMaterialData.costByLevel - 0 ~ 18강은 골드만). 검사 순서: 최대 단계 → 골드 → 재료.
	if (PlayerProfile.getGold(player) or 0) < cost then
		return send(player, { result = "insufficient_gold", level = weapon.level, cost = cost })
	end
	if materialCost then
		local have = PlayerProfile.getMaterial(player, materialCost.id) or 0
		if have < materialCost.count then
			return send(player, { result = "insufficient_material", level = weapon.level, cost = cost, materialId = materialCost.id, need = materialCost.count, have = have })
		end
	end
	PlayerProfile.trySpendGold(player, cost)
	if materialCost then
		PlayerProfile.trySpendMaterial(player, materialCost.id, materialCost.count)
	end

	-- [3] 확률 판정 - 클라이언트가 보낸 값은 아무것도 쓰지 않는다. 여기까지 전부 동기 실행이라(yield 없음) 골드 차감과 결과 반영 사이에
	-- 다른 요청이 끼어들 수 없다. 방지권은 원래 확률표로 굴린 결과가 하락 · 초기화일 때만 막는다(tryEnhance가 blockedBy를 돌려준다) - 그때만 1장을 차감한다.
	local oldLevel = weapon.level -- setWeaponLevel이 weapon 테이블을 바로 고치므로 미리 남겨둔다
	local outcome = Enhance.tryEnhance(oldLevel, oldGauge, { useDrop, useReset })
	PlayerProfile.setWeaponLevel(player, outcome.level)
	PlayerProfile.setEnhanceGauge(player, outcome.gauge)
	if outcome.blockedBy then
		PlayerProfile.trySpendProtectionTicket(player, outcome.blockedBy, 1)
	end

	local payload = send(player, {
		result = outcome.result,
		level = outcome.level,
		cost = cost,
		gauge = outcome.gauge,
		gaugeMax = EnhanceConfig.gauge.max,
		gaugeGain = math.max(0, outcome.gauge - oldGauge),
		blockedBy = outcome.blockedBy,
		ticketsLeft = { drop = PlayerProfile.getProtectionTicket(player, "drop"), reset = PlayerProfile.getProtectionTicket(player, "reset") },
	})

	print(("[forge-game] 강화 결과: %s - %s (레벨 %d -> %d, 비용 %d, 게이지 %d -> %d%s)"):format(
		player.Name, outcome.result, oldLevel, outcome.level, cost, oldGauge, outcome.gauge,
		outcome.blockedBy and (", 방지권 " .. outcome.blockedBy .. " 소모") or ""))

	-- 30-0 S08: 새 단계가 announceFromLevel(20) 이상인 **성공**은 같은 서버 전원에게 알린다(채팅 시스템 메시지는 클라 EnhanceAnnounceClient가 만든다). 실패 · 방지권 · 19강 이하 성공은 없다.
	if outcome.result == "success" and outcome.level >= EnhanceConfig.announceFromLevel and enhanceAnnounce then
		enhanceAnnounce:FireAllClients(player.DisplayName, outcome.level)
	end

	-- [4] 즉시 저장. 골드 차감과 레벨 · 게이지 변경은 이미 같은 profile 테이블에 함께 반영됐다 - SaveSystem.saveProfile이 그 테이블 전체를 한 번의
	-- UpdateAsync로 쓰므로, 이 저장이 실패해도(재시도 소진·stale_session) "골드만 빠지고 강화는 안 남는" 중간 상태는 구조적으로 생기지 않는다 - 다음
	-- 로드가 마지막 성공한 저장 시점으로 통째로 돌아갈 뿐이다(SaveCoordinator가 실패 시 안내까지 처리한다).
	ImmediateSave.request(player)
	return payload
end

return EnhanceService
