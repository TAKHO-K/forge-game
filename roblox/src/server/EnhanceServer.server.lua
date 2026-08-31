-- 강화 서버 권위 처리(10-2). 클라이언트는 "강화하겠다"는 요청만 보낸다(RemoteEvent 인자
-- 없음) - 강화대 근접 확인·상한 확인·골드 확인/차감·확률 판정·결과 반영을 전부 여기서,
-- 중간에 다른 요청이 끼어들 수 없게 한 번의 동기 흐름으로 처리한다(아래 requestImmediateSave
-- 호출 전까지는 yield 지점이 없다 - RemoteEvent 핸들러 하나가 끝까지 실행된 뒤에야 같은
-- 플레이어의 다음 요청이 처리되므로, 골드 차감과 결과 반영 사이에 값이 바뀔 여지가 없다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveCoordinator = require(script.Parent.SaveCoordinator)

local enhanceRequest = Instance.new("RemoteEvent")
enhanceRequest.Name = "EnhanceRequest"
enhanceRequest.Parent = ReplicatedStorage

local enhanceResult = Instance.new("RemoteEvent")
enhanceResult.Name = "EnhanceResult"
enhanceResult.Parent = ReplicatedStorage

-- 요청 자체의 연타 방지. 결과를 화면에 보여줄 시간도 필요하고, 매크로성 연타로 서버
-- 연산(및 아래 즉시저장 스로틀 타이머 갱신)이 낭비되는 것도 막는다.
local ENHANCE_REQUEST_COOLDOWN_SECONDS = 0.5
local lastRequestTick = setmetatable({}, { __mode = "k" })

-- 즉시저장 스로틀(10-1 미결 항목 해소, 10-2 [4]). 강화 성공/실패는 되돌릴 수 없는 사건이라
-- 결과가 확정되는 즉시 저장해야 하지만, 연타마다 DataStore를 치면 예산을 넘긴다 - "마지막
-- 저장 후 이 시간(초)이 안 지났으면 그 창이 끝나는 시점에 한 번만 몰아서 저장한다"는
-- 스로틀(leading + trailing)을 쓴다. 느리게 누르면(간격 6초 이상) 매번 즉시 저장되고,
-- 연타할 때만 묶인다 - 정상적인 강화 페이스(결과 확인하고 다시 누름)에서는 사실상 항상
-- "즉시"다.
--
-- 예산 검산(10-1 자동저장과 같은 기준, N=100명 동시접속 가정): DataStore 쓰기 예산은
-- 로블록스 공식 문서 기준 분당 60+인원수×10 = 100명이면 분당 1060회. 6초 스로틀이면
-- 1인당 분당 최대 10회 저장 - 100명 전원이 쉬지 않고 연타해도 분당 1000회로 예산 안에
-- 들어온다. 1초로 잡으면(1인당 분당 60회) 100명이 전부 연타할 때 분당 6000회로 예산을
-- 5배 넘긴다 - 그래서 1초가 아니라 6초를 골랐다.
local IMMEDIATE_SAVE_THROTTLE_SECONDS = 6
local lastImmediateSaveAt = setmetatable({}, { __mode = "k" })
local pendingSaveScheduled = setmetatable({}, { __mode = "k" })

local function requestImmediateSave(player)
	local now = os.clock()
	local last = lastImmediateSaveAt[player]
	if not last or now - last >= IMMEDIATE_SAVE_THROTTLE_SECONDS then
		lastImmediateSaveAt[player] = now
		SaveCoordinator.saveForPlayer(player)
		return
	end

	if pendingSaveScheduled[player] then
		return -- 이미 이번 창 끝에 저장이 예약돼 있다 - 최신 상태는 그 저장이 알아서 반영한다
	end
	pendingSaveScheduled[player] = true
	task.delay(IMMEDIATE_SAVE_THROTTLE_SECONDS - (now - last), function()
		pendingSaveScheduled[player] = nil
		lastImmediateSaveAt[player] = os.clock()
		SaveCoordinator.saveForPlayer(player)
	end)
end

local function isNearStation(rootPart)
	local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
	return (rootPart.Position - stationPosition).Magnitude <= WorldConfig.enhance.interactionRangeStuds
end

enhanceRequest.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local last = lastRequestTick[player]
	if last and now - last < ENHANCE_REQUEST_COOLDOWN_SECONDS then
		return
	end
	lastRequestTick[player] = now

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not isNearStation(rootPart) then
		return -- 강화대 밖 - 공격 헛스윙과 같은 취급으로 조용히 무시
	end

	local weapon = PlayerProfile.getWeapon(player)
	if not weapon then
		return -- 프로필 로드가 아직 안 끝났다
	end

	-- [3] 상한 확인 - Enhance.getCost는 상한이면 nil을 돌려준다(Enhance.lua 참고).
	local cost = Enhance.getCost(weapon.level)
	if not cost then
		enhanceResult:FireClient(player, { result = "max", level = weapon.level })
		return
	end

	-- [3] 골드 확인+차감을 한 함수 안에서 원자적으로(PlayerProfile.trySpendGold).
	if not PlayerProfile.trySpendGold(player, cost) then
		enhanceResult:FireClient(player, { result = "insufficient_gold", level = weapon.level, cost = cost })
		return
	end

	-- [3] 확률 판정 - 클라이언트가 보낸 값은 아무것도 쓰지 않는다. 여기까지 전부 동기
	-- 실행이라(yield 없음) 골드 차감과 결과 반영 사이에 다른 요청이 끼어들 수 없다.
	local oldLevel = weapon.level -- setWeaponLevel이 weapon 테이블을 바로 고치므로 미리 남겨둔다
	local outcome = Enhance.tryEnhance(weapon.level)
	PlayerProfile.setWeaponLevel(player, outcome.level)

	enhanceResult:FireClient(player, {
		result = outcome.result,
		level = outcome.level,
		cost = cost,
	})

	print(("[forge-game] 강화 결과: %s - %s (레벨 %d -> %d, 비용 %d)"):format(
		player.Name, outcome.result, oldLevel, outcome.level, cost))

	-- [4] 즉시 저장. 골드 차감과 레벨 변경은 이미 같은 profile 테이블에 함께 반영됐다 -
	-- SaveSystem.saveProfile이 그 테이블 전체를 한 번의 UpdateAsync로 쓰므로, 이 저장이
	-- 실패해도(재시도 소진·stale_session) "골드만 빠지고 강화는 안 남는" 중간 상태는
	-- 구조적으로 생기지 않는다 - 다음 로드가 마지막 성공한 저장 시점으로 통째로 돌아갈
	-- 뿐이다(SaveCoordinator가 실패 시 안내까지 처리한다).
	requestImmediateSave(player)
end)
