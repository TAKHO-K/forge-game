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
local ImmediateSave = require(script.Parent.ImmediateSave)

local EnhanceService = {}

local enhanceResult -- 결과 RemoteEvent(EnhanceServer.server.lua가 init으로 넘긴다). 없으면 발신만 건너뛴다(검증 하네스).

-- 요청 자체의 연타 방지. 결과를 화면에 보여줄 시간도 필요하고, 매크로성 연타로 서버 연산(및 ImmediateSave 타이머 갱신)이 낭비되는 것도 막는다.
local ENHANCE_REQUEST_COOLDOWN_SECONDS = 0.5
EnhanceService.requestCooldownSeconds = ENHANCE_REQUEST_COOLDOWN_SECONDS
local lastRequestTick = setmetatable({}, { __mode = "k" })

function EnhanceService.init(resultEvent)
	enhanceResult = resultEvent
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
function EnhanceService.handleRequest(player)
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

	-- [3] 골드 · 재료를 **둘 다 확인한 뒤** 둘 다 차감한다(하나만 빠지는 경로 0). 확인 ~ 차감 ~ 판정 사이에 yield가 없어 확인이 그대로 유효하다.
	-- 재료는 19 ~ 24강 시도에만 든다(EnhanceMaterialData.costByLevel - 0 ~ 18강은 골드만). 검사 순서: 최대 단계 → 골드 → 재료.
	if (PlayerProfile.getGold(player) or 0) < cost then
		return send(player, { result = "insufficient_gold", level = weapon.level, cost = cost })
	end
	local materialCost = EnhanceMaterialData.costByLevel[weapon.level]
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
	-- 다른 요청이 끼어들 수 없다. 방지권(S05)은 아직 없어서 flags는 항상 { false, false }다.
	local oldLevel = weapon.level -- setWeaponLevel이 weapon 테이블을 바로 고치므로 미리 남겨둔다
	local oldGauge = PlayerProfile.getEnhanceGauge(player)
	local outcome = Enhance.tryEnhance(oldLevel, oldGauge, { false, false })
	PlayerProfile.setWeaponLevel(player, outcome.level)
	PlayerProfile.setEnhanceGauge(player, outcome.gauge)

	local payload = send(player, {
		result = outcome.result,
		level = outcome.level,
		cost = cost,
		gauge = outcome.gauge,
		gaugeMax = EnhanceConfig.gauge.max,
		gaugeGain = math.max(0, outcome.gauge - oldGauge),
	})

	print(("[forge-game] 강화 결과: %s - %s (레벨 %d -> %d, 비용 %d, 게이지 %d -> %d)"):format(
		player.Name, outcome.result, oldLevel, outcome.level, cost, oldGauge, outcome.gauge))

	-- [4] 즉시 저장. 골드 차감과 레벨 · 게이지 변경은 이미 같은 profile 테이블에 함께 반영됐다 - SaveSystem.saveProfile이 그 테이블 전체를 한 번의
	-- UpdateAsync로 쓰므로, 이 저장이 실패해도(재시도 소진·stale_session) "골드만 빠지고 강화는 안 남는" 중간 상태는 구조적으로 생기지 않는다 - 다음
	-- 로드가 마지막 성공한 저장 시점으로 통째로 돌아갈 뿐이다(SaveCoordinator가 실패 시 안내까지 처리한다).
	ImmediateSave.request(player)
	return payload
end

return EnhanceService
