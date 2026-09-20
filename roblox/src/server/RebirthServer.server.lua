-- 환생 서버 권위 처리(23-2, PRD 20.38 [1][2]). 클라이언트는 "환생하겠다"는 요청만 보낸다
-- (RemoteEvent 인자 없음, EnhanceServer.server.lua와 같은 패턴) - 레벨 조건 확인·되돌릴 수
-- 없는 반영을 전부 여기서 한 번의 동기 흐름으로 처리한다. 확인창(되돌릴 수 없다는 경고)은
-- 클라이언트(EnhanceUI.client.lua 환생 탭)가 이 요청을 보내기 전에 띄운다 - 서버는 요청이 왔다는
-- 사실 자체를 "이미 확인받았다"로 믿는다(강화 요청과 같은 신뢰 경계).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ImmediateSave = require(script.Parent.ImmediateSave)
local RebirthAccess = require(script.Parent.RebirthAccess)

local rebirthRequest = Instance.new("RemoteEvent")
rebirthRequest.Name = "RebirthRequest"
rebirthRequest.Parent = ReplicatedStorage

local rebirthResult = Instance.new("RemoteEvent")
rebirthResult.Name = "RebirthResult"
rebirthResult.Parent = ReplicatedStorage

-- 요청 연타 방지(EnhanceServer와 같은 이유 - 되돌릴 수 없는 조작이라 매크로성 연타를
-- 서버가 반복 처리할 이유가 없다).
local REBIRTH_REQUEST_COOLDOWN_SECONDS = 1.0
local lastRequestTick = setmetatable({}, { __mode = "k" })

rebirthRequest.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local last = lastRequestTick[player]
	if last and now - last < REBIRTH_REQUEST_COOLDOWN_SECONDS then
		return
	end
	lastRequestTick[player] = now

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	-- 어느 자리(강화대 환생 탭 · 커뮤니티 환생 제단)에서든 서버가 위치 · 보스전 · 강화 중을 직접 잰다(RebirthAccess.attempt). 클라가 어디서 눌렀는지는 믿지 않는다.
	local payload = RebirthAccess.attempt(player, rootPart and rootPart.Position)
	if not payload then
		return -- 자리 밖 · 캐릭터 없음은 조용히 무시
	end
	rebirthResult:FireClient(player, payload)
	if payload.success then
		-- 보석 탭 갱신(무기 등급·슬롯 자동 지급 포함)은 PlayerProfile.rebirth 안에서
		-- GemSync.push가 이미 처리한다 - 여기서 또 챙길 필요가 없다(GemSync.lua 주석 참고).
		print(("[forge-game] 환생: %s - rebirthCount %d"):format(player.Name, payload.rebirthCount))
		-- 되돌릴 수 없는 사건(강화·클래스 선택과 같은 층) - 즉시저장한다.
		ImmediateSave.request(player)
	end
end)
