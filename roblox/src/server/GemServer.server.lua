-- 분해 + 보석 슬롯 장착 + 옵션 변환권 서버 권위 처리(23-2, PRD 20.37/20.38).
-- S20e: 자리 규칙이 바뀌었다 - 보석 장착 · 교체는 **어디서나**(옛 강화대 12stud 제한 제거), 분해도 어디서나(26-3 이후 그대로), 변환 · 리롤(옵션 리롤 · 변환권 구매)은
-- **커뮤니티 센터 보석상인 반경 안에서만**이다(GemMerchantAccess가 요청 시점의 캐릭터 위치로 서버가 직접 잰다).
--
-- 클라이언트로 미는 보석 상태 스냅샷(GemSync RemoteEvent)은 여기서 만들지 않는다 -
-- PlayerProfile.dismantleItem/equipGem/rerollGemOption/tryBuyOptionRerollTicket이 성공할
-- 때마다 PlayerProfile 자신이 GemSync.push를 부른다(GemSync.lua 주석 참고 - 호출부마다
-- push를 챙기게 하면 잊는 사고가 난다, 이번 세션에 실제로 난 버그).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)
local GemEquip = require(script.Parent.GemEquip)
local GemWorkshop = require(script.Parent.GemWorkshop)

local dismantleRequest = Instance.new("RemoteEvent")
dismantleRequest.Name = "DismantleRequest"
dismantleRequest.Parent = ReplicatedStorage

local gemEquipRequest = Instance.new("RemoteEvent")
gemEquipRequest.Name = "GemEquipRequest"
gemEquipRequest.Parent = ReplicatedStorage

-- S20c: 장착 요청의 결과를 클라에 알린다(성공 여부 · 이유 코드 · 요청한 홈). 옛 코드는 실패하면 아무 신호도 안 보내 클라가 왜 안 됐는지 몰랐다. 규칙은 그대로이고 이유만 돌려준다.
--   이유 코드: PlayerProfile.equipGem이 주는 no_class · slot_locked · not_found · grade_too_high + 여기서 거르는 invalid(인자 모양이 틀렸다). (S20e: far(강화대에서 멀다)는 장착에서 더 이상 쓰지 않는다.)
local gemEquipResult = Instance.new("RemoteEvent")
gemEquipResult.Name = "GemEquipResult"
gemEquipResult.Parent = ReplicatedStorage

local rerollRequest = Instance.new("RemoteEvent")
rerollRequest.Name = "GemRerollRequest"
rerollRequest.Parent = ReplicatedStorage

local buyRerollTicketRequest = Instance.new("RemoteEvent")
buyRerollTicketRequest.Name = "BuyRerollTicketRequest"
buyRerollTicketRequest.Parent = ReplicatedStorage

-- S20e: 변환 · 리롤 요청(리롤 · 변환권 구매)의 결과를 클라(보석 공방 창)에 알린다. (action("reroll" | "buy"), success, reason). 성공이면 reason은 nil.
--   이유 코드: out_of_range(보석상인 반경 밖) · no_character · invalid(인자 모양이 틀렸다) + PlayerProfile이 주는 no_class · empty_slot · not_found · not_equipped · not_rerollable · no_ticket ·
--   변환권 구매의 no_gold(골드 부족 - 클라가 가격을 미리 알아 정상 경로에서는 안 나온다).
local workshopResult = Instance.new("RemoteEvent")
workshopResult.Name = "GemWorkshopResult"
workshopResult.Parent = ReplicatedStorage

-- P2.5b C · B: 보석 가공(분해 → 가루 · 일괄 분해 · 재련) 요청과 결과(action, success, reason, data). 판정 = GemCraftRequest. 가루 · 보석 · 골드가 바뀌는 되돌릴 수 없는 사건이라 성공하면 즉시저장.
local GemCraftRequest = require(script.Parent.GemCraftRequest)

local gemCraftRequest = Instance.new("RemoteEvent")
gemCraftRequest.Name = "GemCraftRequest"
gemCraftRequest.Parent = ReplicatedStorage

local gemCraftResult = Instance.new("RemoteEvent")
gemCraftResult.Name = "GemCraftResult"
gemCraftResult.Parent = ReplicatedStorage

gemCraftRequest.OnServerEvent:Connect(function(player, action, a, b, c)
	local success, reason, data = GemCraftRequest.handle(player, action, a, b, c)
	if success then
		ImmediateSave.request(player)
	end
	gemCraftResult:FireClient(player, type(action) == "string" and action or "", success, reason, data)
end)

-- 옵션 변환권 가격(20.37 [5] "몬스터 1마리당 골드 × N") - 배수는 GemData.rerollTicketGoldMultiplier(클라이언트 표시용과
-- 단일 출처). 28-2 [8] 3번: 기준 스테이지는 지금 서 있는 곳이 아니라 계정 최고 스테이지다(스테이지 1로 내려가 싸게 사는 구멍).
local function rerollTicketPrice(player)
	local stage = PlayerProfile.getAccountBestStage(player)
	return GoldCost.cost(MonsterData.tier1.goldDrop, stage, "rerollTicket") * GemData.rerollTicketGoldMultiplier -- P2 C1: GoldCost(기준 1 - P2 전과 같은 값)
end

-- 분해는 판매(SellRequest)와 같은 층의 되돌릴 수 없는 사건이다 - 즉시저장. 사용자 지시로
-- 판매와 똑같이 근접 제한을 없앤다(26-3 수정 - 원래는 PRD 20.37 [3] "분해 UI는 강화대에
-- 둔다"를 따라 강화대 근접 검사를 걸었으나, 판매는 어디서나 되는데 분해만 강화대 근처로
-- 막혀 있어 혼란을 줬다 - SellRequest와 같은 검증 수준으로 맞춘다).
dismantleRequest.OnServerEvent:Connect(function(player, index)
	if type(index) ~= "number" then
		return
	end

	local success, gradeOrReason = PlayerProfile.dismantleItem(player, math.floor(index))
	if success then
		ImmediateSave.request(player)
		print(("[forge-game] 분해: %s - %s 등급 보석 획득"):format(player.Name, gradeOrReason))
	end
end)

-- 보석 슬롯 장착(교체)도 판매·분해와 같은 층이다 - 되돌릴 수 없지는 않지만(다시 교체하면
-- 그만) 무기 전투력이 바로 바뀌는 사건이라 즉시저장한다(강화 결과와 같은 판단).
gemEquipRequest.OnServerEvent:Connect(function(player, slot, gemInventoryIndex)
	local success, reason = GemEquip.handle(player, slot, gemInventoryIndex) -- S20e: 어디서나 - 자리 검사 없음
	if success then
		ImmediateSave.request(player)
	end
	gemEquipResult:FireClient(player, success, reason, type(slot) == "number" and slot or nil)
end)

-- 26-3(PRD 20.67 [10]): 리롤 대상 = 홈 5 + 장비 3부위(가방 · 착용). kind로 어느 함수를 부를지 가르는 것은 GemWorkshop이 한다(kind="gem" key=슬롯 · "equipped" key=부위명 · "bag" key=인벤토리 index).
-- S20e: 판정(모양 · 보석상인 반경 · PlayerProfile)은 GemWorkshop 한 곳이다 - 여기서는 저장과 결과 알림만 한다.
rerollRequest.OnServerEvent:Connect(function(player, kind, key)
	local success, reason = GemWorkshop.reroll(player, kind, key)
	if success then
		ImmediateSave.request(player)
	end
	workshopResult:FireClient(player, "reroll", success, reason)
end)

-- gradeId: "ancient" 또는 "primordial"만 유효하다(GemData.optionPoolByGrade). 가격은
-- 클라이언트가 보낸 값을 절대 믿지 않는다 - 여기서 매번 다시 계산한다(EnhanceServer의
-- Enhance.getCost와 같은 원칙).
buyRerollTicketRequest.OnServerEvent:Connect(function(player, gradeId)
	local cost = rerollTicketPrice(player)
	local success, reason = GemWorkshop.buyTicket(player, gradeId, cost)
	if success then
		ImmediateSave.request(player)
		print(("[forge-game] 변환권 구매: %s - %s (비용 %d)"):format(player.Name, gradeId, cost))
	end
	workshopResult:FireClient(player, "buy", success, reason)
end)
