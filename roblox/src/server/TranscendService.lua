-- QUEUE-ALL10 블록 2 ALL10-P2 초월 계승 서버(규칙 = shared/All10 · 숫자 = shared/data/All10Data · 설계 = docs/design/transcend-inherit-plan.md D1 ~ D17).
--   ① 계승(2-1 · D1 · D2): 태초 +30(활성 직업) → 같은 직업 초월 +0. 2단계(prepare = 미리보기 + 확인 토큰 → confirm = 실행). 메모리 변경은 yield 없이 한 번에 →
--      즉시 저장(flush) 성공 때만 확정 · 실패 = 지급 전으로 되돌림(무기 · 계승 기록 · 칭호 · 보석) · 같은 사람 처리 중 겹친 요청 거절 · 감사 기록 · 같은 서버 알림 + 칭호 "초월 계승자"
--      (세계 번호 · 전 서버 알림 · 명예의 전당 = 드랍 초월만 - 계승은 PrimordialRegistry를 거치지 않는다) · 보상 초월 보석 1개.
--   ② 초월 강화(2-2 · D7 · 결정 4): 확정 · 골드만 · 하락/초기화 없음 · 한 번 = 칸 1개 납입(10칸 = 다음 단계).
--   ③ 고급 수련 51 ~ 100 · 방어 수련(2-3 · D5 · D6): 초월 무기(활성 직업)일 때만 · 상한 = All10.advancedCap · 방어 = 12,000부터.
--   ④ 초월 보석(2-4 · D9 · D16): 계승 뒤에만 · 계정 귀속 목록(profile.transcendGems) · 기본 잠금 · 판매/분해 불가 · 장착 = 초월 무기 1번 홈(태초 상한 홈)에 사본 ·
--      추출 = 100% 무료(목록으로 돌아감) · 다른 보석으로 교체돼도 목록으로 돌아감(PlayerProfile.equipGem) · 보스 드랍(15,000 이상 0.2%) · 지급 감사 기록.
--      보관은 계정 목록이라 가득 참이 없다(D16 "가방 가득이면 우편함" 경우가 생기지 않는다 - 보고서).
--   모든 경제 요소는 골드 · 플레이로만(로벅스 판매 · 유료 랜덤 없음).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local All10 = require(ReplicatedStorage.Shared.All10)
local All10Data = require(ReplicatedStorage.Shared.data.All10Data)
local Option = require(ReplicatedStorage.Shared.Option)
local Gem = require(ReplicatedStorage.Shared.Gem)
local PlayerProfile = require(script.Parent.PlayerProfile)

local TranscendService = {}

local busy = {} -- [Player] = true(계승 저장 대기 중 - 겹친 요청 거절)
local tokens = {} -- [Player] = { token, at, classId }
local gemRng = Random.new()

-- 테스트 · 검증 주입(하네스): save = function(player) → bool, now = function() → 초
TranscendService.deps = nil

local function now()
	return TranscendService.deps and TranscendService.deps.now and TranscendService.deps.now() or os.clock()
end

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local o = {}
	for k, v in pairs(t) do
		o[k] = deepCopy(v)
	end
	return o
end

local function stateOf(player)
	local profile = PlayerProfile.getProfile(player)
	local classState = profile and profile.classId and profile.classes[profile.classId]
	return profile, classState
end

local function hasInherited(profile)
	for _, classState in pairs(profile.classes) do
		if All10.transcendGemUnlocked(classState.transcendInherit) then
			return true
		end
	end
	return false
end
TranscendService.hasInherited = hasInherited

local function audit(player, kind, detail)
	local ok, AuditTrail = pcall(require, script.Parent.AuditTrail)
	if ok and AuditTrail and typeof(player) == "Instance" then
		AuditTrail.note(player, kind, detail)
	end
end

local function sync(player)
	PlayerProfile.syncTranscendAttributes(player)
	PlayerProfile.syncTrainingAttributes(player)
	if typeof(player) == "Instance" then
		PlayerProfile.refreshMaxHp(player)
	end
end

-- 새 초월 보석(계정 목록에 넣고 표를 돌려준다) - source = "inherit" | "boss" | "dev"
local function newGem(player, profile, source)
	local tg = profile.transcendGems
	tg.seq += 1
	local gem = {
		id = "TG" .. tg.seq, grade = "transcendent", itemLevel = PlayerProfile.getAccountBestStage(player),
		option = Option.rollFor("transcendent", profile.classId), locked = true, socket = nil, at = os.time(), source = source,
	}
	table.insert(tg.list, gem)
	return gem
end

local function findGem(profile, gemId)
	for i, gem in ipairs(profile.transcendGems.list) do
		if gem.id == gemId then
			return gem, i
		end
	end
	return nil
end

-- 같은 서버 알림(각자 언어로) - D2: 전 서버 · 세계 번호 · 명예의 전당은 드랍 초월만
local function announceLocal(player)
	local notice = ReplicatedStorage:FindFirstChild("SystemNotice")
	if not notice or typeof(player) ~= "Instance" then
		return
	end
	local Text = require(ReplicatedStorage.Shared.Text)
	for _, other in ipairs(Players:GetPlayers()) do
		notice:FireClient(other, Text.getFor(other, "srv.transcend.inheritAnnounce", { name = player.DisplayName }))
	end
end

-- ── ① 계승 ──
function TranscendService.preview(player)
	local profile, classState = stateOf(player)
	if not classState then
		return { ok = false, why = "no_class" }
	end
	if not All10.enabled() then
		return { ok = false, why = "disabled" }
	end
	local weapon = classState.weapon
	return {
		ok = All10.canInherit(weapon), why = not All10.canInherit(weapon) and (All10.isTranscendWeapon(weapon) and "already" or "not_ready") or nil,
		classId = profile.classId, fromGrade = weapon.grade, fromLevel = weapon.level, toGrade = All10Data.inherit.toGrade,
		weaponMultiplier = All10Data.inherit.weaponMultiplier, rewardGems = All10Data.inherit.rewardGems, titleId = All10Data.inherit.titleId,
		stage = classState.stageProgress.infiniteBest,
	}
end

function TranscendService.prepare(player)
	local view = TranscendService.preview(player)
	if not view.ok then
		return view
	end
	local token = TranscendService.deps and TranscendService.deps.guid and TranscendService.deps.guid() or HttpService:GenerateGUID(false)
	tokens[player] = { token = token, at = now(), classId = view.classId }
	view.token = token
	return view
end

function TranscendService.confirm(player, token)
	local entry = tokens[player]
	tokens[player] = nil -- 한 번 쓰면 끝(같은 토큰 재전송 = 거절)
	if busy[player] then
		return { ok = false, why = "busy" }
	end
	if not entry or type(token) ~= "string" or entry.token ~= token or now() - entry.at > All10Data.inherit.confirmTtlSeconds then
		return { ok = false, why = "token" }
	end
	local profile, classState = stateOf(player)
	if not classState or profile.classId ~= entry.classId then
		return { ok = false, why = "class_changed" }
	end
	if not All10.canInherit(classState.weapon) then
		return { ok = false, why = All10.isTranscendWeapon(classState.weapon) and "already" or "not_ready" }
	end
	if require(script.Parent.BossEncounter).classChangeBlocked(player) then
		return { ok = false, why = "in_boss" } -- 리뷰: 보스전 중 계승 = 거절(전투 중 즉시 강해짐 · 0-2 직업 고정과 같은 원칙)
	end
	-- 지급 전 상태(되돌림용) - 리뷰 높음: 무기 표 전체가 아니라 "이번에 바꾼 칸"만 기억한다(저장 대기 중 보석 교체 · 재련 등 다른 변경을 덮지 않게)
	local before = {
		grade = classState.weapon.grade, transcend = classState.weapon.transcend, inherit = classState.transcendInherit,
		hadTitle = PlayerProfile.hasTitle(player, All10Data.inherit.titleId),
	}
	local weapon = classState.weapon
	local fromGrade, fromLevel = weapon.grade, weapon.level
	weapon.grade = All10Data.inherit.toGrade
	weapon.transcend = { level = 0, slot = 0 }
	-- 계승 스테이지 = 계정 최고(리뷰: 진행 낮은 직업으로 계승해 돌파 기준을 낮추는 이득 방지 - 비용과 같은 기준)
	classState.transcendInherit = { stage = math.max(1, math.floor(tonumber(PlayerProfile.getAccountBestStage(player)) or 1)), at = os.time(), fromGrade = fromGrade, fromLevel = fromLevel }
	if not before.hadTitle then
		PlayerProfile.grantTitle(player, All10Data.inherit.titleId)
	end
	local rewards = {}
	for _ = 1, All10Data.inherit.rewardGems do
		table.insert(rewards, newGem(player, profile, "inherit").id)
	end
	busy[player] = true
	local okSave, saved = pcall(TranscendService.deps and TranscendService.deps.save or function(p)
		return require(script.Parent.ImmediateSave).flush(p)
	end, player)
	busy[player] = nil
	if not (okSave and saved) then
		-- 저장 실패 = 바꾼 칸만 되돌림(등급 · 초월 칸 · 기록 · 칭호 · 보상 보석 - 장착돼 있으면 홈도 비움) - 다음에 다시 시도
		weapon.grade = before.grade
		weapon.transcend = before.transcend
		classState.transcendInherit = before.inherit
		for _, id in ipairs(rewards) do
			local gem, index = findGem(profile, id)
			if gem then
				if gem.socket then
					local cs = profile.classes[gem.socket.classId]
					local copy = cs and cs.weapon and cs.weapon.gems[gem.socket.slot]
					if type(copy) == "table" and copy.transcendGemId == id then
						cs.weapon.gems[gem.socket.slot] = false
					end
				end
				table.remove(profile.transcendGems.list, index) -- 번호(seq)는 되돌리지 않는다(재사용 방지)
			end
		end
		if not before.hadTitle then
			PlayerProfile.revokeTitle(player, All10Data.inherit.titleId)
		end
		sync(player)
		return { ok = false, why = "save_failed" }
	end
	audit(player, "transcendInherit", ("%s 태초 +%d → 초월 +0 · 스테이지 %d · 보석 %s"):format(tostring(profile.classId), fromLevel, classState.transcendInherit.stage, table.concat(rewards, ",")))
	for _, id in ipairs(rewards) do
		audit(player, "transcendGem", ("%s · 계승 보상"):format(id))
	end
	if typeof(player) == "Instance" and profile.classId == entry.classId then -- 리뷰: 대기 중 직업을 바꿨으면 지금 직업 표시를 덮지 않는다
		player:SetAttribute("WeaponGrade", weapon.grade)
	end
	sync(player)
	announceLocal(player)
	return { ok = true, stage = classState.transcendInherit.stage, gems = rewards, titleId = All10Data.inherit.titleId }
end

-- ── ② 초월 강화(칸 1개 납입) ──
function TranscendService.payEnhance(player)
	local _, classState = stateOf(player)
	if not classState or not All10.enabled() then
		return { ok = false, why = "disabled" }
	end
	local t = classState.weapon.transcend
	if not All10.isTranscendWeapon(classState.weapon) then
		return { ok = false, why = "not_transcend" }
	end
	local d = All10Data.transcendEnhance
	if t.level >= d.maxLevel then
		return { ok = false, why = "max" }
	end
	local cost = All10.transcendSlotCost(PlayerProfile.getAccountBestStage(player))
	if not PlayerProfile.trySpendGold(player, cost) then
		return { ok = false, why = "no_gold", cost = cost }
	end
	t.slot += 1
	local leveled = false
	if t.slot >= d.slots then
		t.level += 1
		t.slot = 0
		leveled = true
		audit(player, "transcendEnhance", ("+%d 달성"):format(t.level))
	end
	sync(player)
	if typeof(player) == "Instance" then
		require(script.Parent.ImmediateSave).request(player)
	end
	return { ok = true, level = t.level, slot = t.slot, leveled = leveled, cost = cost }
end

-- ── ③ 고급 · 방어 수련 ──
function TranscendService.buyAdvanced(player)
	local profile, classState = stateOf(player)
	if not classState or not All10.enabled() then
		return { ok = false, why = "disabled" }
	end
	if not All10.isTranscendWeapon(classState.weapon) then
		return { ok = false, why = "not_transcend" } -- ★사용자 규칙: 초월 무기 없으면 안 열림(스테이지만으로 X)
	end
	local best = PlayerProfile.getAccountBestStage(player)
	local level = math.min(profile.training.advanced, All10Data.advancedTraining.maxLevel)
	if level >= All10.advancedCap(best, true) then
		return { ok = false, why = "cap" }
	end
	local cost = All10.advancedCost(level, best)
	if not PlayerProfile.trySpendGold(player, cost) then
		return { ok = false, why = "no_gold", cost = cost }
	end
	profile.training.advanced = level + 1
	sync(player)
	if typeof(player) == "Instance" then
		require(script.Parent.ImmediateSave).request(player)
	end
	return { ok = true, level = level + 1, cost = cost }
end

function TranscendService.buyGuard(player)
	local profile, classState = stateOf(player)
	if not classState or not All10.enabled() then
		return { ok = false, why = "disabled" }
	end
	local best = PlayerProfile.getAccountBestStage(player)
	if not All10.isTranscendWeapon(classState.weapon) then
		return { ok = false, why = "not_transcend" }
	end
	if not All10.defenseUnlocked(best, true) then
		return { ok = false, why = "stage" }
	end
	local level = math.min(profile.training.guard, All10Data.defenseTraining.maxLevel)
	if level >= All10Data.defenseTraining.maxLevel then
		return { ok = false, why = "cap" }
	end
	local cost = All10.defenseCost(level, best)
	if not PlayerProfile.trySpendGold(player, cost) then
		return { ok = false, why = "no_gold", cost = cost }
	end
	profile.training.guard = level + 1
	sync(player)
	if typeof(player) == "Instance" then
		require(script.Parent.ImmediateSave).request(player)
	end
	return { ok = true, level = level + 1, cost = cost }
end

-- ── ④ 초월 보석 ──
TranscendService.GEM_SLOT = 1 -- 태초 상한 홈(GemData.slotGradeCap[1]) - 초월 무기에서만 초월 보석을 받는다

function TranscendService.equipGem(player, gemId)
	local profile, classState = stateOf(player)
	if not classState or not All10.enabled() then
		return { ok = false, why = "disabled" }
	end
	if not hasInherited(profile) then
		return { ok = false, why = "locked" } -- 계승 뒤에만(반드시)
	end
	if not All10.isTranscendWeapon(classState.weapon) then
		return { ok = false, why = "not_transcend" }
	end
	local gem = type(gemId) == "string" and findGem(profile, gemId)
	if not gem then
		return { ok = false, why = "not_found" }
	end
	if gem.socket then
		return { ok = false, why = "socketed" }
	end
	local slot = TranscendService.GEM_SLOT
	local weapon = classState.weapon
	if not Gem.isSlotUnlocked(weapon.slotUnlocked, slot) then
		return { ok = false, why = "slot_locked" }
	end
	local previous = weapon.gems[slot]
	if Gem.isFilled(weapon.gems, slot) then
		if previous.transcendGemId then
			local old = findGem(profile, previous.transcendGemId)
			if old then
				old.socket = nil
			end
		else
			table.insert(classState.gemInventory, { grade = previous.grade, optionId = previous.optionId, itemLevel = previous.itemLevel, option = previous.option })
		end
	end
	weapon.gems[slot] = { grade = gem.grade, itemLevel = gem.itemLevel, option = deepCopy(gem.option), transcendGemId = gem.id }
	gem.socket = { classId = profile.classId, slot = slot }
	if typeof(player) == "Instance" then
		require(script.Parent.GemSync).push(player)
		PlayerProfile.refreshMaxHp(player)
		PlayerProfile.refreshMovementSpeed(player)
		require(script.Parent.ImmediateSave).request(player)
	end
	sync(player)
	return { ok = true, slot = slot }
end

-- 추출: 100% 보존 · 무료 · 재장착 무제한(그 홈은 빈 칸)
function TranscendService.extractGem(player, gemId)
	local profile = PlayerProfile.getProfile(player)
	local gem = profile and type(gemId) == "string" and findGem(profile, gemId)
	if not gem then
		return { ok = false, why = "not_found" }
	end
	if not gem.socket then
		return { ok = false, why = "not_socketed" }
	end
	local classState = profile.classes[gem.socket.classId]
	local weapon = classState and classState.weapon
	if weapon and type(weapon.gems) == "table" then
		local copy = weapon.gems[gem.socket.slot]
		if type(copy) == "table" and copy.transcendGemId == gem.id then
			weapon.gems[gem.socket.slot] = false
		end
	end
	gem.socket = nil
	if typeof(player) == "Instance" then
		require(script.Parent.GemSync).push(player)
		PlayerProfile.refreshMaxHp(player)
		PlayerProfile.refreshMovementSpeed(player)
		require(script.Parent.ImmediateSave).request(player)
	end
	sync(player)
	return { ok = true }
end

-- 일반 보석 교체(PlayerProfile.equipGem)가 초월 보석 사본을 밀어냈을 때 - 목록으로 돌려보낸다(자동 반환)
function TranscendService.onCopyRemoved(player, copy)
	local profile = PlayerProfile.getProfile(player)
	local gem = profile and type(copy) == "table" and copy.transcendGemId and findGem(profile, copy.transcendGemId)
	if gem then
		gem.socket = nil
		audit(player, "transcendGem", ("%s · 홈 교체로 반환"):format(gem.id))
		return true
	end
	return false
end

-- 보스 처치 드랍(CombatResolution - 15,000 이상 · 0.2% · 계승한 계정만)
function TranscendService.rollBossDrop(player, bossStage, roll)
	local profile = PlayerProfile.getProfile(player)
	if not profile or not All10.enabled() or not hasInherited(profile) then
		return nil
	end
	local d = All10Data.transcendGem
	if (bossStage or 0) < d.dropMinStage then
		return nil
	end
	if (roll or gemRng:NextNumber()) >= d.dropChance then
		return nil
	end
	local gem = newGem(player, profile, "boss")
	audit(player, "transcendGem", ("%s · 보스 스테이지 %d 드랍"):format(gem.id, bossStage))
	sync(player)
	if typeof(player) == "Instance" then
		require(script.Parent.ImmediateSave).request(player) -- 리뷰: 희귀 지급은 바로 저장 요청
	end
	return gem
end

-- 화면 표(창이 그리기만 - 서버 계산 그대로)
function TranscendService.view(player)
	local profile, classState = stateOf(player)
	if not classState then
		return nil
	end
	local best = PlayerProfile.getAccountBestStage(player)
	local isT = All10.isTranscendWeapon(classState.weapon)
	local t = isT and classState.weapon.transcend or nil
	local gems = {}
	for _, gem in ipairs(profile.transcendGems.list) do
		table.insert(gems, { id = gem.id, option = deepCopy(gem.option), itemLevel = gem.itemLevel, locked = gem.locked, socket = deepCopy(gem.socket) })
	end
	return {
		enabled = All10.enabled(), canInherit = All10.canInherit(classState.weapon), transcend = isT, inherited = hasInherited(profile),
		level = t and t.level, slot = t and t.slot, slots = All10Data.transcendEnhance.slots, maxLevel = All10Data.transcendEnhance.maxLevel,
		perLevel = All10Data.transcendEnhance.perLevel, slotCost = All10.transcendSlotCost(best),
		advanced = profile.training.advanced, advancedCap = All10.advancedCap(best, isT), advancedMax = All10Data.advancedTraining.maxLevel,
		advancedCost = isT and profile.training.advanced < All10Data.advancedTraining.maxLevel and All10.advancedCost(profile.training.advanced, best) or nil,
		advancedPerLevel = All10Data.advancedTraining.perLevel,
		guard = profile.training.guard, guardMax = All10Data.defenseTraining.maxLevel, guardUnlocked = All10.defenseUnlocked(best, isT), guardUnlockStage = All10Data.defenseTraining.unlockStage,
		guardCost = profile.training.guard < All10Data.defenseTraining.maxLevel and All10.defenseCost(profile.training.guard, best) or nil,
		guardPerLevel = All10Data.defenseTraining.perLevel, guardTake = All10.defenseTakeMultiplier(isT and profile.training.guard or 0),
		gems = gems, bestStage = best, inheritStage = classState.transcendInherit and classState.transcendInherit.stage,
	}
end

local ACTIONS = { view = true, prepare = true, confirm = true, enhance = true, advanced = true, guard = true, equipGem = true, extractGem = true }
function TranscendService.handle(player, action, a)
	if type(action) ~= "string" or not ACTIONS[action] then
		return { ok = false, why = "bad_action" }
	end
	local result
	if action == "view" then
		return { ok = true, view = TranscendService.view(player) }
	elseif busy[player] then
		return { ok = false, why = "busy", view = TranscendService.view(player) } -- 계승 저장 대기 중 = 다른 결제 거절(되돌림과 섞이지 않게)
	elseif action == "prepare" then
		result = TranscendService.prepare(player)
	elseif action == "confirm" then
		result = TranscendService.confirm(player, a)
	elseif action == "enhance" then
		result = TranscendService.payEnhance(player)
	elseif action == "advanced" then
		result = TranscendService.buyAdvanced(player)
	elseif action == "guard" then
		result = TranscendService.buyGuard(player)
	elseif action == "equipGem" then
		result = TranscendService.equipGem(player, a)
	elseif action == "extractGem" then
		result = TranscendService.extractGem(player, a)
	end
	result.view = TranscendService.view(player)
	return result
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	tokens[player] = nil
end)

return TranscendService
