-- S20e 자동 검증(서버) - 보석상인 자리 판정 · 변환 · 리롤 요청의 서버 반경 검사 · 안내 플래그(hints.gemMerchantUsed) · 저장 이관(v29 → v30).
--   runPure()             (가) 순수 함수: GemMerchantAccess.evaluate · WorldConfig.gemMerchant 배치 · SaveSystem 이관 · 검사 (플레이어 불필요)
--   runLive(player, env)  (나) 실제 Player · 실제 프로필: GemWorkshop(reroll · buyTicket)의 이유 코드 · 반경 밖 거절(상태 불변) · 반경 안 성공 · 플래그가 처음 성공에서 켜진다 ·
--                         실제 캐릭터를 보석상인 앞 · 밖으로 옮겨 기본 반경 판정으로 재기 · DataStore 왕복(검증용 키)으로 플래그 유지. 끝에서 프로필을 원래대로 되돌린다.
-- 규칙 · 비용은 이 세션에서 바뀌지 않는다(리롤 = 변환권 1장 · 구매 = 골드). 이 검증이 "자리만 바뀌었다"를 못 박는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Gem = require(ReplicatedStorage.Shared.Gem)
local GemCraft = require(ReplicatedStorage.Shared.GemCraft) -- P2.5b C: 변환권 가루
local PlayerProfile = require(script.Parent.PlayerProfile)
local RebirthAccess = require(script.Parent.RebirthAccess)
local SaveSystem = require(script.Parent.SaveSystem)
local GemMerchantAccess = require(script.Parent.GemMerchantAccess)
local GemWorkshop = require(script.Parent.GemWorkshop)

local GemMerchantVerify = {}

local function tally(label)
	local self = { pass = 0, total = 0 }
	function self.check(name, ok)
		self.total += 1
		if ok then
			self.pass += 1
		end
		print(("[S20e][%s] %s %s"):format(label, name, ok and "O" or "X"))
	end
	return self
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local alwaysNear = function()
	return true
end

-- ═══ (가) 순수 함수 ═══
function GemMerchantVerify.runPure()
	print("===S20e 검증 시작(가: 보석상인 자리 판정 · 배치 · 저장 이관)===")
	local t = tally("가")
	local merchant = WorldConfig.gemMerchant
	local center = GemMerchantAccess.position()
	local range = merchant.interactionRangeStuds

	local okNil, whyNil = GemMerchantAccess.evaluate(nil)
	t.check("캐릭터 위치가 없으면 no_character", okNil == false and whyNil == "no_character")
	t.check("보석상인 바로 앞(3 stud)은 통과", GemMerchantAccess.evaluate(center + Vector3.new(3, 0, 0)) == true)
	t.check("반경 안 끝(반경 - 0.1)은 통과", GemMerchantAccess.evaluate(center + Vector3.new(range - 0.1, 0, 0)) == true)
	local okEdge, whyEdge = GemMerchantAccess.evaluate(center + Vector3.new(range + 0.1, 0, 0))
	t.check("반경 밖 끝(반경 + 0.1)은 out_of_range", okEdge == false and whyEdge == "out_of_range")
	local okFar, whyFar = GemMerchantAccess.evaluate(center + Vector3.new(100, 0, 0))
	t.check("100 stud 밖은 out_of_range", okFar == false and whyFar == "out_of_range")
	local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
	local okStation, whyStation = GemMerchantAccess.evaluate(stationPosition)
	t.check("강화대 자리는 더 이상 통과하지 않는다(변환 · 리롤은 보석상인 전용)", okStation == false and whyStation == "out_of_range")
	local altar = RebirthAccess.altarPosition()
	local okAltar = GemMerchantAccess.evaluate(altar)
	t.check("환생 제단 자리도 통과하지 않는다(제단 - 보석상인 거리 > 반경)", okAltar == false and (altar - center).Magnitude > range)

	t.check(("배치: 프롬프트 거리 %s < 서버 반경 %s(프롬프트가 뜬 곳에서 누른 요청은 항상 반경 안)"):format(tostring(merchant.promptDistanceStuds), tostring(range)),
		merchant.promptDistanceStuds < range and range > 0)
	local toAltar = (altar - center).Magnitude
	t.check(("배치: 환생 제단 옆(거리 %.1f - 두 프롬프트 반경이 같은 자리에서 겹치지 않을 만큼 · 옆이라 부를 만큼)"):format(toAltar),
		toAltar >= WorldConfig.rebirthAltar.promptDistanceStuds + 4 and toAltar <= 30 and merchant.guideSeconds > 0)

	-- 저장 이관: v29 → v30
	local old = SaveSystem.defaultProfile()
	old.version = 29
	old.hints = nil -- v29까지는 이 필드가 없었다
	local migrated = SaveSystem.migrate(old)
	t.check(("이관 v29 → v%d(기대 %d): hints 표 생성 · gemMerchantUsed = false · isValidProfile"):format(migrated.version, SaveConfig.saveVersion),
		migrated.version == SaveConfig.saveVersion and type(migrated.hints) == "table" and migrated.hints.gemMerchantUsed == false and SaveSystem.isValidProfile(migrated))
	local kept = SaveSystem.defaultProfile()
	kept.version = 29
	kept.hints = { gemMerchantUsed = true }
	t.check("이미 true인 값은 이관이 지우지 않는다", SaveSystem.migrate(kept).hints.gemMerchantUsed == true)
	local function validWith(mutate)
		local copy = deepCopy(migrated)
		mutate(copy)
		return SaveSystem.isValidProfile(copy)
	end
	t.check("검사: hints 없음 · 표 아님 · gemMerchantUsed 문자열은 거절 / nil · true는 통과(값이 없으면 false로 본다)",
		not validWith(function(copy) copy.hints = nil end)
			and not validWith(function(copy) copy.hints = 3 end)
			and not validWith(function(copy) copy.hints.gemMerchantUsed = "yes" end)
			and validWith(function(copy) copy.hints.gemMerchantUsed = nil end)
			and validWith(function(copy) copy.hints.gemMerchantUsed = true end))
	t.check("새 프로필의 기본값: hints.gemMerchantUsed = false", SaveSystem.defaultProfile().hints.gemMerchantUsed == false)
	print(("===S20e 검증 끝(가)=== %d/%d 통과"):format(t.pass, t.total))
end

-- ═══ (나) 실제 Player ═══
function GemMerchantVerify.runLive(player, env)
	print("===S20e 검증 시작(나: 실제 프로필 - 보석상인 반경 검사 · 이유 코드 · 플래그 · 왕복)===")
	local t = tally("나")
	env.ensureBackup(player)
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1]) -- 직업을 아직 안 골랐으면 첫 직업(백업이 복원한다)
	end
	local profile = PlayerProfile.getProfile(player)
	local weapon = PlayerProfile.getWeapon(player)
	local tickets = profile.purchases.optionRerollTickets
	-- 백업(DevTools 스냅샷)이 되돌리지 않는 것: 변환권 · 안내 플래그 · 홈 5칸의 보석 - 이 검증이 스스로 되돌린다.
	local saved = {
		tickets = deepCopy(tickets),
		flag = profile.hints.gemMerchantUsed,
		gems = deepCopy(weapon.gems),
		unlocked = deepCopy(weapon.slotUnlocked),
		bag = deepCopy(profile.inventory),
		savedAt = profile.savedAt,
	}
	local function ticketsText()
		return ("고대 %d · 태초 %d"):format(tickets.ancient, tickets.primordial)
	end
	local function state()
		return ticketsText() .. " | 골드 " .. tostring(PlayerProfile.getGold(player)) .. " | 옵션 " .. tostring(weapon.gems[1] and weapon.gems[1].option and weapon.gems[1].option.id)
	end

	-- 시험 상태: 1번 홈 = 태초 보석 · 변환권 없음 · 플래그 false · 골드 충분
	for slot = 1, Gem.slotCount do
		weapon.slotUnlocked[slot] = true
	end
	weapon.gems[1] = { grade = "primordial", itemLevel = 30 }
	weapon.gems[2] = { grade = "epic", itemLevel = 30 }
	tickets.ancient, tickets.primordial = 0, 0
	profile.hints.gemMerchantUsed = false
	player:SetAttribute("GemMerchantUsed", false)
	PlayerProfile.addGold(player, 10000000 - PlayerProfile.getGold(player))
	local base = state()

	local nearRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local realNear = GemMerchantAccess.check(player)
	t.check(("시험 캐릭터는 보석상인 반경 밖이다(기본 판정 %s - 검증 캐릭터가 아레나 · 사냥터에 있다)"):format(tostring(realNear)), nearRoot ~= nil and realNear == false)

	-- 반경 밖 = 기본 판정(GemMerchantAccess.check) - 클라가 요청을 직접 보내는 것과 같은 서버 경로
	local ok1, why1 = GemWorkshop.reroll(player, "gem", 1)
	t.check("반경 밖에서 리롤 요청 -> out_of_range + 상태 불변(변환권 · 골드 · 옵션)", ok1 == false and why1 == "out_of_range" and state() == base and profile.hints.gemMerchantUsed == false)
	local ok2, why2 = GemWorkshop.buyTicket(player, "primordial", 1000)
	t.check("반경 밖에서 변환권 구매 요청 -> out_of_range + 상태 불변(골드가 안 나간다)", ok2 == false and why2 == "out_of_range" and state() == base and profile.hints.gemMerchantUsed == false)
	local ok2b, why2b = GemWorkshop.reroll(player, "gem", 1, function()
		return false, "no_character"
	end)
	t.check("캐릭터가 없으면 no_character(반경 판정이 준 이유 그대로)", ok2b == false and why2b == "no_character")

	-- 요청 모양 검사(반경보다 먼저 - 잘못된 요청은 어디서든 invalid)
	local ok3, why3 = GemWorkshop.reroll(player, "hat", 1, alwaysNear)
	local ok4, why4 = GemWorkshop.reroll(player, "gem", "1", alwaysNear)
	local ok5, why5 = GemWorkshop.reroll(player, "equipped", "hat", alwaysNear)
	local ok6, why6 = GemWorkshop.buyTicket(player, "epic", 1000, alwaysNear)
	local ok7, why7 = GemWorkshop.reroll(player, "gem", 1)
	t.check("모르는 kind · 문자열 key · 없는 부위 · 변환권 없는 등급 -> invalid + 상태 불변",
		not ok3 and why3 == "invalid" and not ok4 and why4 == "invalid" and not ok5 and why5 == "invalid" and not ok6 and why6 == "invalid" and state() == base)
	t.check("모양이 맞으면 반경 밖 요청은 invalid가 아니라 out_of_range다", ok7 == false and why7 == "out_of_range")

	-- 반경 안(판정을 갈아 끼움): 변환권이 없으면 no_ticket · 구매 뒤 리롤 성공 · 플래그가 처음 성공에서 켜진다
	local ok8, why8 = GemWorkshop.reroll(player, "gem", 1, alwaysNear)
	t.check("반경 안 · 변환권 0장 -> no_ticket + 상태 불변 + 플래그 그대로(실패는 안내를 줄이지 않는다)", ok8 == false and why8 == "no_ticket" and state() == base and profile.hints.gemMerchantUsed == false)
	local goldBefore = PlayerProfile.getGold(player)
	local dustBefore = PlayerProfile.getGemDust(player)
	PlayerProfile.addGemDust(player, GemCraft.ticketDust("primordial")) -- P2.5b C: 변환권은 골드 + 보석 가루(가루는 이 한 장 몫만 - env.restore가 되돌린다)
	local ok9, why9 = GemWorkshop.buyTicket(player, "primordial", 1000, alwaysNear)
	t.check(("반경 안 변환권 구매 -> 성공 · 태초 변환권 +1 · 골드 -1000 · 플래그 켜짐 (골드 %d → %d · 태초 %d · 플래그 %s · Attribute %s)"):format(goldBefore, PlayerProfile.getGold(player), tickets.primordial, tostring(profile.hints.gemMerchantUsed), tostring(player:GetAttribute("GemMerchantUsed"))),
		ok9 == true and why9 == nil and tickets.primordial == 1 and PlayerProfile.getGold(player) == goldBefore - 1000 and profile.hints.gemMerchantUsed == true and player:GetAttribute("GemMerchantUsed") == true
			and PlayerProfile.getGemDust(player) == dustBefore)
	profile.hints.gemMerchantUsed = false
	player:SetAttribute("GemMerchantUsed", false)
	local ok10, why10 = GemWorkshop.reroll(player, "gem", 1, alwaysNear)
	t.check(("반경 안 리롤 -> 성공 · 태초 변환권 -1 · 1번 홈 옵션이 새로 배정 · 플래그 켜짐 (변환권 %d · 옵션 %s · 플래그 %s)"):format(tickets.primordial, tostring(weapon.gems[1].option and weapon.gems[1].option.id), tostring(profile.hints.gemMerchantUsed)),
		ok10 == true and why10 == nil and tickets.primordial == 0 and weapon.gems[1].option ~= nil and profile.hints.gemMerchantUsed == true and player:GetAttribute("GemMerchantUsed") == true)

	-- 대상 종류 3가지 + 등급 규칙(규칙 그대로)
	tickets.ancient = 2
	local classState = profile.classes[profile.classId]
	classState.equipment.armor = { grade = "ancient", part = "armor", dropStage = 1, itemLevel = 20, tierIndex = 1, locked = false }
	table.insert(profile.inventory, { grade = "ancient", part = "gloves", dropStage = 1, itemLevel = 21, tierIndex = 1, locked = false })
	table.insert(profile.inventory, { grade = "epic", part = "shoes", dropStage = 1, itemLevel = 22, tierIndex = 1, locked = false })
	local bagIndexAncient, bagIndexEpic = #profile.inventory - 1, #profile.inventory
	local okA, whyA = GemWorkshop.reroll(player, "equipped", "armor", alwaysNear)
	local okB, whyB = GemWorkshop.reroll(player, "bag", bagIndexAncient, alwaysNear)
	t.check(("착용 갑옷 · 가방 장갑(고대) 리롤 -> 성공 · 고대 변환권 2 → %d"):format(tickets.ancient), okA == true and whyA == nil and okB == true and whyB == nil and tickets.ancient == 0)
	tickets.ancient = 1
	classState.equipment.gloves = nil -- 개발 계정은 장갑을 끼고 있을 수 있다 - "빈 착용 부위" 시험이 실제 상태에 기대지 않게 비운다(env.restore가 원래대로 되돌린다)
	local okC, whyC = GemWorkshop.reroll(player, "bag", bagIndexEpic, alwaysNear)
	local okD, whyD = GemWorkshop.reroll(player, "gem", 2, alwaysNear)
	local okE, whyE = GemWorkshop.reroll(player, "equipped", "gloves", alwaysNear)
	t.check("영웅 장비 · 영웅 보석 -> not_rerollable · 빈 착용 부위 -> not_equipped(변환권은 그대로 1장)",
		okC == false and whyC == "not_rerollable" and okD == false and whyD == "not_rerollable" and okE == false and whyE == "not_equipped" and tickets.ancient == 1)

	-- 실제 캐릭터를 옮겨 기본 반경 판정(GemMerchantAccess.check)으로 재기 - 서버가 요청 시점의 캐릭터 위치를 직접 잰다. 한 번도 양보(yield)하지 않아 클라의 위치 복제가 끼어들지 않는다.
	local merchantCenter = GemMerchantAccess.position()
	local originalCFrame = nearRoot and nearRoot.CFrame
	tickets.primordial = 3
	local nearOk, farOk
	if nearRoot then
		nearRoot.CFrame = CFrame.new(merchantCenter + Vector3.new(4, 3, 0))
		nearOk = GemMerchantAccess.check(player)
		local rOk, rWhy = GemWorkshop.reroll(player, "gem", 1) -- 기본 판정 그대로
		nearOk = nearOk and rOk == true and rWhy == nil
		nearRoot.CFrame = CFrame.new(merchantCenter + Vector3.new(WorldConfig.gemMerchant.interactionRangeStuds + 6, 3, 0))
		local fOk, fWhy = GemWorkshop.reroll(player, "gem", 1)
		farOk = fOk == false and fWhy == "out_of_range"
		nearRoot.CFrame = originalCFrame
	end
	t.check("실제 캐릭터를 보석상인 앞(4 stud)으로 옮기면 기본 판정으로 리롤 성공 · 반경 밖(+6)으로 옮기면 out_of_range", nearOk == true and farOk == true)

	-- 저장 왕복(검증용 저장 키 - 수동 Play 모드에서만 이 블록이 돈다): 플래그가 DataStore를 왕복해도 유지된다
	if DevToolsConfig.verifyArmed then
		local copy = deepCopy(profile)
		copy.hints.gemMerchantUsed = true
		local saveOk, saveWhy = SaveSystem.saveProfile(player, copy)
		local loaded, loadWhy = SaveSystem.loadProfile(player)
		if saveOk then
			profile.savedAt = copy.savedAt -- 저장한 시점을 이어받는다(안 그러면 다음 저장이 stale_session이 된다)
		end
		t.check(("DataStore 왕복(검증용 키): 저장 %s(%s) → 불러오기(%s) hints.gemMerchantUsed = %s(기대 true) · 버전 %s"):format(tostring(saveOk), tostring(saveWhy), tostring(loadWhy), tostring(loaded and loaded.hints and loaded.hints.gemMerchantUsed), tostring(loaded and loaded.version)),
			saveOk == true and loaded ~= nil and loaded.hints ~= nil and loaded.hints.gemMerchantUsed == true and loaded.version == SaveConfig.saveVersion)
	end

	-- 정리: 프로필을 원래대로
	env.restore(player)
	tickets.ancient, tickets.primordial = saved.tickets.ancient, saved.tickets.primordial
	profile.hints.gemMerchantUsed = saved.flag
	player:SetAttribute("GemMerchantUsed", saved.flag == true)
	weapon = PlayerProfile.getWeapon(player)
	for slot = 1, Gem.slotCount do
		weapon.gems[slot] = saved.gems[slot]
		weapon.slotUnlocked[slot] = saved.unlocked[slot]
	end
	t.check(("검증 뒤 프로필이 원래대로(변환권 %s · 플래그 %s · 1번 홈 %s)"):format(ticketsText(), tostring(profile.hints.gemMerchantUsed), tostring(weapon.gems[1] and weapon.gems[1].grade)),
		tickets.ancient == saved.tickets.ancient and tickets.primordial == saved.tickets.primordial and profile.hints.gemMerchantUsed == saved.flag and #profile.inventory == #saved.bag)
	print(("===S20e 검증 끝(나)=== %d/%d 통과"):format(t.pass, t.total))
end

return GemMerchantVerify
